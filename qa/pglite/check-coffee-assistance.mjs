import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { randomUUID } from 'node:crypto'
import { PGlite } from '@electric-sql/pglite'

const db = new PGlite()
const owner = randomUUID(), other = randomUUID()
try {
  await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
    create schema auth; create table auth.users(id uuid primary key);
    create function auth.role() returns text language sql stable as $$select current_setting('request.jwt.claim.role', true)$$;
    grant usage on schema auth to service_role; grant select on auth.users to service_role;
    insert into auth.users values ('${owner}'), ('${other}');`)
  await db.exec(await fs.readFile(new URL('../../supabase/migrations/20261102160000_optional_coffee_assistance.sql', import.meta.url), 'utf8'))
  await db.exec("set role authenticated; select set_config('request.jwt.claim.role','authenticated',false)")
  await assert.rejects(db.query('select * from public.coffee_assistance_reservations'), /permission denied/)
  await assert.rejects(db.query('select public.reserve_coffee_assistance_v1($1,$2,$3)', [owner, randomUUID(), 'memory_search']), /permission denied/)
  await db.exec('reset role; set role anon')
  await assert.rejects(db.query('select * from public.coffee_assistance_reservations'), /permission denied/)
  await db.exec("reset role; set role service_role; select set_config('request.jwt.claim.role','service_role',false)")
  const reserve = async (actor, request, task = 'memory_search') =>
    (await db.query('select public.reserve_coffee_assistance_v1($1,$2,$3) as allowed', [actor, request, task])).rows[0].allowed
  const operation = randomUUID()
  assert.equal(await reserve(owner, operation), true)
  assert.equal(await reserve(owner, operation), false, 'same request cannot spend twice')
  assert.equal(await reserve(other, operation), false, 'request IDs are globally unique')
  assert.equal(await reserve(randomUUID(), randomUUID()), false, 'unknown accounts cannot reserve')
  assert.equal(await reserve(owner, randomUUID(), 'publish'), false)
  for (let i = 1; i < 20; i++) assert.equal(await reserve(owner, randomUUID()), true)
  assert.equal(await reserve(owner, randomUUID()), false, 'per-account daily cap is enforced')
  await db.exec('reset role')
  await db.exec('insert into auth.users select gen_random_uuid() from generate_series(1,149)')
  await db.exec("set role service_role; select set_config('request.jwt.claim.role','service_role',false)")
  const fill = await db.query(`select public.reserve_coffee_assistance_v1(u.id,gen_random_uuid(),'memory_search') as allowed
    from auth.users u cross join generate_series(1,20) where u.id not in ($1::uuid,$2::uuid)`, [owner, other])
  assert.equal(fill.rows.length,2980)
  assert.equal(fill.rows.every(x => x.allowed),true,'all admitted synthetic requests reserve through the real function')
  assert.equal(await reserve(other, randomUUID()), false, 'global monthly cap is enforced')
  await db.exec('reset role')
  const columns = (await db.query("select column_name from information_schema.columns where table_name='coffee_assistance_reservations' order by ordinal_position")).rows.map(x => x.column_name)
  assert.deepEqual(columns, ['request_id','user_id','task','created_at'], 'ledger contains no journal content')
  await db.query('delete from auth.users where id=$1', [owner])
  assert.equal((await db.query('select count(*)::int as n from public.coffee_assistance_reservations where user_id=$1', [owner])).rows[0].n, 0, 'account deletion clears usage receipts')
  await db.exec("set role service_role; select set_config('request.jwt.claim.role','service_role',false)")
  assert.equal(await reserve(other, randomUUID()),false,'deleting an account cannot free already spent global request budget')
  console.log('PASS optional coffee assistance: service-only ledger, owner and global quotas, deduplication, no content retention, deletion cascade')
} catch (error) { console.error(error.message); process.exitCode = 1 } finally { await db.close() }
