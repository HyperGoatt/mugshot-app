-- Local text validation and reactive human moderation. Historical provider and
-- human evidence remains intact; no photo is represented as locally screened.
create table private.moderation_text_rules (
 id text primary key, language text not null, phrase text not null unique,
 enabled boolean not null default true, version integer not null default 1
);
alter table private.moderation_text_rules enable row level security;
revoke all on private.moderation_text_rules from public,anon,authenticated;
-- Narrow starter rules, not a profanity ban. Ordinary negative cafe reviews
-- and words containing a forbidden substring must remain valid.
insert into private.moderation_text_rules(id,language,phrase) values
 ('targeted_threat','en','i will kill you'),
 ('suicide_encouragement','en','go kill yourself'),
 ('sexual_exploitation','en','child pornography'),
 ('racial_abuse','en','nigger'),
 ('homophobic_abuse','en','faggot');

create function private.local_text_rule_v1(p_text text)
returns text language sql stable security definer set search_path='' as $$
 select r.id from private.moderation_text_rules r where r.enabled and
 (' ' || regexp_replace(lower(normalize(coalesce(p_text,''),NFKC)), '[^[:alnum:]]+', ' ', 'g') || ' ')
 like ('% ' || r.phrase || ' %') order by r.id limit 1;
$$;
revoke all on function private.local_text_rule_v1(text) from public,anon,authenticated;

create table private.moderation_transition_receipts (
 subject_kind text not null,subject_id uuid not null,revision uuid not null,
 owner_id uuid references public.users(id) on delete cascade,
 previous_state text not null,previous_reason text,previous_evidence jsonb not null,
 recorded_at timestamptz not null default now(),
 primary key(subject_kind,subject_id,revision)
);
alter table private.moderation_transition_receipts enable row level security;
revoke all on private.moderation_transition_receipts from public,anon,authenticated;
insert into private.moderation_transition_receipts
 (subject_kind,subject_id,revision,owner_id,previous_state,previous_reason,previous_evidence)
 select subject_kind,subject_id,revision,owner_id,state,reason,evidence from private.screening_jobs;

create table private.withdrawn_moderation_decisions (
 subject_kind text not null,subject_id uuid not null,owner_id uuid references public.users(id) on delete cascade,
 state text not null,reason text,evidence jsonb,appeal_requested_at timestamptz,
 primary key(subject_kind,subject_id)
);
alter table private.withdrawn_moderation_decisions enable row level security;
revoke all on private.withdrawn_moderation_decisions from public,anon,authenticated;

