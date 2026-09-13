import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
const db = new PGlite();
const owner='10000000-0000-4000-8000-000000000001', other='10000000-0000-4000-8000-000000000002';
const request='20000000-0000-4000-8000-000000000001', person='30000000-0000-4000-8000-000000000001';
try {
 await db.exec(`create role anon;create role authenticated;create role service_role;
 create schema private; create table public.users(id uuid primary key);
 create table private.account_deletion_jobs(id uuid primary key default gen_random_uuid(),request_id uuid,subject_id uuid,identity_deleted_at timestamptz);
 insert into public.users values('${owner}'),('${other}');`);
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913065006_sprint1_analytics_erasure_queue.sql',import.meta.url),'utf8'));
 const job=(await db.query('insert into private.account_deletion_jobs(request_id,subject_id) values($1,$2) returning id',[request,owner])).rows[0].id;
 const row=async()=>(await db.query('select * from private.account_analytics_erasures where request_id=$1',[request])).rows[0];
 const claim=async(limit=1)=>(await db.query('select * from public.claim_account_analytics_erasures_v1($1)',[limit])).rows[0];
 const prepare=async(lease,candidates=[])=>(await db.query('select public.prepare_account_analytics_erasure_v1($1,$2,$3,$4) as value',[request,lease,person,candidates])).rows[0].value;
 const finish=async(lease,outcome)=>(await db.query('select public.finish_account_analytics_erasure_v1($1,$2,$3) as value',[request,lease,outcome])).rows[0].value;
 assert.equal((await row()).owner_id,owner,'account ID durably queued before deletion');
 assert.equal(await claim(),undefined,'no processing before identity deletion');
 await db.query('update private.account_deletion_jobs set identity_deleted_at=now() where id=$1',[job]);
 await db.query('delete from public.users where id=$1',[owner]);
 await db.query('delete from private.account_deletion_jobs where id=$1',[job]);
 assert.equal((await row()).job_id,null,'cleanup survives job retention independently');
 assert.equal(await claim(0),undefined,'missing config does not spend attempts');
 assert.equal((await row()).attempts,0);
 let claimed=await claim();
 assert.equal(await claim(),undefined,'leases exclude concurrent provider work');
 assert.equal(await prepare(other),null,'stale lease cannot persist a target');
 assert.equal(await prepare(claimed.lease_token,[other]),null,'another existing account alias cannot be erased');
 assert.equal(await finish(claimed.lease_token,'verified'),false,'unprepared erasure cannot be marked verified');
 const submitted=await prepare(claimed.lease_token,[]);
 assert(submitted,'target and submission clock persist before provider mutation');
 assert.equal(await finish(other,'verified'),false,'stale completion is rejected');
 assert.equal(await finish(claimed.lease_token,'pending'),true);
 await db.exec("update private.account_analytics_erasures set available_at=now()-interval '1 second'");
 claimed=await claim();
 assert.equal(claimed.person_id,person,'retry retains verified provider target after person removal');
 assert.equal(await finish(claimed.lease_token,'verified'),true);
 assert.equal((await row()).owner_id,null);assert.equal((await row()).person_id,null);
 assert.equal((await row()).state,'verified');
 const grants=(await db.query(`select has_function_privilege('anon','public.claim_account_analytics_erasures_v1(integer)','execute') as anon,
 has_function_privilege('authenticated','public.finish_account_analytics_erasure_v1(uuid,uuid,text)','execute') as authenticated,
 has_function_privilege('service_role','public.claim_account_analytics_erasures_v1(integer)','execute') as service`)).rows[0];
 assert.deepEqual(grants,{anon:false,authenticated:false,service:true});
 console.log('PASS analytics erasure queue: identity gate, job survival, leases, alias isolation, durable target, completion and sealed grants');
} catch(error) {console.error(error.message);process.exitCode=1;} finally {await db.close();}
