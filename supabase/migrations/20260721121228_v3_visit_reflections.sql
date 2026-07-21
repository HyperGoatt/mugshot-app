-- V3 keeps the independent sip score on visits while storing the optional
-- context reflection, raw journal writing, and the derived Mugshot score in an
-- owner-private envelope. Social clients can read only the sanitized RPC.

create or replace function private.v3_rating_criteria_are_valid(p_payload jsonb)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select case
    when p_payload is null or jsonb_typeof(p_payload) <> 'array' then false
    else
      jsonb_array_length(p_payload) <= 40
      and not exists (
        select 1
        from jsonb_array_elements(p_payload) criterion
        where jsonb_typeof(criterion) <> 'object'
          or coalesce(criterion ->> 'id', '')
            !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$'
          or length(btrim(coalesce(criterion ->> 'name', ''))) not between 1 and 80
          or jsonb_typeof(criterion -> 'score') <> 'number'
          or (criterion ->> 'score')::numeric not between 0.5 and 5
          or (criterion ->> 'score')::numeric * 10
            <> trunc((criterion ->> 'score')::numeric * 10)
          or jsonb_typeof(criterion -> 'weight') <> 'number'
          or (criterion ->> 'weight')::numeric not in (0.5, 1, 1.5, 2.25)
          or coalesce(criterion ->> 'sortOrder', '') !~ '^[0-9]+$'
          or (criterion ->> 'sortOrder')::integer not between 0 and 39
          or (
            criterion ? 'relevanceOverride'
            and coalesce(jsonb_typeof(criterion -> 'relevanceOverride'), 'null')
              not in ('boolean', 'null')
          )
      )
      and (
        select count(*) = count(distinct criterion ->> 'id')
        from jsonb_array_elements(p_payload) criterion
      )
  end;
$$;

comment on function private.v3_rating_criteria_are_valid(jsonb) is
  'Validates the bounded, structured V3 context-criterion snapshot.';

revoke all on function private.v3_rating_criteria_are_valid(jsonb)
  from public, anon, authenticated;
grant usage on schema private to service_role;
grant execute on function private.v3_rating_criteria_are_valid(jsonb)
  to service_role;

create table public.visit_v3_reflections (
  visit_id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  schema_version smallint not null default 1,
  sip_score numeric(2, 1) not null,
  context_score numeric(2, 1),
  context_criteria jsonb not null default '[]'::jsonb,
  sip_raw_note text,
  context_raw_note text,
  raw_note_visibility text not null default 'private',
  photo_fallback text,
  home_make_again text,
  mugshot_score numeric(2, 1) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint visit_v3_reflections_visit_owner_unique unique (visit_id, user_id),
  constraint visit_v3_reflections_visit_owner_fk
    foreign key (visit_id, user_id)
    references public.visits(id, user_id)
    on delete cascade
    deferrable initially deferred,
  constraint visit_v3_reflections_schema_version_positive
    check (schema_version > 0),
  constraint visit_v3_reflections_sip_score_tenth_step check (
    sip_score between 0.5 and 5
    and sip_score * 10 = trunc(sip_score * 10)
  ),
  constraint visit_v3_reflections_context_score_tenth_step check (
    context_score is null
    or (
      context_score between 0.5 and 5
      and context_score * 10 = trunc(context_score * 10)
    )
  ),
  constraint visit_v3_reflections_mugshot_score_tenth_step check (
    mugshot_score between 0.5 and 5
    and mugshot_score * 10 = trunc(mugshot_score * 10)
  ),
  constraint visit_v3_reflections_context_criteria_valid
    check (private.v3_rating_criteria_are_valid(context_criteria)),
  constraint visit_v3_reflections_sip_raw_note_length
    check (char_length(coalesce(sip_raw_note, '')) <= 10000),
  constraint visit_v3_reflections_context_raw_note_length
    check (char_length(coalesce(context_raw_note, '')) <= 10000),
  constraint visit_v3_reflections_raw_note_visibility_valid
    check (raw_note_visibility in ('private', 'friends', 'everyone')),
  constraint visit_v3_reflections_photo_fallback_valid check (
    photo_fallback is null or photo_fallback = 'mugsy_missed_photo'
  ),
  constraint visit_v3_reflections_home_make_again_valid check (
    home_make_again is null
    or home_make_again in ('yes', 'with_a_tweak', 'not_this_version')
  )
);

comment on table public.visit_v3_reflections is
  'Owner-private V3 context and raw-note envelope paired one-to-one with a canonical visit.';
comment on column public.visit_v3_reflections.sip_score is
  'One-decimal snapshot of visits.overall_score at the latest reflection write.';
comment on column public.visit_v3_reflections.context_score is
  'Optional independent cafe or setting score; Home intentionally leaves it null.';
comment on column public.visit_v3_reflections.context_criteria is
  'Structured criteria that shaped the optional context score.';
comment on column public.visit_v3_reflections.raw_note_visibility is
  'Explicit raw-note audience, constrained by the canonical visit audience during writes.';
comment on column public.visit_v3_reflections.mugshot_score is
  'One-decimal blend of sip and context, falling back to sip when context is unscored.';

