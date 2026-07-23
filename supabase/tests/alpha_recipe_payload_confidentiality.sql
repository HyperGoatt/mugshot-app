begin;

create temp table alpha_recipe_payload_users as
select id, row_number() over (order by id) n
from (select id from public.users order by id limit 2) users;
grant select on alpha_recipe_payload_users to authenticated;

do $$ begin
  if (select count(*) from alpha_recipe_payload_users) < 2 then
    raise exception 'recipe payload confidentiality requires two existing users';
  end if;
end $$;

create temp table alpha_recipe_payload_ids (
  visit_id uuid not null,
  source_recipe_version_id uuid not null,
  target_recipe_version_id uuid
);
grant select, update on alpha_recipe_payload_ids to authenticated;

with source_identity as (
  insert into public.recipe_identities (user_id, name)
  select id, 'Private source blueprint'
  from alpha_recipe_payload_users where n = 1
  returning id
), source_version as (
  insert into public.recipe_versions (
    recipe_identity_id,
    version_number,
    version_label,
    brew_details,
    visibility,
    source_kind,
    redistribution_allowed
  )
  select
    id,
    1,
    'Source v1',
    '{"beans":"Source beans"}'::jsonb,
    'private',
    'original',
    false
  from source_identity
  returning id
)
insert into alpha_recipe_payload_ids (visit_id, source_recipe_version_id)
select gen_random_uuid(), id from source_version;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_payload_users where n = 1),
  'role', 'authenticated'
)::text, true);

select public.stage_visit_recipe_payload_v2(
  (select visit_id from alpha_recipe_payload_ids),
  jsonb_build_object(
    'recipeName', 'Confidential V60',
    'recipeVersion', 'v7',
    'beans', 'Secret lot 42',
    'doseGrams', 18,
    'yieldGrams', 300,
    'brewTimeSeconds', 180,
    'steps', jsonb_build_array(jsonb_build_object(
      'instruction', 'Private bloom sequence',
      'durationSeconds', 45
    )),
    'additions', 'Mineral concentrate: 2 drops',
    'sourceRecipeIdentityID', gen_random_uuid(),
    'ownerOnlyLabNote', 'must never leave the owner-bound store'
  ),
  'V60: private technique',
  'Prototype dripper'
);

insert into public.visits (
  id,
  user_id,
  drink_type,
  drink_subtype,
  caption,
  visibility,
  ratings,
  overall_score,
  context_type,
  location_name,
  brew_method,
  equipment,
  brew_details,
  upload_state,
  recipe_payload_contract_version
)
select
  ids.visit_id,
  users.id,
  'Coffee',
  'Confidential V60',
  'The MugShot is public; its recipe is independently private.',
  'everyone',
  '{"Overall":4.8}'::jsonb,
  4.8,
  'Recipe',
  'Home',
  null,
  null,
  '{"recipeName":"Confidential V60","recipeVersion":"v7"}'::jsonb,
  'complete',
  2
from alpha_recipe_payload_ids ids
cross join alpha_recipe_payload_users users
where users.n = 1;

update alpha_recipe_payload_ids ids
set target_recipe_version_id = visit.recipe_version_id
from public.visits visit
where visit.id = ids.visit_id;

select public.configure_recipe_source_rights_v1(
  (select target_recipe_version_id from alpha_recipe_payload_ids),
  'adapted',
  false,
  (select source_recipe_version_id from alpha_recipe_payload_ids)
);

reset role;

