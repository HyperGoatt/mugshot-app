import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import pg from 'pg'
import { createMugsyFixture } from './mugsy-attention-fixture.mjs'
// Deliberately refuses TCP and every non-disposable database name. Never uses
// SUPABASE_URL, linked-project configuration or production credentials.
const host=process.env.MUGSY_TEST_SOCKET
if(!host?.startsWith('/tmp/mugsy-reminder-pg-socket-'))throw new Error('Explicit disposable local Unix socket required')
const config={host,port:55483,database:'mugsy_contracts',application_name:'mugsy-disposable-contracts'}
const a=new pg.Client(config),b=new pg.Client(config),ownerClient=new pg.Client(config)
const owner='10000000-0000-4000-8000-000000000111',device='20000000-0000-4000-8000-000000000111'
let checks=0
const eq=(x,y,m)=>{assert.deepEqual(x,y,m);checks++}
const q=async(client,sql,args=[]) => (await client.query(sql,args)).rows
const v=async(client,sql,args=[]) => (await q(client,sql,args))[0]?.result
try{
await Promise.all([a.connect(),b.connect(),ownerClient.connect()])
eq((await q(a,'select current_database() as name'))[0].name,'mugsy_contracts')
await a.query('drop schema if exists private cascade;drop schema if exists auth cascade;drop schema public cascade;create schema public;')
const adapter={query:(...args)=>a.query(...args),exec:sql=>a.query(sql.replaceAll(/create role (anon|authenticated|service_role);/g,(_,name)=>`do $$begin if not exists(select 1 from pg_roles where rolname='${name}') then create role ${name};end if;end$$;`))}
await createMugsyFixture(adapter)
await a.query(await fs.readFile(new URL('../../supabase/migrations/20261125120000_mugsy_attention_policy.sql',import.meta.url),'utf8'))
for(const client of [a,b])await client.query("select set_config('test.actor','',false),set_config('test.role','service_role',false)")
await ownerClient.query("select set_config('test.actor',$1,false),set_config('test.role','authenticated',false)",[owner])
await a.query(`insert into public.users values('${owner}');insert into public.notification_preferences values('${owner}',true);
insert into public.user_devices(id,user_id,device_id,push_token,environment,last_seen_at,mugsy_capability_version,mugsy_baseline_ready)values('${device}','${owner}','${device}','fixture','production',now(),1,true);`)
await v(ownerClient,'select public.get_mugsy_preferences_v1() as result')
await v(ownerClient,"select public.set_mugsy_preferences_v1(true,'standard',660,0,1440,'UTC',null,false,0,gen_random_uuid()) as result")
await a.query(`update private.mugsy_preferences set holdout=false,consented_at=now()-interval '20 days',created_at=now()-interval '20 days';update private.mugsy_delivery_control set mode='pilot',pilot_user_ids=array['${owner}'::uuid],shadow_started_at=now()-interval '8 days';update private.mugsy_preferences set attention_managed=true;`)
const add=key=>v(a,"select private.mugsy_add_opportunity($1,$2,'first_memory',50,now()-interval '1 minute',now()+interval '2 hours','mugshot://mugsy/log') as result",[owner,key])
await add('race-a');await add('race-b')
await a.query('begin')
const claimA=await q(a,'select * from public.claim_mugsy_batch_v1()')
eq(claimA.length,1,'first worker atomically reserves one optional slot')
let secondFinished=false
const waiting=q(b,'select * from public.claim_mugsy_batch_v1()').then(rows=>{secondFinished=true;return rows})
await new Promise(resolve=>setTimeout(resolve,80))
eq(secondFinished,false,'second worker waits on account budget lock')
await a.query('commit')
eq((await waiting).length,0,'racing worker cannot double reserve')
eq(await v(a,'select count(*)::int as result from private.mugsy_attention_ledger'),1)
const claim=claimA[0]
// Pause transaction wins the final dispatch boundary; worker waits rather than
// deadlocking due to an inverted opportunity/account lock order.
await ownerClient.query('begin')
await v(ownerClient,"select public.set_mugsy_preferences_v1(true,'standard',660,0,1440,'UTC',now()+interval '7 days',false,1,gen_random_uuid()) as result")
let validationFinished=false
const validation=v(b,"select public.revalidate_mugsy_delivery_v1($1,$2,$3,'first_memory_1') as result",[claim.delivery_id,claim.claim_token,claim.lease_version]).then(result=>{validationFinished=true;return result})
await new Promise(resolve=>setTimeout(resolve,80));eq(validationFinished,false)
await ownerClient.query('commit')
eq(await validation,{eligible:false},'pause committed before send cancels old lease')
// A delayed request from an old device cannot resurrect an acknowledged Home
// deletion, even after normal decision-history pruning.
const withdrawn='40000000-0000-4000-8000-000000000111'
await v(ownerClient,"select public.record_mugsy_memory_v1($1,'home',now()-interval '10 days') as result",[withdrawn])
await v(ownerClient,'select public.withdraw_mugsy_memory_v1($1) as result',[withdrawn])
await v(ownerClient,"select public.record_mugsy_memory_v1($1,'home',now()-interval '10 days') as result",[withdrawn])
eq(await v(a,'select count(*)::int as result from private.mugsy_memory_signals where user_id=$1 and memory_id=$2',[owner,withdrawn]),0)
eq(await v(a,'select count(*)::int as result from private.mugsy_withdrawals where user_id=$1 and memory_id=$2',[owner,withdrawn]),1)

const inFlight='40000000-0000-4000-8000-000000000112'
await ownerClient.query('begin')
await v(ownerClient,'select public.withdraw_mugsy_memory_v1($1) as result',[inFlight])
await b.query("select set_config('test.actor',$1,false),set_config('test.role','authenticated',false)",[owner])
let staleUpsertFinished=false
const staleUpsert=v(b,"select public.record_mugsy_memory_v1($1,'home',now()-interval '10 days') as result",[inFlight]).then(result=>{staleUpsertFinished=true;return result})
await new Promise(resolve=>setTimeout(resolve,80));eq(staleUpsertFinished,false,'in-flight other-device upsert waits for withdrawal transaction')
await ownerClient.query('commit');eq(await staleUpsert,true,'stale request is acknowledged without retry')
eq(await v(a,'select count(*)::int as result from private.mugsy_memory_signals where user_id=$1 and memory_id=$2',[owner,inFlight]),0,'concurrent upsert cannot resurrect a withdrawn ID')

// Removing a device or content does not erase attention history.
await a.query('delete from public.user_devices where id=$1',[device])
eq(await v(a,'select count(*)::int as result from private.mugsy_attention_ledger'),1,'device deletion preserves historical charges')
eq(await v(a,'select device_record_id is null as result from private.mugsy_attention_ledger'),true)
// Rollback cannot hand an enrolled account back to legacy optional senders.
await v(a,"select public.configure_mugsy_delivery_v1('off') as result")
eq(await v(a,'select private.mugsy_optional_owned($1) as result',[owner]),true,'managed ownership remains sticky after kill switch')
// Account erasure is the intended cascade boundary.
await a.query('delete from public.users where id=$1',[owner])
eq(await v(a,'select count(*)::int as result from private.mugsy_attention_ledger'),0)
eq(await v(a,'select count(*)::int as result from private.mugsy_withdrawals'),0,'account erasure removes tombstones')
console.log(`Mugsy PostgreSQL concurrency: ${checks} checks passed (two worker connections + owner preference transaction).`)
}catch(error){console.error(error.message);if(error.where)console.error(error.where);process.exitCode=1}
finally{await Promise.allSettled([a.end(),b.end(),ownerClient.end()])}
