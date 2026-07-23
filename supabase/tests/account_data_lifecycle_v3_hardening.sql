\set ON_ERROR_STOP on

begin;

do $$
declare
  prepare_definition text := pg_get_functiondef(
    'public.prepare_account_deletion_v3(uuid,uuid,uuid,text,text,uuid,text)'::regprocedure
  );
  begin_step_up_definition text := pg_get_functiondef(
    'public.begin_account_deletion_step_up_v3(uuid,uuid,uuid,text,text)'::regprocedure
  );
  authorize_step_up_definition text := pg_get_functiondef(
    'public.authorize_account_deletion_step_up_v3(uuid,uuid,uuid,text,uuid,text,bigint,text)'::regprocedure
  );
  storage_preflight_definition text := pg_get_functiondef(
    'public.seal_account_deletion_storage_preflight_v3(uuid,uuid)'::regprocedure
  );
  storage_guard_definition text := pg_get_functiondef(
    'private.guard_account_storage_write_v3()'::regprocedure
  );
  storage_verify_definition text := pg_get_functiondef(
    'public.verify_account_storage_cleanup_v3(uuid)'::regprocedure
  );
  purge_definition text := pg_get_functiondef(
    'public.purge_account_deletion_security_receipts_v3()'::regprocedure
  );
  acknowledgement_definition text := pg_get_functiondef(
    'public.acknowledge_account_deletion_completion_v3(uuid,text,text)'::regprocedure
  );
  finalize_definition text := pg_get_functiondef(
    'public.finalize_account_collaboration_v3(uuid,uuid)'::regprocedure
  );
  completion_definition text := pg_get_functiondef(
    'public.mark_account_deletion_cleanup_completed_v3(uuid,uuid)'::regprocedure
  );
  pending_definition text := pg_get_functiondef(
    'public.mark_account_deletion_pending_v3(uuid,text,text,uuid)'::regprocedure
  );
  claim_definition text := pg_get_functiondef(
    'public.claim_account_deletion_jobs_v3(uuid,integer)'::regprocedure
  );
  renew_definition text := pg_get_functiondef(
    'public.renew_account_deletion_job_lease_v3(uuid,uuid)'::regprocedure
  );
  serialization_definition text := pg_get_functiondef(
    'private.serialize_account_collaboration_v3()'::regprocedure
  );
  pair_lock_definition text := pg_get_functiondef(
    'private.enforce_shared_member_pair_lock_v1()'::regprocedure
  );
  shared_recipe_definition text := pg_get_functiondef(
    'public.list_shared_recipes()'::regprocedure
  );
  signature text;
  trigger_name text;
