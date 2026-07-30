begin;

do $$
declare
  target_routine_name text;
  definition text;
begin
  if exists (
    select 1
    from information_schema.column_privileges privilege
    where privilege.table_schema = 'public'
      and privilege.grantee = 'authenticated'
      and privilege.privilege_type = 'SELECT'
      and (
        (privilege.table_name = 'cafe_list_members'
          and privilege.column_name in ('user_id', 'invited_by'))
        or (privilege.table_name = 'cafe_list_items'
          and privilege.column_name = 'contributor_id')
      )
  ) then
    raise exception 'raw collaborative-list identity column remains selectable';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants privilege
    where privilege.table_schema = 'public'
      and privilege.grantee = 'authenticated'
      and privilege.table_name in (
        'cafe_lists', 'cafe_list_members', 'cafe_list_items'
      )
      and privilege.privilege_type in (
        'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'
      )
  ) then
    raise exception 'direct collaborative-list mutation grant detected';
  end if;

  if exists (
    select 1
    from pg_class table_record
    join pg_namespace namespace on namespace.oid = table_record.relnamespace
    where namespace.nspname = 'public'
      and table_record.relname in (
        'cafe_lists', 'cafe_list_members', 'cafe_list_items'
      )
      and not table_record.relrowsecurity
  ) then
    raise exception 'collaborative-list table missing RLS';
  end if;

  foreach target_routine_name in array array[
    'list_cafe_lists_v2',
    'get_cafe_list_v2',
    'create_cafe_list_v2',
    'update_cafe_list_v2',
    'respond_cafe_list_invitation_v2',
    'cancel_cafe_list_invitation_v2',
    'set_cafe_list_member_role_v2',
    'remove_cafe_list_member_v2',
    'leave_cafe_list_v2',
    'transfer_cafe_list_ownership_v2',
    'delete_cafe_list_v2',
    'add_cafe_list_item_v2',
    'remove_cafe_list_item_v2',
    'move_cafe_list_item_v2'
  ] loop
    if not exists (
      select 1
      from information_schema.routine_privileges privilege
      where privilege.routine_schema = 'public'
        and privilege.routine_name = target_routine_name
        and privilege.grantee = 'authenticated'
        and privilege.privilege_type = 'EXECUTE'
    ) then
      raise exception 'authenticated execute grant missing for %', target_routine_name;
    end if;
    if exists (
      select 1
      from information_schema.routine_privileges privilege
      where privilege.routine_schema = 'public'
        and privilege.routine_name = target_routine_name
        and privilege.grantee in ('PUBLIC', 'anon')
        and privilege.privilege_type = 'EXECUTE'
    ) then
      raise exception 'anonymous execute grant detected for %', target_routine_name;
    end if;
  end loop;

  if exists (
    select 1
    from information_schema.routine_privileges privilege
    where privilege.routine_schema = 'public'
      and privilege.routine_name = 'add_cafe_list_item'
      and privilege.grantee in ('PUBLIC', 'anon', 'authenticated')
      and privilege.privilege_type = 'EXECUTE'
  ) then
    raise exception 'identity-bearing legacy cafe-list item RPC remains executable';
  end if;
  if pg_get_function_result(
    'public.add_cafe_list_item_v2(uuid,uuid,text)'::regprocedure
  ) <> 'boolean' then
    raise exception 'safe cafe-list item RPC must return a scalar result';
  end if;
  if exists (
    select 1
    from information_schema.routine_privileges privilege
    where privilege.routine_schema = 'public'
      and privilege.routine_name = 'move_cafe_list_item'
      and privilege.grantee in ('PUBLIC', 'anon', 'authenticated')
      and privilege.privilege_type = 'EXECUTE'
  ) then
    raise exception 'identity-bearing legacy cafe-list move RPC remains executable';
  end if;
  if pg_get_function_result(
    'public.move_cafe_list_item_v2(uuid,integer)'::regprocedure
  ) <> 'boolean' then
    raise exception 'safe cafe-list move RPC must return a scalar result';
  end if;
  if exists (
    select 1
    from information_schema.routine_privileges privilege
    where privilege.routine_schema = 'public'
      and privilege.routine_name = 'remove_cafe_list_item'
      and privilege.grantee in ('PUBLIC', 'anon', 'authenticated')
      and privilege.privilege_type = 'EXECUTE'
  ) then
    raise exception 'legacy cafe-list remove RPC remains executable';
  end if;
  if pg_get_function_result(
    'public.remove_cafe_list_item_v2(uuid)'::regprocedure
  ) <> 'boolean' then
    raise exception 'safe cafe-list remove RPC must return a scalar result';
  end if;

  foreach target_routine_name in array array[
    'can_view_cafe_list_as',
    'can_view_cafe_list_items_as',
    'can_edit_cafe_list_as',
    'can_manage_cafe_list_as',
    'cafe_list_profile_json_v2',
    'cafe_list_summary_json_v2'
  ] loop
    if exists (
      select 1
      from information_schema.routine_privileges privilege
      where privilege.routine_schema = 'private'
        and privilege.routine_name = target_routine_name
        and privilege.grantee in ('PUBLIC', 'anon', 'authenticated')
        and privilege.privilege_type = 'EXECUTE'
    ) then
      raise exception 'private helper is executable by clients: %', target_routine_name;
    end if;
  end loop;

  select pg_get_functiondef('public.get_cafe_list_v2(uuid)'::regprocedure)
  into definition;
  if definition not ilike '%auth.uid()%'
     or definition not ilike '%cafe_list_profile_json_v2%'
     or definition not ilike '%can_view_cafe_list_items_as%' then
    raise exception 'detail projection lost caller binding or identity masking';
  end if;

  select pg_get_functiondef(
    'public.invite_cafe_list_member(uuid,uuid,text)'::regprocedure
  ) into definition;
  if definition not ilike '%invitation_status = ''pending''%'
     or definition not ilike '%result.invitation_status = ''pending''%'
     or definition not ilike '%private.confirmed_friends%'
     or definition not ilike '%private.blocked_between%' then
    raise exception 'invitation function lost retry or relationship controls';
  end if;
end;
$$;

rollback;

select 'alpha_collaborative_cafe_lists_security_passed' as result;
