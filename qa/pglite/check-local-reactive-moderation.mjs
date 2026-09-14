import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
const db=new PGlite();
const owner='10000000-0000-4000-8000-000000000001';
const ids=Array.from({length:6},(_,i)=>`20000000-0000-4000-8000-${String(i+1).padStart(12,'0')}`);
const payload=text=>JSON.stringify({text,images:['mugshot-storage://visit-photos-private/missing.jpg']});
try {
 await db.exec(`create role anon;create role authenticated;create role service_role;create schema private;create table public.users(id uuid primary key);insert into public.users values('${owner}');`);
 const original=await fs.readFile(new URL('../../supabase/migrations/20260913025947_sprint1_screening_queue.sql',import.meta.url),'utf8');
 await db.exec(original.slice(0,original.indexOf('create function private.enqueue_screening_v1')));
 await db.exec("alter table private.screening_jobs drop constraint screening_jobs_state_check;alter table private.screening_jobs add check(state in ('pending','approved','needs_review','rejected','service_error')); ");
 for(const [i,state,reason] of [[0,'service_error','screening_unavailable'],[1,'needs_review','provider_flag'],[2,'rejected','human_review']]) {
  await db.query('insert into private.screening_jobs(subject_kind,subject_id,owner_id,payload,state,reason,evidence) values(\'visit\',$1,$2,$3,$4,$5,\'{"historical":true}\')',[ids[i],owner,payload('Matcha at Prophet Coffee'),state,reason]);
 }
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260914145946_local_text_and_reactive_moderation.sql',import.meta.url),'utf8'));
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260914151146_preserve_current_report_review_revision.sql',import.meta.url),'utf8'));
 const read=async id=>(await db.query('select * from private.screening_jobs where subject_id=$1',[id])).rows[0];
 const save=async(id,text)=>db.query("select private.enqueue_screening_v1('visit',$1,$2,$3)",[id,owner,text===null?null:payload(text)]);
 assert.equal((await read(ids[0])).reason,'reactive_policy_transition');
 assert.equal((await db.query('select previous_evidence from private.moderation_transition_receipts where subject_id=$1',[ids[0]])).rows[0].previous_evidence.historical,true);
 assert.equal((await read(ids[1])).state,'needs_review');assert.equal((await read(ids[2])).state,'rejected');
 await save(ids[3],'Fun woody interior, extremely unfun coffee. Scunthorpe cafe.');assert.equal((await read(ids[3])).reason,'local_text_filter');assert.equal((await read(ids[3])).evidence.photos,'report_driven');
 const before=await read(ids[3]);
 for(const text of ['I WILL KILL YOU!','ｉ ｗｉｌｌ ｋｉｌｌ ｙｏｕ','go   kill\nyourself']) {
  await assert.rejects(save(ids[3],text),/shared_text_not_allowed/);
  assert.deepEqual(await read(ids[3]),before,'failed edit preserves saved revision');
 }
 await assert.rejects(save(ids[4],'child pornography'),/shared_text_not_allowed/);assert.equal(await read(ids[4]),undefined,'invalid shared insert absent');
 await save(ids[3],null);assert.equal(await read(ids[3]),undefined,'private withdrawal leaves no payload');
 await save(ids[2],null);assert.equal(await read(ids[2]),undefined);await save(ids[2],'Harmless revised caption');assert.equal((await read(ids[2])).state,'rejected','Private roundtrip cannot bypass rejection');
 const oldFlagRevision=(await read(ids[1])).revision;await save(ids[1],'New caption');assert.equal((await read(ids[1])).payload.text,'New caption');assert.notEqual((await read(ids[1])).revision,oldFlagRevision);assert.equal((await read(ids[1])).state,'needs_review','real flag retained');
 assert.equal((await db.query('select * from public.claim_screening_jobs_v1(10)')).rows.length,0);
 assert.equal((await db.query('select private.dispatch_screening_worker_v1() result')).rows[0].result,null);
 await db.exec('set role authenticated');await assert.rejects(db.query('select * from private.moderation_text_rules'));await db.exec('reset role');
 console.log('PASS local/reactive moderation: harmless missing-photo post, Unicode/case/boundaries, rejected insert/edit rollback, Private exclusion, retained decisions and audit evidence, no external dispatch, private rules');
} finally {await db.close();}
