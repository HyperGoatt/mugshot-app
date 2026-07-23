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
create table auth.users (
  id uuid primary key,
  deleted_at timestamptz
);
create function auth.uid() returns uuid language sql stable as $$
  select nullif((current_setting('request.jwt.claims', true)::jsonb)->>'sub', '')::uuid
$$;

create table public.users (
  id uuid primary key,
  display_name text,
  username text not null,
  avatar_url text,
  taste_passport_visibility text not null default 'everyone'
);
create table public.cafes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  city text,
  latitude double precision,
  longitude double precision,
  apple_place_id text,
  website_url text
);
create table public.visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  cafe_id uuid not null references public.cafes(id),
  poster_photo_url text,
  visibility text not null default 'everyone',
  upload_state text not null default 'complete',
  created_at timestamptz not null default now()
);
create table public.user_cafe_states (
  user_id uuid not null references public.users(id),
  cafe_id uuid not null references public.cafes(id),
  is_favorite boolean not null default false,
  want_to_try boolean not null default false,
  primary key (user_id, cafe_id)
);
create table public.user_blocks (
  blocker_id uuid not null references public.users(id),
  blocked_id uuid not null references public.users(id),
  primary key (blocker_id, blocked_id)
);
create table public.friends (
  user_id uuid not null references public.users(id),
  friend_user_id uuid not null references public.users(id),
  primary key (user_id, friend_user_id)
);
create table private.restricted_users (
  user_id uuid primary key
);
create table public.cafe_lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.users(id) on delete set null,
  title text not null check (length(trim(title)) between 1 and 80),
  description text check (length(coalesce(description, '')) <= 280),
  visibility text not null default 'private' check (visibility in ('private','friends','invited')),
  system_kind text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.cafe_list_members (
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('editor','viewer')),
  invitation_status text not null default 'pending' check (invitation_status in ('pending','accepted')),
  invited_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  primary key (list_id, user_id)
);
create table public.cafe_list_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id),
  position integer not null default 0,
  contributor_id uuid references public.users(id) on delete set null,
  note text,
  created_at timestamptz not null default now(),
  unique (list_id, cafe_id)
);

create function private.blocked_between(a uuid, b uuid) returns boolean language sql stable as $$
  select a is not null and b is not null and exists (
    select 1 from public.user_blocks
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)
  )
$$;
create function private.confirmed_friends(a uuid, b uuid) returns boolean language sql stable as $$
  select exists (select 1 from public.friends where user_id = a and friend_user_id = b)
$$;
create function private.can_socially_mutate_as(actor uuid) returns boolean language sql stable as $$
  select actor is not null and not exists (
    select 1 from private.restricted_users where user_id = actor
  )
$$;
create function private.is_live_account_as(actor uuid) returns boolean language sql stable as $$
  select actor is not null and exists (
    select 1 from auth.users where id = actor and deleted_at is null
  )
$$;
create function private.can_view_user_as(subject uuid, viewer uuid) returns boolean language sql stable as $$
  select subject is not null
    and viewer is not null
    and not private.blocked_between(subject, viewer)
    and not exists (
      select 1 from private.restricted_users where user_id = subject
    )
$$;
create function private.can_view_visit_as(visit_id uuid, viewer uuid) returns boolean language sql stable as $$
  select exists (
    select 1 from public.visits visit
    where visit.id = visit_id
      and (visit.user_id = viewer or visit.visibility = 'everyone')
      and not private.blocked_between(visit.user_id, viewer)
  )
$$;

create function private.can_view_cafe_list_as(p_list_id uuid, p_viewer uuid) returns boolean language sql stable as $$
  select exists (select 1 from public.cafe_lists where id = p_list_id and owner_id = p_viewer)
$$;
create function private.can_view_cafe_list_items_as(p_list_id uuid, p_viewer uuid) returns boolean language sql stable as $$
  select private.can_view_cafe_list_as(p_list_id, p_viewer)
$$;
create function private.can_edit_cafe_list_as(p_list_id uuid, p_actor uuid) returns boolean language sql stable as $$
  select private.can_view_cafe_list_as(p_list_id, p_actor)
