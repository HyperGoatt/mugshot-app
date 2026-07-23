-- Keep independently private recipe instructions out of socially visible
-- visit rows without rewriting any historical visit or recipe payload.
--
-- Contract v2 clients stage the full owner-bound payload first, then insert a
-- display-only visit row. The existing materialization trigger consumes the
-- private stage in the same transaction as the visit insert, writes the full
-- immutable recipe_version, and leaves only recipe name/version on visits.
-- Contract v1 rows remain byte-for-byte unchanged for pre-alpha compatibility.

begin;

alter table public.visits
  add column if not exists recipe_payload_contract_version smallint
    not null default 1;

alter table public.visits
  drop constraint if exists visits_recipe_payload_contract_version_check,
  add constraint visits_recipe_payload_contract_version_check
    check (recipe_payload_contract_version in (1, 2));

-- The session migration intentionally replaced table-level INSERT with an
-- allowlist. Contract-v2 clients must be able to opt into the new safe path.
grant insert (recipe_payload_contract_version)
  on table public.visits to authenticated;

create table if not exists private.visit_recipe_payload_staging (
  visit_id uuid primary key,
  user_id uuid not null,
  brew_details jsonb not null default '{}'::jsonb,
  brew_method text,
  equipment text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '24 hours'),
  constraint visit_recipe_payload_staging_object_check
    check (jsonb_typeof(brew_details) = 'object'),
  constraint visit_recipe_payload_staging_size_check
    check (octet_length(brew_details::text) <= 200000),
  constraint visit_recipe_payload_staging_method_size_check
    check (brew_method is null or char_length(brew_method) <= 500),
  constraint visit_recipe_payload_staging_equipment_size_check
    check (equipment is null or char_length(equipment) <= 500)
);

alter table private.visit_recipe_payload_staging enable row level security;
alter table private.visit_recipe_payload_staging force row level security;
revoke all on table private.visit_recipe_payload_staging
  from public, anon, authenticated;

create index if not exists visit_recipe_payload_staging_expiry_idx
  on private.visit_recipe_payload_staging (expires_at);

