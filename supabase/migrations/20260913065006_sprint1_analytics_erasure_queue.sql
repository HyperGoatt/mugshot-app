begin;
-- Processor cleanup survives identity/job removal. Only a verified outcome
-- erases the target; exhausted work stays visible for operational resolution.
create table private.account_analytics_erasures (
  request_id uuid primary key,
  job_id uuid references private.account_deletion_jobs(id) on delete set null,
  owner_id uuid,
  person_id uuid,
  submitted_at timestamptz,
  provider_accepted boolean not null default false,
  identity_deleted_at timestamptz,
  state text not null default 'pending' check(state in ('pending','processing','verified','attention')),
  attempts integer not null default 0 check(attempts between 0 and 30),
  lease_token uuid,
  lease_until timestamptz,
  available_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table private.account_analytics_erasures enable row level security;
revoke all on private.account_analytics_erasures from public,anon,authenticated;
create index account_analytics_erasures_due on private.account_analytics_erasures(available_at)
where state in ('pending','processing');

create function private.attach_account_analytics_erasure_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if tg_op='INSERT' and new.subject_id is not null then
    insert into private.account_analytics_erasures(request_id,job_id,owner_id,identity_deleted_at)
    values(new.request_id,new.id,new.subject_id,new.identity_deleted_at) on conflict do nothing;
  else
    update private.account_analytics_erasures set identity_deleted_at=new.identity_deleted_at
    where job_id=new.id and identity_deleted_at is null and new.identity_deleted_at is not null;
  end if;
  return new;
end;
$$;
create trigger attach_account_analytics_erasure after insert or update of identity_deleted_at
on private.account_deletion_jobs for each row execute function private.attach_account_analytics_erasure_v1();
revoke all on function private.attach_account_analytics_erasure_v1() from public,anon,authenticated;
insert into private.account_analytics_erasures(request_id,job_id,owner_id,identity_deleted_at)
select request_id,id,subject_id,identity_deleted_at from private.account_deletion_jobs
where subject_id is not null on conflict do nothing;

create function public.claim_account_analytics_erasures_v1(p_limit integer default 1)
returns setof private.account_analytics_erasures language plpgsql security definer set search_path='' as $$
begin
  update private.account_analytics_erasures set state='attention',lease_token=null,lease_until=null,updated_at=now()
  where state in ('pending','processing') and attempts>=30 and (lease_until is null or lease_until<=now());
  return query with eligible as (
    select request_id from private.account_analytics_erasures
    where state in ('pending','processing') and identity_deleted_at is not null
      and identity_deleted_at<=now()-interval '5 minutes'
      and owner_id is not null and attempts<30 and available_at<=now()
      and (lease_until is null or lease_until<=now())
    order by available_at,created_at limit greatest(0,least(coalesce(p_limit,1),1)) for update skip locked
  ) update private.account_analytics_erasures q set state='processing',attempts=q.attempts+1,
    lease_token=gen_random_uuid(),lease_until=now()+interval '5 minutes',updated_at=now()
    from eligible where q.request_id=eligible.request_id returning q.*;
end;
$$;

create function public.prepare_account_analytics_erasure_v1(
  p_request_id uuid,p_lease uuid,p_person_id uuid,p_other_account_candidates uuid[]
) returns timestamptz language plpgsql security definer set search_path='' as $$
declare q private.account_analytics_erasures; submitted timestamptz;
begin
  select * into q from private.account_analytics_erasures where request_id=p_request_id
    and state='processing' and lease_token=p_lease and lease_until>now() for update;
  if not found or p_person_id is null then return null;end if;
  if cardinality(p_other_account_candidates)>1000 or p_other_account_candidates is null then return null;end if;
  -- Anonymous SDK UUID aliases are allowed, but a different extant Mugshot
  -- account must never be swept into this person's erasure automatically.
  if exists(select 1 from public.users where id=any(p_other_account_candidates) and id<>q.owner_id) then
    return null;
  end if;
  if q.person_id is not null and q.person_id<>p_person_id then return null;end if;
  update private.account_analytics_erasures set person_id=p_person_id,
    submitted_at=coalesce(submitted_at,clock_timestamp()),updated_at=now()
    where request_id=p_request_id returning submitted_at into submitted;
  return submitted;
end;
$$;

create function public.finish_account_analytics_erasure_v1(p_request_id uuid,p_lease uuid,p_outcome text)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if p_outcome is null or p_outcome not in ('pending','submitted','verified','attention') then
    raise exception 'invalid analytics cleanup outcome' using errcode='22023';end if;
  update private.account_analytics_erasures set
    state=case when p_outcome in ('pending','submitted') and attempts>=30 then 'attention'
      when p_outcome='submitted' then 'pending' else p_outcome end,
    provider_accepted=provider_accepted or p_outcome='submitted',
    owner_id=case when p_outcome='verified' then null else owner_id end,
    person_id=case when p_outcome='verified' then null else person_id end,
    lease_token=null,lease_until=null,updated_at=now(),
    available_at=now()+make_interval(secs=>least(21600,60*(2^least(attempts,8))::integer))
  where request_id=p_request_id and state='processing' and lease_token=p_lease and lease_until>now()
    and (p_outcome not in ('verified','submitted') or (person_id is not null and submitted_at is not null));
  return found;
end;
$$;

create function public.read_account_analytics_erasure_status_v1(p_request_id uuid,p_job_id uuid)
returns text language sql stable security definer set search_path='' as $$
  select case when state='verified' then 'verified' when state='attention' then 'attention' else 'pending' end
  from private.account_analytics_erasures where request_id=p_request_id and job_id=p_job_id;
$$;
revoke all on function public.claim_account_analytics_erasures_v1(integer),
public.prepare_account_analytics_erasure_v1(uuid,uuid,uuid,uuid[]),
public.finish_account_analytics_erasure_v1(uuid,uuid,text),
public.read_account_analytics_erasure_status_v1(uuid,uuid) from public,anon,authenticated;
grant execute on function public.claim_account_analytics_erasures_v1(integer),
public.prepare_account_analytics_erasure_v1(uuid,uuid,uuid,uuid[]),
public.finish_account_analytics_erasure_v1(uuid,uuid,text),
public.read_account_analytics_erasure_status_v1(uuid,uuid) to service_role;
commit;