begin
  if not exists (
    select 1 from pg_indexes
    where schemaname = 'private'
      and indexname = 'account_deletion_jobs_one_active_subject_v3'
      and indexdef ilike '%unique%status <> ''completed''%'
  ) then
    raise exception 'one-active-job subject invariant is missing';
  end if;

  if prepare_definition not ilike '%auth.sessions%created_at%15 minutes%'
     or prepare_definition not ilike '%lock table storage.objects%'
     or prepare_definition not ilike '%object_id%'
     or prepare_definition not ilike '%unsafe_account_storage_inventory%'
     or prepare_definition not ilike '%account_storage_mentions_subject_v3%'
     or prepare_definition not ilike '%account_storage_owner_is_exact_v3%'
     or prepare_definition not ilike '%step_up_authorization_required%'
     or prepare_definition not ilike '%consumed_at = now()%'
     or prepare_definition not ilike '%storage_manifest_frozen_at%'
     or prepare_definition not ilike '%successor_ids%'
     or prepare_definition not ilike '%array_agg(member.user_id order by%'
     or prepare_definition ilike '%delete from storage.objects%' then
    raise exception 'recent-session or exact Storage preparation boundary is missing';
  end if;

  if begin_step_up_definition not ilike '%initiating_session_id%'
     or begin_step_up_definition not ilike '%recovery_secret_hash%'
     or begin_step_up_definition not ilike '%subject_proof_hash%'
     or begin_step_up_definition not ilike '%interval ''5 minutes''%'
     or authorize_step_up_definition not ilike
       '%p_session_id = challenge.initiating_session_id%'
     or authorize_step_up_definition not ilike '%auth.sessions%'
     or authorize_step_up_definition not ilike '%authorized_amr_method%'
     or authorize_step_up_definition not ilike
       '%authenticated_at < date_trunc(''second'', challenge.issued_at)%'
     or authorize_step_up_definition not ilike '%interval ''2 minutes''%'
  then
    raise exception 'fresh-AMR, new-session deletion step-up is incomplete';
  end if;

  if storage_preflight_definition not ilike '%lock table storage.objects%'
     or storage_preflight_definition not ilike
       '%assert_account_deletion_lease_v3(p_job_id, p_lease_token)%'
     or storage_preflight_definition not ilike '%account_storage_mentions_subject_v3%'
     or storage_preflight_definition not ilike '%account_storage_owner_is_exact_v3%'
     or storage_preflight_definition not ilike '%storage_manifest_object_count%'
     or storage_guard_definition not ilike '%account_deletion_active_as(authoritative_subject)%'
     or storage_guard_definition not ilike
       '%account_deletion_storage_maintenance_job%'
     or storage_verify_definition ilike
       '%split_part(object.name, ''/'', 1)%'
  then
    raise exception 'owner-authoritative Storage freeze or empty-manifest guard is incomplete';
  end if;

  if finalize_definition not ilike '%jsonb_array_elements_text(successor_candidates)%'
     or finalize_definition not ilike '%lease_token = p_lease_token%'
     or finalize_definition not ilike '%can_socially_mutate_as(candidate)%'
     or finalize_definition not ilike '%account_deletion_active_as(candidate)%' then
    raise exception 'collaboration finalizer has no frozen successor chain';
  end if;

  if finalize_definition ilike '%order by%accepted_at%'
     or finalize_definition not ilike '%membership is removed only after ownership%'
     or finalize_definition not ilike '%invitation_status = ''pending''%' then
    raise exception 'collaboration finalizer does not consume the immutable plan safely';
  end if;

  if completion_definition not ilike '%storage_manifest = ''[]''::jsonb%'
     or completion_definition not ilike '%collaboration_manifest = ''{}''::jsonb%'
     or completion_definition not ilike '%storage_manifest_object_count = 0%'
     or completion_definition not ilike '%subject_id = null%'
     or completion_definition not ilike '%completion_receipt_fresh_until =%interval ''400 days''%'
     or completion_definition not ilike '%completion_proof_state = ''completed''%'
     or completion_definition not ilike '%receipt_expires_at = null%'
     or completion_definition not ilike '%lease_token = p_lease_token%'
     or completion_definition not ilike '%verify_account_storage_cleanup_v3%'
  then
    raise exception 'completed deletion receipts retain private manifests or subject identity';
  end if;

  if purge_definition not ilike '%interval ''1 day''%'
     or purge_definition not ilike '%completion_proof_state = ''expired_completed''%'
     or purge_definition not ilike '%completed_receipt_fresh_days%400%'
     or purge_definition not ilike '%until_local_cleanup_ack_plus_30_days%'
     or purge_definition not ilike '%recovery_capability_expires%false%'
     or purge_definition not ilike '%local_cleanup_acknowledged_at is not null%'
     or purge_definition not ilike '%receipt_expires_at <= now()%'
  then
    raise exception 'deletion security receipt retention is undefined';
  end if;

  if acknowledgement_definition not ilike '%status = ''completed''%'
     or acknowledgement_definition not ilike '%completion_proof_state in%'
     or acknowledgement_definition not ilike '%recovery_secret_hash = decode%'
     or acknowledgement_definition not ilike '%subject_proof_hash = decode%'
     or acknowledgement_definition not ilike '%local_cleanup_acknowledged_at%'
     or acknowledgement_definition not ilike '%interval ''30 days''%'
     or acknowledgement_definition not ilike '%''not_found''%' then
    raise exception 'capability-authenticated local-cleanup acknowledgement is incomplete';
  end if;

  if claim_definition not ilike '%limit 1%'
     or renew_definition not ilike '%lease_token = p_lease_token%'
     or renew_definition not ilike '%lease_expires_at > clock_timestamp()%'
     or pending_definition not ilike '%lease_token = p_lease_token%'
     or pending_definition not ilike '%lease_expires_at > clock_timestamp()%'
  then
    raise exception 'account deletion worker leases are not fully fenced';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgrelid = 'storage.objects'::regclass
      and tgname = 'guard_account_storage_write_v3'
      and not tgisinternal
  ) then
    raise exception 'Storage stale-token/deletion guard is missing';
  end if;

  if serialization_definition not ilike '%auth.uid()%'
     or serialization_definition not ilike '%tg_op = ''DELETE''%'
     or serialization_definition not ilike '%related_owners%'
     or serialization_definition not ilike '%monotonic_safety_exit%'
     or serialization_definition not ilike '%old.status = ''accepted''%new.status = ''left''%'
     or serialization_definition not ilike
       '%old.invitation_status = ''pending''%''declined'', ''cancelled''%'
     or serialization_definition not ilike
       '%collaboration plan is frozen by account deletion%'
     or serialization_definition not ilike '%return old%' then
    raise exception 'actor-aware immutable collaboration guard is incomplete';
  end if;

  if pair_lock_definition not ilike '%tg_op = ''UPDATE''%'
     or pair_lock_definition not ilike '%auth.uid()%is null%'
     or pair_lock_definition not ilike '%old.invited_by is not null%'
     or pair_lock_definition not ilike '%new.invited_by is null%'
     or pair_lock_definition not ilike '%new.status is not distinct from old.status%'
     or pair_lock_definition not ilike '%shared MugShot inviter is unavailable%' then
    raise exception 'shared MugShot inviter FK transition is not safely isolated';
  end if;

  if shared_recipe_definition not ilike '%can_project_recipe_version_as%'
     or shared_recipe_definition not ilike '%recipient_id =%auth.uid()%'
     or shared_recipe_definition ilike '%privateNotes%' then
    raise exception 'legacy shared-recipe inbox bypasses V3 projection enforcement';
  end if;

  if finalize_definition not ilike
       '%where id = planned_id and managed_by is null%' then
    raise exception 'deletion successor fallback can strand collaboration state';
  end if;

  foreach trigger_name in array array[
    'serialize_account_collaboration_lists_v3',
    'serialize_account_collaboration_list_members_v3',
    'serialize_account_shared_memories_v3',
    'serialize_account_shared_memory_members_v3'
  ] loop
    if not exists (
      select 1
      from pg_trigger trigger_row
      where trigger_row.tgname = trigger_name
        and not trigger_row.tgisinternal
        and pg_get_triggerdef(trigger_row.oid) ilike '%DELETE%'
    ) then
      raise exception 'collaboration DELETE serialization is missing: %', trigger_name;
    end if;
  end loop;

  foreach signature in array array[
    'public.begin_account_deletion_step_up_v3(uuid,uuid,uuid,text,text)',
    'public.authorize_account_deletion_step_up_v3(uuid,uuid,uuid,text,uuid,text,bigint,text)',
    'public.prepare_account_deletion_v3(uuid,uuid,uuid,text,text,uuid,text)',
    'public.read_account_deletion_job_v3(uuid)',
    'public.read_account_deletion_job_by_recovery_v3(uuid,text,text)',
    'public.claim_account_deletion_job_v3(uuid,uuid)',
    'public.renew_account_deletion_job_lease_v3(uuid,uuid)',
    'public.seal_account_deletion_storage_preflight_v3(uuid,uuid)',
    'public.revoke_account_sessions_v3(uuid,uuid)',
    'public.confirm_account_identity_deleted_v3(uuid,uuid)',
    'public.mark_account_deletion_identity_deleted_v3(uuid,uuid)',
    'public.detach_account_storage_ownership_v3(uuid,uuid)',
    'public.restore_account_storage_ownership_v3(uuid,uuid)',
    'public.finalize_account_collaboration_v3(uuid,uuid)',
    'public.mark_account_deletion_cleanup_completed_v3(uuid,uuid)',
    'public.mark_account_deletion_pending_v3(uuid,text,text,uuid)',
    'public.claim_account_deletion_jobs_v3(uuid,integer)',
    'public.acknowledge_account_deletion_completion_v3(uuid,text,text)',
    'public.purge_account_deletion_security_receipts_v3()'
  ] loop
    if has_function_privilege('authenticated', signature, 'EXECUTE')
       or not has_function_privilege('service_role', signature, 'EXECUTE') then
      raise exception 'V3 deletion function grant is unsafe: %', signature;
    end if;
  end loop;

  if not has_function_privilege(
    'authenticated', 'public.enforce_mugshot_live_session_v3()', 'EXECUTE'
  ) then
    raise exception 'PostgREST live-session hook cannot run for authenticated requests';
  end if;
