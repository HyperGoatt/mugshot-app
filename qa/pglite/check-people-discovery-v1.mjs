import assert from 'node:assert/strict'
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
create schema private;
create schema extensions;

-- PGlite does not bundle pgcrypto. These test-only functions preserve the
-- byte lengths and determinism needed to exercise the migration contract.
create function extensions.gen_random_bytes(p_length integer) returns bytea language sql volatile as $$
  select decode(substr(repeat(md5(random()::text), 8), 1, p_length * 2), 'hex')
$$;
create function extensions.digest(p_value text, p_algorithm text) returns bytea language sql immutable as $$
  select decode(md5(p_value) || md5(p_value || p_algorithm), 'hex')
$$;
create function extensions.hmac(p_value bytea, p_key bytea, p_algorithm text) returns bytea language sql immutable as $$
  select decode(
    md5(encode(p_value, 'hex') || encode(p_key, 'hex')) ||
    md5(encode(p_key, 'hex') || encode(p_value, 'hex') || p_algorithm),
    'hex'
  )
$$;

create table auth.users (
  id uuid primary key,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create function auth.uid() returns uuid language sql stable as $$
  select nullif((coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb)->>'sub', '')::uuid
$$;

create table public.users (
  id uuid primary key references auth.users(id),
  display_name text,
  username text not null unique,
  bio text,
  location text,
  favorite_drink text,
  avatar_url text,
  banner_url text
);
create table public.friend_requests (
  id uuid primary key default gen_random_uuid(),
  from_user_id uuid not null references public.users(id),
  to_user_id uuid not null references public.users(id),
  status text not null default 'pending',
  unique (from_user_id, to_user_id)
);
create table public.friends (
  user_id uuid not null references public.users(id),
  friend_user_id uuid not null references public.users(id),
  primary key (user_id, friend_user_id)
);
create table public.visits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  visibility text not null default 'everyone',
  upload_state text not null default 'complete',
  created_at timestamptz not null default now()
);
create table public.likes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  visit_id uuid not null references public.visits(id),
  created_at timestamptz not null default now(),
  unique(user_id, visit_id)
);
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  visit_id uuid not null references public.visits(id),
  text text not null,
  created_at timestamptz not null default now(),
  removed_at timestamptz
);
create table public.visit_reactions (
  visit_id uuid not null references public.visits(id),
  user_id uuid not null references public.users(id),
  reaction text not null,
  created_at timestamptz not null default now(),
  primary key(visit_id, user_id)
);
create table public.visit_companions (
  visit_id uuid not null references public.visits(id),
  companion_user_id uuid not null references public.users(id),
  added_by uuid not null references public.users(id)
);
create table public.cafe_list_members (
  list_id uuid not null,
  user_id uuid not null references public.users(id),
  invitation_status text not null default 'accepted',
  primary key (list_id, user_id)
);

create function private.blocked_between(uuid, uuid) returns boolean
language sql stable as $$ select false $$;
create function private.confirmed_friends(a uuid, b uuid) returns boolean
language sql stable as $$
  select exists(select 1 from public.friends where user_id = a and friend_user_id = b)
$$;
create function private.can_view_user_as(subject uuid, viewer uuid) returns boolean
language sql stable as $$ select subject is not null and viewer is not null $$;
create function private.can_view_visit_as(p_visit_id uuid, viewer uuid) returns boolean
language sql stable as $$
  select exists(select 1 from public.visits where id = p_visit_id and visibility <> 'private')
$$;

create function public.search_users(
  p_query text, p_limit integer, p_after_rank integer, p_after_score real,
  p_after_username text, p_after_id uuid
) returns table (
  id uuid, display_name text, username text, bio text, location text,
  favorite_drink text, avatar_url text, banner_url text,
  friendship_state text, mutual_friend_count bigint,
  rank_bucket integer, match_score real
) language sql stable as $$
  select profile.id, profile.display_name, profile.username, profile.bio,
    profile.location, profile.favorite_drink, profile.avatar_url, profile.banner_url,
    'none'::text, 0::bigint, 1, 1::real
  from public.users profile
  where profile.id <> auth.uid()
    and (profile.username ilike '%' || p_query || '%' or profile.display_name ilike '%' || p_query || '%')
  order by profile.username, profile.id limit p_limit
