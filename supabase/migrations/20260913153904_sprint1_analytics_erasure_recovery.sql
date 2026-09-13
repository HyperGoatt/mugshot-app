begin;
-- Service-only recovery never overrides identity mapping or provider evidence.
create table private.account_analytics_erasure_recoveries (
  operation_id uuid primary key,
  request_id uuid not null references private.account_analytics_erasures(request_id) on delete cascade,
  previous_attempts integer not null check (previous_attempts between 0 and 30),
  previous_updated_at timestamptz not null,
  reason text not null check (reason in ('provider_restored', 'configuration_repaired', 'identity_mapping_reviewed')),
  created_at timestamptz not null default now()
);
alter table private.account_analytics_erasure_recoveries enable row level security;
revoke all on private.account_analytics_erasure_recoveries from public, anon, authenticated;
create index account_analytics_erasure_recoveries_request
  on private.account_analytics_erasure_recoveries(request_id);

create function public.retry_account_analytics_erasure_v1(
  p_request_id uuid, p_operation_id uuid, p_expected_updated_at timestamptz, p_reason text
) returns text language plpgsql security definer set search_path = '' as $$
declare
  target private.account_analytics_erasures;
  receipt private.account_analytics_erasure_recoveries;
begin
  if p_request_id is null or p_operation_id is null or p_expected_updated_at is null
     or p_reason is null or p_reason not in
       ('provider_restored', 'configuration_repaired', 'identity_mapping_reviewed') then
    raise exception 'invalid recovery request' using errcode = '22023';
  end if;
  select * into target from private.account_analytics_erasures
    where request_id = p_request_id for update;
  if not found then return 'unavailable'; end if;
  select * into receipt from private.account_analytics_erasure_recoveries
    where operation_id = p_operation_id;
  if found then
    if receipt.request_id is distinct from p_request_id
       or receipt.previous_updated_at is distinct from p_expected_updated_at
       or receipt.reason is distinct from p_reason then
      raise exception 'recovery operation already used' using errcode = '22023';
    end if;
    return 'already_applied';
  end if;
  if target.state <> 'attention' or target.owner_id is null
     or target.identity_deleted_at is null
     or target.updated_at is distinct from p_expected_updated_at
     or target.lease_token is not null or target.lease_until is not null then
    return 'unavailable';
  end if;
  insert into private.account_analytics_erasure_recoveries (
    operation_id, request_id, previous_attempts, previous_updated_at, reason
  ) values (p_operation_id, p_request_id, target.attempts, target.updated_at, p_reason);
  update private.account_analytics_erasures
    set state = 'pending', attempts = 0, available_at = now(), updated_at = clock_timestamp()
    where request_id = p_request_id;
  return 'requeued';
end;
$$;
revoke all on function public.retry_account_analytics_erasure_v1(uuid, uuid, timestamptz, text)
  from public, anon, authenticated;
grant execute on function public.retry_account_analytics_erasure_v1(uuid, uuid, timestamptz, text)
  to service_role;
commit;
