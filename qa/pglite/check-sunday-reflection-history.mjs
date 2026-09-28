import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const owner = '10000000-0000-4000-8000-000000000001'
const stranger = '10000000-0000-4000-8000-000000000002'
const delivered = '20000000-0000-4000-8000-000000000001'
const pending = '20000000-0000-4000-8000-000000000002'

try {
  await db.exec(`
    create role anon;
    create role authenticated;
    create schema auth;
    create schema private;
    create function auth.uid() returns uuid language sql stable as
      $$select nullif(current_setting('test.actor', true), '')::uuid$$;
    create table private.reflection_reminder_occurrences(
      id uuid primary key, user_id uuid not null, reminder_kind text not null,
      scheduled_at timestamptz not null, timezone_name text not null,
      target_visit_id uuid
    );
    create table private.reflection_reminder_deliveries(
      id uuid primary key, occurrence_id uuid not null,
      device_record_id uuid not null, status text not null,
      completed_at timestamptz
    );
    insert into private.reflection_reminder_occurrences values
      ('${delivered}', '${owner}', 'weekly_reflection',
       '2026-09-27 22:00:00+00', 'America/New_York', null),
      ('${pending}', '${owner}', 'weekly_reflection',
       '2026-09-20 22:00:00+00', 'America/New_York', null);
    insert into private.reflection_reminder_deliveries values
      ('30000000-0000-4000-8000-000000000001', '${delivered}',
       '40000000-0000-4000-8000-000000000001', 'sent',
       '2026-09-27 22:00:04+00'),
      ('30000000-0000-4000-8000-000000000002', '${pending}',
       '40000000-0000-4000-8000-000000000001', 'pending', null);
  `)
  await db.exec(await fs.readFile(
    new URL('../../supabase/migrations/20260928205407_sunday_reflection_history.sql', import.meta.url),
    'utf8'
  ))

  await db.query("select set_config('test.actor', $1, false)", [owner])
  await db.exec('set role authenticated')
  let rows = (await db.query('select * from public.list_reflection_reminders_v1()')).rows
  assert.equal(rows.length, 1, 'only delivered reminders appear')
  assert.equal(rows[0].occurrence_id, delivered)
  assert.ok(rows[0].delivered_at, 'past sent delivery was backfilled')

  await db.exec('reset role')
  await db.query(`update private.reflection_reminder_deliveries
    set status='sent', completed_at='2026-09-20 22:00:05+00'
    where occurrence_id=$1`, [pending])
  await db.exec('delete from private.reflection_reminder_deliveries')
  await db.exec('set role authenticated')
  rows = (await db.query('select * from public.list_reflection_reminders_v1()')).rows
  assert.equal(rows.length, 2, 'history survives removal of device deliveries')
  assert.equal((await db.query(
    'select count(*)::integer as count from public.list_reflection_reminders_v1(1, $1)',
    [pending]
  )).rows[0].count, 1, 'a tapped occurrence can be looked up directly')

  await db.exec('reset role')
  await db.query("select set_config('test.actor', $1, false)", [stranger])
  await db.exec('set role authenticated')
  assert.equal((await db.query(
    'select count(*)::integer as count from public.list_reflection_reminders_v1()'
  )).rows[0].count, 0, 'another account cannot read reminders')
  await db.exec('reset role')
  await db.exec('set role anon')
  await assert.rejects(db.query('select * from public.list_reflection_reminders_v1()'))
  console.log('PASS: delivered-only history, backfill, device-independent persistence, owner isolation, anon denial')
} finally {
  await db.close()
}
