import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const migration = await fs.readFile(
  new URL('../../supabase/migrations/20260914191634_reflection_reminders_v2.sql', import.meta.url),
  'utf8',
)
const collapseMigration = await fs.readFile(
  new URL('../../supabase/migrations/20260914204700_bound_reflection_collapse_identifier.sql', import.meta.url),
  'utf8',
)
const ids = {
  owner: '10000000-0000-4000-8000-000000000101',
  leapOwner: '10000000-0000-4000-8000-000000000102',
  unsupported: '10000000-0000-4000-8000-000000000103',
  dstOwner: '10000000-0000-4000-8000-000000000104',
  emptyOwner: '10000000-0000-4000-8000-000000000105',
  device: '20000000-0000-4000-8000-000000000101',
  leapDevice: '20000000-0000-4000-8000-000000000102',
  unsupportedDevice: '20000000-0000-4000-8000-000000000103',
  dstDevice: '20000000-0000-4000-8000-000000000104',
  emptyDevice: '20000000-0000-4000-8000-000000000105',
  recentMemory: '30000000-0000-4000-8000-000000000101',
  olderMemory: '30000000-0000-4000-8000-000000000102',
  weeklyVisit: '30000000-0000-4000-8000-000000000103',
  leapMemory: '30000000-0000-4000-8000-000000000104',
  dstMemory: '30000000-0000-4000-8000-000000000105',
  currentWeeklyVisit: '30000000-0000-4000-8000-000000000106',
}

const asUser = async (userID, sql) => {
  await db.query("select set_config('test.actor', $1, false)", [userID])
  await db.query("select set_config('test.role', 'authenticated', false)")
  return db.query(sql)
}
const asService = async (sql) => {
  await db.query("select set_config('test.actor', '', false)")
  await db.query("select set_config('test.role', 'service_role', false)")
  return db.query(sql)
}

