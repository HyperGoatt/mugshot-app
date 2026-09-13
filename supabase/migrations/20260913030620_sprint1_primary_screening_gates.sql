-- Source-owned snapshots contain shared fields only. Private visits and notes
-- never enter the queue. Processing remains disabled until worker activation.
create function private.refresh_profile_screening_v1(p_owner uuid)
returns void language plpgsql security definer set search_path='' as $$
declare payload jsonb;
begin
  select jsonb_build_object(
    'text',concat_ws(E'\n',profile.display_name,profile.username,profile.bio,profile.location,
      profile.favorite_drink,profile.instagram_handle,
      (select string_agg(spot.descriptor,E'\n' order by spot.position) from public.profile_favorite_spots spot where spot.user_id=profile.id)),
    'images',to_jsonb(array_remove(array[nullif(profile.avatar_url,''),nullif(profile.banner_url,'')],null))
  ) into payload from public.users profile where profile.id=p_owner;
  perform private.enqueue_screening_v1('user',p_owner,p_owner,payload);
end;
$$;

create function private.refresh_visit_screening_v1(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare payload jsonb; owner_id uuid;
begin
  select visit.user_id,case when visit.visibility in ('friends','everyone') and visit.upload_state='complete' then
    jsonb_build_object(
      'text',concat_ws(E'\n',visit.caption,visit.drink_type_custom,to_jsonb(visit)->>'location_name'),
      'images',coalesce((select jsonb_agg(image.url order by image.url) from (
        select nullif(visit.poster_photo_url,'') as url
        union select nullif(photo.photo_url,'') from public.visit_photos photo where photo.visit_id=visit.id
      ) image where image.url is not null),'[]'::jsonb)
    ) else null end into owner_id,payload
  from public.visits visit where visit.id=p_id;
  perform private.enqueue_screening_v1('visit',p_id,owner_id,payload);
end;
$$;

create function private.refresh_comment_screening_v1(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare payload jsonb; owner_id uuid;
begin
  select comment.user_id,case when comment.removed_at is null and visit.visibility in ('friends','everyone') and visit.upload_state='complete' then
    jsonb_build_object('text',comment.text,'images','[]'::jsonb) else null end
    into owner_id,payload
  from public.comments comment join public.visits visit on visit.id=comment.visit_id where comment.id=p_id;
  perform private.enqueue_screening_v1('comment',p_id,owner_id,payload);
end;
$$;

create function private.refresh_primary_screening_trigger_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare value jsonb:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
  previous jsonb:=case when tg_op='UPDATE' then to_jsonb(old) else null end;
  target_id uuid; comment_id uuid;
begin
  if tg_table_name='users' then perform private.refresh_profile_screening_v1((value->>'id')::uuid);
  elsif tg_table_name='profile_favorite_spots' then
    perform private.refresh_profile_screening_v1((value->>'user_id')::uuid);
    if previous->>'user_id' is distinct from value->>'user_id' and previous is not null then
      perform private.refresh_profile_screening_v1((previous->>'user_id')::uuid);
    end if;
  elsif tg_table_name='comments' then perform private.refresh_comment_screening_v1((value->>'id')::uuid);
  elsif tg_table_name='visits' then
    target_id:=(value->>'id')::uuid;
    perform private.refresh_visit_screening_v1(target_id);
    if to_regprocedure('private.refresh_collection_screening_v1(text,uuid)') is not null then
      for comment_id in select id from public.recipe_versions where source_visit_id=target_id loop
        perform private.refresh_collection_screening_v1('recipe',comment_id);
      end loop;
    end if;
    -- Parent audience changes invalidate comment payloads in the same commit.
    for comment_id in select id from public.comments where visit_id=target_id loop
      perform private.refresh_comment_screening_v1(comment_id);
    end loop;
  elsif tg_table_name='visit_photos' then
    perform private.refresh_visit_screening_v1((value->>'visit_id')::uuid);
    if previous->>'visit_id' is distinct from value->>'visit_id' and previous is not null then
      perform private.refresh_visit_screening_v1((previous->>'visit_id')::uuid);
    end if;
  end if;
  return null;
end;
$$;
create trigger screening_profile after insert or update or delete on public.users
  for each row execute function private.refresh_primary_screening_trigger_v1();
create trigger screening_profile_spots after insert or update or delete on public.profile_favorite_spots
  for each row execute function private.refresh_primary_screening_trigger_v1();
create trigger screening_visit after insert or update or delete on public.visits
  for each row execute function private.refresh_primary_screening_trigger_v1();
create trigger screening_visit_photos after insert or update or delete on public.visit_photos
  for each row execute function private.refresh_primary_screening_trigger_v1();
create trigger screening_comment after insert or update or delete on public.comments
  for each row execute function private.refresh_primary_screening_trigger_v1();

revoke all on function private.refresh_profile_screening_v1(uuid),private.refresh_visit_screening_v1(uuid),private.refresh_comment_screening_v1(uuid),private.refresh_primary_screening_trigger_v1() from public,anon,authenticated;

-- Existing shared data starts pending. This only creates sealed local queue
-- snapshots; no external processing happens inside a migration.
select private.refresh_profile_screening_v1(id) from public.users;
select private.refresh_visit_screening_v1(id) from public.visits;
select private.refresh_comment_screening_v1(id) from public.comments;

-- Preserve the existing function identities and audience/moderation rules.
-- Do not rename helpers: stored policy dependencies must use these new bodies.

create or replace function private.can_view_user_as(p_user_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (coalesce(p_user_id=p_viewer,false) or private.screening_approved_v1('user',p_user_id))
    and private.is_live_account_as(p_viewer)
    and private.is_live_account_as(p_user_id)
    and not private.blocked_between(p_viewer, p_user_id)
    and (
      p_user_id = p_viewer
      or not private.has_active_moderation_action(
        'user', p_user_id, array['account_suspended']::text[]
      )
    );
$$;

create or replace function private.can_view_visit_as(p_visit_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_viewer) and exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and (coalesce(visit.user_id=p_viewer,false) or private.screening_approved_v1('visit',visit.id))
      and (visit.upload_state = 'complete' or visit.user_id = p_viewer)
      and private.can_view_user_as(visit.user_id, p_viewer)
      and (
        visit.user_id = p_viewer
        or not private.has_active_moderation_action(
          'visit', visit.id, array['content_hidden']::text[]
        )
      )
      and (
        visit.user_id = p_viewer
        or visit.visibility = 'everyone'
        or (
          visit.visibility = 'friends'
          and private.confirmed_friends(p_viewer, visit.user_id)
        )
      )
  );
$$;

create or replace function private.can_view_comment_as(p_comment_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_viewer) and exists (
    select 1
    from public.comments comment
    where comment.id = p_comment_id
      and (coalesce(comment.user_id=p_viewer,false) or private.screening_approved_v1('comment',comment.id))
      and comment.removed_at is null
      and not private.has_active_moderation_action(
        'comment', comment.id, array['content_hidden']::text[]
      )
      and private.can_view_visit_as(comment.visit_id, p_viewer)
      and private.can_view_user_as(comment.user_id, p_viewer)
  );
$$;

create or replace function private.profile_owner_visible_v2(
  p_owner uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (coalesce(p_owner=p_viewer,false) or private.screening_approved_v1('user',p_owner))
    and private.is_live_account_as(p_owner)
    and (
      p_viewer is null
      or (
        private.is_live_account_as(p_viewer)
        and not private.blocked_between(p_viewer, p_owner)
      )
    )
    and (
      coalesce(p_viewer = p_owner,false)
      or not private.has_active_moderation_action(
        'user', p_owner, array['account_suspended']::text[]
      )
    );
$$;

create or replace function private.profile_visit_visible_v2(
  p_visit_id uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and (coalesce(visit.user_id=p_viewer,false) or private.screening_approved_v1('visit',visit.id))
      and visit.upload_state = 'complete'
      and private.profile_owner_visible_v2(visit.user_id, p_viewer)
      and not private.has_active_moderation_action(
        'visit', visit.id, array['content_hidden']::text[]
      )
      and (
        visit.user_id = p_viewer
        or visit.visibility = 'everyone'
        or (
          p_viewer is not null
          and visit.visibility = 'friends'
          and private.confirmed_friends(p_viewer, visit.user_id)
        )
      )
  );
$$;

create or replace function private.profile_visit_published_v1(
  p_visit_id uuid, p_profile_owner uuid
)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.visits visit
    where visit.id = p_visit_id
      and private.screening_approved_v1('visit',visit.id)
      and visit.upload_state = 'complete'
      and private.profile_owner_visible_v2(visit.user_id, null)
      and not private.has_active_moderation_action(
        'visit', visit.id, array['content_hidden']::text[]
      )
      and (
        lower(visit.visibility) = 'everyone'
        or (lower(visit.visibility) = 'friends'
          and private.profile_shows_friends_v1(visit.user_id)
          and private.profile_shows_friends_v1(p_profile_owner))
      )
  );
$$;

create or replace function private.is_public_visit_discoverable_v3(
  p_visit_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and private.screening_approved_v1('visit',visit.id)
      and private.screening_approved_v1('user',visit.user_id)
      and visit.visibility = 'everyone'
      and visit.upload_state = 'complete'
      and private.is_live_account_as(visit.user_id)
      and not private.has_active_moderation_action(
        'user', visit.user_id, array['account_suspended']::text[]
      )
      and not private.has_active_moderation_action(
        'visit', visit.id, array['content_hidden']::text[]
      )
  );
$$;

create or replace function private.is_capability_shareable_visit_v1(
  p_visit_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and private.screening_approved_v1('visit',visit.id)
      and private.screening_approved_v1('user',visit.user_id)
      and visit.visibility in ('everyone', 'friends')
      and visit.upload_state = 'complete'
      and private.is_live_account_as(visit.user_id)
      and not private.has_active_moderation_action(
        'user', visit.user_id, array['account_suspended']::text[]
      )
      and not private.has_active_moderation_action(
        'visit', visit.id, array['content_hidden']::text[]
      )
  );
$$;


-- Restrictive policies also cover older permissive raw-table read policies.
create policy screening_users_read on public.users as restrictive for select to anon,authenticated
  using(id=(select auth.uid()) or public.content_screening_approved_v1('user',id));
create policy screening_visits_read on public.visits as restrictive for select to anon,authenticated
  using(user_id=(select auth.uid()) or public.content_screening_approved_v1('visit',id));
create policy screening_comments_read on public.comments as restrictive for select to anon,authenticated
  using(user_id=(select auth.uid()) or public.content_screening_approved_v1('comment',id));

create function private.screening_decode_path_v1(p_value text)
returns text language plpgsql immutable set search_path='' as $$
declare result bytea:=''::bytea; position integer:=1; part text;
begin
  while position<=char_length(p_value) loop
    part:=substr(p_value,position,1);
    if part='%' then
      part:=substr(p_value,position+1,2);
      if part !~ '^[A-Fa-f0-9]{2}$' then return null;end if;
      result:=result||decode(part,'hex');position:=position+3;
    else result:=result||convert_to(part,'UTF8');position:=position+1;
    end if;
  end loop;
  return convert_from(result,'UTF8');
exception when others then return null;
end;
$$;

create function private.invalidate_screening_media_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare current_object jsonb:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
  previous_object jsonb:=case when tg_op='UPDATE' then to_jsonb(old) else null end;
begin
  -- Reading an object must not trigger a screening loop. Content writes update
  -- the Storage version/ETag metadata; access-time-only changes are ignored.
  if tg_op='UPDATE' and current_object->'name' is not distinct from previous_object->'name'
    and current_object->'bucket_id' is not distinct from previous_object->'bucket_id'
    and current_object->'metadata' is not distinct from previous_object->'metadata'
    and current_object->'version' is not distinct from previous_object->'version' then return null;end if;
  update private.screening_jobs job set state='pending',revision=gen_random_uuid(),reason=null,
    evidence='{}'::jsonb,attempts=0,available_at=now(),lease_token=null,lease_until=null,
    appeal_requested_at=null,updated_at=now()
  where exists (
    select 1 from jsonb_array_elements_text(job.payload->'images') image(ref)
    where private.screening_decode_path_v1(regexp_replace(image.ref,
      '^(mugshot-storage://|https://[^/]+/storage/v1/object/public/)','')) in (
      (current_object->>'bucket_id')||'/'||(current_object->>'name'),
      (previous_object->>'bucket_id')||'/'||(previous_object->>'name')
    )
  );
  return null;
end;
$$;
revoke all on function private.screening_decode_path_v1(text),private.invalidate_screening_media_v1() from public,anon,authenticated;
create trigger screening_storage_content after insert or update or delete on storage.objects
  for each row execute function private.invalidate_screening_media_v1();
