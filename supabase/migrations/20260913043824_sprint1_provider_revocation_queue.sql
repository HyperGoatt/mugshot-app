-- Encrypted provider credentials survive identity deletion but have bounded
-- retention. Nothing here invokes Apple or delays deletion of Mugshot data.
create table private.account_provider_revocations (
  request_id uuid primary key,
  subject_id uuid,
  job_id uuid references private.account_deletion_jobs(id) on delete set null,
  client_id text not null check(char_length(client_id) between 1 and 256),
  ciphertext jsonb,
  state text not null default 'staged' check(state in ('staged','pending','processing','revoked','unavailable')),
  reason text,
  attempts integer not null default 0 check(attempts between 0 and 10),
  lease_token uuid,
  lease_until timestamptz,
  available_at timestamptz not null default now(),
  expires_at timestamptz not null default now()+interval '15 minutes',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(ciphertext is null or (jsonb_typeof(ciphertext)='object' and octet_length(ciphertext::text)<=32768))
);
alter table private.account_provider_revocations enable row level security;
revoke all on private.account_provider_revocations from public,anon,authenticated;
create index account_provider_revocations_due on private.account_provider_revocations(available_at) where state in ('pending','processing');

create function public.stage_account_apple_revocation_v1(p_challenge_id uuid,p_subject_id uuid,p_request_id uuid,p_session_id uuid,p_client_id text,p_ciphertext jsonb)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if not exists(select 1 from private.account_deletion_step_up_challenges
    where id=p_challenge_id and subject_id=p_subject_id and request_id=p_request_id
      and authorized_session_id=p_session_id and authorized_at is not null
      and authorization_expires_at>now() and superseded_at is null and consumed_at is null) then
    raise exception 'verified deletion challenge required' using errcode='42501';
  end if;
  if p_ciphertext is not null and (jsonb_typeof(p_ciphertext) is distinct from 'object'
    or p_ciphertext->'version' is distinct from '1'::jsonb
    or not(p_ciphertext ?& array['nonce','data'])
    or jsonb_typeof(p_ciphertext->'nonce') is distinct from 'string'
    or jsonb_typeof(p_ciphertext->'data') is distinct from 'string'
    or (p_ciphertext-array['version','nonce','data'])<>'{}'::jsonb) then
    raise exception 'invalid encrypted credential' using errcode='22023';
  end if;
  insert into private.account_provider_revocations(request_id,subject_id,client_id,ciphertext,reason)
    values(p_request_id,p_subject_id,p_client_id,p_ciphertext,case when p_ciphertext is null then 'token_unavailable' end)
    on conflict(request_id) do nothing;
  if not exists(select 1 from private.account_provider_revocations where request_id=p_request_id and subject_id=p_subject_id and client_id=p_client_id and state='staged') then
    raise exception 'deletion request changed' using errcode='42501';
  end if;
  return true;
end;
$$;

create function private.attach_account_provider_revocation_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  update private.account_provider_revocations set job_id=new.id,subject_id=null,
    state=case when ciphertext is null then 'unavailable' else 'pending' end,
    expires_at=now()+interval '7 days',updated_at=now()
    where request_id=new.request_id and subject_id=new.subject_id and state='staged' and expires_at>now();
  return new;
end;
$$;
create trigger attach_account_provider_revocation after insert on private.account_deletion_jobs
for each row execute function private.attach_account_provider_revocation_v1();
revoke all on function private.attach_account_provider_revocation_v1() from public,anon,authenticated;

create function public.claim_account_apple_revocations_v1(p_limit integer default 5)
returns setof private.account_provider_revocations language plpgsql security definer set search_path='' as $$
begin
  delete from private.account_provider_revocations where state='staged' and expires_at<=now();
  update private.account_provider_revocations set state='unavailable',ciphertext=null,subject_id=null,
    lease_token=null,lease_until=null,reason='revocation_unavailable',updated_at=now()
    where state in ('pending','processing') and (expires_at<=now() or attempts>=10)
      and (lease_until is null or lease_until<=now());
  delete from private.account_provider_revocations where state in ('revoked','unavailable') and updated_at<now()-interval '30 days';
  return query with eligible as (
    select provider.request_id from private.account_provider_revocations provider
    join private.account_deletion_jobs job on job.id=provider.job_id
    where provider.state in ('pending','processing') and provider.available_at<=now()
      and provider.expires_at>now() and provider.attempts<10
      and (provider.lease_until is null or provider.lease_until<=now())
      and job.identity_deleted_at is not null
    order by provider.available_at,provider.created_at
    limit greatest(0,least(coalesce(p_limit,5),5)) for update of provider skip locked
  ) update private.account_provider_revocations provider set state='processing',attempts=attempts+1,
    lease_token=gen_random_uuid(),lease_until=now()+interval '5 minutes',updated_at=now()
    from eligible where provider.request_id=eligible.request_id returning provider.*;
end;
$$;

create function public.finish_account_apple_revocation_v1(p_request_id uuid,p_lease uuid,p_revoked boolean)
returns boolean language plpgsql security definer set search_path='' as $$
begin
  if p_revoked is null then raise exception 'revocation outcome required' using errcode='22023'; end if;
  update private.account_provider_revocations set
    state=case when p_revoked then 'revoked' when attempts>=10 then 'unavailable' else 'pending' end,
    ciphertext=case when p_revoked or attempts>=10 then null else ciphertext end,
    reason=case when p_revoked then null else 'revocation_unavailable' end,
    lease_token=null,lease_until=null,updated_at=now(),
    available_at=now()+make_interval(secs=>least(21600,60*(2^attempts)::integer))
    where request_id=p_request_id and state='processing' and lease_token=p_lease and lease_until>now();
  return found;
end;
$$;
revoke all on function public.stage_account_apple_revocation_v1(uuid,uuid,uuid,uuid,text,jsonb),public.claim_account_apple_revocations_v1(integer),public.finish_account_apple_revocation_v1(uuid,uuid,boolean) from public,anon,authenticated;
grant execute on function public.stage_account_apple_revocation_v1(uuid,uuid,uuid,uuid,text,jsonb),public.claim_account_apple_revocations_v1(integer),public.finish_account_apple_revocation_v1(uuid,uuid,boolean) to service_role;

-- Called only after the endpoint has verified the deletion/recovery capability.
create function public.read_account_apple_revocation_status_v1(p_request_id uuid,p_job_id uuid)
returns text language sql stable security definer set search_path='' as $$
  select case when state in ('pending','processing') then 'pending'
    when state='revoked' then 'revoked' else 'unavailable' end
  from private.account_provider_revocations
  where request_id=p_request_id and job_id=p_job_id;
$$;
revoke all on function public.read_account_apple_revocation_status_v1(uuid,uuid) from public,anon,authenticated;
grant execute on function public.read_account_apple_revocation_status_v1(uuid,uuid) to service_role;
