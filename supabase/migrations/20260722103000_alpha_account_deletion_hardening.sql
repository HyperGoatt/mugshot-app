begin;

-- Account deletion V3 is additive and intentionally does not delete or rewrite
-- existing Mugshot content. It hardens the irreversible boundary with a
-- fresh-AMR/new-session step-up authorization, an exact owner-validated
-- Storage manifest, a single active job per identity, immutable collaboration
-- succession, and a capability-bound recovery route that survives Auth deletion.

-- ---------------------------------------------------------------------------
-- Durable job and lifecycle serialization
-- ---------------------------------------------------------------------------

alter table private.account_deletion_jobs
  drop constraint if exists account_deletion_jobs_protocol_version_check;
alter table private.account_deletion_jobs
  add constraint account_deletion_jobs_protocol_version_check
  check (protocol_version in (2, 3));

alter table private.account_deletion_jobs
  add column if not exists authorized_session_id uuid,
  add column if not exists authorized_at timestamptz,
  add column if not exists step_up_challenge_id uuid,
  add column if not exists recovery_secret_hash bytea,
  add column if not exists subject_proof_hash bytea,
  add column if not exists storage_manifest_frozen_at timestamptz,
  add column if not exists storage_manifest_object_count integer not null default 0,
  add column if not exists storage_preflight_verified_at timestamptz,
  add column if not exists lease_token uuid,
  add column if not exists lease_expires_at timestamptz,
  add column if not exists next_attempt_at timestamptz not null default now(),
  add column if not exists redacted_at timestamptz,
  add column if not exists receipt_expires_at timestamptz,
  add column if not exists completion_receipt_fresh_until timestamptz,
  add column if not exists completion_proof_state text
    check (completion_proof_state is null or completion_proof_state in (
      'completed', 'expired_completed'
    ));

alter table private.account_deletion_jobs
  alter column subject_id drop not null;

update private.account_deletion_jobs
set storage_manifest_object_count = jsonb_array_length(storage_manifest)
where storage_manifest_object_count <> jsonb_array_length(storage_manifest);

-- Recovery capabilities currently have no client-side expiry. Existing
-- minimized V3 completions therefore retain a capability-bound tombstone for
-- that same lifetime; only their fresh-receipt presentation is time-bounded.
update private.account_deletion_jobs job
set completion_proof_state = coalesce(
      job.completion_proof_state,
      case
        when coalesce(job.cleanup_completed_at, job.updated_at) + interval '400 days' <= now()
          then 'expired_completed'
        else 'completed'
      end
    ),
    completion_receipt_fresh_until = coalesce(
      job.completion_receipt_fresh_until,
      coalesce(job.cleanup_completed_at, job.updated_at) + interval '400 days'
    ),
    receipt_expires_at = null
where job.protocol_version = 3 and job.status = 'completed';

alter table private.account_deletion_jobs
  add constraint account_deletion_jobs_recovery_hash_length_check
    check (recovery_secret_hash is null or octet_length(recovery_secret_hash) = 32),
  add constraint account_deletion_jobs_subject_proof_length_check
    check (subject_proof_hash is null or octet_length(subject_proof_hash) = 32),
  add constraint account_deletion_jobs_storage_manifest_count_check
    check (
      storage_manifest_object_count >= 0
      and storage_manifest_object_count = jsonb_array_length(storage_manifest)
    ),
  add constraint account_deletion_jobs_v3_authorization_check
    check (
      protocol_version <> 3
      or status = 'completed'
      or (
        recovery_secret_hash is not null
        and subject_proof_hash is not null
        and authorized_session_id is not null
        and authorized_at is not null
        and step_up_challenge_id is not null
        and storage_manifest_frozen_at is not null
      )
    );

create table if not exists private.account_deletion_step_up_challenges (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null,
  subject_id uuid not null,
  initiating_session_id uuid not null,
  recovery_secret_hash bytea not null check (octet_length(recovery_secret_hash) = 32),
  subject_proof_hash bytea not null check (octet_length(subject_proof_hash) = 32),
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  authorized_session_id uuid,
  authorized_amr_method text,
  authorized_amr_at timestamptz,
  authorization_secret_hash bytea
    check (authorization_secret_hash is null or octet_length(authorization_secret_hash) = 32),
  authorization_expires_at timestamptz,
  authorized_at timestamptz,
  superseded_at timestamptz,
  consumed_at timestamptz,
  updated_at timestamptz not null default now(),
  check (expires_at > issued_at),
  check (
    (authorized_at is null and authorized_session_id is null
      and authorized_amr_method is null and authorized_amr_at is null
      and authorization_secret_hash is null and authorization_expires_at is null)
    or
    (authorized_at is not null and authorized_session_id is not null
      and authorized_amr_method is not null and authorized_amr_at is not null
      and authorization_secret_hash is not null and authorization_expires_at is not null)
  )
);

revoke all on table private.account_deletion_step_up_challenges
  from public, anon, authenticated;
grant select, insert, update, delete
  on table private.account_deletion_step_up_challenges to service_role;

create unique index if not exists account_deletion_step_up_secret_v3
  on private.account_deletion_step_up_challenges (authorization_secret_hash)
  where authorization_secret_hash is not null;
create index if not exists account_deletion_step_up_subject_request_v3
  on private.account_deletion_step_up_challenges (
    subject_id, request_id, issued_at desc, id desc
  );
create index if not exists account_deletion_step_up_expiry_v3
  on private.account_deletion_step_up_challenges (expires_at, id);

do $$
begin
  if exists (
    select 1
    from private.account_deletion_jobs job
    where job.subject_id is not null and job.status <> 'completed'
    group by job.subject_id
    having count(*) > 1
  ) then
    raise exception 'multiple active account deletion jobs require operator review'
      using errcode = '55000';
  end if;
end;
$$;

create unique index if not exists account_deletion_jobs_one_active_subject_v3
  on private.account_deletion_jobs (subject_id)
  where subject_id is not null and status <> 'completed';
create unique index if not exists account_deletion_jobs_recovery_hash_v3
  on private.account_deletion_jobs (recovery_secret_hash)
  where recovery_secret_hash is not null;
create index if not exists account_deletion_jobs_due_v3
  on private.account_deletion_jobs (next_attempt_at, updated_at, id)
  where protocol_version = 3 and status <> 'completed';

create or replace function private.lock_account_lifecycle_v3(p_subject_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_subject_id is not null then
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(
        'mugshot-account-lifecycle-v3:' || lower(p_subject_id::text),
        0
      )
    );
  end if;
end;
$$;