create index visit_v3_reflections_user_updated_idx
  on public.visit_v3_reflections (user_id, updated_at desc, visit_id);

alter table public.visit_v3_reflections enable row level security;
alter table public.visit_v3_reflections force row level security;

create policy "Owners read V3 visit reflections"
  on public.visit_v3_reflections
  for select
  to authenticated
  using (user_id = (select auth.uid()));

-- Authenticated clients can inspect only their own row. All mutation is routed
-- through the caller-bound RPC so visit ownership and audience breadth are
-- checked atomically with the upsert.
revoke all on table public.visit_v3_reflections from public, anon, authenticated;
grant select on table public.visit_v3_reflections to authenticated;
grant select, insert, update, delete on table public.visit_v3_reflections to service_role;

create or replace function public.upsert_visit_v3_reflection_v1(
  p_visit_id uuid,
  p_schema_version integer default 1,
  p_context_score numeric default null,
  p_context_criteria jsonb default '[]'::jsonb,
  p_sip_raw_note text default null,
  p_context_raw_note text default null,
  p_raw_note_visibility text default 'private',
  p_photo_fallback text default null,
  p_home_make_again text default null
)
returns table (
  schema_version integer,
  visit_id uuid,
  sip_score numeric,
  context_score numeric,
  context_criteria jsonb,
  sip_raw_note text,
  context_raw_note text,
  raw_note_visibility text,
  photo_fallback text,
  home_make_again text,
  mugshot_score numeric,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_visit public.visits%rowtype;
  target_context text;
  normalized_context_score numeric;
  normalized_context_criteria jsonb := coalesce(p_context_criteria, '[]'::jsonb);
  normalized_sip_note text := nullif(btrim(coalesce(p_sip_raw_note, '')), '');
  normalized_context_note text := nullif(btrim(coalesce(p_context_raw_note, '')), '');
  normalized_raw_visibility text := lower(btrim(coalesce(p_raw_note_visibility, 'private')));
  normalized_photo_fallback text := nullif(lower(btrim(coalesce(p_photo_fallback, ''))), '');
  normalized_home_make_again text := nullif(lower(btrim(coalesce(p_home_make_again, ''))), '');
  normalized_sip_score numeric;
  derived_mugshot_score numeric;
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
    raise exception 'visit reflection belongs to another account' using errcode = '42501';
  end if;
  if p_schema_version <> 1 then
    raise exception 'unsupported V3 reflection schema' using errcode = '22023';
  end if;
  if not private.v3_rating_criteria_are_valid(normalized_context_criteria) then
    raise exception 'invalid context criteria' using errcode = '22023';
  end if;

  normalized_context_score := case
    when p_context_score is null then null
    else round(p_context_score, 1)
  end;
  if p_context_score is not null and normalized_context_score <> p_context_score then
    raise exception 'context score must use one decimal place' using errcode = '22023';
  end if;
  if normalized_context_score is not null
     and normalized_context_score not between 0.5 and 5 then
    raise exception 'context score is outside the supported range' using errcode = '22023';
  end if;

  normalized_sip_score := round(target_visit.overall_score::numeric, 1);
  if normalized_sip_score not between 0.5 and 5 then
    raise exception 'sip score is outside the supported range' using errcode = '22023';
  end if;

  if normalized_raw_visibility not in ('private', 'friends', 'everyone') then
    raise exception 'invalid raw-note visibility' using errcode = '22023';
  end if;
  if (
    case normalized_raw_visibility
      when 'private' then 0 when 'friends' then 1 else 2
    end
  ) > (
    case lower(btrim(target_visit.visibility))
      when 'private' then 0 when 'friends' then 1 else 2
    end
  ) then
    raise exception 'raw-note visibility exceeds visit visibility' using errcode = '22023';
  end if;

  if normalized_photo_fallback is not null
     and normalized_photo_fallback <> 'mugsy_missed_photo' then
    raise exception 'invalid photo fallback' using errcode = '22023';
  end if;
  if normalized_home_make_again is not null
     and normalized_home_make_again not in ('yes', 'with_a_tweak', 'not_this_version') then
    raise exception 'invalid Home make-again value' using errcode = '22023';
  end if;

  target_context := lower(btrim(coalesce(target_visit.context_type, 'cafe')));
  if target_context in ('home', 'recipe') then
    if normalized_context_score is not null
       or jsonb_array_length(normalized_context_criteria) > 0 then
      raise exception 'Home reflections do not have a context score' using errcode = '22023';
    end if;
  elsif normalized_home_make_again is not null then
    raise exception 'make-again belongs only to Home reflections' using errcode = '22023';
  end if;

  derived_mugshot_score := case
    when normalized_context_score is null then normalized_sip_score
    else round((normalized_sip_score + normalized_context_score) / 2, 1)
  end;

  insert into public.visit_v3_reflections as reflection (
    visit_id,
    user_id,
    schema_version,
    sip_score,
    context_score,
    context_criteria,
    sip_raw_note,
    context_raw_note,
    raw_note_visibility,
    photo_fallback,
    home_make_again,
    mugshot_score
  ) values (
    p_visit_id,
    actor,
    p_schema_version,
    normalized_sip_score,
    normalized_context_score,
    normalized_context_criteria,
    normalized_sip_note,
    normalized_context_note,
    normalized_raw_visibility,
    normalized_photo_fallback,
    normalized_home_make_again,
    derived_mugshot_score
  )
  on conflict on constraint visit_v3_reflections_pkey do update set
    schema_version = excluded.schema_version,
    sip_score = excluded.sip_score,
    context_score = excluded.context_score,
    context_criteria = excluded.context_criteria,
    sip_raw_note = excluded.sip_raw_note,
    context_raw_note = excluded.context_raw_note,
    raw_note_visibility = excluded.raw_note_visibility,
    photo_fallback = excluded.photo_fallback,
    home_make_again = excluded.home_make_again,
    mugshot_score = excluded.mugshot_score,
    updated_at = clock_timestamp()
  where reflection.user_id = actor;

  if not found then
    raise exception 'visit reflection ownership conflict' using errcode = '42501';
  end if;

  return query
  select
    reflection.schema_version::integer,
    reflection.visit_id,
    reflection.sip_score,
    reflection.context_score,
    reflection.context_criteria,
    reflection.sip_raw_note,
    reflection.context_raw_note,
    reflection.raw_note_visibility,
    reflection.photo_fallback,
    reflection.home_make_again,
    reflection.mugshot_score,
    reflection.created_at,
    reflection.updated_at
  from public.visit_v3_reflections reflection
  where reflection.visit_id = p_visit_id
    and reflection.user_id = actor;
end;
$$;

comment on function public.upsert_visit_v3_reflection_v1(
  uuid, integer, numeric, jsonb, text, text, text, text, text
) is
  'Caller-bound, retry-safe upsert of the owner-private V3 visit reflection.';

create or replace function public.get_visit_v3_reflection_v1(p_visit_id uuid)
returns table (
  schema_version integer,
  visit_id uuid,
  sip_score numeric,
  context_score numeric,
  context_criteria jsonb,
  sip_raw_note text,
  context_raw_note text,
  raw_note_visibility text,
  photo_fallback text,
  home_make_again text,
  mugshot_score numeric,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  return query
  select
    reflection.schema_version::integer,
    reflection.visit_id,
    reflection.sip_score,
    reflection.context_score,
    reflection.context_criteria,
    case
      when actor = reflection.user_id
        or reflection.raw_note_visibility = 'everyone'
        or (
          reflection.raw_note_visibility = 'friends'
          and private.confirmed_friends(actor, reflection.user_id)
        )
      then reflection.sip_raw_note
      else null
    end,
    case
      when actor = reflection.user_id
        or reflection.raw_note_visibility = 'everyone'
        or (
          reflection.raw_note_visibility = 'friends'
          and private.confirmed_friends(actor, reflection.user_id)
        )
      then reflection.context_raw_note
      else null
    end,
    reflection.raw_note_visibility,
    reflection.photo_fallback,
    reflection.home_make_again,
    reflection.mugshot_score,
    reflection.created_at,
    reflection.updated_at
  from public.visit_v3_reflections reflection
  join public.visits visit on visit.id = reflection.visit_id
  where reflection.visit_id = p_visit_id
    and not private.blocked_between(actor, reflection.user_id)
    and (
      actor = reflection.user_id
      or (
        visit.upload_state = 'complete'
        and (
          visit.visibility = 'everyone'
          or (
            visit.visibility = 'friends'
            and private.confirmed_friends(actor, reflection.user_id)
          )
        )
      )
    );
end;
$$;

comment on function public.get_visit_v3_reflection_v1(uuid) is
  'Returns a visible V3 reflection while nulling raw notes outside their explicit audience.';

revoke all on function public.upsert_visit_v3_reflection_v1(
  uuid, integer, numeric, jsonb, text, text, text, text, text
) from public, anon, authenticated;
revoke all on function public.get_visit_v3_reflection_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.upsert_visit_v3_reflection_v1(
  uuid, integer, numeric, jsonb, text, text, text, text, text
) to authenticated, service_role;
grant execute on function public.get_visit_v3_reflection_v1(uuid)
  to authenticated, service_role;

-- Criteria-derived cafe ratings may preserve one decimal. Direct star input
-- can remain half-step in the client without constraining adopted suggestions.
alter table public.cafe_experience_snapshots
  drop constraint if exists cafe_experience_snapshots_rating_half_step;
alter table public.cafe_experience_snapshots
  add constraint cafe_experience_snapshots_rating_tenth_step check (
    cafe_rating is null
    or (
      cafe_rating between 1 and 5
      and cafe_rating * 10 = trunc(cafe_rating * 10)
    )
  );

alter table public.cafe_experience_public_projections
  drop constraint if exists cafe_experience_public_projection_rating_half_step;
alter table public.cafe_experience_public_projections
  add constraint cafe_experience_public_projection_rating_tenth_step check (
    cafe_rating is null
    or (
      cafe_rating between 1 and 5
      and cafe_rating * 10 = trunc(cafe_rating * 10)
    )
  );
