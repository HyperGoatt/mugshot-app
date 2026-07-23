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

create function auth.uid() returns uuid language sql stable as $$
  select nullif(
    (current_setting('request.jwt.claims', true)::jsonb)->>'sub', ''
  )::uuid
$$;

create table public.users (
  id uuid primary key,
  display_name text,
  username text not null
);
create table private.restricted_users (
  user_id uuid primary key references public.users(id) on delete cascade,
  social_disabled boolean not null default false,
  hidden boolean not null default false,
  recipient_disabled boolean not null default false
);
create table public.user_blocks (
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  primary key (blocker_id, blocked_id)
);

create table public.cafe_lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.users(id) on delete set null,
  title text not null check (char_length(btrim(title)) between 1 and 80),
  system_kind text,
  updated_at timestamptz not null default now()
);
create table public.cafe_list_members (
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('editor', 'viewer')),
  invitation_status text not null check (
    invitation_status in ('pending', 'accepted', 'declined', 'cancelled')
  ),
  invited_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  accepted_at timestamptz,
  responded_at timestamptz,
  expires_at timestamptz,
  primary key (list_id, user_id)
);

create table public.notification_preferences (
  user_id uuid primary key references public.users(id) on delete cascade,
  push_enabled boolean not null default true,
  friend_posts boolean not null default true,
  tags boolean not null default true,
  shared_mugshot_invitations boolean not null default true,
  collaborative_list_invitations boolean not null default true,
  likes boolean not null default true,
  comments boolean not null default true,
  reactions boolean not null default true,
  friend_requests boolean not null default true
);
create table public.visit_companions (
  visit_id uuid not null,
  companion_user_id uuid not null,
  added_by uuid not null
);
create table public.shared_memory_members (
  shared_memory_id uuid not null,
  user_id uuid not null,
  invited_by uuid,
  status text not null
);
create table public.comment_mentions (
  comment_id uuid not null,
  mentioned_user_id uuid not null
);
create table public.friend_requests (
  id uuid primary key,
  from_user_id uuid not null,
  to_user_id uuid not null,
  status text not null
);

create table public.activity_events (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.users(id) on delete cascade,
  actor_user_id uuid not null references public.users(id) on delete cascade,
  kind text not null,
  dedupe_key text not null check (char_length(dedupe_key) between 1 and 240),
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 280),
  visit_id uuid,
  comment_id uuid,
  shared_memory_id uuid,
  cafe_list_id uuid references public.cafe_lists(id) on delete cascade,
  friend_request_id uuid,
  deep_link text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  suppressed_at timestamptz,
  constraint activity_events_kind_check check (kind in (
    'friend_post', 'tag', 'shared_mugshot_invitation',
    'collaborative_list_invitation', 'like', 'comment',
    'comment_mention', 'reaction', 'friend_request',
    'friend_request_accepted'
  )),
  unique (recipient_id, dedupe_key),
  check (recipient_id <> actor_user_id)
);

create function private.blocked_between(p_first uuid, p_second uuid)
returns boolean language sql stable as $$
  select p_first is not null and p_second is not null and exists (
    select 1 from public.user_blocks block
    where (block.blocker_id = p_first and block.blocked_id = p_second)
       or (block.blocker_id = p_second and block.blocked_id = p_first)
  )
$$;
create function private.can_socially_mutate_as(p_actor uuid)
returns boolean language sql stable as $$
  select p_actor is not null
    and exists (select 1 from public.users profile where profile.id = p_actor)
    and not exists (
      select 1 from private.restricted_users restriction
      where restriction.user_id = p_actor and restriction.social_disabled
    )
$$;
create function private.can_view_user_as(p_subject uuid, p_viewer uuid)
returns boolean language sql stable as $$
  select p_subject is not null and p_viewer is not null
    and exists (select 1 from public.users profile where profile.id = p_subject)
    and exists (select 1 from public.users profile where profile.id = p_viewer)
    and not private.blocked_between(p_subject, p_viewer)
    and not exists (
      select 1 from private.restricted_users restriction
      where restriction.user_id = p_subject and restriction.hidden
    )
$$;
create function private.activity_recipient_is_eligible_v2(p_recipient uuid)
returns boolean language sql stable as $$
  select p_recipient is not null
    and exists (select 1 from public.users profile where profile.id = p_recipient)
    and not exists (
      select 1 from private.restricted_users restriction
      where restriction.user_id = p_recipient
        and restriction.recipient_disabled
    )
