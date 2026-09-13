\set ON_ERROR_STOP on
begin;
-- The remote runner refuses production. This additional guard requires the
-- reserved, non-sign-in QA identity before changing even transactional state.
do $$
declare
  qa_owner_id uuid:='00000000-0000-4000-8000-000000000101';
  item_id uuid:=gen_random_uuid();
  first_job private.screening_jobs;
  next_job private.screening_jobs;
  client_role text;
begin
  if not exists(select 1 from auth.users where id=qa_owner_id and email='alpha-fixture-1@example.invalid') then
    raise exception 'disposable QA fixture required';
  end if;
  foreach client_role in array array['anon','authenticated'] loop
    if has_table_privilege(client_role,'private.screening_jobs','SELECT')
      or has_table_privilege(client_role,'private.screening_review_events','SELECT')
      or has_function_privilege(client_role,'public.claim_screening_jobs_v1(integer)','EXECUTE')
      or has_function_privilege(client_role,'public.finish_screening_job_v1(text,uuid,uuid,uuid,text,jsonb,integer)','EXECUTE') then
      raise exception 'screening worker boundary exposed to %',client_role;
    end if;
  end loop;
  -- Isolate queue selection; all changes are rolled back below.
  update private.screening_jobs set available_at=now()+interval '1 day',lease_until=null;
  delete from private.screening_owner_budget where screening_owner_budget.owner_id=qa_owner_id;
  update private.screening_dispatch_budget set claimed=0;
  perform private.enqueue_screening_v1('visit',item_id,qa_owner_id,'{"text":"Synthetic shared text","images":[]}'::jsonb);
  select * into first_job from public.claim_screening_jobs_v1(1);
  if first_job.subject_id is distinct from item_id or first_job.lease_token is null then
    raise exception 'eligible synthetic revision was not leased';
  end if;
  perform private.enqueue_screening_v1('visit',item_id,qa_owner_id,'{"text":"Edited synthetic text","images":[]}'::jsonb);
  if public.finish_screening_job_v1('visit',item_id,first_job.revision,first_job.lease_token,'approved','{"categories":{"sexual":false}}'::jsonb) then
    raise exception 'stale screening result approved edited content';
  end if;
  select * into next_job from public.claim_screening_jobs_v1(1);
  if next_job.revision is not distinct from first_job.revision then
    raise exception 'shared edit did not create a new revision';
  end if;
  if not public.finish_screening_job_v1('visit',item_id,next_job.revision,next_job.lease_token,'approved','{"categories":{"sexual":false}}'::jsonb) then
    raise exception 'current unflagged revision was not approved';
  end if;
  if not private.screening_approved_v1('visit',item_id) then
    raise exception 'approved revision is not publishable';
  end if;
  perform private.enqueue_screening_v1('visit',item_id,qa_owner_id,null);
  if private.screening_approved_v1('visit',item_id)
    or exists(select 1 from private.screening_jobs where subject_kind='visit' and subject_id=item_id) then
    raise exception 'withdrawal retained a publishable queued payload';
  end if;
end;
$$;
rollback;
