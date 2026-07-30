import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const repoPath = fileURLToPath(new URL('../../', import.meta.url))
const bootstrap = String.raw`
create role anon;
create role authenticated;
create role service_role;
create schema auth;
create schema private;
create schema storage;

create table auth.users (
  id uuid primary key,
  deleted_at timestamptz
);
create table auth.sessions (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), '')::jsonb, '{}'::jsonb)
$$;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(auth.jwt()->>'sub', '')::uuid
$$;

create table public.users (
  id uuid primary key,
  display_name text,
  username text not null
);
create table public.visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  upload_state text not null default 'complete',
  visibility text not null default 'everyone'
);
create table public.recipe_identities (
  id uuid primary key default gen_random_uuid(),
  name text not null
);
create table public.recipe_versions (
  id uuid primary key default gen_random_uuid(),
  recipe_identity_id uuid not null references public.recipe_identities(id),
  version_number integer not null default 1,
  version_label text,
  brew_details jsonb not null default '{}'::jsonb
);
create table public.trusted_recommendations (
  id uuid primary key default gen_random_uuid(),
  target_recipe_version_id uuid references public.recipe_versions(id),
  target_kind text not null,
  recipient_id uuid not null,
  sender_id uuid not null,
  status text not null default 'active',
  note text,
  created_at timestamptz not null default now()
);
create function private.can_project_recipe_version_as(uuid,uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select false
$$;
create table public.cafe_lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.users(id) on delete set null,
  title text not null,
  description text,
  visibility text not null default 'private',
  system_kind text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.cafe_list_members (
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'editor',
  invitation_status text not null default 'pending',
  invited_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  accepted_at timestamptz,
  responded_at timestamptz,
  expires_at timestamptz,
  primary key (list_id, user_id)
);
create table public.shared_memories (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references public.users(id) on delete set null,
  managed_by uuid references public.users(id) on delete set null,
  context_type text not null default 'home',
  location_label text not null default 'Home',
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.shared_memory_members (
  id uuid primary key default gen_random_uuid(),
  shared_memory_id uuid not null references public.shared_memories(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  invited_by uuid references public.users(id) on delete set null,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  left_at timestamptz,
  expires_at timestamptz,
  unique (shared_memory_id, user_id)
);

create table private.moderation_actions (
  target_type text not null,
  target_id uuid not null,
  action_kind text not null,
  active boolean not null default true
);
create function private.is_live_account_as(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_user_id is not null and exists (
    select 1 from auth.users where id = p_user_id and deleted_at is null
  )
$$;
create function private.has_active_moderation_action(
  p_target_type text, p_target_id uuid, p_actions text[]
) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from private.moderation_actions
    where target_type = p_target_type and target_id = p_target_id
      and action_kind = any(p_actions) and active
  )
$$;
create function private.can_socially_mutate_as(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_live_account_as(p_user_id)
$$;
create function private.blocked_between(uuid,uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select false
$$;
create function private.lock_social_pairs_v1(uuid,uuid[],boolean)
returns void language plpgsql security definer set search_path = '' as $$
begin
  return;
end
$$;

create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text not null,
  name text not null,
  owner uuid,
  owner_id text,
  unique (bucket_id, name)
);
create function storage.foldername(path text) returns text[] language sql immutable as $$
  select case when array_length(string_to_array(path, '/'), 1) > 1
    then (string_to_array(path, '/'))[1:array_length(string_to_array(path, '/'), 1)-1]
    else array[]::text[] end
$$;
create function storage.extension(path text) returns text language sql immutable as $$
  select split_part(path, '.', array_length(string_to_array(path, '.'), 1))
$$;
alter table storage.objects enable row level security;

create function public.can_view_visit_photo_object(p_object_name text)
returns boolean language sql stable security definer set search_path = '' as $$
  select false
$$;

create table private.account_deletion_jobs (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null unique,
  subject_id uuid not null,
  protocol_version smallint not null default 2
    constraint account_deletion_jobs_protocol_version_check check (protocol_version = 2),
  status text not null default 'prepared' check (status in (
    'prepared','identity_deletion_pending','collaboration_pending','cleanup_pending','completed'
  )),
  storage_manifest jsonb not null default '[]'::jsonb,
  collaboration_manifest jsonb not null default '{}'::jsonb,
  identity_attempts integer not null default 0,
  cleanup_attempts integer not null default 0,
  last_error_code text,
  storage_ownership_detached_at timestamptz,
  identity_deleted_at timestamptz,
  collaboration_finalized_at timestamptz,
  cleanup_completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to service_role;
grant select,insert,update on private.account_deletion_jobs to service_role;

create function public.prepare_account_deletion_v2(p_subject_id uuid, p_request_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare job private.account_deletion_jobs%rowtype;
declare list_plan jsonb;
declare list_delete jsonb;
declare memory_plan jsonb;
declare memory_delete jsonb;
begin
  select coalesce(jsonb_agg(jsonb_build_object(
    'list_id', list.id, 'successor_id', successor.user_id
  )), '[]'::jsonb) into list_plan
  from public.cafe_lists list
  join lateral (
    select member.user_id from public.cafe_list_members member
    where member.list_id = list.id and member.user_id <> p_subject_id
      and member.invitation_status = 'accepted'
    order by member.created_at, member.user_id limit 1
  ) successor on true
  where list.owner_id = p_subject_id and list.system_kind is null;
  select coalesce(jsonb_agg(list.id), '[]'::jsonb) into list_delete
  from public.cafe_lists list where list.owner_id = p_subject_id
    and (list.system_kind is not null or not exists (
      select 1 from public.cafe_list_members member
      where member.list_id = list.id and member.user_id <> p_subject_id
        and member.invitation_status = 'accepted'
    ));
  select coalesce(jsonb_agg(jsonb_build_object(
    'shared_memory_id', memory.id, 'successor_id', successor.user_id
  )), '[]'::jsonb) into memory_plan
  from public.shared_memories memory
  join lateral (
    select member.user_id from public.shared_memory_members member
    where member.shared_memory_id = memory.id and member.user_id <> p_subject_id
      and member.status = 'accepted'
    order by member.created_at, member.user_id limit 1
  ) successor on true
  where memory.managed_by = p_subject_id or memory.created_by = p_subject_id;
  select coalesce(jsonb_agg(memory.id), '[]'::jsonb) into memory_delete
  from public.shared_memories memory
  where (memory.managed_by = p_subject_id or memory.created_by = p_subject_id)
    and not exists (
      select 1 from public.shared_memory_members member
      where member.shared_memory_id = memory.id and member.user_id <> p_subject_id
        and member.status = 'accepted'
    );
  insert into private.account_deletion_jobs(
    request_id,subject_id,collaboration_manifest
  ) values (
    p_request_id,p_subject_id,jsonb_build_object(
      'transferred_cafe_lists',list_plan,
      'deleted_owner_only_cafe_lists',list_delete,
      'transferred_shared_memories',memory_plan,
      'deleted_owner_only_shared_memories',memory_delete
    )
  ) returning * into job;
  return jsonb_build_object('job_id',job.id);
end
$$;

create function public.confirm_account_identity_deleted_v2(p_job_id uuid)
returns boolean language sql security definer set search_path = '' as $$
  select not exists (
    select 1 from auth.users account join private.account_deletion_jobs job
      on account.id = job.subject_id where job.id = p_job_id
  )
$$;
create function public.mark_account_deletion_identity_deleted_v2(p_job_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update private.account_deletion_jobs set status='collaboration_pending',
    identity_deleted_at=coalesce(identity_deleted_at,now()),updated_at=now()
  where id=p_job_id;
end
$$;
`

