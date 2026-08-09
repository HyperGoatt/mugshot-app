begin;

-- Account deletion revokes Auth sessions before removing the identity. Make
-- every Data API request verify that its JWT still names a live session, a
-- live account, and an account without an active deletion job. This is a
-- deployment setting, so fail closed instead of replacing an unknown hook.
do $migration$
declare
  expected_setting constant text :=
    'pgrst.db_pre_request=public.enforce_mugshot_live_session_v3';
  existing_settings text[];
begin
  if not exists (
    select 1 from pg_catalog.pg_roles where rolname = 'authenticator'
  ) then
    raise exception 'authenticator role is required for the live-session gate';
  end if;

  if to_regprocedure('public.enforce_mugshot_live_session_v3()') is null then
    raise exception 'live-session enforcement function is missing';
  end if;

  select array_agg(config.setting order by settings.setdatabase, config.setting)
  into existing_settings
  from pg_catalog.pg_db_role_setting settings
  join pg_catalog.pg_roles role_record
    on role_record.oid = settings.setrole
  cross join lateral unnest(settings.setconfig) config(setting)
  where role_record.rolname = 'authenticator'
    and config.setting like 'pgrst.db_pre_request=%';

  if coalesce(cardinality(existing_settings), 0) = 0 then
    execute format(
      'alter role authenticator set pgrst.db_pre_request = %L',
      'public.enforce_mugshot_live_session_v3'
    );
  elsif existing_settings = array[expected_setting] then
    -- Idempotent when a managed environment has already applied this exact
    -- hook. Multiple database/role settings remain an error because their
    -- precedence would make the effective control ambiguous.
    null;
  else
    raise exception
      'refusing to replace existing PostgREST pre-request settings: %',
      existing_settings;
  end if;
end;
$migration$;

-- PostgREST reloads role/database settings without a service restart.
notify pgrst, 'reload config';

commit;
