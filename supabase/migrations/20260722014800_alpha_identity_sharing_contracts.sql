-- Alpha identity and shared-memory contracts.
--
-- This migration is intentionally additive. Existing recipe payloads, tags,
-- visits, and taste evidence are preserved in place. New public reads go
-- through allowlisted projections; no historical JSON is scrubbed here.

begin;

-- ---------------------------------------------------------------------------
-- Independent recipe-version visibility and reusable-source rights
-- ---------------------------------------------------------------------------

alter table public.recipe_versions
  add column if not exists visibility text not null default 'private',
  add column if not exists brew_method text,
  add column if not exists equipment text,
  add column if not exists source_kind text not null default 'unspecified',
  add column if not exists redistribution_allowed boolean not null default false,
  add column if not exists source_recipe_version_id uuid
    references public.recipe_versions(id) on delete set null,
  add column if not exists public_reuse_acknowledged_at timestamptz;

alter table public.visits
  add column if not exists recipe_visibility text not null default 'private',
  add column if not exists recipe_source_kind text not null default 'unspecified',
  add column if not exists recipe_redistribution_allowed boolean not null default false,
  add column if not exists source_recipe_version_id uuid
    references public.recipe_versions(id) on delete set null,
  add column if not exists recipe_public_reuse_acknowledged_at timestamptz;

alter table public.recipe_versions
  drop constraint if exists recipe_versions_visibility_check,
  add constraint recipe_versions_visibility_check
    check (visibility in ('private', 'friends', 'everyone')),
  drop constraint if exists recipe_versions_source_kind_check,
  add constraint recipe_versions_source_kind_check
    check (source_kind in ('original', 'adapted', 'purchased', 'external', 'unspecified')),
  drop constraint if exists recipe_versions_adapted_source_check,
  add constraint recipe_versions_adapted_source_check
    check (source_kind = 'adapted' or source_recipe_version_id is null),
  drop constraint if exists recipe_versions_everyone_rights_check,
  add constraint recipe_versions_everyone_rights_check check (
    visibility <> 'everyone'
    or (
      source_kind in ('original', 'adapted')
      and redistribution_allowed
      and public_reuse_acknowledged_at is not null
    )
  );

alter table public.visits
  drop constraint if exists visits_recipe_visibility_check,
  add constraint visits_recipe_visibility_check
    check (recipe_visibility in ('private', 'friends', 'everyone')),
  drop constraint if exists visits_recipe_source_kind_check,
  add constraint visits_recipe_source_kind_check
    check (recipe_source_kind in ('original', 'adapted', 'purchased', 'external', 'unspecified')),
  drop constraint if exists visits_recipe_adapted_source_check,
  add constraint visits_recipe_adapted_source_check
    check (recipe_source_kind = 'adapted' or source_recipe_version_id is null),
  drop constraint if exists visits_recipe_everyone_rights_check,
  add constraint visits_recipe_everyone_rights_check check (
    recipe_visibility <> 'everyone'
    or (
      recipe_source_kind in ('original', 'adapted')
      and recipe_redistribution_allowed
      and recipe_public_reuse_acknowledged_at is not null
    )
  );

create index if not exists recipe_versions_visibility_created_idx
  on public.recipe_versions (visibility, created_at desc, id);
create index if not exists recipe_versions_source_version_idx
  on public.recipe_versions (source_recipe_version_id)
  where source_recipe_version_id is not null;

create or replace function public.materialize_visit_recipe_version(p_visit_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.visits%rowtype;
  identity_id uuid;
  version_id uuid;
  next_version integer;
  recipe_name text;
  version_label text;
begin
  select * into target from public.visits where id = p_visit_id for update;
  if not found or target.recipe_version_id is not null then
    return target.recipe_version_id;
  end if;

  recipe_name := nullif(trim(coalesce(target.brew_details ->> 'recipeName', '')), '');
  if lower(coalesce(target.context_type, '')) <> 'recipe' and recipe_name is null then
    return null;
  end if;
  recipe_name := coalesce(recipe_name, nullif(trim(target.drink_subtype), ''), 'Saved recipe');
  version_label := nullif(trim(coalesce(target.brew_details ->> 'recipeVersion', '')), '');

  begin
    identity_id := nullif(target.brew_details ->> 'recipeIdentityID', '')::uuid;
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
    target.brew_details,
    target.brew_method,
    target.equipment,
    target.id,
    target.recipe_visibility,
    target.recipe_source_kind,
    target.recipe_redistribution_allowed,
    target.source_recipe_version_id,
    target.recipe_public_reuse_acknowledged_at
  )
  returning id into version_id;

  update public.visits
  set recipe_version_id = version_id,
      brew_details = jsonb_set(
        brew_details,
        '{recipeIdentityID}',
        to_jsonb(identity_id::text),
        true
      )
  where id = target.id;

  return version_id;
end;
$$;

revoke all on function public.materialize_visit_recipe_version(uuid)
  from public, anon, authenticated;

