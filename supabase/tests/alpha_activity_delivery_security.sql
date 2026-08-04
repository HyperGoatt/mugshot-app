\set ON_ERROR_STOP on

begin;

do $$
declare
  signature text;
begin
  if to_regclass('public.activity_events') is null
     or to_regclass('public.notification_preferences') is null
     or to_regclass('private.activity_push_deliveries') is null then
    raise exception 'activity delivery tables are incomplete';
  end if;

  if exists (
    select 1
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where (namespace.nspname, relation.relname) in (
      ('public', 'activity_events'),
      ('public', 'notification_preferences'),
      ('public', 'user_devices'),
      ('private', 'activity_push_deliveries')
    )
      and not relation.relrowsecurity
  ) then
    raise exception 'an activity or device table is missing RLS';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants grant_row
    where (grant_row.table_schema, grant_row.table_name) in (
      ('public', 'activity_events'),
      ('public', 'notification_preferences'),
      ('public', 'user_devices'),
      ('private', 'activity_push_deliveries')
    )
      and grant_row.grantee in ('PUBLIC', 'anon', 'authenticated')
  ) then
    raise exception 'a raw activity, preference, device, or delivery table is client accessible';
  end if;

  if has_schema_privilege('anon', 'private', 'USAGE')
     or has_schema_privilege('authenticated', 'private', 'USAGE') then
    raise exception 'private delivery schema is client accessible';
  end if;

  if exists (
    select 1 from pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.notifications'::regclass
      and trigger_row.tgname = 'on_notification_insert'
      and not trigger_row.tgisinternal
  ) then
    raise exception 'legacy notification push trigger still exists';
  end if;

  if exists (
    select 1 from pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.visits'::regclass
      and trigger_row.tgname = 'notify-friends-on-new-visit'
      and not trigger_row.tgisinternal
  ) then
    raise exception 'legacy visit webhook trigger still exists';
  end if;

  if to_regprocedure('public.send_push_notification_trigger()') is not null then
    raise exception 'legacy push function still exists';
  end if;

  if (
    select count(*)
    from pg_trigger trigger_row
    join pg_class relation on relation.oid = trigger_row.tgrelid
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where not trigger_row.tgisinternal
      and trigger_row.tgname in (
        'activity_from_visit', 'activity_from_tag', 'cleanup_activity_from_tag',
        'activity_from_cafe_list_invitation',
        'cleanup_activity_from_cafe_list_invitation',
        'cleanup_activity_from_cafe_list_invitation_status',
        'activity_from_like', 'cleanup_activity_from_like',
        'activity_from_comment', 'suppress_activity_from_comment',
        'activity_from_comment_mention',
        'cleanup_activity_from_comment_mention', 'activity_from_reaction',
        'cleanup_activity_from_reaction',
        'activity_from_friend_request', 'enqueue_activity_push',
        'cleanup_blocked_pair_activity', 'suppress_moderated_activity',
        'suppress_invisible_visit_activity'
      )
  ) <> 19 then
    raise exception 'authoritative activity triggers are incomplete';
  end if;

  if not exists (
    select 1
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'notification_preferences'
      and column_row.column_name = 'friend_posts'
      and column_row.column_default ilike '%true%'
  ) then
    raise exception 'friend-post notification preference does not default enabled';
  end if;

  foreach signature in array array[
    'public.register_user_device_v2(uuid,text,text)',
    'public.unregister_user_device_v2(uuid)',
    'public.get_notification_preferences_v1()',
    'public.set_notification_preferences_v1(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean)',
    'public.list_activity_events_v1(integer,timestamp with time zone,uuid)',
    'public.activity_unread_count_v1()',
    'public.mark_activity_read_v1(uuid)',
    'public.build_owner_activity_export_v1()'
  ] loop
    if not has_function_privilege('authenticated', signature, 'EXECUTE') then
      raise exception 'authenticated role cannot execute %', signature;
    end if;
    if has_function_privilege('anon', signature, 'EXECUTE') then
      raise exception 'anon role can execute %', signature;
    end if;
  end loop;

  foreach signature in array array[
    'public.claim_activity_push_batch_v2(integer)',
    'public.complete_activity_push_delivery_v2(uuid,uuid,bigint,text,text,integer)'
  ] loop
    if has_function_privilege('anon', signature, 'EXECUTE')
       or has_function_privilege('authenticated', signature, 'EXECUTE') then
      raise exception 'client role can execute delivery worker RPC %', signature;
    end if;
    if not has_function_privilege('service_role', signature, 'EXECUTE') then
      raise exception 'service role cannot execute delivery worker RPC %', signature;
    end if;
  end loop;

  if exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'register_user_device_v2', 'unregister_user_device_v2',
        'get_notification_preferences_v1', 'set_notification_preferences_v1',
        'list_activity_events_v1', 'activity_unread_count_v1',
        'mark_activity_read_v1', 'claim_activity_push_batch_v2',
        'complete_activity_push_delivery_v2', 'build_owner_activity_export_v1'
      )
      and (
        not procedure.prosecdef
        or not coalesce(procedure.proconfig @> array['search_path=""'], false)
      )
  ) then
    raise exception 'a public activity function lacks SECURITY DEFINER or an empty search_path';
  end if;

  if has_function_privilege(
       'service_role', 'public.claim_activity_push_batch_v1(integer)', 'EXECUTE'
     )
     or has_function_privilege(
       'service_role',
       'public.complete_activity_push_delivery_v1(uuid,boolean,text,boolean)',
       'EXECUTE'
     ) then
    raise exception 'service role can still use the unfenced delivery protocol';
  end if;

  if exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'private'
      and procedure.proname like '%activity%'
      and (
        has_function_privilege('anon', procedure.oid, 'EXECUTE')
        or has_function_privilege('authenticated', procedure.oid, 'EXECUTE')
      )
  ) then
    raise exception 'a private activity helper remains client executable';
  end if;

  if pg_get_function_result(
    'public.list_activity_events_v1(integer,timestamp with time zone,uuid)'::regprocedure
  ) ilike '%push_token%'
     or pg_get_function_result(
       'public.build_owner_activity_export_v1()'::regprocedure
     ) ilike '%push_token%' then
    raise exception 'a client activity projection exposes a push token';
  end if;
end;
$$;

rollback;

select 'alpha_activity_delivery_security_passed' as result;