create or replace function public.stage_visit_recipe_payload_v2(
  p_visit_id uuid,
  p_brew_details jsonb,
  p_brew_method text default null,
  p_equipment text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  existing_owner uuid;
  existing_contract smallint;
  normalized_details jsonb := coalesce(p_brew_details, '{}'::jsonb);
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_visit_id is null
     or jsonb_typeof(normalized_details) <> 'object'
     or octet_length(normalized_details::text) > 200000
     or char_length(coalesce(p_brew_method, '')) > 500
     or char_length(coalesce(p_equipment, '')) > 500 then
    raise exception 'invalid staged recipe payload' using errcode = '22023';
  end if;

  delete from private.visit_recipe_payload_staging stage
  where stage.expires_at <= now();

  select visit.user_id, visit.recipe_payload_contract_version
  into existing_owner, existing_contract
  from public.visits visit
  where visit.id = p_visit_id;

  if found then
    if existing_owner <> actor then
      raise exception 'visit identifier is unavailable' using errcode = '42501';
    end if;
    if existing_contract = 2 then
      -- Idempotent retry after the visit insert committed and consumed its
      -- original stage. Never recreate an orphan stage for a completed insert.
      return false;
    end if;
    raise exception 'visit identifier already uses a legacy recipe contract'
      using errcode = '55000';
  end if;

  insert into private.visit_recipe_payload_staging (
    visit_id,
    user_id,
    brew_details,
    brew_method,
    equipment,
    created_at,
    expires_at
  ) values (
    p_visit_id,
    actor,
    normalized_details,
    nullif(btrim(p_brew_method), ''),
    nullif(btrim(p_equipment), ''),
    now(),
    now() + interval '24 hours'
  )
  on conflict (visit_id) do update
    set brew_details = excluded.brew_details,
        brew_method = excluded.brew_method,
        equipment = excluded.equipment,
        created_at = excluded.created_at,
        expires_at = excluded.expires_at
    where private.visit_recipe_payload_staging.user_id = actor;

  if not found then
    raise exception 'visit identifier is unavailable' using errcode = '42501';
  end if;
  return true;
end;
$$;

revoke all on function public.stage_visit_recipe_payload_v2(uuid, jsonb, text, text)
  from public, anon, authenticated;
grant execute on function public.stage_visit_recipe_payload_v2(uuid, jsonb, text, text)
  to authenticated;

create or replace function public.materialize_visit_recipe_version(p_visit_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.visits%rowtype;
  staged private.visit_recipe_payload_staging%rowtype;
  full_brew_details jsonb;
  full_brew_method text;
  full_equipment text;
  identity_id uuid;
  version_id uuid;
  next_version integer;
  recipe_name text;
  version_label text;
begin
  select * into target from public.visits where id = p_visit_id for update;
  if not found then
    return null;
  end if;
  if target.recipe_version_id is not null then
    delete from private.visit_recipe_payload_staging stage
    where stage.visit_id = target.id and stage.user_id = target.user_id;
    return target.recipe_version_id;
  end if;

  if target.recipe_payload_contract_version = 2 then
    select * into staged
    from private.visit_recipe_payload_staging stage
    where stage.visit_id = target.id
      and stage.user_id = target.user_id
      and stage.expires_at > now()
    for update;
    if not found then
      raise exception 'contract v2 recipe payload was not staged'
        using errcode = '23514';
    end if;
    full_brew_details := staged.brew_details;
    full_brew_method := staged.brew_method;
    full_equipment := staged.equipment;
  else
    full_brew_details := coalesce(target.brew_details, '{}'::jsonb);
    full_brew_method := target.brew_method;
    full_equipment := target.equipment;
  end if;

  recipe_name := nullif(trim(coalesce(full_brew_details ->> 'recipeName', '')), '');
  if lower(coalesce(target.context_type, '')) <> 'recipe' and recipe_name is null then
    return null;
  end if;
  recipe_name := coalesce(
    recipe_name,
    nullif(trim(target.drink_subtype), ''),
    'Saved recipe'
  );
  version_label := nullif(
    trim(coalesce(full_brew_details ->> 'recipeVersion', '')),
    ''
  );

  begin
    identity_id := nullif(full_brew_details ->> 'recipeIdentityID', '')::uuid;
  exception when invalid_text_representation then
    identity_id := null;
  end;

  if identity_id is not null and exists (
    select 1 from public.recipe_identities identity
    where identity.id = identity_id and identity.user_id <> target.user_id
  ) then
    identity_id := null;
  end if;
  identity_id := coalesce(identity_id, gen_random_uuid());

  if target.recipe_source_kind = 'adapted' and not exists (
    select 1
    from public.recipe_versions source_version
    join public.recipe_identities source_identity
      on source_identity.id = source_version.recipe_identity_id
    where source_version.id = target.source_recipe_version_id
      and not private.blocked_between(target.user_id, source_identity.user_id)
      and (
        source_identity.user_id = target.user_id
        or (
          source_version.visibility = 'everyone'
          and source_version.source_kind in ('original', 'adapted')
          and source_version.redistribution_allowed
        )
      )
  ) then
    raise exception 'source recipe is unavailable for adaptation' using errcode = '42501';
  end if;

  insert into public.recipe_identities (id, user_id, name)
  values (identity_id, target.user_id, recipe_name)
  on conflict (id) do update
    set name = excluded.name, updated_at = now()
    where public.recipe_identities.user_id = excluded.user_id;

  select coalesce(max(version_number), 0) + 1
  into next_version
  from public.recipe_versions
  where recipe_identity_id = identity_id;

  insert into public.recipe_versions (
    recipe_identity_id,
    version_number,
    version_label,
    brew_details,
    brew_method,
    equipment,
    source_visit_id,
    visibility,
    source_kind,
    redistribution_allowed,
    source_recipe_version_id,
    public_reuse_acknowledged_at
  ) values (
    identity_id,
    next_version,
    version_label,
    full_brew_details,
    full_brew_method,
    full_equipment,
    target.id,
    target.recipe_visibility,
    target.recipe_source_kind,
    target.recipe_redistribution_allowed,
    target.source_recipe_version_id,
    target.recipe_public_reuse_acknowledged_at
  )
  returning id into version_id;

  if target.recipe_payload_contract_version = 2 then
    update public.visits
    set recipe_version_id = version_id,
        brew_method = null,
        equipment = null,
        brew_details = jsonb_strip_nulls(jsonb_build_object(
          'recipeName', recipe_name,
          'recipeVersion', version_label
        )),
        recipe_visibility = 'private',
        recipe_source_kind = 'unspecified',
        recipe_redistribution_allowed = false,
        source_recipe_version_id = null,
        recipe_public_reuse_acknowledged_at = null
    where id = target.id;
  else
    update public.visits
    set recipe_version_id = version_id,
        brew_details = jsonb_set(
          full_brew_details,
          '{recipeIdentityID}',
          to_jsonb(identity_id::text),
          true
        )
    where id = target.id;
  end if;

  delete from private.visit_recipe_payload_staging stage
  where stage.visit_id = target.id and stage.user_id = target.user_id;
  return version_id;
end;
$$;

revoke all on function public.materialize_visit_recipe_version(uuid)
  from public, anon, authenticated;

create or replace function private.protect_v2_visit_recipe_payload()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.recipe_payload_contract_version = 2
     or new.recipe_payload_contract_version = 2 then
    new.recipe_payload_contract_version := 2;
    new.brew_method := null;
    new.equipment := null;
    new.brew_details := jsonb_strip_nulls(jsonb_build_object(
      'recipeName', coalesce(
        new.brew_details -> 'recipeName',
        old.brew_details -> 'recipeName'
      ),
      'recipeVersion', coalesce(
        new.brew_details -> 'recipeVersion',
        old.brew_details -> 'recipeVersion'
      )
    ));
    new.recipe_visibility := old.recipe_visibility;
    new.recipe_source_kind := 'unspecified';
    new.recipe_redistribution_allowed := false;
    new.source_recipe_version_id := null;
    new.recipe_public_reuse_acknowledged_at := null;
  end if;
  return new;
end;
$$;

drop trigger if exists protect_v2_visit_recipe_payload_before_update
  on public.visits;
create trigger protect_v2_visit_recipe_payload_before_update
before update of
  recipe_payload_contract_version,
  brew_method,
  equipment,
  brew_details,
  recipe_visibility,
  recipe_source_kind,
  recipe_redistribution_allowed,
  source_recipe_version_id,
  recipe_public_reuse_acknowledged_at
on public.visits
for each row execute function private.protect_v2_visit_recipe_payload();

revoke all on function private.protect_v2_visit_recipe_payload()
  from public, anon, authenticated;

comment on column public.visits.recipe_payload_contract_version is
  'Contract 2 means the visit row contains display-only recipe metadata; full instructions live only in recipe_versions.';
comment on function public.stage_visit_recipe_payload_v2(uuid, jsonb, text, text) is
  'Owner-bound, expiring staging for a single contract-v2 visit insert. Materialization consumes it transactionally.';

-- Cut direct social reads over to an explicit safe surface. Historical bytes
-- remain untouched in visits, but neither old nor new clients can select raw
-- recipe instructions or provenance after this migration. Authorized recipe
-- reads use get_recipe_projection_for_visit_v1 exclusively.
revoke select on table public.visits from anon, authenticated;
grant select (
  id,
  user_id,
  cafe_id,
  drink_type,
  drink_type_custom,
  drink_subtype,
  caption,
  visibility,
  upload_state,
  ratings,
  category_scores,
  overall_score,
  poster_photo_url,
  context_type,
  location_name,
  city_state,
  recipe_version_id,
  cafe_session_id,
  cafe_session_order,
  cafe_session_role,
  created_at
) on table public.visits to anon, authenticated;

comment on table private.visit_recipe_payload_staging is
  'Unexposed owner-bound staging consumed transactionally by recipe materialization; direct app-role access is forbidden.';

commit;
