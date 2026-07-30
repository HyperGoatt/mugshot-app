begin;

-- Account deletion is deliberately split into two irreversible boundaries:
-- database/auth identity first, Storage objects second. A private, no-FK job
-- survives the identity cascade and gives the service-role worker a durable
-- retry receipt if Storage is temporarily unavailable.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table private.account_deletion_jobs (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  subject_id uuid not null,
  protocol_version smallint not null default 2 check (protocol_version = 2),
  status text not null default 'prepared' check (status in (
    'prepared',
    'identity_deletion_pending',
    'collaboration_pending',
    'cleanup_pending',
    'completed'
  )),
  storage_manifest jsonb not null default '[]'::jsonb
    check (jsonb_typeof(storage_manifest) = 'array'),
  collaboration_manifest jsonb not null default '{}'::jsonb
    check (jsonb_typeof(collaboration_manifest) = 'object'),
  identity_attempts integer not null default 0 check (identity_attempts >= 0),
  cleanup_attempts integer not null default 0 check (cleanup_attempts >= 0),
  last_error_code text check (char_length(coalesce(last_error_code, '')) <= 80),
  storage_ownership_detached_at timestamptz,
  identity_deleted_at timestamptz,
  collaboration_finalized_at timestamptz,
  cleanup_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table private.account_deletion_jobs is
  'Durable no-FK account deletion and post-identity Storage cleanup receipts.';
comment on column private.account_deletion_jobs.subject_id is
  'Intentionally has no FK so the cleanup receipt survives auth/public identity deletion.';

create index account_deletion_jobs_subject_created_idx
  on private.account_deletion_jobs (subject_id, created_at desc, id desc);
create index account_deletion_jobs_retry_idx
  on private.account_deletion_jobs (status, updated_at, id)
  where status in (
    'prepared', 'identity_deletion_pending', 'collaboration_pending', 'cleanup_pending'
  );

revoke all on table private.account_deletion_jobs
  from public, anon, authenticated;
grant usage on schema private to service_role;
grant select, insert, update on table private.account_deletion_jobs to service_role;

-- The original constraint used NULLS NOT DISTINCT, which accidentally allowed
-- only one custom list per owner and could make a legitimate ownership transfer
-- collide with the successor's custom list. System lists still remain unique.
alter table public.cafe_lists
  drop constraint if exists cafe_lists_owner_id_system_kind_key;
create unique index if not exists cafe_lists_owner_system_kind_unique
  on public.cafe_lists (owner_id, system_kind)
  where system_kind is not null;

-- Preserve collaborative rows across the public.users cascade. Authorship is
-- never reassigned: a departing contributor becomes NULL/anonymized, while a
-- list's stewardship is applied from the immutable plan after identity
-- deletion is confirmed.
alter table public.cafe_lists
  alter column owner_id drop not null,
  drop constraint if exists cafe_lists_owner_id_fkey,
  add constraint cafe_lists_owner_id_fkey
    foreign key (owner_id) references public.users(id) on delete set null;

alter table public.cafe_list_members
  alter column invited_by drop not null,
  drop constraint if exists cafe_list_members_invited_by_fkey,
  add constraint cafe_list_members_invited_by_fkey
    foreign key (invited_by) references public.users(id) on delete set null;

alter table public.cafe_list_items
  alter column contributor_id drop not null,
  drop constraint if exists cafe_list_items_contributor_id_fkey,
  add constraint cafe_list_items_contributor_id_fkey
    foreign key (contributor_id) references public.users(id) on delete set null;

alter table public.shared_memories
  add column managed_by uuid references public.users(id) on delete set null;

update public.shared_memories
set managed_by = created_by
where managed_by is null and created_by is not null;

create index shared_memories_manager_updated_idx
  on public.shared_memories (managed_by, updated_at desc, id);

comment on column public.shared_memories.managed_by is
  'Current steward for invitation management; distinct from immutable creator attribution.';

create or replace function private.set_shared_memory_initial_manager()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.managed_by is null then new.managed_by := new.created_by; end if;
  return new;
end;
$$;

revoke all on function private.set_shared_memory_initial_manager()
  from public, anon, authenticated;

drop trigger if exists set_shared_memory_initial_manager
  on public.shared_memories;
create trigger set_shared_memory_initial_manager
before insert on public.shared_memories
for each row execute function private.set_shared_memory_initial_manager();

-- Once preparation commits, no new owner-scoped collaboration object may be
-- introduced outside the immutable job plan. The normal FK cascade is still
-- allowed because it writes NULL, and finalization writes a different live
-- successor. This closes the prepare/delete concurrency window without making
-- any visible mutation during preparation itself.
create or replace function private.reject_deleting_account_collaboration_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidate uuid;
  candidates uuid[] := '{}'::uuid[];
begin
  if tg_table_name = 'cafe_lists' then
    if tg_op = 'INSERT' then
      candidates := array[new.owner_id];
    elsif new.owner_id is distinct from old.owner_id then
      candidates := array[new.owner_id];
    end if;
  elsif tg_table_name = 'shared_memories' then
    -- Auth/public-user cascades may null these two FKs in separate updates.
    -- Check only a newly assigned non-NULL pointer; an unchanged old pointer
    -- must not make the other pointer's old-subject -> NULL transition fail.
    if tg_op = 'INSERT' then
      candidates := array[new.created_by, new.managed_by];
    else
      if new.created_by is distinct from old.created_by then
        candidates := pg_catalog.array_append(candidates, new.created_by);
      end if;
      if new.managed_by is distinct from old.managed_by then
        candidates := pg_catalog.array_append(candidates, new.managed_by);
      end if;
    end if;
  end if;

  foreach candidate in array candidates loop
    if candidate is not null and exists (
      select 1
      from private.account_deletion_jobs job
      where job.subject_id = candidate
        and job.identity_deleted_at is null
        and job.status in ('prepared', 'identity_deletion_pending')
    ) then
      raise exception 'account deletion is already prepared'
        using errcode = '55000';
    end if;
  end loop;
  return new;
end;
$$;

revoke all on function private.reject_deleting_account_collaboration_owner()
  from public, anon, authenticated;

drop trigger if exists reject_deleting_account_cafe_list_owner
  on public.cafe_lists;
create trigger reject_deleting_account_cafe_list_owner
before insert or update of owner_id on public.cafe_lists
for each row execute function private.reject_deleting_account_collaboration_owner();

drop trigger if exists reject_deleting_account_shared_memory_owner
  on public.shared_memories;
create trigger reject_deleting_account_shared_memory_owner
before insert or update of created_by, managed_by on public.shared_memories
for each row execute function private.reject_deleting_account_collaboration_owner();

create or replace function public.prepare_account_deletion_v2(
  p_subject_id uuid,
  p_request_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_job private.account_deletion_jobs%rowtype;
  storage_rows jsonb := '[]'::jsonb;
  list_transfers jsonb := '[]'::jsonb;
  deleted_lists jsonb := '[]'::jsonb;
  memory_transfers jsonb := '[]'::jsonb;
  deleted_memories jsonb := '[]'::jsonb;
begin
  if p_subject_id is null or p_request_id is null then
    raise exception 'subject and request are required' using errcode = '22023';
  end if;

  -- Serialize preparations for this identity. Only service_role can execute
  -- this function; the subject comes from the verified Edge Function token.
  perform 1 from auth.users where id = p_subject_id for update;
  if not found then
    raise exception 'account identity is unavailable' using errcode = 'P0002';
  end if;

  select job.* into existing_job
  from private.account_deletion_jobs job
  where job.request_id = p_request_id
  for update;

  if found then
    if existing_job.subject_id <> p_subject_id then
      raise exception 'request belongs to another account' using errcode = '42501';
    end if;
    return jsonb_build_object(
      'job_id', existing_job.id,
      'request_id', existing_job.request_id,
      'subject_id', existing_job.subject_id,
      'status', existing_job.status,
      'storage_manifest', existing_job.storage_manifest
    );
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'bucket', object.bucket_id,
    'path', object.name,
    'owner_id', to_jsonb(object) -> 'owner_id',
    'owner', to_jsonb(object) -> 'owner'
  ) order by object.bucket_id, object.name), '[]'::jsonb)
  into storage_rows
  from storage.objects object
  where object.bucket_id in (
      'visit-photos',
      'visit-photos-private',
      'profile-media'
    )
    and lower(pg_catalog.split_part(object.name, '/', 1)) = lower(p_subject_id::text);

  -- Preparation records an immutable plan and makes no user-visible mutation.
  -- Prefer the earliest accepted editor, then the earliest accepted viewer.
  select coalesce(jsonb_agg(jsonb_build_object(
    'list_id', planned.id,
    'successor_id', planned.successor_id
  ) order by planned.created_at, planned.id), '[]'::jsonb)
  into list_transfers
  from (
    select listing.id, listing.created_at, successor.user_id as successor_id
    from public.cafe_lists listing
    left join lateral (
      select member.user_id
      from public.cafe_list_members member
      where member.list_id = listing.id
        and member.user_id <> p_subject_id
        and member.invitation_status = 'accepted'
      order by
        case when member.role = 'editor' then 0 else 1 end,
        coalesce(member.accepted_at, member.created_at),
        member.created_at,
        member.user_id
      limit 1
    ) successor on true
    where listing.owner_id = p_subject_id
      and listing.system_kind is null
  ) planned
  where planned.successor_id is not null;

  select coalesce(jsonb_agg(planned.id order by planned.created_at, planned.id), '[]'::jsonb)
  into deleted_lists
  from (
    select listing.id, listing.created_at, listing.system_kind,
      successor.user_id as successor_id
    from public.cafe_lists listing
    left join lateral (
      select member.user_id
      from public.cafe_list_members member
      where member.list_id = listing.id
        and member.user_id <> p_subject_id
        and member.invitation_status = 'accepted'
      order by
        case when member.role = 'editor' then 0 else 1 end,
        coalesce(member.accepted_at, member.created_at),
        member.created_at,
        member.user_id
      limit 1
    ) successor on true
    where listing.owner_id = p_subject_id
  ) planned
  where planned.system_kind is not null or planned.successor_id is null;

  -- Shared-memory stewardship is distinct from creator attribution. Accepted
  -- participants can inherit management, while created_by remains NULL after
  -- the original creator's identity is removed.
  select coalesce(jsonb_agg(jsonb_build_object(
    'shared_memory_id', planned.id,
    'successor_id', planned.successor_id
  ) order by planned.created_at, planned.id), '[]'::jsonb)
  into memory_transfers
  from (
    select memory.id, memory.created_at, successor.user_id as successor_id
    from public.shared_memories memory
    left join lateral (
      select member.user_id
      from public.shared_memory_members member
      where member.shared_memory_id = memory.id
        and member.user_id <> p_subject_id
        and member.status = 'accepted'
      order by
        coalesce(member.responded_at, member.created_at),
        member.created_at,
        member.user_id
      limit 1
    ) successor on true
    where memory.managed_by = p_subject_id or memory.created_by = p_subject_id
  ) planned
  where planned.successor_id is not null;

  select coalesce(jsonb_agg(planned.id order by planned.created_at, planned.id), '[]'::jsonb)
  into deleted_memories
  from (
    select memory.id, memory.created_at, successor.user_id as successor_id
    from public.shared_memories memory
    left join lateral (
      select member.user_id
      from public.shared_memory_members member
      where member.shared_memory_id = memory.id
        and member.user_id <> p_subject_id
        and member.status = 'accepted'
      order by coalesce(member.responded_at, member.created_at), member.created_at, member.user_id
      limit 1
    ) successor on true
    where memory.managed_by = p_subject_id or memory.created_by = p_subject_id
  ) planned
  where planned.successor_id is null;

  insert into private.account_deletion_jobs (
    request_id,
    subject_id,
    storage_manifest,
    collaboration_manifest
  ) values (
    p_request_id,
    p_subject_id,
    storage_rows,
    jsonb_build_object(
      'transferred_cafe_lists', list_transfers,
      'deleted_owner_only_cafe_lists', deleted_lists,
      'transferred_shared_memories', memory_transfers,
      'deleted_owner_only_shared_memories', deleted_memories
    )
  )
  returning * into existing_job;

  return jsonb_build_object(
    'job_id', existing_job.id,
    'request_id', existing_job.request_id,
    'subject_id', existing_job.subject_id,
    'status', existing_job.status,
    'storage_manifest', existing_job.storage_manifest
  );
