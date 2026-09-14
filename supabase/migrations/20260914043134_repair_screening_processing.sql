-- Technical failures are service work, never content-policy decisions.
alter table private.screening_jobs drop constraint screening_jobs_state_check;
alter table private.screening_jobs add constraint screening_jobs_state_check check(state in ('pending','approved','needs_review','rejected','service_error'));
create table private.screening_processing_recovery (
 subject_kind text not null, subject_id uuid not null, revision uuid not null,
 previous_reason text, previous_evidence jsonb not null, recovered_at timestamptz not null default now(),
 primary key(subject_kind,subject_id,revision)
);
alter table private.screening_processing_recovery enable row level security;
revoke all on private.screening_processing_recovery from public,anon,authenticated;
create or replace function public.finish_screening_job_v1(p_kind text,p_id uuid,p_revision uuid,p_lease uuid,p_state text,p_evidence jsonb default '{}'::jsonb,p_retry_seconds integer default 60)
returns boolean language plpgsql security definer set search_path='' as $$
declare matched boolean; reason_code text;
begin
  if p_state not in ('approved','needs_review','retry') or p_state is null
     or jsonb_typeof(p_evidence) is distinct from 'object'
     or octet_length(p_evidence::text)>8192
     or (p_evidence-array['model','reason','categories','scores','diagnostics']::text[]) <> '{}'::jsonb then
    raise exception 'invalid screening outcome' using errcode='22023';
  end if;
  reason_code:=p_evidence->>'reason';
  if reason_code is not null and reason_code not in ('provider_flag','spam_signal','invalid_input','provider_configuration','invalid_response','provider_unavailable','screening_unavailable') then
    raise exception 'invalid screening reason' using errcode='22023';
  end if;
  if p_evidence ? 'diagnostics' and (
    jsonb_typeof(p_evidence->'diagnostics') is distinct from 'object'
    or ((p_evidence->'diagnostics')-array['stage','http_status','error_code','request_id']::text[])<>'{}'::jsonb
    or octet_length((p_evidence->'diagnostics')::text)>512
  ) then raise exception 'invalid screening diagnostics' using errcode='22023'; end if;
  -- Older workers may still label technical failures needs_review.
  if p_state='needs_review' and reason_code not in ('provider_flag','spam_signal') then p_state:='retry'; end if;
  if p_state='approved' and (
    jsonb_typeof(p_evidence->'categories') is distinct from 'object'
    or p_evidence->'categories'='{}'::jsonb
    or exists(select 1 from jsonb_each(p_evidence->'categories') entry where entry.value <> 'false'::jsonb)
  ) then raise exception 'approval requires unflagged evidence' using errcode='22023'; end if;
  update private.screening_jobs set
    state=case when p_state='retry' then case when attempts>=5 then 'service_error' else 'pending' end else p_state end,
    reason=case when p_state='retry' and attempts>=5 then 'screening_unavailable' else reason_code end,
    evidence=p_evidence, available_at=now()+make_interval(secs=>greatest(30,least(coalesce(p_retry_seconds,60),3600))),
    lease_token=null,lease_until=null,updated_at=now()
    where subject_kind=p_kind and subject_id=p_id and revision=p_revision
      and lease_token=p_lease and lease_until>now() and state='pending';
  matched:=found;
  return matched;
end;
$$;
create or replace function public.claim_screening_jobs_v1(p_limit integer default 3)
returns setof private.screening_jobs language plpgsql security definer set search_path='' as $$
declare
  budget private.screening_dispatch_budget;
  candidate private.screening_jobs;
  claimed_job private.screening_jobs;
  current_window timestamptz;
  remaining integer;
  owner_claims integer;
begin
  -- One short database lock serializes budget reservations across workers.
  select * into budget from private.screening_dispatch_budget where singleton for update;
  current_window:=date_trunc('minute',clock_timestamp());
  if budget.window_start<>current_window then
    update private.screening_dispatch_budget set window_start=current_window,claimed=0 where singleton;
    budget.claimed:=0;
  end if;
  delete from private.screening_owner_budget where window_start<current_window-interval '1 day';
  update private.screening_jobs set state='service_error',reason=coalesce(reason,'screening_unavailable'),
    lease_token=null,lease_until=null,updated_at=now()
    where state='pending' and attempts>=5 and (lease_until is null or lease_until<=now());
  remaining:=least(greatest(0,least(coalesce(p_limit,3),5)),60-budget.claimed,
    6-(select count(*)::integer from private.screening_jobs where state='pending' and lease_until>now()));
  if remaining<=0 then return; end if;
  for candidate in
    select job.* from private.screening_jobs job
    left join private.screening_owner_budget owner_budget on owner_budget.owner_id=job.owner_id
      and owner_budget.window_start=current_window
    where job.state='pending' and job.attempts<5 and job.available_at<=now()
      and (job.lease_until is null or job.lease_until<=now())
      and coalesce(owner_budget.claimed,0)<10
      and (select count(*) from private.screening_jobs active where active.owner_id=job.owner_id and active.state='pending' and active.lease_until>now())<2
    order by job.available_at,job.created_at
    limit 100 for update of job skip locked
  loop
    select coalesce((select claimed from private.screening_owner_budget
      where owner_id=candidate.owner_id and window_start=current_window),0) into owner_claims;
    if owner_claims>=10 or (select count(*) from private.screening_jobs
      where owner_id=candidate.owner_id and state='pending' and lease_until>now())>=2 then continue; end if;
    update private.screening_jobs set lease_token=gen_random_uuid(),lease_until=now()+interval '5 minutes',attempts=attempts+1
      where subject_kind=candidate.subject_kind and subject_id=candidate.subject_id returning * into claimed_job;
    insert into private.screening_owner_budget(owner_id,window_start,claimed)
      values(candidate.owner_id,current_window,1)
      on conflict(owner_id) do update set window_start=current_window,claimed=owner_claims+1;
    update private.screening_dispatch_budget set claimed=claimed+1 where singleton;
    return next claimed_job;
    remaining:=remaining-1;
    exit when remaining<=0;
  end loop;
