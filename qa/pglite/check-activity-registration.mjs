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
create table auth.users (
  id uuid primary key,
  deleted_at timestamptz
);
create function auth.uid() returns uuid language sql stable as $$
  select nullif((current_setting('request.jwt.claims', true)::jsonb)->>'sub', '')::uuid
$$;
create function private.is_live_account_as(actor uuid) returns boolean
language sql stable as $$
  select actor is not null and exists (
    select 1 from auth.users where id = actor and deleted_at is null
  )
$$;
create table public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  push_token text not null unique,
  platform text not null default 'ios',
  device_id uuid,
  environment text,
  last_seen_at timestamptz,
  disabled_at timestamptz,
  failure_count integer not null default 0,
  last_failure_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index user_devices_user_installation_idx
  on public.user_devices(user_id, device_id) where device_id is not null;
`)

const migration = await fs.readFile(
  repoPath + 'supabase/migrations/20260722101000_alpha_activity_delivery_hardening.sql',
  'utf8',
)
const registrationEnd = migration.indexOf(
  '-- Suspended accounts keep settings, appeals, and export access',
)
if (registrationEnd < 0) throw new Error('registration section marker missing')
await db.exec(`${migration.slice(0, registrationEnd)}\ncommit;`)

const ids = {
  first: '81000000-0000-4000-8000-000000000001',
  second: '81000000-0000-4000-8000-000000000002',
  third: '81000000-0000-4000-8000-000000000003',
}
await db.exec(`insert into auth.users(id) values ('${ids.first}'),('${ids.second}'),('${ids.third}')`)

const asUser = async (id, sql) => {
  await db.exec(`select set_config('request.jwt.claims', '{"sub":"${id}"}', false)`)
  return db.query(sql)
}

const firstDevice = '82000000-0000-4000-8000-000000000001'
await asUser(ids.first, `
  select public.register_user_device_v2('${firstDevice}','${'a'.repeat(64)}','sandbox')
`)
await asUser(ids.first, `
  select public.register_user_device_v2('${firstDevice}','${'a'.repeat(64)}','sandbox')
`)
let window = await db.query(`
  select material_change_count
  from private.user_device_registration_windows
  where user_id='${ids.first}'
`)
if (window.rows[0]?.material_change_count !== 1) {
  throw new Error('idempotent device heartbeat spent the churn budget')
}

for (let index = 1; index <= 19; index += 1) {
  const token = index.toString(16).padStart(64, '0')
  await asUser(ids.first, `
    select public.register_user_device_v2('${firstDevice}','${token}','sandbox')
  `)
}
try {
  await asUser(ids.first, `
    select public.register_user_device_v2('${firstDevice}','${'f'.repeat(64)}','sandbox')
  `)
  throw new Error('material device registration churn was not rejected')
} catch (error) {
  if (!String(error).includes('too many device registration changes')) throw error
}
window = await db.query(`
  select material_change_count
  from private.user_device_registration_windows
  where user_id='${ids.first}'
`)
const retained = await db.query(`
  select push_token from public.user_devices
  where user_id='${ids.first}' and device_id='${firstDevice}'
`)
if (
  window.rows[0]?.material_change_count !== 20 ||
  retained.rows[0]?.push_token !== (19).toString(16).padStart(64, '0')
) {
  throw new Error('rejected churn changed durable registration state')
}

const lastKnownToken = (19).toString(16).padStart(64, '0')
const claimed = await asUser(ids.second, `
  select public.claim_user_device_installation_v2(
    '${firstDevice}','sandbox','${lastKnownToken}'
  ) claimed
`)
if (claimed.rows[0]?.claimed !== true) {
  throw new Error('installation ownership claim was not confirmed')
}
const staleOwnership = await db.query(`
  select count(*) stale_count from public.user_devices
  where user_id='${ids.first}'
    and (device_id='${firstDevice}' or push_token='${lastKnownToken}')
`)
if (staleOwnership.rows[0]?.stale_count !== 0) {
  throw new Error('installation claim retained a prior-account push binding')
}

await asUser(ids.second, `
  select public.register_user_device_v2(
    '84000000-0000-4000-8000-000000000001','${'b'.repeat(64)}','sandbox'
  )
`)
await asUser(ids.third, `
  select public.register_user_device_v2(
    '84000000-0000-4000-8000-000000000001','${'c'.repeat(64)}','sandbox'
  )
`)
const installationOwner = await db.query(`
  select user_id from public.user_devices
  where device_id='84000000-0000-4000-8000-000000000001'
`)
if (
  installationOwner.rows.length !== 1 ||
  installationOwner.rows[0]?.user_id !== ids.third
) {
  throw new Error('registration did not atomically replace prior installation ownership')
}

for (let index = 1; index <= 6; index += 1) {
  const deviceID = `83000000-0000-4000-8000-${index.toString().padStart(12, '0')}`
  const token = (100 + index).toString(16).padStart(64, '0')
  await asUser(ids.second, `
    select public.register_user_device_v2('${deviceID}','${token}','production')
  `)
}
const active = await db.query(`
  select count(*) active_count
  from public.user_devices
  where user_id='${ids.second}' and disabled_at is null
`)
if (active.rows[0]?.active_count !== 5) {
  throw new Error('active device cap did not prune deterministically')
}

console.log('PGlite device registration heartbeat, ownership claim, churn, and fanout-cap checks passed')
await db.close()
