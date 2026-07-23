\set ON_ERROR_STOP on

begin;

do $$
declare
  signature text;
  trigger_name text;
  receipt_fields text[];
begin
  if has_table_privilege(
    'authenticated', 'private.report_client_receipts', 'SELECT'
  ) or has_table_privilege(
    'authenticated', 'private.report_client_receipts', 'INSERT'
  ) or has_table_privilege(
    'anon', 'private.report_client_receipts', 'SELECT'
  ) then
    raise exception 'private report idempotency aliases are client accessible';
  end if;

  select array_agg(attribute.attname order by attribute.attnum)
  into receipt_fields
  from pg_type type_row
  join pg_namespace namespace on namespace.oid = type_row.typnamespace
  join pg_class relation on relation.oid = type_row.typrelid
  join pg_attribute attribute on attribute.attrelid = relation.oid
  where namespace.nspname = 'public'
    and type_row.typname = 'report_submission_receipt_v1'
    and attribute.attnum > 0
    and not attribute.attisdropped;

  if receipt_fields is distinct from array[
    'id', 'status', 'created_at', 'closed_at', 'resolution_code'
  ]::text[] then
    raise exception 'report submission receipt is not strictly allowlisted: %',
      receipt_fields;
  end if;

  if pg_get_function_result(
    'public.submit_report_v2(uuid,public.report_reason,text,uuid,text)'::regprocedure
  ) not ilike '%report_submission_receipt_v1'
     or pg_get_function_result(
       'public.submit_report(public.report_reason,text,uuid,uuid,uuid)'::regprocedure
     ) not ilike '%report_submission_receipt_v1' then
    raise exception 'a report endpoint still returns the raw report row';
  end if;

  foreach signature in array array[
    'private.is_live_account_as(uuid)',
    'private.social_pair_lock_key_v1(uuid,uuid)',
    'private.lock_social_pairs_v1(uuid,uuid[],boolean)',
    'private.safe_report_submission_receipt_v1(public.reports)',
    'private.lock_report_submission_actor_v1(uuid)',
    'private.enforce_moderation_action_report_subject_v1()',
    'private.enforce_moderation_action_admin_update_v1()',
    'private.enforce_moderation_appeal_operator_role_v1()'
  ] loop
    if has_function_privilege('authenticated', signature, 'EXECUTE')
       or has_function_privilege('anon', signature, 'EXECUTE') then
      raise exception 'private hardening helper is client executable: %', signature;
    end if;
  end loop;

  if pg_get_functiondef(
       'private.can_socially_mutate_as(uuid)'::regprocedure
     ) not ilike '%is_live_account_as%'
     or pg_get_functiondef(
       'private.can_view_user_as(uuid,uuid)'::regprocedure
     ) not ilike '%is_live_account_as%'
     or pg_get_functiondef(
       'private.can_view_visit_as(uuid,uuid)'::regprocedure
     ) not ilike '%is_live_account_as%'
     or pg_get_functiondef(
       'private.can_view_comment_as(uuid,uuid)'::regprocedure
     ) not ilike '%is_live_account_as%'
     or pg_get_functiondef(
       'private.can_view_shared_memory_as(uuid,uuid)'::regprocedure
     ) not ilike '%is_live_account_as%' then
    raise exception 'a central social/view helper lacks the live-account gate';
  end if;

  if pg_get_functiondef(
       'public.attach_shared_memory_contribution_v1(uuid,uuid)'::regprocedure
     ) not ilike '%can_socially_mutate_as%' then
    raise exception 'shared MugShot attachment bypassed social enforcement';
  end if;

  foreach trigger_name in array array[
    'enforce_user_block_pair_lock',
    'enforce_friend_pair_lock',
    'enforce_friend_request_pair_lock',
    'enforce_like_pair_lock',
    'enforce_reaction_pair_lock',
    'enforce_comment_pair_lock',
    'enforce_comment_mention_pair_lock',
    'enforce_visit_companion_pair_lock',
    'enforce_recommendation_pair_lock',
    'enforce_shared_member_pair_lock',
    'enforce_moderation_action_report_subject',
    'enforce_moderation_action_admin_update',
    'enforce_moderation_appeal_operator_role'
  ] loop
    if not exists (
      select 1 from pg_trigger trigger_row
      where trigger_row.tgname = trigger_name
        and not trigger_row.tgisinternal
    ) then
      raise exception 'hardening trigger is missing: %', trigger_name;
    end if;
  end loop;

  if pg_get_functiondef(
       'private.lock_social_pairs_v1(uuid,uuid[],boolean)'::regprocedure
     ) not ilike '%pg_advisory_xact_lock%'
     or pg_get_functiondef(
       'private.lock_social_pairs_v1(uuid,uuid[],boolean)'::regprocedure
     ) not ilike '%hashtextextended%'
     or pg_get_functiondef(
       'public.block_user_v2(uuid,boolean)'::regprocedure
     ) not ilike '%pg_advisory_xact_lock%'
     or pg_get_functiondef(
       'public.block_user_v2(uuid,boolean)'::regprocedure
     ) not ilike '%hashtextextended%' then
    raise exception 'blocking and social writes do not share canonical locks';
  end if;

  if has_function_privilege(
    'anon',
    'public.submit_report_v2(uuid,public.report_reason,text,uuid,text)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.submit_report_v2(uuid,public.report_reason,text,uuid,text)',
    'EXECUTE'
  ) then
    raise exception 'sealed report submission grants are incorrect';
  end if;
end;
$$;

rollback;

select 'alpha_moderation_integrity_hardening_security_passed' as result;
