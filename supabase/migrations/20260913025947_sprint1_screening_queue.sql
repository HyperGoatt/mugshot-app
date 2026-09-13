-- The queue is sealed; source triggers and outward read gates land in the
-- following migration. Nothing in this migration transmits content externally.
create table private.screening_jobs (
  subject_kind text not null check (subject_kind in ('user','visit','comment','list','list_item','list_comment','recipe','recommendation','cafe_photo','profile_spot')),
  subject_id uuid not null,
  owner_id uuid not null references public.users(id) on delete cascade,
  revision uuid not null default gen_random_uuid(),
  payload jsonb not null check (jsonb_typeof(payload) = 'object'),
  state text not null default 'pending' check (state in ('pending','approved','needs_review','rejected')),
  reason text,
  evidence jsonb not null default '{}'::jsonb,
  attempts integer not null default 0 check (attempts between 0 and 5),
  available_at timestamptz not null default now(),
  lease_token uuid,
  lease_until timestamptz,
  appeal_requested_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (subject_kind, subject_id)
);
create index screening_jobs_due on private.screening_jobs(available_at,created_at) where state='pending';
create index screening_jobs_review on private.screening_jobs(updated_at) where state='needs_review';
create index screening_jobs_owner on private.screening_jobs(owner_id,updated_at desc);
alter table private.screening_jobs enable row level security;
revoke all on private.screening_jobs from public, anon, authenticated;

create table private.screening_review_events (
  id uuid primary key default gen_random_uuid(),
  subject_kind text not null,
  subject_id uuid not null,
  revision uuid not null,
  owner_id uuid references public.users(id) on delete cascade,
  actor_id uuid references public.users(id) on delete set null,
  decision text not null check (decision in ('approved','rejected','reconsideration')),
  reason text not null check (char_length(reason) between 1 and 1000),
  created_at timestamptz not null default now()
);
alter table private.screening_review_events enable row level security;
revoke all on private.screening_review_events from public, anon, authenticated;

create function private.enqueue_screening_v1(p_kind text, p_id uuid, p_owner uuid, p_payload jsonb)
returns void language plpgsql security definer set search_path='' as $$
begin
  -- Null means no longer outward-facing or deleted. Withdraw any active lease.
  if p_payload is null then
    delete from private.screening_jobs where subject_kind=p_kind and subject_id=p_id;
    return;
  end if;
  if jsonb_typeof(p_payload) <> 'object'
     or (p_payload - array['text','images']::text[]) <> '{}'::jsonb
     or jsonb_typeof(p_payload->'text') is distinct from 'string'
     or jsonb_typeof(p_payload->'images') is distinct from 'array'
     or jsonb_array_length(p_payload->'images') > 12
     or octet_length(p_payload::text) > 65536 then
    raise exception 'invalid screening payload' using errcode='22023';
  end if;
  insert into private.screening_jobs(subject_kind,subject_id,owner_id,payload)
    values(p_kind,p_id,p_owner,p_payload)
  on conflict(subject_kind,subject_id) do update set
    owner_id=excluded.owner_id, payload=excluded.payload, revision=gen_random_uuid(),
    state='pending', reason=null, evidence='{}'::jsonb, attempts=0,
    available_at=now(), lease_token=null, lease_until=null, appeal_requested_at=null,
    updated_at=now()
  where private.screening_jobs.payload is distinct from excluded.payload
     or private.screening_jobs.owner_id is distinct from excluded.owner_id;
  -- Structured-only rows with no shared text or images need no provider call.
  if btrim(p_payload->>'text')='' and p_payload->'images'='[]'::jsonb then
    update private.screening_jobs set state='approved',reason='no_screenable_content',
      lease_token=null,lease_until=null,updated_at=now()
      where subject_kind=p_kind and subject_id=p_id and state='pending';
  end if;
end;
$$;

create function private.screening_approved_v1(p_kind text,p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.screening_jobs
    where subject_kind=p_kind and subject_id=p_id and state='approved');
$$;

create function public.claim_screening_jobs_v1(p_limit integer default 3)
returns setof private.screening_jobs language plpgsql security definer set search_path='' as $$
begin
  -- A repeatedly crashed worker cannot leave an invisible job stranded forever.
  update private.screening_jobs set state='needs_review', reason='screening_unavailable',
    lease_token=null,lease_until=null,updated_at=now()
    where state='pending' and attempts>=5 and (lease_until is null or lease_until<=now());
  return query
    with eligible as (
      select subject_kind,subject_id from private.screening_jobs
      where state='pending' and attempts<5 and available_at<=now()
        and (lease_until is null or lease_until<=now())
      order by available_at,created_at
      limit greatest(1,least(coalesce(p_limit,3),5)) for update skip locked
    )
    update private.screening_jobs job set lease_token=gen_random_uuid(),
      lease_until=now()+interval '5 minutes',attempts=job.attempts+1
    from eligible
    where job.subject_kind=eligible.subject_kind and job.subject_id=eligible.subject_id
    returning job.*;