$$;
create function public.list_social_connections(p_kind text, p_limit integer)
returns table (relationship_id uuid, user_id uuid, display_name text, username text, avatar_url text, status text)
language sql stable as $$
  select null::uuid, null::uuid, null::text, null::text, null::text, null::text where false
$$;
create function public.send_friend_request(p_target_user_id uuid)
returns public.friend_requests language plpgsql as $$
declare result public.friend_requests;
begin
  insert into public.friend_requests(from_user_id, to_user_id)
    values(auth.uid(), p_target_user_id) returning * into result;
  return result;
end
$$;
create function public.respond_friend_request(p_request_id uuid, p_accept boolean)
returns public.friend_requests language plpgsql as $$
declare result public.friend_requests;
begin
  update public.friend_requests set status = case when p_accept then 'accepted' else 'declined' end
    where id = p_request_id and to_user_id = auth.uid() returning * into result;
  if result.id is null then raise exception 'request unavailable'; end if;
  if p_accept then
    insert into public.friends(user_id, friend_user_id) values
      (result.from_user_id, result.to_user_id), (result.to_user_id, result.from_user_id)
      on conflict do nothing;
  end if;
  return result;
end
$$;
create function public.get_profile_link_v1(p_reference text) returns jsonb
language sql stable as $$
  select jsonb_build_object('profile', jsonb_build_object(
    'display_name', display_name, 'username', username, 'avatar_url', avatar_url
  )) from public.users where lower(username) = lower(trim(leading '@' from p_reference))
$$;
`)

const migration = await fs.readFile(
  repoPath + 'supabase/migrations/20260917185300_people_discovery_v1.sql',
  'utf8'
)
await db.exec(migration)
const migrationV2 = await fs.readFile(
  repoPath + 'supabase/migrations/20260917214432_people_suggestions_v2.sql',
  'utf8'
)
await db.exec(migrationV2)

const actor = '91000000-0000-4000-8000-000000000001'
const candidate = '91000000-0000-4000-8000-000000000002'
const interactionCandidate = '91000000-0000-4000-8000-000000000003'
await db.exec(`
insert into auth.users(id) values ('${actor}'), ('${candidate}'), ('${interactionCandidate}');
insert into public.users(id, display_name, username) values
  ('${actor}', 'Alex', 'alex'), ('${candidate}', 'Bea', 'bea'),
  ('${interactionCandidate}', 'Cam', 'cam');
select set_config('request.jwt.claims', '{"sub":"${actor}"}', false);
`)

const capabilities = (await db.query('select * from public.get_people_discovery_capabilities_v1()')).rows[0]
assert.deepEqual(capabilities, {
  contact_matching: false,
  invitations: false,
  suggestions: false,
  first_week_prompt: false
})
await assert.rejects(
  db.query("select * from public.create_friend_invite_v1('92000000-0000-4000-8000-000000000099')"),
  /invitations unavailable/
)
await db.exec(`update private.discovery_capabilities set enabled = true`)

let preference = (await db.query('select * from public.get_discovery_preferences_v1()')).rows[0]
assert.equal(preference.version, 0)
assert.equal(preference.email_discoverable, false)
assert.equal(preference.suggestions_enabled, true)
assert.equal(preference.mutual_explanations_enabled, true)
preference = (await db.query(
  'select * from public.set_discovery_preferences_v1(true,true,true,1,$1)',
  [preference.version]
)).rows[0]
assert.equal(preference.version, 1)
assert.equal(preference.suggestions_enabled, true)

await db.exec(`
select set_config('request.jwt.claims', '{"sub":"${candidate}"}', false);
select * from public.set_discovery_preferences_v1(false,true,true,1,null);
insert into public.cafe_list_members(list_id,user_id) values
  ('93000000-0000-4000-8000-000000000001','${actor}'),
  ('93000000-0000-4000-8000-000000000001','${candidate}');
insert into public.visits(id,user_id) values
  ('94000000-0000-4000-8000-000000000001','${actor}');
insert into public.likes(user_id,visit_id) values
  ('${interactionCandidate}','94000000-0000-4000-8000-000000000001');