await db.exec(bootstrap)
const migration = await fs.readFile(
  repoPath + 'supabase/migrations/20260722103000_alpha_account_deletion_hardening.sql',
  'utf8'
)
await db.exec(migration)
const acknowledgementMigration = await fs.readFile(
  repoPath + 'supabase/migrations/20260722105000_alpha_account_deletion_completion_ack.sql',
  'utf8'
)
await db.exec(acknowledgementMigration)

const ids = {
  owner: '10000000-0000-4000-8000-000000000001',
  successor: '10000000-0000-4000-8000-000000000002',
  unsafe: '10000000-0000-4000-8000-000000000003',
  session: '20000000-0000-4000-8000-000000000001',
  oldSession: '20000000-0000-4000-8000-000000000002',
  freshSession: '20000000-0000-4000-8000-000000000003',
  unsafeFreshSession: '20000000-0000-4000-8000-000000000004',
  request: '30000000-0000-4000-8000-000000000001',
  list: '40000000-0000-4000-8000-000000000001',
  memory: '50000000-0000-4000-8000-000000000001',
  listInvite: '40000000-0000-4000-8000-000000000002',
  listAccept: '40000000-0000-4000-8000-000000000003',
  memoryInvite: '50000000-0000-4000-8000-000000000002',
  memoryAccept: '50000000-0000-4000-8000-000000000003',
  object: '60000000-0000-4000-8000-000000000001',
  foreignPrefixObject: '60000000-0000-4000-8000-000000000002',
  unsafeObject: '60000000-0000-4000-8000-000000000003',
  staleLease: '80000000-0000-4000-8000-000000000001',
  currentLease: '80000000-0000-4000-8000-000000000002'
}
const recoveryHash = '11'.repeat(32)
const proofHash = '22'.repeat(32)
const authorizationHash = '55'.repeat(32)

