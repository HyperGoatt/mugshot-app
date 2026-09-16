\set ON_ERROR_STOP on
begin;
do $$
declare
 owner_id uuid:='00000000-0000-4000-8000-000000000101';
 item uuid:=gen_random_uuid();
 role_name text;
begin
 if not exists(select 1 from auth.users where id=owner_id and email='alpha-fixture-1@example.invalid') then
  raise exception 'disposable QA fixture required';
 end if;
 foreach role_name in array array['anon','authenticated','service_role'] loop
  if has_table_privilege(role_name,'private.screening_existing_visibility','INSERT') then
   raise exception 'client can manufacture legacy eligibility';
  end if;
 end loop;
 perform private.enqueue_screening_v1('visit',item,owner_id,'{"text":"Original synthetic shared content","images":[]}'::jsonb);
 if not private.screening_approved_v1('visit',item) then raise exception 'safe local content was not admitted';end if;
 -- Simulate a migration-era technical review snapshot as database owner, never a client API.
 insert into private.screening_existing_visibility(subject_kind,subject_id,revision)
 select subject_kind,subject_id,revision from private.screening_jobs where subject_kind='visit' and subject_id=item;
 update private.screening_jobs set state='needs_review',reason='screening_unavailable'
 where subject_kind='visit' and subject_id=item;
 if not private.screening_approved_v1('visit',item) then raise exception 'review queue hid preserved revision';end if;
 perform private.enqueue_screening_v1('visit',item,owner_id,'{"text":"Edited synthetic content","images":[]}'::jsonb);
 if not private.screening_approved_v1('visit',item)
   or exists(select 1 from private.screening_existing_visibility where subject_id=item)
   or not exists(select 1 from private.screening_jobs where subject_kind='visit' and subject_id=item
     and state='approved' and reason='local_text_filter') then raise exception 'safe edit did not replace legacy eligibility';end if;
 update private.screening_jobs set state='rejected',reason='human_review' where subject_kind='visit' and subject_id=item;
 perform private.enqueue_screening_v1('visit',item,owner_id,'{"text":"Another safe edit","images":[]}'::jsonb);
 if private.screening_approved_v1('visit',item) then raise exception 'edit cleared a genuine rejection';end if;
 update private.screening_jobs set state='approved',reason='human_review' where subject_kind='visit' and subject_id=item;
 if not private.screening_approved_v1('visit',item) then raise exception 'actual approval not visible';end if;
 perform private.enqueue_screening_v1('visit',item,owner_id,null);
 if private.screening_approved_v1('visit',item) or exists(select 1 from private.screening_existing_visibility where subject_id=item) then raise exception 'Private withdrawal retained screening eligibility';end if;
end;
$$;
rollback;