end;
$$;

-- This compensating boundary is used only after Auth reports the documented
-- Storage-owner blocker. It refreshes and freezes the exact owner metadata in
-- the durable job, then detaches ownership without removing a single object.
create or replace function public.detach_account_storage_ownership_v2(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target private.account_deletion_jobs%rowtype;
  storage_rows jsonb;
begin
  select job.* into target
  from private.account_deletion_jobs job
  where job.id = p_job_id
  for update;
  if not found then
    raise exception 'deletion job not found' using errcode = 'P0002';
  end if;
  if target.identity_deleted_at is not null then
    raise exception 'identity is already deleted' using errcode = '55000';
  end if;
  if not exists(select 1 from auth.users where id = target.subject_id) then
    raise exception 'identity is unavailable for reversible detach' using errcode = '55000';
  end if;
  if target.storage_ownership_detached_at is not null then return; end if;

  lock table storage.objects in share row exclusive mode;
  select coalesce(jsonb_agg(jsonb_build_object(
    'bucket', object.bucket_id,
    'path', object.name,
    'owner_id', to_jsonb(object) -> 'owner_id',
    'owner', to_jsonb(object) -> 'owner'
  ) order by object.bucket_id, object.name), '[]'::jsonb)
  into storage_rows
  from storage.objects object
  where object.bucket_id in (
      'visit-photos', 'visit-photos-private', 'profile-media'
    )
    and lower(pg_catalog.split_part(object.name, '/', 1)) = lower(target.subject_id::text);

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'storage' and table_name = 'objects'
      and column_name = 'owner_id' and is_nullable = 'YES'
  ) then
    execute $detach_owner_id$
      update storage.objects set owner_id = null
      where bucket_id in ('visit-photos', 'visit-photos-private', 'profile-media')
        and lower(pg_catalog.split_part(name, '/', 1)) = lower($1::text)
    $detach_owner_id$ using target.subject_id;
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'storage' and table_name = 'objects'
      and column_name = 'owner' and is_nullable = 'YES'
  ) then
    execute $detach_owner$
      update storage.objects set owner = null
      where bucket_id in ('visit-photos', 'visit-photos-private', 'profile-media')
        and lower(pg_catalog.split_part(name, '/', 1)) = lower($1::text)
    $detach_owner$ using target.subject_id;
  end if;

  update private.account_deletion_jobs
  set storage_manifest = storage_rows,
      storage_ownership_detached_at = now(),
      updated_at = now()
  where id = p_job_id;
