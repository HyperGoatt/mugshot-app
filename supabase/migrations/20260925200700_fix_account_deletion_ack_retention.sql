begin;

-- Use one timestamp for the acknowledgement and the start of its retention
-- period. Two clock_timestamp() calls can differ by microseconds and violate
-- account_deletion_jobs_ack_retention_check after identity deletion succeeded.
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
  acknowledgement_time timestamptz := clock_timestamp();
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
      acknowledgement_time
    ),
    receipt_expires_at = greatest(
      coalesce(job.receipt_expires_at, '-infinity'::timestamptz),
      coalesce(job.local_cleanup_acknowledged_at, acknowledgement_time)
        + interval '30 days'
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

commit;
