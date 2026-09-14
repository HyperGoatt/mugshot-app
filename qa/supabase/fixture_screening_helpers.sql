-- Connection-local fixture utilities. The remote runner refuses production and
-- sets isolated mode before loading this file. These are never migrations.
create function pg_temp.approve_shared_fixture(p_kind text,p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare queued private.screening_jobs;
begin
  if current_setting('mugshot.qa_contract',true) is distinct from 'isolated' then
    raise exception 'Isolated QA mode required';
  end if;
  select * into queued from private.screening_jobs
    where subject_kind=p_kind and subject_id=p_id;
  if not found then raise exception 'Shared fixture has no queued revision';end if;
  if not exists(select 1 from auth.users u where u.id=queued.owner_id and
    (u.id,u.email) in (
      ('00000000-0000-4000-8000-000000000101'::uuid,'alpha-fixture-1@example.invalid'),
      ('00000000-0000-4000-8000-000000000102'::uuid,'alpha-fixture-2@example.invalid'),
      ('00000000-0000-4000-8000-000000000103'::uuid,'alpha-fixture-3@example.invalid'),
      ('00000000-0000-4000-8000-000000000104'::uuid,'alpha-fixture-4@example.invalid')
    )) then raise exception 'Only reserved synthetic fixture owners may be admitted';end if;
  if queued.state='approved' then return;end if;
  if queued.state<>'pending' then raise exception 'Unexpected fixture screening state';end if;
  update private.screening_jobs set lease_token=gen_random_uuid(),
    lease_until=now()+interval '1 minute',attempts=greatest(attempts,1)
    where subject_kind=p_kind and subject_id=p_id returning * into queued;
  if not public.finish_screening_job_v1(p_kind,p_id,queued.revision,queued.lease_token,
    'approved','{"categories":{"sexual":false}}'::jsonb) then
    raise exception 'Synthetic fixture screening did not finish';
  end if;
end;
$$;
