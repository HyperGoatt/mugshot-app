begin;
-- Provider recovery uses synthetic queue facts only, never a provider request.
do $$
declare
  request uuid := gen_random_uuid();
  operation uuid := gen_random_uuid();
  owner uuid := gen_random_uuid();
  person uuid := gen_random_uuid();
  snapshot timestamptz;
  target private.account_analytics_erasures;
  claimed private.account_analytics_erasures;
  claim_attempt integer;
begin
  if has_function_privilege('anon', 'public.retry_account_analytics_erasure_v1(uuid,uuid,timestamptz,text)', 'execute')
     or has_function_privilege('authenticated', 'public.retry_account_analytics_erasure_v1(uuid,uuid,timestamptz,text)', 'execute')
     or not has_function_privilege('service_role', 'public.retry_account_analytics_erasure_v1(uuid,uuid,timestamptz,text)', 'execute') then
    raise exception 'analytics recovery is not service-only';
  end if;
  insert into private.account_analytics_erasures (
    request_id, owner_id, person_id, submitted_at, provider_accepted,
    identity_deleted_at, state, attempts
  ) values (
    request, owner, person, now()-interval '10 minutes', true,
    now()-interval '15 minutes', 'attention', 30
  ) returning updated_at into snapshot;
  if public.retry_account_analytics_erasure_v1(request,operation,snapshot-interval '1 second','provider_restored') <> 'unavailable'
     or public.retry_account_analytics_erasure_v1(request,operation,snapshot,'provider_restored') <> 'requeued'
     or public.retry_account_analytics_erasure_v1(request,operation,snapshot,'provider_restored') <> 'already_applied' then
    raise exception 'analytics recovery snapshot or retry fence failed';
  end if;
  select * into target from private.account_analytics_erasures where request_id=request;
  if target.state <> 'pending' or target.attempts <> 0 or target.owner_id <> owner
     or target.person_id <> person or not target.provider_accepted
     or target.submitted_at <> now()-interval '10 minutes'
     or (select count(*) from private.account_analytics_erasure_recoveries where request_id=request) <> 1 then
    raise exception 'analytics recovery discarded target evidence or duplicated its audit';
  end if;
  begin
    perform public.retry_account_analytics_erasure_v1(request,operation,snapshot,'configuration_repaired');
    raise exception 'operation reuse with different facts was accepted';
  exception when sqlstate '22023' then null;
  end;
  -- Runtime acceptance may leave older synthetic cleanup work in this QA
  -- database. Claim through it inside this rolled-back transaction rather
  -- than assuming this contract owns the first queue position.
  for claim_attempt in 1..(select count(*)::integer + 1 from private.account_analytics_erasures) loop
    select * into claimed from public.claim_account_analytics_erasures_v1(1);
    exit when claimed.request_id is null or claimed.request_id = request;
  end loop;
  if claimed.request_id is distinct from request then
    raise exception 'recovered analytics work was not claimable';
  end if;
  if public.retry_account_analytics_erasure_v1(request,gen_random_uuid(),claimed.updated_at,'provider_restored') <> 'unavailable' then
    raise exception 'active analytics work could be reset';
  end if;
  if not public.finish_account_analytics_erasure_v1(request,claimed.lease_token,'verified') then
    raise exception 'normal fenced completion failed after recovery';
  end if;
  select * into target from private.account_analytics_erasures where request_id=request;
  if target.owner_id is not null or target.person_id is not null
     or public.retry_account_analytics_erasure_v1(request,gen_random_uuid(),target.updated_at,'provider_restored') <> 'unavailable' then
    raise exception 'verified cleanup retained identity or could be resurrected';
  end if;
end;
$$;
rollback;
