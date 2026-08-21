import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const repoPath = fileURLToPath(new URL('../../', import.meta.url))
const ownerID = '10000000-0000-4000-8000-000000000001'
const otherID = '10000000-0000-4000-8000-000000000002'
const strangerID = '10000000-0000-4000-8000-000000000003'
const unrelatedID = '10000000-0000-4000-8000-000000000004'
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
  display_name text not null,
  username text not null,
  bio text,
  location text,
  favorite_drink text,
  instagram_handle text,
  avatar_url text,
  banner_url text,
  website_url text,
  taste_passport_visibility text not null default 'everyone',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.cafes (
  id uuid primary key,
  name text not null,
  address text,
  city text,
  latitude double precision,
  longitude double precision,
  identity_key text
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
  category_scores jsonb,
  poster_photo_url text,
  context_type text,
  location_name text,
  city_state text,
  brew_method text,
  equipment text,
  brew_method_visible boolean not null default false,
  equipment_visible boolean not null default false,
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
create table public.user_blocks (
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  primary key (blocker_id, blocked_id)
);
create table public.friends (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  friend_user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, friend_user_id)
);
create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references public.users(id) on delete cascade,
  to_user_id uuid not null references public.users(id) on delete cascade,
  status text not null,
  created_at timestamptz not null default now()
);
create table public.cafe_experience_public_projections (
  session_id uuid primary key,
  primary_visit_id uuid references public.visits(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  includes_cafe_rating boolean not null default false,
  cafe_rating numeric
);
create table public.taste_signals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  signal_type text not null,
  attribute text not null,
  owner_label text,
  owner_state text not null,
  support_count integer not null default 0,
  confidence numeric not null default 0,
  updated_at timestamptz not null default now()
);
create table public.visit_v3_reflections (
  visit_id uuid primary key references public.visits(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  sip_score numeric not null,
  context_score numeric,
  context_criteria jsonb not null default '[]'::jsonb,
  sip_raw_note text,
  context_raw_note text,
  raw_note_visibility text not null default 'private',
  mugshot_score numeric not null
);
create table public.likes (
  user_id uuid not null references public.users(id) on delete cascade,
  visit_id uuid not null references public.visits(id) on delete cascade,
  primary key (user_id, visit_id)
);
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  visit_id uuid not null references public.visits(id) on delete cascade,
  removed_at timestamptz
);
create table public.visit_bookmarks (
  user_id uuid not null references public.users(id) on delete cascade,
  visit_id uuid not null references public.visits(id) on delete cascade,
  primary key (user_id, visit_id)
);
create table public.visit_tags (
  visit_id uuid not null references public.visits(id) on delete cascade,
  tagged_user_id uuid not null references public.users(id) on delete cascade,
  tagged_by uuid not null references public.users(id) on delete cascade,
  primary key (visit_id, tagged_user_id)
);

