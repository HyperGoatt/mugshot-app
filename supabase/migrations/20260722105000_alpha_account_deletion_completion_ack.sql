begin;

-- A completed deletion remains recoverable until the device confirms that its
-- own account-scoped cleanup has finished. That confirmation is authenticated
-- by the same high-entropy recovery capability that survived Auth deletion.
-- The minimized tombstone then has a bounded grace period for lost responses
-- and multi-launch retries before the scheduled worker removes it.

alter table private.account_deletion_jobs
  add column if not exists local_cleanup_acknowledged_at timestamptz;

alter table private.account_deletion_jobs
  drop constraint if exists account_deletion_jobs_ack_retention_check;
alter table private.account_deletion_jobs
  add constraint account_deletion_jobs_ack_retention_check check (
    local_cleanup_acknowledged_at is null
    or (
      status = 'completed'
      and receipt_expires_at is not null
      and receipt_expires_at >= local_cleanup_acknowledged_at + interval '30 days'
    )
  );

create or replace function public.acknowledge_account_deletion_completion_v3(
  p_request_id uuid,
  p_recovery_hash text,
  p_subject_proof_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  acknowledged private.account_deletion_jobs%rowtype;
begin
  if p_request_id is null
     or p_recovery_hash !~ '^[0-9a-f]{64}$'
     or p_subject_proof_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid deletion acknowledgement' using errcode = '22023';
  end if;

  update private.account_deletion_jobs job
  set
    local_cleanup_acknowledged_at = coalesce(
      job.local_cleanup_acknowledged_at,
      clock_timestamp()
    ),
    receipt_expires_at = coalesce(
      job.receipt_expires_at,
      clock_timestamp() + interval '30 days'
    ),
    updated_at = now()
  where job.protocol_version = 3
    and job.request_id = p_request_id
    and job.status = 'completed'
    and job.completion_proof_state in ('completed', 'expired_completed')
    and job.recovery_secret_hash = decode(p_recovery_hash, 'hex')
    and job.subject_proof_hash = decode(p_subject_proof_hash, 'hex')
  returning job.* into acknowledged;

  if not found then
    -- Do not disclose whether the request, subject proof, or capability was
    -- wrong. A previously acknowledged tombstone may also have been purged.
    return jsonb_build_object(
      'acknowledged', false,
      'status', 'not_found'
    );
  end if;

  return jsonb_build_object(
    'acknowledged', true,
    'status', 'acknowledged',
    'request_id', acknowledged.request_id,
    'receipt_expires_at', acknowledged.receipt_expires_at,
    'final_retention_days', 30
  );
end;
$$;

create or replace function public.purge_account_deletion_security_receipts_v3()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  purged_challenges integer := 0;
  expired_completion_proofs integer := 0;
  purged_receipts integer := 0;
begin
  delete from private.account_deletion_step_up_challenges challenge
  where greatest(
    challenge.expires_at,
    coalesce(challenge.authorization_expires_at, challenge.expires_at),
    coalesce(challenge.consumed_at, challenge.expires_at)
  ) <= now() - interval '1 day';
  get diagnostics purged_challenges = row_count;

  update private.account_deletion_jobs job
  set completion_proof_state = 'expired_completed', updated_at = now()
  where job.status = 'completed'
    and job.completion_proof_state = 'completed'
    and job.completion_receipt_fresh_until is not null
    and job.completion_receipt_fresh_until <= now();
  get diagnostics expired_completion_proofs = row_count;

  delete from private.account_deletion_jobs job
  where job.status = 'completed'
    and job.local_cleanup_acknowledged_at is not null
    and job.receipt_expires_at is not null
    and job.receipt_expires_at <= now();
  get diagnostics purged_receipts = row_count;

  return jsonb_build_object(
    'purged_challenges', purged_challenges,
    'expired_completion_proofs', expired_completion_proofs,
    'purged_receipts', purged_receipts,
    'completed_receipt_fresh_days', 400,
    'completed_tombstone_retention',
      'until_local_cleanup_ack_plus_30_days',
    'recovery_capability_expires', false,
    'recovery_capability_expires_after_local_acknowledgement', true,
    'final_retention_days', 30,
    'step_up_evidence_retention_days', 1
  );
end;
$$;

revoke all on function public.acknowledge_account_deletion_completion_v3(
  uuid,text,text
) from public, anon, authenticated, service_role;
revoke all on function public.purge_account_deletion_security_receipts_v3()
  from public, anon, authenticated, service_role;
grant execute on function public.acknowledge_account_deletion_completion_v3(
  uuid,text,text
) to service_role;
grant execute on function public.purge_account_deletion_security_receipts_v3()
  to service_role;

comment on function public.acknowledge_account_deletion_completion_v3(
  uuid,text,text
) is
  'Service-only, recovery-capability-authenticated acknowledgement that device cleanup succeeded; starts a 30-day lost-response grace period before the minimized deletion tombstone is purged.';
comment on column private.account_deletion_jobs.local_cleanup_acknowledged_at is
  'Set only after a capability-authenticated device confirms its account-scoped local purge completed.';
comment on column private.account_deletion_jobs.receipt_expires_at is
  'For completed V3 jobs, set to 30 days after local cleanup acknowledgement; null preserves recovery indefinitely until acknowledgement.';

commit;
