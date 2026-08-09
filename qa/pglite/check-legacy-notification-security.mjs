import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const repoPath = fileURLToPath(new URL('../../', import.meta.url))

await db.exec(String.raw`
create role anon;
create role authenticated;
create role service_role;
create schema auth;
create table auth.users (id uuid primary key);
create function auth.uid() returns uuid language sql stable as $$
  select nullif((current_setting('request.jwt.claims', true)::jsonb)->>'sub', '')::uuid
$$;

create table public.users (
  id uuid primary key references auth.users(id),
  username text not null unique
);
create table public.user_blocks (
  blocker_id uuid not null references public.users(id),
  blocked_id uuid not null references public.users(id),
  primary key (blocker_id, blocked_id)
);
create table public.visits (
  id uuid primary key,
  user_id uuid not null references public.users(id)
);
create table public.likes (
  user_id uuid not null references public.users(id),
  visit_id uuid not null references public.visits(id),
  primary key (user_id, visit_id)
);
create table public.comments (
  id uuid primary key,
  user_id uuid not null references public.users(id),
  visit_id uuid not null references public.visits(id),
  text text not null,
  parent_comment_id uuid references public.comments(id)
);
create table public.comment_mentions (
  comment_id uuid not null references public.comments(id),
  mentioned_user_id uuid not null references public.users(id),
  primary key (comment_id, mentioned_user_id)
);
create table public.friend_requests (
  id uuid primary key,
  from_user_id uuid not null references public.users(id),
  to_user_id uuid not null references public.users(id),
  status text not null
);
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  actor_user_id uuid not null references public.users(id),
  type text not null check (type in (
    'like', 'comment', 'reply', 'mention', 'follow', 'friend_request',
    'friend_request_accepted', 'new_visit_from_friend'
  )),
  visit_id uuid references public.visits(id),
  comment_id uuid references public.comments(id),
  created_at timestamptz not null default now(),
  read_at timestamptz
);

create function public.is_blocked_between(p_first uuid, p_second uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.user_blocks block
    where (block.blocker_id = p_first and block.blocked_id = p_second)
       or (block.blocker_id = p_second and block.blocked_id = p_first)
  )
$$;
create function public.can_view_visit(p_visit_id uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.visits where id = p_visit_id)
$$;

alter table public.notifications enable row level security;
grant usage on schema auth to authenticated;
grant execute on function auth.uid() to authenticated;
grant execute on function public.is_blocked_between(uuid, uuid) to authenticated;
grant execute on function public.can_view_visit(uuid, uuid) to authenticated;
grant select on public.users, public.user_blocks, public.visits, public.likes,
  public.comments, public.comment_mentions, public.friend_requests to authenticated;
grant all on public.notifications to anon, authenticated;
`)

const migration = await fs.readFile(
  repoPath + 'supabase/migrations/20260809022000_harden_legacy_notification_inserts.sql',
  'utf8',
)
await db.exec(migration)

const ids = {
  actor: 'a1000000-0000-4000-8000-000000000001',
  owner: 'a1000000-0000-4000-8000-000000000002',
  other: 'a1000000-0000-4000-8000-000000000003',
}
const visitID = 'a2000000-0000-4000-8000-000000000001'
const commentID = 'a3000000-0000-4000-8000-000000000001'
const parentID = 'a3000000-0000-4000-8000-000000000002'
const replyID = 'a3000000-0000-4000-8000-000000000003'
const requestID = 'a4000000-0000-4000-8000-000000000001'

await db.exec(`
insert into auth.users(id) values ('${ids.actor}'), ('${ids.owner}'), ('${ids.other}');
insert into public.users(id, username) values
  ('${ids.actor}', 'actor'), ('${ids.owner}', 'owner'), ('${ids.other}', 'other');
insert into public.visits(id, user_id) values ('${visitID}', '${ids.owner}');
insert into public.likes(user_id, visit_id) values ('${ids.actor}', '${visitID}');
insert into public.comments(id, user_id, visit_id, text) values
  ('${commentID}', '${ids.actor}', '${visitID}', 'Hello @[Alpha owner]'),
  ('${parentID}', '${ids.other}', '${visitID}', 'Parent');
insert into public.comments(id, user_id, visit_id, text, parent_comment_id) values
  ('${replyID}', '${ids.actor}', '${visitID}', 'Reply', '${parentID}');
insert into public.friend_requests(id, from_user_id, to_user_id, status) values
  ('${requestID}', '${ids.owner}', '${ids.actor}', 'accepted');
`)

