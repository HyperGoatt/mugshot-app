import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import {PGlite} from '@electric-sql/pglite'
const db=new PGlite()
try {
 await db.exec(`create role anon;create role authenticated;create role service_role bypassrls;
 create table public.cafes(id uuid primary key default gen_random_uuid(),name text);
 alter table public.cafes enable row level security;
 grant select,insert,update on public.cafes to authenticated;grant select on public.cafes to anon;grant all on public.cafes to service_role;
 create policy "Cafes are readable by everyone" on public.cafes for select using(true);
 create policy "Authenticated users can write cafes" on public.cafes for insert to authenticated with check(true);
 create policy "Authenticated users can update cafes" on public.cafes for update to authenticated using(true) with check(true);
 insert into public.cafes(name) values('Existing synthetic cafe');`)
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913051130_sprint1_cafe_catalog_write_boundary.sql',import.meta.url),'utf8'))
 await db.exec('set role authenticated')
 await assert.rejects(db.exec("update public.cafes set name='Unauthorized change'"),/permission denied/)
 await db.exec("insert into public.cafes(name) values('New synthetic cafe')")
 assert.equal((await db.query('select * from public.cafes')).rows.length,2,'normal insert and resolve remain available')
 await db.exec('reset role;set role anon')
 assert.equal((await db.query('select * from public.cafes')).rows.length,2,'existing read access is unchanged')
 await assert.rejects(db.exec("update public.cafes set name='Unauthorized anonymous change'"),/permission denied/)
 await db.exec("reset role;set role service_role;update public.cafes set name='Server correction' where name='Existing synthetic cafe'")
 assert.equal((await db.query("select count(*)::int n from public.cafes where name='Server correction'")).rows[0].n,1,'trusted server maintenance remains possible')
 console.log('PASS cafe catalog boundary: client updates denied, insert/read preserved, server correction retained')
}catch(error){console.error(error.message);process.exitCode=1}finally{await db.close()}