await db.exec(`
insert into auth.users(id) values ('${ids.owner}'),('${ids.successor}'),('${ids.unsafe}');
insert into auth.sessions(id,user_id,created_at) values
('${ids.session}','${ids.owner}',now()-interval '1 hour'),
('${ids.oldSession}','${ids.unsafe}',now()-interval '1 hour');
insert into public.users(id,display_name,username) values
('${ids.owner}','Owner','owner'),
('${ids.successor}','Successor','successor'),
('${ids.unsafe}','Unsafe','unsafe');
insert into public.cafe_lists(id,owner_id,title)
values ('${ids.list}','${ids.owner}','Transfer me');
insert into public.cafe_lists(id,owner_id,title) values
('${ids.listInvite}','${ids.owner}','Freeze invite'),
('${ids.listAccept}','${ids.owner}','Freeze accept');
insert into public.cafe_list_members(
  list_id,user_id,invited_by,invitation_status,accepted_at,responded_at
) values (
  '${ids.list}','${ids.successor}','${ids.owner}','accepted',now(),now()
);
insert into public.cafe_list_members(
  list_id,user_id,invited_by,invitation_status
) values (
  '${ids.listAccept}','${ids.successor}','${ids.owner}','pending'
);
insert into public.shared_memories(id,created_by,managed_by)
values ('${ids.memory}','${ids.owner}','${ids.owner}');
insert into public.shared_memories(id,created_by,managed_by) values
('${ids.memoryInvite}','${ids.owner}','${ids.owner}'),
('${ids.memoryAccept}','${ids.owner}','${ids.owner}');
insert into public.shared_memory_members(
  shared_memory_id,user_id,invited_by,status,responded_at
) values (
  '${ids.memory}','${ids.successor}','${ids.owner}','accepted',now()
);
insert into public.shared_memory_members(
  shared_memory_id,user_id,invited_by,status
) values (
  '${ids.memoryAccept}','${ids.successor}','${ids.owner}','pending'
);
insert into storage.objects(id,bucket_id,name,owner,owner_id)
values (
  '${ids.object}','visit-photos-private',
  '${ids.owner}/70000000-0000-4000-8000-000000000001/photo.jpg',
  '${ids.owner}','${ids.owner}'
);
alter table storage.objects disable trigger guard_account_storage_write_v3;
insert into storage.objects(id,bucket_id,name,owner,owner_id) values (
  '${ids.foreignPrefixObject}','visit-photos',
  '${ids.owner}/foreign-owned.jpg','${ids.successor}','${ids.successor}'
);
alter table storage.objects enable trigger guard_account_storage_write_v3;
`)

