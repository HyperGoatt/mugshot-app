do $$
begin
  if to_regclass('public.visit_bookmarks') is null
    or to_regclass('public.recipe_identities') is null
    or to_regclass('public.recipe_versions') is null then
    raise exception 'canonical journal tables are missing';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'visits'
      and column_name = 'recipe_version_id'
  ) then
    raise exception 'visits do not reference immutable recipe versions';
  end if;

  if exists (
    select 1 from (values
      ('visit_bookmarks'), ('recipe_identities'), ('recipe_versions')
    ) required(table_name)
    where not (
      select relrowsecurity from pg_class
      where oid = format('public.%I', required.table_name)::regclass
    )
  ) then
    raise exception 'a canonical journal table is missing RLS';
  end if;

  if (
    select count(*) from pg_policies
    where schemaname = 'public' and tablename = 'visit_bookmarks'
      and roles = '{authenticated}'::name[]
  ) < 3 then
    raise exception 'bookmark owner policies are incomplete';
  end if;

  if has_table_privilege('anon', 'public.visit_bookmarks', 'select')
    or has_table_privilege('anon', 'public.recipe_identities', 'select')
    or has_table_privilege('anon', 'public.recipe_versions', 'select') then
    raise exception 'anonymous users can read private journal structures';
  end if;

  if has_function_privilege(
    'authenticated',
    'public.materialize_visit_recipe_version(uuid)',
    'EXECUTE'
  ) then
    raise exception 'recipe materialization is callable from the client';
  end if;

  if has_function_privilege(
    'anon',
    'public.materialize_new_visit_recipe_version()',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'public.materialize_new_visit_recipe_version()',
    'EXECUTE'
  ) then
    raise exception 'recipe trigger wrapper is callable from the API';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'public.visits'::regclass
      and tgname = 'materialize_visit_recipe_version_after_insert'
      and not tgisinternal
  ) then
    raise exception 'new recipe visits are not materialized';
  end if;
end $$;

select 'canonical_journal_contract_passed' as result;
