\set ON_ERROR_STOP on

begin;

do $$
declare
  signature text;
begin
  if has_table_privilege('authenticated', 'public.reports', 'SELECT') then
    raise exception 'authenticated clients can read raw report evidence';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants grant_row
    where grant_row.table_schema = 'private'
      and grant_row.table_name in (
        'moderation_appeals', 'moderation_appeal_events'
      )
      and grant_row.grantee in ('PUBLIC', 'anon', 'authenticated')
  ) then
    raise exception 'private appeal tables have a client grant';
  end if;

  if exists (
    select 1
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'private'
      and relation.relname in ('moderation_appeals', 'moderation_appeal_events')
      and not relation.relrowsecurity
  ) then
    raise exception 'a private appeal table is missing RLS';
  end if;

  foreach signature in array array[
    'public.get_my_enforcement_state_v1()',
    'public.submit_moderation_appeal_v1(uuid,uuid,text)',
    'public.review_moderation_appeal_v1(uuid,text,text,text,timestamp with time zone)',
    'public.list_my_report_receipts_v1(integer,timestamp with time zone,uuid)',
    'public.build_owner_enforcement_export_v1()'
  ] loop
    if not has_function_privilege('authenticated', signature, 'EXECUTE') then
      raise exception 'authenticated role cannot execute %', signature;
    end if;
    if has_function_privilege('anon', signature, 'EXECUTE') then
      raise exception 'anon role can execute %', signature;
    end if;
  end loop;

  if exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'get_my_enforcement_state_v1',
        'submit_moderation_appeal_v1',
        'review_moderation_appeal_v1',
        'list_my_report_receipts_v1',
        'build_owner_enforcement_export_v1'
      )
      and (
        not procedure.prosecdef
        or not coalesce(procedure.proconfig @> array['search_path=""'], false)
      )
  ) then
    raise exception 'an enforcement function lacks a hardened execution context';
  end if;

  if has_function_privilege(
    'authenticated',
    'private.owns_moderation_subject_as(text,uuid,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'anon',
    'private.owns_moderation_subject_as(text,uuid,uuid)',
    'EXECUTE'
  ) or has_function_privilege(
    'authenticated',
    'private.assign_moderation_action_subject_owner()',
    'EXECUTE'
  ) or has_function_privilege(
    'anon',
    'private.assign_moderation_action_subject_owner()',
    'EXECUTE'
  ) then
    raise exception 'private action-ownership helper is client executable';
  end if;

  if exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'get_my_enforcement_state_v1', 'list_my_report_receipts_v1'
      )
      and pg_get_function_result(procedure.oid) ~* (
        'reporter_id|reporter_subject_id|reviewed_by|reviewer_id|'
        'target_snapshot|details|statement|internal_note|subject_owner_id'
      )
  ) then
    raise exception 'a caller projection exposes private moderation fields';
  end if;
end;
$$;

rollback;

select 'alpha_enforcement_transparency_security_passed' as result;