create or replace function private.account_deletion_active_as(p_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_subject_id is not null and exists (
    select 1
    from private.account_deletion_jobs job
    where job.subject_id = p_subject_id
      and job.status <> 'completed'
  );
$$;

create or replace function private.can_write_account_storage_as(p_subject_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_subject_id)
    and not private.account_deletion_active_as(p_subject_id);
$$;

revoke all on function private.lock_account_lifecycle_v3(uuid)
  from public, anon, authenticated;
revoke all on function private.account_deletion_active_as(uuid)
  from public, anon, authenticated;
revoke all on function private.can_write_account_storage_as(uuid)
  from public, anon, authenticated;

-- Row triggers are a second serialization boundary for every collaboration
-- table. Preparation also takes SHARE ROW EXCLUSIVE table locks below, so an
-- in-flight mutation either commits before the frozen plan or aborts/retries;
-- it can never land silently between planning and Auth deletion.
create or replace function private.serialize_account_collaboration_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  candidates uuid[] := '{}'::uuid[];
  assignments uuid[] := '{}'::uuid[];
  related_owners uuid[] := '{}'::uuid[];
  actor uuid := (select auth.uid());
  candidate uuid;
  old_owner uuid;
  new_owner uuid;
  monotonic_safety_exit boolean := false;
begin
  if tg_table_name = 'cafe_lists' then
    if tg_op = 'INSERT' then
      candidates := array[new.owner_id];
      assignments := array[new.owner_id];
      related_owners := array[new.owner_id];
    elsif tg_op = 'DELETE' then
      candidates := array[old.owner_id];
      related_owners := array[old.owner_id];
    else
      candidates := array[old.owner_id, new.owner_id];
      related_owners := array[old.owner_id, new.owner_id];
      if new.owner_id is distinct from old.owner_id and new.owner_id is not null then
        assignments := array[new.owner_id];
      end if;
    end if;
  elsif tg_table_name = 'cafe_list_members' then
    if tg_op <> 'INSERT' then
      select list.owner_id into old_owner
      from public.cafe_lists list where list.id = old.list_id;
      candidates := array[old_owner, old.user_id, old.invited_by];
      related_owners := array[old_owner];
    end if;
    if tg_op <> 'DELETE' then
      select list.owner_id into new_owner
      from public.cafe_lists list where list.id = new.list_id;
      candidates := candidates || array[new_owner, new.user_id, new.invited_by];
      related_owners := related_owners || array[new_owner];
    end if;
    if tg_op = 'INSERT' then
      assignments := array[new.user_id, new.invited_by];
    elsif tg_op = 'DELETE' then
      monotonic_safety_exit := true;
    elsif tg_op = 'UPDATE' then
      monotonic_safety_exit :=
        new.list_id is not distinct from old.list_id
        and new.user_id is not distinct from old.user_id
        and new.role is not distinct from old.role
        and new.invited_by is not distinct from old.invited_by
        and old.invitation_status = 'pending'
        and new.invitation_status in ('declined', 'cancelled');
      if new.user_id is distinct from old.user_id
         or new.list_id is distinct from old.list_id then
        assignments := pg_catalog.array_append(assignments, new.user_id);
      end if;
      if new.invited_by is distinct from old.invited_by
         or new.list_id is distinct from old.list_id then
        assignments := pg_catalog.array_append(assignments, new.invited_by);
      end if;
      if new.invitation_status = 'accepted'
         and (
           new.invitation_status is distinct from old.invitation_status
           or new.list_id is distinct from old.list_id
         ) then
        assignments := pg_catalog.array_append(assignments, new.user_id);
      end if;
    end if;
  elsif tg_table_name = 'shared_memories' then
    if tg_op = 'INSERT' then
      candidates := array[new.created_by, new.managed_by];
      assignments := array[new.created_by, new.managed_by];
      related_owners := array[new.created_by, new.managed_by];
    elsif tg_op = 'DELETE' then
      candidates := array[old.created_by, old.managed_by];
      related_owners := array[old.created_by, old.managed_by];
    else
      candidates := array[old.created_by, old.managed_by, new.created_by, new.managed_by];
      related_owners := array[
        old.created_by, old.managed_by, new.created_by, new.managed_by
      ];
      if new.created_by is distinct from old.created_by and new.created_by is not null then
        assignments := pg_catalog.array_append(assignments, new.created_by);
      end if;
      if new.managed_by is distinct from old.managed_by and new.managed_by is not null then
        assignments := pg_catalog.array_append(assignments, new.managed_by);
      end if;
    end if;
  elsif tg_table_name = 'shared_memory_members' then
    if tg_op <> 'INSERT' then
      select memory.managed_by, memory.created_by into old_owner, new_owner
      from public.shared_memories memory where memory.id = old.shared_memory_id;
      candidates := array[old_owner, new_owner, old.user_id, old.invited_by];
      related_owners := array[old_owner, new_owner];
    end if;
    if tg_op <> 'DELETE' then
      select memory.managed_by, memory.created_by into old_owner, new_owner
      from public.shared_memories memory where memory.id = new.shared_memory_id;
      candidates := candidates || array[
        old_owner, new_owner, new.user_id, new.invited_by
      ];
      related_owners := related_owners || array[old_owner, new_owner];
    end if;
    if tg_op = 'INSERT' then
      assignments := array[new.user_id, new.invited_by];
    elsif tg_op = 'DELETE' then
      monotonic_safety_exit := true;
    elsif tg_op = 'UPDATE' then
      monotonic_safety_exit :=
        new.shared_memory_id is not distinct from old.shared_memory_id
        and new.user_id is not distinct from old.user_id
        and new.invited_by is not distinct from old.invited_by
        and (
          (old.status = 'pending' and new.status in ('declined', 'cancelled'))
          or (old.status = 'accepted' and new.status = 'left')
        );
      if new.user_id is distinct from old.user_id
         or new.shared_memory_id is distinct from old.shared_memory_id then
        assignments := pg_catalog.array_append(assignments, new.user_id);
      end if;
      if new.invited_by is distinct from old.invited_by
         or new.shared_memory_id is distinct from old.shared_memory_id then
        assignments := pg_catalog.array_append(assignments, new.invited_by);
      end if;
      if new.status = 'accepted' and (
        new.status is distinct from old.status
        or new.shared_memory_id is distinct from old.shared_memory_id
      ) then
        assignments := pg_catalog.array_append(assignments, new.user_id);
      end if;
    end if;
  end if;

  for candidate in
    select distinct value
    from pg_catalog.unnest(candidates) value
    where value is not null
    order by value
  loop
    perform private.lock_account_lifecycle_v3(candidate);
  end loop;

  -- User-driven invitation, acceptance, departure, ownership, or deletion
  -- changes cannot alter a collaboration plan after it is frozen. Auth-null
  -- work is reserved for trusted FK cascades and the deletion finalizer.
  if actor is not null and not monotonic_safety_exit and exists (
    select 1
    from pg_catalog.unnest(related_owners) value
    where value is not null and private.account_deletion_active_as(value)
  ) then
    raise exception 'collaboration plan is frozen by account deletion'
      using errcode = '55000';
  end if;

  if exists (
    select 1
    from pg_catalog.unnest(assignments) value
    where value is not null and private.account_deletion_active_as(value)
  ) then
    raise exception 'account deletion is already prepared' using errcode = '55000';
  end if;
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.serialize_account_collaboration_v3()
  from public, anon, authenticated;

drop trigger if exists serialize_account_collaboration_lists_v3 on public.cafe_lists;
create trigger serialize_account_collaboration_lists_v3
before insert or delete or update of owner_id on public.cafe_lists
for each row execute function private.serialize_account_collaboration_v3();
drop trigger if exists serialize_account_collaboration_list_members_v3 on public.cafe_list_members;
create trigger serialize_account_collaboration_list_members_v3
before insert or delete or update of list_id, user_id, invited_by, invitation_status
on public.cafe_list_members
for each row execute function private.serialize_account_collaboration_v3();
drop trigger if exists serialize_account_shared_memories_v3 on public.shared_memories;
create trigger serialize_account_shared_memories_v3
before insert or delete or update of created_by, managed_by on public.shared_memories
for each row execute function private.serialize_account_collaboration_v3();
drop trigger if exists serialize_account_shared_memory_members_v3 on public.shared_memory_members;
create trigger serialize_account_shared_memory_members_v3
before insert or delete or update of shared_memory_id, user_id, invited_by, status
on public.shared_memory_members
for each row execute function private.serialize_account_collaboration_v3();

-- The inviter foreign key is intentionally ON DELETE SET NULL. PostgreSQL
-- fires BEFORE UPDATE triggers alphabetically, so the pair-lock trigger must
-- allow the exact trusted FK transition before the invitation guard converts
-- pending consent requests to cancelled. App callers still cannot erase the
-- inviter from an actionable or accepted shared MugShot membership.
create or replace function private.enforce_shared_member_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and (select auth.uid()) is null
     and old.invited_by is not null
     and new.invited_by is null
     and new.shared_memory_id is not distinct from old.shared_memory_id
     and new.user_id is not distinct from old.user_id
     and new.status is not distinct from old.status then
    return new;
  end if;

  if new.invited_by is null then
    if new.status in ('pending', 'accepted') then
      raise exception 'shared MugShot inviter is unavailable' using errcode = '42501';
    end if;
    return new;
  end if;

  perform private.lock_social_pairs_v1(
    new.invited_by,
    array[new.user_id],
    new.status in ('pending', 'accepted')
  );
  return new;
end;
$$;

revoke all on function private.enforce_shared_member_pair_lock_v1()
  from public, anon, authenticated;

-- Keep the still-callable legacy recipe inbox on the same live-account,
-- suspension, block, audience, and explicit-recipient boundary as every V3
-- recipe projection. The result remains an allowlisted recipe snapshot.
create or replace function public.list_shared_recipes()
returns table(
  recommendation_id uuid,
  recipe_identity_id uuid,
  recipe_version_id uuid,
  recipe_name text,
  version_number integer,
  version_label text,
  brew_details jsonb,
  sender_id uuid,
  note text,
  shared_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    recommendation.id,
    identity.id,
    version.id,
    identity.name,
    version.version_number,
    version.version_label,
    jsonb_strip_nulls(jsonb_build_object(
      'beans', version.brew_details -> 'beans',
      'doseGrams', version.brew_details -> 'doseGrams',
      'yieldGrams', version.brew_details -> 'yieldGrams',
      'brewTimeSeconds', version.brew_details -> 'brewTimeSeconds',
      'beanOrigin', version.brew_details -> 'beanOrigin',
      'roastLevel', version.brew_details -> 'roastLevel',
      'grindSetting', version.brew_details -> 'grindSetting',
      'waterTemperatureCelsius', version.brew_details -> 'waterTemperatureCelsius',
      'waterNotes', version.brew_details -> 'waterNotes',
      'recipeName', version.brew_details -> 'recipeName',
      'recipeVersion', version.brew_details -> 'recipeVersion',
      'steps', version.brew_details -> 'steps',
      'additions', version.brew_details -> 'additions',
      'servingVolumeMilliliters', version.brew_details -> 'servingVolumeMilliliters',
      'espressoShotCount', version.brew_details -> 'espressoShotCount'
    )),
    recommendation.sender_id,
    recommendation.note,
    recommendation.created_at
  from public.trusted_recommendations recommendation
  join public.recipe_versions version
    on version.id = recommendation.target_recipe_version_id
  join public.recipe_identities identity
    on identity.id = version.recipe_identity_id
  where recommendation.target_kind = 'recipe'
    and recommendation.recipient_id = (select auth.uid())
    and recommendation.status <> 'dismissed'
    and private.can_project_recipe_version_as(
      version.id,
      (select auth.uid())
    )
  order by recommendation.created_at desc, recommendation.id desc;
$$;

revoke all on function public.list_shared_recipes() from public, anon;
grant execute on function public.list_shared_recipes() to authenticated;

-- ---------------------------------------------------------------------------
-- Exact owner-validated Storage inventory and stale-token write boundary
-- ---------------------------------------------------------------------------

create or replace function private.safe_account_storage_path_v3(
  p_subject_id uuid,
  p_path text
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_subject_id is not null
    and p_path is not null
    and lower(pg_catalog.split_part(p_path, '/', 1)) = lower(p_subject_id::text)
    and p_path not like '%\\%'
    and p_path not like '%//%'
    and p_path !~ '(^|/)[.][.]?(/|$)'
    and p_path !~ '[[:cntrl:]]'
    and pg_catalog.array_length(pg_catalog.string_to_array(p_path, '/'), 1) >= 2;
$$;

revoke all on function private.safe_account_storage_path_v3(uuid, text)
  from public, anon, authenticated;

create or replace function private.account_storage_mentions_subject_v3(
  p_object jsonb,
  p_subject_id uuid
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select p_subject_id is not null and (
    nullif(p_object ->> 'owner_id', '') = p_subject_id::text
    or nullif(p_object ->> 'owner', '') = p_subject_id::text
  );
$$;

create or replace function private.account_storage_owner_is_exact_v3(
  p_object jsonb,
  p_subject_id uuid
)
returns boolean
language sql
immutable
set search_path = ''
as $$
  select private.account_storage_mentions_subject_v3(p_object, p_subject_id)
    and (
      nullif(p_object ->> 'owner_id', '') is null
      or nullif(p_object ->> 'owner_id', '') = p_subject_id::text
    )
    and (
      nullif(p_object ->> 'owner', '') is null
      or nullif(p_object ->> 'owner', '') = p_subject_id::text
    );
$$;

revoke all on function private.account_storage_mentions_subject_v3(jsonb, uuid)
  from public, anon, authenticated;
revoke all on function private.account_storage_owner_is_exact_v3(jsonb, uuid)
  from public, anon, authenticated;

create or replace function private.guard_account_storage_write_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  prefix_subject uuid;
  actor uuid := auth.uid();
  target_bucket text;
  target_name text;
  target_object jsonb;
  owner_id_value text;
  owner_value text;
  authoritative_subject uuid;
  trusted_storage_role boolean := coalesce(auth.jwt() ->> 'role', session_user)
    in ('service_role', 'postgres');
  maintenance_job text := nullif(
    current_setting('mugshot.account_deletion_storage_maintenance_job', true),
    ''
  );
begin
  if tg_op = 'DELETE' then
    target_bucket := old.bucket_id;
    target_name := old.name;
    target_object := to_jsonb(old);
  else
    target_bucket := new.bucket_id;
    target_name := new.name;
    target_object := to_jsonb(new);
  end if;

  owner_id_value := nullif(target_object ->> 'owner_id', '');
  owner_value := nullif(target_object ->> 'owner', '');
  if owner_id_value is not null and owner_value is not null
     and owner_id_value <> owner_value then
    raise exception 'Storage owner metadata conflict' using errcode = '55000';
  end if;
  begin
    authoritative_subject := coalesce(owner_id_value, owner_value)::uuid;
  exception when invalid_text_representation then
    raise exception 'invalid Storage owner metadata' using errcode = '22023';
  end;

  -- An account in deletion cannot acquire a new owned object in any bucket,
  -- including the empty-manifest case. Only exact detach/restore work executed
  -- by the lifecycle RPC for this job may change frozen ownership metadata.
  if tg_op <> 'DELETE' and authoritative_subject is not null then
    perform private.lock_account_lifecycle_v3(authoritative_subject);
    if private.account_deletion_active_as(authoritative_subject)
       and not (
         trusted_storage_role
         and exists (
           select 1 from private.account_deletion_jobs job
           where job.subject_id = authoritative_subject
             and job.status <> 'completed'
             and job.id::text = maintenance_job
         )
       ) then
      raise exception 'account Storage writes are unavailable' using errcode = '42501';
    end if;
  end if;

  if target_bucket not in ('visit-photos', 'visit-photos-private', 'profile-media') then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  begin
    prefix_subject := pg_catalog.split_part(target_name, '/', 1)::uuid;
  exception when invalid_text_representation then
    raise exception 'owner-scoped Storage path required' using errcode = '22023';
  end;
  if not private.safe_account_storage_path_v3(prefix_subject, target_name) then
    raise exception 'unsafe owner-scoped Storage path' using errcode = '22023';
  end if;
  if authoritative_subject is not null and authoritative_subject <> prefix_subject then
    raise exception 'Storage owner scope mismatch' using errcode = '42501';
  end if;

  -- Service-role operations are the trusted cleanup/restore boundary. They
  -- still must use an owner-scoped safe path, but may update the frozen object
  -- after the user-facing account has entered deletion.
  if trusted_storage_role then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  perform private.lock_account_lifecycle_v3(prefix_subject);
  if not private.can_write_account_storage_as(prefix_subject) then
    raise exception 'account Storage writes are unavailable' using errcode = '42501';
  end if;
  if actor is null or actor <> prefix_subject
     or authoritative_subject is distinct from actor then
    raise exception 'Storage owner scope mismatch' using errcode = '42501';
  end if;
  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function private.guard_account_storage_write_v3()
  from public, anon, authenticated;
drop trigger if exists guard_account_storage_write_v3 on storage.objects;
create trigger guard_account_storage_write_v3
before insert or update or delete on storage.objects
for each row execute function private.guard_account_storage_write_v3();

-- Existing visit-photo policies keep their media and audience rules while
-- adding the same live/non-deleting owner predicate used by the trigger.
drop policy if exists "Authenticated users can upload visit photos" on storage.objects;
create policy "Authenticated users can upload visit photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'visit-photos'
    and private.can_write_account_storage_as((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
  );
drop policy if exists "Users can update their own visit photos" on storage.objects;
create policy "Users can update their own visit photos"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'visit-photos'
    and private.can_write_account_storage_as((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  )
  with check (
    bucket_id = 'visit-photos'
    and private.can_write_account_storage_as((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
  );
drop policy if exists "Users can delete their own visit photos" on storage.objects;
create policy "Users can delete their own visit photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'visit-photos'
    and private.can_write_account_storage_as((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  );
drop policy if exists "Owners can read their visit photo objects" on storage.objects;
create policy "Owners can read their visit photo objects"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'visit-photos'
    and private.is_live_account_as((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  );
drop policy if exists "View photos based on completed visit visibility" on storage.objects;
create policy "View photos based on completed visit visibility"
  on storage.objects for select to public
  using (
    bucket_id = 'visit-photos'
    and (
      (
        private.is_live_account_as((select auth.uid()))
        and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
      )
      or public.can_view_visit_photo_object(name)
    )
  );

drop policy if exists "Owners upload private visit photos" on storage.objects;
create policy "Owners upload private visit photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'visit-photos-private'
    and private.can_write_account_storage_as((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
    and exists (
      select 1 from public.visits visit
      where lower(visit.id::text) = lower((storage.foldername(name))[2])
        and visit.user_id = (select auth.uid())
    )
  );
drop policy if exists "Owners update private visit photos" on storage.objects;
create policy "Owners update private visit photos"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'visit-photos-private'
    and private.can_write_account_storage_as((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  )
  with check (
    bucket_id = 'visit-photos-private'
    and private.can_write_account_storage_as((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
    and exists (
      select 1 from public.visits visit
      where lower(visit.id::text) = lower((storage.foldername(name))[2])
        and visit.user_id = (select auth.uid())
    )
  );
drop policy if exists "Owners delete private visit photos" on storage.objects;
create policy "Owners delete private visit photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'visit-photos-private'
    and private.can_write_account_storage_as((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  );
drop policy if exists "Visit audiences read private visit photos" on storage.objects;
create policy "Visit audiences read private visit photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'visit-photos-private'
    and (
      (
        private.is_live_account_as((select auth.uid()))
        and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
      )
      or public.can_view_visit_photo_object(name)
    )
  );

-- ---------------------------------------------------------------------------
-- Recent-session preparation and capability-bound recovery
-- ---------------------------------------------------------------------------

-- Defined before preparation because PL/pgSQL body validation resolves this
-- service-role projection while creating the preparation function.
create or replace function public.read_account_deletion_job_v3(p_job_id uuid)
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
      'storage_manifest_object_count', job.storage_manifest_object_count,
      'storage_manifest_frozen_at', job.storage_manifest_frozen_at,
      'storage_preflight_verified_at', job.storage_preflight_verified_at,
      'identity_exists', job.subject_id is not null and exists(
        select 1 from auth.users account where account.id = job.subject_id
      ),
      'database_identity_exists', job.subject_id is not null and exists(
        select 1 from public.users profile where profile.id = job.subject_id
      ),
      'storage_ownership_detached_at', job.storage_ownership_detached_at,
      'identity_deleted_at', job.identity_deleted_at,
      'collaboration_finalized_at', job.collaboration_finalized_at,
      'cleanup_completed_at', job.cleanup_completed_at,
      'identity_attempts', job.identity_attempts,
      'cleanup_attempts', job.cleanup_attempts,
      'redacted_at', job.redacted_at,
      'receipt_expires_at', job.receipt_expires_at,
      'completion_receipt_fresh_until', job.completion_receipt_fresh_until,
      'completion_proof_state', job.completion_proof_state
    )
    from private.account_deletion_jobs job
    where job.id = p_job_id and job.protocol_version = 3
  ), '{}'::jsonb);
$$;

create or replace function public.begin_account_deletion_step_up_v3(
  p_subject_id uuid,
  p_session_id uuid,
  p_request_id uuid,
  p_recovery_hash text,
  p_subject_proof_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  challenge private.account_deletion_step_up_challenges%rowtype;
begin
  if p_subject_id is null or p_session_id is null or p_request_id is null
     or p_recovery_hash !~ '^[0-9a-f]{64}$'
     or p_subject_proof_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid step_up challenge request' using errcode = '22023';
  end if;

  perform private.lock_account_lifecycle_v3(p_subject_id);
  if not exists (
    select 1 from auth.users account
    where account.id = p_subject_id and account.deleted_at is null
  ) or not exists (
    select 1 from auth.sessions session
    where session.id = p_session_id and session.user_id = p_subject_id
  ) then
    raise exception 'step_up_session_unavailable' using errcode = '42501';
  end if;

  -- A newly issued challenge supersedes any unconsumed challenge for the same
  -- durable request. It still cannot authorize deletion until a different,
  -- freshly authenticated session proves an eligible AMR event.
  update private.account_deletion_step_up_challenges existing
  set superseded_at = now(), updated_at = now()
  where existing.subject_id = p_subject_id
    and existing.request_id = p_request_id
    and existing.consumed_at is null
    and existing.superseded_at is null
    and existing.expires_at > now();

  insert into private.account_deletion_step_up_challenges(
    request_id, subject_id, initiating_session_id,
    recovery_secret_hash, subject_proof_hash,
    issued_at, expires_at
  ) values (
    p_request_id, p_subject_id, p_session_id,
    pg_catalog.decode(p_recovery_hash, 'hex'),
    pg_catalog.decode(p_subject_proof_hash, 'hex'),
    now(), now() + interval '5 minutes'
  ) returning * into challenge;

  return jsonb_build_object(
    'challenge_id', challenge.id,
    'expires_at', challenge.expires_at
  );
end;
$$;

create or replace function public.authorize_account_deletion_step_up_v3(
  p_challenge_id uuid,
  p_subject_id uuid,
  p_request_id uuid,
  p_recovery_hash text,
  p_session_id uuid,
  p_amr_method text,
  p_amr_authenticated_at bigint,
  p_authorization_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  challenge private.account_deletion_step_up_challenges%rowtype;
  authenticated_at timestamptz;
begin
  if p_challenge_id is null or p_subject_id is null or p_request_id is null
     or p_session_id is null
     or p_recovery_hash !~ '^[0-9a-f]{64}$'
     or p_authorization_hash !~ '^[0-9a-f]{64}$'
     or p_amr_method not in ('password', 'oauth', 'otp', 'totp', 'magiclink', 'sso/saml')
     or p_amr_authenticated_at is null or p_amr_authenticated_at <= 0 then
    raise exception 'invalid step_up authorization request' using errcode = '22023';
  end if;

  authenticated_at := pg_catalog.to_timestamp(
    p_amr_authenticated_at::double precision
  );
  perform private.lock_account_lifecycle_v3(p_subject_id);
  select row.* into challenge
  from private.account_deletion_step_up_challenges row
  where row.id = p_challenge_id
  for update;
  if not found then
    raise exception 'step_up_challenge_unavailable' using errcode = 'P0002';
  end if;
  if challenge.subject_id <> p_subject_id
     or challenge.request_id <> p_request_id
     or challenge.recovery_secret_hash <> pg_catalog.decode(p_recovery_hash, 'hex') then
    raise exception 'step_up_challenge_scope_mismatch' using errcode = '42501';
  end if;
  if challenge.expires_at <= now() or challenge.superseded_at is not null
     or challenge.consumed_at is not null
     or challenge.authorized_at is not null then
    raise exception 'step_up_challenge_expired' using errcode = '42501';
  end if;

  -- A refresh of the initiating token is not step-up. Require a different live
  -- Auth session plus a server-issued AMR event at or after the challenge's
  -- second. The two-second session allowance handles timestamp precision only;
  -- the new-session and AMR conditions remain mandatory.
  if p_session_id = challenge.initiating_session_id
     or authenticated_at < date_trunc('second', challenge.issued_at)
     or authenticated_at > now() + interval '30 seconds'
     or not exists (
       select 1 from auth.sessions session
       where session.id = p_session_id
         and session.user_id = p_subject_id
         and session.created_at >= challenge.issued_at - interval '2 seconds'
     ) then
    raise exception 'step_up_reauthentication_required' using errcode = '42501';
  end if;

  update private.account_deletion_step_up_challenges row
  set authorized_session_id = p_session_id,
      authorized_amr_method = p_amr_method,
      authorized_amr_at = authenticated_at,
      authorization_secret_hash = pg_catalog.decode(p_authorization_hash, 'hex'),
      authorization_expires_at = least(
        challenge.expires_at, now() + interval '2 minutes'
      ),
      authorized_at = now(), updated_at = now()
  where row.id = challenge.id
  returning * into challenge;

  return jsonb_build_object(
    'authorized', true,
    'expires_at', challenge.authorization_expires_at
  );
end;
$$;

create or replace function public.prepare_account_deletion_v3(
  p_subject_id uuid,
  p_session_id uuid,
  p_request_id uuid,
  p_recovery_hash text,
  p_subject_proof_hash text,
  p_step_up_challenge_id uuid,
  p_step_up_authorization_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  existing_job private.account_deletion_jobs%rowtype;
  prepared jsonb;
  storage_rows jsonb := '[]'::jsonb;
  list_transfers jsonb := '[]'::jsonb;
  deleted_lists jsonb := '[]'::jsonb;
  memory_transfers jsonb := '[]'::jsonb;
  deleted_memories jsonb := '[]'::jsonb;
  owner_id_value text;
  owner_value text;
  object_row record;
  step_up private.account_deletion_step_up_challenges%rowtype;
begin
  if p_subject_id is null or p_session_id is null or p_request_id is null
     or p_recovery_hash !~ '^[0-9a-f]{64}$'
     or p_subject_proof_hash !~ '^[0-9a-f]{64}$'
     or p_step_up_challenge_id is null
     or p_step_up_authorization_hash !~ '^[0-9a-f]{64}$' then
    raise exception 'invalid account deletion authorization' using errcode = '22023';
  end if;

  perform private.lock_account_lifecycle_v3(p_subject_id);
  perform 1 from auth.users account
  where account.id = p_subject_id and account.deleted_at is null
  for update;
  if not found then
    raise exception 'account identity is unavailable' using errcode = 'P0002';
  end if;
  if not exists (
    select 1 from auth.sessions session
    where session.id = p_session_id
      and session.user_id = p_subject_id
      and session.created_at >= now() - interval '15 minutes'
  ) then
    raise exception 'recent_authentication_required' using errcode = '42501';
  end if;

  select row.* into step_up
  from private.account_deletion_step_up_challenges row
  where row.id = p_step_up_challenge_id
    and row.subject_id = p_subject_id
    and row.request_id = p_request_id
    and row.recovery_secret_hash = pg_catalog.decode(p_recovery_hash, 'hex')
    and row.subject_proof_hash = pg_catalog.decode(p_subject_proof_hash, 'hex')
    and row.authorized_session_id = p_session_id
    and row.authorization_secret_hash =
      pg_catalog.decode(p_step_up_authorization_hash, 'hex')
    and row.authorized_at is not null
    and row.superseded_at is null
    and row.authorization_expires_at > now()
    and row.consumed_at is null
  for update;
  if not found then
    raise exception 'step_up_authorization_required' using errcode = '42501';
  end if;
  update private.account_deletion_step_up_challenges
  set consumed_at = now(), updated_at = now()
  where id = step_up.id and consumed_at is null;

  select job.* into existing_job
  from private.account_deletion_jobs job
  where job.subject_id = p_subject_id and job.status <> 'completed'
  for update;
  if found then
    if existing_job.request_id <> p_request_id
       or existing_job.recovery_secret_hash <> pg_catalog.decode(p_recovery_hash, 'hex')
       or existing_job.subject_proof_hash <> pg_catalog.decode(p_subject_proof_hash, 'hex') then
      raise exception 'account deletion is already prepared' using errcode = '55000';
    end if;
    return public.read_account_deletion_job_v3(existing_job.id);
  end if;
  if exists (
    select 1 from private.account_deletion_jobs job
    where job.request_id = p_request_id
  ) then
    raise exception 'account deletion request is already bound'
      using errcode = '55000';
  end if;

  -- Freeze all plan inputs and Storage metadata. Deletion is rare and this
  -- deliberately favors correctness over concurrent collaboration throughput.
  lock table public.cafe_lists, public.cafe_list_members,
    public.shared_memories, public.shared_memory_members in share row exclusive mode;
  lock table storage.objects in share row exclusive mode;

  for object_row in
    select object.id, object.bucket_id, object.name,
      to_jsonb(object) ->> 'owner_id' as owner_id,
      to_jsonb(object) ->> 'owner' as owner
    from storage.objects object
    where private.account_storage_mentions_subject_v3(
      to_jsonb(object), p_subject_id
    )
    order by object.bucket_id, object.name, object.id
  loop
    owner_id_value := nullif(object_row.owner_id, '');
    owner_value := nullif(object_row.owner, '');
    if object_row.bucket_id not in ('visit-photos', 'visit-photos-private', 'profile-media')
       or not private.safe_account_storage_path_v3(p_subject_id, object_row.name)
       or not private.account_storage_owner_is_exact_v3(
         jsonb_build_object('owner_id', owner_id_value, 'owner', owner_value),
         p_subject_id
       ) then
      raise exception 'unsafe_account_storage_inventory' using errcode = '55000';
    end if;
    storage_rows := storage_rows || jsonb_build_array(jsonb_build_object(
      'object_id', object_row.id,
      'bucket', object_row.bucket_id,
      'path', object_row.name
    ));
  end loop;

  -- V2 recorded only the first accepted successor. V3 freezes the complete,
  -- deterministic eligible chain so a later restriction, suspension, or
  -- deletion by the first choice cannot destroy a collaboration that another
  -- accepted participant can safely steward.
  select coalesce(jsonb_agg(jsonb_build_object(
    'list_id', planned.id,
    'successor_id', planned.successor_ids[1],
    'successor_ids', to_jsonb(planned.successor_ids)
  ) order by planned.created_at, planned.id), '[]'::jsonb)
  into list_transfers
  from (
    select listing.id, listing.created_at,
      coalesce(successors.user_ids, '{}'::uuid[]) successor_ids
    from public.cafe_lists listing
    left join lateral (
      select array_agg(member.user_id order by
        case when member.role = 'editor' then 0 else 1 end,
        coalesce(member.accepted_at, member.created_at),
        member.created_at,
        member.user_id
      ) user_ids
      from public.cafe_list_members member
      where member.list_id = listing.id
        and member.user_id <> p_subject_id
        and member.invitation_status = 'accepted'
        and private.can_socially_mutate_as(member.user_id)
        and not private.account_deletion_active_as(member.user_id)
        and not private.blocked_between(p_subject_id, member.user_id)
    ) successors on true
    where listing.owner_id = p_subject_id
      and listing.system_kind is null
  ) planned
  where cardinality(planned.successor_ids) > 0;

  select coalesce(jsonb_agg(planned.id order by planned.created_at, planned.id), '[]'::jsonb)
  into deleted_lists
  from (
    select listing.id, listing.created_at, listing.system_kind,
      coalesce(successors.user_ids, '{}'::uuid[]) successor_ids
    from public.cafe_lists listing
    left join lateral (
      select array_agg(member.user_id order by
        case when member.role = 'editor' then 0 else 1 end,
        coalesce(member.accepted_at, member.created_at),
        member.created_at,
        member.user_id
      ) user_ids
      from public.cafe_list_members member
      where member.list_id = listing.id
        and member.user_id <> p_subject_id
        and member.invitation_status = 'accepted'
        and private.can_socially_mutate_as(member.user_id)
        and not private.account_deletion_active_as(member.user_id)
        and not private.blocked_between(p_subject_id, member.user_id)
    ) successors on true
    where listing.owner_id = p_subject_id
  ) planned
  where planned.system_kind is not null
     or cardinality(planned.successor_ids) = 0;

  select coalesce(jsonb_agg(jsonb_build_object(
    'shared_memory_id', planned.id,
    'successor_id', planned.successor_ids[1],
    'successor_ids', to_jsonb(planned.successor_ids)
  ) order by planned.created_at, planned.id), '[]'::jsonb)
  into memory_transfers
  from (
    select memory.id, memory.created_at,
      coalesce(successors.user_ids, '{}'::uuid[]) successor_ids
    from public.shared_memories memory
    left join lateral (
      select array_agg(member.user_id order by
        coalesce(member.responded_at, member.created_at),
        member.created_at,
        member.user_id
      ) user_ids
      from public.shared_memory_members member
      where member.shared_memory_id = memory.id
        and member.user_id <> p_subject_id
        and member.status = 'accepted'
        and private.can_socially_mutate_as(member.user_id)
        and not private.account_deletion_active_as(member.user_id)
        and not private.blocked_between(p_subject_id, member.user_id)
    ) successors on true
    where memory.managed_by = p_subject_id or memory.created_by = p_subject_id
  ) planned
  where cardinality(planned.successor_ids) > 0;

  select coalesce(jsonb_agg(planned.id order by planned.created_at, planned.id), '[]'::jsonb)
  into deleted_memories
  from (
    select memory.id, memory.created_at,
      coalesce(successors.user_ids, '{}'::uuid[]) successor_ids
    from public.shared_memories memory
    left join lateral (
      select array_agg(member.user_id order by
        coalesce(member.responded_at, member.created_at),
        member.created_at,
        member.user_id
      ) user_ids
      from public.shared_memory_members member
      where member.shared_memory_id = memory.id
        and member.user_id <> p_subject_id
        and member.status = 'accepted'
        and private.can_socially_mutate_as(member.user_id)
        and not private.account_deletion_active_as(member.user_id)
        and not private.blocked_between(p_subject_id, member.user_id)
    ) successors on true
    where memory.managed_by = p_subject_id or memory.created_by = p_subject_id
  ) planned
  where cardinality(planned.successor_ids) = 0;

  prepared := public.prepare_account_deletion_v2(p_subject_id, p_request_id);
  update private.account_deletion_jobs job
  set protocol_version = 3,
      storage_manifest = storage_rows,
      collaboration_manifest = jsonb_build_object(
        'transferred_cafe_lists', list_transfers,
        'deleted_owner_only_cafe_lists', deleted_lists,
        'transferred_shared_memories', memory_transfers,
        'deleted_owner_only_shared_memories', deleted_memories
      ),
      authorized_session_id = p_session_id,
      authorized_at = now(),
      step_up_challenge_id = step_up.id,
      recovery_secret_hash = pg_catalog.decode(p_recovery_hash, 'hex'),
      subject_proof_hash = pg_catalog.decode(p_subject_proof_hash, 'hex'),
      storage_manifest_frozen_at = now(),
      storage_manifest_object_count = jsonb_array_length(storage_rows),
      storage_preflight_verified_at = null,
      next_attempt_at = now(),
      updated_at = now()
  where job.id = (prepared ->> 'job_id')::uuid
  returning * into existing_job;

  return public.read_account_deletion_job_v3(existing_job.id);
end;
$$;

create or replace function public.read_account_deletion_job_v3(p_job_id uuid)
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
      'storage_manifest_object_count', job.storage_manifest_object_count,
      'storage_manifest_frozen_at', job.storage_manifest_frozen_at,
      'storage_preflight_verified_at', job.storage_preflight_verified_at,
      'identity_exists', job.subject_id is not null and exists(
        select 1 from auth.users account where account.id = job.subject_id
      ),
      'database_identity_exists', job.subject_id is not null and exists(
        select 1 from public.users profile where profile.id = job.subject_id
      ),
      'storage_ownership_detached_at', job.storage_ownership_detached_at,
      'identity_deleted_at', job.identity_deleted_at,
      'collaboration_finalized_at', job.collaboration_finalized_at,
      'cleanup_completed_at', job.cleanup_completed_at,
      'identity_attempts', job.identity_attempts,
      'cleanup_attempts', job.cleanup_attempts,
      'redacted_at', job.redacted_at,
      'receipt_expires_at', job.receipt_expires_at,
      'completion_receipt_fresh_until', job.completion_receipt_fresh_until,
      'completion_proof_state', job.completion_proof_state
    )
    from private.account_deletion_jobs job
    where job.id = p_job_id and job.protocol_version = 3
  ), '{}'::jsonb);
$$;

create or replace function public.read_account_deletion_job_by_recovery_v3(
  p_request_id uuid,
  p_recovery_hash text,
  p_subject_proof_hash text
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select public.read_account_deletion_job_v3(job.id)
    from private.account_deletion_jobs job
    where job.request_id = p_request_id
      and job.protocol_version = 3
      and p_recovery_hash ~ '^[0-9a-f]{64}$'
      and p_subject_proof_hash ~ '^[0-9a-f]{64}$'
      and job.recovery_secret_hash = pg_catalog.decode(p_recovery_hash, 'hex')
      and job.subject_proof_hash = pg_catalog.decode(p_subject_proof_hash, 'hex')
  ), '{}'::jsonb);
$$;

create or replace function private.assert_account_deletion_lease_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_job_id is null or p_lease_token is null then
    raise exception 'account deletion lease required' using errcode = '22023';
  end if;
  perform 1
  from private.account_deletion_jobs job
  where job.id = p_job_id
    and job.protocol_version = 3
    and job.status <> 'completed'
    and job.lease_token = p_lease_token
    and job.lease_expires_at > clock_timestamp()
  for update;
  if not found then
    raise exception 'stale_account_deletion_lease' using errcode = '55000';
  end if;
end;
$$;

create or replace function public.claim_account_deletion_job_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  with claimed as (
    update private.account_deletion_jobs job
    set lease_token = p_lease_token,
        lease_expires_at = clock_timestamp() + interval '2 minutes',
        updated_at = now()
    where job.id = p_job_id
      and p_lease_token is not null
      and job.protocol_version = 3
      and job.status <> 'completed'
      and (
        job.lease_token is null
        or job.lease_expires_at is null
        or job.lease_expires_at <= clock_timestamp()
        or job.lease_token = p_lease_token
      )
    returning 1
  )
  select exists(select 1 from claimed);
$$;

create or replace function public.renew_account_deletion_job_lease_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  with renewed as (
    update private.account_deletion_jobs job
    set lease_expires_at = clock_timestamp() + interval '2 minutes',
        updated_at = now()
    where job.id = p_job_id
      and p_lease_token is not null
      and job.protocol_version = 3
      and job.status <> 'completed'
      and job.lease_token = p_lease_token
      and job.lease_expires_at > clock_timestamp()
    returning 1
  )
  select exists(select 1 from renewed);
$$;

create or replace function public.seal_account_deletion_storage_preflight_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target private.account_deletion_jobs%rowtype;
begin
  perform private.assert_account_deletion_lease_v3(p_job_id, p_lease_token);
  select job.* into target
  from private.account_deletion_jobs job
  where job.id = p_job_id and job.protocol_version = 3
  for update;
  if not found or target.subject_id is null
     or target.identity_deleted_at is not null
     or target.storage_manifest_frozen_at is null
     or target.storage_manifest_object_count < 0
     or target.storage_manifest_object_count <>
       jsonb_array_length(target.storage_manifest) then
    return false;
  end if;

  lock table storage.objects in share row exclusive mode;

  -- Every authoritative owner reference must be exact, supported, path-safe,
  -- and represented by the immutable object-id/bucket/path tuple.
  if exists (
    select 1
    from storage.objects object
    where private.account_storage_mentions_subject_v3(
      to_jsonb(object), target.subject_id
    )
      and (
        not private.account_storage_owner_is_exact_v3(
          to_jsonb(object), target.subject_id
        )
        or object.bucket_id not in (
          'visit-photos', 'visit-photos-private', 'profile-media'
        )
        or not private.safe_account_storage_path_v3(
          target.subject_id, object.name
        )
        or not exists (
          select 1
          from jsonb_array_elements(target.storage_manifest) item
          where (item ->> 'object_id')::uuid = object.id
            and item ->> 'bucket' = object.bucket_id
            and item ->> 'path' = object.name
        )
      )
  ) or exists (
    select 1
    from jsonb_array_elements(target.storage_manifest) item
    left join storage.objects object
      on object.id = (item ->> 'object_id')::uuid
      and object.bucket_id = item ->> 'bucket'
      and object.name = item ->> 'path'
    where object.id is null
       or item ->> 'bucket' not in (
         'visit-photos', 'visit-photos-private', 'profile-media'
       )
       or not private.safe_account_storage_path_v3(
         target.subject_id, item ->> 'path'
       )
       or not private.account_storage_owner_is_exact_v3(
         to_jsonb(object), target.subject_id
       )
  ) then
    return false;
  end if;

  update private.account_deletion_jobs
  set storage_preflight_verified_at = now(), updated_at = now()
  where id = target.id
    and lease_token = p_lease_token
    and lease_expires_at > clock_timestamp();
  if not found then return false; end if;
  return true;
end;
$$;

create or replace function public.revoke_account_sessions_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  subject uuid;
begin
  perform private.assert_account_deletion_lease_v3(p_job_id, p_lease_token);
  select job.subject_id into subject
  from private.account_deletion_jobs job
  where job.id = p_job_id and job.protocol_version = 3
  for update;
  if not found then raise exception 'deletion job not found' using errcode = 'P0002'; end if;
  if subject is not null then
    delete from auth.sessions session where session.user_id = subject;
  end if;
end;
$$;

create or replace function public.confirm_account_identity_deleted_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare subject uuid;
begin
  perform private.assert_account_deletion_lease_v3(p_job_id, p_lease_token);
  select job.subject_id into subject
  from private.account_deletion_jobs job
  where job.id = p_job_id and job.protocol_version = 3
  for update;
  if not found or subject is null then
    raise exception 'deletion job not found' using errcode = 'P0002';
  end if;
  if exists(select 1 from auth.users where id = subject) then
    return false;
  end if;
  delete from public.users where id = subject;
  return not exists(select 1 from public.users where id = subject);
end;
$$;

create or replace function public.mark_account_deletion_identity_deleted_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare subject uuid;
begin
  perform private.assert_account_deletion_lease_v3(p_job_id, p_lease_token);
  select job.subject_id into subject
  from private.account_deletion_jobs job
  where job.id = p_job_id and job.protocol_version = 3
  for update;
  if not found or subject is null then
    raise exception 'deletion job not found' using errcode = 'P0002';
  end if;
  if exists(select 1 from auth.users where id = subject)
     or exists(select 1 from public.users where id = subject) then
    raise exception 'identity deletion is not confirmed' using errcode = '55000';
  end if;
  update private.account_deletion_jobs job
  set status = 'collaboration_pending',
      identity_attempts = identity_attempts + 1,
      identity_deleted_at = coalesce(identity_deleted_at, now()),
      last_error_code = null,
      next_attempt_at = now(),
      updated_at = now()
  where job.id = p_job_id
    and job.lease_token = p_lease_token
    and job.lease_expires_at > clock_timestamp();
  if not found then
    raise exception 'stale_account_deletion_lease' using errcode = '55000';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Exact detach/restore, immutable collaboration finalization, and redaction
-- ---------------------------------------------------------------------------

create or replace function public.detach_account_storage_ownership_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target private.account_deletion_jobs%rowtype;
  item jsonb;
  matched integer;
begin
  perform private.assert_account_deletion_lease_v3(p_job_id, p_lease_token);
  select job.* into target from private.account_deletion_jobs job
  where job.id = p_job_id and job.protocol_version = 3 for update;
  if not found then raise exception 'deletion job not found' using errcode = 'P0002'; end if;
  if target.subject_id is null or target.identity_deleted_at is not null
     or not exists(select 1 from auth.users where id = target.subject_id) then
    raise exception 'identity is unavailable for reversible detach' using errcode = '55000';
  end if;
  if target.storage_ownership_detached_at is not null then return; end if;

  perform set_config(
    'mugshot.account_deletion_storage_maintenance_job',
    p_job_id::text,
    true
  );
  lock table storage.objects in share row exclusive mode;
  for item in select value from jsonb_array_elements(target.storage_manifest)
  loop
    if item ->> 'bucket' not in ('visit-photos', 'visit-photos-private', 'profile-media')
       or not private.safe_account_storage_path_v3(target.subject_id, item ->> 'path') then
      raise exception 'unsafe Storage detach manifest' using errcode = '22023';
    end if;
    select count(*) into matched
    from storage.objects object
    where object.id = (item ->> 'object_id')::uuid
      and object.bucket_id = item ->> 'bucket'
      and object.name = item ->> 'path'
      and coalesce(to_jsonb(object) ->> 'owner_id', target.subject_id::text) = target.subject_id::text
      and coalesce(to_jsonb(object) ->> 'owner', target.subject_id::text) = target.subject_id::text
      and coalesce(to_jsonb(object) ->> 'owner_id', to_jsonb(object) ->> 'owner') is not null;
    if matched <> 1 then
      raise exception 'Storage ownership changed after preparation' using errcode = '55000';
    end if;

    if exists (
      select 1 from information_schema.columns column_row
      where column_row.table_schema = 'storage' and column_row.table_name = 'objects'
        and column_row.column_name = 'owner_id' and column_row.is_nullable = 'YES'
    ) then
      execute 'update storage.objects set owner_id = null where id = $1 and bucket_id = $2 and name = $3'
      using (item ->> 'object_id')::uuid, item ->> 'bucket', item ->> 'path';
    end if;
    if exists (
      select 1 from information_schema.columns column_row
      where column_row.table_schema = 'storage' and column_row.table_name = 'objects'
        and column_row.column_name = 'owner' and column_row.is_nullable = 'YES'
    ) then
      execute 'update storage.objects set owner = null where id = $1 and bucket_id = $2 and name = $3'
      using (item ->> 'object_id')::uuid, item ->> 'bucket', item ->> 'path';
    end if;
  end loop;
  update private.account_deletion_jobs
  set storage_ownership_detached_at = now(), updated_at = now()
  where id = p_job_id
    and lease_token = p_lease_token
    and lease_expires_at > clock_timestamp();
  if not found then
    raise exception 'stale_account_deletion_lease' using errcode = '55000';
  end if;
end;
$$;

create or replace function public.restore_account_storage_ownership_v3(
  p_job_id uuid,
  p_lease_token uuid
)
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
  perform private.assert_account_deletion_lease_v3(p_job_id, p_lease_token);
  select job.* into target from private.account_deletion_jobs job
  where job.id = p_job_id and job.protocol_version = 3 for update;
  if not found then raise exception 'deletion job not found' using errcode = 'P0002'; end if;
  if target.storage_ownership_detached_at is null then return; end if;
  if target.subject_id is null
     or not exists(select 1 from auth.users where id = target.subject_id) then
    raise exception 'cannot restore ownership after identity deletion' using errcode = '55000';
  end if;
  select column_row.udt_name into owner_id_type
  from information_schema.columns column_row
  where column_row.table_schema = 'storage' and column_row.table_name = 'objects'
    and column_row.column_name = 'owner_id';
  select column_row.udt_name into owner_type
  from information_schema.columns column_row
  where column_row.table_schema = 'storage' and column_row.table_name = 'objects'
    and column_row.column_name = 'owner';
  perform set_config(
    'mugshot.account_deletion_storage_maintenance_job',
    p_job_id::text,
    true
  );
  lock table storage.objects in share row exclusive mode;
  for item in select value from jsonb_array_elements(target.storage_manifest)
  loop
    if not private.safe_account_storage_path_v3(target.subject_id, item ->> 'path') then
      raise exception 'unsafe Storage restore manifest' using errcode = '22023';
    end if;
    if owner_id_type = 'uuid' then
      execute 'update storage.objects set owner_id = $1 where id = $2 and bucket_id = $3 and name = $4'
      using target.subject_id, (item ->> 'object_id')::uuid,
        item ->> 'bucket', item ->> 'path';
    elsif owner_id_type is not null then
      execute 'update storage.objects set owner_id = $1 where id = $2 and bucket_id = $3 and name = $4'
      using target.subject_id::text, (item ->> 'object_id')::uuid,
        item ->> 'bucket', item ->> 'path';
    end if;
    if owner_type = 'uuid' then
      execute 'update storage.objects set owner = $1 where id = $2 and bucket_id = $3 and name = $4'
      using target.subject_id, (item ->> 'object_id')::uuid,
        item ->> 'bucket', item ->> 'path';
    elsif owner_type is not null then
      execute 'update storage.objects set owner = $1 where id = $2 and bucket_id = $3 and name = $4'
      using target.subject_id::text, (item ->> 'object_id')::uuid,
        item ->> 'bucket', item ->> 'path';
    end if;
  end loop;
  update private.account_deletion_jobs
  set storage_ownership_detached_at = null, updated_at = now()
  where id = p_job_id
    and lease_token = p_lease_token
    and lease_expires_at > clock_timestamp();
  if not found then
    raise exception 'stale_account_deletion_lease' using errcode = '55000';
  end if;
end;
$$;

create or replace function public.finalize_account_collaboration_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  target private.account_deletion_jobs%rowtype;
  item jsonb;
  planned_id uuid;
  successor uuid;
  candidate uuid;
  successor_candidates jsonb;
  current_owner uuid;
  changed integer;
begin
  perform private.assert_account_deletion_lease_v3(p_job_id, p_lease_token);
  select job.* into target from private.account_deletion_jobs job
  where job.id = p_job_id and job.protocol_version = 3 for update;
  if not found then raise exception 'deletion job not found' using errcode = 'P0002'; end if;
  if target.identity_deleted_at is null or target.subject_id is null
     or exists(select 1 from auth.users where id = target.subject_id)
     or exists(select 1 from public.users where id = target.subject_id) then
    raise exception 'identity deletion must be confirmed first' using errcode = '55000';
  end if;
  if target.collaboration_finalized_at is not null then return; end if;
  perform private.lock_account_lifecycle_v3(target.subject_id);

  for item in select value from jsonb_array_elements(coalesce(
    target.collaboration_manifest -> 'transferred_cafe_lists', '[]'::jsonb
  ))
  loop
    planned_id := (item ->> 'list_id')::uuid;
    successor := null;
    successor_candidates := coalesce(
      item -> 'successor_ids',
      jsonb_build_array(item ->> 'successor_id')
    );
    for candidate in
      select value::uuid
      from jsonb_array_elements_text(successor_candidates)
    loop
      if private.can_socially_mutate_as(candidate)
         and not private.account_deletion_active_as(candidate)
         and exists (
           select 1 from public.cafe_list_members member
           where member.list_id = planned_id and member.user_id = candidate
             and member.invitation_status = 'accepted'
         ) then
        successor := candidate;
        exit;
      end if;
    end loop;
    select list.owner_id into current_owner from public.cafe_lists list
    where list.id = planned_id for update;
    if not found then continue; end if;
    if successor is null then
      if current_owner is not null then
        raise exception 'immutable cafe list plan conflict' using errcode = '55000';
      end if;
      delete from public.cafe_lists where id = planned_id and owner_id is null;
      continue;
    end if;
    if current_owner is not null and current_owner <> successor then
      raise exception 'immutable cafe list plan conflict' using errcode = '55000';
    end if;
    if current_owner is null then
      update public.cafe_lists set owner_id = successor, updated_at = now()
      where id = planned_id and owner_id is null;
      get diagnostics changed = row_count;
      if changed <> 1 then
        raise exception 'cafe list transfer was not committed' using errcode = '55000';
      end if;
    end if;
    -- Membership is removed only after ownership is durably assigned.
    delete from public.cafe_list_members
    where list_id = planned_id and user_id = successor;
    update public.cafe_list_members
    set invitation_status = 'cancelled', responded_at = now(), updated_at = now(), expires_at = null
    where list_id = planned_id and invitation_status = 'pending';
  end loop;

  for planned_id in select value::uuid from jsonb_array_elements_text(coalesce(
    target.collaboration_manifest -> 'deleted_owner_only_cafe_lists', '[]'::jsonb
  ))
  loop
    select list.owner_id into current_owner from public.cafe_lists list
    where list.id = planned_id for update;
    if not found then continue; end if;
    if current_owner is not null then
      raise exception 'immutable cafe list deletion plan conflict' using errcode = '55000';
    end if;
    delete from public.cafe_lists where id = planned_id and owner_id is null;
  end loop;

  for item in select value from jsonb_array_elements(coalesce(
    target.collaboration_manifest -> 'transferred_shared_memories', '[]'::jsonb
  ))
  loop
    planned_id := (item ->> 'shared_memory_id')::uuid;
    successor := null;
    successor_candidates := coalesce(
      item -> 'successor_ids',
      jsonb_build_array(item ->> 'successor_id')
    );
    for candidate in
      select value::uuid
      from jsonb_array_elements_text(successor_candidates)
    loop
      if private.can_socially_mutate_as(candidate)
         and not private.account_deletion_active_as(candidate)
         and exists (
           select 1 from public.shared_memory_members member
           where member.shared_memory_id = planned_id and member.user_id = candidate
             and member.status = 'accepted'
         ) then
        successor := candidate;
        exit;
      end if;
    end loop;
    select memory.managed_by into current_owner from public.shared_memories memory
    where memory.id = planned_id for update;
    if not found then continue; end if;
    if successor is null then
      if current_owner is not null then
        raise exception 'immutable shared MugShot plan conflict' using errcode = '55000';
      end if;
      delete from public.shared_memories
      where id = planned_id and managed_by is null;
      continue;
    end if;
    if current_owner is not null and current_owner <> successor then
      raise exception 'immutable shared MugShot plan conflict' using errcode = '55000';
    end if;
    if current_owner is null then
      update public.shared_memories set managed_by = successor, updated_at = now()
      where id = planned_id and managed_by is null;
      get diagnostics changed = row_count;
      if changed <> 1 then
        raise exception 'shared MugShot transfer was not committed' using errcode = '55000';
      end if;
    end if;
    update public.shared_memory_members
    set status = 'cancelled', responded_at = now(), expires_at = null
    where shared_memory_id = planned_id and status = 'pending';
  end loop;

  for planned_id in select value::uuid from jsonb_array_elements_text(coalesce(
    target.collaboration_manifest -> 'deleted_owner_only_shared_memories', '[]'::jsonb
  ))
  loop
    select memory.managed_by into current_owner from public.shared_memories memory
    where memory.id = planned_id for update;
    if not found then continue; end if;
    if current_owner is not null then
      raise exception 'immutable shared MugShot deletion plan conflict' using errcode = '55000';
    end if;
    delete from public.shared_memories
    where id = planned_id and managed_by is null;
  end loop;

  update private.account_deletion_jobs
  set collaboration_finalized_at = now(), status = 'cleanup_pending',
      last_error_code = null, next_attempt_at = now(), updated_at = now()
  where id = p_job_id
    and lease_token = p_lease_token
    and lease_expires_at > clock_timestamp();
  if not found then
    raise exception 'stale_account_deletion_lease' using errcode = '55000';
  end if;
end;
$$;

create or replace function public.verify_account_storage_cleanup_v3(p_job_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare target private.account_deletion_jobs%rowtype;
begin
  select job.* into target from private.account_deletion_jobs job
  where job.id = p_job_id and job.protocol_version = 3;
  if not found or target.subject_id is null then return false; end if;
  if exists (
    select 1 from storage.objects object
    where private.account_storage_mentions_subject_v3(
      to_jsonb(object), target.subject_id
    ) and (
      not private.account_storage_owner_is_exact_v3(
        to_jsonb(object), target.subject_id
      )
      or not exists (
        select 1 from jsonb_array_elements(target.storage_manifest) item
        where (item ->> 'object_id')::uuid = object.id
          and item ->> 'bucket' = object.bucket_id
          and item ->> 'path' = object.name
      )
    )
  ) or exists (
    select 1 from jsonb_array_elements(target.storage_manifest) item
    join storage.objects object
      on object.id = (item ->> 'object_id')::uuid
      and object.bucket_id = item ->> 'bucket'
      and object.name = item ->> 'path'
    where not private.account_storage_owner_is_exact_v3(
      to_jsonb(object), target.subject_id
    ) and not (
      target.storage_ownership_detached_at is not null
      and nullif(to_jsonb(object) ->> 'owner_id', '') is null
      and nullif(to_jsonb(object) ->> 'owner', '') is null
    )
  ) or exists (
    select 1 from jsonb_array_elements(target.storage_manifest) item
    join storage.objects object
      on object.bucket_id = item ->> 'bucket'
      and object.name = item ->> 'path'
    where object.id <> (item ->> 'object_id')::uuid
  ) then
    return false;
  end if;
  return true;
end;
$$;

create or replace function public.mark_account_deletion_cleanup_completed_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare target private.account_deletion_jobs%rowtype;
begin
  perform private.assert_account_deletion_lease_v3(p_job_id, p_lease_token);
  select job.* into target from private.account_deletion_jobs job
  where job.id = p_job_id and job.protocol_version = 3 for update;
  if not found then raise exception 'deletion job not found' using errcode = 'P0002'; end if;
  if target.identity_deleted_at is null or target.collaboration_finalized_at is null
     or target.subject_id is null then
    raise exception 'identity and collaboration deletion must precede cleanup'
      using errcode = '55000';
  end if;
  if not public.verify_account_storage_cleanup_v3(p_job_id) then
    raise exception 'Storage inventory changed after preparation' using errcode = '55000';
  end if;
  if exists (
    select 1 from jsonb_array_elements(target.storage_manifest) item
    join storage.objects object on object.id = (item ->> 'object_id')::uuid
      and object.bucket_id = item ->> 'bucket' and object.name = item ->> 'path'
  ) then
    raise exception 'Storage cleanup is incomplete' using errcode = '55000';
  end if;

  -- Retain only a non-reversible proof and support reference. Paths,
  -- collaboration identifiers, and the raw subject UUID are not retained.
  update private.account_deletion_jobs
  set status = 'completed', cleanup_attempts = cleanup_attempts + 1,
      cleanup_completed_at = coalesce(cleanup_completed_at, now()),
      storage_manifest = '[]'::jsonb, collaboration_manifest = '{}'::jsonb,
      storage_manifest_object_count = 0,
      storage_manifest_frozen_at = null,
      storage_preflight_verified_at = null,
      storage_ownership_detached_at = null,
      authorized_session_id = null, authorized_at = null,
      step_up_challenge_id = null, subject_id = null,
      lease_token = null, lease_expires_at = null,
      last_error_code = null, redacted_at = now(),
      completion_proof_state = 'completed',
      completion_receipt_fresh_until = now() + interval '400 days',
      -- NULL means the recovery capability has no expiry. Do not purge its
      -- minimal proof while a matching Keychain capability remains valid.
      receipt_expires_at = null, updated_at = now()
  where id = p_job_id
    and lease_token = p_lease_token
    and lease_expires_at > clock_timestamp();
  if not found then
    raise exception 'stale_account_deletion_lease' using errcode = '55000';
  end if;
end;
$$;

create or replace function public.mark_account_deletion_pending_v3(
  p_job_id uuid,
  p_status text,
  p_error_code text,
  p_lease_token uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_status not in ('identity_deletion_pending', 'collaboration_pending', 'cleanup_pending') then
    raise exception 'invalid pending deletion state' using errcode = '22023';
  end if;
  update private.account_deletion_jobs
  set status = p_status,
      identity_attempts = identity_attempts + case when p_status = 'identity_deletion_pending' then 1 else 0 end,
      cleanup_attempts = cleanup_attempts + case when p_status = 'cleanup_pending' then 1 else 0 end,
      last_error_code = left(coalesce(p_error_code, p_status), 80),
      next_attempt_at = now() + least(
        interval '6 hours', interval '30 seconds' *
          power(2, least(8, identity_attempts + cleanup_attempts))::double precision
      ),
      lease_token = null, lease_expires_at = null, updated_at = now()
  where id = p_job_id and protocol_version = 3 and status <> 'completed'
    and lease_token = p_lease_token
    and lease_expires_at > clock_timestamp();
  return found;
end;
$$;

create or replace function public.claim_account_deletion_jobs_v3(
  p_lease_token uuid,
  p_limit integer default 10
)
returns table(job_id uuid)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_lease_token is null then raise exception 'lease token required' using errcode = '22023'; end if;
  return query
  with due as (
    select job.id from private.account_deletion_jobs job
    where job.protocol_version = 3 and job.status <> 'completed'
      and job.next_attempt_at <= now()
      and (job.lease_expires_at is null or job.lease_expires_at <= now())
    order by job.next_attempt_at, job.updated_at, job.id
    -- One job per claim prevents a batch from aging behind earlier work.
    limit 1
    for update skip locked
  )
  update private.account_deletion_jobs job
  set lease_token = p_lease_token,
      lease_expires_at = clock_timestamp() + interval '2 minutes',
      updated_at = now()
  from due where job.id = due.id
  returning job.id;
end;
$$;

create or replace function public.release_account_deletion_job_v3(
  p_job_id uuid,
  p_lease_token uuid
)
returns boolean
language sql
security definer
set search_path = ''
as $$
  with released as (
    update private.account_deletion_jobs
    set lease_token = null, lease_expires_at = null, updated_at = now()
    where id = p_job_id and lease_token = p_lease_token
    returning 1
  ) select exists(select 1 from released);
$$;

create or replace function public.purge_account_deletion_security_receipts_v3()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  purged_challenges integer := 0;
  expired_completion_proofs integer := 0;
  purged_receipts integer := 0;
begin
  -- Step-up evidence is operationally useful only for a short audit window.
  -- Raw authorization capabilities are never stored; their hashes are removed
  -- one day after expiry/consumption. A completed receipt remains a minimized,
  -- capability-bound proof for 400 days, then becomes an explicit
  -- expired-completed tombstone. The current recovery capability has no
  -- expiry, so this minimal proof is not hard-purged. A future capability
  -- expiry may set receipt_expires_at explicitly and only then permit purge.
  delete from private.account_deletion_step_up_challenges challenge
  where greatest(
    challenge.expires_at,
    coalesce(challenge.authorization_expires_at, challenge.expires_at),
    coalesce(challenge.consumed_at, challenge.expires_at)
  ) <= now() - interval '1 day';
  get diagnostics purged_challenges = row_count;

  update private.account_deletion_jobs job
  set completion_proof_state = 'expired_completed', updated_at = now()
  where job.status = 'completed'
    and job.completion_proof_state = 'completed'
    and job.completion_receipt_fresh_until is not null
    and job.completion_receipt_fresh_until <= now();
  get diagnostics expired_completion_proofs = row_count;

  -- No current writer sets receipt_expires_at: Keychain recovery capabilities
  -- remain valid until the client removes them after observing completion.
  -- Keep this guarded branch for a future explicitly expiring capability.
  delete from private.account_deletion_jobs job
  where job.status = 'completed'
    and job.receipt_expires_at is not null
    and job.receipt_expires_at <= now();
  get diagnostics purged_receipts = row_count;

  return jsonb_build_object(
    'purged_challenges', purged_challenges,
    'expired_completion_proofs', expired_completion_proofs,
    'purged_receipts', purged_receipts,
    'completed_receipt_fresh_days', 400,
    'completed_tombstone_retention', 'recovery_capability_lifetime',
    'recovery_capability_expires', false,
    'step_up_evidence_retention_days', 1
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Data API stale-session hook (activation is an explicit deployment gate)
-- ---------------------------------------------------------------------------

create or replace function public.enforce_mugshot_live_session_v3()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  session_id uuid;
begin
  if actor is null then return; end if;
  begin
    session_id := nullif(auth.jwt() ->> 'session_id', '')::uuid;
  exception when invalid_text_representation then
    session_id := null;
  end;
  if not private.is_live_account_as(actor)
     or private.account_deletion_active_as(actor)
     or session_id is null
     or not exists (
       select 1 from auth.sessions session
       where session.id = session_id and session.user_id = actor
     ) then
    raise sqlstate 'PGRST' using
      message = '{"code":"PGRST301","message":"Session is no longer active","details":null,"hint":null}',
      detail = '{"status":401,"headers":{"WWW-Authenticate":"Bearer"}}';
  end if;
end;
$$;

revoke all on function public.enforce_mugshot_live_session_v3() from public;
grant execute on function public.enforce_mugshot_live_session_v3() to anon, authenticated;

-- All privileged V3 lifecycle APIs are service-role only.
revoke all on function public.begin_account_deletion_step_up_v3(uuid, uuid, uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.authorize_account_deletion_step_up_v3(
  uuid, uuid, uuid, text, uuid, text, bigint, text
)
  from public, anon, authenticated;
revoke all on function public.prepare_account_deletion_v3(
  uuid, uuid, uuid, text, text, uuid, text
)
  from public, anon, authenticated;
revoke all on function public.read_account_deletion_job_v3(uuid)
  from public, anon, authenticated;
revoke all on function public.read_account_deletion_job_by_recovery_v3(uuid, text, text)
  from public, anon, authenticated;
revoke all on function private.assert_account_deletion_lease_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.claim_account_deletion_job_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.renew_account_deletion_job_lease_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.seal_account_deletion_storage_preflight_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.revoke_account_sessions_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.confirm_account_identity_deleted_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.mark_account_deletion_identity_deleted_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.detach_account_storage_ownership_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.restore_account_storage_ownership_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.finalize_account_collaboration_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.verify_account_storage_cleanup_v3(uuid)
  from public, anon, authenticated;
revoke all on function public.mark_account_deletion_cleanup_completed_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.mark_account_deletion_pending_v3(uuid, text, text, uuid)
  from public, anon, authenticated;
revoke all on function public.claim_account_deletion_jobs_v3(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.release_account_deletion_job_v3(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.purge_account_deletion_security_receipts_v3()
  from public, anon, authenticated;

grant execute on function public.begin_account_deletion_step_up_v3(uuid, uuid, uuid, text, text)
  to service_role;
grant execute on function public.authorize_account_deletion_step_up_v3(
  uuid, uuid, uuid, text, uuid, text, bigint, text
)
  to service_role;
grant execute on function public.prepare_account_deletion_v3(
  uuid, uuid, uuid, text, text, uuid, text
)
  to service_role;
grant execute on function public.read_account_deletion_job_v3(uuid) to service_role;
grant execute on function public.read_account_deletion_job_by_recovery_v3(uuid, text, text)
  to service_role;
grant execute on function public.claim_account_deletion_job_v3(uuid, uuid)
  to service_role;
grant execute on function public.renew_account_deletion_job_lease_v3(uuid, uuid)
  to service_role;
grant execute on function public.seal_account_deletion_storage_preflight_v3(uuid, uuid)
  to service_role;
grant execute on function public.revoke_account_sessions_v3(uuid, uuid) to service_role;
grant execute on function public.confirm_account_identity_deleted_v3(uuid, uuid)
  to service_role;
grant execute on function public.mark_account_deletion_identity_deleted_v3(uuid, uuid)
  to service_role;
grant execute on function public.detach_account_storage_ownership_v3(uuid, uuid)
  to service_role;
grant execute on function public.restore_account_storage_ownership_v3(uuid, uuid)
  to service_role;
grant execute on function public.finalize_account_collaboration_v3(uuid, uuid)
  to service_role;
grant execute on function public.verify_account_storage_cleanup_v3(uuid) to service_role;
grant execute on function public.mark_account_deletion_cleanup_completed_v3(uuid, uuid)
  to service_role;
grant execute on function public.mark_account_deletion_pending_v3(uuid, text, text, uuid)
  to service_role;
grant execute on function public.claim_account_deletion_jobs_v3(uuid, integer)
  to service_role;
grant execute on function public.release_account_deletion_job_v3(uuid, uuid)
  to service_role;
grant execute on function public.purge_account_deletion_security_receipts_v3()
  to service_role;

comment on function public.enforce_mugshot_live_session_v3() is
  'PostgREST pre-request hook for live Auth sessions. Deployment must compose it with any existing pgrst.db_pre_request hook before enabling the V3 Edge capability.';
comment on function public.prepare_account_deletion_v3(
  uuid, uuid, uuid, text, text, uuid, text
) is
  'Service-role-only account deletion preparation. Atomically consumes a fresh-AMR, new-session, subject/request/recovery-bound step-up authorization before freezing an owner-authoritative Storage manifest and immutable collaboration plan.';
comment on function public.purge_account_deletion_security_receipts_v3() is
  'Service worker retention boundary: step-up evidence is retained for at most one day after expiry/consumption. Minimized completion receipts remain fresh for 400 days, then become explicit expired-completed tombstones retained for the lifetime of the currently non-expiring recovery capability.';
comment on column private.account_deletion_jobs.completion_receipt_fresh_until is
  'After this bounded 400-day fresh window, recovery returns expired_completed without conflating the deletion with a never-prepared request.';
comment on column private.account_deletion_jobs.receipt_expires_at is
  'Hard-purge boundary for a future expiring recovery capability. NULL while current Keychain recovery capabilities remain non-expiring.';

commit;