$$;
create function private.can_view_visit_as(uuid, uuid)
returns boolean language sql stable as $$ select false $$;
create function private.can_view_comment_as(uuid, uuid)
returns boolean language sql stable as $$ select false $$;
create function private.can_manage_cafe_list_as(p_list_id uuid, p_actor uuid)
returns boolean language sql stable as $$
  select private.can_socially_mutate_as(p_actor) and exists (
    select 1 from public.cafe_lists list
    where list.id = p_list_id
      and list.owner_id = p_actor
      and list.system_kind is null
  )
$$;
create function private.can_view_cafe_list_as(p_list_id uuid, p_actor uuid)
returns boolean language sql stable as $$
  select p_actor is not null and exists (
    select 1
    from public.cafe_lists list
    where list.id = p_list_id
      and not private.blocked_between(p_actor, list.owner_id)
      and (
        list.owner_id = p_actor
        or exists (
          select 1
          from public.cafe_list_members member
          where member.list_id = list.id
            and member.user_id = p_actor
            and member.invitation_status in ('pending', 'accepted')
        )
      )
  )
$$;
create function public.get_cafe_list_v2(p_list_id uuid)
returns jsonb language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'id', list.id,
    'owner_id', list.owner_id,
    'title', list.title
  )
  from public.cafe_lists list
  where list.id = p_list_id
$$;

create function public.respond_cafe_list_invitation_v2(
  p_list_id uuid,
  p_response text
)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid();
  target_status text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_response not in ('accept', 'decline') then
    raise exception 'invalid invitation response' using errcode = '22023';
  end if;
  target_status := case when p_response = 'accept' then 'accepted' else 'declined' end;
  update public.cafe_list_members
  set invitation_status = target_status,
      accepted_at = case when target_status = 'accepted' then now() else null end,
      responded_at = now(),
      updated_at = now()
  where list_id = p_list_id
    and user_id = actor
    and invitation_status = 'pending';
  if not found then
    raise exception 'invitation unavailable' using errcode = '42501';
  end if;
  return jsonb_build_object('list_id', p_list_id, 'status', target_status);
