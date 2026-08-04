\set ON_ERROR_STOP on

begin;

do $$
declare
  prepare_definition text := pg_get_functiondef(
    'public.prepare_account_deletion_v2(uuid,uuid)'::regprocedure
  );
  finalize_definition text := pg_get_functiondef(
    'public.finalize_account_collaboration_v2(uuid)'::regprocedure
  );
  export_definition text := pg_get_functiondef(
    'public.build_owner_data_export_v2()'::regprocedure
  );
  signature text;
begin
  if exists (
    select 1
    from pg_constraint constraint_row
    where constraint_row.conrelid = 'private.account_deletion_jobs'::regclass
      and constraint_row.contype = 'f'
  ) then
    raise exception 'deletion jobs must survive identity cascades without FKs';
  end if;

  if has_schema_privilege('authenticated', 'private', 'USAGE')
     or has_table_privilege(
       'authenticated',
       'private.account_deletion_jobs',
       'SELECT'
     ) then
    raise exception 'private deletion receipts are client-readable';
  end if;

  if prepare_definition ilike '%update public.cafe_lists%'
     or prepare_definition ilike '%update public.shared_memories%'
     or prepare_definition ilike '%update storage.objects%'
     or prepare_definition ilike '%delete from public.%'
     or prepare_definition ilike '%delete from storage.%' then
    raise exception 'deletion preparation is not immutable/read-only';
  end if;
  if prepare_definition not ilike '%visit-photos-private%'
     or prepare_definition not ilike '%collaboration_manifest%' then
    raise exception 'deletion plan omits private media or collaboration';
  end if;

  if finalize_definition not ilike '%invitation_status = ''accepted''%'
     or finalize_definition ilike '%set invited_by =%'
     or finalize_definition ilike '%set contributor_id =%'
     or finalize_definition ilike '%set created_by =%' then
    raise exception 'finalization falsifies attribution or skips live succession';
  end if;

  if (
    select count(*)
    from pg_constraint constraint_row
    where constraint_row.conname in (
      'cafe_lists_owner_id_fkey',
      'cafe_list_members_invited_by_fkey',
      'cafe_list_items_contributor_id_fkey'
    )
      and constraint_row.confdeltype = 'n'
  ) <> 3 then
    raise exception 'collaborative cafe attribution must use ON DELETE SET NULL';
  end if;

  if exists (
    select 1 from pg_trigger trigger_row
    join pg_class relation on relation.oid = trigger_row.tgrelid
    where not trigger_row.tgisinternal
      and relation.relname in (
        'shared_memories', 'shared_memory_members', 'shared_memory_contributions'
      )
  ) then
    raise exception 'retired Shared Mugshot lifecycle trigger remains';
  end if;

  foreach signature in array array[
    'public.prepare_account_deletion_v2(uuid,uuid)',
    'public.detach_account_storage_ownership_v2(uuid)',
    'public.restore_account_storage_ownership_v2(uuid)',
    'public.finalize_account_collaboration_v2(uuid)',
    'public.read_account_deletion_job_v2(uuid)',
    'public.confirm_account_identity_deleted_v2(uuid)',
    'public.mark_account_deletion_identity_deleted_v2(uuid)',
    'public.mark_account_deletion_cleanup_completed_v2(uuid)'
  ] loop
    if has_function_privilege('authenticated', signature, 'EXECUTE')
       or not has_function_privilege('service_role', signature, 'EXECUTE') then
      raise exception 'service-role deletion RPC privilege is unsafe: %', signature;
    end if;
  end loop;

  if export_definition not ilike '%auth.uid()%'
     or export_definition not ilike '%build_owner_data_export_with_retired_shared_v2%'
     or export_definition not ilike '%created_shared_memories%'
     or export_definition not ilike '%visit_tags_added_or_received%'
     or export_definition ilike '%device.push_token%'
     or export_definition ilike '%device.id%' then
    raise exception 'owner export is unsealed, incomplete, or exposes device secrets';
  end if;

  if has_function_privilege(
       'anon',
       'public.build_owner_data_export_v2()',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.build_owner_data_export_v2()',
       'EXECUTE'
     ) then
    raise exception 'owner export grants are incorrect';
  end if;
end;
$$;

rollback;

select 'account_data_lifecycle_v2_contract_passed' as result;