try {
  await db.exec(`
    create role anon;
    create role authenticated;
    create role service_role;
    create schema auth;
    create schema private;
    create schema cron;
    create schema net;
    create schema vault;
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('test.actor', true), '')::uuid$$;
    create function auth.role() returns text language sql stable as
      $$select nullif(current_setting('test.role', true), '')$$;
    create function private.is_live_account_as(actor uuid) returns boolean
      language sql stable as $$select actor is not null$$;
    create table public.users(id uuid primary key);
    create table public.visits(
      id uuid primary key,
      user_id uuid not null references public.users(id) on delete cascade,
      upload_state text not null,
      created_at timestamptz not null
    );
    create table public.visit_v3_reflections(
      visit_id uuid primary key references public.visits(id) on delete cascade,
      user_id uuid not null references public.users(id) on delete cascade,
      mugshot_score numeric not null
    );
    create table public.user_reflection_preferences(
      user_id uuid primary key references public.users(id) on delete cascade,
      monthly_recaps boolean not null default false,
      yearly_recaps boolean not null default false,
      on_this_sip_reminders boolean not null default false,
      reflection_reminders boolean not null default false,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    );
    create table public.notification_preferences(
      user_id uuid primary key references public.users(id) on delete cascade,
      push_enabled boolean not null default false
    );
    create table public.user_devices(
      id uuid primary key default gen_random_uuid(),
      user_id uuid not null references public.users(id) on delete cascade,
      device_id uuid,
      push_token text not null,
      environment text not null,
      disabled_at timestamptz,
      last_seen_at timestamptz,
      created_at timestamptz not null default now(),
      updated_at timestamptz not null default now()
    );
    create table vault.decrypted_secrets(name text primary key, decrypted_secret text);
    create table cron.job(jobid bigint generated always as identity primary key, jobname text, command text);
    create function cron.schedule(job_name text, schedule text, command text) returns bigint
      language plpgsql as $$declare result bigint; begin
        insert into cron.job(jobname, command) values(job_name, command) returning jobid into result;
        return result;
      end$$;
    create function cron.unschedule(job_id bigint) returns boolean language plpgsql as $$begin
      delete from cron.job where jobid=job_id; return found;
    end$$;
    create function net.http_post(
      url text, body jsonb default '{}'::jsonb, params jsonb default '{}'::jsonb,
      headers jsonb default '{}'::jsonb, timeout_milliseconds integer default 1000
    ) returns bigint language sql as $$select 1::bigint$$;
  `)
  await db.exec(migration)
  await db.exec(collapseMigration)
  await db.exec(`
    insert into public.users(id) values
      ('${ids.owner}'), ('${ids.leapOwner}'), ('${ids.unsupported}'),
      ('${ids.dstOwner}'), ('${ids.emptyOwner}');
    insert into public.notification_preferences(user_id, push_enabled) values
      ('${ids.owner}', true), ('${ids.leapOwner}', true), ('${ids.unsupported}', true),
      ('${ids.dstOwner}', true), ('${ids.emptyOwner}', true);
    insert into public.user_devices(id,user_id,device_id,push_token,environment) values
      ('${ids.device}','${ids.owner}','${ids.device}','${'a'.repeat(64)}','production'),
      ('${ids.leapDevice}','${ids.leapOwner}','${ids.leapDevice}','${'b'.repeat(64)}','production'),
      ('${ids.unsupportedDevice}','${ids.unsupported}','${ids.unsupportedDevice}','${'c'.repeat(64)}','production'),
      ('${ids.dstDevice}','${ids.dstOwner}','${ids.dstDevice}','${'d'.repeat(64)}','production'),
      ('${ids.emptyDevice}','${ids.emptyOwner}','${ids.emptyDevice}','${'e'.repeat(64)}','production');
    insert into public.visits(id,user_id,upload_state,created_at) values
      ('${ids.recentMemory}','${ids.owner}','complete','2025-09-14T14:30:00Z'),
      ('${ids.olderMemory}','${ids.owner}','complete','2024-09-14T18:30:00Z'),
      ('${ids.weeklyVisit}','${ids.owner}','complete','2026-09-10T16:00:00Z'),
      ('${ids.leapMemory}','${ids.leapOwner}','complete','2024-02-29T12:00:00Z'),
      ('${ids.dstMemory}','${ids.dstOwner}','complete','2025-03-08T15:00:00Z'),
      ('${ids.currentWeeklyVisit}','${ids.owner}','complete','2026-09-18T16:00:00Z');
    insert into public.visit_v3_reflections(visit_id,user_id,mugshot_score) values
      ('${ids.recentMemory}','${ids.owner}',3.7),
      ('${ids.leapMemory}','${ids.leapOwner}',4.8);
  `)

  const legacy = await asUser(ids.owner, 'select * from public.get_reflection_preferences_v2()')
  assert.equal(legacy.rows[0].delivery_activated, false)
  const ownScores = await asUser(ids.owner, `
    select * from public.get_owned_visit_map_scores_v1(
      array['${ids.recentMemory}'::uuid,'${ids.leapMemory}'::uuid]
    )
  `)
  assert.deepEqual(ownScores.rows, [{ visit_id: ids.recentMemory, mugshot_score: '3.7' }])
  await asUser(ids.owner, `
    select public.set_reflection_preferences_v2(false,false,true,true,'America/New_York',true,1)
  `)
  await asUser(ids.owner, `
    select public.set_reflection_device_capability_v1('${ids.device}','America/New_York',true)
  `)
  await asUser(ids.leapOwner, `
    select public.set_reflection_preferences_v2(false,false,true,false,'UTC',true,1)
  `)
  await asUser(ids.leapOwner, `
    select public.set_reflection_device_capability_v1('${ids.leapDevice}','UTC',true)
  `)
  await asUser(ids.unsupported, `
    select public.set_reflection_preferences_v2(false,false,true,true,'UTC',true,1)
  `)
  await asUser(ids.dstOwner, `
    select public.set_reflection_preferences_v2(false,false,true,false,'America/New_York',true,1)
  `)
  await asUser(ids.dstOwner, `
    select public.set_reflection_device_capability_v1('${ids.dstDevice}','America/New_York',true)
  `)
  await asUser(ids.emptyOwner, `
    select public.set_reflection_preferences_v2(false,false,false,true,'America/New_York',true,1)
  `)
  await asUser(ids.emptyOwner, `
    select public.set_reflection_device_capability_v1('${ids.emptyDevice}','America/New_York',true)
  `)

  let result = await asService("select public.enqueue_reflection_reminders_v1('2026-09-14T14:05:00Z') value")
  assert.equal(result.rows[0].value, 0, 'disabled rollout switch enqueued work')
  await db.exec('update private.reflection_delivery_control set enabled=true where singleton')
  result = await asService("select public.enqueue_reflection_reminders_v1('2026-09-14T14:05:00Z') value")
  assert.equal(result.rows[0].value, 1)
  const occurrence = (await db.query(`
    select * from private.reflection_reminder_occurrences where user_id='${ids.owner}'
  `)).rows[0]
  assert.equal(occurrence.target_visit_id, ids.recentMemory)
  assert.equal(occurrence.reminder_kind, 'on_this_day')
  result = await asService("select public.enqueue_reflection_reminders_v1('2026-09-14T14:10:00Z') value")
  assert.equal(result.rows[0].value, 0, 'duplicate scheduler run created another delivery')
  assert.equal(
    Number((await db.query(`select count(*) n from private.reflection_reminder_occurrences where user_id='${ids.unsupported}'`)).rows[0].n),
    0,
  )

  result = await asService("select public.enqueue_reflection_reminders_v1('2026-03-08T13:59:00Z') value")
  assert.equal(result.rows[0].value, 0, 'DST occurrence was sent before local 10 AM')
  result = await asService("select public.enqueue_reflection_reminders_v1('2026-03-08T14:00:00Z') value")
  assert.equal(result.rows[0].value, 1, 'DST occurrence did not follow local 10 AM')

  // Claiming uses the database clock. Keep this fixture stable after the
  // anniversary delivery window on the wall clock has elapsed.
  await db.exec(`
    update private.reflection_reminder_occurrences
    set expires_at = now() + interval '6 hours'
    where user_id='${ids.owner}' and reminder_kind='on_this_day'
  `)
  let claim = await asService('select * from public.claim_reflection_reminder_batch_v1(25)')
  assert.equal(claim.rows.length, 1)
  assert.equal(claim.rows[0].title, 'A Mugshot to remember')
  assert.equal(claim.rows[0].body, 'Revisit a sip you saved on this day.')
  assert.equal(claim.rows[0].deep_link, `mugshot://reflection/memory/${ids.recentMemory}`)
  assert.equal(claim.rows[0].collapse_id, `reflection:${claim.rows[0].occurrence_id}`)
  assert.ok(Buffer.byteLength(claim.rows[0].collapse_id, 'utf8') <= 64)

  await asUser(ids.owner, `
    select public.set_reflection_preferences_v2(false,false,false,true,'America/New_York',true,1)
  `)
  const eligibility = await asService(`
    select public.revalidate_reflection_reminder_delivery_v1(
      '${claim.rows[0].delivery_id}','${claim.rows[0].claim_token}',${claim.rows[0].lease_version}
    ) value
  `)
  assert.equal(eligibility.rows[0].value.eligible, false)

  await asService("select public.enqueue_reflection_reminders_v1('2026-02-28T10:05:00Z')")
  assert.equal(
    Number((await db.query(`select count(*) n from private.reflection_reminder_occurrences where user_id='${ids.leapOwner}'`)).rows[0].n),
    0,
  )
  result = await asService("select public.enqueue_reflection_reminders_v1('2028-02-29T10:05:00Z') value")
  assert.equal(result.rows[0].value, 1)

  await asUser(ids.owner, `
    select public.set_reflection_preferences_v2(false,false,false,true,'America/New_York',true,1)
  `)
  result = await asService("select public.enqueue_reflection_reminders_v1('2026-09-20T22:05:00Z') value")
  assert.equal(result.rows[0].value, 1)
  const weekly = (await db.query(`
    select reminder_kind,target_visit_id from private.reflection_reminder_occurrences
    where user_id='${ids.owner}' and reminder_kind='weekly_reflection'
  `)).rows[0]
  assert.equal(weekly.reminder_kind, 'weekly_reflection')
  assert.equal(weekly.target_visit_id, null)
  assert.equal(
    Number((await db.query(`select count(*) n from private.reflection_reminder_occurrences where user_id='${ids.emptyOwner}'`)).rows[0].n),
    0,
    'empty week created a reminder',
  )

  claim = await asService('select * from public.claim_reflection_reminder_batch_v1(25)')
  const weeklyClaim = claim.rows.find(row => row.reminder_kind === 'weekly_reflection')
  assert.ok(weeklyClaim, 'weekly reminder was not claimable')
  result = await asService(`
    select public.complete_reflection_reminder_delivery_v1(
      '${weeklyClaim.delivery_id}','${weeklyClaim.claim_token}',${weeklyClaim.lease_version},
      'retryable','apns_timeout',60
    ) value
  `)
  assert.equal(result.rows[0].value, true)
  const retried = (await db.query(`
    select status,attempt_count,claim_token from private.reflection_reminder_deliveries
    where id='${weeklyClaim.delivery_id}'
  `)).rows[0]
  assert.equal(retried.status, 'pending')
  assert.equal(retried.attempt_count, 1)
  assert.equal(retried.claim_token, null)

  await db.exec(`
    with occurrence as (
      insert into private.reflection_reminder_occurrences(
        user_id,reminder_kind,local_occurrence_date,timezone_name,scheduled_at,expires_at,target_visit_id
      ) values(
        '${ids.owner}','on_this_day','2026-01-01','UTC',
        '2026-01-01T10:00:00Z','2026-01-01T16:00:00Z','${ids.olderMemory}'
      ) returning id
    )
    insert into private.reflection_reminder_deliveries(occurrence_id,device_record_id)
    select id,'${ids.device}' from occurrence;
  `)
  await asService('select * from public.claim_reflection_reminder_batch_v1(25)')
  const expired = (await db.query(`
    select delivery.status from private.reflection_reminder_deliveries delivery
    join private.reflection_reminder_occurrences occurrence on occurrence.id=delivery.occurrence_id
    where occurrence.local_occurrence_date='2026-01-01'
  `)).rows[0]
  assert.equal(expired.status, 'cancelled')

  await db.exec(`delete from public.users where id='${ids.leapOwner}'`)
  assert.equal(
    Number((await db.query(`select count(*) n from private.reflection_reminder_occurrences where user_id='${ids.leapOwner}'`)).rows[0].n),
    0,
  )
  console.log('PASS reflection reminders: explicit activation, timezone schedules, leap day, dedupe, privacy copy, capability, opt-out and deletion')
} catch (error) {
  console.error(error)
  process.exitCode = 1
} finally {
  await db.close()
}
