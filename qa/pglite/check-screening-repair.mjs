import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
const db=new PGlite();
const owner='10000000-0000-4000-8000-000000000001',operator='10000000-0000-4000-8000-000000000002',id='20000000-0000-4000-8000-000000000001';
const apply=async name=>db.exec(await fs.readFile(new URL('../../supabase/migrations/'+name,import.meta.url),'utf8'));
try {
 await db.exec(`create role anon;create role authenticated;create role service_role;create schema private;create schema auth;
 create table public.users(id uuid primary key);insert into public.users values('${owner}'),('${operator}');
 create table private.moderation_operators(user_id uuid,is_active boolean,role text);insert into private.moderation_operators values('${operator}',true,'admin');
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 create function private.is_live_account_as(uuid) returns boolean language sql stable as $$select exists(select 1 from public.users where id=$1)$$;`);
 await apply('20260913025947_sprint1_screening_queue.sql');await apply('20260913045917_sprint1_screening_rate_limits.sql');
 await db.query('select private.enqueue_screening_v1($1,$2,$3,$4)',['visit',id,owner,{text:'Synthetic coffee',images:[]}]);
 await db.exec("update private.screening_jobs set state='needs_review',reason='provider_configuration',evidence='{\"reason\":\"provider_configuration\"}'");
 await apply('20260914023251_sprint1_existing_revision_visibility.sql');
 const revision=(await db.query('select revision from private.screening_jobs')).rows[0].revision;
 await apply('20260914043134_repair_screening_processing.sql');
 assert.equal((await db.query('select state,revision from private.screening_jobs')).rows[0].state,'pending');
 assert.equal((await db.query('select revision from private.screening_jobs')).rows[0].revision,revision);
 assert.equal((await db.query('select count(*)::int n from private.screening_processing_recovery')).rows[0].n,1);
 for(let n=0;n<5;n++){
 await db.exec("update private.screening_jobs set available_at=now()-interval '1 second'");
 const j=(await db.query('select * from public.claim_screening_jobs_v1(1)')).rows[0];
 assert.ok(j);
 await db.query('select public.finish_screening_job_v1($1,$2,$3,$4,$5,$6)',['visit',id,revision,j.lease_token,'retry',{reason:'invalid_input',diagnostics:{stage:'provider_request',http_status:400,error_code:'invalid_image'}}]);
 }
 assert.equal((await db.query('select state from private.screening_jobs')).rows[0].state,'service_error');
 assert.equal((await db.query('select private.screening_approved_v1($1,$2) visible',['visit',id])).rows[0].visible,true,'historical visibility preserved');
 await db.query("select set_config('test.actor',$1,false)",[operator]);
 assert.deepEqual((await db.query('select public.list_screening_review_v1() items')).rows[0].items,[],'no service failures in human queue');
 assert.equal((await db.query("select public.list_screening_review_v1(50,null,'service_error') items")).rows[0].items.length,1);
 await assert.rejects(db.query('select public.review_screening_v1($1,$2,$3,$4,$5,$6)',['visit',id,revision,'approved','',operator]),/policy decision/);
 await db.exec("update private.screening_jobs set state='needs_review',reason='provider_flag'");
 await assert.rejects(db.query('select public.review_screening_v1($1,$2,$3,$4,$5,$6)',['visit',id,revision,'rejected','',operator]),/reason required/);
 assert.equal((await db.query('select public.review_screening_v1($1,$2,$3,$4,$5,$6) ok',['visit',id,revision,'approved','',operator])).rows[0].ok,true);
 console.log('PASS screening repair: preserved recovery, bounded service failure, separate queues, review reason policy');
} finally {await db.close();}
