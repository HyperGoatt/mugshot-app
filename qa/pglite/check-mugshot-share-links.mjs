import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const repoPath = fileURLToPath(new URL('../../', import.meta.url))
const ownerID = '10000000-0000-4000-8000-000000000001'
const otherID = '10000000-0000-4000-8000-000000000002'
const visitID = '20000000-0000-4000-8000-000000000001'
const cafeID = '30000000-0000-4000-8000-000000000001'

const assert = (condition, message) => {
  if (!condition) throw new Error(message)
}

await db.exec(String.raw`
create role anon;
create role authenticated;
create schema auth;
create schema private;
create schema extensions;
create function extensions.gen_random_bytes(byte_count integer)
returns bytea language sql volatile as $$
  select decode(
    substr(md5(random()::text) || md5(clock_timestamp()::text), 1, byte_count * 2),
    'hex'
  )
$$;

create function auth.uid() returns uuid language sql stable as $$
  select nullif((current_setting('request.jwt.claims', true)::jsonb)->>'sub', '')::uuid
$$;

create type public.report_reason as enum ('spam');

create table public.users (
  id uuid primary key,
  display_name text,
  username text not null,
  avatar_url text
);
create table public.cafes (
  id uuid primary key,
  name text not null
);
create table public.visits (
  id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  cafe_id uuid references public.cafes(id) on delete set null,
  drink_type text,
  drink_type_custom text,
  drink_subtype text,
  caption text not null default '',
  visibility text not null,
  upload_state text not null,
  overall_score double precision not null,
  ratings jsonb not null default '{}'::jsonb,
  poster_photo_url text,
  context_type text,
  created_at timestamptz not null default now()
);
create table public.visit_photos (
  id uuid primary key,
  visit_id uuid not null references public.visits(id) on delete cascade,
  photo_url text not null,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create table private.suppressed_visits (
  visit_id uuid primary key
);

create function private.is_public_visit_discoverable_v3(p_visit_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.visits visit
    join public.users owner on owner.id = visit.user_id
    where visit.id = p_visit_id
      and visit.visibility = 'everyone'
      and visit.upload_state = 'complete'
      and not exists (
        select 1 from private.suppressed_visits suppression
        where suppression.visit_id = visit.id
      )
  )
$$;

create function private.is_live_account_as(p_user_id uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.users where id = p_user_id)
$$;

create function private.has_active_moderation_action(
  p_subject_kind text,
  p_subject_id uuid,
  p_action_kinds text[],
  p_at timestamptz default now()
)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_subject_kind = 'visit'
    and 'content_hidden' = any(p_action_kinds)
    and exists (
      select 1 from private.suppressed_visits
      where visit_id = p_subject_id
    )
$$;

insert into public.users (id, display_name, username, avatar_url) values
  ('${ownerID}', 'Journal Owner', 'owner', 'https://example.com/avatar.jpg'),
  ('${otherID}', 'Other Person', 'other', null);
insert into public.cafes (id, name) values
  ('${cafeID}', 'Public Test Cafe');
insert into public.visits (
  id, user_id, cafe_id, drink_type, drink_subtype, caption, visibility,
  upload_state, overall_score, ratings, poster_photo_url, context_type
) values (
  '${visitID}', '${ownerID}', '${cafeID}', 'Coffee', 'Cortado',
  'A bright finish', 'friends', 'complete', 4.5, '{"Body":4,"Sweetness":3.5}',
  'https://example.com/cover.jpg', 'cafe'
);
insert into public.visit_photos (id, visit_id, photo_url, sort_order) values
  ('40000000-0000-4000-8000-000000000001', '${visitID}', 'https://example.com/cover.jpg', 0),
  ('40000000-0000-4000-8000-000000000002', '${visitID}', 'mugshot-storage://visit-photos-private/owner/visit/second.jpg', 1);
`)

const migration = await fs.readFile(
  repoPath + 'supabase/migrations/20260723154204_post_publish_share_hub.sql',
  'utf8',
)
await db.exec(migration)
const capabilityMigration = await fs.readFile(
  repoPath + 'supabase/migrations/20260820150833_friends_capability_share_links.sql',
  'utf8',
)
await db.exec(capabilityMigration)
const contract = await fs.readFile(
  repoPath + 'supabase/tests/mugshot_share_links_contract.sql',
  'utf8',
)
await db.exec(contract)

const authenticatedAs = async (userID, statement) => {
  await db.exec(`
    set role authenticated;
    select set_config(
      'request.jwt.claims',
      '{"sub":"${userID}","role":"authenticated"}',
      false
    );
  `)
  try {
    return await db.query(statement)
  } finally {
    await db.exec('reset role;')
  }
}

const firstLink = await authenticatedAs(
  ownerID,
  `select public.create_visit_share_link_v1('${visitID}') slug`,
)
const slug = firstLink.rows[0]?.slug
assert(/^[A-Za-z0-9_-]{24,128}$/.test(slug), 'owner link was not opaque')

const retryLink = await authenticatedAs(
  ownerID,
  `select public.create_visit_share_link_v1('${visitID}') slug`,
)
assert(retryLink.rows[0]?.slug === slug, 'link creation was not idempotent')