select set_config('request.jwt.claims', '{"sub":"${actor}"}', false);
`)
const suggestions = (await db.query('select * from public.get_people_suggestions_v1(10)')).rows
assert.equal(suggestions[0].id, interactionCandidate)
assert.equal(suggestions[0].reason, 'interacted_with_you')
assert.equal(suggestions[0].ranking_version, 'people_v2')
assert.equal(suggestions[1].id, candidate)
assert.equal(suggestions[1].reason, 'shared_list')
const hub = (await db.query('select public.get_people_hub_v1(20) as payload')).rows[0].payload
assert.equal(hub.suggestions[0].username, 'cam')
assert.deepEqual(hub.partial_errors, {})

await db.exec(`
  select set_config('request.jwt.claims', '{"sub":"${interactionCandidate}"}', false);
  select * from public.set_discovery_preferences_v1(false,false,true,1,null);
  select set_config('request.jwt.claims', '{"sub":"${actor}"}', false);
`)
assert.equal(
  (await db.query('select count(*)::int count from public.get_people_suggestions_v1(10) where id=$1', [interactionCandidate])).rows[0].count,
  0
)

const digestValue = 'a'.repeat(64)
await db.query(
  'select public.service_set_discovery_email_v1($1,$2,1,now())',
  [actor, digestValue]
)
assert.equal((await db.query(
  'select has_discovery_email from public.get_discovery_preferences_v1()'
)).rows[0].has_discovery_email, true)

const searchRows = (await db.query("select * from public.search_people_v2('bea')")).rows
assert.equal(searchRows.length, 1)
assert.equal(searchRows[0].username, 'bea')

const invite = (await db.query(
  "select * from public.create_friend_invite_v1('92000000-0000-4000-8000-000000000001')"
)).rows[0]
assert.match(invite.token, /^[A-Za-z0-9_-]{40,64}$/)
assert.match(invite.code, /^[A-Z2-9]{4}-[A-Z2-9]{4}-[A-Z2-9]{4}$/)
assert.equal((await db.query(
  'select username from public.get_friend_invite_landing_v1($1)', [invite.token]
)).rows[0].username, 'alex')

await db.exec(`select set_config('request.jwt.claims', '{"sub":"${candidate}"}', false)`)
const resolved = (await db.query(
  'select * from public.resolve_friend_invite_v1($1)', [invite.code]
)).rows[0]
assert.equal(resolved.user_id, actor)
await assert.rejects(
  db.query(
    "select public.send_friend_request_v2($1,'invite_code',$2,$3)",
    [actor, '92000000-0000-4000-8000-000000000098', '92000000-0000-4000-8000-000000000099']
  ),
  /invalid invitation attribution/
)

const request = (await db.query(
  "select (public.send_friend_request_v2($1,'invite_code',$2,$3)).*",
  [actor, '92000000-0000-4000-8000-000000000002', invite.invite_id]
)).rows[0]
assert.equal(request.status, 'pending')

await db.exec(`select set_config('request.jwt.claims', '{"sub":"${actor}"}', false)`)
const accepted = (await db.query(
  'select (public.respond_friend_request_v2($1,true)).*', [request.id]
)).rows[0]
assert.equal(accepted.status, 'accepted')
assert.equal((await db.query(
  'select first_friend_source from private.friend_discovery_state where user_id=$1',
  [candidate]
)).rows[0].first_friend_source, 'invite_code')

const grants = (await db.query(`
select
  has_function_privilege('anon','public.get_friend_invite_landing_v1(text)','execute') as landing_anon,
  has_function_privilege('anon','public.search_people_v2(text,integer,integer,real,text,uuid)','execute') as search_anon,
  has_function_privilege('authenticated','public.search_people_v2(text,integer,integer,real,text,uuid)','execute') as search_user,
  has_function_privilege('authenticated','public.service_match_discovery_digests_v1(uuid,text[],integer)','execute') as service_user,
  has_function_privilege('service_role','public.service_match_discovery_digests_v1(uuid,text[],integer)','execute') as service_worker
`)).rows[0]
assert.deepEqual(grants, {
  landing_anon: true,
  search_anon: false,
  search_user: true,
  service_user: false,
  service_worker: true
})

await db.close()
console.log('People discovery v1 migration and caller-bound contracts verified.')
