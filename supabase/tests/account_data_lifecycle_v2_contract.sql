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
  subject uuid;
  memory_id uuid;
  assignment_target_id uuid;
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
     or finalize_definition not ilike '%member.status = ''accepted''%'
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

  if not exists (
    select 1
    from information_schema.columns column_row
    where column_row.table_schema = 'public'
      and column_row.table_name = 'shared_memories'
      and column_row.column_name = 'managed_by'
      and column_row.is_nullable = 'YES'
  ) then
    raise exception 'shared memory stewardship column is missing';
  end if;

  select profile.id into subject
  from public.users profile
  where not exists (
    select 1
    from private.account_deletion_jobs job
    where job.subject_id = profile.id
      and job.identity_deleted_at is null
      and job.status in ('prepared', 'identity_deletion_pending')
  )
  order by profile.id
  limit 1;
  if subject is null then
    raise exception 'cascade guard contract requires one live test profile';
  end if;

  insert into public.shared_memories (
    created_by, managed_by, context_type, location_label, occurred_at
  ) values (
    subject, subject, 'home', 'Lifecycle contract', now()
  ) returning id into memory_id;
  insert into private.account_deletion_jobs (request_id, subject_id)
  values (gen_random_uuid(), subject);

  -- PostgreSQL may apply these SET NULL FKs as separate updates. Both must be
  -- accepted even though the other old pointer still names the deleting user.
  update public.shared_memories set created_by = null where id = memory_id;
  update public.shared_memories set managed_by = null where id = memory_id;
  if exists (
    select 1 from public.shared_memories memory
    where memory.id = memory_id
      and (memory.created_by is not null or memory.managed_by is not null)
  ) then
    raise exception 'separate shared-memory SET NULL transitions were blocked';
  end if;

  insert into public.shared_memories (
    created_by, managed_by, context_type, location_label, occurred_at
  ) values (
    null, null, 'home', 'Assignment guard contract', now()
  ) returning id into assignment_target_id;
  begin
    update public.shared_memories
    set managed_by = subject
    where id = assignment_target_id;
    raise exception 'deleting subject was assigned as a new steward';
  exception when sqlstate '55000' then null;
  end;

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
     or export_definition not ilike '%complete_as_of_schema_version_2%'
     or export_definition not ilike '%build_owner_activity_export_v1%'
     or export_definition not ilike '%visit-photos-private%'
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
