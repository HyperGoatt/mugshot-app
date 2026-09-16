import fs from 'node:fs/promises'
import {PGlite} from '@electric-sql/pglite'
const db=new PGlite()
try {
 await db.exec(`create role anon;create role authenticated;create role service_role;create schema private;create schema auth;
 create table public.users(id uuid primary key);create table auth.users(id uuid,email text);
 insert into public.users values('00000000-0000-4000-8000-000000000101');
 insert into auth.users values('00000000-0000-4000-8000-000000000101','alpha-fixture-1@example.invalid');
 create table private.moderation_operators(user_id uuid,is_active boolean,role text);
 create function auth.uid() returns uuid language sql stable as $$select null::uuid$$;
 create function private.is_live_account_as(id uuid) returns boolean language sql stable as $$select true$$;`)
 for(const name of [
  '20260913025947_sprint1_screening_queue',
  '20260913045917_sprint1_screening_rate_limits',
  '20260914145946_local_text_and_reactive_moderation',
 ]) await db.exec(await fs.readFile(new URL(`../../supabase/migrations/${name}.sql`,import.meta.url),'utf8'))
 const source=await fs.readFile(new URL('../../supabase/tests/sprint1_screening_queue_contract.sql',import.meta.url),'utf8')
 await db.exec(source.replace(/^\s*\\[^\n]*(?:\n|$)/gm,''))
 console.log('PASS remote screening SQL contract in hermetic PostgreSQL; full-history remote run remains required')
}catch(error){console.error(error.message);process.exitCode=1}finally{await db.close()}
