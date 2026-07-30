begin;

do $$
declare
  definition text;
  constraint_definition text;
  lifecycle_kind text;
begin
  select pg_get_constraintdef(constraint_record.oid)
  into constraint_definition
  from pg_constraint constraint_record
  where constraint_record.conrelid = 'public.activity_events'::regclass
    and constraint_record.conname = 'activity_events_kind_check';

  if constraint_definition is null then
    raise exception 'activity kind constraint is missing';
  end if;
  foreach lifecycle_kind in array array[
    'collaborative_list_invitation_accepted',
    'collaborative_list_invitation_declined',
    'collaborative_list_invitation_cancelled',
    'collaborative_list_role_changed',
    'collaborative_list_member_removed',
    'collaborative_list_member_left',
    'collaborative_list_ownership_transferred',
    'collaborative_list_deleted'
  ] loop
    if position(quote_literal(lifecycle_kind) in constraint_definition) = 0 then
      raise exception 'activity constraint is missing lifecycle kind %', lifecycle_kind;
    end if;
  end loop;

  select pg_get_functiondef(
    'private.activity_kind_push_enabled(uuid,text)'::regprocedure
  ) into definition;
  foreach lifecycle_kind in array array[
    'collaborative_list_invitation_accepted',
    'collaborative_list_invitation_declined',
    'collaborative_list_invitation_cancelled',
    'collaborative_list_role_changed',
    'collaborative_list_member_removed',
    'collaborative_list_member_left',
    'collaborative_list_ownership_transferred',
    'collaborative_list_deleted'
  ] loop
    if definition not ilike '%when ' || quote_literal(lifecycle_kind)
         || '%preference.collaborative_list_invitations%' then
      raise exception 'push preference mapping is missing for %', lifecycle_kind;
    end if;
  end loop;

  select pg_get_functiondef(
    'private.create_cafe_list_lifecycle_activity_v1(uuid,uuid,text,text,text,text,uuid,text,jsonb)'::regprocedure
  ) into definition;
  if definition not ilike '%p_recipient = p_actor%'
     or definition not ilike '%activity_recipient_is_eligible_v2(p_recipient)%'
     or definition not ilike '%can_socially_mutate_as(p_actor)%'
     or definition not ilike '%can_view_user_as(p_actor, p_recipient)%'
     or definition not ilike '%on conflict (recipient_id, dedupe_key) do nothing%'
     or definition not ilike '%''source'', ''cafe_list_lifecycle''%' then
    raise exception 'lifecycle creator lost eligibility, privacy, or idempotency controls';
  end if;

  select pg_get_functiondef(
    'private.activity_event_is_visible(public.activity_events,uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%p_event.recipient_id = p_viewer%'
     or definition not ilike '%p_event.suppressed_at is null%'
     or definition not ilike '%activity_recipient_is_eligible_v2(p_viewer)%'
     or definition not ilike '%can_view_user_as(p_event.actor_user_id, p_viewer)%'
     or definition not ilike '%when ''collaborative_list_deleted''%'
     or definition not ilike '%p_event.cafe_list_id is null%'
     or definition not ilike '%p_event.metadata ->> ''reason'' = ''list_deleted''%'
     or definition not ilike '%p_event.metadata ->> ''list_id'' is not null%'
     or definition not ilike '%p_event.metadata ->> ''source'' = ''cafe_list_lifecycle''%' then
    raise exception 'lifecycle visibility lost recipient, safety, or deleted-list controls';
  end if;

  select pg_get_functiondef(
    'private.activity_from_cafe_list_member_lifecycle_v1()'::regprocedure
  ) into definition;
  if definition not ilike '%actor = new.invited_by%'
     or definition not ilike '%old.invitation_status = ''pending''%'
     or definition not ilike '%collaborative_list_invitation_cancelled%'
     or definition not ilike '%collaborative_list_member_removed%'
     or definition not ilike '%collaborative_list_member_left%' then
    raise exception 'member lifecycle trigger lost transfer cancellation or departure handling';
  end if;

  select pg_get_functiondef(
    'private.activity_from_cafe_list_owner_lifecycle_v1()'::regprocedure
  ) into definition;
  if definition not ilike '%old.owner_id is distinct from new.owner_id%'
     or definition not ilike '%collaborative_list_ownership_transferred%'
     or definition not ilike '%collaborative_list_deleted%'
     or definition not ilike '%collaborative_list_invitation_cancelled%'
     or definition not ilike '%invitation_status in (''accepted'', ''pending'')%'
     or definition not ilike '%''reason'', ''list_deleted''%'
     or definition not ilike '%''list_id'', old.id%'
     or definition not ilike '%''list_title'', old.title%'
     or definition not ilike '%null, ''mugshot://activity''%' then
    raise exception 'owner lifecycle trigger lost transfer or detached deletion behavior';
  end if;

  select pg_get_functiondef(
    'public.transfer_cafe_list_ownership_v2(uuid,uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%auth.uid()%'
     or definition not ilike '%for update%'
     or definition not ilike '%can_manage_cafe_list_as(p_list_id, actor)%'
     or definition not ilike '%can_view_cafe_list_as(p_list_id, actor)%'
     or definition not ilike '%can_socially_mutate_as(p_new_owner_id)%'
     or definition not ilike '%can_view_user_as(p_new_owner_id, actor)%'
     or definition not ilike '%invitation_status = ''accepted''%'
     or definition not ilike '%receipt.ownership_epoch = target_list.ownership_epoch%'
     or definition not ilike '%receipt.previous_owner_id = actor%'
     or definition not ilike '%receipt.new_owner_id = p_new_owner_id%'
     or definition not ilike '%returning ownership_epoch into completed_epoch%'
     or definition not ilike '%insert into private.cafe_list_ownership_transfer_receipts%'
     or definition not ilike '%get diagnostics changed = row_count%'
     or definition not ilike '%if changed <> 1%'
     or position('update public.cafe_lists' in lower(definition)) = 0
     or position('delete from public.cafe_list_members' in lower(definition)) = 0
     or position('update public.cafe_lists' in lower(definition))
        > position('delete from public.cafe_list_members' in lower(definition)) then
    raise exception 'ownership transfer lost caller, successor, lock, or ordering controls';
  end if;

  if not exists (
    select 1
    from information_schema.columns column_record
    where column_record.table_schema = 'public'
      and column_record.table_name = 'cafe_lists'
      and column_record.column_name = 'ownership_epoch'
      and column_record.data_type = 'bigint'
      and column_record.is_nullable = 'NO'
  ) then
    raise exception 'cafe-list ownership epoch is missing or nullable';
  end if;

  select pg_get_functiondef(
    'private.advance_cafe_list_ownership_epoch_v1()'::regprocedure
  ) into definition;
  if definition not ilike '%new.owner_id is distinct from old.owner_id%'
     or definition not ilike '%new.ownership_epoch := old.ownership_epoch + 1%'
     or definition not ilike '%delete from private.cafe_list_ownership_transfer_receipts%'
     or definition not ilike '%new.ownership_epoch := old.ownership_epoch%' then
    raise exception 'ownership epoch is not server-maintained or does not invalidate stale receipts';
  end if;

  if not exists (
    select 1
    from pg_class table_record
    where table_record.oid =
      'private.cafe_list_ownership_transfer_receipts'::regclass
      and table_record.relrowsecurity
  ) then
    raise exception 'ownership transfer receipts are not protected by RLS';
  end if;

  select pg_get_functiondef(
    'public.revoke_cafe_list_member(uuid,uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%auth.uid()%'
     or definition not ilike '%for update%'
     or definition not ilike '%member_status = ''pending''%'
     or definition not ilike '%respond_cafe_list_invitation_v2(p_list_id, ''decline'')%'
     or definition not ilike '%member_status = ''accepted''%'
     or definition not ilike '%leave_cafe_list_v2(p_list_id)%'
     or definition not ilike '%cancel_cafe_list_invitation_v2(p_list_id, p_user_id)%' then
    raise exception 'legacy cafe-list revoke lost consent-preserving routing';
  end if;

  if not exists (
    select 1
    from pg_trigger trigger_record
    where trigger_record.tgrelid = 'public.cafe_list_members'::regclass
      and trigger_record.tgname = 'activity_from_cafe_list_member_lifecycle'
      and trigger_record.tgfoid =
        'private.activity_from_cafe_list_member_lifecycle_v1()'::regprocedure
      and not trigger_record.tgisinternal
  ) then
    raise exception 'member lifecycle trigger is not installed';
  end if;
  if not exists (
    select 1
    from pg_trigger trigger_record
    where trigger_record.tgrelid = 'public.cafe_lists'::regclass
      and trigger_record.tgname = 'activity_from_cafe_list_owner_lifecycle'
      and trigger_record.tgfoid =
        'private.activity_from_cafe_list_owner_lifecycle_v1()'::regprocedure
      and pg_get_triggerdef(trigger_record.oid) ilike '%after update of owner_id%'
      and not trigger_record.tgisinternal
  ) then
    raise exception 'owner-transfer lifecycle trigger is not installed after owner update';
  end if;
  if not exists (
    select 1
    from pg_trigger trigger_record
    where trigger_record.tgrelid = 'public.cafe_lists'::regclass
      and trigger_record.tgname = 'activity_from_cafe_list_deletion'
      and trigger_record.tgfoid =
        'private.activity_from_cafe_list_owner_lifecycle_v1()'::regprocedure
      and pg_get_triggerdef(trigger_record.oid) ilike '%before delete%'
      and not trigger_record.tgisinternal
  ) then
    raise exception 'list-deletion lifecycle trigger is not installed before delete';
  end if;
  if not exists (
    select 1
    from pg_trigger trigger_record
    where trigger_record.tgrelid = 'public.cafe_lists'::regclass
      and trigger_record.tgname = 'advance_cafe_list_ownership_epoch'
      and trigger_record.tgfoid =
        'private.advance_cafe_list_ownership_epoch_v1()'::regprocedure
      and pg_get_triggerdef(trigger_record.oid) ilike '%before update%'
      and not trigger_record.tgisinternal
  ) then
    raise exception 'ownership epoch trigger is not installed before owner changes';
  end if;

  if exists (
    select 1
    from information_schema.routine_privileges privilege
    where privilege.routine_schema = 'private'
      and privilege.routine_name in (
        'activity_kind_push_enabled',
        'activity_event_is_visible',
        'create_cafe_list_lifecycle_activity_v1',
        'activity_from_cafe_list_member_lifecycle_v1',
        'activity_from_cafe_list_owner_lifecycle_v1',
        'advance_cafe_list_ownership_epoch_v1'
      )
      and privilege.grantee in ('PUBLIC', 'anon', 'authenticated')
      and privilege.privilege_type = 'EXECUTE'
  ) then
    raise exception 'client can execute a private cafe-list lifecycle helper';
  end if;
  if exists (
    select 1
    from information_schema.table_privileges privilege
    where privilege.table_schema = 'private'
      and privilege.table_name = 'cafe_list_ownership_transfer_receipts'
      and privilege.grantee in ('PUBLIC', 'anon', 'authenticated')
  ) then
    raise exception 'client can read or mutate ownership transfer receipts';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.transfer_cafe_list_ownership_v2(uuid,uuid)',
    'EXECUTE'
  ) then
    raise exception 'authenticated transfer execute grant is missing';
  end if;
  if has_function_privilege(
    'anon',
    'public.transfer_cafe_list_ownership_v2(uuid,uuid)',
    'EXECUTE'
  ) or exists (
    select 1
    from information_schema.routine_privileges privilege
    where privilege.routine_schema = 'public'
      and privilege.routine_name = 'transfer_cafe_list_ownership_v2'
      and privilege.grantee = 'PUBLIC'
      and privilege.privilege_type = 'EXECUTE'
  ) then
    raise exception 'anonymous ownership transfer execution remains granted';
  end if;
  if not has_function_privilege(
    'authenticated',
    'public.revoke_cafe_list_member(uuid,uuid)',
    'EXECUTE'
  ) then
    raise exception 'authenticated legacy revoke compatibility grant is missing';
  end if;
  if has_function_privilege(
    'anon',
    'public.revoke_cafe_list_member(uuid,uuid)',
    'EXECUTE'
  ) or exists (
    select 1
    from information_schema.routine_privileges privilege
    where privilege.routine_schema = 'public'
      and privilege.routine_name = 'revoke_cafe_list_member'
      and privilege.grantee = 'PUBLIC'
      and privilege.privilege_type = 'EXECUTE'
  ) then
    raise exception 'anonymous legacy cafe-list revoke execution remains granted';
  end if;
end;
$$;

rollback;

select 'alpha_collaborative_list_activity_lifecycle_security_passed' as result;
