import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import {PGlite} from '@electric-sql/pglite'
const db=new PGlite()
try {
 await db.exec(`create role anon;create role authenticated;create role service_role;
 create schema private;create schema vault;create schema cron;create schema net;
 create table private.screening_jobs(state text,available_at timestamptz,lease_until timestamptz);
 create table vault.decrypted_secrets(name text,decrypted_secret text);
 create table cron.job(jobid bigserial primary key,jobname text unique,schedule text,command text);
 create table net.requests(url text,headers jsonb,body jsonb);
 create function cron.schedule(name text,timing text,sql text) returns bigint language plpgsql as $$declare id bigint;begin
 insert into cron.job(jobname,schedule,command) values(name,timing,sql) on conflict(jobname) do update set schedule=excluded.schedule,command=excluded.command returning jobid into id;return id;end;$$;
 create function cron.unschedule(id bigint) returns boolean language plpgsql as $$begin delete from cron.job where jobid=id;return found;end;$$;
 create function net.http_post(url text,headers jsonb,body jsonb,timeout_milliseconds integer) returns bigint language plpgsql as $$begin insert into net.requests values(url,headers,body);return 1;end;$$;`)
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913050301_sprint1_screening_schedule.sql',import.meta.url),'utf8'))
 const configure=enabled=>db.query('select public.configure_screening_schedule_v1($1)',[enabled])
 const dispatch=()=>db.query('select private.dispatch_screening_worker_v1()')
 assert.equal((await db.query('select * from cron.job')).rows.length,0,'migration does not activate processing')
 await assert.rejects(configure(true),/no rows/)
 await db.query('insert into vault.decrypted_secrets values($1,$2),($3,$4)', ['mugshot_screening_worker_url','https://abcdefghijklmnopqrst.supabase.co/functions/v1/screen-content','mugshot_screening_worker_secret','synthetic-worker-secret-32-characters'])
 await configure(true);await configure(true)
 const jobs=(await db.query('select * from cron.job')).rows
 assert.equal(jobs.length,1,'idempotent canonical schedule')
 assert.equal(jobs[0].schedule,'10 seconds')
 assert.ok(!jobs[0].command.includes('synthetic'),'no secret in scheduler command')
 await dispatch()
 assert.equal((await db.query('select * from net.requests')).rows.length,0,'empty queue makes no external call')
 await db.exec("insert into private.screening_jobs values('pending',now(),null)")
 await dispatch()
 assert.equal((await db.query('select * from net.requests')).rows.length,1)
 await db.exec("update vault.decrypted_secrets set decrypted_secret='https://evil.invalid' where name='mugshot_screening_worker_url'")
 await assert.rejects(dispatch(),/configuration invalid/)
 await assert.rejects(configure(true),/configuration invalid/)
 await configure(false)
 assert.equal((await db.query('select * from cron.job')).rows.length,0,'disable requires no valid secrets')
 for(const role of ['anon','authenticated']) assert.equal((await db.query("select has_function_privilege($1,'public.configure_screening_schedule_v1(boolean)','execute') allowed",[role])).rows[0].allowed,false)
 console.log('PASS screening scheduler: inactive migration, configuration gates, idempotency, secret isolation, empty-queue skip and disable')
}catch(error){console.error(error.message);process.exitCode=1}finally{await db.close()}