$$;
create function public.can_view_cafe_list(p_list_id uuid, p_viewer uuid default auth.uid()) returns boolean language sql stable as $$
  select private.can_view_cafe_list_as(p_list_id, p_viewer)
$$;
create function public.can_view_cafe_list_items(p_list_id uuid, p_viewer uuid default auth.uid()) returns boolean language sql stable as $$
  select private.can_view_cafe_list_items_as(p_list_id, p_viewer)
$$;
create function public.is_blocked_between(a uuid, b uuid) returns boolean language sql stable as $$
  select private.blocked_between(a, b)
$$;

alter table public.cafe_lists enable row level security;
alter table public.cafe_list_members enable row level security;
alter table public.cafe_list_items enable row level security;
create policy "Visible cafe list memberships" on public.cafe_list_members for select to authenticated using (true);
create policy "Visible cafe list items" on public.cafe_list_items for select to authenticated using (true);
grant select on public.cafe_lists, public.cafe_list_members, public.cafe_list_items to authenticated;

create table private.visit_recipe_payload_staging (
  visit_id uuid primary key,
  user_id uuid not null,
  brew_details jsonb not null default '{}'::jsonb,
  brew_method text,
  equipment text,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '24 hours'
);
create table public.recipe_identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  name text not null
);
create table public.recipe_versions (
  id uuid primary key default gen_random_uuid(),
  recipe_identity_id uuid not null references public.recipe_identities(id) on delete cascade,
  version_number integer not null default 1,
  version_label text,
  brew_details jsonb not null default '{}'::jsonb,
  brew_method text,
  equipment text,
  source_visit_id uuid,
  visibility text not null default 'private',
  source_kind text not null default 'unspecified',
  redistribution_allowed boolean not null default false,
  source_recipe_version_id uuid references public.recipe_versions(id),
  created_at timestamptz not null default now()
);
create table public.trusted_recommendations (
  id uuid primary key default gen_random_uuid(),
  target_kind text not null,
  target_recipe_version_id uuid references public.recipe_versions(id),
  recipient_id uuid not null references public.users(id),
  sender_id uuid not null references public.users(id),
  status text not null default 'active'
);
create table public.shared_memories (
  id uuid primary key default gen_random_uuid(),
  created_by uuid references public.users(id) on delete set null,
  source_visit_id uuid,
  context_type text not null default 'Cafe',
  location_label text not null default 'Cafe',
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.shared_memory_members (
  id uuid primary key default gen_random_uuid(),
  shared_memory_id uuid not null references public.shared_memories(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  invited_by uuid references public.users(id) on delete set null,
  status text not null default 'pending' check (status in ('pending','accepted','declined','cancelled','left')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  left_at timestamptz,
  unique (shared_memory_id, user_id)
);
`

await db.exec(bootstrap)
const migration = await fs.readFile(
  repoPath + 'supabase/migrations/20260722034500_alpha_collaborative_cafe_lists.sql',
  'utf8'
)
await db.exec(migration)

// Seed invitations that predate the expiry contract. The migration must keep
// the still-live rows with their original deterministic deadline and close the
// already-expired rows instead of granting every legacy row a fresh window.
await db.exec(`
insert into auth.users(id) values
('71000000-0000-4000-8000-000000000001'),
('71000000-0000-4000-8000-000000000002'),
('71000000-0000-4000-8000-000000000003');
insert into public.users(id,display_name,username) values
('71000000-0000-4000-8000-000000000001','Legacy Owner','legacy_owner'),
('71000000-0000-4000-8000-000000000002','Legacy Live','legacy_live'),
('71000000-0000-4000-8000-000000000003','Legacy Expired','legacy_expired');
insert into public.cafe_lists(id,owner_id,title) values
('72000000-0000-4000-8000-000000000001',
 '71000000-0000-4000-8000-000000000001','Legacy list');
insert into public.cafe_list_members(
  list_id,user_id,role,invitation_status,invited_by,created_at,updated_at
) values
('72000000-0000-4000-8000-000000000001',
 '71000000-0000-4000-8000-000000000002','viewer','pending',
 '71000000-0000-4000-8000-000000000001',now() - interval '7 days',now() - interval '7 days'),
('72000000-0000-4000-8000-000000000001',
 '71000000-0000-4000-8000-000000000003','viewer','pending',
 '71000000-0000-4000-8000-000000000001',now() - interval '20 days',now() - interval '20 days');
insert into public.shared_memories(id,created_by) values
('73000000-0000-4000-8000-000000000001',
 '71000000-0000-4000-8000-000000000001');
insert into public.shared_memory_members(
  shared_memory_id,user_id,invited_by,status,created_at
) values
('73000000-0000-4000-8000-000000000001',
 '71000000-0000-4000-8000-000000000002',
 '71000000-0000-4000-8000-000000000001','pending',now() - interval '7 days'),
('73000000-0000-4000-8000-000000000001',
 '71000000-0000-4000-8000-000000000003',
 '71000000-0000-4000-8000-000000000001','pending',now() - interval '20 days');
`)
const hardeningMigration = await fs.readFile(
  repoPath + 'supabase/migrations/20260722102000_alpha_recipe_collaboration_hardening.sql',
  'utf8'
)
await db.exec(hardeningMigration)

const legacyCafeInvites = await db.query(`
  select user_id, invitation_status, expires_at, created_at
  from public.cafe_list_members
  where list_id = '72000000-0000-4000-8000-000000000001'
  order by user_id
`)
if (
  legacyCafeInvites.rows[0]?.invitation_status !== 'pending' ||
  !legacyCafeInvites.rows[0]?.expires_at ||
  Math.abs(
    new Date(legacyCafeInvites.rows[0].expires_at).getTime() -
      (new Date(legacyCafeInvites.rows[0].created_at).getTime() + 14 * 86400_000),
  ) > 2_000 ||
  legacyCafeInvites.rows[1]?.invitation_status !== 'cancelled' ||
  legacyCafeInvites.rows[1]?.expires_at !== null
) {
  throw new Error('legacy cafe-list invitation expiry backfill was unsafe')
}
const legacySharedInvites = await db.query(`
  select user_id, status, expires_at, created_at
  from public.shared_memory_members
  where shared_memory_id = '73000000-0000-4000-8000-000000000001'
  order by user_id
`)
if (
  legacySharedInvites.rows[0]?.status !== 'pending' ||
  !legacySharedInvites.rows[0]?.expires_at ||
  Math.abs(
    new Date(legacySharedInvites.rows[0].expires_at).getTime() -
      (new Date(legacySharedInvites.rows[0].created_at).getTime() + 14 * 86400_000),
  ) > 2_000 ||
  legacySharedInvites.rows[1]?.status !== 'cancelled' ||
  legacySharedInvites.rows[1]?.expires_at !== null
) {
  throw new Error('legacy shared MugShot invitation expiry backfill was unsafe')
}

const ids = {
  owner: '10000000-0000-4000-8000-000000000001',
  editor: '10000000-0000-4000-8000-000000000002',
  peer: '10000000-0000-4000-8000-000000000003',
  viewer: '10000000-0000-4000-8000-000000000004',
  cafe1: '20000000-0000-4000-8000-000000000001',
  cafe2: '20000000-0000-4000-8000-000000000002'
}
await db.exec(`
insert into auth.users(id) values
('${ids.owner}'),('${ids.editor}'),('${ids.peer}'),('${ids.viewer}');
insert into public.users(id,display_name,username) values
('${ids.owner}','Owner','owner'),('${ids.editor}','Editor','editor'),
('${ids.peer}','Peer','peer'),('${ids.viewer}','Viewer','viewer');
insert into public.cafes(id,name,address,city,latitude,longitude) values
('${ids.cafe1}','First Cafe','1 Main St','Queens',40.7,-73.9),
('${ids.cafe2}','Second Cafe','2 Main St','Queens',40.71,-73.91);
insert into public.friends(user_id,friend_user_id) values
('${ids.owner}','${ids.editor}'),('${ids.editor}','${ids.owner}'),
('${ids.owner}','${ids.peer}'),('${ids.peer}','${ids.owner}'),
('${ids.owner}','${ids.viewer}'),('${ids.viewer}','${ids.owner}'),
('${ids.editor}','${ids.peer}'),('${ids.peer}','${ids.editor}');
`)

const asUser = async (id, sql) => {
  await db.exec(`select set_config('request.jwt.claims', '{"sub":"${id}"}', false)`)
  return db.query(sql)
}

const created = await asUser(ids.owner, `select public.create_cafe_list_v2('Trip',null,'invited') payload`)
const listID = created.rows[0].payload.id
await asUser(ids.owner, `select public.add_cafe_list_item_v2('${listID}','${ids.cafe1}',null)`)
await asUser(ids.owner, `select public.invite_cafe_list_member('${listID}','${ids.editor}','editor')`)
const inviteExpiry = await db.query(`select expires_at from public.cafe_list_members where list_id = '${listID}' and user_id = '${ids.editor}'`)
if (!inviteExpiry.rows[0]?.expires_at) throw new Error('cafe-list invite did not receive expiry')
const pending = await asUser(ids.editor, `select public.get_cafe_list_v2('${listID}') payload`)
if (pending.rows[0].payload.can_view_items !== false || pending.rows[0].payload.items.length !== 0) {
  throw new Error('pending invitation exposed items')
}
await asUser(ids.editor, `select public.respond_cafe_list_invitation_v2('${listID}','accept')`)
await asUser(ids.editor, `select public.add_cafe_list_item_v2('${listID}','${ids.cafe2}','editor stop')`)
const detail = await asUser(ids.editor, `select public.get_cafe_list_v2('${listID}') payload`)
if (detail.rows[0].payload.items[1].cafe_name !== 'Second Cafe') {
  throw new Error('hydrated cafe was missing')
}
await asUser(ids.owner, `select public.invite_cafe_list_member('${listID}','${ids.peer}','editor')`)
await asUser(ids.peer, `select public.respond_cafe_list_invitation_v2('${listID}','accept')`)
await db.exec(`insert into public.user_blocks values ('${ids.editor}','${ids.peer}')`)
const masked = await asUser(ids.editor, `select public.get_cafe_list_v2('${listID}') payload`)
const hidden = masked.rows[0].payload.members.find((member) => member.person.identity_state === 'hidden')
if (!hidden || Object.hasOwn(hidden.person, 'user_id')) {
  throw new Error('blocked collaborator identity was exposed')
}

// A restricted owner disappears from friend-only discovery. Accepted
// collaborators retain durable cafe context with a masked owner and can leave;
// pending invitees receive only redacted decision context, while cancellation
// remains available to the restricted owner as a safety exit.
const friendFixture = await asUser(ids.owner, `
  select public.create_cafe_list_v2('Friend fixture','Hidden while unavailable','friends') payload
`)
const friendFixtureID = friendFixture.rows[0].payload.id
const suspensionFixture = await asUser(ids.owner, `
  select public.create_cafe_list_v2('Suspension fixture','Durable cafe context','invited') payload
`)
const suspensionFixtureID = suspensionFixture.rows[0].payload.id
await asUser(ids.owner, `select public.add_cafe_list_item_v2('${suspensionFixtureID}','${ids.cafe1}','durable')`)
await asUser(ids.owner, `select public.invite_cafe_list_member('${suspensionFixtureID}','${ids.editor}','editor')`)
await asUser(ids.editor, `select public.respond_cafe_list_invitation_v2('${suspensionFixtureID}','accept')`)
await asUser(ids.owner, `select public.invite_cafe_list_member('${suspensionFixtureID}','${ids.viewer}','viewer')`)
await db.exec(`insert into private.restricted_users values ('${ids.owner}')`)

const friendProjection = await asUser(ids.peer, `select public.list_cafe_lists_v2() payload`)
if (friendProjection.rows[0].payload.some((item) => item.id === friendFixtureID)) {
  throw new Error('restricted owner remained in friend-only discovery')
}
const pendingRestricted = await asUser(ids.viewer, `select public.get_cafe_list_v2('${suspensionFixtureID}') payload`)
if (
  pendingRestricted.rows[0].payload.title !== 'Unavailable cafe list invitation' ||
  pendingRestricted.rows[0].payload.description !== null ||
  pendingRestricted.rows[0].payload.can_view_items !== false ||
  pendingRestricted.rows[0].payload.cafe_count !== 0 ||
  pendingRestricted.rows[0].payload.owner.identity_state !== 'hidden' ||
  pendingRestricted.rows[0].payload.items.length !== 0
) {
  throw new Error('restricted-owner pending invitation exposed metadata')
}
const acceptedRestricted = await asUser(ids.editor, `select public.get_cafe_list_v2('${suspensionFixtureID}') payload`)
if (
  acceptedRestricted.rows[0].payload.title !== 'Suspension fixture' ||
  acceptedRestricted.rows[0].payload.can_view_items !== true ||
  acceptedRestricted.rows[0].payload.can_edit_items !== false ||
  acceptedRestricted.rows[0].payload.owner.identity_state !== 'hidden' ||
  acceptedRestricted.rows[0].payload.items.length !== 1
) {
  throw new Error('accepted collaborator lost durable restricted-owner context')
}
try {
  await asUser(ids.editor, `select public.add_cafe_list_item_v2('${suspensionFixtureID}','${ids.cafe2}','blocked')`)
  throw new Error('accepted collaborator edited for a restricted owner')
} catch (error) {
  if (!String(error).includes('cafe list unavailable')) throw error
}
await asUser(ids.owner, `select public.cancel_cafe_list_invitation_v2('${suspensionFixtureID}','${ids.viewer}')`)
try {
  await asUser(ids.owner, `select public.invite_cafe_list_member('${suspensionFixtureID}','${ids.peer}','viewer')`)
  throw new Error('restricted owner expanded collaboration')
} catch (error) {
  if (!String(error).includes('only the list owner can invite')) throw error
}
await asUser(ids.editor, `select public.leave_cafe_list_v2('${suspensionFixtureID}')`)
const exited = await db.query(`
  select
    exists(select 1 from public.cafe_list_members where list_id='${suspensionFixtureID}' and user_id='${ids.editor}') editor_remains,
    (select invitation_status from public.cafe_list_members where list_id='${suspensionFixtureID}' and user_id='${ids.viewer}') viewer_status
`)
if (exited.rows[0].editor_remains || exited.rows[0].viewer_status !== 'cancelled') {
  throw new Error('restricted-owner safety exits were not preserved')
}
await db.exec(`delete from private.restricted_users where user_id='${ids.owner}'`)

await asUser(ids.editor, `select public.move_cafe_list_item_v2((select id from public.cafe_list_items where list_id='${listID}' and cafe_id='${ids.cafe2}'),0)`)
await asUser(ids.editor, `select public.remove_cafe_list_item_v2((select id from public.cafe_list_items where list_id='${listID}' and cafe_id='${ids.cafe1}'))`)
const positions = await db.query(`select position from public.cafe_list_items where list_id='${listID}' order by position`)
if (positions.rows.map(row => row.position).join(',') !== '0') {
  throw new Error('cafe-list positions were not normalized after move/remove')
}

// Exercise the real ON DELETE SET NULL path used by account deletion, then
// prove a live successor is accepted and a restricted successor is rejected.
const departingOwner = '10000000-0000-4000-8000-000000000005'
await db.exec(`
insert into auth.users(id) values ('${departingOwner}');
insert into public.users(id,display_name,username)
values ('${departingOwner}','Departing Owner','departing_owner');
insert into public.cafe_lists(id,owner_id,title)
values ('50000000-0000-4000-8000-000000000001','${departingOwner}','Deletion boundary');
delete from public.users where id = '${departingOwner}';
`)
const orphaned = await db.query(`select owner_id from public.cafe_lists where id='50000000-0000-4000-8000-000000000001'`)
if (orphaned.rows[0]?.owner_id !== null) {
  throw new Error('account deletion could not cross the null cafe-list owner boundary')
}
await db.exec(`update public.cafe_lists set owner_id='${ids.owner}' where id='50000000-0000-4000-8000-000000000001'`)
await db.exec(`insert into private.restricted_users values ('${ids.peer}')`)
try {
  await db.exec(`update public.cafe_lists set owner_id='${ids.peer}' where id='50000000-0000-4000-8000-000000000001'`)
  throw new Error('restricted successor received cafe-list ownership')
} catch (error) {
  if (!String(error).includes('new cafe list owner is unavailable')) throw error
}
await db.exec(`delete from private.restricted_users where user_id='${ids.peer}'`)

// Public reuse is an independent sharing capability. A restricted owner may
// reduce it, but may not turn it back on without the restriction being lifted.
const recipeIdentity = '60000000-0000-4000-8000-000000000001'
const recipeVersion = '60000000-0000-4000-8000-000000000002'
await asUser(ids.owner, `
  insert into public.recipe_identities(id,user_id,name)
  values ('${recipeIdentity}','${ids.owner}','Reusable recipe')
`)
await asUser(ids.owner, `
  insert into public.recipe_versions(
    id,recipe_identity_id,visibility,source_kind,redistribution_allowed
  ) values (
    '${recipeVersion}','${recipeIdentity}','everyone','original',true
  )
`)
await db.exec(`insert into private.restricted_users values ('${ids.owner}')`)
await asUser(ids.owner, `update public.recipe_versions set redistribution_allowed=false where id='${recipeVersion}'`)
try {
  await asUser(ids.owner, `update public.recipe_versions set redistribution_allowed=true where id='${recipeVersion}'`)
  throw new Error('restricted owner expanded public recipe reuse')
} catch (error) {
  if (!String(error).includes('recipe sharing expansion is unavailable')) throw error
}
await db.exec(`delete from private.restricted_users where user_id='${ids.owner}'`)
await asUser(ids.owner, `update public.recipe_versions set redistribution_allowed=true where id='${recipeVersion}'`)

await db.exec(`
insert into private.visit_recipe_payload_staging(visit_id,user_id,expires_at)
select gen_random_uuid(), '${ids.owner}', now() + interval '7 days'
from generate_series(1,20);
do $$ begin
  begin
    insert into private.visit_recipe_payload_staging(visit_id,user_id)
    values (gen_random_uuid(), '${ids.owner}');
    raise exception 'recipe staging quota was not enforced';
  exception when sqlstate '54000' then null;
  end;
end $$;
`)
const clippedExpiry = await db.query(`select max(expires_at) maximum from private.visit_recipe_payload_staging where user_id='${ids.owner}'`)
if (new Date(clippedExpiry.rows[0].maximum).getTime() > Date.now() + 24 * 60 * 60 * 1000 + 10_000) {
  throw new Error('recipe stage expiry exceeded 24 hours')
}

await db.exec(`
insert into auth.users(id)
select ('30000000-0000-4000-8000-' || lpad(value::text, 12, '0'))::uuid
from generate_series(1,13) value;
insert into public.users(id,display_name,username)
select ('30000000-0000-4000-8000-' || lpad(value::text, 12, '0'))::uuid,
       'Invitee ' || value, 'invitee_' || value
from generate_series(1,13) value;
insert into public.shared_memories(id,created_by)
values ('40000000-0000-4000-8000-000000000001','${ids.owner}');
insert into public.shared_memory_members(shared_memory_id,user_id,invited_by,status,responded_at)
values ('40000000-0000-4000-8000-000000000001','${ids.owner}','${ids.owner}','accepted',now());
insert into public.shared_memory_members(shared_memory_id,user_id,invited_by,status)
select '40000000-0000-4000-8000-000000000001',
       ('30000000-0000-4000-8000-' || lpad(value::text, 12, '0'))::uuid,
       '${ids.owner}', 'pending'
from generate_series(1,12) value;
do $$ begin
  begin
    insert into public.shared_memory_members(shared_memory_id,user_id,invited_by,status)
    values (
      '40000000-0000-4000-8000-000000000001',
      '30000000-0000-4000-8000-000000000013',
      '${ids.owner}', 'pending'
    );
    raise exception 'shared MugShot participant cap was not enforced';
  exception when sqlstate '54000' then null;
  end;
end $$;
`)

const securityContract = await fs.readFile(
  repoPath + 'supabase/tests/alpha_collaborative_cafe_lists_security.sql',
  'utf8'
)
await db.exec(securityContract)

console.log('PGlite collaborative migration, legacy expiry, behavior, and security checks passed')
await db.close()
