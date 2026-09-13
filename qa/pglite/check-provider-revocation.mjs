import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import {PGlite} from '@electric-sql/pglite'
const db=new PGlite()
const subject='10000000-0000-4000-8000-000000000001',request='20000000-0000-4000-8000-000000000001',challenge='30000000-0000-4000-8000-000000000001',session='40000000-0000-4000-8000-000000000001'
const encrypted={version:1,nonce:'synthetic-nonce',data:'synthetic-ciphertext'}
try {
 await db.exec(`create role anon;create role authenticated;create role service_role;create schema private;
 create table private.account_deletion_jobs(id uuid primary key default gen_random_uuid(),request_id uuid,subject_id uuid,identity_deleted_at timestamptz);
 create table private.account_deletion_step_up_challenges(id uuid,subject_id uuid,request_id uuid,authorized_session_id uuid,authorized_at timestamptz,authorization_expires_at timestamptz,superseded_at timestamptz,consumed_at timestamptz);
 insert into private.account_deletion_step_up_challenges values('${challenge}','${subject}','${request}','${session}',now(),now()+interval '10 minutes',null,null);`)
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913043824_sprint1_provider_revocation_queue.sql',import.meta.url),'utf8'))
 const stage=(sid=session,payload=encrypted)=>db.query('select public.stage_account_apple_revocation_v1($1,$2,$3,$4,$5,$6)',[challenge,subject,request,sid,'com.example.synthetic',payload])
 const row=async()=>(await db.query('select * from private.account_provider_revocations where request_id=$1',[request])).rows[0]
 const claim=async()=>(await db.query('select * from public.claim_account_apple_revocations_v1(1)')).rows[0]
 const finish=async(lease,revoked)=>(await db.query('select public.finish_account_apple_revocation_v1($1,$2,$3) as applied',[request,lease,revoked])).rows[0].applied
 await assert.rejects(stage(subject),/verified deletion challenge/)
 await assert.rejects(stage(session,{...encrypted,plaintext:'never store'}),/invalid encrypted credential/)
 await assert.rejects(stage(session,{...encrypted,version:'1'}),/invalid encrypted credential/)
 await stage();await stage()
 assert.equal((await row()).state,'staged')
 assert.equal(await claim(),undefined,'unconfirmed deletion cannot revoke an Apple authorization')
 const job=(await db.query('insert into private.account_deletion_jobs(request_id,subject_id) values($1,$2) returning id',[request,subject])).rows[0].id
 assert.equal((await row()).job_id,job)
 assert.equal((await row()).subject_id,null,'attachment drops the duplicate account identifier')
 assert.equal(await claim(),undefined,'provider cleanup waits for confirmed identity deletion')
 await db.query('update private.account_deletion_jobs set identity_deleted_at=now() where id=$1',[job])
 assert.equal((await db.query('select * from public.claim_account_apple_revocations_v1(0)')).rows.length,0,'housekeeping does not consume attempts')
 assert.equal((await row()).attempts,0)
 const status=async(jobID=job)=>(await db.query('select public.read_account_apple_revocation_status_v1($1,$2) as status',[request,jobID])).rows[0].status
 assert.equal(await status(),'pending')
 assert.equal(await status(subject),null,'a different job reveals no provider state')
 const first=await claim()
 assert.ok(first.lease_token)
 assert.equal(await claim(),undefined,'active leases cannot be claimed twice')
 await db.exec("update private.account_provider_revocations set lease_until=now()-interval '1 second'")
 const second=await claim()
 assert.notEqual(second.lease_token,first.lease_token)
 assert.equal(await finish(first.lease_token,true),false,'stale worker cannot wipe a reclaimed credential')
 assert.equal(await finish(second.lease_token,false),true)
 assert.equal((await row()).state,'pending')
 assert.deepEqual((await row()).ciphertext,encrypted,'failed revocation retains ciphertext for retry')
 await db.exec('update private.account_provider_revocations set available_at=now()')
 const third=await claim()
 assert.equal(await finish(third.lease_token,true),true)
 assert.equal((await row()).state,'revoked')
 assert.equal(await status(),'revoked')
 assert.equal((await row()).ciphertext,null,'success erases provider credential')
 assert.equal(await finish(third.lease_token,false),false,'late failure cannot overwrite success')
 await db.exec("update private.account_provider_revocations set state='pending',ciphertext='{}',expires_at=now()-interval '1 second'")
 assert.equal((await db.query('select * from public.claim_account_apple_revocations_v1(0)')).rows.length,0)
 assert.equal((await row()).state,'unavailable')
 assert.equal(await status(),'unavailable')
 assert.equal((await row()).ciphertext,null,'expired cleanup erases credentials without changing the deletion job')
 assert.ok((await db.query('select identity_deleted_at from private.account_deletion_jobs where id=$1',[job])).rows[0].identity_deleted_at)
 for(const role of ['anon','authenticated']) {
  assert.equal((await db.query("select has_function_privilege($1,'public.read_account_apple_revocation_status_v1(uuid,uuid)','execute') as allowed",[role])).rows[0].allowed,false)
  assert.equal((await db.query("select has_table_privilege($1,'private.account_provider_revocations','select') as allowed",[role])).rows[0].allowed,false)
  assert.equal((await db.query("select has_function_privilege($1,'public.claim_account_apple_revocations_v1(integer)','execute') as allowed",[role])).rows[0].allowed,false)
 }
 console.log('PASS encrypted provider queue: verified staging, deletion binding, lease fencing, retries, credential erasure and grants')
}catch(error){console.error(error.message);process.exitCode=1}finally{await db.close()}