end;
$$;

create or replace function public.restore_account_storage_ownership_v2(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target private.account_deletion_jobs%rowtype;
  item jsonb;
  owner_id_type text;
  owner_type text;
begin
  select job.* into target
  from private.account_deletion_jobs job
  where job.id = p_job_id
  for update;
  if not found then
    raise exception 'deletion job not found' using errcode = 'P0002';
  end if;
  if target.storage_ownership_detached_at is null then return; end if;
  if not exists(select 1 from auth.users where id = target.subject_id) then
    raise exception 'cannot restore ownership after identity deletion' using errcode = '55000';
  end if;

  select column_info.udt_name into owner_id_type
  from information_schema.columns as column_info
  where column_info.table_schema = 'storage'
    and column_info.table_name = 'objects'
    and column_info.column_name = 'owner_id';
  select column_info.udt_name into owner_type
  from information_schema.columns as column_info
  where column_info.table_schema = 'storage'
    and column_info.table_name = 'objects'
    and column_info.column_name = 'owner';

  lock table storage.objects in share row exclusive mode;
  for item in
    select value from jsonb_array_elements(target.storage_manifest)
  loop
    if item ->> 'bucket' not in ('visit-photos', 'visit-photos-private', 'profile-media')
       or lower(pg_catalog.split_part(item ->> 'path', '/', 1))
          <> lower(target.subject_id::text) then
      raise exception 'unsafe Storage restore manifest' using errcode = '22023';
    end if;

    if owner_id_type = 'uuid' then
      execute 'update storage.objects set owner_id = $1 where bucket_id = $2 and name = $3'
      using nullif(item ->> 'owner_id', '')::uuid, item ->> 'bucket', item ->> 'path';
    elsif owner_id_type is not null then
      execute 'update storage.objects set owner_id = $1 where bucket_id = $2 and name = $3'
      using nullif(item ->> 'owner_id', ''), item ->> 'bucket', item ->> 'path';
    end if;

    if owner_type = 'uuid' then
      execute 'update storage.objects set owner = $1 where bucket_id = $2 and name = $3'
      using nullif(item ->> 'owner', '')::uuid, item ->> 'bucket', item ->> 'path';
    elsif owner_type is not null then
      execute 'update storage.objects set owner = $1 where bucket_id = $2 and name = $3'
      using nullif(item ->> 'owner', ''), item ->> 'bucket', item ->> 'path';
    end if;
  end loop;

  update private.account_deletion_jobs
  set storage_ownership_detached_at = null,
      status = 'identity_deletion_pending',
      updated_at = now()
  where id = p_job_id;
end;
$$;

create or replace function public.finalize_account_collaboration_v2(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target private.account_deletion_jobs%rowtype;
  planned_id uuid;
  successor uuid;
begin
  select job.* into target
  from private.account_deletion_jobs job
  where job.id = p_job_id
  for update;
  if not found then
    raise exception 'deletion job not found' using errcode = 'P0002';
  end if;
  if target.identity_deleted_at is null
     or exists(select 1 from auth.users where id = target.subject_id)
     or exists(select 1 from public.users where id = target.subject_id) then
    raise exception 'identity deletion must be confirmed first' using errcode = '55000';
  end if;
  if target.collaboration_finalized_at is not null then return; end if;

  for planned_id in
    select (value ->> 'list_id')::uuid
    from jsonb_array_elements(coalesce(
      target.collaboration_manifest -> 'transferred_cafe_lists', '[]'::jsonb
    ))
    union
    select value::uuid
    from jsonb_array_elements_text(coalesce(
      target.collaboration_manifest -> 'deleted_owner_only_cafe_lists', '[]'::jsonb
    ))
  loop
    successor := null;
    select member.user_id into successor
    from public.cafe_list_members member
    join public.users profile on profile.id = member.user_id
    where member.list_id = planned_id
      and member.invitation_status = 'accepted'
    order by
      case when member.role = 'editor' then 0 else 1 end,
      coalesce(member.accepted_at, member.created_at),
      member.created_at,
      member.user_id
    limit 1;

    if successor is null then
      delete from public.cafe_lists where id = planned_id and owner_id is null;
    else
      delete from public.cafe_list_members
      where list_id = planned_id and user_id = successor;
      update public.cafe_lists
      set owner_id = successor, updated_at = now()
      where id = planned_id and owner_id is null;
    end if;
  end loop;

  for planned_id in
    select (value ->> 'shared_memory_id')::uuid
    from jsonb_array_elements(coalesce(
      target.collaboration_manifest -> 'transferred_shared_memories', '[]'::jsonb
    ))
    union
    select value::uuid
    from jsonb_array_elements_text(coalesce(
      target.collaboration_manifest -> 'deleted_owner_only_shared_memories', '[]'::jsonb
    ))
  loop
    successor := null;
    select member.user_id into successor
    from public.shared_memory_members member
    join public.users profile on profile.id = member.user_id
    where member.shared_memory_id = planned_id
      and member.status = 'accepted'
    order by
      coalesce(member.responded_at, member.created_at),
      member.created_at,
      member.user_id
    limit 1;

    if successor is null then
      delete from public.shared_memories
      where id = planned_id and managed_by is null and created_by is null;
    else
      -- The invitation remains historically attributable to nobody after its
      -- inviter departs; it must not linger as an actionable consent request.
      update public.shared_memory_members
      set status = 'cancelled', responded_at = now()
      where shared_memory_id = planned_id
        and status = 'pending'
        and invited_by is null;
      update public.shared_memories
      set managed_by = successor, updated_at = now()
      where id = planned_id and managed_by is null;
    end if;
  end loop;

  update private.account_deletion_jobs
  set collaboration_finalized_at = now(),
      status = 'cleanup_pending',
      last_error_code = null,
      updated_at = now()
  where id = p_job_id;
end;
$$;

create or replace function public.read_account_deletion_job_v2(p_job_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select jsonb_build_object(
      'job_id', job.id,
      'request_id', job.request_id,
      'subject_id', job.subject_id,
      'status', job.status,
      'storage_manifest', job.storage_manifest,
      'storage_ownership_present', exists(
        select 1
        from storage.objects object
        where object.bucket_id in (
            'visit-photos', 'visit-photos-private', 'profile-media'
          )
          and lower(pg_catalog.split_part(object.name, '/', 1)) = lower(job.subject_id::text)
          and coalesce(
            to_jsonb(object) ->> 'owner_id',
            to_jsonb(object) ->> 'owner'
          ) = job.subject_id::text
      ),
      'identity_exists', exists(select 1 from auth.users where id = job.subject_id),
      'database_identity_exists', exists(select 1 from public.users where id = job.subject_id),
      'identity_deleted_at', job.identity_deleted_at,
      'storage_ownership_detached_at', job.storage_ownership_detached_at,
      'collaboration_finalized_at', job.collaboration_finalized_at,
      'cleanup_completed_at', job.cleanup_completed_at,
      'identity_attempts', job.identity_attempts,
      'cleanup_attempts', job.cleanup_attempts
    )
    from private.account_deletion_jobs job
    where job.id = p_job_id
  ), '{}'::jsonb);
$$;

create or replace function public.confirm_account_identity_deleted_v2(p_job_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare subject uuid;
begin
  select job.subject_id into subject
  from private.account_deletion_jobs job
  where job.id = p_job_id
  for update;
  if not found then
    raise exception 'deletion job not found' using errcode = 'P0002';
  end if;
  if exists(select 1 from auth.users where id = subject) then
    return false;
  end if;

  -- The normal auth cascade removes this row. This explicit finalization only
  -- handles a legacy database whose public profile FK was not cascading.
  delete from public.users where id = subject;
  return not exists(select 1 from public.users where id = subject);
end;
$$;

create or replace function public.mark_account_deletion_identity_pending_v2(
  p_job_id uuid,
  p_error_code text default 'identity_deletion_pending'
)
returns void
language sql
security definer
set search_path = ''
as $$
  update private.account_deletion_jobs
  set status = 'identity_deletion_pending',
      identity_attempts = identity_attempts + 1,
      last_error_code = left(coalesce(p_error_code, 'identity_deletion_pending'), 80),
      updated_at = now()
  where id = p_job_id
    and identity_deleted_at is null;
$$;

create or replace function public.mark_account_deletion_identity_deleted_v2(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare subject uuid;
begin
  select job.subject_id into subject
  from private.account_deletion_jobs job
  where job.id = p_job_id
  for update;
  if not found then
    raise exception 'deletion job not found' using errcode = 'P0002';
  end if;
  if exists(select 1 from auth.users where id = subject)
     or exists(select 1 from public.users where id = subject) then
    raise exception 'identity deletion is not confirmed' using errcode = '55000';
  end if;

  update private.account_deletion_jobs
  set status = 'collaboration_pending',
      identity_attempts = identity_attempts + 1,
      identity_deleted_at = coalesce(identity_deleted_at, now()),
      last_error_code = null,
      updated_at = now()
  where id = p_job_id;
end;
$$;

create or replace function public.mark_account_deletion_collaboration_pending_v2(
  p_job_id uuid,
  p_error_code text default 'collaboration_finalization_pending'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from private.account_deletion_jobs
    where id = p_job_id and identity_deleted_at is not null
  ) then
    raise exception 'identity deletion must precede collaboration finalization'
      using errcode = '55000';
  end if;
  update private.account_deletion_jobs
  set status = 'collaboration_pending',
      last_error_code = left(coalesce(p_error_code, 'collaboration_finalization_pending'), 80),
      updated_at = now()
  where id = p_job_id;
end;
$$;

create or replace function public.mark_account_deletion_cleanup_pending_v2(
  p_job_id uuid,
  p_error_code text default 'storage_cleanup_pending'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from private.account_deletion_jobs
    where id = p_job_id
      and identity_deleted_at is not null
      and collaboration_finalized_at is not null
  ) then
    raise exception 'collaboration finalization must precede Storage cleanup'
      using errcode = '55000';
  end if;

  update private.account_deletion_jobs
  set status = 'cleanup_pending',
      cleanup_attempts = cleanup_attempts + 1,
      last_error_code = left(coalesce(p_error_code, 'storage_cleanup_pending'), 80),
      updated_at = now()
  where id = p_job_id;
end;
$$;

create or replace function public.mark_account_deletion_cleanup_completed_v2(p_job_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not exists (
    select 1 from private.account_deletion_jobs
    where id = p_job_id
      and identity_deleted_at is not null
      and collaboration_finalized_at is not null
  ) then
    raise exception 'collaboration finalization must precede Storage cleanup'
      using errcode = '55000';
  end if;

  update private.account_deletion_jobs
  set status = 'completed',
      cleanup_attempts = cleanup_attempts + 1,
      cleanup_completed_at = coalesce(cleanup_completed_at, now()),
      last_error_code = null,
      updated_at = now()
  where id = p_job_id;
end;
$$;

create or replace function public.account_deletion_status_v2(p_request_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  return coalesce((
    select jsonb_build_object(
      'found', true,
      'protocol_version', job.protocol_version,
      'request_id', job.request_id,
      'job_id', job.id,
      'status', job.status,
      'identity_deleted', job.identity_deleted_at is not null,
      'collaboration_finalized', job.collaboration_finalized_at is not null,
      'cleanup_completed', job.cleanup_completed_at is not null,
      'updated_at', job.updated_at
    )
    from private.account_deletion_jobs job
    where job.request_id = p_request_id
      and job.subject_id = actor
  ), jsonb_build_object('found', false, 'protocol_version', 2));
end;
$$;

revoke all on function public.prepare_account_deletion_v2(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.detach_account_storage_ownership_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.restore_account_storage_ownership_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.finalize_account_collaboration_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.read_account_deletion_job_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.confirm_account_identity_deleted_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.mark_account_deletion_identity_pending_v2(uuid, text)
  from public, anon, authenticated;
revoke all on function public.mark_account_deletion_identity_deleted_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.mark_account_deletion_collaboration_pending_v2(uuid, text)
  from public, anon, authenticated;
revoke all on function public.mark_account_deletion_cleanup_pending_v2(uuid, text)
  from public, anon, authenticated;
revoke all on function public.mark_account_deletion_cleanup_completed_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.account_deletion_status_v2(uuid)
  from public, anon;

grant execute on function public.prepare_account_deletion_v2(uuid, uuid)
  to service_role;
grant execute on function public.detach_account_storage_ownership_v2(uuid)
  to service_role;
grant execute on function public.restore_account_storage_ownership_v2(uuid)
  to service_role;
grant execute on function public.finalize_account_collaboration_v2(uuid)
  to service_role;
grant execute on function public.read_account_deletion_job_v2(uuid)
  to service_role;
grant execute on function public.confirm_account_identity_deleted_v2(uuid)
  to service_role;
grant execute on function public.mark_account_deletion_identity_pending_v2(uuid, text)
  to service_role;
grant execute on function public.mark_account_deletion_identity_deleted_v2(uuid)
  to service_role;
grant execute on function public.mark_account_deletion_collaboration_pending_v2(uuid, text)
  to service_role;
grant execute on function public.mark_account_deletion_cleanup_pending_v2(uuid, text)
  to service_role;
grant execute on function public.mark_account_deletion_cleanup_completed_v2(uuid)
  to service_role;
grant execute on function public.account_deletion_status_v2(uuid)
  to authenticated;

-- Shared-memory management follows stewardship, never mutable creator
-- attribution. Existing v1 signatures stay stable for current clients.
drop policy if exists "Own or managed shared memory memberships"
  on public.shared_memory_members;
create policy "Own or managed shared memory memberships"
  on public.shared_memory_members for select to authenticated
  using (
    user_id = (select auth.uid())
    or invited_by = (select auth.uid())
    or exists (
      select 1
      from public.shared_memories memory
      where memory.id = shared_memory_id
        and memory.managed_by = (select auth.uid())
    )
  );

create or replace function public.list_managed_shared_memory_invitations_v1(
  p_shared_memory_id uuid
)
returns table (
  invitation_id uuid,
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  status text,
  invited_at timestamptz,
  responded_at timestamptz,
  left_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    member.id,
    profile.id,
    profile.display_name,
    profile.username,
    profile.avatar_url,
    member.status,
    member.created_at,
    member.responded_at,
    member.left_at
  from input
  join public.shared_memories memory
    on memory.id = p_shared_memory_id
   and memory.managed_by = input.actor
  join public.shared_memory_members member
    on member.shared_memory_id = memory.id
   and member.user_id <> input.actor
  join public.users profile on profile.id = member.user_id
  where input.actor is not null
    and not private.blocked_between(input.actor, profile.id)
  order by member.created_at, member.id;
$$;

create or replace function public.list_my_shared_memory_memberships_v1()
returns table (
  membership_id uuid,
  shared_memory_id uuid,
  status text,
  inviter_id uuid,
  inviter_display_name text,
  inviter_username text,
  inviter_avatar_url text,
  relationship_available boolean,
  context_type text,
  cafe_id uuid,
  location_label text,
  occurred_at timestamptz,
  invited_at timestamptz,
  responded_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    member.id,
    memory.id,
    member.status,
    case when not private.blocked_between(input.actor, inviter.id) then inviter.id end,
    case when not private.blocked_between(input.actor, inviter.id) then inviter.display_name end,
    case when not private.blocked_between(input.actor, inviter.id) then inviter.username end,
    case when not private.blocked_between(input.actor, inviter.id) then inviter.avatar_url end,
    not private.blocked_between(input.actor, inviter.id),
    memory.context_type,
    memory.cafe_id,
    memory.location_label,
    memory.occurred_at,
    member.created_at,
    member.responded_at
  from input
  join public.shared_memory_members member
    on member.user_id = input.actor
   and member.status in ('pending', 'accepted')
  join public.shared_memories memory on memory.id = member.shared_memory_id
  left join public.users inviter on inviter.id = member.invited_by
  where input.actor is not null
    and memory.managed_by is distinct from input.actor
  order by
    (member.status = 'pending') desc,
    member.created_at desc,
    member.id desc;
$$;

create or replace function public.list_owned_shared_memories_v1()
returns table (
  shared_memory_id uuid,
  source_visit_id uuid,
  context_type text,
  cafe_id uuid,
  location_label text,
  occurred_at timestamptz,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    memory.id,
    memory.source_visit_id,
    memory.context_type,
    memory.cafe_id,
    memory.location_label,
    memory.occurred_at,
    memory.created_at,
    memory.updated_at
  from input
  join public.shared_memories memory on memory.managed_by = input.actor
  where input.actor is not null
  order by memory.updated_at desc, memory.id desc;
$$;

create or replace function public.cancel_shared_memory_invitation_v1(p_invitation_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  changed_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  update public.shared_memory_members member
  set status = 'cancelled', responded_at = now()
  from public.shared_memories memory
  where member.id = p_invitation_id
    and member.shared_memory_id = memory.id
    and member.status = 'pending'
    and (member.invited_by = actor or memory.managed_by = actor);
  get diagnostics changed_count = row_count;
  if changed_count > 0 then
    update public.shared_memories memory
    set updated_at = now()
    where memory.id = (
      select member.shared_memory_id
      from public.shared_memory_members member
      where member.id = p_invitation_id
    );
  end if;
  return changed_count > 0;
end;
$$;

-- Accepted participants attach their own independently-owned post. After an
-- original creator departs, the current steward is the live trust boundary;
-- created_by remains immutable historical attribution (and therefore NULL).
create or replace function public.attach_shared_memory_contribution_v1(
  p_shared_memory_id uuid,
  p_visit_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  memory public.shared_memories%rowtype;
  target public.visits%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select * into memory
  from public.shared_memories
  where id = p_shared_memory_id
  for update;
  if not found then
    raise exception 'shared MugShot not found' using errcode = 'P0002';
  end if;
  if memory.managed_by is null
     or private.blocked_between(actor, memory.managed_by)
     or not exists (
       select 1
       from public.shared_memory_members member
       where member.shared_memory_id = memory.id
         and member.user_id = actor
         and member.status = 'accepted'
     ) then
    raise exception 'accepted participation required' using errcode = '42501';
  end if;

  select * into target
  from public.visits
  where id = p_visit_id and user_id = actor
  for update;
  if not found then
    raise exception 'visit ownership required' using errcode = '42501';
  end if;
  if target.upload_state <> 'complete' or target.cafe_session_role = 'secondary' then
    raise exception 'a complete primary post is required' using errcode = '22023';
  end if;
  if actor = memory.created_by and target.id <> memory.source_visit_id then
    raise exception 'shared MugShot creator contribution is the immutable source post'
      using errcode = '55000';
  end if;
  if exists (
    select 1
    from public.shared_memories existing_memory
    where existing_memory.source_visit_id = target.id
      and existing_memory.id <> memory.id
  ) then
    raise exception 'post already anchors another shared MugShot' using errcode = '23505';
  end if;
  if (case
       when lower(btrim(coalesce(target.context_type, ''))) = 'cafe'
         or (nullif(btrim(target.context_type), '') is null and target.cafe_id is not null)
         then 'cafe'
       when lower(btrim(coalesce(target.context_type, ''))) = 'home' then 'home'
       when lower(btrim(coalesce(target.context_type, ''))) = 'recipe' then 'recipe'
       else 'elsewhere'
     end) <> lower(btrim(memory.context_type)) then
    raise exception 'post context does not match the shared MugShot' using errcode = '22023';
  end if;
  if lower(btrim(memory.context_type)) = 'cafe'
     and target.cafe_id is distinct from memory.cafe_id then
    raise exception 'post cafe does not match the shared MugShot' using errcode = '22023';
  end if;

  insert into public.shared_memory_contributions (
    shared_memory_id, visit_id, user_id
  ) values (
    memory.id, target.id, actor
  )
  on conflict (shared_memory_id, user_id) do update
    set visit_id = excluded.visit_id,
        joined_at = now();

  update public.shared_memories
  set updated_at = now()
  where id = memory.id;

  return target.id;
end;
$$;

-- A steward cannot leave an object stranded. Stewardship moves to the current
-- earliest accepted participant, or the owner-only memory is removed.
create or replace function public.leave_shared_memory_v1(p_shared_memory_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  memory public.shared_memories%rowtype;
  successor uuid;
  changed_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select * into memory
  from public.shared_memories
  where id = p_shared_memory_id
  for update;
  if not found or not exists (
    select 1
    from public.shared_memory_members member
    where member.shared_memory_id = p_shared_memory_id
      and member.user_id = actor
      and member.status = 'accepted'
  ) then
    return false;
  end if;

  if memory.managed_by = actor then
    select member.user_id into successor
    from public.shared_memory_members member
    join public.users profile on profile.id = member.user_id
    where member.shared_memory_id = p_shared_memory_id
      and member.user_id <> actor
      and member.status = 'accepted'
    order by
      coalesce(member.responded_at, member.created_at),
      member.created_at,
      member.user_id
    limit 1;

    if successor is null then
      delete from public.shared_memories where id = p_shared_memory_id;
      return true;
    end if;
    update public.shared_memories
    set managed_by = successor, updated_at = now()
    where id = p_shared_memory_id;
  end if;

  update public.shared_memory_members
  set status = 'left', left_at = now(), responded_at = coalesce(responded_at, now())
  where shared_memory_id = p_shared_memory_id
    and user_id = actor
    and status = 'accepted';
  get diagnostics changed_count = row_count;

  if changed_count > 0 then
    delete from public.shared_memory_contributions
    where shared_memory_id = p_shared_memory_id and user_id = actor;
    update public.shared_memories
    set updated_at = now()
    where id = p_shared_memory_id;
  end if;
  return changed_count > 0;
end;
$$;

revoke all on function public.list_managed_shared_memory_invitations_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.list_my_shared_memory_memberships_v1()
  from public, anon, authenticated;
revoke all on function public.list_owned_shared_memories_v1()
  from public, anon, authenticated;
revoke all on function public.cancel_shared_memory_invitation_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.attach_shared_memory_contribution_v1(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.leave_shared_memory_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.list_managed_shared_memory_invitations_v1(uuid)
  to authenticated;
grant execute on function public.list_my_shared_memory_memberships_v1()
  to authenticated;
grant execute on function public.list_owned_shared_memories_v1()
  to authenticated;
grant execute on function public.cancel_shared_memory_invitation_v1(uuid)
  to authenticated;
grant execute on function public.attach_shared_memory_contribution_v1(uuid, uuid)
  to authenticated;
grant execute on function public.leave_shared_memory_v1(uuid)
  to authenticated;

-- V2 remains caller-sealed: there is no user parameter to substitute, and
-- every collection is filtered by auth.uid(). The function intentionally
-- excludes private moderation/operator tables and secret push tokens.
create or replace function public.build_owner_data_export_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  activity_export jsonb := jsonb_build_object(
    'contract_available', false,
    'notification_preferences', '{}'::jsonb,
    'activity_events', '[]'::jsonb,
    'registered_device_summary', '{}'::jsonb
  );
  activity_contract_available boolean := false;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  -- The activity contract is intentionally introduced by a later migration.
  -- Dynamic invocation keeps this migration bootstrappable while making an
  -- older/partial deployment explicit rather than silently claiming complete.
  if pg_catalog.to_regprocedure('public.build_owner_activity_export_v1()')
     is not null then
    execute 'select public.build_owner_activity_export_v1()'
      into activity_export;
    activity_contract_available := true;
  end if;

  return jsonb_build_object(
    'schema_version', 2,
    'generated_at', now(),
    'export_manifest', jsonb_build_object(
      'contract', 'mugshot-owner-data-export',
      'protocol_version', 2,
      'caller_binding', 'auth.uid',
      'server_contract_completeness', case
        when activity_contract_available then 'complete_as_of_schema_version_2'
        else 'partial'
      end,
      'known_omissions', case
        when activity_contract_available then '[]'::jsonb
        else jsonb_build_array('activity delivery contract is unavailable')
      end,
      'included_collections', jsonb_build_array(
        'profile',
        'journal entries and pending media references',
        'private notes and reflections',
        'recipes and recipe provenance',
        'taste and cafe-experience signals',
        'saved cafes and collaborative cafe lists',
        'shared MugShot memberships, stewardship, and contributions',
        'friendships, tags, comments, likes, reactions, and recommendations',
        'owner-visible safety receipts',
        'preferences and caller-visible activity history'
      ),
      'excluded_private_collections', jsonb_build_array(
        'moderation_operators',
        'moderation_case_events',
        'moderation_actions',
        'push_tokens',
        'device_identifiers',
        'private_delivery_queue'
      )
    ),
    'profile', coalesce((
      select to_jsonb(profile)
      from public.users profile
      where profile.id = actor
    ), '{}'::jsonb),
    'journal_entries', coalesce((
      select jsonb_agg(to_jsonb(visit) order by visit.created_at, visit.id)
      from public.visits visit
      where visit.user_id = actor
    ), '[]'::jsonb),
    'private_notes', coalesce((
      select jsonb_agg(to_jsonb(note) order by note.created_at, note.visit_id)
      from public.visit_private_notes note
      where note.user_id = actor
    ), '[]'::jsonb),
    'visit_photos', coalesce((
      select jsonb_agg(to_jsonb(photo) order by photo.created_at, photo.sort_order, photo.id)
      from public.visit_photos photo
      join public.visits visit on visit.id = photo.visit_id
      where visit.user_id = actor
    ), '[]'::jsonb),
    'drink_analyses', coalesce((
      select jsonb_agg(to_jsonb(analysis) order by analysis.created_at, analysis.visit_id)
      from public.visit_drink_analyses analysis
      where analysis.user_id = actor
    ), '[]'::jsonb),
    'journal_bookmarks', coalesce((
      select jsonb_agg(to_jsonb(bookmark) order by bookmark.created_at, bookmark.visit_id)
      from public.visit_bookmarks bookmark
      where bookmark.user_id = actor
    ), '[]'::jsonb),
    'recipe_identities', coalesce((
      select jsonb_agg(
        to_jsonb(identity) || jsonb_build_object(
          'versions', coalesce((
            select jsonb_agg(to_jsonb(version) order by version.version_number, version.id)
            from public.recipe_versions version
            where version.recipe_identity_id = identity.id
          ), '[]'::jsonb)
        ) order by identity.created_at, identity.id
      )
      from public.recipe_identities identity
      where identity.user_id = actor
    ), '[]'::jsonb),
    'taste_signals', coalesce((
      select jsonb_agg(to_jsonb(signal) order by signal.updated_at, signal.id)
      from public.taste_signals signal
      where signal.user_id = actor
    ), '[]'::jsonb),
    'tasting', jsonb_build_object(
      'sensory_snapshots', coalesce((
        select jsonb_agg(to_jsonb(snapshot) order by snapshot.created_at, snapshot.visit_id)
        from public.visit_sensory_snapshots snapshot
        where snapshot.user_id = actor
      ), '[]'::jsonb),
      'public_projections', coalesce((
        select jsonb_agg(to_jsonb(projection) order by projection.created_at, projection.visit_id)
        from public.visit_sensory_public_projections projection
        where projection.user_id = actor
      ), '[]'::jsonb),
      'corrections', coalesce((
        select jsonb_agg(to_jsonb(correction) order by correction.created_at, correction.id)
        from public.tasting_lens_corrections correction
        where correction.user_id = actor
      ), '[]'::jsonb),
      'preferences', coalesce((
        select to_jsonb(preference)
        from public.tasting_lens_preferences preference
        where preference.user_id = actor
      ), '{}'::jsonb)
    ),
    'v3_reflections', coalesce((
      select jsonb_agg(to_jsonb(reflection) order by reflection.created_at, reflection.visit_id)
      from public.visit_v3_reflections reflection
      where reflection.user_id = actor
    ), '[]'::jsonb),
    'cafe_experience', jsonb_build_object(
      'sessions', coalesce((
        select jsonb_agg(to_jsonb(session) order by session.started_at, session.id)
        from public.cafe_sessions session
        where session.user_id = actor
      ), '[]'::jsonb),
      'sip_intentions', coalesce((
        select jsonb_agg(to_jsonb(intention) order by intention.created_at, intention.visit_id)
        from public.cafe_sip_intentions intention
        where intention.user_id = actor
      ), '[]'::jsonb),
      'snapshots', coalesce((
        select jsonb_agg(to_jsonb(snapshot) order by snapshot.created_at, snapshot.session_id)
        from public.cafe_experience_snapshots snapshot
        where snapshot.user_id = actor
      ), '[]'::jsonb),
      'public_projections', coalesce((
        select jsonb_agg(to_jsonb(projection) order by projection.created_at, projection.session_id)
        from public.cafe_experience_public_projections projection
        where projection.user_id = actor
      ), '[]'::jsonb),
      'corrections', coalesce((
        select jsonb_agg(to_jsonb(correction) order by correction.created_at, correction.id)
        from public.cafe_experience_corrections correction
        where correction.user_id = actor
      ), '[]'::jsonb),
      'signals', coalesce((
        select jsonb_agg(to_jsonb(signal) order by signal.updated_at, signal.id)
        from public.cafe_experience_signals signal
        where signal.user_id = actor
      ), '[]'::jsonb),
      'signal_evidence', coalesce((
        select jsonb_agg(to_jsonb(evidence) order by evidence.created_at, evidence.signal_id)
        from public.cafe_experience_signal_evidence evidence
        where evidence.user_id = actor
      ), '[]'::jsonb)
    ),
    'saved_cafes', coalesce((
      select jsonb_agg(to_jsonb(state) order by state.updated_at, state.cafe_id)
      from public.user_cafe_states state
      where state.user_id = actor
    ), '[]'::jsonb),
    'collaboration', jsonb_build_object(
      'owned_cafe_lists', coalesce((
        select jsonb_agg(
          to_jsonb(listing) || jsonb_build_object(
            'items', coalesce((
              select jsonb_agg(to_jsonb(item) order by item.position, item.created_at, item.id)
              from public.cafe_list_items item
              where item.list_id = listing.id
            ), '[]'::jsonb),
            'members', coalesce((
              select jsonb_agg(to_jsonb(member) order by member.created_at, member.user_id)
              from public.cafe_list_members member
              where member.list_id = listing.id
            ), '[]'::jsonb)
          ) order by listing.created_at, listing.id
        )
        from public.cafe_lists listing
        where listing.owner_id = actor
      ), '[]'::jsonb),
      'cafe_list_memberships', coalesce((
        select jsonb_agg(
          to_jsonb(member) || jsonb_build_object(
            'list', jsonb_build_object(
              'id', listing.id,
              'owner_id', listing.owner_id,
              'title', listing.title,
              'description', listing.description,
              'visibility', listing.visibility,
              'system_kind', listing.system_kind,
              'created_at', listing.created_at,
              'updated_at', listing.updated_at
            )
          ) order by member.created_at, member.list_id
        )
        from public.cafe_list_members member
        join public.cafe_lists listing on listing.id = member.list_id
        where member.user_id = actor
      ), '[]'::jsonb),
      'cafe_list_contributions', coalesce((
        select jsonb_agg(to_jsonb(item) order by item.created_at, item.id)
        from public.cafe_list_items item
        where item.contributor_id = actor
      ), '[]'::jsonb),
      'created_shared_memories', coalesce((
        select jsonb_agg(
          to_jsonb(memory) || jsonb_build_object(
            'members', coalesce((
              select jsonb_agg(to_jsonb(member) order by member.created_at, member.id)
              from public.shared_memory_members member
              where member.shared_memory_id = memory.id
            ), '[]'::jsonb),
            'contributions', coalesce((
              select jsonb_agg(to_jsonb(contribution) order by contribution.joined_at, contribution.visit_id)
              from public.shared_memory_contributions contribution
              where contribution.shared_memory_id = memory.id
            ), '[]'::jsonb)
          ) order by memory.created_at, memory.id
        )
        from public.shared_memories memory
        where memory.created_by = actor
      ), '[]'::jsonb),
      'managed_shared_memories', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', memory.id,
          'created_by', memory.created_by,
          'managed_by', memory.managed_by,
          'source_visit_id', memory.source_visit_id,
          'context_type', memory.context_type,
          'cafe_id', memory.cafe_id,
          'location_label', memory.location_label,
          'occurred_at', memory.occurred_at,
          'created_at', memory.created_at,
          'updated_at', memory.updated_at
        ) order by memory.created_at, memory.id)
        from public.shared_memories memory
        where memory.managed_by = actor
          and memory.created_by is distinct from actor
      ), '[]'::jsonb),
      'shared_memory_memberships', coalesce((
        select jsonb_agg(
          to_jsonb(member) || jsonb_build_object(
            'memory', jsonb_build_object(
              'id', memory.id,
              'created_by', memory.created_by,
              'managed_by', memory.managed_by,
              'context_type', memory.context_type,
              'cafe_id', memory.cafe_id,
              'location_label', memory.location_label,
              'occurred_at', memory.occurred_at,
              'created_at', memory.created_at,
              'updated_at', memory.updated_at
            )
          ) order by member.created_at, member.id
        )
        from public.shared_memory_members member
        join public.shared_memories memory on memory.id = member.shared_memory_id
        where member.user_id = actor
      ), '[]'::jsonb),
      'shared_memory_contributions', coalesce((
        select jsonb_agg(to_jsonb(contribution) order by contribution.joined_at, contribution.visit_id)
        from public.shared_memory_contributions contribution
        where contribution.user_id = actor
      ), '[]'::jsonb)
    ),
    'social', jsonb_build_object(
      'friendships', coalesce((
        select jsonb_agg(to_jsonb(friendship) order by friendship.created_at, friendship.id)
        from public.friends friendship
        where friendship.user_id = actor or friendship.friend_user_id = actor
      ), '[]'::jsonb),
      'friend_requests', coalesce((
        select jsonb_agg(to_jsonb(request) order by request.created_at, request.id)
        from public.friend_requests request
        where request.from_user_id = actor or request.to_user_id = actor
      ), '[]'::jsonb),
      'comments_authored', coalesce((
        select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
          'id', comment.id,
          'visit_id', comment.visit_id,
          'parent_comment_id', comment.parent_comment_id,
          'text', comment.text,
          'created_at', comment.created_at,
          'edited_at', comment.edited_at,
          'removed_at', comment.removed_at
        )) order by comment.created_at, comment.id)
        from public.comments comment
        where comment.user_id = actor
      ), '[]'::jsonb),
      'likes', coalesce((
        select jsonb_agg(to_jsonb(liked) order by liked.created_at, liked.id)
        from public.likes liked
        where liked.user_id = actor
      ), '[]'::jsonb),
      'reactions', coalesce((
        select jsonb_agg(to_jsonb(reaction) order by reaction.created_at, reaction.visit_id)
        from public.visit_reactions reaction
        where reaction.user_id = actor
      ), '[]'::jsonb),
      'visit_tags_added_or_received', coalesce((
        select jsonb_agg(to_jsonb(tag) order by tag.created_at, tag.visit_id, tag.companion_user_id)
        from public.visit_companions tag
        where tag.added_by = actor or tag.companion_user_id = actor
      ), '[]'::jsonb),
      'comment_mentions_received', coalesce((
        select jsonb_agg(to_jsonb(mention) order by mention.created_at, mention.comment_id)
        from public.comment_mentions mention
        where mention.mentioned_user_id = actor
      ), '[]'::jsonb),
      'trusted_recommendations', coalesce((
        select jsonb_agg(to_jsonb(recommendation) order by recommendation.created_at, recommendation.id)
        from public.trusted_recommendations recommendation
        where recommendation.sender_id = actor or recommendation.recipient_id = actor
      ), '[]'::jsonb)
    ),
    'safety', jsonb_build_object(
      'blocks_created', coalesce((
        select jsonb_agg(to_jsonb(block) order by block.created_at, block.blocked_id)
        from public.user_blocks block
        where block.blocker_id = actor
      ), '[]'::jsonb),
      'report_receipts', coalesce((
        select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
          'id', report.id,
          'client_report_id', report.client_report_id,
          'reporter_subject_id', report.reporter_subject_id,
          'target_kind', report.target_kind,
          'target_id', report.target_id,
          'target_snapshot', report.target_snapshot,
          'reason', report.reason,
          'details', report.details,
          'status', report.status,
          'created_at', report.created_at,
          'closed_at', report.closed_at
        )) order by report.created_at, report.id)
        from public.reports report
        where report.reporter_subject_id = actor
      ), '[]'::jsonb)
    ),
    'preferences', jsonb_build_object(
      'capture', coalesce((
        select to_jsonb(preference)
        from public.user_capture_preferences preference
        where preference.user_id = actor
      ), '{}'::jsonb),
      'reflection', coalesce((
        select to_jsonb(preference)
        from public.user_reflection_preferences preference
        where preference.user_id = actor
      ), '{}'::jsonb),
      'rating_templates', coalesce((
        select jsonb_agg(to_jsonb(template) order by template.created_at, template.id)
        from public.rating_templates template
        where template.user_id = actor
      ), '[]'::jsonb)
    ),
    'notifications', coalesce((
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'id', notification.id,
        'actor_user_id', notification.actor_user_id,
        'type', notification.type,
        'visit_id', notification.visit_id,
        'comment_id', notification.comment_id,
        'created_at', notification.created_at,
        'read_at', notification.read_at
      )) order by notification.created_at, notification.id)
      from public.notifications notification
      where notification.user_id = actor
    ), '[]'::jsonb),
    'activity', activity_export,
    'registered_device_summary', coalesce((
      select jsonb_build_object(
        'record_count', count(*),
        'platforms', coalesce(
          jsonb_agg(distinct device.platform)
            filter (where device.platform is not null),
          '[]'::jsonb
        )
      )
      from public.user_devices device
      where device.user_id = actor
    ), jsonb_build_object('record_count', 0, 'platforms', '[]'::jsonb)),
    'media_references', coalesce((
      select jsonb_agg(reference.payload order by
        reference.payload ->> 'kind',
        reference.payload ->> 'bucket',
        reference.payload ->> 'path',
        reference.payload ->> 'url'
      )
      from (
        select distinct jsonb_build_object(
          'kind', 'storage',
          'bucket', object.bucket_id,
          'path', object.name,
          'access', case when bucket.public then 'public' else 'private' end
        ) as payload
        from storage.objects object
        join storage.buckets bucket on bucket.id = object.bucket_id
        where object.bucket_id in (
            'visit-photos',
            'visit-photos-private',
            'profile-media'
          )
          and lower(pg_catalog.split_part(object.name, '/', 1)) = lower(actor::text)
        union
        select jsonb_build_object(
          'kind', 'remote_url',
          'url', external.url,
          'access', 'external'
        )
        from (
          select profile.avatar_url as url
          from public.users profile
          where profile.id = actor
          union
          select profile.banner_url as url
          from public.users profile
          where profile.id = actor
        ) external
        where external.url is not null and btrim(external.url) <> ''
      ) reference
    ), '[]'::jsonb)
  );
end;
$$;

revoke all on function public.build_owner_data_export_v2()
  from public, anon;
grant execute on function public.build_owner_data_export_v2()
  to authenticated;

comment on function public.build_owner_data_export_v2() is
  'Caller-sealed owner export covering V3, tasting, social/safety receipts, tags, shared memories, collaboration, preferences, and resolvable media references.';

commit;
