begin;

do $test$
declare
  configured_settings text[];
begin
  if to_regprocedure('public.enforce_mugshot_live_session_v3()') is null then
    raise exception 'live-session enforcement function is missing';
  end if;

  select array_agg(config.setting order by settings.setdatabase, config.setting)
  into configured_settings
  from pg_catalog.pg_db_role_setting settings
  join pg_catalog.pg_roles role_record
    on role_record.oid = settings.setrole
  cross join lateral unnest(settings.setconfig) config(setting)
  where role_record.rolname = 'authenticator'
    and config.setting like 'pgrst.db_pre_request=%';

  if configured_settings is distinct from array[
    'pgrst.db_pre_request=public.enforce_mugshot_live_session_v3'
  ] then
    raise exception 'unexpected PostgREST pre-request setting: %',
      configured_settings;
  end if;

  if not has_function_privilege(
    'anon', 'public.enforce_mugshot_live_session_v3()', 'EXECUTE'
  ) or not has_function_privilege(
    'authenticated', 'public.enforce_mugshot_live_session_v3()', 'EXECUTE'
  ) then
    raise exception 'PostgREST request roles cannot execute the live-session hook';
  end if;
end;
$test$;

rollback;
