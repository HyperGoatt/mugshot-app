begin;
-- Preserve already-shared revisions during first activation, without inventing
-- provider approval. Existing audience/block/moderation rules still apply.
create table private.screening_existing_visibility (
 subject_kind text not null,
 subject_id uuid not null,
 revision uuid not null,
 captured_at timestamptz not null default now(),
 primary key(subject_kind,subject_id),
 foreign key(subject_kind,subject_id) references private.screening_jobs(subject_kind,subject_id) on delete cascade
);
alter table private.screening_existing_visibility enable row level security;
revoke all on private.screening_existing_visibility from public,anon,authenticated,service_role;
insert into private.screening_existing_visibility(subject_kind,subject_id,revision)
 select subject_kind,subject_id,revision from private.screening_jobs
 where state in ('pending','needs_review');

create function private.expire_existing_screening_visibility_v1() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if old.revision is distinct from new.revision or new.state in ('approved','rejected') then
  delete from private.screening_existing_visibility
   where subject_kind=new.subject_kind and subject_id=new.subject_id;
 end if;
 return null;
end;
$$;
revoke all on function private.expire_existing_screening_visibility_v1() from public,anon,authenticated,service_role;
create trigger expire_existing_screening_visibility after update of revision,state on private.screening_jobs
 for each row execute function private.expire_existing_screening_visibility_v1();

-- Historical function name retained for read-contract compatibility. Job.state
-- and review APIs remain the authoritative moderation outcome, never this gate.
create or replace function private.screening_approved_v1(p_kind text,p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from private.screening_jobs job
 where job.subject_kind=p_kind and job.subject_id=p_id and (
  job.state='approved' or (job.state in ('pending','needs_review') and exists(
   select 1 from private.screening_existing_visibility legacy
   where legacy.subject_kind=job.subject_kind and legacy.subject_id=job.subject_id
     and legacy.revision=job.revision
  ))
 ));
$$;
comment on table private.screening_existing_visibility is
'One-time preservation of pre-cutover shared revision visibility; not moderation approval. Never insert future jobs. Edits, review decisions and deletion remove eligibility. Apply initial Sprint migrations atomically so no interim read gate hides existing content.';
commit;