end;
$$;

-- Behavior coverage for the race that matters: after owner A's plan is
-- frozen, user-context invitations, acceptances, and departures by B cannot
-- change list or shared MugShot succession. Auth-null cleanup remains valid
-- for FK cascades and the trusted finalizer.
do $$
declare
  identities uuid[];
  owner_id uuid;
  collaborator_id uuid;
  deletion_request_id uuid := gen_random_uuid();
  list_invite_id uuid;
  list_accept_id uuid;
  list_leave_id uuid;
  memory_invite_id uuid;
  memory_accept_id uuid;
  memory_leave_id uuid;
  failure_message text;
begin
  select array_agg(candidate.id order by candidate.id) into identities
  from (
    select profile.id
    from public.users profile
    join auth.users account on account.id = profile.id
    where account.deleted_at is null
      and not private.account_deletion_active_as(profile.id)
    order by profile.id
    limit 2
  ) candidate;
  if coalesce(array_length(identities, 1), 0) < 2 then
    raise exception 'collaboration freeze behavior requires two live test profiles';
  end if;
  owner_id := identities[1];
  collaborator_id := identities[2];

  insert into public.cafe_lists(owner_id, title)
  values (owner_id, 'V3 freeze invite') returning id into list_invite_id;
  insert into public.cafe_lists(owner_id, title)
  values (owner_id, 'V3 freeze accept') returning id into list_accept_id;
  insert into public.cafe_lists(owner_id, title)
  values (owner_id, 'V3 freeze leave') returning id into list_leave_id;
  insert into public.cafe_list_members(
    list_id, user_id, role, invitation_status, invited_by
  ) values (
    list_accept_id, collaborator_id, 'viewer', 'pending', owner_id
  );
  insert into public.cafe_list_members(
    list_id, user_id, role, invitation_status, invited_by,
    accepted_at, responded_at
  ) values (
    list_leave_id, collaborator_id, 'viewer', 'accepted', owner_id,
    now(), now()
  );

  insert into public.shared_memories(
    created_by, managed_by, context_type, location_label, occurred_at
  ) values (
    owner_id, owner_id, 'home', 'V3 freeze invite', now()
  ) returning id into memory_invite_id;
  insert into public.shared_memories(
    created_by, managed_by, context_type, location_label, occurred_at
  ) values (
    owner_id, owner_id, 'home', 'V3 freeze accept', now()
  ) returning id into memory_accept_id;
  insert into public.shared_memories(
    created_by, managed_by, context_type, location_label, occurred_at
  ) values (
    owner_id, owner_id, 'home', 'V3 freeze leave', now()
  ) returning id into memory_leave_id;
  insert into public.shared_memory_members(
    shared_memory_id, user_id, invited_by, status
  ) values (
    memory_accept_id, collaborator_id, owner_id, 'pending'
  );
  insert into public.shared_memory_members(
    shared_memory_id, user_id, invited_by, status, responded_at
  ) values (
    memory_leave_id, collaborator_id, owner_id, 'accepted', now()
  );

  insert into private.account_deletion_jobs(
    request_id, subject_id, protocol_version, status,
    authorized_session_id, authorized_at,
    step_up_challenge_id, recovery_secret_hash, subject_proof_hash,
    storage_manifest_frozen_at
  ) values (
    deletion_request_id, owner_id, 3, 'prepared', gen_random_uuid(), now(),
    gen_random_uuid(),
    decode(
      replace(deletion_request_id::text, '-', '')
        || replace(deletion_request_id::text, '-', ''),
      'hex'
    ),
    decode(
      replace(collaborator_id::text, '-', '')
        || replace(collaborator_id::text, '-', ''),
      'hex'
    ),
    now()
  );

  begin
    insert into storage.objects(id, bucket_id, name, owner, owner_id)
    values (
      gen_random_uuid(),
      'profile-media',
      owner_id::text || '/post-freeze-owned.jpg',
      owner_id,
      owner_id::text
    );
    raise exception 'empty-manifest post-freeze Storage write was accepted';
  exception when sqlstate '42501' then
    get stacked diagnostics failure_message = message_text;
    if failure_message <> 'account Storage writes are unavailable' then
      raise exception 'unexpected Storage freeze failure: %', failure_message;
    end if;
  end;

  perform set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', collaborator_id::text,
      'role', 'authenticated'
    )::text,
    true
  );

  begin
    insert into public.cafe_list_members(
      list_id, user_id, role, invitation_status, invited_by
    ) values (
      list_invite_id, collaborator_id, 'viewer', 'pending', collaborator_id
    );
    raise exception 'post-freeze cafe-list invitation was accepted';
  exception when sqlstate '55000' or sqlstate '42501' then
    get stacked diagnostics failure_message = message_text;
    if failure_message not in (
      'collaboration plan is frozen by account deletion',
      'cafe list invitation is unavailable'
    ) then
      raise exception 'unexpected cafe-list invitation failure: %', failure_message;
    end if;
  end;

  begin
    update public.cafe_list_members
    set invitation_status = 'accepted', accepted_at = now(), responded_at = now()
    where list_id = list_accept_id and user_id = collaborator_id;
    raise exception 'post-freeze cafe-list acceptance was accepted';
  exception when sqlstate '55000' or sqlstate '42501' then
    get stacked diagnostics failure_message = message_text;
    if failure_message not in (
      'collaboration plan is frozen by account deletion',
      'cafe list invitation is unavailable'
    ) then
      raise exception 'unexpected cafe-list acceptance failure: %', failure_message;
    end if;
  end;

  update public.cafe_list_members
  set invitation_status = 'declined', responded_at = now(), updated_at = now()
  where list_id = list_accept_id and user_id = collaborator_id;
  delete from public.cafe_list_members
  where list_id = list_leave_id and user_id = collaborator_id;

  begin
    insert into public.shared_memory_members(
      shared_memory_id, user_id, invited_by, status
    ) values (
      memory_invite_id, collaborator_id, collaborator_id, 'pending'
    );
    raise exception 'post-freeze shared MugShot invitation was accepted';
  exception when sqlstate '55000' or sqlstate '42501' then
    get stacked diagnostics failure_message = message_text;
    if failure_message not in (
      'collaboration plan is frozen by account deletion',
      'shared MugShot invitation is unavailable'
    ) then
      raise exception 'unexpected shared MugShot invitation failure: %', failure_message;
    end if;
  end;

  begin
    update public.shared_memory_members
    set status = 'accepted', responded_at = now()
    where shared_memory_id = memory_accept_id and user_id = collaborator_id;
    raise exception 'post-freeze shared MugShot acceptance was accepted';
  exception when sqlstate '55000' or sqlstate '42501' then
    get stacked diagnostics failure_message = message_text;
    if failure_message not in (
      'collaboration plan is frozen by account deletion',
      'shared MugShot invitation is unavailable'
    ) then
      raise exception 'unexpected shared MugShot acceptance failure: %', failure_message;
    end if;
  end;

  update public.shared_memory_members
  set status = 'declined', responded_at = now()
  where shared_memory_id = memory_accept_id and user_id = collaborator_id;
  delete from public.shared_memory_members
  where shared_memory_id = memory_leave_id and user_id = collaborator_id;

  if exists (
       select 1 from public.cafe_list_members
       where list_id = list_invite_id and user_id = collaborator_id
     )
     or not exists (
       select 1 from public.cafe_list_members
       where list_id = list_accept_id and user_id = collaborator_id
         and invitation_status = 'declined'
     )
     or exists (
       select 1 from public.cafe_list_members
       where list_id = list_leave_id and user_id = collaborator_id
     ) then
    raise exception 'cafe-list freeze or safety-exit state is incorrect';
  end if;

  if exists (
       select 1 from public.shared_memory_members
       where shared_memory_id = memory_invite_id and user_id = collaborator_id
     )
     or not exists (
       select 1 from public.shared_memory_members
       where shared_memory_id = memory_accept_id and user_id = collaborator_id
         and status = 'declined'
     )
     or exists (
       select 1 from public.shared_memory_members
       where shared_memory_id = memory_leave_id and user_id = collaborator_id
     ) then
    raise exception 'shared MugShot freeze or safety-exit state is incorrect';
  end if;

  perform set_config('request.jwt.claims', '{}'::jsonb::text, true);
  delete from public.cafe_list_members
  where list_id = list_accept_id and user_id = collaborator_id;
  delete from public.shared_memory_members
  where shared_memory_id = memory_accept_id and user_id = collaborator_id;
  if exists (
       select 1 from public.cafe_list_members
       where list_id = list_accept_id and user_id = collaborator_id
     )
     or exists (
       select 1 from public.shared_memory_members
       where shared_memory_id = memory_accept_id and user_id = collaborator_id
     ) then
    raise exception 'auth-null collaboration cleanup was blocked';
  end if;
end;
$$;

rollback;

select 'account_data_lifecycle_v3_hardening_passed' as result;
