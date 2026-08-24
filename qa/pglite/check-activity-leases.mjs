import fs from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const repoPath = fileURLToPath(new URL('../../', import.meta.url))

await db.exec(String.raw`
create role anon;
create role authenticated;
create role service_role;
create schema private;
create table public.users (id uuid primary key);
create table public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  device_id uuid,
  push_token text not null,
  platform text not null default 'ios',
  environment text not null,
  last_seen_at timestamptz,
  disabled_at timestamptz,
  failure_count integer not null default 0,
  last_failure_at timestamptz,
  supports_badge_sync boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.activity_events (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.users(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  deep_link text not null,
  read_at timestamptz,
  suppressed_at timestamptz,
  created_at timestamptz not null default now()
);
create table private.activity_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  activity_event_id uuid not null references public.activity_events(id) on delete cascade,
  device_record_id uuid not null references public.user_devices(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending','processing','sent','failed','cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  available_at timestamptz not null default now(),
  claimed_at timestamptz,
  claim_token uuid,
  lease_version bigint not null default 0,
  completed_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(activity_event_id, device_record_id)
);
create table private.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  subject_kind text not null,
  subject_id uuid not null,
  action_kind text not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  revoked_at timestamptz
);
create function private.activity_recipient_is_eligible_v2(p_recipient uuid)
returns boolean language sql stable as $$
  select p_recipient is not null and not exists (
    select 1 from private.moderation_actions action
    where action.subject_kind = 'user'
      and action.subject_id = p_recipient
      and action.action_kind = 'account_suspended'
      and action.revoked_at is null
      and action.starts_at <= now()
      and (action.ends_at is null or action.ends_at > now())
  )
$$;
create function private.activity_kind_push_enabled(p_recipient uuid, p_kind text)
returns boolean language sql stable as $$ select true $$;
create function private.activity_event_is_visible(
  p_event public.activity_events,
  p_viewer uuid
) returns boolean language sql stable as $$
  select p_viewer = p_event.recipient_id and p_event.suppressed_at is null
$$;
`)

const migration = await fs.readFile(
  repoPath + 'supabase/migrations/20260722101000_alpha_activity_delivery_hardening.sql',
  'utf8',
)
const leaseStart = migration.indexOf(
  "update private.activity_push_deliveries delivery\nset\n  status = 'pending'",
)
const leaseEnd = migration.indexOf(
  '-- The unfenced protocol cannot be used by any service after this migration.',
)
if (leaseStart < 0 || leaseEnd <= leaseStart) {
  throw new Error('fenced lease section markers missing')
}
await db.exec(migration.slice(leaseStart, leaseEnd))

const badgeMigration = await fs.readFile(
  repoPath + 'supabase/migrations/20260824162710_activity_push_badge_v3.sql',
  'utf8',
)
const badgeRevalidationStart = badgeMigration.indexOf(
  '-- Badge-aware final revalidation.',
)
const badgeRevalidationEnd = badgeMigration.indexOf(
  '-- Backend capability contract.',
)
if (
  badgeRevalidationStart < 0 ||
  badgeRevalidationEnd <= badgeRevalidationStart
) {
  throw new Error('badge revalidation section markers missing')
}
await db.exec(
  badgeMigration.slice(badgeRevalidationStart, badgeRevalidationEnd),
)

const recipient = '91000000-0000-4000-8000-000000000001'
const event = '92000000-0000-4000-8000-000000000001'
const device = '93000000-0000-4000-8000-000000000001'
const delivery = '94000000-0000-4000-8000-000000000001'
await db.exec(`
insert into public.users(id) values ('${recipient}');
insert into public.activity_events(id,recipient_id,kind,title,body,deep_link)
values ('${event}','${recipient}','reaction','Title','Body','mugshot://activity');
insert into public.user_devices(
  id,user_id,device_id,push_token,environment
) values (
  '${device}','${recipient}','95000000-0000-4000-8000-000000000001',
  '${'a'.repeat(64)}','sandbox'
);
insert into private.activity_push_deliveries(
  id,activity_event_id,device_record_id
) values ('${delivery}','${event}','${device}');
`)

