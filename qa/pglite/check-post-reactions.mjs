import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const repoPath = fileURLToPath(new URL('../../', import.meta.url))
const migrationPath = new URL(
  '../../supabase/migrations/20260825030917_post_reactions.sql',
  import.meta.url,
)
const ownerID = '10000000-0000-4000-8000-000000000001'
const actorID = '10000000-0000-4000-8000-000000000002'
const visitID = '20000000-0000-4000-8000-000000000001'
const privateVisitID = '20000000-0000-4000-8000-000000000002'

const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}

await db.exec(String.raw`
create role anon;
create role authenticated;
create schema auth;
create schema private;

create function auth.uid() returns uuid language sql stable as $$
  select nullif(
    (current_setting('request.jwt.claims', true)::jsonb)->>'sub',
    ''
  )::uuid
$$;

create table public.users (
  id uuid primary key,
  username text not null
);
create table public.user_blocks (
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  primary key (blocker_id, blocked_id)
);
create table public.visits (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  visibility text not null,
  upload_state text not null
);
create table public.likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  visit_id uuid not null references public.visits(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, visit_id)
);
create table public.activity_events (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.users(id) on delete cascade,
  actor_user_id uuid not null references public.users(id) on delete cascade,
  kind text not null,
  dedupe_key text not null,
  title text not null,
  body text not null,
  visit_id uuid references public.visits(id) on delete cascade,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (recipient_id, dedupe_key)
);
grant select on public.likes, public.activity_events to authenticated;

create function public.can_socially_mutate(p_actor uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_actor = (select auth.uid())
    and exists (select 1 from public.users profile where profile.id = p_actor)
$$;
create function public.can_view_user(p_subject uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_viewer = (select auth.uid())
    and exists (select 1 from public.users profile where profile.id = p_subject)
    and not exists (
      select 1 from public.user_blocks block
      where (block.blocker_id = p_subject and block.blocked_id = p_viewer)
         or (block.blocker_id = p_viewer and block.blocked_id = p_subject)
    )
$$;
create function public.can_view_visit(p_visit_id uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_viewer = (select auth.uid()) and exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and visit.upload_state = 'complete'
      and (visit.user_id = p_viewer or visit.visibility = 'everyone')
      and not exists (
        select 1 from public.user_blocks block
        where (block.blocker_id = visit.user_id and block.blocked_id = p_viewer)
           or (block.blocker_id = p_viewer and block.blocked_id = visit.user_id)
      )
  )
$$;

create function private.create_activity_event_v1(
  p_recipient uuid,
  p_actor uuid,
  p_kind text,
  p_dedupe_key text,
  p_title text,
  p_body text,
  p_visit_id uuid default null,
  p_comment_id uuid default null,
  p_shared_memory_id uuid default null,
  p_cafe_list_id uuid default null,
  p_friend_request_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare created_id uuid;
begin
  if p_recipient is null or p_recipient = p_actor then return null; end if;
  insert into public.activity_events (
    recipient_id, actor_user_id, kind, dedupe_key, title, body,
    visit_id, metadata
  ) values (
    p_recipient, p_actor, p_kind, p_dedupe_key, p_title, p_body,
    p_visit_id, p_metadata
  )
  on conflict (recipient_id, dedupe_key) do nothing
  returning id into created_id;
  return created_id;
end
$$;

insert into public.users (id, username) values
  ('${ownerID}', 'owner'),
  ('${actorID}', 'actor');
insert into public.visits (id, user_id, visibility, upload_state) values
  ('${visitID}', '${ownerID}', 'everyone', 'complete'),
  ('${privateVisitID}', '${ownerID}', 'private', 'complete');

-- This row predates the additive column and must decode as a legacy Like.
insert into public.likes (user_id, visit_id) values ('${actorID}', '${visitID}');
`)

await db.exec(await fs.readFile(migrationPath, 'utf8'))

const setActor = async () => {
  await db.exec(String.raw`
    set role authenticated;
    select set_config(
      'request.jwt.claims',
      '{"sub":"${actorID}","role":"authenticated"}',
      false
    );
  `)
}

