\set ON_ERROR_STOP on

begin;

do $$
declare
  validator regprocedure := 'public.is_valid_legacy_notification_insert_v1(uuid,uuid,text,uuid,uuid,timestamp with time zone,timestamp with time zone)'::regprocedure;
begin
  if not has_function_privilege('authenticated', validator, 'EXECUTE')
     or has_function_privilege('anon', validator, 'EXECUTE') then
    raise exception 'legacy notification validator grants are incorrect';
  end if;

  if exists (
    select 1
    from pg_proc procedure
    where procedure.oid = validator
      and (
        procedure.prosecdef
        or not coalesce(procedure.proconfig @> array['search_path=""'], false)
      )
  ) then
    raise exception 'legacy notification validator is not a sealed security invoker';
  end if;

  if (select count(*) from pg_policies policy
      where policy.schemaname = 'public'
        and policy.tablename = 'notifications') <> 4 then
    raise exception 'legacy notification policy count is incorrect';
  end if;

  if exists (
    select 1
    from pg_policies policy
    where policy.schemaname = 'public'
      and policy.tablename = 'notifications'
      and policy.roles <> array['authenticated']::name[]
  ) then
    raise exception 'a legacy notification policy remains available to a public role';
  end if;

  if not exists (
    select 1
    from pg_policies policy
    where policy.schemaname = 'public'
      and policy.tablename = 'notifications'
      and policy.cmd = 'INSERT'
      and policy.with_check ilike '%is_valid_legacy_notification_insert_v1%'
  ) then
    raise exception 'legacy notification inserts do not use the relationship validator';
  end if;

  if has_table_privilege('anon', 'public.notifications', 'SELECT')
     or has_table_privilege('anon', 'public.notifications', 'INSERT')
     or has_table_privilege('anon', 'public.notifications', 'UPDATE')
     or has_table_privilege('anon', 'public.notifications', 'DELETE')
     or has_table_privilege('authenticated', 'public.notifications', 'TRUNCATE')
     or has_table_privilege('authenticated', 'public.notifications', 'TRIGGER')
     or has_table_privilege('authenticated', 'public.notifications', 'REFERENCES') then
    raise exception 'legacy notification table retains an excessive client grant';
  end if;

  if not has_column_privilege(
       'authenticated', 'public.notifications', 'actor_user_id', 'INSERT'
     )
     or not has_column_privilege(
       'authenticated', 'public.notifications', 'read_at', 'UPDATE'
     )
     or has_column_privilege(
       'authenticated', 'public.notifications', 'created_at', 'INSERT'
     )
     or has_column_privilege(
       'authenticated', 'public.notifications', 'type', 'UPDATE'
     ) then
    raise exception 'legacy notification column grants are incorrect';
  end if;

  if not exists (
    select 1
    from pg_constraint constraint_record
    where constraint_record.conrelid = 'public.notifications'::regclass
      and constraint_record.conname = 'notifications_type_check'
      and pg_get_constraintdef(constraint_record.oid) ilike '%friend_accept%'
  ) then
    raise exception 'legacy PWA friend acceptance type is not constrained';
  end if;
end;
$$;

rollback;

select 'legacy_notification_insert_security_passed' as result;
