do $$
declare
  projection_definition text;
  owner_brew_definition text;
  export_definition text;
  deletion_definition text;
begin
  if to_regclass('public.home_coffee_bags') is null
    or to_regclass('public.home_equipment_profiles') is null then
    raise exception 'Home Workbench owner tables are missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'visits'
      and column_name = 'home_coffee_bag_id'
  ) then
    raise exception 'visits are missing the Home coffee relationship';
  end if;

  if not has_column_privilege(
      'anon', 'public.visits', 'home_coffee_bag_id', 'SELECT'
    )
    or not has_column_privilege(
      'authenticated', 'public.visits', 'home_coffee_bag_id', 'SELECT'
    )
    or not has_column_privilege(
      'authenticated', 'public.visits', 'home_coffee_bag_id', 'INSERT'
    )
    or has_column_privilege(
      'anon', 'public.visits', 'home_coffee_bag_id', 'INSERT'
    ) then
    raise exception 'Home visit column privileges are incomplete or too broad';
  end if;

  select pg_get_functiondef(
    'public.get_owner_visit_brew_details_v1(uuid[],integer)'::regprocedure
  ) into owner_brew_definition;
  if position('visit.user_id = actor' in owner_brew_definition) = 0
    or position('visit.upload_state = ''complete''' in owner_brew_definition) = 0
    or not exists (
      select 1
      from pg_proc
      where oid = 'public.get_owner_visit_brew_details_v1(uuid[],integer)'::regprocedure
        and prosecdef
        and proconfig @> array['search_path=""']::text[]
    )
    or not has_function_privilege(
      'authenticated',
      'public.get_owner_visit_brew_details_v1(uuid[],integer)',
      'EXECUTE'
    )
    or has_function_privilege(
      'anon',
      'public.get_owner_visit_brew_details_v1(uuid[],integer)',
      'EXECUTE'
    ) then
    raise exception 'owner Journal brew projection is missing or unsafe';
  end if;

  if not (
    select relrowsecurity from pg_class
    where oid = 'public.home_coffee_bags'::regclass
  ) or not (
    select relrowsecurity from pg_class
    where oid = 'public.home_equipment_profiles'::regclass
  ) then
    raise exception 'Home Workbench tables are missing RLS';
  end if;

  if has_table_privilege('anon', 'public.home_coffee_bags', 'select')
    or has_table_privilege('anon', 'public.home_equipment_profiles', 'select') then
    raise exception 'anonymous clients can read the Home library';
  end if;

  if (
    select count(*) from pg_policies
    where schemaname = 'public'
      and tablename in ('home_coffee_bags', 'home_equipment_profiles')
      and roles = '{authenticated}'::name[]
  ) <> 8 then
    raise exception 'Home Workbench owner policies are incomplete';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.home_coffee_bags'::regclass
      and tgname = 'home_coffee_bags_keep_newest_v1'
      and not tgisinternal
  ) or not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.home_equipment_profiles'::regclass
      and tgname = 'home_equipment_profiles_keep_newest_v1'
      and not tgisinternal
  ) then
    raise exception 'Home library last-write-wins triggers are missing';
  end if;

  if not exists (
    select 1 from storage.buckets
    where id = 'home-coffee-bag-photos' and not public
  ) then
    raise exception 'Home bag photo bucket is missing or public';
  end if;

  foreach deletion_definition in array array[
    pg_get_functiondef('private.guard_account_storage_write_v3()'::regprocedure),
    pg_get_functiondef(
      'public.prepare_account_deletion_v3(uuid,uuid,uuid,text,text,uuid,text)'::regprocedure
    ),
    pg_get_functiondef(
      'public.seal_account_deletion_storage_preflight_v3(uuid,uuid)'::regprocedure
    ),
    pg_get_functiondef(
      'public.detach_account_storage_ownership_v3(uuid,uuid)'::regprocedure
    )
  ] loop
    if position('''home-coffee-bag-photos''' in deletion_definition) = 0 then
      raise exception 'account deletion does not cover the Home bag photo bucket';
    end if;
  end loop;

  select pg_get_functiondef('public.get_recipe_projection_v1(uuid)'::regprocedure)
  into projection_definition;
  if position('coffeeBag' in projection_definition) = 0
    or position('equipmentSnapshots' in projection_definition) = 0
    or position('homeMethodDetails' in projection_definition) = 0
    or position('privatePhotoPath' in projection_definition) > 0
    or position('remainingWeightGrams' in projection_definition) > 0 then
    raise exception 'recipe projection Home allowlist is unsafe or incomplete';
  end if;

  select pg_get_functiondef('public.build_owner_data_export_v2()'::regprocedure)
  into export_definition;
  if position('home_workbench' in export_definition) = 0
    or position('home-coffee-bag-photos' in export_definition) = 0 then
    raise exception 'owner export does not include the complete Home library';
  end if;
end $$;

select 'home_workbench_contract_passed' as result;

begin;

create temp table home_workbench_users as
select gen_random_uuid() owner_id, gen_random_uuid() other_id;
grant select on home_workbench_users to authenticated;

insert into auth.users (id)
select owner_id from home_workbench_users
union all
select other_id from home_workbench_users;

insert into public.users (id, display_name, username)
select owner_id, 'Home owner', 'home_owner_fixture'
from home_workbench_users
union all
select other_id, 'Home other', 'home_other_fixture'
from home_workbench_users;

insert into public.visits (
  id,
  user_id,
  caption,
  visibility,
  overall_score,
  context_type,
  location_name,
  brew_method,
  equipment,
  brew_details,
  upload_state,
  created_at
)
select
  gen_random_uuid(),
  owner_id,
  'Owner fixture',
  'private',
  8.0,
  'Home',
  'Home',
  'Espresso',
  'Owner grinder',
  '{"doseGrams":18,"ownerOnlyLabNote":"private"}'::jsonb,
  'complete',
  now()
from home_workbench_users
union all
select
  gen_random_uuid(),
  other_id,
  'Other fixture',
  'private',
  8.0,
  'Home',
  'Home',
  'Pour Over',
  'Other grinder',
  '{"doseGrams":20,"ownerOnlyLabNote":"other private"}'::jsonb,
  'complete',
  now()
from home_workbench_users;

-- auth.uid() reads request claims in hermetic contract runs. Foreign-key
-- fixtures are supplied by the harness in full RLS execution environments.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from home_workbench_users),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if exists (
    select 1 from public.home_coffee_bags
    where user_id = (select other_id from home_workbench_users)
  ) or exists (
    select 1 from public.home_equipment_profiles
    where user_id = (select other_id from home_workbench_users)
  ) then
    raise exception 'Home library rows crossed account scope';
  end if;

  if (
    select count(*)
    from public.get_owner_visit_brew_details_v1(null, 500)
  ) <> 1 or exists (
    select 1
    from public.get_owner_visit_brew_details_v1(null, 500)
    where equipment = 'Other grinder'
      or brew_details ->> 'ownerOnlyLabNote' = 'other private'
  ) then
    raise exception 'owner Journal brew projection crossed account scope';
  end if;
end $$;

rollback;
