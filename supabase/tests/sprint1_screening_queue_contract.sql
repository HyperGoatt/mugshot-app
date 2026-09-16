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
  forbidden_blocked boolean:=false;
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
  -- External provider dispatch is retired. Safe text is admitted locally while
  -- the same sealed table continues to hold reactive moderation decisions.
  perform private.enqueue_screening_v1('visit',item_id,qa_owner_id,'{"text":"Synthetic shared text","images":[]}'::jsonb);
  select * into first_job from private.screening_jobs where subject_kind='visit' and subject_id=item_id;
  if first_job.state is distinct from 'approved' or first_job.reason is distinct from 'local_text_filter'
    or first_job.lease_token is not null then
    raise exception 'safe synthetic revision was not admitted locally';
  end if;
  if exists(select 1 from public.claim_screening_jobs_v1(1)) then
    raise exception 'retired provider queue still leased work';
  end if;
  perform private.enqueue_screening_v1('visit',item_id,qa_owner_id,'{"text":"Edited synthetic text","images":[]}'::jsonb);
  select * into next_job from private.screening_jobs where subject_kind='visit' and subject_id=item_id;
  if next_job.revision is not distinct from first_job.revision or next_job.state is distinct from 'approved' then
    raise exception 'shared edit did not create a new revision';
  end if;
  if not private.screening_approved_v1('visit',item_id) then
    raise exception 'approved revision is not publishable';
  end if;
  begin
    perform private.enqueue_screening_v1('visit',item_id,qa_owner_id,'{"text":"I will kill you","images":[]}'::jsonb);
  exception when sqlstate '22023' then forbidden_blocked:=true;
  end;
  if not forbidden_blocked then raise exception 'forbidden local text was admitted';end if;
  if not private.screening_approved_v1('visit',item_id) then raise exception 'rejected edit damaged the last admitted revision';end if;
  update private.screening_jobs set state='rejected',reason='human_review'
  where subject_kind='visit' and subject_id=item_id;
  perform private.enqueue_screening_v1('visit',item_id,qa_owner_id,'{"text":"Another safe edit","images":[]}'::jsonb);
  if private.screening_approved_v1('visit',item_id) then raise exception 'safe edit cleared a genuine rejection';end if;
  perform private.enqueue_screening_v1('visit',item_id,qa_owner_id,null);
  if private.screening_approved_v1('visit',item_id)
    or exists(select 1 from private.screening_jobs where subject_kind='visit' and subject_id=item_id) then
    raise exception 'withdrawal retained a publishable queued payload';
  end if;
end;
$$;
rollback;
