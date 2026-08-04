-- One owner-bound edit transaction keeps the canonical post, structured taste
-- evidence, journal audience, and ordered photo references in sync. Storage
-- objects are uploaded before this RPC and cleaned up after it by the client.

create or replace function private.edit_owned_visit_content_v2(
  p_visit_id uuid,
  p_caption text,
  p_visibility text,
  p_overall_score numeric,
  p_sip_criteria jsonb default '[]'::jsonb,
  p_context_score numeric default null,
  p_context_criteria jsonb default '[]'::jsonb,
  p_sip_raw_note text default null,
  p_context_raw_note text default null,
  p_raw_note_visibility text default 'private',
  p_legacy_private_note text default null,
  p_photo_urls jsonb default '[]'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_visit public.visits%rowtype;
  normalized_caption text := btrim(coalesce(p_caption, ''));
  normalized_visibility text := lower(btrim(coalesce(p_visibility, '')));
  normalized_journal_visibility text := lower(btrim(coalesce(p_raw_note_visibility, 'private')));
  normalized_score numeric := round(p_overall_score, 1);
  normalized_context_score numeric := case
    when p_context_score is null then null
    else round(p_context_score, 1)
  end;
  normalized_sip_criteria jsonb := coalesce(p_sip_criteria, '[]'::jsonb);
  normalized_context_criteria jsonb := coalesce(p_context_criteria, '[]'::jsonb);
  normalized_sip_note text := nullif(btrim(coalesce(p_sip_raw_note, '')), '');
  normalized_context_note text := nullif(btrim(coalesce(p_context_raw_note, '')), '');
  normalized_legacy_note text := nullif(btrim(coalesce(p_legacy_private_note, '')), '');
  normalized_ratings jsonb := '{}'::jsonb;
  normalized_category_scores jsonb := '[]'::jsonb;
  photo_count integer;
  target_has_reflection boolean;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_visit_id is null then
    raise exception 'visit is required' using errcode = '22023';
  end if;

  select visit.* into target_visit
  from public.visits visit
  where visit.id = p_visit_id
  for update;

  if not found then
    raise exception 'visit not found' using errcode = 'P0002';
  end if;
  if target_visit.user_id <> actor then
    raise exception 'visit belongs to another account' using errcode = '42501';
  end if;
  if target_visit.upload_state <> 'complete' then
    raise exception 'only a published visit can be edited' using errcode = '55000';
  end if;

  if char_length(normalized_caption) not between 1 and 1000 then
    raise exception 'caption must contain between 1 and 1000 characters' using errcode = '22023';
  end if;
  if normalized_visibility not in ('private', 'friends', 'everyone') then
    raise exception 'invalid visit visibility' using errcode = '22023';
  end if;
  if normalized_journal_visibility not in ('private', 'friends', 'everyone') then
    raise exception 'invalid journal visibility' using errcode = '22023';
  end if;
  if (
    case normalized_journal_visibility
      when 'private' then 0 when 'friends' then 1 else 2
    end
  ) > (
    case normalized_visibility
      when 'private' then 0 when 'friends' then 1 else 2
    end
  ) then
    raise exception 'journal visibility exceeds visit visibility' using errcode = '22023';
  end if;
  if normalized_score not between 0.5 and 5
     or normalized_score <> p_overall_score then
    raise exception 'sip score must be one decimal between 0.5 and 5' using errcode = '22023';
  end if;
  if not private.v3_rating_criteria_are_valid(normalized_sip_criteria) then
    raise exception 'invalid sip criteria' using errcode = '22023';
  end if;
  if not private.v3_rating_criteria_are_valid(normalized_context_criteria) then
    raise exception 'invalid context criteria' using errcode = '22023';
  end if;
  if normalized_context_score is not null and (
    normalized_context_score not between 0.5 and 5
    or normalized_context_score <> p_context_score
  ) then
    raise exception 'context score must be one decimal between 0.5 and 5' using errcode = '22023';
  end if;
  if char_length(coalesce(normalized_sip_note, '')) > 10000
     or char_length(coalesce(normalized_context_note, '')) > 10000
     or char_length(coalesce(normalized_legacy_note, '')) > 10000 then
    raise exception 'journal note exceeds 10000 characters' using errcode = '22023';
  end if;

  if lower(btrim(coalesce(target_visit.context_type, 'cafe'))) in ('home', 'recipe')
     and (
       normalized_context_score is not null
       or jsonb_array_length(normalized_context_criteria) > 0
     ) then
    raise exception 'Home reflections do not have context criteria' using errcode = '22023';
  end if;

  if jsonb_typeof(p_photo_urls) <> 'array' then
    raise exception 'photo URLs must be an array' using errcode = '22023';
  end if;
  photo_count := jsonb_array_length(p_photo_urls);
  if photo_count > 10 then
    raise exception 'a visit can contain at most 10 photos' using errcode = '22023';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_photo_urls) photo(value)
    where jsonb_typeof(photo.value) <> 'string'
      or btrim(photo.value #>> '{}') = ''
  ) then
    raise exception 'photo URLs must be nonempty strings' using errcode = '22023';
  end if;
  if (
    select count(*) <> count(distinct photo.value #>> '{}')
    from jsonb_array_elements(p_photo_urls) photo(value)
  ) then
    raise exception 'photo URLs must be unique' using errcode = '22023';
  end if;
  if exists (
    select 1
    from jsonb_array_elements_text(p_photo_urls) photo(value)
    where not exists (
      select 1
      from public.visit_photos existing_photo
      where existing_photo.visit_id = p_visit_id
        and existing_photo.photo_url = photo.value
    )
      and photo.value is distinct from target_visit.poster_photo_url
      and lower(photo.value) !~ (
        '^mugshot-storage://visit-photos-private/'
        || lower(actor::text)
        || '/'
        || lower(p_visit_id::text)
        || '/[^/?#]+$'
      )
  ) then
    raise exception 'photo reference is not owned by this visit' using errcode = '42501';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(normalized_sip_criteria) left_criterion
    join jsonb_array_elements(normalized_sip_criteria) right_criterion
      on lower(btrim(left_criterion ->> 'name')) = lower(btrim(right_criterion ->> 'name'))
     and left_criterion ->> 'id' <> right_criterion ->> 'id'
  ) then
    raise exception 'sip criterion names must be unique' using errcode = '22023';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(normalized_context_criteria) left_criterion
    join jsonb_array_elements(normalized_context_criteria) right_criterion
      on lower(btrim(left_criterion ->> 'name')) = lower(btrim(right_criterion ->> 'name'))
     and left_criterion ->> 'id' <> right_criterion ->> 'id'
  ) then
    raise exception 'context criterion names must be unique' using errcode = '22023';
  end if;

  select coalesce(
    jsonb_object_agg(criterion ->> 'name', (criterion ->> 'score')::numeric),
    '{}'::jsonb
  ) into normalized_ratings
  from jsonb_array_elements(normalized_sip_criteria) criterion;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'name', criterion ->> 'name',
        'score', (criterion ->> 'score')::numeric,
        'weight', (criterion ->> 'weight')::numeric
      )
      order by (criterion ->> 'sortOrder')::integer
    ),
    '[]'::jsonb
  ) into normalized_category_scores
  from jsonb_array_elements(normalized_sip_criteria) criterion;

  if target_visit.cafe_session_id is not null then
    update public.cafe_sessions
    set visibility = normalized_visibility
    where id = target_visit.cafe_session_id
      and user_id = actor;

    update public.visits
    set visibility = normalized_visibility
    where cafe_session_id = target_visit.cafe_session_id
      and user_id = actor;

    if normalized_visibility = 'private' then
      delete from public.cafe_experience_public_projections
      where session_id = target_visit.cafe_session_id
        and user_id = actor;
    end if;
  end if;

  update public.visits
  set caption = normalized_caption,
      visibility = normalized_visibility,
      overall_score = normalized_score,
      ratings = normalized_ratings,
      category_scores = normalized_category_scores,
      poster_photo_url = case
        when photo_count = 0 then null
        else p_photo_urls ->> 0
      end
  where id = p_visit_id
    and user_id = actor;

  delete from public.visit_photos
  where visit_id = p_visit_id;

  insert into public.visit_photos (visit_id, photo_url, sort_order)
  select p_visit_id, photo.value, (photo.ordinality - 1)::integer
  from jsonb_array_elements_text(p_photo_urls) with ordinality as photo(value, ordinality);

  select exists (
    select 1
    from public.visit_v3_reflections reflection
    where reflection.visit_id = p_visit_id
      and reflection.user_id = actor
  ) into target_has_reflection;

  if target_has_reflection then
    perform public.upsert_visit_v3_reflection_v1(
      p_visit_id => p_visit_id,
      p_schema_version => 1,
      p_context_score => normalized_context_score,
      p_context_criteria => normalized_context_criteria,
      p_sip_raw_note => normalized_sip_note,
      p_context_raw_note => normalized_context_note,
      p_raw_note_visibility => normalized_journal_visibility,
      p_photo_fallback => case
        when photo_count > 0 then null
        else (
          select reflection.photo_fallback
          from public.visit_v3_reflections reflection
          where reflection.visit_id = p_visit_id
        )
      end,
      p_home_make_again => (
        select reflection.home_make_again
        from public.visit_v3_reflections reflection
        where reflection.visit_id = p_visit_id
      )
    );

    delete from public.visit_private_notes
    where visit_id = p_visit_id
      and user_id = actor;
  elsif normalized_legacy_note is null then
    delete from public.visit_private_notes
    where visit_id = p_visit_id
      and user_id = actor;
  else
    insert into public.visit_private_notes (visit_id, user_id, note)
    values (p_visit_id, actor, normalized_legacy_note)
    on conflict (visit_id) do update
    set note = excluded.note,
        updated_at = now()
    where public.visit_private_notes.user_id = actor;
  end if;

  return p_visit_id;
end;
$$;

comment on function private.edit_owned_visit_content_v2(
  uuid, text, text, numeric, jsonb, numeric, jsonb, text, text, text, text, jsonb
) is
  'Atomically edits an owned published visit, taste criteria, journal audience, and ordered photo references.';

revoke all on function private.edit_owned_visit_content_v2(
  uuid, text, text, numeric, jsonb, numeric, jsonb, text, text, text, text, jsonb
) from public, anon, authenticated;