-- Existing source triggers cover outward text, edits and Private-to-shared
-- changes. Keep their signature for installed clients and all read predicates.
create or replace function private.enqueue_screening_v1(p_kind text,p_id uuid,p_owner uuid,p_payload jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare existing private.screening_jobs; retained private.withdrawn_moderation_decisions;
begin
 select * into existing from private.screening_jobs where subject_kind=p_kind and subject_id=p_id for update;
 if p_payload is null then
   if existing.state='rejected' or (existing.state='needs_review' and
     (coalesce(existing.reason,'') not in ('invalid_input','provider_configuration','invalid_response','provider_unavailable','screening_unavailable')
      or existing.appeal_requested_at is not null)) then
     insert into private.withdrawn_moderation_decisions values
      (p_kind,p_id,p_owner,existing.state,existing.reason,existing.evidence,existing.appeal_requested_at)
     on conflict(subject_kind,subject_id) do update set state=excluded.state,reason=excluded.reason,
      evidence=excluded.evidence,appeal_requested_at=excluded.appeal_requested_at;
   end if;
   delete from private.screening_jobs where subject_kind=p_kind and subject_id=p_id;
   return;
 end if;
 if jsonb_typeof(p_payload) is distinct from 'object'
 or jsonb_typeof(p_payload->'text') is distinct from 'string'
 or jsonb_typeof(p_payload->'images') is distinct from 'array'
 or octet_length(p_payload::text)>65536 then
   raise exception 'invalid shared content' using errcode='22023';
 end if;
 if private.local_text_rule_v1(p_payload->>'text') is not null then
   raise exception 'shared_text_not_allowed' using errcode='22023';
 end if;
 select * into retained from private.withdrawn_moderation_decisions where subject_kind=p_kind and subject_id=p_id;
 if retained.subject_id is not null and existing.subject_id is null then
   insert into private.screening_jobs(subject_kind,subject_id,owner_id,payload,state,reason,evidence,appeal_requested_at)
   values(p_kind,p_id,p_owner,p_payload,retained.state,retained.reason,retained.evidence,retained.appeal_requested_at);
   delete from private.withdrawn_moderation_decisions where subject_kind=p_kind and subject_id=p_id;
   return;
 end if;
 -- Genuine decisions are not cleared by editing, changing audience or retiring
 -- a provider. Moderators retain the existing review/appeal controls.
 if existing.state='rejected' or (existing.state='needs_review' and
   (coalesce(existing.reason,'') not in ('invalid_input','provider_configuration','invalid_response','provider_unavailable','screening_unavailable')
    or existing.appeal_requested_at is not null)) then return; end if;
 if existing.subject_id is not null then
   insert into private.moderation_transition_receipts
    (subject_kind,subject_id,revision,owner_id,previous_state,previous_reason,previous_evidence)
   values(existing.subject_kind,existing.subject_id,existing.revision,existing.owner_id,existing.state,existing.reason,existing.evidence)
   on conflict do nothing;
 end if;
 insert into private.screening_jobs(subject_kind,subject_id,owner_id,payload,state,reason,evidence)
 values(p_kind,p_id,p_owner,p_payload,'approved','local_text_filter',jsonb_build_object('method','local_text_v1','photos','report_driven'))
 on conflict(subject_kind,subject_id) do update set
 owner_id=excluded.owner_id,payload=excluded.payload,revision=gen_random_uuid(),state='approved',
 reason='local_text_filter',evidence=excluded.evidence,attempts=0,lease_token=null,lease_until=null,updated_at=now()
 where private.screening_jobs.payload is distinct from excluded.payload or private.screening_jobs.reason is distinct from 'local_text_filter';
end;
$$;
-- Retire existing technical waits under the new policy, with exact previous
-- evidence in receipts. Preserve approvals, genuine flags, rejection and appeals.
update private.screening_jobs set state='approved',reason='reactive_policy_transition',
 evidence=jsonb_build_object('method','reactive_policy_transition','photos','report_driven'),
 lease_token=null,lease_until=null,updated_at=now()
 where state in ('pending','service_error','needs_review') and appeal_requested_at is null
 and (reason is null or reason in ('invalid_input','provider_configuration','invalid_response','provider_unavailable','screening_unavailable'));
-- No outstanding request can apply an old provider result after this cutover.
update private.screening_jobs set lease_token=null,lease_until=null where lease_token is not null or lease_until is not null;
create or replace function public.claim_screening_jobs_v1(p_limit integer default 3)
returns setof private.screening_jobs language sql security definer set search_path='' as $$
 select * from private.screening_jobs where false;
$$;
create or replace function private.dispatch_screening_worker_v1()
returns bigint language sql security definer set search_path='' as $$select null::bigint$$;
-- Safe on isolated rehearsals without cron. Retire only this named schedule.
do $$declare j record;begin
 if to_regclass('cron.job') is not null then
  for j in execute 'select jobid from cron.job where jobname=''mugshot-screening-v1''' loop
   execute 'select cron.unschedule($1)' using j.jobid;
  end loop;
 end if;
end$$;
create or replace function public.configure_screening_schedule_v1(p_enabled boolean)
returns boolean language plpgsql security definer set search_path='' as $$begin
 if p_enabled then raise exception 'external screening retired';end if;return false;
end$$;
