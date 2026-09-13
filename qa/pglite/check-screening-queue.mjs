import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'
const db=new PGlite()
const owner='10000000-0000-4000-8000-000000000001'
const moderator='10000000-0000-4000-8000-000000000002'
const subject='20000000-0000-4000-8000-000000000001'
const payload={text:'Synthetic coffee',images:[]}
try {
 await db.exec(`create role anon; create role authenticated; create role service_role;
 create schema private; create schema auth;
 create table public.users(id uuid primary key);
 insert into public.users values('${owner}'),('${moderator}');
 create table private.moderation_operators(user_id uuid, is_active boolean, role text default 'reviewer');
 insert into private.moderation_operators(user_id,is_active) values('${moderator}',true),('${owner}',true);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 create function private.is_live_account_as(id uuid) returns boolean language sql stable as $$select exists(select 1 from public.users where users.id=$1)$$;`)
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913025947_sprint1_screening_queue.sql',import.meta.url),'utf8'))
 const actor=(id)=>db.query("select set_config('test.actor',$1,false)",[id])
 const enqueue=(value)=>db.query('select private.enqueue_screening_v1($1,$2,$3,$4)', ['visit',subject,owner,value])
 const claim=async()=> (await db.query('select * from public.claim_screening_jobs_v1(1)')).rows[0]
 const finish=async(job,state='approved',evidence={model:'synthetic',categories:{sexual:false}})=>(await db.query('select public.finish_screening_job_v1($1,$2,$3,$4,$5,$6) as applied',['visit',subject,job.revision,job.lease_token,state,evidence])).rows[0].applied
 const status=async()=>(await db.query('select * from private.screening_jobs')).rows[0]
 await enqueue(payload)
 const first=await claim()
 assert.equal((await claim()),undefined,'active lease cannot be claimed twice')
 await enqueue(payload)
 assert.equal((await status()).revision,first.revision,'unrelated updates retain approval revision')
 await enqueue({...payload,text:'Edited synthetic coffee'})
 assert.notEqual((await status()).revision,first.revision)
 assert.equal(await finish(first),false,'stale revision cannot approve edit')
 const second=await claim()
 await db.exec("update private.screening_jobs set lease_until=now()-interval '1 second'")
 const third=await claim()
 assert.notEqual(third.lease_token,second.lease_token)
 assert.equal(await finish(second),false,'expired worker cannot commit after reclaim')
 assert.equal(await finish(third),true)
 assert.equal((await status()).state,'approved')
 await enqueue({...payload,text:'Private next'})
 const withdrawing=await claim()
 await enqueue(null)
 assert.equal(await finish(withdrawing),false,'privacy withdrawal deletes queued payload and invalidates result')
 assert.equal(await status(),undefined)
 await assert.rejects(enqueue({...payload,private_notes:'Never send'}),/invalid screening payload/)
 await enqueue(payload)
 let reviewJob=await claim()
 assert.equal(await finish(reviewJob,'needs_review',{reason:'provider_flag'}),true)
 await actor(owner)
 await assert.rejects(db.query('select public.review_screening_v1($1,$2,$3,$4,$5,$6)',['visit',subject,reviewJob.revision,'approved','Own content',owner]),/cannot review your own/)
 await actor(moderator)
 await assert.rejects(db.query('select public.review_screening_v1($1,$2,$3,$4,$5,$6)',['visit',subject,reviewJob.revision,'approved','Previous account',owner]),/account changed/)
 assert.equal((await db.query('select public.review_screening_v1($1,$2,$3,$4,$5,$6) as done',['visit',subject,reviewJob.revision,'rejected','Synthetic policy reason',moderator])).rows[0].done,true)
 assert.equal(await finish(reviewJob),false,'worker cannot overwrite human decision')
 await actor(owner)
 const appeal=()=>db.query('select public.request_screening_review_v1($1,$2,$3,$4,$5)',['visit',subject,reviewJob.revision,'Please reconsider this synthetic fixture',owner])
 await appeal();await appeal()
 assert.equal((await status()).state,'needs_review')
 assert.equal((await db.query("select count(*)::int as total from private.screening_review_events where decision='reconsideration'")).rows[0].total,1,'appeal is idempotent per revision')
 await enqueue({...payload,text:'Retry synthetic'})
 for(let i=0;i<5;i++) {
  await db.exec("update private.screening_jobs set available_at=now()-interval '1 second'")
  const leased=await claim()
  assert.equal(await finish(leased,'retry',{reason:'provider_unavailable'}),true)
 }
 assert.equal((await status()).state,'needs_review','five failures reach human review')
 assert.equal((await status()).reason,'screening_unavailable')
 // Reviewer pagination, history, owner receipts and revoked access use the real RPC bodies.
 await actor(moderator)
 const queue=async(cursor=null)=>(await db.query('select public.list_screening_review_v1(1,$1) as items',[cursor])).rows[0].items
 const minimalQueue=await queue()
 for(const field of ['payload','history','evidence','owner_id','lease_token']) assert(!Object.hasOwn(minimalQueue[0],field),'list must omit '+field)

 const page=await queue()
 assert.equal(page.length,1)
 assert.equal(page[0].self_review_conflict,false)
 assert.equal('lease_token' in page[0],false)
 const cursor={updated_at:page[0].updated_at,subject_kind:page[0].subject_kind,subject_id:page[0].subject_id}
 assert.deepEqual(await queue(cursor),[],'cursor does not repeat its boundary row')
 await assert.rejects(queue({updated_at:page[0].updated_at}),/complete queue cursor/)
 const preview=async(revision)=>(await db.query('select public.get_screening_review_item_v1($1,$2,$3) as item',['visit',subject,revision])).rows[0].item
 assert.equal((await preview(page[0].revision)).payload.text,'Retry synthetic')
 assert.equal(await preview(first.revision),null,'stale previews are unavailable')
 await actor(owner)
 const receipts=(await db.query('select public.my_screening_status_v1() as items')).rows[0].items
 assert.equal(receipts.length,1)
 assert.equal('payload' in receipts[0],false,'owner receipts do not duplicate raw content')
 await db.query('update private.moderation_operators set is_active=false where user_id=$1',[moderator])
 await actor(moderator)
 await assert.rejects(queue(),/moderation permission required/)
 await assert.rejects(preview(page[0].revision),/moderation permission required/)
 assert.equal((await db.query('select public.get_my_moderation_role_v1() as role')).rows[0].role,null)
 // Repeated crashes, as well as explicit retry responses, terminate in human review.
 await enqueue({...payload,text:'Crashed worker fixture'})
 for(let i=0;i<5;i++) {
  assert.ok(await claim())
  await db.exec("update private.screening_jobs set lease_until=now()-interval '1 second'")
 }
 assert.equal(await claim(),undefined)
 assert.equal((await status()).state,'needs_review')
 await actor('')
 await assert.rejects(db.query('select public.list_screening_review_v1()'),/moderation permission required/)
 await assert.rejects(db.query('select public.my_screening_status_v1()'),/authentication required/)
 for(const role of ['anon','authenticated']) {
  const permissions=(await db.query(`select has_table_privilege($1,'private.screening_jobs','select') as payload,
   has_function_privilege($1,'public.claim_screening_jobs_v1(integer)','execute') as worker,
   has_function_privilege($1,'private.enqueue_screening_v1(text,uuid,uuid,jsonb)','execute') as enqueue`,[role])).rows[0]
  assert.deepEqual(permissions,{payload:false,worker:false,enqueue:false})
 }
 await db.query('delete from public.users where id=$1',[owner])
 assert.equal(await status(),undefined,'account deletion removes queued payload')
 assert.equal((await db.query('select count(*)::int total from private.screening_review_events where subject_id=$1',[subject])).rows[0].total,0,'account deletion removes owned screening reasons and reconsideration text')
 console.log('PASS screening revisions, leases, privacy withdrawal, retries, human decisions, appeals, grants and deletion')
} finally {await db.close()}