end;
$$;
revoke all on function public.claim_screening_jobs_v1(integer) from public,anon,authenticated;
grant execute on function public.claim_screening_jobs_v1(integer) to service_role;

create or replace function public.list_screening_review_v1(p_limit integer default 50,p_cursor jsonb default null,p_state text default 'needs_review')
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not private.screening_operator_v1() then
    raise exception 'moderation permission required' using errcode='42501';
  end if;
  if p_state is null or p_state not in ('pending','needs_review','rejected','approved','service_error') then raise exception 'invalid queue state' using errcode='22023'; end if;
  if p_cursor is not null and not (p_cursor ?& array['updated_at','subject_kind','subject_id']) then raise exception 'complete queue cursor required' using errcode='22023'; end if;
  return coalesce((select jsonb_agg(to_jsonb(queue)) from (
    select subject_kind,subject_id,revision,state,reason,evidence,
      appeal_requested_at,created_at,updated_at,owner_id=auth.uid() as self_review_conflict
    from private.screening_jobs job where state=p_state
      and (p_cursor is null or (updated_at,subject_kind,subject_id)>((p_cursor->>'updated_at')::timestamptz,p_cursor->>'subject_kind',(p_cursor->>'subject_id')::uuid))
    order by updated_at,subject_kind,subject_id limit greatest(1,least(coalesce(p_limit,50),100))
  ) queue),'[]'::jsonb);
end;
$$;
create or replace function public.review_screening_v1(p_kind text,p_id uuid,p_revision uuid,p_decision text,p_reason text,p_actor uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare job private.screening_jobs;
begin
  if p_actor is distinct from auth.uid() or p_actor is null then raise exception 'account changed' using errcode='28000'; end if;
  if not private.screening_operator_v1() then raise exception 'moderation permission required' using errcode='42501'; end if;
  if p_decision is null or p_decision not in ('approved','rejected') or (p_decision='rejected' and char_length(btrim(coalesce(p_reason,''))) not between 1 and 1000) or char_length(coalesce(p_reason,''))>1000 then
    raise exception 'decision and reason required' using errcode='22023';
  end if;
  select * into job from private.screening_jobs where subject_kind=p_kind and subject_id=p_id for update;
  if not found or job.revision is distinct from p_revision then return false; end if;
  if job.owner_id=auth.uid() then raise exception 'cannot review your own content' using errcode='42501'; end if;
  if job.state not in ('needs_review','rejected') then raise exception 'content is not awaiting a policy decision' using errcode='22023'; end if;
  p_reason:=coalesce(nullif(btrim(p_reason),''),'Approved after review');
  update private.screening_jobs set state=p_decision,reason='human_review',
    lease_token=null,lease_until=null,updated_at=now()
    where subject_kind=p_kind and subject_id=p_id;
  insert into private.screening_review_events(subject_kind,subject_id,revision,owner_id,actor_id,decision,reason)
    values(p_kind,p_id,p_revision,job.owner_id,auth.uid(),p_decision,btrim(p_reason));
  return true;
end;
$$;
create or replace function private.screening_approved_v1(p_kind text,p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.screening_jobs job
 where job.subject_kind=p_kind and job.subject_id=p_id and (
  job.state='approved' or (job.state in ('pending','needs_review','service_error') and exists(
   select 1 from private.screening_existing_visibility legacy
   where legacy.subject_kind=job.subject_kind and legacy.subject_id=job.subject_id
     and legacy.revision=job.revision
  ))
 ));
$$;

-- Preserve evidence and human decisions. Reset only technical failures once.
insert into private.screening_processing_recovery(subject_kind,subject_id,revision,previous_reason,previous_evidence)
 select subject_kind,subject_id,revision,reason,evidence from private.screening_jobs
 where state='needs_review' and reason in ('invalid_input','provider_configuration','invalid_response','provider_unavailable','screening_unavailable')
 on conflict do nothing;
update private.screening_jobs j set state='pending',attempts=0,available_at=now(),lease_token=null,lease_until=null,updated_at=now()
 where j.state='needs_review' and j.reason in ('invalid_input','provider_configuration','invalid_response','provider_unavailable','screening_unavailable')
 and exists(select 1 from private.screening_processing_recovery r where (r.subject_kind,r.subject_id,r.revision)=(j.subject_kind,j.subject_id,j.revision));