const challengeResult = await db.query(`
select public.begin_account_deletion_step_up_v3(
  '${ids.owner}','${ids.session}','${ids.request}','${recoveryHash}','${proofHash}'
) payload
`)
const challenge = challengeResult.rows[0].payload
const currentEpochResult = await db.query(`select extract(epoch from now())::bigint value`)
const currentEpoch = currentEpochResult.rows[0].value
try {
  await db.query(`select public.authorize_account_deletion_step_up_v3(
    '${challenge.challenge_id}','${ids.owner}','${ids.request}','${recoveryHash}',
    '${ids.session}','password',${currentEpoch},'${authorizationHash}'
  )`)
  throw new Error('initiating session authorized its own deletion challenge')
} catch (error) {
  if (!String(error).includes('step_up_reauthentication_required')) throw error
}

await db.exec(`insert into auth.sessions(id,user_id,created_at)
values ('${ids.freshSession}','${ids.owner}',now())`)
const freshEpochResult = await db.query(`select extract(epoch from now())::bigint value`)
const freshEpoch = freshEpochResult.rows[0].value
const authorized = await db.query(`
select public.authorize_account_deletion_step_up_v3(
  '${challenge.challenge_id}','${ids.owner}','${ids.request}','${recoveryHash}',
  '${ids.freshSession}','password',${freshEpoch},'${authorizationHash}'
) payload
`)
if (authorized.rows[0].payload.authorized !== true) {
  throw new Error('fresh AMR/new-session step-up was not authorized')
}
try {
  await db.query(`select public.authorize_account_deletion_step_up_v3(
    '${challenge.challenge_id}','${ids.owner}','${ids.request}','${recoveryHash}',
    '${ids.freshSession}','password',${freshEpoch},'${'66'.repeat(32)}'
  )`)
  throw new Error('step-up challenge was authorized more than once')
} catch (error) {
  if (!String(error).includes('step_up_challenge_expired')) throw error
}

const prepared = await db.query(`
select public.prepare_account_deletion_v3(
  '${ids.owner}','${ids.freshSession}','${ids.request}','${recoveryHash}','${proofHash}',
  '${challenge.challenge_id}','${authorizationHash}'
) payload
`)
const job = prepared.rows[0].payload
if (job.storage_manifest.length !== 1 || job.storage_manifest[0].object_id !== ids.object) {
  throw new Error('owner-authoritative exact Storage object was not frozen')
}
const consumed = await db.query(`select consumed_at from private.account_deletion_step_up_challenges
  where id='${challenge.challenge_id}'`)
if (!consumed.rows[0].consumed_at) throw new Error('step-up authorization was not consumed')
const firstLease = await db.query(`select public.claim_account_deletion_job_v3(
  '${job.job_id}','${ids.staleLease}'
) claimed`)
if (firstLease.rows[0].claimed !== true) throw new Error('exact job lease was not claimed')
await db.exec(`update private.account_deletion_jobs
  set lease_expires_at=now()-interval '1 second' where id='${job.job_id}'`)
const reclaimed = await db.query(`select public.claim_account_deletion_job_v3(
  '${job.job_id}','${ids.currentLease}'
) claimed`)
if (reclaimed.rows[0].claimed !== true) throw new Error('expired job lease was not reclaimed')
const staleMutation = await db.query(`select public.mark_account_deletion_pending_v3(
  '${job.job_id}','identity_deletion_pending','stale','${ids.staleLease}'
) changed`)
if (staleMutation.rows[0].changed !== false) throw new Error('stale job lease mutated a reclaimed job')
const renewed = await db.query(`select public.renew_account_deletion_job_lease_v3(
  '${job.job_id}','${ids.currentLease}'
) renewed`)
if (renewed.rows[0].renewed !== true) throw new Error('current job lease did not renew')
const sealed = await db.query(`select public.seal_account_deletion_storage_preflight_v3(
  '${job.job_id}','${ids.currentLease}'
) ok`)
if (sealed.rows[0].ok !== true) throw new Error('Storage preflight did not seal')