let foreignCreateRejected = false
try {
  await authenticatedAs(
    otherID,
    `select public.create_visit_share_link_v1('${visitID}')`,
  )
} catch {
  foreignCreateRejected = true
}
assert(foreignCreateRejected, 'non-owner created a public visit link')

await db.exec('set role anon;')
const projection = await db.query(
  `select to_jsonb(result) projection
   from public.get_public_mugshot_share_v1('${slug}') result`,
)
await db.query(
  `select public.record_public_mugshot_share_event_v1('${slug}', 'landing_visit')`,
)
await db.query(
  `select public.record_public_mugshot_share_event_v1('${slug}', 'app_open')`,
)
await db.exec('reset role;')
assert(projection.rows.length === 1, 'anonymous public projection was missing')

const expectedKeys = [
  'author_avatar_url',
  'author_name',
  'author_username',
  'caption',
  'context_name',
  'cover_photo_url',
  'created_at',
  'drink_name',
  'photo_urls',
  'rating',
  'ratings',
  'slug',
  'visit_id',
]
assert(
  JSON.stringify(Object.keys(projection.rows[0].projection).sort()) ===
    JSON.stringify(expectedKeys),
  'public projection exposed an unexpected field',
)
assert(
  projection.rows[0].projection.context_name === 'Public Test Cafe',
  'public projection lost the safe cafe label',
)
assert(
  projection.rows[0].projection.photo_urls.length === 2 &&
    projection.rows[0].projection.photo_urls[0] === 'https://example.com/cover.jpg',
  'capability projection lost the ordered real post photos',
)
const metrics = await db.query(
  `select landing_visits, app_opens
   from public.visit_share_link_metrics where visit_id = '${visitID}'`,
)
assert(
  metrics.rows[0]?.landing_visits === 1 &&
    metrics.rows[0]?.app_opens === 1,
  'anonymous-safe public share metrics were not attributed',
)

for (const visibility of ['friends', 'everyone']) {
  await db.exec(
    `update public.visits set visibility = '${visibility}' where id = '${visitID}'`,
  )
  const visible = await db.query(
    `select * from public.get_public_mugshot_share_v1('${slug}')`,
  )
  assert(visible.rows.length === 1, `${visibility} capability link disappeared`)
}

await db.exec(
  `update public.visits set visibility = 'private', upload_state = 'complete'
   where id = '${visitID}'`,
)
const privateProjection = await db.query(
  `select * from public.get_public_mugshot_share_v1('${slug}')`,
)
assert(privateProjection.rows.length === 0, 'private visit remained capability-visible')

await db.exec(
  `update public.visits set visibility = 'friends', upload_state = 'pending'
   where id = '${visitID}'`,
)
const unpublished = await db.query(
  `select * from public.get_public_mugshot_share_v1('${slug}')`,
)
assert(unpublished.rows.length === 0, 'queued visit remained public')

await db.exec(`
  update public.visits set upload_state = 'complete' where id = '${visitID}';
  insert into private.suppressed_visits (visit_id) values ('${visitID}');
`)
const suppressed = await db.query(
  `select * from public.get_public_mugshot_share_v1('${slug}')`,
)
assert(suppressed.rows.length === 0, 'moderated visit remained public')

await db.exec(
  `delete from private.suppressed_visits where visit_id = '${visitID}'`,
)
const revoked = await authenticatedAs(
  ownerID,
  `select public.revoke_visit_share_link_v1('${visitID}') revoked`,
)
assert(revoked.rows[0]?.revoked, 'owner could not revoke the link')
const revokedProjection = await db.query(
  `select * from public.get_public_mugshot_share_v1('${slug}')`,
)
assert(revokedProjection.rows.length === 0, 'revoked link remained public')

const replacementLink = await authenticatedAs(
  ownerID,
  `select public.create_visit_share_link_v1('${visitID}') slug`,
)
assert(replacementLink.rows[0]?.slug !== slug, 'revoked slug was reused')

let directReadRejected = false
try {
  await db.exec('set role authenticated;')
  await db.query('select * from public.visit_share_links')
} catch {
  directReadRejected = true
} finally {
  await db.exec('reset role;')
}
assert(directReadRejected, 'authenticated role can read sealed link rows')

let directMetricsReadRejected = false
try {
  await db.exec('set role authenticated;')
  await db.query('select * from public.visit_share_link_metrics')
} catch {
  directMetricsReadRejected = true
} finally {
  await db.exec('reset role;')
}
assert(
  directMetricsReadRejected,
  'authenticated role can read sealed share metrics',
)

await db.exec(`delete from public.users where id = '${ownerID}'`)
const deletedAccountProjection = await db.query(
  `select * from public.get_public_mugshot_share_v1('${replacementLink.rows[0].slug}')`,
)
assert(
  deletedAccountProjection.rows.length === 0,
  'deleted account link remained public',
)

await db.close()
console.log(
  'PGlite Mugshot share-link ownership, privacy, moderation, revocation, and projection checks passed',
)