end;
$$;

create function public.read_screening_lease_v1(p_kind text,p_id uuid,p_revision uuid,p_lease uuid)
returns jsonb language sql stable security definer set search_path='' as $$
  select payload from private.screening_jobs
    where subject_kind=p_kind and subject_id=p_id and revision=p_revision
      and lease_token=p_lease and lease_until>now() and state='pending';
$$;

create function public.finish_screening_job_v1(p_kind text,p_id uuid,p_revision uuid,p_lease uuid,p_state text,p_evidence jsonb default '{}'::jsonb,p_retry_seconds integer default 60)
returns boolean language plpgsql security definer set search_path='' as $$
declare matched boolean; reason_code text;
begin
  if p_state not in ('approved','needs_review','retry') or p_state is null
     or jsonb_typeof(p_evidence) is distinct from 'object'
     or octet_length(p_evidence::text)>8192
     or (p_evidence-array['model','reason','categories','scores']::text[]) <> '{}'::jsonb then
    raise exception 'invalid screening outcome' using errcode='22023';
  end if;
  reason_code:=p_evidence->>'reason';
  if reason_code is not null and reason_code not in ('provider_flag','spam_signal','invalid_input','provider_configuration','invalid_response','provider_unavailable','screening_unavailable') then
    raise exception 'invalid screening reason' using errcode='22023';
  end if;
  if p_state='approved' and (
    jsonb_typeof(p_evidence->'categories') is distinct from 'object'
    or p_evidence->'categories'='{}'::jsonb
    or exists(select 1 from jsonb_each(p_evidence->'categories') entry where entry.value <> 'false'::jsonb)
  ) then raise exception 'approval requires unflagged evidence' using errcode='22023'; end if;
  update private.screening_jobs set
    state=case when p_state='retry' then case when attempts>=5 then 'needs_review' else 'pending' end else p_state end,
    reason=case when p_state='retry' and attempts>=5 then 'screening_unavailable' else reason_code end,
    evidence=p_evidence, available_at=now()+make_interval(secs=>greatest(30,least(coalesce(p_retry_seconds,60),3600))),
    lease_token=null,lease_until=null,updated_at=now()
    where subject_kind=p_kind and subject_id=p_id and revision=p_revision
      and lease_token=p_lease and lease_until>now() and state='pending';
  matched:=found;
  return matched;
end;
$$;

create function private.screening_operator_v1()
returns boolean language sql stable security definer set search_path='' as $$
  select private.is_live_account_as(auth.uid()) and exists (
    select 1 from private.moderation_operators where user_id=auth.uid() and is_active
  );
$$;

create function public.list_screening_review_v1(p_limit integer default 50,p_cursor jsonb default null,p_state text default 'needs_review')
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not private.screening_operator_v1() then
    raise exception 'moderation permission required' using errcode='42501';
  end if;
  if p_state is null or p_state not in ('pending','needs_review','rejected','approved') then raise exception 'invalid queue state' using errcode='22023'; end if;
  if p_cursor is not null and not (p_cursor ?& array['updated_at','subject_kind','subject_id']) then raise exception 'complete queue cursor required' using errcode='22023'; end if;
  return coalesce((select jsonb_agg(to_jsonb(queue)) from (
    select subject_kind,subject_id,revision,state,reason,
      appeal_requested_at,created_at,updated_at,owner_id=auth.uid() as self_review_conflict
    from private.screening_jobs job where state=p_state
      and (p_cursor is null or (updated_at,subject_kind,subject_id)>((p_cursor->>'updated_at')::timestamptz,p_cursor->>'subject_kind',(p_cursor->>'subject_id')::uuid))
    order by updated_at,subject_kind,subject_id limit greatest(1,least(coalesce(p_limit,50),100))
  ) queue),'[]'::jsonb);
end;
$$;