await db.exec(`select set_config(
  'request.jwt.claims',
  '{"sub":"${ids.successor}","role":"authenticated"}',
  false
)`)
for (const [label, statement] of [
  ['cafe-list invite', `insert into public.cafe_list_members(
    list_id,user_id,invited_by,invitation_status
  ) values ('${ids.listInvite}','${ids.successor}','${ids.successor}','pending')`],
  ['cafe-list accept', `update public.cafe_list_members
    set invitation_status='accepted',accepted_at=now(),responded_at=now()
    where list_id='${ids.listAccept}' and user_id='${ids.successor}'`],
  ['shared MugShot invite', `insert into public.shared_memory_members(
    shared_memory_id,user_id,invited_by,status
  ) values ('${ids.memoryInvite}','${ids.successor}','${ids.successor}','pending')`],
  ['shared MugShot accept', `update public.shared_memory_members
    set status='accepted',responded_at=now()
    where shared_memory_id='${ids.memoryAccept}' and user_id='${ids.successor}'`]
]) {
  try {
    await db.exec(statement)
    throw new Error(`post-prepare ${label} was accepted`)
  } catch (error) {
    if (!String(error).includes('collaboration plan is frozen by account deletion')) throw error
  }
}
await db.exec(`select set_config('request.jwt.claims', '{}', false)`)

try {
  await db.exec(`
    alter table storage.objects disable row level security;
    grant usage on schema storage to authenticated;
    grant insert on storage.objects to authenticated;
    select set_config(
      'request.jwt.claims',
      '{"sub":"${ids.owner}","role":"authenticated"}',
      false
    );
    set role authenticated;
    insert into storage.objects(bucket_id,name,owner,owner_id) values (
      'future-owned-media','legacy/noncanonical.jpg','${ids.owner}','${ids.owner}'
    );
    reset role;
  `)
  throw new Error('post-prepare Storage write was accepted')
} catch (error) {
  await db.exec('reset role')
  if (!String(error).includes('account Storage writes are unavailable')) throw error
}

const unsafeRequest = '30000000-0000-4000-8000-000000000002'
const unsafeRecoveryHash = '33'.repeat(32)
const unsafeProofHash = '44'.repeat(32)
const unsafeAuthorizationHash = '77'.repeat(32)
await db.exec(`insert into storage.objects(id,bucket_id,name,owner,owner_id) values (
  '${ids.unsafeObject}','unsupported-owned-media','legacy/unsafe.jpg',
  '${ids.unsafe}','${ids.unsafe}'
)`)
const unsafeChallengeResult = await db.query(`
select public.begin_account_deletion_step_up_v3(
  '${ids.unsafe}','${ids.oldSession}','${unsafeRequest}',
  '${unsafeRecoveryHash}','${unsafeProofHash}'
) payload
`)
const unsafeChallenge = unsafeChallengeResult.rows[0].payload
await db.exec(`insert into auth.sessions(id,user_id,created_at)
values ('${ids.unsafeFreshSession}','${ids.unsafe}',now())`)
try {
  await db.query(`select public.authorize_account_deletion_step_up_v3(
    '${unsafeChallenge.challenge_id}','${ids.unsafe}','${unsafeRequest}',
    '${unsafeRecoveryHash}','${ids.unsafeFreshSession}','password',
    ${freshEpoch - 3600},'${unsafeAuthorizationHash}'
  )`)
  throw new Error('stale AMR event authorized deletion')
} catch (error) {
  if (!String(error).includes('step_up_reauthentication_required')) throw error
}
const unsafeFreshEpochResult = await db.query(`select extract(epoch from now())::bigint value`)
const unsafeFreshEpoch = unsafeFreshEpochResult.rows[0].value
await db.query(`select public.authorize_account_deletion_step_up_v3(
  '${unsafeChallenge.challenge_id}','${ids.unsafe}','${unsafeRequest}',
  '${unsafeRecoveryHash}','${ids.unsafeFreshSession}','password',
  ${unsafeFreshEpoch},'${unsafeAuthorizationHash}'
)`)
try {
  await db.query(`select public.prepare_account_deletion_v3(
    '${ids.unsafe}','${ids.unsafeFreshSession}','${unsafeRequest}',
    '${unsafeRecoveryHash}','${unsafeProofHash}',
    '${unsafeChallenge.challenge_id}','${unsafeAuthorizationHash}'
  )`)
  throw new Error('unsupported owner-authoritative Storage inventory was accepted')
} catch (error) {
  if (!String(error).includes('unsafe_account_storage_inventory')) throw error
}
const unsafeJob = await db.query(`select count(*)::int count
  from private.account_deletion_jobs where subject_id='${ids.unsafe}'`)