const first = await db.query('select * from public.claim_activity_push_batch_v2(10)')
if (first.rows.length !== 1 || !first.rows[0].claim_token || first.rows[0].lease_version !== 1) {
  throw new Error('first delivery lease was not fenced')
}
await db.exec(`
  update private.activity_push_deliveries
  set claimed_at=now() - interval '3 minutes'
  where id='${delivery}'
`)
const second = await db.query('select * from public.claim_activity_push_batch_v2(10)')
if (
  second.rows.length !== 1 ||
  second.rows[0].lease_version !== 2 ||
  second.rows[0].claim_token === first.rows[0].claim_token
) {
  throw new Error('reclaimed delivery did not advance its fence')
}
const stale = await db.query(`
  select public.complete_activity_push_delivery_v2(
    '${delivery}','${first.rows[0].claim_token}',${first.rows[0].lease_version},
    'unregistered','Unregistered',null
  ) completed
`)
if (stale.rows[0]?.completed !== false) {
  throw new Error('stale worker completed a newer lease')
}
let deviceState = await db.query(`select disabled_at from public.user_devices where id='${device}'`)
if (deviceState.rows[0]?.disabled_at !== null) {
  throw new Error('stale worker disabled a live installation')
}
const retry = await db.query(`
  select public.complete_activity_push_delivery_v2(
    '${delivery}','${second.rows[0].claim_token}',${second.rows[0].lease_version},
    'retryable','ServiceUnavailable',900
  ) completed
`)
if (retry.rows[0]?.completed !== true) throw new Error('current lease did not complete')
let deliveryState = await db.query(`
  select status,attempt_count,available_at from private.activity_push_deliveries
  where id='${delivery}'
`)
if (
  deliveryState.rows[0]?.status !== 'pending' ||
  deliveryState.rows[0]?.attempt_count !== 2 ||
  new Date(deliveryState.rows[0].available_at).getTime() < Date.now() + 890_000
) {
  throw new Error('durable retry delay was not preserved')
}

await db.exec(`
  update private.activity_push_deliveries set available_at=now() where id='${delivery}'
`)
const terminalClaim = await db.query('select * from public.claim_activity_push_batch_v2(10)')
await db.query(`
  select public.complete_activity_push_delivery_v2(
    '${delivery}','${terminalClaim.rows[0].claim_token}',${terminalClaim.rows[0].lease_version},
    'terminal','PayloadTooLarge',null
  )
`)
deliveryState = await db.query(`select status from private.activity_push_deliveries where id='${delivery}'`)
deviceState = await db.query(`select disabled_at from public.user_devices where id='${device}'`)
if (deliveryState.rows[0]?.status !== 'failed' || deviceState.rows[0]?.disabled_at !== null) {
  throw new Error('terminal payload failure disabled the installation or retried')
}

const event2 = '92000000-0000-4000-8000-000000000002'
const device2 = '93000000-0000-4000-8000-000000000002'
const delivery2 = '94000000-0000-4000-8000-000000000002'
await db.exec(`
insert into public.activity_events(id,recipient_id,kind,title,body,deep_link)
values ('${event2}','${recipient}','tag','Title','Body','mugshot://activity');
insert into public.user_devices(id,user_id,device_id,push_token,environment)
values ('${device2}','${recipient}','95000000-0000-4000-8000-000000000002',
        '${'b'.repeat(64)}','sandbox');
insert into private.activity_push_deliveries(id,activity_event_id,device_record_id)
values ('${delivery2}','${event2}','${device2}');
`)
const unregisterClaim = await db.query('select * from public.claim_activity_push_batch_v2(10)')
await db.query(`
  select public.complete_activity_push_delivery_v2(
    '${delivery2}','${unregisterClaim.rows[0].claim_token}',${unregisterClaim.rows[0].lease_version},
    'unregistered','Unregistered',null
  )
`)
deviceState = await db.query(`select disabled_at from public.user_devices where id='${device2}'`)
if (!deviceState.rows[0]?.disabled_at) throw new Error('Unregistered did not disable the device')

const event3 = '92000000-0000-4000-8000-000000000003'
const device3 = '93000000-0000-4000-8000-000000000003'
const delivery3 = '94000000-0000-4000-8000-000000000003'
await db.exec(`
insert into public.activity_events(id,recipient_id,kind,title,body,deep_link)
values ('${event3}','${recipient}','like','Title','Body','mugshot://activity');
insert into public.user_devices(id,user_id,device_id,push_token,environment)
values ('${device3}','${recipient}','95000000-0000-4000-8000-000000000003',
        '${'c'.repeat(64)}','sandbox');
insert into private.activity_push_deliveries(
  id,activity_event_id,device_record_id,attempt_count
) values ('${delivery3}','${event3}','${device3}',11);
`)
const exhaustedClaim = await db.query('select * from public.claim_activity_push_batch_v2(10)')
await db.query(`
  select public.complete_activity_push_delivery_v2(
    '${delivery3}','${exhaustedClaim.rows[0].claim_token}',${exhaustedClaim.rows[0].lease_version},
    'retryable','ServiceUnavailable',900
  )
`)
deliveryState = await db.query(`select status from private.activity_push_deliveries where id='${delivery3}'`)
if (deliveryState.rows[0]?.status !== 'failed') {
  throw new Error('bounded retry exhaustion did not terminate')
}