create function public.review_screening_v1(p_kind text,p_id uuid,p_revision uuid,p_decision text,p_reason text,p_actor uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare job private.screening_jobs;
begin
  if p_actor is distinct from auth.uid() or p_actor is null then raise exception 'account changed' using errcode='28000'; end if;
  if not private.screening_operator_v1() then raise exception 'moderation permission required' using errcode='42501'; end if;
  if p_decision is null or p_decision not in ('approved','rejected') or char_length(btrim(coalesce(p_reason,''))) not between 1 and 1000 then
    raise exception 'decision and reason required' using errcode='22023';
  end if;
  select * into job from private.screening_jobs where subject_kind=p_kind and subject_id=p_id for update;
  if not found or job.revision is distinct from p_revision then return false; end if;
  if job.owner_id=auth.uid() then raise exception 'cannot review your own content' using errcode='42501'; end if;
  update private.screening_jobs set state=p_decision,reason='human_review',
    lease_token=null,lease_until=null,updated_at=now()
    where subject_kind=p_kind and subject_id=p_id;
  insert into private.screening_review_events(subject_kind,subject_id,revision,owner_id,actor_id,decision,reason)
    values(p_kind,p_id,p_revision,job.owner_id,auth.uid(),p_decision,btrim(p_reason));
  return true;
end;
$$;

create function public.request_screening_review_v1(p_kind text,p_id uuid,p_revision uuid,p_reason text,p_actor uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare job private.screening_jobs;
begin
  if p_actor is distinct from auth.uid() or p_actor is null then raise exception 'account changed' using errcode='28000'; end if;
  if not private.is_live_account_as(auth.uid()) then raise exception 'authentication required' using errcode='28000'; end if;
  if char_length(btrim(coalesce(p_reason,''))) not between 1 and 1000 then raise exception 'reason required' using errcode='22023'; end if;
  select * into job from private.screening_jobs where subject_kind=p_kind and subject_id=p_id and owner_id=auth.uid() for update;
  if not found or job.revision is distinct from p_revision or job.state not in ('needs_review','rejected') then return false; end if;
  if job.appeal_requested_at is not null then return true; end if;
  update private.screening_jobs set state='needs_review',appeal_requested_at=now(),updated_at=now()
    where subject_kind=p_kind and subject_id=p_id;
  insert into private.screening_review_events(subject_kind,subject_id,revision,owner_id,actor_id,decision,reason)
    values(p_kind,p_id,p_revision,job.owner_id,auth.uid(),'reconsideration',btrim(p_reason));
  return true;
end;
$$;

create function public.my_screening_status_v1(p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not private.is_live_account_as(auth.uid()) then raise exception 'authentication required' using errcode='28000'; end if;
  return coalesce((select jsonb_agg(to_jsonb(own)) from (
    select subject_kind,subject_id,revision,state,reason,appeal_requested_at,updated_at,
      (select history.reason from private.screening_review_events history
       where history.subject_kind=job.subject_kind and history.subject_id=job.subject_id and history.revision=job.revision
         and history.decision='rejected' order by history.created_at desc limit 1) as review_reason
    from private.screening_jobs job where owner_id=auth.uid()
    order by updated_at desc limit greatest(1,least(coalesce(p_limit,50),100))
  ) own),'[]'::jsonb);
end;
$$;

revoke all on function private.enqueue_screening_v1(text,uuid,uuid,jsonb),private.screening_approved_v1(text,uuid),private.screening_operator_v1() from public,anon,authenticated;
revoke all on function public.claim_screening_jobs_v1(integer),public.read_screening_lease_v1(text,uuid,uuid,uuid),public.finish_screening_job_v1(text,uuid,uuid,uuid,text,jsonb,integer) from public,anon,authenticated;
grant execute on function public.claim_screening_jobs_v1(integer),public.read_screening_lease_v1(text,uuid,uuid,uuid),public.finish_screening_job_v1(text,uuid,uuid,uuid,text,jsonb,integer) to service_role;
revoke all on function public.list_screening_review_v1(integer,jsonb,text),public.review_screening_v1(text,uuid,uuid,text,text,uuid),public.request_screening_review_v1(text,uuid,uuid,text,uuid),public.my_screening_status_v1(integer) from public,anon;
grant execute on function public.list_screening_review_v1(integer,jsonb,text),public.review_screening_v1(text,uuid,uuid,text,text,uuid),public.request_screening_review_v1(text,uuid,uuid,text,uuid),public.my_screening_status_v1(integer) to authenticated;


create function public.get_my_moderation_role_v1()
returns text language sql stable security definer set search_path='' as $$
  select operator.role from private.moderation_operators operator
  where operator.user_id=auth.uid() and operator.is_active and private.is_live_account_as(auth.uid());
$$;
revoke all on function public.get_my_moderation_role_v1() from public,anon;
grant execute on function public.get_my_moderation_role_v1() to authenticated;

create function public.get_screening_review_item_v1(p_kind text,p_id uuid,p_revision uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not private.screening_operator_v1() then raise exception 'moderation permission required' using errcode='42501'; end if;
  return (select to_jsonb(item) from (
    select subject_kind,subject_id,owner_id,revision,payload,state,reason,evidence,
      appeal_requested_at,created_at,updated_at,owner_id=auth.uid() as self_review_conflict,
      coalesce((select jsonb_agg(to_jsonb(event)) from (
        select decision,reason,created_at from private.screening_review_events history
        where history.subject_kind=job.subject_kind and history.subject_id=job.subject_id and history.revision=job.revision
        order by created_at desc limit 10
      ) event),'[]'::jsonb) as history
    from private.screening_jobs job where subject_kind=p_kind and subject_id=p_id and revision=p_revision
  ) item);
end;
$$;
revoke all on function public.get_screening_review_item_v1(text,uuid,uuid) from public,anon;
grant execute on function public.get_screening_review_item_v1(text,uuid,uuid) to authenticated;


create function public.content_screening_approved_v1(p_kind text,p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select private.screening_approved_v1(p_kind,p_id);
$$;
revoke all on function public.content_screening_approved_v1(text,uuid) from public;
grant execute on function public.content_screening_approved_v1(text,uuid) to anon,authenticated;