do $$
declare raw_visit jsonb;
begin
  select to_jsonb(visit) into raw_visit
  from public.visits visit
  where visit.id = (select visit_id from alpha_recipe_payload_ids);

  if (select target_recipe_version_id from alpha_recipe_payload_ids) is null then
    raise exception 'contract-v2 visit did not materialize a recipe version';
  end if;
  if raw_visit ->> 'brew_method' is not null
     or raw_visit ->> 'equipment' is not null
     or raw_visit -> 'brew_details' ?| array[
       'beans', 'doseGrams', 'yieldGrams', 'brewTimeSeconds', 'steps',
       'additions', 'sourceRecipeIdentityID', 'ownerOnlyLabNote'
     ]
     or raw_visit ->> 'source_recipe_version_id' is not null then
    raise exception 'social visit row retained protected contract-v2 recipe data';
  end if;
  if raw_visit -> 'brew_details' ->> 'recipeName' <> 'Confidential V60'
     or raw_visit -> 'brew_details' ->> 'recipeVersion' <> 'v7' then
    raise exception 'social visit row lost safe recipe display metadata';
  end if;
  if exists (
    select 1 from private.visit_recipe_payload_staging stage
    where stage.visit_id = (select visit_id from alpha_recipe_payload_ids)
  ) then
    raise exception 'owner-bound recipe stage was not consumed transactionally';
  end if;
  if not exists (
    select 1
    from public.recipe_versions version
    where version.id = (select target_recipe_version_id from alpha_recipe_payload_ids)
      and version.brew_method = 'V60: private technique'
      and version.equipment = 'Prototype dripper'
      and version.brew_details ->> 'beans' = 'Secret lot 42'
      and version.brew_details ->> 'doseGrams' = '18'
      and version.brew_details ->> 'yieldGrams' = '300'
      and jsonb_array_length(version.brew_details -> 'steps') = 1
      and version.brew_details ->> 'additions' = 'Mineral concentrate: 2 drops'
      and version.source_kind = 'adapted'
      and version.source_recipe_version_id =
        (select source_recipe_version_id from alpha_recipe_payload_ids)
  ) then
    raise exception 'private recipe version did not retain the complete staged blueprint';
  end if;

  if has_column_privilege('authenticated', 'public.visits', 'brew_details', 'SELECT')
     or has_column_privilege('authenticated', 'public.visits', 'brew_method', 'SELECT')
     or has_column_privilege('authenticated', 'public.visits', 'equipment', 'SELECT')
     or has_column_privilege(
       'authenticated', 'public.visits', 'source_recipe_version_id', 'SELECT'
     )
     or has_column_privilege('anon', 'public.visits', 'brew_details', 'SELECT') then
    raise exception 'app roles retain direct access to protected visit recipe columns';
  end if;
  if not has_column_privilege('authenticated', 'public.visits', 'id', 'SELECT')
     or not has_column_privilege(
       'authenticated', 'public.visits', 'recipe_payload_contract_version', 'INSERT'
     ) then
    raise exception 'safe visit read/write privileges are incomplete';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_payload_users where n = 2),
  'role', 'authenticated'
)::text, true);

do $$ begin
  begin
    perform brew_details
    from public.visits
    where id = (select visit_id from alpha_recipe_payload_ids);
    raise exception 'authenticated client selected protected visit recipe JSON';
  exception when sqlstate '42501' then null;
  end;

  if public.get_recipe_projection_for_visit_v1(
    (select visit_id from alpha_recipe_payload_ids)
  ) is not null then
    raise exception 'public MugShot leaked an independently private recipe';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_payload_users where n = 1),
  'role', 'authenticated'
)::text, true);

do $$
declare projection jsonb;
begin
  projection := public.get_recipe_projection_for_visit_v1(
    (select visit_id from alpha_recipe_payload_ids)
  );
  if projection is null
     or projection ->> 'brew_method' <> 'V60: private technique'
     or projection ->> 'equipment' <> 'Prototype dripper'
     or projection -> 'brew_details' ->> 'beans' <> 'Secret lot 42'
     or projection -> 'brew_details' ->> 'doseGrams' <> '18'
     or projection -> 'brew_details' ->> 'yieldGrams' <> '300'
     or jsonb_array_length(projection -> 'brew_details' -> 'steps') <> 1
     or projection -> 'brew_details' ->> 'additions' <>
       'Mineral concentrate: 2 drops'
     or projection ->> 'source_recipe_version_id' <>
       (select source_recipe_version_id::text from alpha_recipe_payload_ids) then
    raise exception 'owner recipe projection did not return the complete allowed blueprint';
  end if;
  if projection -> 'brew_details' ? 'ownerOnlyLabNote' then
    raise exception 'allowlisted recipe projection exposed an arbitrary owner-only key';
  end if;
end $$;

rollback;

select 'alpha_recipe_payload_confidentiality_passed' as result;
