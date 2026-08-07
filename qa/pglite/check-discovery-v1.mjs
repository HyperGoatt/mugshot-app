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
  id uuid primary key references auth.users(id),
  display_name text,
  username text not null,
  avatar_url text
);
create table public.cafes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  city text,
  country text,
  latitude double precision,
  longitude double precision,
  apple_place_id text,
  website_url text,
  identity_key text not null unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create function public.set_cafe_identity_key() returns trigger language plpgsql as $$
begin new.identity_key := coalesce(new.identity_key, gen_random_uuid()::text); return new; end
$$;
create trigger cafes_set_identity_key before insert or update on public.cafes
for each row execute function public.set_cafe_identity_key();

create table public.visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  cafe_id uuid not null references public.cafes(id),
  drink_type text,
  drink_type_custom text,
  drink_subtype text,
  caption text not null default '',
  notes text,
  visibility text not null default 'everyone',
  overall_score double precision not null default 0,
  poster_photo_url text,
  upload_state text not null default 'complete',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.user_cafe_states (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  cafe_id uuid not null references public.cafes(id),
  is_favorite boolean not null default false,
  want_to_try boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, cafe_id)
);
alter table public.user_cafe_states enable row level security;

create table public.cafe_lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references public.users(id),
  title text not null check (length(trim(title)) between 1 and 80),
  description text check (length(coalesce(description, '')) <= 280),
  visibility text not null default 'private'
    constraint cafe_lists_visibility_check check (visibility in ('private','friends','invited')),
  system_kind text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.cafe_list_members (
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null default 'viewer',
  invitation_status text not null default 'accepted',
  invited_by uuid references public.users(id),
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  primary key (list_id, user_id)
);
create table public.cafe_list_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  position integer not null default 0,
  contributor_id uuid not null references public.users(id),
  note text,
  created_at timestamptz not null default now(),
  unique (list_id, cafe_id)
);
alter table public.cafe_lists enable row level security;
alter table public.cafe_list_members enable row level security;
alter table public.cafe_list_items enable row level security;