create function private.blocked_between(p_first uuid, p_second uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_first is null or p_second is null or exists (
    select 1 from public.user_blocks block
    where (block.blocker_id = p_first and block.blocked_id = p_second)
       or (block.blocker_id = p_second and block.blocked_id = p_first)
  )
$$;

create function private.confirmed_friends(p_first uuid, p_second uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select p_first = p_second or (
    not private.blocked_between(p_first, p_second)
    and exists (
      select 1 from public.friends friend
      where friend.user_id = p_first and friend.friend_user_id = p_second
    )
    and exists (
      select 1 from public.friends friend
      where friend.user_id = p_second and friend.friend_user_id = p_first
    )
  )
$$;

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

create function private.can_view_user_as(p_user_id uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select private.is_live_account_as(p_viewer)
    and private.is_live_account_as(p_user_id)
    and not private.blocked_between(p_viewer, p_user_id)
$$;

insert into public.users (id, display_name, username, avatar_url) values
  ('${ownerID}', 'Journal Owner', 'owner', 'https://example.com/avatar.jpg'),
  ('${otherID}', 'Other Person', 'other', null),
  ('${strangerID}', 'Stranger', 'stranger', null),
  ('${unrelatedID}', 'Unrelated', 'unrelated', null);
insert into public.cafes (id, name, city, identity_key) values
  ('${cafeID}', 'Public Test Cafe', 'Test City', 'test:public-cafe');
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
const profileContractMigration = await fs.readFile(
  repoPath +
    'supabase/migrations/20260821162404_profile_sharing_and_canonical_post_v2.sql',
  'utf8',
)
await db.exec(profileContractMigration)

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
    await db.exec(`
      reset role;
      select set_config('request.jwt.claims', '{}', false);
    `)
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

await db.exec(
  `update public.visits set visibility = 'everyone' where id = '${visitID}'`,
)
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

await db.exec(
  `update public.visits set visibility = 'friends' where id = '${visitID}'`,
)
const anonymousFriendsProjection = await db.query(
  `select * from public.get_public_mugshot_share_v1('${slug}')`,
)
assert(
  anonymousFriendsProjection.rows.length === 0,
  'Friends link expanded the post audience for an anonymous viewer',
)

await db.exec(`
  insert into public.friends (user_id, friend_user_id) values
    ('${ownerID}', '${otherID}'),
    ('${otherID}', '${ownerID}');
`)
const mutualFriendProjection = await authenticatedAs(
  otherID,
  `select * from public.get_public_mugshot_share_v1('${slug}')`,
)
assert(
  mutualFriendProjection.rows.length === 1,
  'confirmed mutual friend could not resolve a Friends link',
)

await db.exec(
  `update public.visits set visibility = 'everyone' where id = '${visitID}'`,
)
const everyoneProjection = await db.query(
  `select * from public.get_public_mugshot_share_v1('${slug}')`,
)
assert(everyoneProjection.rows.length === 1, 'Everyone link disappeared')

await db.exec(`
  insert into public.visit_v3_reflections (
    visit_id, user_id, sip_score, context_score, context_criteria,
    sip_raw_note, context_raw_note, raw_note_visibility, mugshot_score
  ) values (
    '${visitID}', '${ownerID}', 4.5, 4.0,
    '[{"name":"Flavor balance","score":4.5}]',
    'Bright orange and cocoa', 'Calm room', 'friends', 4.3
  );
`)

const anonymousCanonical = await db.query(
  `select public.get_canonical_post_v1('${visitID}', '${slug}') projection`,
)
assert(
  anonymousCanonical.rows[0]?.projection?.journal_note?.sip_note === null,
  'anonymous viewer received a Friends journal note',
)
assert(
  anonymousCanonical.rows[0]?.projection?.author?.avatar_url ===
    'https://example.com/avatar.jpg',
  'canonical post lost the real author avatar',
)

const friendCanonical = await authenticatedAs(
  otherID,
  `select public.get_canonical_post_v1('${visitID}', '${slug}') projection`,
)
assert(
  friendCanonical.rows[0]?.projection?.journal_note?.sip_note ===
    'Bright orange and cocoa',
  'confirmed mutual friend could not read the Friends journal note',
)

await db.exec(
  `update public.visit_v3_reflections
   set raw_note_visibility = 'everyone' where visit_id = '${visitID}'`,
)
const everyoneCanonical = await db.query(
  `select public.get_canonical_post_v1('${visitID}', '${slug}') projection`,
)
assert(
  everyoneCanonical.rows[0]?.projection?.journal_note?.sip_note ===
    'Bright orange and cocoa',
  'Everyone journal note was not available to the public post',
)

const profileLinkResult = await authenticatedAs(
  ownerID,
  'select public.create_profile_share_link_v1() slug',
)
const profileSlug = profileLinkResult.rows[0]?.slug
assert(
  /^[A-Za-z0-9_-]{24,128}$/.test(profileSlug),
  'profile link was not opaque',
)

const publicProfile = await db.query(
  `select public.get_profile_share_v1('${profileSlug}') projection`,
)
assert(
  publicProfile.rows[0]?.projection?.profile?.username === 'owner',
  'public profile link did not resolve the real shared profile',
)
assert(
  publicProfile.rows[0]?.projection?.stats?.sips === 1,
  'public profile stats did not use the Everyone projection',
)
assert(
  publicProfile.rows[0]?.projection?.taste_passport?.visibility === 'everyone',
  'Everyone Taste Passport was missing from the public profile',
)

await db.exec(
  `update public.users set taste_passport_visibility = 'private'
   where id = '${ownerID}'`,
)
const privatePassportProfile = await db.query(
  `select public.get_profile_share_v1('${profileSlug}') projection`,
)
assert(
  privatePassportProfile.rows[0]?.projection?.taste_passport_visible === false &&
    privatePassportProfile.rows[0]?.projection?.taste_passport === null,
  'Private Taste Passport leaked into the public profile',
)
await db.exec(
  `update public.users set taste_passport_visibility = 'everyone'
   where id = '${ownerID}'`,
)

const publicGrid = await db.query(
  `select * from public.list_profile_share_sips_v1('${profileSlug}', 24)`,
)
assert(
  publicGrid.rows.length === 1 && publicGrid.rows[0].id === visitID,
  'public profile grid did not return the canonical sip',
)

const everyonePreview = await authenticatedAs(
  ownerID,
  `select public.get_profile_projection_v2('${ownerID}', true) projection`,
)
assert(
  JSON.stringify(everyonePreview.rows[0]?.projection?.stats) ===
    JSON.stringify(publicProfile.rows[0]?.projection?.stats),
  'Preview as Everyone drifted from the public-link projection',
)

const sipHighlight = await authenticatedAs(
  ownerID,
  `select public.set_profile_highlight_v1('sip', '${visitID}') highlight`,
)
assert(
  sipHighlight.rows[0]?.highlight?.sip?.id === visitID,
  'owner could not pin a sip',
)

await db.exec(
  `update public.visits set visibility = 'friends' where id = '${visitID}'`,
)
const hiddenPublicProfile = await db.query(
  `select public.get_profile_share_v1('${profileSlug}') projection`,
)
assert(
  hiddenPublicProfile.rows[0]?.projection?.stats?.sips === 0 &&
    hiddenPublicProfile.rows[0]?.projection?.highlight === null,
  'Friends sip leaked through public profile stats or highlight',
)

const cafeHighlight = await authenticatedAs(
  ownerID,
  `select public.set_profile_highlight_v1('cafe', '${cafeID}') highlight`,
)
assert(
  cafeHighlight.rows[0]?.highlight?.cafe?.id === cafeID,
  'owner could not feature a favorite cafe',
)

await db.exec(
  `update public.users set profile_setup_completed_at = null where id = '${strangerID}'`,
)
const incompleteSetup = await authenticatedAs(
  strangerID,
  'select public.get_profile_setup_state_v1() state',
)
assert(
  incompleteSetup.rows[0]?.state?.is_complete === false,
  'new account was not gated by profile setup',
)
const completedSetup = await authenticatedAs(
  strangerID,
  `select public.complete_profile_setup_v1('Amanda', 'amanda_test') profile`,
)
assert(
  completedSetup.rows[0]?.profile?.username === 'amanda_test' &&
    completedSetup.rows[0]?.profile?.profile_setup_completed_at,
  'required profile setup did not complete atomically',
)

await db.exec(`
  insert into public.visit_tags (visit_id, tagged_user_id, tagged_by)
  values ('${visitID}', '${strangerID}', '${ownerID}');
  update public.visits set visibility = 'everyone' where id = '${visitID}';
`)
const suggestions = await authenticatedAs(
  ownerID,
  'select user_id from public.visit_tag_suggestions_v1(50)',
)
const suggestionIDs = new Set(suggestions.rows.map((row) => row.user_id))
assert(suggestionIDs.has(otherID), 'confirmed friend was missing from tag suggestions')
assert(suggestionIDs.has(strangerID), 'past real tag was missing from suggestions')
assert(
  !suggestionIDs.has(unrelatedID),
  'unrelated account appeared in Friends and past tags',
)

let directProfileLinkReadRejected = false
try {
  await db.exec('set role authenticated;')
  await db.query('select * from public.profile_share_links')
} catch {
  directProfileLinkReadRejected = true
} finally {
  await db.exec('reset role;')
}
assert(
  directProfileLinkReadRejected,
  'authenticated role can read sealed profile links',
)

let directHighlightWriteRejected = false
try {
  await db.exec('set role authenticated;')
  await db.query(
    `insert into public.profile_highlights (user_id, highlight_type, cafe_id)
     values ('${otherID}', 'cafe', '${cafeID}')`,
  )
} catch {
  directHighlightWriteRejected = true
} finally {
  await db.exec('reset role;')
}
assert(
  directHighlightWriteRejected,
  'authenticated role bypassed the owner highlight RPC',
)

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
