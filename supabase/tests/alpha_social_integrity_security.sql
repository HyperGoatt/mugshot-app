\set ON_ERROR_STOP on

begin;

do $$
declare
  function_signature text;
  private_signature text;
begin
  if has_schema_privilege('anon', 'private', 'USAGE')
     or has_schema_privilege('authenticated', 'private', 'USAGE') then
    raise exception 'private moderation schema is client accessible';
  end if;

  if exists (
    select 1
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'private'
      and relation.relname in (
        'moderation_operators', 'moderation_case_events', 'moderation_actions'
      )
      and not relation.relrowsecurity
  ) then
    raise exception 'a private moderation table is missing RLS';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants grant_row
    where grant_row.table_schema = 'private'
      and grant_row.table_name in (
        'moderation_operators', 'moderation_case_events', 'moderation_actions'
      )
      and grant_row.grantee in ('PUBLIC', 'anon', 'authenticated')
  ) then
    raise exception 'a private moderation table has a client grant';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants grant_row
    where grant_row.table_schema = 'public'
      and grant_row.table_name in (
        'shared_memories', 'shared_memory_members',
        'shared_memory_contributions'
      )
      and grant_row.grantee in ('PUBLIC', 'anon', 'authenticated')
  ) then
    raise exception 'raw shared-memory tables are client accessible';
  end if;

  if not exists (
    select 1
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'reports'
      and column_row.column_name = 'reporter_subject_id'
      and column_row.is_nullable = 'NO'
  ) or not exists (
    select 1
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'reports'
      and column_row.column_name = 'target_snapshot'
      and column_row.data_type = 'jsonb'
  ) then
    raise exception 'durable report evidence columns are incomplete';
  end if;

  if (
    select count(*)
    from pg_constraint constraint_row
    join pg_class relation on relation.oid = constraint_row.conrelid
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'reports'
      and constraint_row.conname in (
        'reports_reporter_id_fkey',
        'reports_target_user_id_fkey',
        'reports_target_visit_id_fkey',
        'reports_target_comment_id_fkey'
      )
      and constraint_row.confdeltype = 'n'
  ) <> 4 then
    raise exception 'report retention foreign keys are not ON DELETE SET NULL';
  end if;

  if not exists (
    select 1
    from pg_indexes index_row
    where index_row.schemaname = 'public'
      and index_row.indexname = 'reports_reporter_client_receipt_idx'
      and index_row.indexdef ilike '%unique%'
  ) then
    raise exception 'idempotent report receipt index is missing';
  end if;

  if not exists (
    select 1
    from pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.reports'::regclass
      and trigger_row.tgname = 'reports_evidence_is_immutable'
      and not trigger_row.tgisinternal
  ) then
    raise exception 'report evidence immutability trigger is missing';
  end if;

  if has_table_privilege('authenticated', 'public.reports', 'INSERT')
     or has_table_privilege('authenticated', 'public.reports', 'UPDATE')
     or has_table_privilege('authenticated', 'public.reports', 'DELETE')
     or has_table_privilege('authenticated', 'public.reports', 'SELECT') then
    raise exception 'reports retain a direct client table grant';
  end if;

  if has_table_privilege('authenticated', 'public.comments', 'INSERT')
     or has_table_privilege('authenticated', 'public.comments', 'UPDATE')
     or has_table_privilege('authenticated', 'public.comments', 'DELETE') then
    raise exception 'comments retain a direct client mutation grant';
  end if;

  if not exists (
    select 1
    from pg_policies policy
    where policy.schemaname = 'public'
      and policy.tablename = 'comments'
      and policy.policyname = 'Visible comments'
      and policy.qual ilike '%can_view_comment%'
  ) then
    raise exception 'comment visibility is not removal/moderation aware';
  end if;

  if (
    select count(*)
    from pg_policies policy
    where policy.schemaname = 'public'
      and policy.tablename = 'visits'
      and policy.policyname in ('Owners create visits', 'Owners update visits')
      and policy.with_check ilike '%can_socially_mutate%'
  ) <> 2 then
    raise exception 'shared visit publishing is not moderation aware';
  end if;

  foreach function_signature in array array[
    'public.submit_report_v2(uuid,public.report_reason,text,uuid,text)',
    'public.submit_report(public.report_reason,text,uuid,uuid,uuid)',
    'public.get_report_receipt_v1(uuid)',
    'public.review_report_v1(uuid,public.report_status,text,text,text,text,uuid,timestamp with time zone)',
    'public.revoke_moderation_action_v1(uuid,text)',
    'public.create_comment(uuid,text,uuid,uuid[])',
    'public.update_comment_v1(uuid,text)',
    'public.remove_comment_v1(uuid,text)',
    'public.block_user_v2(uuid,boolean)',
    'public.block_user(uuid)',
    'public.set_visit_tags_v1(uuid,uuid[])',
    'public.create_shared_memory_invitations_v1(uuid,uuid[])',
    'public.respond_shared_memory_invitation_v1(uuid,boolean)',
    'public.attach_shared_memory_contribution_v1(uuid,uuid)',
    'public.send_friend_request(uuid)',
    'public.respond_friend_request(uuid,boolean)',
    'public.send_trusted_recommendation(uuid,text,uuid,text)',
    'public.set_visit_companions(uuid,uuid[])'
  ] loop
    if not has_function_privilege('authenticated', function_signature, 'EXECUTE') then
      raise exception 'authenticated role cannot execute %', function_signature;
    end if;
    if has_function_privilege('anon', function_signature, 'EXECUTE') then
      raise exception 'anon role can execute %', function_signature;
    end if;
  end loop;

  if exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'submit_report_v2', 'submit_report', 'get_report_receipt_v1',
        'review_report_v1', 'revoke_moderation_action_v1',
        'create_comment', 'update_comment_v1', 'remove_comment_v1',
        'block_user_v2', 'block_user', 'can_view_user',
        'can_view_visit', 'can_view_comment', 'can_socially_mutate',
        'set_visit_tags_v1', 'create_shared_memory_invitations_v1',
        'respond_shared_memory_invitation_v1',
        'attach_shared_memory_contribution_v1', 'send_friend_request',
        'respond_friend_request', 'send_trusted_recommendation',
        'set_visit_companions'
      )
      and (
        not procedure.prosecdef
        or not coalesce(procedure.proconfig @> array['search_path=""'], false)
      )
  ) then
    raise exception 'a public social integrity function lacks SECURITY DEFINER or an empty search_path';
  end if;

  foreach private_signature in array array[
    'private.has_active_moderation_action(text,uuid,text[],timestamp with time zone)',
    'private.can_socially_mutate_as(uuid)',
    'private.can_view_user_as(uuid,uuid)',
    'private.can_view_visit_as(uuid,uuid)',
    'private.can_view_comment_as(uuid,uuid)',
    'private.submit_report_internal(uuid,public.report_reason,text,text,uuid,uuid,boolean)',
    'private.set_visit_tags_v1(uuid,uuid[])',
    'private.create_shared_memory_invitations_v1(uuid,uuid[])',
    'private.respond_shared_memory_invitation_v1(uuid,boolean)',
    'private.attach_shared_memory_contribution_v1(uuid,uuid)',
    'private.send_friend_request(uuid)',
    'private.respond_friend_request(uuid,boolean)',
    'private.send_trusted_recommendation(uuid,text,uuid,text)',
    'private.set_visit_companions(uuid,uuid[])'
  ] loop
    if has_function_privilege('anon', private_signature, 'EXECUTE')
       or has_function_privilege('authenticated', private_signature, 'EXECUTE') then
      raise exception 'private helper remains client executable: %', private_signature;
    end if;
  end loop;
end;
$$;

rollback;

select 'alpha_social_integrity_security_passed' as result;
