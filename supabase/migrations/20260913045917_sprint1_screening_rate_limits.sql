-- Operational throughput limits do not change sharing permissions or decisions.
create table private.screening_dispatch_budget (
  singleton boolean primary key default true check(singleton),
  window_start timestamptz not null default now(),
  claimed integer not null default 0 check(claimed>=0)
);
insert into private.screening_dispatch_budget(singleton) values(true);
create table private.screening_owner_budget (
  owner_id uuid primary key references public.users(id) on delete cascade,
  window_start timestamptz not null,
  claimed integer not null check(claimed>=0)
);
alter table private.screening_dispatch_budget enable row level security;
alter table private.screening_owner_budget enable row level security;
revoke all on private.screening_dispatch_budget,private.screening_owner_budget from public,anon,authenticated;

create index screening_jobs_active_owner on private.screening_jobs(owner_id,lease_until) where state='pending';

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
  update private.screening_jobs set state='needs_review',reason='screening_unavailable',
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