await setActor()
const legacy = await db.query(String.raw`
  select reaction_kind from public.likes
  where user_id = '${actorID}' and visit_id = '${visitID}'
`)
assert(legacy.rows[0]?.reaction_kind === 'like', 'legacy like did not default to Like')

const loved = await db.query(String.raw`
  select * from public.set_visit_reaction_v1('${visitID}', 'love')
`)
assert(loved.rows[0]?.viewer_reaction === 'love', 'Love was not selected')
assert(Number(loved.rows[0]?.love_count) === 1, 'Love count was not returned')
assert(Number(loved.rows[0]?.total_count) === 1, 'reaction total drifted during change')

const laughed = await db.query(String.raw`
  select * from public.set_visit_reaction_v1('${visitID}', 'laugh')
`)
assert(laughed.rows[0]?.viewer_reaction === 'laugh', 'reaction was not changed')
assert(Number(laughed.rows[0]?.laugh_count) === 1, 'Laugh count was not returned')

const rowCount = await db.query(String.raw`
  select count(*)::integer count from public.likes
  where user_id = '${actorID}' and visit_id = '${visitID}'
`)
assert(rowCount.rows[0]?.count === 1, 'more than one caller reaction row exists')

const activity = await db.query(String.raw`
  select count(*)::integer count, max(metadata->>'reaction_kind') reaction_kind
  from public.activity_events
  where actor_user_id = '${actorID}' and visit_id = '${visitID}' and kind = 'like'
`)
assert(activity.rows[0]?.count === 1, 'reaction change duplicated activity')
assert(activity.rows[0]?.reaction_kind === 'laugh', 'activity did not track reaction change')

await Promise.all(
  Array.from({ length: 12 }, (_, index) => db.query(String.raw`
    select * from public.set_visit_reaction_v1(
      '${visitID}',
      '${index % 2 === 0 ? 'love' : 'yummy'}'
    )
  `)),
)
const concurrentRows = await db.query(String.raw`
  select count(*)::integer count from public.likes
  where user_id = '${actorID}' and visit_id = '${visitID}'
`)
assert(concurrentRows.rows[0]?.count === 1, 'concurrent upserts created duplicate reactions')

const removed = await db.query(String.raw`
  select * from public.set_visit_reaction_v1('${visitID}', null)
`)
assert(removed.rows[0]?.viewer_reaction == null, 'nullable reaction did not remove selection')
assert(Number(removed.rows[0]?.total_count) === 0, 'remove did not update total count')
const activityAfterRemoval = await db.query(String.raw`
  select count(*)::integer count from public.activity_events
  where actor_user_id = '${actorID}' and visit_id = '${visitID}' and kind = 'like'
`)
assert(activityAfterRemoval.rows[0]?.count === 0, 'remove preserved reaction activity')

let invalidRejected = false
try {
  await db.query(String.raw`
    select * from public.set_visit_reaction_v1('${visitID}', 'surprised')
  `)
} catch (error) {
  invalidRejected = error?.code === '22023'
}
assert(invalidRejected, 'invalid reaction kind was accepted')

let privateRejected = false
try {
  await db.query(String.raw`
    select * from public.set_visit_reaction_v1('${privateVisitID}', 'like')
  `)
} catch (error) {
  privateRejected = error?.code === '42501'
}
assert(privateRejected, 'private visit reaction was accepted')

await db.exec(String.raw`
  reset role;
  insert into public.user_blocks (blocker_id, blocked_id)
  values ('${ownerID}', '${actorID}');
`)
await setActor()
let blockedRejected = false
try {
  await db.query(String.raw`
    select * from public.set_visit_reaction_v1('${visitID}', 'like')
  `)
} catch (error) {
  blockedRejected = error?.code === '42501'
}
assert(blockedRejected, 'blocked actor reaction was accepted')

console.log(`post reactions hermetic checks passed (${repoPath})`)