end
$$;
create function public.cancel_cafe_list_invitation_v2(
  p_list_id uuid,
  p_user_id uuid
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if not exists (
    select 1 from public.cafe_lists list
    where list.id = p_list_id and list.owner_id = actor
  ) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;
  update public.cafe_list_members
  set invitation_status = 'cancelled', responded_at = now(), updated_at = now()
  where list_id = p_list_id
    and user_id = p_user_id
    and invitation_status = 'pending';
  if not found then
    raise exception 'pending invitation unavailable' using errcode = '42501';
  end if;
  return true;
end
$$;
create function public.remove_cafe_list_member_v2(
  p_list_id uuid,
  p_user_id uuid
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if not exists (
    select 1 from public.cafe_lists list
    where list.id = p_list_id and list.owner_id = actor
  ) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;
  delete from public.cafe_list_members
  where list_id = p_list_id and user_id = p_user_id;
  return true;
end
$$;
create function public.leave_cafe_list_v2(p_list_id uuid)
returns boolean language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if exists (
    select 1 from public.cafe_lists list
    where list.id = p_list_id and list.owner_id = actor
  ) then
    raise exception 'transfer or delete this cafe list instead' using errcode = '42501';
  end if;
  delete from public.cafe_list_members
  where list_id = p_list_id
    and user_id = actor
    and invitation_status = 'accepted';
  return true;
end
$$;

-- This trigger exists before the lifecycle migration in production. It closes
-- pending invitations after an ownership transfer.
create function private.cancel_pending_cafe_list_invites_on_transfer_v3()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.owner_id is distinct from old.owner_id then
    update public.cafe_list_members member
    set invitation_status = 'cancelled',
        responded_at = now(),
        updated_at = now(),
        expires_at = null
    where member.list_id = new.id
      and member.invitation_status = 'pending';
  end if;
  return new;
end
$$;
create trigger cancel_pending_cafe_list_invites_on_transfer_v3
after update of owner_id on public.cafe_lists
for each row execute function private.cancel_pending_cafe_list_invites_on_transfer_v3();

-- The original invitation Activity row is ephemeral once the invitation is
-- answered or removed. Lifecycle events must survive that cleanup.
create function private.cleanup_activity_from_cafe_list_invitation_v1()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    delete from public.activity_events event
    where event.kind = 'collaborative_list_invitation'
      and event.recipient_id = old.user_id
      and event.actor_user_id = old.invited_by
      and event.cafe_list_id = old.list_id;
    return old;
  elsif old.invitation_status = 'pending'
        and new.invitation_status <> 'pending' then
    delete from public.activity_events event
    where event.kind = 'collaborative_list_invitation'
      and event.recipient_id = old.user_id
      and event.actor_user_id = old.invited_by
      and event.cafe_list_id = old.list_id;
  end if;
  return new;
end
$$;
create trigger cleanup_activity_from_cafe_list_invitation
after delete on public.cafe_list_members
for each row execute function private.cleanup_activity_from_cafe_list_invitation_v1();
create trigger cleanup_activity_from_cafe_list_invitation_status
after update of invitation_status on public.cafe_list_members
for each row execute function private.cleanup_activity_from_cafe_list_invitation_v1();
`

await db.exec(bootstrap)
const migration = await fs.readFile(
  repoPath +
    'supabase/migrations/20260722110000_alpha_collaborative_list_activity_lifecycle.sql',
  'utf8',
)
await db.exec(migration)

const ids = {
  owner: '10000000-0000-4000-8000-000000000001',
  accepted: '10000000-0000-4000-8000-000000000002',
  declined: '10000000-0000-4000-8000-000000000003',
  cancelled: '10000000-0000-4000-8000-000000000004',
  deletedPending: '10000000-0000-4000-8000-000000000005',
  roleMember: '10000000-0000-4000-8000-000000000006',
  removedMember: '10000000-0000-4000-8000-000000000007',
  leavingMember: '10000000-0000-4000-8000-000000000008',
  newOwner: '10000000-0000-4000-8000-000000000009',
  transferPending: '10000000-0000-4000-8000-000000000010',
  blockedPeer: '10000000-0000-4000-8000-000000000011',
  deletedMemberA: '10000000-0000-4000-8000-000000000012',
  deletedMemberB: '10000000-0000-4000-8000-000000000013',
  deletedListPending: '10000000-0000-4000-8000-000000000014',
  restrictedCandidate: '10000000-0000-4000-8000-000000000015',
  blockedMember: '10000000-0000-4000-8000-000000000016',
  legacyPending: '10000000-0000-4000-8000-000000000017',
}

const userValues = Object.entries(ids)
  .map(([name, id]) => `('${id}', '${name}', '${name}')`)
  .join(',')
await db.exec(`
  insert into public.users(id, display_name, username) values ${userValues};
  insert into public.notification_preferences(user_id)
  select id from public.users;
`)

const asUser = async (id, sql) => {
  await db.exec(
    `select set_config('request.jwt.claims', '{"sub":"${id}"}', false)`,
  )
  return db.query(sql)
}
const count = async (where) => {
  const result = await db.query(
    `select count(*)::integer count from public.activity_events where ${where}`,
  )
  return Number(result.rows[0].count)
}
const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}

// Core response, role, removal, and leave transitions each produce one durable
// lifecycle event and remain idempotent when a caller repeats settled state.
const lifecycleList = '20000000-0000-4000-8000-000000000001'
await db.exec(`
  insert into public.cafe_lists(id, owner_id, title)
  values ('${lifecycleList}', '${ids.owner}', 'Lifecycle plans');
  insert into public.cafe_list_members(
    list_id, user_id, role, invitation_status, invited_by, accepted_at
  ) values
    ('${lifecycleList}', '${ids.accepted}', 'viewer', 'pending', '${ids.owner}', null),
    ('${lifecycleList}', '${ids.declined}', 'viewer', 'pending', '${ids.owner}', null),
    ('${lifecycleList}', '${ids.cancelled}', 'viewer', 'pending', '${ids.owner}', null),
    ('${lifecycleList}', '${ids.deletedPending}', 'viewer', 'pending', '${ids.owner}', null),
    ('${lifecycleList}', '${ids.roleMember}', 'viewer', 'accepted', '${ids.owner}', now()),
    ('${lifecycleList}', '${ids.removedMember}', 'editor', 'accepted', '${ids.owner}', now()),
    ('${lifecycleList}', '${ids.leavingMember}', 'editor', 'accepted', '${ids.owner}', now());
`)

await asUser(
  ids.accepted,
  `update public.cafe_list_members
   set invitation_status='accepted', accepted_at=now(), responded_at=now(), updated_at=now()
   where list_id='${lifecycleList}' and user_id='${ids.accepted}'`,
)
await asUser(
  ids.accepted,
  `update public.cafe_list_members
   set invitation_status='accepted', updated_at=updated_at
   where list_id='${lifecycleList}' and user_id='${ids.accepted}'`,
)
assert(
  (await count(
    `kind='collaborative_list_invitation_accepted' and recipient_id='${ids.owner}' and actor_user_id='${ids.accepted}'`,
  )) === 1,
  'accepted invitation lifecycle was missing or duplicated',
)

await asUser(
  ids.declined,
  `update public.cafe_list_members
   set invitation_status='declined', responded_at=now(), updated_at=now()
   where list_id='${lifecycleList}' and user_id='${ids.declined}'`,
)
assert(
  (await count(
    `kind='collaborative_list_invitation_declined' and recipient_id='${ids.owner}' and actor_user_id='${ids.declined}'`,
  )) === 1,
  'declined invitation lifecycle was missing',
)

await asUser(
  ids.owner,
  `update public.cafe_list_members
   set invitation_status='cancelled', responded_at=now(), updated_at=now()
   where list_id='${lifecycleList}' and user_id='${ids.cancelled}'`,
)
await asUser(
  ids.owner,
  `delete from public.cafe_list_members
   where list_id='${lifecycleList}' and user_id='${ids.deletedPending}'`,
)
assert(
  (await count(
    `kind='collaborative_list_invitation_cancelled' and recipient_id in ('${ids.cancelled}','${ids.deletedPending}')`,
  )) === 2,
  'cancelled or directly removed pending invitation was not explained',
)

await db.exec(`
  insert into public.cafe_list_members(
    list_id, user_id, role, invitation_status, invited_by
  ) values (
    '${lifecycleList}', '${ids.legacyPending}', 'viewer',
    'pending', '${ids.owner}'
  );
  insert into public.activity_events(
    recipient_id, actor_user_id, kind, dedupe_key, title, body,
    cafe_list_id, deep_link
  ) values (
    '${ids.legacyPending}', '${ids.owner}',
    'collaborative_list_invitation', 'legacy-pending-invite',
    'Cafe list invitation', 'Plan cafes together.',
    '${lifecycleList}', 'mugshot://activity/lists'
  );
`)
await asUser(
  ids.legacyPending,
  `select public.revoke_cafe_list_member('${lifecycleList}', '${ids.legacyPending}')`,
)
const legacyPendingState = await db.query(`
  select invitation_status
  from public.cafe_list_members
  where list_id='${lifecycleList}' and user_id='${ids.legacyPending}'
`)
assert(
  legacyPendingState.rows[0]?.invitation_status === 'declined',
  'legacy pending self-removal deleted consent provenance instead of declining',
)
assert(
  (await count(
    `kind='collaborative_list_invitation_declined' and recipient_id='${ids.owner}' and actor_user_id='${ids.legacyPending}'`,
  )) === 1,
  'legacy pending self-removal did not notify the owner of the decline',
)
assert(
  (await count(
    `kind='collaborative_list_invitation' and recipient_id='${ids.legacyPending}'`,
  )) === 0,
  'legacy pending self-removal left an actionable invitation',
)

await asUser(
  ids.owner,
  `update public.cafe_list_members
   set role='editor', updated_at=now()
   where list_id='${lifecycleList}' and user_id='${ids.roleMember}'`,
)
await asUser(
  ids.owner,
  `update public.cafe_list_members
   set role='editor', updated_at=updated_at
   where list_id='${lifecycleList}' and user_id='${ids.roleMember}'`,
)
assert(
  (await count(
    `kind='collaborative_list_role_changed' and recipient_id='${ids.roleMember}'`,
  )) === 1,
  'role-change lifecycle was missing or duplicated',
)

await asUser(
  ids.owner,
  `delete from public.cafe_list_members
   where list_id='${lifecycleList}' and user_id='${ids.removedMember}'`,
)
await asUser(
  ids.leavingMember,
  `delete from public.cafe_list_members
   where list_id='${lifecycleList}' and user_id='${ids.leavingMember}'`,
)
assert(
  (await count(
    `kind='collaborative_list_member_removed' and recipient_id='${ids.removedMember}'`,
  )) === 1,
  'owner removal lifecycle was missing',
)
assert(
  (await count(
    `kind='collaborative_list_member_left' and recipient_id='${ids.owner}' and actor_user_id='${ids.leavingMember}'`,
  )) === 1,
  'member departure lifecycle was missing',
)

// Ownership transfer must notify both owners, cancel the old owner's pending
// invitations, avoid false removal notices, and preserve the old owner as an
// editor. A retry by the former owner must not duplicate Activity.
const transferList = '20000000-0000-4000-8000-000000000002'
await db.exec(`
  insert into public.cafe_lists(id, owner_id, title)
  values ('${transferList}', '${ids.owner}', 'Transfer plans');
  insert into public.cafe_list_members(
    list_id, user_id, role, invitation_status, invited_by, accepted_at, expires_at
  ) values
    ('${transferList}', '${ids.newOwner}', 'editor', 'accepted', '${ids.owner}', now(), null),
    ('${transferList}', '${ids.transferPending}', 'viewer', 'pending', '${ids.owner}', null, now() + interval '7 days'),
    ('${transferList}', '${ids.blockedPeer}', 'viewer', 'accepted', '${ids.owner}', now(), null);
  insert into public.activity_events(
    recipient_id, actor_user_id, kind, dedupe_key, title, body,
    cafe_list_id, deep_link
  ) values (
    '${ids.transferPending}', '${ids.owner}',
    'collaborative_list_invitation', 'original-transfer-invite',
    'Cafe list invitation', 'Plan cafes together.',
    '${transferList}', 'mugshot://activity/lists'
  );
  insert into public.user_blocks(blocker_id, blocked_id)
  values ('${ids.newOwner}', '${ids.blockedPeer}');
`)

await asUser(
  ids.owner,
  `select public.transfer_cafe_list_ownership_v2('${transferList}', '${ids.newOwner}') payload`,
)
const transferState = await db.query(`
  select
    (select owner_id from public.cafe_lists where id='${transferList}') owner_id,
    exists(
      select 1 from public.cafe_list_members
      where list_id='${transferList}' and user_id='${ids.newOwner}'
    ) new_owner_still_member,
    exists(
      select 1 from public.cafe_list_members
      where list_id='${transferList}' and user_id='${ids.owner}'
        and role='editor' and invitation_status='accepted'
    ) former_owner_is_editor,
    (select invitation_status from public.cafe_list_members
      where list_id='${transferList}' and user_id='${ids.transferPending}') pending_status,
    exists(
      select 1 from public.cafe_list_members
      where list_id='${transferList}' and user_id='${ids.blockedPeer}'
    ) blocked_peer_remains
`)
const transferRow = transferState.rows[0]
assert(transferRow.owner_id === ids.newOwner, 'ownership did not transfer')
assert(!transferRow.new_owner_still_member, 'new owner retained a duplicate membership')
assert(transferRow.former_owner_is_editor, 'former owner was not retained as editor')
assert(transferRow.pending_status === 'cancelled', 'pending invitation survived transfer')
assert(!transferRow.blocked_peer_remains, 'blocked peer survived new ownership')
assert(
  (await count(
    `kind='collaborative_list_ownership_transferred' and cafe_list_id='${transferList}'`,
  )) === 2,
  'ownership transfer did not produce exactly two directional events',
)
assert(
  (await count(
    `kind='collaborative_list_invitation_cancelled' and recipient_id='${ids.transferPending}' and actor_user_id='${ids.owner}'`,
  )) === 1,
  'ownership transfer silently cancelled a pending invitation',
)
assert(
  (await count(
    `kind='collaborative_list_invitation' and cafe_list_id='${transferList}'`,
  )) === 0,
  'settled transfer invitation remained actionable',
)
assert(
  (await count(
    `kind='collaborative_list_member_removed' and cafe_list_id='${transferList}'`,
  )) === 0,
  'transfer cleanup was misclassified as owner removal',
)

// A committed response can be lost. The immediately previous owner may retry
// the exact A-to-B transition, but an ownership cycle must advance the epoch
// and invalidate the older receipt instead of suppressing a new transfer.
const retryList = '20000000-0000-4000-8000-000000000006'
await db.exec(`
  insert into public.cafe_lists(id, owner_id, title)
  values ('${retryList}', '${ids.owner}', 'Retry-safe transfer');
  insert into public.cafe_list_members(
    list_id, user_id, role, invitation_status, invited_by, accepted_at
  ) values (
    '${retryList}', '${ids.newOwner}', 'editor',
    'accepted', '${ids.owner}', now()
  );
`)
await asUser(
  ids.owner,
  `select public.transfer_cafe_list_ownership_v2('${retryList}', '${ids.newOwner}') payload`,
)
const firstTransferReceipt = await db.query(`
  select
    list.owner_id,
    list.ownership_epoch,
    receipt.previous_owner_id,
    receipt.new_owner_id
  from public.cafe_lists list
  join private.cafe_list_ownership_transfer_receipts receipt
    on receipt.list_id=list.id
   and receipt.ownership_epoch=list.ownership_epoch
  where list.id='${retryList}'
`)
assert(
  firstTransferReceipt.rows[0]?.owner_id === ids.newOwner &&
    Number(firstTransferReceipt.rows[0]?.ownership_epoch) === 1 &&
    firstTransferReceipt.rows[0]?.previous_owner_id === ids.owner &&
    firstTransferReceipt.rows[0]?.new_owner_id === ids.newOwner,
  'ownership transition did not persist its exact epoch receipt',
)
await asUser(
  ids.owner,
  `select public.transfer_cafe_list_ownership_v2('${retryList}', '${ids.newOwner}') payload`,
)
assert(
  (await count(
    `kind='collaborative_list_ownership_transferred' and cafe_list_id='${retryList}'`,
  )) === 2,
  'ambiguous-response retry duplicated ownership Activity',
)

await asUser(
  ids.newOwner,
  `select public.transfer_cafe_list_ownership_v2('${retryList}', '${ids.owner}') payload`,
)
await asUser(
  ids.owner,
  `select public.transfer_cafe_list_ownership_v2('${retryList}', '${ids.newOwner}') payload`,
)
const cycledTransfer = await db.query(`
  select
    list.owner_id,
    list.ownership_epoch,
    count(receipt.*)::integer receipt_count,
    min(receipt.previous_owner_id::text) previous_owner_id,
    min(receipt.new_owner_id::text) new_owner_id
  from public.cafe_lists list
  left join private.cafe_list_ownership_transfer_receipts receipt
    on receipt.list_id=list.id
  where list.id='${retryList}'
  group by list.id
`)
assert(
  cycledTransfer.rows[0]?.owner_id === ids.newOwner &&
    Number(cycledTransfer.rows[0]?.ownership_epoch) === 3 &&
    Number(cycledTransfer.rows[0]?.receipt_count) === 1 &&
    cycledTransfer.rows[0]?.previous_owner_id === ids.owner &&
    cycledTransfer.rows[0]?.new_owner_id === ids.newOwner,
  'ownership cycle reused a stale receipt or retained obsolete generations',
)
assert(
  (await count(
    `kind='collaborative_list_ownership_transferred' and cafe_list_id='${retryList}'`,
  )) === 6,
  'a legitimate later ownership cycle was incorrectly deduplicated',
)

try {
  await asUser(
    ids.owner,
    `select public.transfer_cafe_list_ownership_v2('${transferList}', '${ids.blockedPeer}')`,
  )
  throw new Error('former owner retried a completed transfer')
} catch (error) {
  if (String(error).includes('former owner retried')) throw error
}
assert(
  (await count(
    `kind='collaborative_list_ownership_transferred' and cafe_list_id='${transferList}'`,
  )) === 2,
  'failed transfer retry duplicated Activity',
)

// The RPC rejects an accepted collaborator who became socially unavailable
// after acceptance, before changing ownership or creating Activity.
const restrictedList = '20000000-0000-4000-8000-000000000003'
await db.exec(`
  insert into public.cafe_lists(id, owner_id, title)
  values ('${restrictedList}', '${ids.owner}', 'Restricted transfer');
  insert into public.cafe_list_members(
    list_id, user_id, role, invitation_status, invited_by, accepted_at
  ) values (
    '${restrictedList}', '${ids.restrictedCandidate}', 'editor',
    'accepted', '${ids.owner}', now()
  );
  insert into private.restricted_users(user_id, social_disabled)
  values ('${ids.restrictedCandidate}', true);
`)
try {
  await asUser(
    ids.owner,
    `select public.transfer_cafe_list_ownership_v2('${restrictedList}', '${ids.restrictedCandidate}')`,
  )
  throw new Error('ownership transferred to a restricted collaborator')
} catch (error) {
  if (String(error).includes('ownership transferred')) throw error
}
assert(
  (await count(
    `kind='collaborative_list_ownership_transferred' and cafe_list_id='${restrictedList}'`,
  )) === 0,
  'rejected transfer created Activity',
)

// Deletion emits one durable, list-detached event per accepted collaborator.
// Pending invitees are not told they collaborated, and list-bound history is
// removed by the existing foreign-key cascade.
const deletedList = '20000000-0000-4000-8000-000000000004'
await db.exec(`
  insert into public.cafe_lists(id, owner_id, title)
  values ('${deletedList}', '${ids.owner}', 'Delete after the trip');
  insert into public.cafe_list_members(
    list_id, user_id, role, invitation_status, invited_by, accepted_at
  ) values
    ('${deletedList}', '${ids.deletedMemberA}', 'editor', 'accepted', '${ids.owner}', now()),
    ('${deletedList}', '${ids.deletedMemberB}', 'viewer', 'accepted', '${ids.owner}', now()),
    ('${deletedList}', '${ids.deletedListPending}', 'viewer', 'pending', '${ids.owner}', null);
  insert into public.activity_events(
    recipient_id, actor_user_id, kind, dedupe_key, title, body,
    cafe_list_id, deep_link, metadata
  ) values (
    '${ids.deletedMemberA}', '${ids.owner}',
    'collaborative_list_role_changed', 'delete-cascade-fixture',
    'Role changed', 'Fixture', '${deletedList}',
    'mugshot://activity/lists', '{"source":"cafe_list_lifecycle"}'
  ), (
    '${ids.deletedListPending}', '${ids.owner}',
    'collaborative_list_invitation', 'delete-pending-invite-fixture',
    'Cafe list invitation', 'Plan cafes together.', '${deletedList}',
    'mugshot://activity/lists', '{}'
  );
`)
await asUser(ids.owner, `delete from public.cafe_lists where id='${deletedList}'`)
await asUser(ids.owner, `delete from public.cafe_lists where id='${deletedList}'`)
const deletedEvents = await db.query(`
  select recipient_id, cafe_list_id, metadata
  from public.activity_events
  where kind='collaborative_list_deleted'
    and metadata->>'list_id'='${deletedList}'
  order by recipient_id
`)
assert(deletedEvents.rows.length === 2, 'list deletion events were missing or duplicated')
assert(
  deletedEvents.rows.every(
    (event) =>
      event.cafe_list_id === null &&
      event.metadata.list_title === 'Delete after the trip' &&
      event.metadata.source === 'cafe_list_lifecycle',
  ),
  'deleted-list Activity retained a dangling list reference or lost safe context',
)
assert(
  !deletedEvents.rows.some(
    (event) => event.recipient_id === ids.deletedListPending,
  ),
  'pending invitee received an accepted-collaborator deletion event',
)
const deletedPendingEvent = await db.query(`
  select recipient_id, cafe_list_id, body, metadata,
    private.activity_event_is_visible(event, recipient_id) visible
  from public.activity_events event
  where kind='collaborative_list_invitation_cancelled'
    and recipient_id='${ids.deletedListPending}'
    and metadata->>'list_id'='${deletedList}'
`)
assert(
  deletedPendingEvent.rows.length === 1 &&
    deletedPendingEvent.rows[0].cafe_list_id === null &&
    deletedPendingEvent.rows[0].metadata.reason === 'list_deleted' &&
    deletedPendingEvent.rows[0].metadata.list_title === 'Delete after the trip' &&
    deletedPendingEvent.rows[0].body.includes('list was deleted') &&
    deletedPendingEvent.rows[0].visible === true,
  'pending invitee did not receive a safe detached list-deletion notice',
)
assert(
  (await count(`cafe_list_id='${deletedList}'`)) === 0,
  'list-bound Activity survived list deletion',
)

// A block suppresses new lifecycle Activity and makes existing pairwise events
// unreadable through the caller-bound visibility predicate.
const blockedList = '20000000-0000-4000-8000-000000000005'
await db.exec(`
  insert into public.cafe_lists(id, owner_id, title)
  values ('${blockedList}', '${ids.owner}', 'Blocked cleanup');
  insert into public.cafe_list_members(
    list_id, user_id, role, invitation_status, invited_by, accepted_at
  ) values (
    '${blockedList}', '${ids.blockedMember}', 'viewer',
    'accepted', '${ids.owner}', now()
  );
  insert into public.user_blocks(blocker_id, blocked_id)
  values ('${ids.owner}', '${ids.blockedMember}');
`)
await asUser(
  ids.owner,
  `delete from public.cafe_list_members
   where list_id='${blockedList}' and user_id='${ids.blockedMember}'`,
)
assert(
  (await count(
    `kind='collaborative_list_member_removed' and recipient_id='${ids.blockedMember}'`,
  )) === 0,
  'block cleanup leaked a lifecycle event across the block',
)

await db.exec(`
  insert into public.user_blocks(blocker_id, blocked_id)
  values ('${ids.owner}', '${ids.newOwner}');
`)
const transferVisibility = await db.query(`
  select private.activity_event_is_visible(event, event.recipient_id) visible
  from public.activity_events event
  where event.kind='collaborative_list_ownership_transferred'
    and event.cafe_list_id='${transferList}'
    and event.recipient_id='${ids.newOwner}'
`)
assert(
  transferVisibility.rows[0]?.visible === false,
  'blocked ownership Activity remained visible',
)

await db.exec(`
  update public.notification_preferences
  set collaborative_list_invitations=false
  where user_id='${ids.owner}';
`)
const pushPreference = await db.query(`
  select
    private.activity_kind_push_enabled(
      '${ids.owner}', 'collaborative_list_member_left'
    ) disabled,
    private.activity_kind_push_enabled(
      '${ids.accepted}', 'collaborative_list_member_left'
    ) enabled
`)
assert(
  pushPreference.rows[0].disabled === false &&
    pushPreference.rows[0].enabled === true,
  'collaborative lifecycle push preference mapping was incorrect',
)

const grants = await db.query(`
  select
    has_function_privilege(
      'authenticated',
      'public.transfer_cafe_list_ownership_v2(uuid,uuid)',
      'execute'
    ) authenticated_transfer,
    has_function_privilege(
      'anon',
      'public.transfer_cafe_list_ownership_v2(uuid,uuid)',
      'execute'
    ) anon_transfer,
    has_function_privilege(
      'authenticated',
      'public.revoke_cafe_list_member(uuid,uuid)',
      'execute'
    ) authenticated_legacy_revoke,
    has_function_privilege(
      'anon',
      'public.revoke_cafe_list_member(uuid,uuid)',
      'execute'
    ) anon_legacy_revoke,
    has_function_privilege(
      'authenticated',
      'private.create_cafe_list_lifecycle_activity_v1(uuid,uuid,text,text,text,text,uuid,text,jsonb)',
      'execute'
    ) authenticated_private_helper
`)
assert(grants.rows[0].authenticated_transfer, 'authenticated transfer grant is missing')
assert(!grants.rows[0].anon_transfer, 'anonymous transfer execution remains granted')
assert(
  grants.rows[0].authenticated_legacy_revoke,
  'authenticated legacy revoke compatibility grant is missing',
)
assert(
  !grants.rows[0].anon_legacy_revoke,
  'anonymous legacy revoke execution remains granted',
)
assert(
  !grants.rows[0].authenticated_private_helper,
  'client can execute the private lifecycle event helper',
)

const securityContract = await fs.readFile(
  repoPath +
    'supabase/tests/alpha_collaborative_list_activity_lifecycle_security.sql',
  'utf8',
)
await db.exec(securityContract)

console.log(
  'PGlite collaborative-list lifecycle, transfer, deletion, privacy, idempotency, and grant checks passed',
)
