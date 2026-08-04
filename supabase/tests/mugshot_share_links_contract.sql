begin;

do $$
declare
  function_name text;
  function_config text[];
  is_security_definer boolean;
  projection_definition text;
begin
  if to_regclass('public.visit_share_links') is null then
    raise exception 'visit_share_links table is missing';
  end if;

  if not (
    select class.relrowsecurity
    from pg_class class
    where class.oid = 'public.visit_share_links'::regclass
  ) then
    raise exception 'visit_share_links RLS is disabled';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'visit_share_links'
      and grantee in ('anon', 'authenticated')
  ) then
    raise exception 'client roles can access sealed share-link rows directly';
  end if;
  if exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'visit_share_link_metrics'
      and grantee in ('anon', 'authenticated')
  ) then
    raise exception 'client roles can access share metrics directly';
  end if;

  foreach function_name in array array[
    'public.create_visit_share_link_v1(uuid)',
    'public.get_visit_share_slug_v1(uuid)',
    'public.revoke_visit_share_link_v1(uuid)',
    'public.get_public_mugshot_share_v1(text)',
    'public.record_public_mugshot_share_event_v1(text,text)'
  ] loop
    select procedure.prosecdef, procedure.proconfig
    into is_security_definer, function_config
    from pg_proc procedure
    where procedure.oid = function_name::regprocedure;

    if not is_security_definer then
      raise exception '% must remain security definer', function_name;
    end if;
    if function_config is null
       or not ('search_path=""' = any(function_config)) then
      raise exception '% lost its empty search_path', function_name;
    end if;
  end loop;

  if has_function_privilege(
       'anon', 'public.create_visit_share_link_v1(uuid)', 'EXECUTE'
     )
     or has_function_privilege(
       'anon', 'public.get_visit_share_slug_v1(uuid)', 'EXECUTE'
     )
     or has_function_privilege(
       'anon', 'public.revoke_visit_share_link_v1(uuid)', 'EXECUTE'
     ) then
    raise exception 'anonymous clients can mutate or resolve owner share links';
  end if;

  if not has_function_privilege(
       'authenticated', 'public.create_visit_share_link_v1(uuid)', 'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated', 'public.get_visit_share_slug_v1(uuid)', 'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated', 'public.revoke_visit_share_link_v1(uuid)', 'EXECUTE'
     )
     or not has_function_privilege(
       'anon', 'public.get_public_mugshot_share_v1(text)', 'EXECUTE'
     )
     or not has_function_privilege(
       'anon',
       'public.record_public_mugshot_share_event_v1(text,text)',
       'EXECUTE'
     ) then
    raise exception 'share-link function grants are incomplete';
  end if;

  select lower(pg_get_functiondef(
    'public.get_public_mugshot_share_v1(text)'::regprocedure
  )) into projection_definition;

  if projection_definition ~
      '(private_note|visit_private_notes|brew_details|recipe_version|latitude|longitude|location_name|passport)' then
    raise exception 'public Mugshot projection references a private field';
  end if;
end;
$$;

create temp table mugshot_share_fixture as
select visit.id visit_id, visit.user_id owner_id, visit.visibility
from public.visits visit
where private.is_public_visit_discoverable_v3(visit.id)
order by visit.created_at desc
limit 1;

do $$
begin
  if not exists (select 1 from mugshot_share_fixture) then
    raise exception 'share-link contract requires one discoverable public visit fixture';
  end if;
end;
$$;

insert into public.visit_share_links (visit_id, owner_id, slug)
select visit_id, owner_id, repeat('a', 48)
from mugshot_share_fixture;

do $$
declare
  projection jsonb;
  expected_keys constant text[] := array[
    'visit_id', 'slug', 'author_name', 'author_username', 'drink_name',
    'context_name', 'rating', 'caption', 'cover_photo_url', 'created_at'
  ];
begin
  select to_jsonb(result)
  into projection
  from public.get_public_mugshot_share_v1(repeat('a', 48)) result;

  if projection is null then
    raise exception 'discoverable public Mugshot link returned no projection';
  end if;

  if (
    select array_agg(key order by key)
    from jsonb_object_keys(projection) key
  ) <> (
    select array_agg(key order by key)
    from unnest(expected_keys) key
  ) then
    raise exception 'public Mugshot projection returned unexpected fields: %',
      projection;
  end if;
end;
$$;

update public.visits
set visibility = 'private'
where id = (select visit_id from mugshot_share_fixture);

do $$
begin
  if exists (
    select 1
    from public.get_public_mugshot_share_v1(repeat('a', 48))
  ) then
    raise exception 'private audience did not revoke anonymous share access';
  end if;
end;
$$;

update public.visits
set visibility = 'friends'
where id = (select visit_id from mugshot_share_fixture);

do $$
begin
  if exists (
    select 1
    from public.get_public_mugshot_share_v1(repeat('a', 48))
  ) then
    raise exception 'friends audience did not revoke anonymous share access';
  end if;
end;
$$;

update public.visits
set visibility = 'everyone',
    upload_state = 'uploading'
where id = (select visit_id from mugshot_share_fixture);

do $$
begin
  if exists (
    select 1
    from public.get_public_mugshot_share_v1(repeat('a', 48))
  ) then
    raise exception 'unpublished visit remained available from public share link';
  end if;
end;
$$;

rollback;

select 'mugshot_share_links_contract_passed' as result;