const asRole = async (role, id, sql) => {
  await db.exec(`
    reset role;
    select set_config('request.jwt.claims', '{"sub":"${id ?? ''}"}', false);
    set role ${role};
  `)
  try {
    return await db.query(sql)
  } finally {
    await db.exec('reset role')
  }
}

const expectDenied = async (role, id, sql, label) => {
  try {
    await asRole(role, id, sql)
  } catch (error) {
    if (/row-level security|permission denied/i.test(String(error))) return
    throw error
  }
  throw new Error(`${label} was accepted`)
}

await asRole('authenticated', ids.actor, `
  insert into public.notifications(user_id, actor_user_id, type, visit_id)
  values ('${ids.owner}', '${ids.actor}', 'like', '${visitID}')
`)
await expectDenied('authenticated', ids.actor, `
  insert into public.notifications(user_id, actor_user_id, type, visit_id)
  values ('${ids.other}', '${ids.actor}', 'like', '${visitID}')
`, 'spoofed like recipient')
await expectDenied('authenticated', ids.other, `
  insert into public.notifications(user_id, actor_user_id, type, visit_id)
  values ('${ids.owner}', '${ids.actor}', 'like', '${visitID}')
`, 'spoofed actor')
await expectDenied('authenticated', ids.actor, `
  insert into public.notifications(user_id, actor_user_id, type)
  values ('${ids.owner}', '${ids.actor}', 'follow')
`, 'unbacked notification type')

await asRole('authenticated', ids.actor, `
  insert into public.notifications(user_id, actor_user_id, type, visit_id, comment_id)
  values ('${ids.owner}', '${ids.actor}', 'comment', '${visitID}', '${commentID}')
`)
await asRole('authenticated', ids.actor, `
  insert into public.notifications(user_id, actor_user_id, type, visit_id, comment_id)
  values ('${ids.other}', '${ids.actor}', 'reply', '${visitID}', '${replyID}')
`)
await asRole('authenticated', ids.actor, `
  insert into public.notifications(user_id, actor_user_id, type, visit_id, comment_id)
  values ('${ids.owner}', '${ids.actor}', 'mention', '${visitID}', '${commentID}')
`)
await expectDenied('authenticated', ids.actor, `
  insert into public.notifications(user_id, actor_user_id, type, visit_id, comment_id)
  values ('${ids.other}', '${ids.actor}', 'mention', '${visitID}', '${commentID}')
`, 'unbacked mention recipient')

await asRole('authenticated', ids.actor, `
  insert into public.notifications(user_id, actor_user_id, type)
  values ('${ids.owner}', '${ids.actor}', 'friend_accept')
`)

const notification = await db.query(`
  select id from public.notifications
  where user_id = '${ids.owner}' and actor_user_id = '${ids.actor}' and type = 'like'
  limit 1
`)
const notificationID = notification.rows[0]?.id
if (!notificationID) throw new Error('valid legacy notification was not stored')

await asRole('authenticated', ids.owner, `
  update public.notifications set read_at = now() where id = '${notificationID}'
`)
await expectDenied('authenticated', ids.owner, `
  update public.notifications set type = 'follow' where id = '${notificationID}'
`, 'recipient content mutation')
await expectDenied('anon', null, `
  select * from public.notifications
`, 'anonymous notification read')

await db.exec(`
  insert into public.user_blocks(blocker_id, blocked_id)
  values ('${ids.owner}', '${ids.actor}')
`)
await expectDenied('authenticated', ids.actor, `
  insert into public.notifications(user_id, actor_user_id, type, visit_id)
  values ('${ids.owner}', '${ids.actor}', 'like', '${visitID}')
`, 'blocked-pair notification')

console.log('PGlite legacy notification actor, recipient, reference, and grant checks passed')
await db.close()