if (unsafeJob.rows[0].count !== 0) {
  throw new Error('unsupported Storage preflight crossed the durable job boundary')
}

await db.query(`select public.detach_account_storage_ownership_v3(
  '${job.job_id}','${ids.currentLease}'
)`)
const detached = await db.query(`select owner,owner_id from storage.objects where id='${ids.object}'`)
if (detached.rows[0].owner !== null || detached.rows[0].owner_id !== null) {
  throw new Error('exact object ownership was not detached')
}

await db.exec(`
delete from auth.users where id='${ids.owner}';
delete from public.users where id='${ids.owner}';
select public.mark_account_deletion_identity_deleted_v3(
  '${job.job_id}','${ids.currentLease}'
);
select public.finalize_account_collaboration_v3(
  '${job.job_id}','${ids.currentLease}'
);
`)
const transferred = await db.query(`select owner_id from public.cafe_lists where id='${ids.list}'`)
if (transferred.rows[0].owner_id !== ids.successor) {
  throw new Error('frozen cafe-list successor did not receive ownership')
}
const managed = await db.query(`select managed_by from public.shared_memories where id='${ids.memory}'`)
if (managed.rows[0].managed_by !== ids.successor) {
  throw new Error('frozen shared MugShot successor did not receive management')
}

const verified = await db.query(`select public.verify_account_storage_cleanup_v3('${job.job_id}') ok`)
if (verified.rows[0].ok !== true) throw new Error('exact Storage cleanup verification failed')
await db.exec(`
delete from storage.objects where id='${ids.object}';
select public.mark_account_deletion_cleanup_completed_v3(
  '${job.job_id}','${ids.currentLease}'
);
`)
const receipt = await db.query(`
select subject_id,storage_manifest,storage_manifest_object_count,
  collaboration_manifest,authorized_session_id,authorized_at,
  step_up_challenge_id,redacted_at,receipt_expires_at,
  completion_receipt_fresh_until,completion_proof_state
from private.account_deletion_jobs where id='${job.job_id}'
`)
const final = receipt.rows[0]
if (
  final.subject_id !== null || final.authorized_session_id !== null ||
  final.authorized_at !== null || final.step_up_challenge_id !== null ||
  final.storage_manifest.length !== 0 ||
  final.storage_manifest_object_count !== 0 ||
  Object.keys(final.collaboration_manifest).length !== 0 || !final.redacted_at ||
  final.receipt_expires_at !== null || !final.completion_receipt_fresh_until ||
  final.completion_proof_state !== 'completed'
) {
  throw new Error('completed receipt was not redacted')
}
const recovered = await db.query(`select public.read_account_deletion_job_by_recovery_v3(
  '${ids.request}','${recoveryHash}','${proofHash}'
) payload`)
if (
  recovered.rows[0].payload.job_id !== job.job_id ||
  recovered.rows[0].payload.status !== 'completed'
) {
  throw new Error('capability-bound recovery did not survive identity deletion')
}