create or replace function private.can_project_recipe_version_as(
  p_version_id uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not null and exists (
    select 1
    from public.recipe_versions version
    join public.recipe_identities identity
      on identity.id = version.recipe_identity_id
    where version.id = p_version_id
      and not private.blocked_between(p_viewer, identity.user_id)
      and (
        identity.user_id = p_viewer
        or version.visibility = 'everyone'
        or (
          version.visibility = 'friends'
          and private.confirmed_friends(p_viewer, identity.user_id)
        )
        or exists (
          select 1
          from public.trusted_recommendations recommendation
          where recommendation.target_kind = 'recipe'
            and recommendation.target_recipe_version_id = version.id
            and recommendation.recipient_id = p_viewer
            and recommendation.status <> 'dismissed'
            and not private.blocked_between(
              recommendation.sender_id,
              recommendation.recipient_id
            )
        )
      )
  );
$$;

revoke all on function private.can_project_recipe_version_as(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.get_recipe_projection_v1(p_recipe_version_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target record;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select
    version.id,
    version.recipe_identity_id,
    version.version_number,
    version.version_label,
    version.brew_details,
    coalesce(version.brew_method, source_visit.brew_method) brew_method,
    coalesce(version.equipment, source_visit.equipment) equipment,
    version.source_visit_id,
    version.visibility,
    version.source_kind,
    version.redistribution_allowed,
    version.source_recipe_version_id,
    version.created_at,
    identity.user_id owner_id,
    identity.name recipe_name,
    profile.display_name,
    profile.username,
    profile.avatar_url
  into target
  from public.recipe_versions version
  join public.recipe_identities identity
    on identity.id = version.recipe_identity_id
  join public.users profile on profile.id = identity.user_id
  left join public.visits source_visit on source_visit.id = version.source_visit_id
  where version.id = p_recipe_version_id;

  if not found
     or not private.can_project_recipe_version_as(p_recipe_version_id, actor) then
    return null;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'recipe_identity_id', target.recipe_identity_id,
    'recipe_version_id', target.id,
    'recipe_name', target.recipe_name,
    'version_number', target.version_number,
    'version_label', target.version_label,
    'visibility', target.visibility,
    'source_kind', target.source_kind,
    'source_recipe_version_id', case
      when target.source_recipe_version_id is null
        or private.can_project_recipe_version_as(target.source_recipe_version_id, actor)
      then target.source_recipe_version_id
    end,
    'owner', jsonb_build_object(
      'id', target.owner_id,
      'display_name', target.display_name,
      'username', target.username,
      'avatar_url', target.avatar_url
    ),
    'brew_method', target.brew_method,
    'equipment', target.equipment,
    'brew_details', jsonb_strip_nulls(jsonb_build_object(
      'beans', target.brew_details -> 'beans',
      'doseGrams', target.brew_details -> 'doseGrams',
      'yieldGrams', target.brew_details -> 'yieldGrams',
      'brewTimeSeconds', target.brew_details -> 'brewTimeSeconds',
      'beanOrigin', target.brew_details -> 'beanOrigin',
      'roastLevel', target.brew_details -> 'roastLevel',
      'grindSetting', target.brew_details -> 'grindSetting',
      'waterTemperatureCelsius', target.brew_details -> 'waterTemperatureCelsius',
      'waterNotes', target.brew_details -> 'waterNotes',
      'recipeName', target.brew_details -> 'recipeName',
      'recipeVersion', target.brew_details -> 'recipeVersion',
      'steps', target.brew_details -> 'steps',
      'additions', target.brew_details -> 'additions',
      'servingVolumeMilliliters', target.brew_details -> 'servingVolumeMilliliters',
      'espressoShotCount', target.brew_details -> 'espressoShotCount'
    )),
    'can_save_and_adapt',
      target.visibility = 'everyone'
      and target.source_kind in ('original', 'adapted')
      and target.redistribution_allowed,
    'created_at', target.created_at
  ));
end;
$$;

create or replace function public.get_recipe_projection_for_visit_v1(p_visit_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_version uuid;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_view_visit_as(p_visit_id, actor) then
    return null;
  end if;

  select recipe_version_id into target_version
  from public.visits
  where id = p_visit_id;

  if target_version is null then
    return null;
  end if;
  return public.get_recipe_projection_v1(target_version);
end;
$$;

create or replace function public.set_recipe_visibility_v1(
  p_recipe_version_id uuid,
  p_visibility text,
  p_acknowledges_public_reuse boolean default false
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_visibility text := lower(btrim(coalesce(p_visibility, '')));
  target record;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if normalized_visibility not in ('private', 'friends', 'everyone') then
    raise exception 'invalid recipe visibility' using errcode = '22023';
  end if;

  select version.source_kind, version.redistribution_allowed
  into target
  from public.recipe_versions version
  join public.recipe_identities identity
    on identity.id = version.recipe_identity_id
  where version.id = p_recipe_version_id
    and identity.user_id = actor
  for update of version;

  if not found then
    raise exception 'recipe ownership required' using errcode = '42501';
  end if;
  if normalized_visibility = 'everyone' and (
    target.source_kind not in ('original', 'adapted')
    or not target.redistribution_allowed
    or not coalesce(p_acknowledges_public_reuse, false)
  ) then
    raise exception 'public recipes require reusable source rights and acknowledgment'
      using errcode = '42501';
  end if;

  update public.recipe_versions
  set visibility = normalized_visibility,
      public_reuse_acknowledged_at = case
        when normalized_visibility = 'everyone' then now()
        else public_reuse_acknowledged_at
      end
  where id = p_recipe_version_id;

  update public.visits
  set recipe_visibility = normalized_visibility,
      recipe_public_reuse_acknowledged_at = case
        when normalized_visibility = 'everyone' then now()
        else recipe_public_reuse_acknowledged_at
      end
  where recipe_version_id = p_recipe_version_id;

  return normalized_visibility;
end;
$$;

create or replace function public.configure_recipe_source_rights_v1(
  p_recipe_version_id uuid,
  p_source_kind text,
  p_redistribution_allowed boolean default false,
  p_source_recipe_version_id uuid default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_source_kind text := lower(btrim(coalesce(p_source_kind, '')));
  target_visibility text;
  target_source_kind text;
  target_source_recipe_version_id uuid;
  effective_redistribution boolean := coalesce(p_redistribution_allowed, false);
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if normalized_source_kind not in (
    'original', 'adapted', 'purchased', 'external', 'unspecified'
  ) then
    raise exception 'invalid recipe source kind' using errcode = '22023';
  end if;
  if normalized_source_kind = 'adapted' and p_source_recipe_version_id is null then
    raise exception 'adapted recipes require an immutable source version'
      using errcode = '22023';
  end if;
  if normalized_source_kind <> 'adapted' and p_source_recipe_version_id is not null then
    raise exception 'only adapted recipes may reference a source version'
      using errcode = '22023';
  end if;
  if normalized_source_kind in ('purchased', 'external', 'unspecified') then
    effective_redistribution := false;
  end if;

  select
    version.visibility,
    version.source_kind,
    version.source_recipe_version_id
  into target_visibility, target_source_kind, target_source_recipe_version_id
  from public.recipe_versions version
  join public.recipe_identities identity
    on identity.id = version.recipe_identity_id
  where version.id = p_recipe_version_id
    and identity.user_id = actor
  for update of version;

  if not found then
    raise exception 'recipe ownership required' using errcode = '42501';
  end if;
  if target_source_kind <> 'unspecified' and (
    target_source_kind <> normalized_source_kind
    or target_source_recipe_version_id is distinct from p_source_recipe_version_id
  ) then
    raise exception 'immutable recipe source provenance cannot be replaced'
      using errcode = '55000';
  end if;
  if p_source_recipe_version_id = p_recipe_version_id then
    raise exception 'a recipe version cannot source itself' using errcode = '22023';
  end if;
  if normalized_source_kind = 'adapted' and exists (
    with recursive source_chain(id) as (
      select p_source_recipe_version_id
      union
      select ancestor.source_recipe_version_id
      from public.recipe_versions ancestor
      join source_chain on source_chain.id = ancestor.id
      where ancestor.source_recipe_version_id is not null
    )
    select 1 from source_chain where id = p_recipe_version_id
  ) then
    raise exception 'recipe source lineage cannot contain a cycle' using errcode = '22023';
  end if;
  if normalized_source_kind = 'adapted' and not exists (
    select 1
    from public.recipe_versions source_version
    join public.recipe_identities source_identity
      on source_identity.id = source_version.recipe_identity_id
    where source_version.id = p_source_recipe_version_id
      and not private.blocked_between(actor, source_identity.user_id)
      and (
        source_identity.user_id = actor
        or (
          source_version.visibility = 'everyone'
          and source_version.source_kind in ('original', 'adapted')
          and source_version.redistribution_allowed
        )
      )
  ) then
    raise exception 'source recipe is unavailable for adaptation' using errcode = '42501';
  end if;
  if target_visibility = 'everyone' and (
    normalized_source_kind not in ('original', 'adapted')
    or not effective_redistribution
  ) then
    raise exception 'an Everyone recipe must retain reusable source rights'
      using errcode = '42501';
  end if;

  update public.recipe_versions
  set source_kind = normalized_source_kind,
      redistribution_allowed = effective_redistribution,
      source_recipe_version_id = p_source_recipe_version_id
  where id = p_recipe_version_id;

  update public.visits
  set recipe_source_kind = normalized_source_kind,
      recipe_redistribution_allowed = effective_redistribution,
      source_recipe_version_id = p_source_recipe_version_id
  where recipe_version_id = p_recipe_version_id;

  return normalized_source_kind;
end;
$$;

create or replace function public.save_recipe_adaptation_v1(
  p_source_recipe_version_id uuid,
  p_name text,
  p_version_label text default 'Adapted'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  source record;
  identity_id uuid;
  version_id uuid;
  clean_name text := nullif(btrim(coalesce(p_name, '')), '');
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if clean_name is null or char_length(clean_name) > 120 then
    raise exception 'recipe name must contain 1 to 120 characters' using errcode = '22023';
  end if;

  select
    version.brew_details,
    coalesce(version.brew_method, source_visit.brew_method) brew_method,
    coalesce(version.equipment, source_visit.equipment) equipment,
    version.visibility,
    version.source_kind,
    version.redistribution_allowed,
    identity.user_id owner_id
  into source
  from public.recipe_versions version
  join public.recipe_identities identity
    on identity.id = version.recipe_identity_id
  left join public.visits source_visit on source_visit.id = version.source_visit_id
  where version.id = p_source_recipe_version_id;

  if not found
     or private.blocked_between(actor, source.owner_id)
     or not (
       source.owner_id = actor
       or (
         source.visibility = 'everyone'
         and source.source_kind in ('original', 'adapted')
         and source.redistribution_allowed
       )
     ) then
    raise exception 'recipe is not available to save and adapt' using errcode = '42501';
  end if;

  insert into public.recipe_identities (user_id, name)
  values (actor, clean_name)
  returning id into identity_id;

  insert into public.recipe_versions (
    recipe_identity_id,
    version_number,
    version_label,
    brew_details,
    brew_method,
    equipment,
    visibility,
    source_kind,
    redistribution_allowed,
    source_recipe_version_id
  ) values (
    identity_id,
    1,
    nullif(btrim(coalesce(p_version_label, '')), ''),
    jsonb_strip_nulls(jsonb_build_object(
      'beans', source.brew_details -> 'beans',
      'doseGrams', source.brew_details -> 'doseGrams',
      'yieldGrams', source.brew_details -> 'yieldGrams',
      'brewTimeSeconds', source.brew_details -> 'brewTimeSeconds',
      'beanOrigin', source.brew_details -> 'beanOrigin',
      'roastLevel', source.brew_details -> 'roastLevel',
      'grindSetting', source.brew_details -> 'grindSetting',
      'waterTemperatureCelsius', source.brew_details -> 'waterTemperatureCelsius',
      'waterNotes', source.brew_details -> 'waterNotes',
      'recipeName', source.brew_details -> 'recipeName',
      'recipeVersion', source.brew_details -> 'recipeVersion',
      'steps', source.brew_details -> 'steps',
      'additions', source.brew_details -> 'additions',
      'servingVolumeMilliliters', source.brew_details -> 'servingVolumeMilliliters',
      'espressoShotCount', source.brew_details -> 'espressoShotCount'
    )),
    source.brew_method,
    source.equipment,
    'private',
    'adapted',
    true,
    p_source_recipe_version_id
  )
  returning id into version_id;

  return version_id;
end;
$$;

revoke all on function public.get_recipe_projection_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.get_recipe_projection_for_visit_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.set_recipe_visibility_v1(uuid, text, boolean)
  from public, anon, authenticated;
revoke all on function public.configure_recipe_source_rights_v1(uuid, text, boolean, uuid)
  from public, anon, authenticated;
revoke all on function public.save_recipe_adaptation_v1(uuid, text, text)
  from public, anon, authenticated;
grant execute on function public.get_recipe_projection_v1(uuid) to authenticated;
grant execute on function public.get_recipe_projection_for_visit_v1(uuid) to authenticated;
grant execute on function public.set_recipe_visibility_v1(uuid, text, boolean) to authenticated;
grant execute on function public.configure_recipe_source_rights_v1(uuid, text, boolean, uuid)
  to authenticated;
grant execute on function public.save_recipe_adaptation_v1(uuid, text, text) to authenticated;

comment on function public.get_recipe_projection_v1(uuid) is
  'Caller-bound, allowlisted recipe projection. Never returns arbitrary brew_details keys.';
comment on function public.save_recipe_adaptation_v1(uuid, text, text) is
  'Creates a private attributed copy only when the exact immutable source version grants reuse.';
comment on column public.recipe_versions.source_recipe_version_id is
  'Immutable adaptation source when still present; may become null if the source owner deletes their account or recipe.';

-- ---------------------------------------------------------------------------
-- Taste Passport: Everyone by default, owner-configurable, evidence-safe
-- ---------------------------------------------------------------------------

alter table public.users
  add column if not exists taste_passport_visibility text not null default 'everyone';

alter table public.users
  drop constraint if exists users_taste_passport_visibility_check,
  add constraint users_taste_passport_visibility_check
    check (taste_passport_visibility in ('private', 'friends', 'everyone'));

create or replace function private.can_view_taste_passport_as(
  p_owner uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not null
    and not private.blocked_between(p_viewer, p_owner)
    and exists (
      select 1
      from public.users owner
      where owner.id = p_owner
        and (
          owner.id = p_viewer
          or owner.taste_passport_visibility = 'everyone'
          or (
            owner.taste_passport_visibility = 'friends'
            and private.confirmed_friends(p_viewer, owner.id)
          )
        )
    );
$$;

revoke all on function private.can_view_taste_passport_as(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.get_taste_passport_visibility_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  owner_visibility text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select owner.taste_passport_visibility
  into owner_visibility
  from public.users owner
  where owner.id = actor;

  if not found then
    raise exception 'profile not found' using errcode = 'P0002';
  end if;

  return jsonb_build_object(
    'user_id', actor,
    'visibility', owner_visibility
  );
end;
$$;

create or replace function public.set_taste_passport_visibility_v1(
  p_visibility text,
  p_account_id uuid
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_visibility text := lower(btrim(coalesce(p_visibility, '')));
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_account_id is null or p_account_id <> actor then
    raise exception 'account scope mismatch' using errcode = '42501';
  end if;
  if normalized_visibility not in ('private', 'friends', 'everyone') then
    raise exception 'invalid Taste Passport visibility' using errcode = '22023';
  end if;

  update public.users
  set taste_passport_visibility = normalized_visibility
  where id = actor;

  if not found then
    raise exception 'profile not found' using errcode = 'P0002';
  end if;
  return normalized_visibility;
end;
$$;

create or replace function public.get_taste_passport_v1(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  owner_visibility text;
  order_attribute text;
  order_label text;
  order_support integer := 0;
  order_confidence numeric := 0;
  sensory_attribute text;
  sensory_label text;
  sensory_support integer := 0;
  sensory_confidence numeric := 0;
  complete_visits integer := 0;
  home_visits integer := 0;
  cafe_visits integer := 0;
  recipe_visits integer := 0;
  distinct_cafes integer := 0;
  repeated_cafe_visits integer := 0;
  ritual_label text;
  confidence_band text;
  description text;
  passport_is_forming boolean;
  latest_signal_at timestamptz;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_view_taste_passport_as(p_user_id, actor) then
    return null;
  end if;

  select taste_passport_visibility into owner_visibility
  from public.users where id = p_user_id;

  select
    signal.attribute,
    coalesce(nullif(btrim(signal.owner_label), ''), initcap(replace(signal.attribute, '_', ' '))),
    signal.support_count,
    signal.confidence
  into order_attribute, order_label, order_support, order_confidence
  from public.taste_signals signal
  where signal.user_id = p_user_id
    and signal.signal_type = 'order_preference'
    and signal.owner_state in ('active', 'corrected')
  order by (signal.owner_state = 'corrected') desc,
           signal.support_count desc,
           signal.confidence desc,
           signal.updated_at desc,
           signal.id
  limit 1;

  select
    signal.attribute,
    coalesce(nullif(btrim(signal.owner_label), ''), initcap(replace(signal.attribute, '_', ' '))),
    signal.support_count,
    signal.confidence
  into sensory_attribute, sensory_label, sensory_support, sensory_confidence
  from public.taste_signals signal
  where signal.user_id = p_user_id
    and signal.signal_type = 'sensory_evaluation'
    and signal.owner_state in ('active', 'corrected')
  order by (signal.owner_state = 'corrected') desc,
           signal.support_count desc,
           signal.confidence desc,
           signal.updated_at desc,
           signal.id
  limit 1;

  select
    count(*)::integer,
    count(*) filter (where lower(coalesce(visit.context_type, '')) = 'home')::integer,
    count(*) filter (where lower(coalesce(visit.context_type, 'cafe')) = 'cafe')::integer,
    count(*) filter (where lower(coalesce(visit.context_type, '')) = 'recipe')::integer,
    count(distinct visit.cafe_id) filter (where visit.cafe_id is not null)::integer
  into complete_visits, home_visits, cafe_visits, recipe_visits, distinct_cafes
  from public.visits visit
  where visit.user_id = p_user_id
    and visit.upload_state = 'complete';

  select coalesce(max(grouped.visit_count), 0)::integer
  into repeated_cafe_visits
  from (
    select count(*) visit_count
    from public.visits visit
    where visit.user_id = p_user_id
      and visit.upload_state = 'complete'
      and visit.cafe_id is not null
    group by visit.cafe_id
  ) grouped;

  select max(signal.updated_at) into latest_signal_at
  from public.taste_signals signal
  where signal.user_id = p_user_id
    and signal.owner_state in ('active', 'corrected');

  ritual_label := case
    when recipe_visits >= 2 then 'Recipe Builder'
    when home_visits > cafe_visits and home_visits >= 2 then 'Home Dialer'
    when repeated_cafe_visits >= 3 then 'Neighborhood Regular'
    when distinct_cafes >= 3 then 'Cafe Explorer'
    when home_visits > 0 and cafe_visits > 0 then 'Ritual Mixer'
    when cafe_visits > 0 then 'Cafe Explorer'
    else 'Memory Keeper'
  end;

  confidence_band := case
    when greatest(coalesce(order_confidence, 0), coalesce(sensory_confidence, 0)) >= 0.75
      then 'established'
    when greatest(coalesce(order_confidence, 0), coalesce(sensory_confidence, 0)) >= 0.40
      then 'growing'
    else 'emerging'
  end;

  description := case
    when order_attribute is not null and sensory_attribute is not null then
      'Often reaches for ' || lower(order_label) ||
      ' and tends to notice ' || lower(sensory_label) || '.'
    when order_attribute is not null then
      'Often reaches for ' || lower(order_label) || '. More sensory detail is still forming.'
    when sensory_attribute is not null then
      'Tends to notice ' || lower(sensory_label) || '. Order patterns are still forming.'
    else
      'This Taste Passport is forming with each logged sip.'
  end;

  passport_is_forming := greatest(
    coalesce(order_support, 0),
    coalesce(sensory_support, 0)
  ) < 3;

  if passport_is_forming then
    order_label := 'Taste Forming';
    sensory_label := 'Lens Forming';
    ritual_label := 'Ritual Forming';
    confidence_band := 'emerging';
    description := 'This Taste Passport is forming with each logged sip.';
    latest_signal_at := null;
  end if;

  return jsonb_build_object(
    'user_id', p_user_id,
    'visibility', owner_visibility,
    'descriptors', jsonb_build_array(
      jsonb_build_object(
        'kind', 'order_preference',
        'label', coalesce(order_label, 'Taste Forming')
      ),
      jsonb_build_object(
        'kind', 'sensory_lens',
        'label', coalesce(sensory_label, 'Lens Forming')
      ),
      jsonb_build_object('kind', 'ritual', 'label', ritual_label)
    ),
    'description', description,
    'is_forming', passport_is_forming,
    'confidence_band', confidence_band,
    'calculation_version', 'taste-passport-1',
    'updated_at', latest_signal_at
  );
end;
$$;

revoke all on function public.get_taste_passport_visibility_v1()
  from public, anon, authenticated;
revoke all on function public.set_taste_passport_visibility_v1(text, uuid)
  from public, anon, authenticated;
revoke all on function public.get_taste_passport_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.get_taste_passport_visibility_v1() to authenticated;
grant execute on function public.set_taste_passport_visibility_v1(text, uuid) to authenticated;
grant execute on function public.get_taste_passport_v1(uuid) to authenticated;

comment on column public.users.taste_passport_visibility is
  'Taste Passport audience. Defaults to everyone; raw taste evidence remains owner-only.';
comment on function public.get_taste_passport_visibility_v1() is
  'Returns only the authenticated owner identity and current Taste Passport audience.';
comment on function public.set_taste_passport_visibility_v1(text, uuid) is
  'Updates the authenticated owner only when the caller supplies the same expected account identity.';
comment on function public.get_taste_passport_v1(uuid) is
  'Returns three evidence-derived descriptors without evidence visit IDs, exact support counts, private notes, or low-evidence provisional traits.';

-- ---------------------------------------------------------------------------
-- Ordinary post tags (no consent, no audience expansion)
-- ---------------------------------------------------------------------------

create or replace function public.set_visit_tags_v1(
  p_visit_id uuid,
  p_tagged_user_ids uuid[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  tagged_user_id uuid;
  distinct_ids uuid[];
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id and visit.user_id = actor
  ) then
    raise exception 'visit ownership required' using errcode = '42501';
  end if;

  select coalesce(array_agg(distinct requested_id), '{}'::uuid[])
  into distinct_ids
  from unnest(coalesce(p_tagged_user_ids, '{}'::uuid[])) requested_id
  where requested_id is not null and requested_id <> actor;

  if cardinality(distinct_ids) > 12 then
    raise exception 'a post can include at most 12 tags' using errcode = '22023';
  end if;

  foreach tagged_user_id in array distinct_ids loop
    if not exists (select 1 from public.users where id = tagged_user_id)
       or private.blocked_between(actor, tagged_user_id) then
      raise exception 'tagged account is unavailable' using errcode = '42501';
    end if;
  end loop;

  delete from public.visit_companions companion
  where companion.visit_id = p_visit_id
    and companion.added_by = actor
    and companion.companion_user_id <> all(distinct_ids);

  insert into public.visit_companions (visit_id, companion_user_id, added_by)
  select p_visit_id, requested_id, actor
  from unnest(distinct_ids) requested_id
  on conflict (visit_id, companion_user_id) do nothing;
end;
$$;

create or replace function public.list_visible_visit_tags_v1(p_visit_id uuid)
returns table (
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  tagged_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    profile.id,
    profile.display_name,
    profile.username,
    profile.avatar_url,
    tag.created_at
  from input
  join public.visit_companions tag on tag.visit_id = p_visit_id
  join public.users profile on profile.id = tag.companion_user_id
  where input.actor is not null
    and private.can_view_visit_as(p_visit_id, input.actor)
    and not private.blocked_between(input.actor, profile.id)
  order by tag.created_at, profile.id;
$$;

create or replace function public.remove_self_visit_tag_v1(p_visit_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  removed_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  delete from public.visit_companions
  where visit_id = p_visit_id and companion_user_id = actor;
  get diagnostics removed_count = row_count;
  return removed_count > 0;
end;
$$;

revoke all on function public.set_visit_tags_v1(uuid, uuid[])
  from public, anon, authenticated;
revoke all on function public.list_visible_visit_tags_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.remove_self_visit_tag_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.set_visit_tags_v1(uuid, uuid[]) to authenticated;
grant execute on function public.list_visible_visit_tags_v1(uuid) to authenticated;
grant execute on function public.remove_self_visit_tag_v1(uuid) to authenticated;

comment on function public.set_visit_tags_v1(uuid, uuid[]) is
  'Ordinary tags require no consent, do not require friendship, and never grant post visibility.';

-- ---------------------------------------------------------------------------
-- Consented shared memories: invitations, membership, and own contributions
-- ---------------------------------------------------------------------------

create table public.shared_memories (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references public.users(id) on delete set null,
  source_visit_id uuid unique references public.visits(id) on delete set null,
  context_type text not null check (
    lower(btrim(context_type)) in ('cafe', 'home', 'elsewhere', 'recipe')
  ),
  cafe_id uuid references public.cafes(id) on delete set null,
  location_label text not null check (char_length(btrim(location_label)) between 1 and 120),
  occurred_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (
    (lower(btrim(context_type)) = 'cafe' and cafe_id is not null)
    or (lower(btrim(context_type)) <> 'cafe' and cafe_id is null)
  )
);

create table public.shared_memory_members (
  id uuid primary key default gen_random_uuid(),
  shared_memory_id uuid not null references public.shared_memories(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  invited_by uuid references public.users(id) on delete set null,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'declined', 'cancelled', 'left')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  left_at timestamptz,
  unique (shared_memory_id, user_id),
  constraint shared_memory_members_status_time_check check (
    (status = 'pending' and responded_at is null and left_at is null)
    or (status = 'accepted' and responded_at is not null and left_at is null)
    or (status in ('declined', 'cancelled') and responded_at is not null and left_at is null)
    or (status = 'left' and responded_at is not null and left_at is not null)
  )
);

create table public.shared_memory_contributions (
  shared_memory_id uuid not null references public.shared_memories(id) on delete cascade,
  visit_id uuid not null unique references public.visits(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (shared_memory_id, visit_id),
  constraint shared_memory_contributions_memory_user_key
    unique (shared_memory_id, user_id)
);

create index shared_memories_creator_created_idx
  on public.shared_memories (created_by, created_at desc, id);
create index shared_memory_members_user_status_idx
  on public.shared_memory_members (user_id, status, created_at desc, id);
create index shared_memory_members_inviter_status_idx
  on public.shared_memory_members (invited_by, status, created_at desc, id);
create index shared_memory_contributions_visit_idx
  on public.shared_memory_contributions (visit_id, shared_memory_id);

create or replace function private.enforce_shared_memory_source_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_visit public.visits%rowtype;
begin
  if new.source_visit_id is null or new.created_by is null then
    return new;
  end if;

  select visit.* into source_visit
  from public.visits visit
  where visit.id = new.source_visit_id;

  if not found or source_visit.user_id <> new.created_by then
    raise exception 'shared MugShot source must belong to its creator'
      using errcode = '23514';
  end if;
  if source_visit.upload_state <> 'complete'
     or source_visit.cafe_session_role = 'secondary' then
    raise exception 'shared MugShot source must be a complete primary post'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create or replace function private.enforce_shared_memory_contribution_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_visit public.visits%rowtype;
  target_memory public.shared_memories%rowtype;
begin
  select * into target_visit
  from public.visits visit
  where visit.id = new.visit_id;
  if not found or target_visit.user_id <> new.user_id then
    raise exception 'shared MugShot contribution must be owned by its participant'
      using errcode = '23514';
  end if;
  if target_visit.upload_state <> 'complete'
     or target_visit.cafe_session_role = 'secondary' then
    raise exception 'shared MugShot contribution must be a complete primary post'
      using errcode = '23514';
  end if;

  select * into target_memory
  from public.shared_memories memory
  where memory.id = new.shared_memory_id;
  if not found then
    raise exception 'shared MugShot not found' using errcode = '23503';
  end if;
  if new.user_id = target_memory.created_by
     and new.visit_id <> target_memory.source_visit_id then
    raise exception 'creator contribution must remain the shared MugShot source'
      using errcode = '23514';
  end if;
  if (case
       when lower(btrim(coalesce(target_visit.context_type, ''))) = 'cafe'
         or (nullif(btrim(target_visit.context_type), '') is null and target_visit.cafe_id is not null)
         then 'cafe'
       when lower(btrim(coalesce(target_visit.context_type, ''))) = 'home' then 'home'
       when lower(btrim(coalesce(target_visit.context_type, ''))) = 'recipe' then 'recipe'
       else 'elsewhere'
     end) <> lower(btrim(target_memory.context_type))
     or (
       lower(btrim(target_memory.context_type)) = 'cafe'
       and target_visit.cafe_id is distinct from target_memory.cafe_id
     ) then
    raise exception 'shared MugShot contribution context does not match'
      using errcode = '23514';
  end if;
  if not exists (
    select 1
    from public.shared_memory_members member
    where member.shared_memory_id = new.shared_memory_id
      and member.user_id = new.user_id
      and member.status = 'accepted'
  ) then
    raise exception 'accepted shared MugShot membership is required'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_shared_memory_source_owner()
  from public, anon, authenticated;
revoke all on function private.enforce_shared_memory_contribution_owner()
  from public, anon, authenticated;

create trigger enforce_shared_memory_source_owner
before insert or update of created_by, source_visit_id
on public.shared_memories
for each row execute function private.enforce_shared_memory_source_owner();

create trigger enforce_shared_memory_contribution_owner
before insert or update of shared_memory_id, visit_id, user_id
on public.shared_memory_contributions
for each row execute function private.enforce_shared_memory_contribution_owner();

alter table public.shared_memories enable row level security;
alter table public.shared_memory_members enable row level security;
alter table public.shared_memory_contributions enable row level security;

revoke all on table public.shared_memories from public, anon, authenticated;
revoke all on table public.shared_memory_members from public, anon, authenticated;
revoke all on table public.shared_memory_contributions from public, anon, authenticated;

-- No shared-memory table is exposed directly through the Data API. Even safe
-- row policies cannot hide source IDs or member columns. Caller-bound
-- projections below are the only authenticated read surface.

create or replace function private.can_view_shared_memory_as(
  p_shared_memory_id uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not null and (
    exists (
      select 1
      from public.shared_memory_members member
      where member.shared_memory_id = p_shared_memory_id
        and member.user_id = p_viewer
        and member.status in ('pending', 'accepted')
    )
    or exists (
      select 1
      from public.shared_memory_contributions contribution
      where contribution.shared_memory_id = p_shared_memory_id
        and private.can_view_visit_as(contribution.visit_id, p_viewer)
        and not private.blocked_between(p_viewer, contribution.user_id)
    )
  );
$$;

revoke all on function private.can_view_shared_memory_as(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.can_view_shared_memory(
  p_shared_memory_id uuid,
  p_viewer uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer = (select auth.uid())
    and private.can_view_shared_memory_as(p_shared_memory_id, p_viewer);
$$;

revoke all on function public.can_view_shared_memory(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.can_view_shared_memory(uuid, uuid) to authenticated;

create policy "Visible shared memories"
  on public.shared_memories for select to authenticated
  using (public.can_view_shared_memory(id, (select auth.uid())));

create policy "Own or managed shared memory memberships"
  on public.shared_memory_members for select to authenticated
  using (
    user_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or exists (
      select 1
      from public.shared_memories memory
      where memory.id = shared_memory_id
        and memory.created_by = (select auth.uid())
    )
  );

create policy "Visible shared memory contributions"
  on public.shared_memory_contributions for select to authenticated
  using (
    public.can_view_visit(visit_id, (select auth.uid()))
    and not public.is_blocked_between(user_id, (select auth.uid()))
  );

create or replace function public.create_shared_memory_invitations_v1(
  p_visit_id uuid,
  p_invitee_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.visits%rowtype;
  memory_id uuid;
  invitee_id uuid;
  distinct_ids uuid[];
  target_location text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select * into target
  from public.visits
  where id = p_visit_id and user_id = actor
  for update;

  if not found then
    raise exception 'visit ownership required' using errcode = '42501';
  end if;
  if target.upload_state <> 'complete' then
    raise exception 'only complete posts can become shared MugShots' using errcode = '22023';
  end if;
  if target.cafe_session_role = 'secondary' then
    raise exception 'only a primary cafe post can become a shared MugShot' using errcode = '22023';
  end if;

  select coalesce(array_agg(distinct requested_id), '{}'::uuid[])
  into distinct_ids
  from unnest(coalesce(p_invitee_ids, '{}'::uuid[])) requested_id
  where requested_id is not null and requested_id <> actor;

  if cardinality(distinct_ids) = 0 then
    raise exception 'a shared MugShot requires at least one invitee' using errcode = '22023';
  end if;
  if cardinality(distinct_ids) > 12 then
    raise exception 'a shared MugShot can invite at most 12 people' using errcode = '22023';
  end if;
  foreach invitee_id in array distinct_ids loop
    if not private.confirmed_friends(actor, invitee_id)
       or not private.can_view_visit_as(target.id, invitee_id) then
      raise exception 'shared MugShot invitations require confirmed friends in the post audience'
        using errcode = '42501';
    end if;
  end loop;

  select left(coalesce(
      nullif(btrim(target.location_name), ''),
      cafe.name,
      case lower(coalesce(target.context_type, ''))
        when 'home' then 'Home'
        when 'recipe' then 'Recipe'
        else 'Shared sip'
      end
    ), 120)
  into target_location
  from (select 1) seed
  left join public.cafes cafe on cafe.id = target.cafe_id;

  insert into public.shared_memories (
    created_by,
    source_visit_id,
    context_type,
    cafe_id,
    location_label,
    occurred_at
  ) values (
    actor,
    target.id,
    case
      when lower(btrim(coalesce(target.context_type, ''))) = 'cafe'
        or (nullif(btrim(target.context_type), '') is null and target.cafe_id is not null)
        then 'Cafe'
      when lower(btrim(coalesce(target.context_type, ''))) = 'home' then 'Home'
      when lower(btrim(coalesce(target.context_type, ''))) = 'recipe' then 'Recipe'
      else 'Elsewhere'
    end,
    case
      when lower(btrim(coalesce(target.context_type, ''))) = 'cafe'
        or (nullif(btrim(target.context_type), '') is null and target.cafe_id is not null)
        then target.cafe_id
    end,
    target_location,
    target.created_at
  )
  on conflict (source_visit_id) do update
    set updated_at = public.shared_memories.updated_at
    where public.shared_memories.created_by = actor
  returning id into memory_id;

  if memory_id is null then
    raise exception 'shared MugShot ownership required' using errcode = '42501';
  end if;

  insert into public.shared_memory_members (
    shared_memory_id, user_id, invited_by, status, responded_at
  ) values (
    memory_id, actor, actor, 'accepted', now()
  )
  on conflict (shared_memory_id, user_id) do update
    set status = 'accepted',
        responded_at = coalesce(public.shared_memory_members.responded_at, now()),
        left_at = null;

  insert into public.shared_memory_contributions (
    shared_memory_id, visit_id, user_id
  ) values (
    memory_id, target.id, actor
  )
  on conflict (shared_memory_id, user_id) do update
    set visit_id = public.shared_memory_contributions.visit_id;

  insert into public.shared_memory_members (
    shared_memory_id, user_id, invited_by, status
  )
  select memory_id, requested_id, actor, 'pending'
  from unnest(distinct_ids) requested_id
  on conflict (shared_memory_id, user_id) do update
    set invited_by = excluded.invited_by,
        status = 'pending',
        created_at = now(),
        responded_at = null,
        left_at = null
    where public.shared_memory_members.status in ('declined', 'cancelled', 'left');

  return memory_id;
end;
$$;

create or replace function public.list_pending_shared_memory_invitations_v1()
returns table (
  invitation_id uuid,
  shared_memory_id uuid,
  inviter_id uuid,
  inviter_display_name text,
  inviter_username text,
  inviter_avatar_url text,
  context_type text,
  cafe_id uuid,
  location_label text,
  occurred_at timestamptz,
  invited_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    member.id,
    memory.id,
    inviter.id,
    inviter.display_name,
    inviter.username,
    inviter.avatar_url,
    memory.context_type,
    memory.cafe_id,
    memory.location_label,
    memory.occurred_at,
    member.created_at
  from input
  join public.shared_memory_members member
    on member.user_id = input.actor and member.status = 'pending'
  join public.shared_memories memory on memory.id = member.shared_memory_id
  join public.users inviter on inviter.id = member.invited_by
  where input.actor is not null
    and not private.blocked_between(input.actor, inviter.id)
  order by member.created_at desc, member.id desc;
$$;

create or replace function public.list_managed_shared_memory_invitations_v1(
  p_shared_memory_id uuid
)
returns table (
  invitation_id uuid,
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  status text,
  invited_at timestamptz,
  responded_at timestamptz,
  left_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    member.id,
    profile.id,
    profile.display_name,
    profile.username,
    profile.avatar_url,
    member.status,
    member.created_at,
    member.responded_at,
    member.left_at
  from input
  join public.shared_memories memory
    on memory.id = p_shared_memory_id
   and memory.created_by = input.actor
  join public.shared_memory_members member
    on member.shared_memory_id = memory.id
   and member.user_id <> input.actor
  join public.users profile on profile.id = member.user_id
  where input.actor is not null
    and not private.blocked_between(input.actor, profile.id)
  order by member.created_at, member.id;
$$;

create or replace function public.list_my_shared_memory_memberships_v1()
returns table (
  membership_id uuid,
  shared_memory_id uuid,
  status text,
  inviter_id uuid,
  inviter_display_name text,
  inviter_username text,
  inviter_avatar_url text,
  relationship_available boolean,
  context_type text,
  cafe_id uuid,
  location_label text,
  occurred_at timestamptz,
  invited_at timestamptz,
  responded_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    member.id,
    memory.id,
    member.status,
    case when not private.blocked_between(input.actor, inviter.id) then inviter.id end,
    case when not private.blocked_between(input.actor, inviter.id) then inviter.display_name end,
    case when not private.blocked_between(input.actor, inviter.id) then inviter.username end,
    case when not private.blocked_between(input.actor, inviter.id) then inviter.avatar_url end,
    not private.blocked_between(input.actor, inviter.id),
    memory.context_type,
    memory.cafe_id,
    memory.location_label,
    memory.occurred_at,
    member.created_at,
    member.responded_at
  from input
  join public.shared_memory_members member
    on member.user_id = input.actor
   and member.status in ('pending', 'accepted')
  join public.shared_memories memory on memory.id = member.shared_memory_id
  left join public.users inviter on inviter.id = member.invited_by
  where input.actor is not null
    and memory.created_by is distinct from input.actor
  order by
    (member.status = 'pending') desc,
    member.created_at desc,
    member.id desc;
$$;

create or replace function public.list_owned_shared_memories_v1()
returns table (
  shared_memory_id uuid,
  source_visit_id uuid,
  context_type text,
  cafe_id uuid,
  location_label text,
  occurred_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    memory.id,
    memory.source_visit_id,
    memory.context_type,
    memory.cafe_id,
    memory.location_label,
    memory.occurred_at,
    memory.created_at,
    memory.updated_at
  from input
  join public.shared_memories memory on memory.created_by = input.actor
  where input.actor is not null
  order by memory.updated_at desc, memory.id desc;
$$;

create or replace function public.respond_shared_memory_invitation_v1(
  p_invitation_id uuid,
  p_accept boolean
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target record;
  next_status text := case when coalesce(p_accept, false) then 'accepted' else 'declined' end;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select
    member.shared_memory_id,
    member.invited_by,
    member.status,
    memory.created_by,
    memory.source_visit_id
  into target
  from public.shared_memory_members member
  join public.shared_memories memory on memory.id = member.shared_memory_id
  where member.id = p_invitation_id and member.user_id = actor
  for update of member;

  if not found or target.status <> 'pending' then
    raise exception 'pending invitation not found' using errcode = 'P0002';
  end if;
  if coalesce(p_accept, false) and (
    private.blocked_between(actor, target.invited_by)
    or not private.confirmed_friends(actor, target.invited_by)
    or not private.can_view_visit_as(target.source_visit_id, actor)
    or target.created_by is distinct from target.invited_by
    or target.source_visit_id is null
    or not exists (
      select 1
      from public.shared_memory_contributions contribution
      where contribution.shared_memory_id = target.shared_memory_id
        and contribution.visit_id = target.source_visit_id
        and contribution.user_id = target.created_by
    )
  ) then
    raise exception 'invitation is unavailable' using errcode = '42501';
  end if;

  update public.shared_memory_members
  set status = next_status,
      responded_at = now(),
      left_at = null
  where id = p_invitation_id;

  update public.shared_memories
  set updated_at = now()
  where id = target.shared_memory_id;

  return next_status;
end;
$$;

create or replace function public.attach_shared_memory_contribution_v1(
  p_shared_memory_id uuid,
  p_visit_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  memory public.shared_memories%rowtype;
  target public.visits%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select * into memory
  from public.shared_memories
  where id = p_shared_memory_id
  for update;
  if not found then
    raise exception 'shared MugShot not found' using errcode = 'P0002';
  end if;
  if not exists (
    select 1
    from public.shared_memory_members member
    where member.shared_memory_id = memory.id
      and member.user_id = actor
      and member.status = 'accepted'
  ) then
    raise exception 'accepted participation required' using errcode = '42501';
  end if;
  if private.blocked_between(actor, memory.created_by)
     or memory.source_visit_id is null
     or not private.can_view_visit_as(memory.source_visit_id, actor) then
    raise exception 'shared MugShot is unavailable' using errcode = '42501';
  end if;

  select * into target
  from public.visits
  where id = p_visit_id and user_id = actor
  for update;
  if not found then
    raise exception 'visit ownership required' using errcode = '42501';
  end if;
  if target.upload_state <> 'complete' or target.cafe_session_role = 'secondary' then
    raise exception 'a complete primary post is required' using errcode = '22023';
  end if;
  if actor = memory.created_by and target.id <> memory.source_visit_id then
    raise exception 'shared MugShot creator contribution is the immutable source post'
      using errcode = '55000';
  end if;
  if exists (
    select 1
    from public.shared_memories existing_memory
    where existing_memory.source_visit_id = target.id
      and existing_memory.id <> memory.id
  ) then
    raise exception 'post already anchors another shared MugShot' using errcode = '23505';
  end if;
  if (case
       when lower(btrim(coalesce(target.context_type, ''))) = 'cafe'
         or (nullif(btrim(target.context_type), '') is null and target.cafe_id is not null)
         then 'cafe'
       when lower(btrim(coalesce(target.context_type, ''))) = 'home' then 'home'
       when lower(btrim(coalesce(target.context_type, ''))) = 'recipe' then 'recipe'
       else 'elsewhere'
     end) <> lower(btrim(memory.context_type)) then
    raise exception 'post context does not match the shared MugShot' using errcode = '22023';
  end if;
  if lower(btrim(memory.context_type)) = 'cafe'
     and target.cafe_id is distinct from memory.cafe_id then
    raise exception 'post cafe does not match the shared MugShot' using errcode = '22023';
  end if;

  insert into public.shared_memory_contributions (
    shared_memory_id, visit_id, user_id
  ) values (
    memory.id, target.id, actor
  )
  on conflict (shared_memory_id, user_id) do update
    set visit_id = excluded.visit_id,
        joined_at = now();

  update public.shared_memories
  set updated_at = now()
  where id = memory.id;

  return target.id;
end;
$$;

create or replace function public.cancel_shared_memory_invitation_v1(p_invitation_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  changed_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  update public.shared_memory_members member
  set status = 'cancelled', responded_at = now()
  from public.shared_memories memory
  where member.id = p_invitation_id
    and member.shared_memory_id = memory.id
    and member.status = 'pending'
    and (member.invited_by = actor or memory.created_by = actor);
  get diagnostics changed_count = row_count;
  if changed_count > 0 then
    update public.shared_memories memory
    set updated_at = now()
    where memory.id = (
      select member.shared_memory_id
      from public.shared_memory_members member
      where member.id = p_invitation_id
    );
  end if;
  return changed_count > 0;
end;
$$;

create or replace function public.leave_shared_memory_v1(p_shared_memory_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  changed_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  update public.shared_memory_members
  set status = 'left', left_at = now(), responded_at = coalesce(responded_at, now())
  where shared_memory_id = p_shared_memory_id
    and user_id = actor
    and status = 'accepted';
  get diagnostics changed_count = row_count;

  if changed_count > 0 then
    delete from public.shared_memory_contributions
    where shared_memory_id = p_shared_memory_id and user_id = actor;
    update public.shared_memories
    set updated_at = now()
    where id = p_shared_memory_id;
  end if;
  return changed_count > 0;
end;
$$;

create or replace function public.get_shared_memory_projection_v1(p_visit_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  memory public.shared_memories%rowtype;
  visible_contributions jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select shared_memory.* into memory
  from public.shared_memories shared_memory
  where shared_memory.source_visit_id = p_visit_id
     or exists (
       select 1
       from public.shared_memory_contributions contribution
       where contribution.shared_memory_id = shared_memory.id
         and contribution.visit_id = p_visit_id
     )
  limit 1;

  if not found or not private.can_view_shared_memory_as(memory.id, actor) then
    return null;
  end if;

  select coalesce(jsonb_agg(
    jsonb_strip_nulls(jsonb_build_object(
      'visit_id', visible.visit_id,
      'user_id', visible.user_id,
      'display_name', visible.display_name,
      'username', visible.username,
      'avatar_url', visible.avatar_url,
      'caption', visible.caption,
      'drink', visible.drink,
      'overall_score', visible.overall_score,
      'poster_photo_url', visible.poster_photo_url,
      'visibility', visible.visibility,
      'created_at', visible.created_at
    )) order by visible.created_at, visible.visit_id
  ), '[]'::jsonb)
  into visible_contributions
  from (
    select
      visit.id visit_id,
      profile.id user_id,
      profile.display_name,
      profile.username,
      profile.avatar_url,
      visit.caption,
      coalesce(visit.drink_subtype, visit.drink_type_custom, visit.drink_type) drink,
      visit.overall_score,
      visit.poster_photo_url,
      visit.visibility,
      visit.created_at
    from public.shared_memory_contributions contribution
    join public.visits visit on visit.id = contribution.visit_id
    join public.users profile on profile.id = contribution.user_id
    where contribution.shared_memory_id = memory.id
      and private.can_view_visit_as(visit.id, actor)
      and not private.blocked_between(actor, profile.id)
  ) visible;

  -- A shared MugShot is a grouped presentation, not a durable ownership
  -- shortcut. Once audience or blocking rules leave fewer than two visible
  -- contributions, each surviving post renders independently instead.
  if jsonb_array_length(visible_contributions) < 2 then
    return null;
  end if;

  return jsonb_build_object(
    'shared_memory_id', memory.id,
    'context_type', memory.context_type,
    'cafe_id', memory.cafe_id,
    'location_label', memory.location_label,
    'occurred_at', memory.occurred_at,
    'contributions', visible_contributions
  );
end;
$$;

revoke all on function public.create_shared_memory_invitations_v1(uuid, uuid[])
  from public, anon, authenticated;
revoke all on function public.list_pending_shared_memory_invitations_v1()
  from public, anon, authenticated;
revoke all on function public.list_managed_shared_memory_invitations_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.list_my_shared_memory_memberships_v1()
  from public, anon, authenticated;
revoke all on function public.list_owned_shared_memories_v1()
  from public, anon, authenticated;
revoke all on function public.respond_shared_memory_invitation_v1(uuid, boolean)
  from public, anon, authenticated;
revoke all on function public.attach_shared_memory_contribution_v1(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.cancel_shared_memory_invitation_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.leave_shared_memory_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.get_shared_memory_projection_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.create_shared_memory_invitations_v1(uuid, uuid[]) to authenticated;
grant execute on function public.list_pending_shared_memory_invitations_v1() to authenticated;
grant execute on function public.list_managed_shared_memory_invitations_v1(uuid)
  to authenticated;
grant execute on function public.list_my_shared_memory_memberships_v1()
  to authenticated;
grant execute on function public.list_owned_shared_memories_v1()
  to authenticated;
grant execute on function public.respond_shared_memory_invitation_v1(uuid, boolean) to authenticated;
grant execute on function public.attach_shared_memory_contribution_v1(uuid, uuid) to authenticated;
grant execute on function public.cancel_shared_memory_invitation_v1(uuid) to authenticated;
grant execute on function public.leave_shared_memory_v1(uuid) to authenticated;
grant execute on function public.get_shared_memory_projection_v1(uuid) to authenticated;

comment on table public.shared_memories is
  'A consented shared moment. It never replaces or merges each participant''s immutable visit.';
comment on table public.shared_memory_contributions is
  'At most one independently owned visit per accepted participant; original visibility remains authoritative.';
comment on function public.get_shared_memory_projection_v1(uuid) is
  'Returns a grouped card only with at least two independently visible contributions; never exposes hidden member identities or counts.';
comment on function public.list_managed_shared_memory_invitations_v1(uuid) is
  'Creator-only invitation roster; blocked identities and raw post IDs are omitted.';
comment on function public.list_my_shared_memory_memberships_v1() is
  'Recoverable pending and accepted memberships; blocked inviter identity fields are suppressed so leave remains available.';
comment on function public.list_owned_shared_memories_v1() is
  'Caller-bound recovery surface for memories anchored by the caller''s own posts.';

-- Every projection above checks blocks at read time. The ordered alpha social
-- integrity migration owns physical graph severance so one caller-bound block
-- transaction can report accurate mutation counts without duplicate triggers.

-- Deliberately held outside this migration: historical JSON may contain old
-- companion names or other owner-entered recipe keys. New projections never
-- expose arbitrary keys. Any future scrub must be separately reviewed,
-- backed up, and applied only after the production-like pre-alpha data is
-- confirmed recoverable.

commit;