create table public.cafe_experience_public_projections (
  session_id uuid primary key,
  snapshot_id uuid,
  primary_visit_id uuid references public.visits(id),
  user_id uuid not null references public.users(id),
  cafe_id uuid not null references public.cafes(id),
  descriptor_ids text[] not null default '{}'
);
create table public.cafe_sessions (
  id uuid primary key,
  user_id uuid not null references public.users(id),
  cafe_id uuid not null references public.cafes(id),
  visit_mode text
);
create table public.cafe_experience_snapshots (
  session_id uuid primary key references public.cafe_sessions(id),
  snapshot_id uuid not null unique,
  user_id uuid not null references public.users(id),
  cafe_id uuid not null references public.cafes(id),
  responses jsonb not null
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
create function private.blocked_between(a uuid, b uuid) returns boolean language sql stable as $$
  select a is not null and b is not null and exists (
    select 1 from public.user_blocks
    where (blocker_id = a and blocked_id = b) or (blocker_id = b and blocked_id = a)
  )
$$;
create function private.confirmed_friends(a uuid, b uuid) returns boolean language sql stable as $$
  select exists (select 1 from public.friends where user_id = a and friend_user_id = b)
$$;
create function private.has_active_moderation_action(text, uuid, text[], timestamptz default now())
returns boolean language sql stable as $$ select false $$;
create function private.is_live_account_as(actor uuid) returns boolean language sql stable as $$
  select actor is not null and exists (
    select 1 from auth.users where id = actor and deleted_at is null
  )
$$;
create function private.can_socially_mutate_as(actor uuid) returns boolean language sql stable as $$
  select private.is_live_account_as(actor)
$$;
create function private.can_view_user_as(subject uuid, viewer uuid) returns boolean language sql stable as $$
  select private.is_live_account_as(subject) and private.is_live_account_as(viewer)
    and not private.blocked_between(subject, viewer)
$$;
create function private.can_view_visit_as(visit_id uuid, viewer uuid) returns boolean language sql stable as $$
  select exists (
    select 1 from public.visits visit
    where visit.id = visit_id and private.can_view_user_as(visit.user_id, viewer)
      and (visit.user_id = viewer or visit.visibility = 'everyone'
        or (visit.visibility = 'friends' and private.confirmed_friends(viewer, visit.user_id)))
  )
$$;
create function private.can_view_cafe_list_as(uuid, uuid) returns boolean
language sql stable as $$ select false $$;
create function private.can_view_cafe_list_items_as(uuid, uuid) returns boolean
language sql stable as $$ select false $$;
create function private.can_manage_cafe_list_as(list_id uuid, actor uuid) returns boolean
language sql stable as $$
  select private.can_socially_mutate_as(actor) and exists (
    select 1 from public.cafe_lists where id = list_id and owner_id = actor and system_kind is null
  )
$$;
create function public.get_cafe_list_v2(list_id uuid) returns jsonb language sql stable as $$
  select jsonb_build_object('id', id, 'title', title, 'visibility', visibility)
  from public.cafe_lists where id = list_id
$$;
`

await db.exec(bootstrap)
const migration = await fs.readFile(
  repoPath + 'supabase/migrations/20260806203723_discovery_v1.sql',
  'utf8'
)
await db.exec(migration)
const indexMigration = await fs.readFile(
  repoPath + 'supabase/migrations/20260807013624_index_discovery_foreign_keys.sql',
  'utf8'
)
await db.exec(indexMigration)

const ids = {
  owner: '81000000-0000-4000-8000-000000000001',
  viewer: '81000000-0000-4000-8000-000000000002',
  friend: '81000000-0000-4000-8000-000000000003',
  cafe: '82000000-0000-4000-8000-000000000001',
  list: '83000000-0000-4000-8000-000000000001',
  visit: '84000000-0000-4000-8000-000000000001'
}

await db.exec(`
insert into auth.users(id) values
('${ids.owner}'), ('${ids.viewer}'), ('${ids.friend}'),
('81000000-0000-4000-8000-000000000004'),
('81000000-0000-4000-8000-000000000005');
insert into public.users(id,display_name,username) values
('${ids.owner}','Owner','owner'),
('${ids.viewer}','Viewer','viewer'),
('${ids.friend}','Amanda','amanda'),
('81000000-0000-4000-8000-000000000004','Bea','bea'),
('81000000-0000-4000-8000-000000000005','Chris','chris');
insert into public.cafes(
  id,name,address,latitude,longitude,apple_maps_place_id,apple_place_id,identity_key
) values (
  '${ids.cafe}','Ritual Coffee Roasters','1026 Valencia St',37.7564,-122.4212,
  'mapkit-ritual','https://maps.apple.com/legacy','seed'
);
insert into public.cafe_lists(id,owner_id,title,description,visibility,published_at)
values ('${ids.list}','${ids.owner}','Mission coffee walk','Five thoughtful stops','public',now());
insert into public.cafe_list_items(list_id,cafe_id,position,contributor_id,note)
values ('${ids.list}','${ids.cafe}',0,'${ids.owner}','Start with the seasonal drink');
insert into public.cafe_list_share_links(list_id,slug,created_by)
values ('${ids.list}','0123456789abcdef01234567','${ids.owner}');
insert into public.friends(user_id,friend_user_id)
values ('${ids.viewer}','${ids.friend}');
insert into public.visits(
  id,user_id,cafe_id,drink_subtype,caption,visibility,overall_score,upload_state,created_at
) values (
  '${ids.visit}','${ids.friend}','${ids.cafe}','matcha','Loved it','friends',4.5,'complete',now()
);

insert into public.cafe_sessions(id,user_id,cafe_id,visit_mode) values
('85000000-0000-4000-8000-000000000001','${ids.friend}','${ids.cafe}','work_study'),
('85000000-0000-4000-8000-000000000002','${ids.friend}','${ids.cafe}','work_study'),
('85000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000004','${ids.cafe}','work_study'),
('85000000-0000-4000-8000-000000000004','81000000-0000-4000-8000-000000000004','${ids.cafe}','work_study'),
('85000000-0000-4000-8000-000000000005','81000000-0000-4000-8000-000000000005','${ids.cafe}','work_study');

insert into public.visits(id,user_id,cafe_id,caption,visibility,overall_score,upload_state) values
('86000000-0000-4000-8000-000000000001','${ids.friend}','${ids.cafe}','','everyone',4,'complete'),
('86000000-0000-4000-8000-000000000002','${ids.friend}','${ids.cafe}','','everyone',4,'complete'),
('86000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000004','${ids.cafe}','','everyone',4,'complete'),
('86000000-0000-4000-8000-000000000004','81000000-0000-4000-8000-000000000004','${ids.cafe}','','everyone',4,'complete'),
('86000000-0000-4000-8000-000000000005','81000000-0000-4000-8000-000000000005','${ids.cafe}','','everyone',4,'complete');

insert into public.cafe_experience_snapshots(
  session_id,snapshot_id,user_id,cafe_id,responses
) values
('85000000-0000-4000-8000-000000000001','87000000-0000-4000-8000-000000000001','${ids.friend}','${ids.cafe}','[{"state":"observed","impact":"lifted","descriptorIDs":["cafe.descriptor.comfort_and_practicality.wifi"]}]'),
('85000000-0000-4000-8000-000000000002','87000000-0000-4000-8000-000000000002','${ids.friend}','${ids.cafe}','[{"state":"observed","impact":"lifted","descriptorIDs":["cafe.descriptor.comfort_and_practicality.wifi"]}]'),
('85000000-0000-4000-8000-000000000003','87000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000004','${ids.cafe}','[{"state":"observed","impact":"lifted","descriptorIDs":["cafe.descriptor.comfort_and_practicality.wifi"]}]'),
('85000000-0000-4000-8000-000000000004','87000000-0000-4000-8000-000000000004','81000000-0000-4000-8000-000000000004','${ids.cafe}','[{"state":"observed","impact":"lifted","descriptorIDs":["cafe.descriptor.comfort_and_practicality.wifi"]}]'),
('85000000-0000-4000-8000-000000000005','87000000-0000-4000-8000-000000000005','81000000-0000-4000-8000-000000000005','${ids.cafe}','[{"state":"observed","impact":"lifted","descriptorIDs":["cafe.descriptor.comfort_and_practicality.wifi"]}]');

insert into public.cafe_experience_public_projections(
  session_id,snapshot_id,primary_visit_id,user_id,cafe_id,descriptor_ids
) values
('85000000-0000-4000-8000-000000000001','87000000-0000-4000-8000-000000000001','86000000-0000-4000-8000-000000000001','${ids.friend}','${ids.cafe}',array['cafe.descriptor.comfort_and_practicality.wifi']),
('85000000-0000-4000-8000-000000000002','87000000-0000-4000-8000-000000000002','86000000-0000-4000-8000-000000000002','${ids.friend}','${ids.cafe}',array['cafe.descriptor.comfort_and_practicality.wifi']),
('85000000-0000-4000-8000-000000000003','87000000-0000-4000-8000-000000000003','86000000-0000-4000-8000-000000000003','81000000-0000-4000-8000-000000000004','${ids.cafe}',array['cafe.descriptor.comfort_and_practicality.wifi']),
('85000000-0000-4000-8000-000000000004','87000000-0000-4000-8000-000000000004','86000000-0000-4000-8000-000000000004','81000000-0000-4000-8000-000000000004','${ids.cafe}',array['cafe.descriptor.comfort_and_practicality.wifi']),
('85000000-0000-4000-8000-000000000005','87000000-0000-4000-8000-000000000005','86000000-0000-4000-8000-000000000005','81000000-0000-4000-8000-000000000005','${ids.cafe}',array['cafe.descriptor.comfort_and_practicality.wifi']);
`)

const identity = await db.query(`
  select apple_maps_place_id, identity_key from public.cafes where id = '${ids.cafe}'
`)
if (identity.rows[0].identity_key !== 'apple-mapkit:mapkit-ritual') {
  throw new Error('new Apple MapKit identity did not take precedence')
}

const publicDetail = await db.query(`
  select public.get_public_cafe_list_v1('0123456789abcdef01234567') detail
`)
const detail = publicDetail.rows[0].detail
if (detail.title !== 'Mission coffee walk' || detail.items?.length !== 1) {
  throw new Error('anonymous-safe public list detail was not hydrated')
}
if ('discovery_note' in detail.items[0] || 'notes' in detail.items[0]) {
  throw new Error('public list projection leaked a private note')
}

await db.exec(`set request.jwt.claims = '{"sub":"${ids.viewer}"}'`)
await db.query(`select public.follow_cafe_list_v1('${ids.list}', true)`)
const followed = await db.query(`
  select count(*)::int count from public.cafe_list_follows
  where list_id = '${ids.list}' and user_id = '${ids.viewer}'
`)
if (followed.rows[0].count !== 1) throw new Error('public list follow was not recorded')

await db.exec(`
insert into public.user_cafe_states(
  user_id,cafe_id,want_to_try,discovery_note,discovery_source,discovered_at
) values (
  '${ids.viewer}','${ids.cafe}',true,'Try the matcha','share_import',now() - interval '90 days'
);
`)
const enriched = await db.query(`
  select public.enrich_discovery_candidates_v1(
    '[{"apple_maps_place_id":"mapkit-ritual","name":"Ritual Coffee Roasters","latitude":37.7564,"longitude":-122.4212}]'::jsonb
  ) result
`)
const candidate = enriched.rows[0].result[0]
if (!candidate.want_to_try || candidate.friend_evidence?.[0]?.author?.display_name !== 'Amanda') {
  throw new Error('candidate enrichment omitted owner-safe or visible friend evidence')
}
if ('discovery_note' in candidate) {
  throw new Error('candidate enrichment leaked the caller private discovery note')
}
const practicalIDs = new Set(candidate.practical_evidence?.map(row => row.descriptor_id))
if (!practicalIDs.has('cafe.descriptor.comfort_and_practicality.wifi')
    || !practicalIDs.has('cafe.fit.work_study')) {
  throw new Error('thresholded positive practical evidence was not projected')
}

const viewerVisit = '84000000-0000-4000-8000-000000000002'
await db.exec(`
insert into public.visits(id,user_id,cafe_id,caption,visibility,overall_score,created_at)
values ('${viewerVisit}','${ids.viewer}','${ids.cafe}','Finally here','private',4.0,now());
`)
const attribution = await db.query(`
  select public.consume_discovery_attribution_v1('${viewerVisit}') result
`)
if (!attribution.rows[0].result.attributed
    || attribution.rows[0].result.kind !== 'saved_first_log') {
  throw new Error('far-future first-log attribution was not consumed')
}
const second = await db.query(`
  select public.consume_discovery_attribution_v1('${viewerVisit}') result
`)
const attributionCount = await db.query(`
  select count(*)::int count from public.mugshot_discovery_attributions
  where visit_id = '${viewerVisit}'
`)
if (attributionCount.rows[0].count !== 1 || !second.rows[0].result.attributed) {
  throw new Error('attribution retry was not idempotent')
}

const privileges = await db.query(`
  select
    has_table_privilege('authenticated', 'public.discovery_interactions', 'insert') interactions_insert,
    has_table_privilege('authenticated', 'public.cafe_list_comments', 'insert') comments_insert
`)
if (privileges.rows[0].interactions_insert || privileges.rows[0].comments_insert) {
  throw new Error('RPC-only discovery tables exposed direct writes')
}

const supportIndexes = await db.query(`
  select count(*)::int count
  from pg_indexes
  where schemaname = 'public'
    and indexname in (
      'discovery_interactions_cafe_idx',
      'discovery_interactions_source_list_idx',
      'mugshot_discovery_attributions_cafe_idx',
      'mugshot_discovery_attributions_interaction_idx',
      'cafe_list_share_links_creator_idx',
      'cafe_list_comments_author_idx',
      'cafe_list_comments_deleted_by_idx',
      'cafe_list_comment_reports_reporter_idx'
    )
`)
if (supportIndexes.rows[0].count !== 8) {
  throw new Error('discovery foreign-key support indexes are incomplete')
}

console.log('PASS discovery V1 identity, public-list, enrichment, and attribution contracts')
await db.close()