const contract = await fs.readFile(
  repoPath + 'supabase/tests/account_data_lifecycle_v3_hardening.sql',
  'utf8'
)
await db.exec(contract.replace(/^\\set[^\n]*\n/, ''))

await db.exec(`
update private.account_deletion_jobs
set cleanup_completed_at=now()-interval '31 days',
    redacted_at=now()-interval '31 days',
    completion_receipt_fresh_until=now()+interval '369 days',
    receipt_expires_at=null
where id='${job.job_id}';
update private.account_deletion_step_up_challenges
set issued_at=now()-interval '3 days',
    expires_at=now()-interval '2 days',
    authorization_expires_at=now()-interval '2 days',
    authorized_at=now()-interval '2 days',
    consumed_at=now()-interval '2 days'
where id='${challenge.challenge_id}';
select public.purge_account_deletion_security_receipts_v3();
`)
const afterThirtyDays = await db.query(`select
  exists(select 1 from private.account_deletion_jobs where id='${job.job_id}') job_exists,
  exists(select 1 from private.account_deletion_step_up_challenges
    where id='${challenge.challenge_id}') challenge_exists`)
if (!afterThirtyDays.rows[0].job_exists || afterThirtyDays.rows[0].challenge_exists) {
  throw new Error('31-day recovery proof or short-lived step-up retention was wrong')
}
const recoveredAfterThirtyDays = await db.query(`
  select public.read_account_deletion_job_by_recovery_v3(
    '${ids.request}','${recoveryHash}','${proofHash}'
  ) payload
`)
if (recoveredAfterThirtyDays.rows[0].payload.status !== 'completed') {
  throw new Error('capability recovery was lost after more than 30 days offline')
}
await db.exec(`
update private.account_deletion_jobs
set completion_receipt_fresh_until=now()-interval '1 second'
where id='${job.job_id}';
select public.purge_account_deletion_security_receipts_v3();
`)
const expiredProof = await db.query(`
  select public.read_account_deletion_job_by_recovery_v3(
    '${ids.request}','${recoveryHash}','${proofHash}'
  ) payload
`)
if (
  expiredProof.rows[0].payload.job_id !== job.job_id ||
  expiredProof.rows[0].payload.completion_proof_state !== 'expired_completed'
) {
  throw new Error('expired completion was conflated with a never-prepared request')
}

const rejectedAcknowledgement = await db.query(`
  select public.acknowledge_account_deletion_completion_v3(
    '${ids.request}','${'aa'.repeat(32)}','${proofHash}'
  ) payload
`)
if (rejectedAcknowledgement.rows[0].payload.status !== 'not_found') {
  throw new Error('wrong recovery capability acknowledged local cleanup')
}
const acknowledgement = await db.query(`
  select public.acknowledge_account_deletion_completion_v3(
    '${ids.request}','${recoveryHash}','${proofHash}'
  ) payload
`)
if (
  acknowledgement.rows[0].payload.acknowledged !== true ||
  acknowledgement.rows[0].payload.final_retention_days !== 30
) {
  throw new Error('valid local-cleanup acknowledgement was not retained')
}
await db.exec(`
  update private.account_deletion_jobs
  set local_cleanup_acknowledged_at=now()-interval '31 days',
      receipt_expires_at=now()-interval '1 second'
  where id='${job.job_id}';
  select public.purge_account_deletion_security_receipts_v3();
`)
const afterAcknowledgedGrace = await db.query(`
  select exists(
    select 1 from private.account_deletion_jobs where id='${job.job_id}'
  ) job_exists
`)
if (afterAcknowledgedGrace.rows[0].job_exists) {
  throw new Error('acknowledged tombstone survived its final grace period')
}

console.log('PGlite account deletion V3 step-up, lease fencing, Storage, succession, durable recovery, and bounded acknowledgement checks passed')
await db.close()