const event4 = '92000000-0000-4000-8000-000000000004'
const device4 = '93000000-0000-4000-8000-000000000004'
const delivery4 = '94000000-0000-4000-8000-000000000004'
const suspension = '96000000-0000-4000-8000-000000000004'
await db.exec(`
insert into public.activity_events(id,recipient_id,kind,title,body,deep_link)
values ('${event4}','${recipient}','comment','Title','Body','mugshot://activity');
insert into public.user_devices(id,user_id,device_id,push_token,environment)
values ('${device4}','${recipient}','95000000-0000-4000-8000-000000000004',
        '${'d'.repeat(64)}','sandbox');
insert into private.activity_push_deliveries(id,activity_event_id,device_record_id)
values ('${delivery4}','${event4}','${device4}');
insert into private.moderation_actions(
  id,subject_kind,subject_id,action_kind,starts_at
) values (
  '${suspension}','user','${recipient}','account_suspended',now()+interval '1 hour'
);
`)
const futureSuspensionClaim = await db.query(
  'select * from public.claim_activity_push_batch_v2(10)',
)
if (futureSuspensionClaim.rows[0]?.delivery_id !== delivery4) {
  throw new Error('future suspension incorrectly prevented the initial claim')
}
await db.exec(`
update private.moderation_actions
set starts_at=now()+interval '20 seconds'
where id='${suspension}'
`)
const revalidated = await db.query(`
  select public.revalidate_activity_push_delivery_v2(
    '${delivery4}',
    '${futureSuspensionClaim.rows[0].claim_token}',
    ${futureSuspensionClaim.rows[0].lease_version}
  ) eligible
`)
if (revalidated.rows[0]?.eligible !== false) {
  throw new Error('imminent suspension remained eligible inside the APNs horizon')
}
deliveryState = await db.query(`
  select status,last_error_code from private.activity_push_deliveries
  where id='${delivery4}'
`)
if (
  deliveryState.rows[0]?.status !== 'cancelled' ||
  deliveryState.rows[0]?.last_error_code !== 'recipient_suspension_imminent'
) {
  throw new Error('pre-send suspension did not cancel the exact lease')
}

const badgeEvent = '92000000-0000-4000-8000-000000000005'
const otherUnreadEvent = '92000000-0000-4000-8000-000000000006'
const readEvent = '92000000-0000-4000-8000-000000000007'
const badgeDevice = '93000000-0000-4000-8000-000000000005'
const badgeDelivery = '94000000-0000-4000-8000-000000000005'
await db.exec(`
update public.activity_events set read_at=now();
delete from private.moderation_actions where id='${suspension}';
insert into public.activity_events(id,recipient_id,kind,title,body,deep_link)
values
  ('${badgeEvent}','${recipient}','friend_post','Title','Body','mugshot://activity'),
  ('${otherUnreadEvent}','${recipient}','tag','Title','Body','mugshot://activity');
insert into public.activity_events(
  id,recipient_id,kind,title,body,deep_link,read_at
) values (
  '${readEvent}','${recipient}','like','Title','Body','mugshot://activity',now()
);
insert into public.user_devices(
  id,user_id,device_id,push_token,environment,supports_badge_sync
) values (
  '${badgeDevice}','${recipient}','95000000-0000-4000-8000-000000000005',
  '${'e'.repeat(64)}','production',true
);
insert into private.activity_push_deliveries(
  id,activity_event_id,device_record_id
) values ('${badgeDelivery}','${badgeEvent}','${badgeDevice}');
`)
const badgeClaim = await db.query('select * from public.claim_activity_push_batch_v2(10)')
const badgeRevalidation = await db.query(`
  select public.revalidate_activity_push_delivery_v3(
    '${badgeDelivery}',
    '${badgeClaim.rows[0].claim_token}',
    ${badgeClaim.rows[0].lease_version}
  ) result
`)
if (
  badgeRevalidation.rows[0]?.result?.eligible !== true ||
  badgeRevalidation.rows[0]?.result?.unread_count !== 2 ||
  badgeRevalidation.rows[0]?.result?.supports_badge_sync !== true
) {
  throw new Error('v3 revalidation did not return the authoritative badge contract')
}

console.log('PGlite fenced lease, retry, invalidity, eligibility, and badge-count checks passed')
await db.close()
