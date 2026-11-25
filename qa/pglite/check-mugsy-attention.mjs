import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'
import { createMugsyFixture } from './mugsy-attention-fixture.mjs'
const db=new PGlite();let checks=0
const eq=(a,b,m)=>{assert.deepEqual(a,b,m);checks++}
const owner='10000000-0000-4000-8000-000000000101',other='10000000-0000-4000-8000-000000000102',device='20000000-0000-4000-8000-000000000101',device2='20000000-0000-4000-8000-000000000102',visit='30000000-0000-4000-8000-000000000101',home='40000000-0000-4000-8000-000000000101'
const user=async id=>db.query("select set_config('test.actor',$1,false),set_config('test.role','authenticated',false)",[id])
const service=async()=>db.query("select set_config('test.actor','',false),set_config('test.role','service_role',false)")
const value=async(sql,args=[]) => (await db.query(sql,args)).rows[0]?.result
const rejects=async(fn,code)=>{await assert.rejects(fn,e=>e.code===code);checks++}
try{
await createMugsyFixture(db)
if(!process.argv.includes('--red'))await db.exec(await fs.readFile(new URL('../../supabase/migrations/20261125193209_mugsy_attention_policy.sql',import.meta.url),'utf8'))
await db.exec(`insert into public.users values('${owner}'),('${other}');insert into public.notification_preferences values('${owner}',true),('${other}',true);
insert into public.user_devices(id,user_id,device_id,push_token,environment,last_seen_at) values('${device}','${owner}','${device}','aaa','production',now()),('${device2}','${other}','${device2}','bbb','production',now());`)
await user(owner)
const initial=await value('select public.get_mugsy_preferences_v1() as result')
eq(initial.mugsy_enabled,false);eq(initial.delivery_mode,'off');eq(initial.revision,0)
await db.query("select set_config('request.headers',$1,false)",[JSON.stringify({'x-mugshot-account-id':other})])
await rejects(()=>value('select public.get_mugsy_preferences_v1() as result'),'42501')
await db.query("select set_config('request.headers',$1,false)",[JSON.stringify({'x-mugshot-account-id':owner})])
eq((await value('select public.get_mugsy_preferences_v1() as result')).revision,0)
await db.query("select set_config('request.headers','{}',false)")
const request='50000000-0000-4000-8000-000000000101'
const save=`select public.set_mugsy_preferences_v1(true,'standard',660,0,1440,'UTC',null,false,0,'${request}') as result`
const saved=await value(save);eq(saved.revision,1);eq(await value(save),saved)
await rejects(()=>value(save.replace("'standard'","'light'")),'22023')
await rejects(()=>value(save.replace(request,'50000000-0000-4000-8000-000000000102')),'40001')
await rejects(()=>value("select public.set_mugsy_preferences_v1(true,'standard',660,0,1440,'Fake/Timezone',null,false,1,gen_random_uuid()) as result"),'22023')
await rejects(()=>value("select public.configure_mugsy_delivery_v1('live') as result"),'42501')
await service();await rejects(()=>value("select public.configure_mugsy_delivery_v1('pilot',array[$1::uuid]) as result",[owner]),'55000')
eq(await value("select public.configure_mugsy_delivery_v1('shadow') as result"),true)
await db.exec("update private.mugsy_delivery_control set shadow_started_at=now()-interval '8 days'")
eq(await value("select public.configure_mugsy_delivery_v1('pilot',array[$1::uuid]) as result",[owner]),true)
await user(owner);eq(await value("select public.set_mugsy_device_capability_v1($1,'UTC',1) as result",[device]),true)
eq(await value("select public.set_mugsy_device_capability_v1($1,'UTC',1) as result",[device2]),false)
await db.exec(`update private.mugsy_preferences set holdout=false,created_at=now()-interval '20 days',consented_at=now()-interval '20 days' where user_id='${owner}'`)
eq(await value("select private.mugsy_suppression_reason($1,'first_memory',now()) as result",[owner]),'completion_baseline_missing')
eq(await value('select public.record_mugsy_baseline_v1($1,true) as result',[device]),true)
eq(await value("select private.mugsy_suppression_reason($1,'first_memory',now()) as result",[owner]),null)
await value("select public.record_mugsy_memory_v1($1,'home',now()-interval '10 days') as result",[home]);await value("select public.record_mugsy_memory_v1($1,'home',now()) as result",[home])
eq(await value('select count(*)::int as result from private.mugsy_completed_memories($1)',[owner]),1)
eq(await value("select completed_at<now()-interval '9 days' as result from private.mugsy_completed_memories($1)",[owner]),true)
await db.query("insert into public.visits values($1,$2,'complete',now())",[visit,owner]);await value("select public.record_mugsy_memory_v1($1,'canonical',now()) as result",[visit]);await value("select public.record_mugsy_memory_v1($1,'home',now()-interval '10 days',$2) as result",[home,visit])
eq(await value('select count(*)::int as result from private.mugsy_completed_memories($1)',[owner]),1,'Home publication deduplicates')
eq(await value("select completed_at<now()-interval '9 days' as result from private.mugsy_completed_memories($1)",[owner]),true,'original completion retained')
await user(other);await rejects(()=>value("select public.record_mugsy_memory_v1($1,'canonical',now()) as result",[visit]),'42501')
eq(await value('select public.get_mugsy_notification_intent_v1(gen_random_uuid()) as result'),null)
await user(owner);eq(await value('select public.record_mugsy_activity_v1($1,true,true) as result',[device]),true)
eq(await value("select private.mugsy_suppression_reason($1,'second_memory',now()) as result",[owner]),'currently_active')
await value('select public.record_mugsy_activity_v1($1,false,false) as result',[device]);await service()
const add=async(key,kind='second_memory')=>value("select private.mugsy_add_opportunity($1,$2,$3,50,now()-interval '1 minute',now()+interval '2 hours','mugshot://mugsy/log') as result",[owner,key,kind])
await add('first');const claimed=(await db.query('select * from public.claim_mugsy_batch_v1()')).rows;eq(claimed.length,1);const c=claimed[0];eq(c.device_record_id,device)
eq(await value('select count(*)::int as result from private.mugsy_attention_ledger'),1)
eq(await value("select public.revalidate_mugsy_delivery_v1($1,$2,$3,'second_memory_1') as result",[c.delivery_id,c.claim_token,c.lease_version]),{eligible:true})
eq(await value("select public.complete_mugsy_delivery_v1($1,$2,$3,'unknown','apns_timeout') as result",[c.delivery_id,c.claim_token,c.lease_version]),true)
eq(await value("select public.complete_mugsy_delivery_v1($1,$2,$3,'succeeded') as result",[c.delivery_id,c.claim_token,c.lease_version]),false)
eq((await db.query('select * from public.claim_mugsy_batch_v1()')).rows.length,0)
eq(await value("select private.mugsy_suppression_reason($1,'second_memory',now()) as result",[owner]),'spacing')
await db.exec("update private.mugsy_attention_ledger set charged_at=now()-interval '8 days'")
eq(await value("select private.mugsy_suppression_reason($1,'second_memory',now()) as result",[owner]),'logging_cooldown')
await db.exec("update private.mugsy_attention_state set last_logging_attempt=now()-interval '8 days'")
eq(await value("select private.mugsy_suppression_reason($1,'second_memory',now()) as result",[owner]),null)
await add('second');const c2=(await db.query('select * from public.claim_mugsy_batch_v1()')).rows[0];eq(Boolean(c2),true)
eq(await value("select public.revalidate_mugsy_delivery_v1($1,$2,$3,'second_memory_1') as result",[c2.delivery_id,c2.claim_token,c2.lease_version]),{eligible:false,reason:'copy_cooldown'})
await db.exec("update private.mugsy_attention_ledger set charged_at=now()-interval '100 days';update private.mugsy_attention_state set last_logging_attempt=now()-interval '100 days'")
eq(await value("select private.mugsy_suppression_reason($1,'second_memory',now()) as result",[owner]),'logging_sunset')
await user(owner);await value("select public.record_mugsy_memory_v1(gen_random_uuid(),'home',now()) as result")
eq(await value("select private.mugsy_suppression_reason($1,'return_memory',now()) as result",[owner]),'recent_completion')
await service();await db.exec('delete from private.mugsy_attention_ledger')
await add('budget-a','weekly_pour');await add('budget-b','on_this_day');await add('budget-c','social_digest')
await db.exec("insert into private.mugsy_attention_ledger(opportunity_id,user_id,kind,charged_at) select id,user_id,kind,now()-interval '3 days' from private.mugsy_opportunities where opportunity_key like 'budget-%'")
eq(await value("select private.mugsy_suppression_reason($1,'weekly_pour',now()) as result",[owner]),'weekly_budget')
await db.exec(`update private.mugsy_preferences set pace='light' where user_id='${owner}';delete from private.mugsy_attention_ledger where kind<>'weekly_pour'`)
eq(await value("select private.mugsy_suppression_reason($1,'on_this_day',now()) as result",[owner]),'weekly_budget')
await db.exec(`delete from private.mugsy_attention_ledger;update private.mugsy_preferences set pace='standard',window_start_minute=540,window_end_minute=1140,timezone_name='America/New_York' where user_id='${owner}'`)
eq(await value("select private.mugsy_suppression_reason($1,'weekly_pour','2026-03-08T12:59:00Z') as result",[owner]),'quiet_hours')
eq(await value("select private.mugsy_suppression_reason($1,'weekly_pour','2026-03-08T13:00:00Z') as result",[owner]),null)
await db.exec(`update private.mugsy_preferences set timezone_name='UTC',window_start_minute=0,window_end_minute=1440 where user_id='${owner}'`)
await user(owner);eq((await value('select public.request_mugsy_nearby_permit_v1($1,gen_random_uuid()) as result',[device])).allowed,false)
await service();await db.exec(`insert into public.user_devices(user_id,device_id,push_token,environment,last_seen_at) values('${owner}',gen_random_uuid(),'legacy','production',now())`)
eq(await value('select private.mugsy_is_coordinated($1) as result',[owner]),false)
eq(await value("select private.mugsy_suppression_reason($1,'weekly_pour',now()) as result",[owner]),'legacy_installation')
eq(await value("select has_function_privilege('anon','public.get_mugsy_preferences_v1()','EXECUTE') as result"),false)
eq(await value("select has_function_privilege('authenticated','public.claim_mugsy_batch_v1(integer)','EXECUTE') as result"),false)
eq(await value("select has_table_privilege('authenticated','private.mugsy_attention_ledger','SELECT') as result"),false)
eq(await value("select has_function_privilege('authenticated','private.mugsy_suppression_reason(uuid,text,timestamptz,uuid)','EXECUTE') as result"),false)

await service();await db.exec(`update public.user_devices set disabled_at=now() where push_token='legacy';
update private.mugsy_preferences set attention_managed=true,pace='standard',paused_until=null,paused_indefinitely=false where user_id='${owner}';
update private.mugsy_attention_state set active_until=null,composing_until=null;delete from private.mugsy_attention_ledger;`)
// Canonical completion and memory date are separate: uploading an old memory
// today suppresses nudges today but does not move it into this week's recap.
const delayed='30000000-0000-4000-8000-000000000199'
await db.query("insert into public.visits values($1,$2,'complete',now()-interval '20 days')",[delayed,owner]);await user(owner)
await value("select public.record_mugsy_memory_v1($1,'canonical',now()) as result",[delayed])
eq(await value("select completed_at>now()-interval '1 minute' and memory_at<now()-interval '19 days' as result from private.mugsy_completed_memories($1) where memory_key=$2",[owner,delayed]),true)
const exportData=await value('select public.get_mugsy_owner_data_v1() as result');eq(exportData.version,1);eq(exportData.completion_signals.some(x=>x.memory_id===home),true)
await rejects(()=>value('select public.mugsy_retention_report_v1() as result'),'42501')
await service();eq((await value('select public.mugsy_retention_report_v1() as result')).definition_version,1)
// The delivery TTL has elapsed, but the accepted occurrence keeps its original
// weekly route for ninety days rather than silently retargeting a later week.
const late=await value(`insert into private.mugsy_opportunities(user_id,opportunity_key,kind,priority,scheduled_at,expires_at,week_end,preference_revision,status,deep_link,created_at)
values($1,'late-week','weekly_pour',20,now()-interval '2 days',now()-interval '1 day',now()-interval '2 days',1,'accepted','mugshot://mugsy/weekly?end=2026-11-22T18:00:00Z',now()-interval '2 days')returning id as result`,[owner])
await user(owner);const lateIntent=await value('select public.get_mugsy_notification_intent_v1($1) as result',[late]);eq(lateIntent.kind,'weekly_pour');eq(lateIntent.deep_link,'mugshot://mugsy/weekly?end=2026-11-22T18:00:00Z')
await user(other);eq(await value('select public.get_mugsy_notification_intent_v1($1) as result',[late]),null)
await service();await value("select public.configure_mugsy_delivery_v1('off') as result")
const lease='60000000-0000-4000-8000-000000000111'
async function legacyActivity(kind,key,recipient=owner,installation=device){
const event=await value("insert into public.activity_events(recipient_id,kind,title,body,deep_link)values($1,$2,'Fixture','Fixture',$3)returning id as result",[recipient,kind,'mugshot://visit/'+key])
const delivery=await value("insert into private.activity_push_deliveries(activity_event_id,device_record_id,status,claim_token,lease_version,claimed_at)values($1,$2,'processing',$3,1,now())returning id as result",[event,installation,lease])
return{event,delivery,result:await value('select public.revalidate_activity_push_delivery_v3($1,$2,1) as result',[delivery,lease])}}
eq((await legacyActivity('friend_post','ambient')).result.eligible,false,'kill switch cannot re-enable legacy ambient bypass')
eq((await legacyActivity('friend_post','ambient-other',other,device2)).result.eligible,true,'never-managed legacy behavior preserved')
const firstComment=await legacyActivity('comment','same-thread');eq(firstComment.result.eligible,true)
eq((await legacyActivity('comment','same-thread')).result.eligible,false,'same-thread comment grouped')
eq(await value("select count(*)::int as result from public.activity_events where kind='comment'"),2,'grouped Activity is retained')
eq(await value("select private.mugsy_suppression_reason($1,'weekly_pour',now()) as result",[owner]),'recent_direct_activity')
await db.query('delete from public.activity_events where id=$1',[firstComment.event])
eq(await value("select private.mugsy_suppression_reason($1,'weekly_pour',now()) as result",[owner]),'recent_direct_activity','deleting Activity does not erase collision charge')
await db.query('insert into public.user_reflection_preferences(user_id,delivery_activated,reflection_reminders)values($1,true,true)',[owner])
const oldOccurrence=await value("insert into private.reflection_reminder_occurrences(id,user_id,reminder_kind,scheduled_at,expires_at)values(gen_random_uuid(),$1,'weekly_reflection',now(),now()+interval '4 hours')returning id as result",[owner])
const oldReflection=await value("insert into private.reflection_reminder_deliveries(id,occurrence_id,status,claim_token,lease_version,device_record_id)values(gen_random_uuid(),$1,'processing',$2,1,$3)returning id as result",[oldOccurrence,lease,device])
eq((await value('select public.revalidate_reflection_reminder_delivery_v1($1,$2,1) as result',[oldReflection,lease])).eligible,false,'kill switch cannot re-enable legacy reflection bypass')
// Charges survive content removal; account deletion remains the intended erase.
const historical=await value("select private.mugsy_add_opportunity($1,'historical-charge','on_this_day',30,now()-interval '1 day',now()+interval '1 hour','mugshot://mugsy/journal',null,$2) as result",[owner,delayed])
await db.query("insert into private.mugsy_attention_ledger(opportunity_id,user_id,kind,device_record_id,charged_at,outcome)values($1,$2,'on_this_day',$3,now(),'accepted')",[historical,owner,device]);await db.query('delete from public.visits where id=$1',[delayed])
eq(await value('select count(*)::int as result from private.mugsy_attention_ledger where opportunity_id=$1',[historical]),1)
eq(await value('select target_visit_id is null as result from private.mugsy_opportunities where id=$1',[historical]),true)
await db.exec('delete from private.mugsy_attention_ledger;delete from private.mugsy_direct_receipts')
// Shared local permits consume once across retries and fail closed on a second
// installation with incomplete private-memory baseline.
await value("select public.configure_mugsy_delivery_v1('pilot',array[$1::uuid]) as result",[owner]);await user(owner)
const extra='20000000-0000-4000-8000-000000000199'
await db.query("insert into public.user_devices(id,user_id,device_id,push_token,environment,last_seen_at,mugsy_capability_version)values($1,$2,$1,'new-device','production',now(),1)",[extra,owner])
eq(await value("select private.mugsy_suppression_reason($1,'return_memory',now()+interval '6 days') as result",[owner]),'completion_baseline_missing')
eq(await value('select public.record_mugsy_baseline_v1($1,true) as result',[device]),true)
eq(await value("select private.mugsy_suppression_reason($1,'return_memory',now()+interval '6 days') as result",[owner]),'completion_baseline_missing','another device readiness cannot overwrite pending baseline')
await value('select public.record_mugsy_baseline_v1($1,true) as result',[extra])
await value('select public.record_mugsy_activity_v1($1,true,true) as result',[device]);await value('select public.record_mugsy_activity_v1($1,false,false) as result',[extra])
eq(await value("select private.mugsy_suppression_reason($1,'weekly_pour',now()) as result",[owner]),'currently_active','second device background does not clear active composer')


await service();await db.query("insert into private.moderation_actions(subject_kind,subject_id,action_kind,starts_at)values('user',$1,'account_suspended',now()+interval '10 seconds')",[owner])
eq(await value("select private.mugsy_suppression_reason($1,'weekly_pour',now()) as result",[owner]),'account_unavailable','imminent suspension blocks new optional delivery')
await db.exec('delete from private.moderation_actions')
await user(other);await value('select public.withdraw_mugsy_memory_v1($1) as result',[home]);eq(await value('select count(*)::int as result from private.mugsy_memory_signals where user_id=$1 and memory_id=$2',[owner,home]),1,'withdrawal cannot delete another account memory')
await user(owner);eq(await value('select public.withdraw_mugsy_memory_v1($1) as result',[home]),true);eq(await value('select count(*)::int as result from private.mugsy_memory_signals where user_id=$1 and memory_id=$2',[owner,home]),0)
eq(await value('select public.withdraw_mugsy_memory_v1($1) as result',[home]),true,'withdrawal retries are idempotent')

// Another device may finish an already-started request after withdrawal was
// acknowledged. The server tombstone, rather than request order, decides.
eq(await value("select public.record_mugsy_memory_v1($1,'home',now()-interval '10 days') as result",[home]),true)
eq(await value('select count(*)::int as result from private.mugsy_memory_signals where user_id=$1 and memory_id=$2',[owner,home]),0,'delayed upsert cannot resurrect withdrawn Home memory')
eq(await value('select count(*)::int as result from private.mugsy_completed_memories($1) where memory_key=$2',[owner,home]),0)
eq(await value('select count(*)::int as result from private.mugsy_withdrawals where user_id=$1 and memory_id=$2',[owner,home]),1)
eq((await value('select public.get_mugsy_owner_data_v1() as result')).withdrawals.some(x=>x.memory_id===home),true)
eq(await value("select has_table_privilege('authenticated','private.mugsy_withdrawals','SELECT') as result"),false)
// The same opaque ID in another owner's namespace is independent.
await user(other)
eq(await value("select public.record_mugsy_memory_v1($1,'home',now()-interval '10 days') as result",[home]),true)
eq(await value('select count(*)::int as result from private.mugsy_completed_memories($1) where memory_key=$2',[other,home]),0,'earlier own withdrawal is also permanent')
const isolated='40000000-0000-4000-8000-000000000188'
await user(owner);await value('select public.withdraw_mugsy_memory_v1($1) as result',[isolated])
await user(other);await value("select public.record_mugsy_memory_v1($1,'home',now()-interval '30 days') as result",[isolated])
eq(await value('select count(*)::int as result from private.mugsy_completed_memories($1) where memory_key=$2',[other,isolated]),1,'owner tombstone cannot affect another account')
await value('select public.withdraw_mugsy_memory_v1($1) as result',[isolated]);await user(owner)

eq(await value("select has_function_privilege('authenticated','public.withdraw_mugsy_memory_v1(uuid)','EXECUTE') as result"),true)


// A fresh factual digest may reuse its summary wording after 48 hours, but it
// never reuses already-covered Activity records from the earlier occurrence.
await service();await db.exec(`update public.user_devices set mugsy_active_until=null,mugsy_composing_until=null where user_id='${owner}';
update private.mugsy_attention_state set active_until=null,composing_until=null,automatic_pause_until=null;
update private.mugsy_preferences set preferred_minute=extract(hour from now() at time zone 'UTC')::int*60+extract(minute from now() at time zone 'UTC')::int,timezone_name='UTC',window_start_minute=0,window_end_minute=1440 where user_id='${owner}';
update private.mugsy_opportunities set status='cancelled',claim_token=null where status in('candidate','processing','reserved');
delete from private.mugsy_attention_ledger;delete from private.mugsy_direct_receipts;update public.activity_events set read_at=now();`)
const oldSocial=await value("insert into public.activity_events(recipient_id,kind,title,body,deep_link,created_at)values($1,'friend_post','Fixture','Fixture','mugshot://activity',now()-interval '3 days')returning id as result",[owner])
const priorDigest=await value("insert into private.mugsy_opportunities(user_id,opportunity_key,kind,priority,scheduled_at,expires_at,preference_revision,status,deep_link,template_id,dispatch_started_at)values($1,'old-digest','social_digest',40,now()-interval '49 hours',now()-interval '47 hours',1,'accepted','mugshot://mugsy/activity','social_digest_1',now()-interval '49 hours')returning id as result",[owner])
await db.query('insert into private.mugsy_opportunity_activity values($1,$2)',[priorDigest,oldSocial]);await db.query("insert into private.mugsy_attention_ledger(opportunity_id,user_id,kind,charged_at,outcome)values($1,$2,'social_digest',now()-interval '49 hours','accepted')",[priorDigest,owner])
const newSocial=await value("insert into public.activity_events(recipient_id,kind,title,body,deep_link)values($1,'like','Fixture','Fixture','mugshot://activity')returning id as result",[owner])
await value('select public.enqueue_mugsy_opportunities_v1() as result');const digestClaim=(await db.query('select * from public.claim_mugsy_batch_v1()')).rows.find(x=>x.kind==='social_digest');eq(Boolean(digestClaim),true)
eq((await db.query('select activity_event_id from private.mugsy_opportunity_activity where opportunity_id=$1',[digestClaim.delivery_id])).rows.map(x=>x.activity_event_id),[newSocial])
eq(await value("select public.revalidate_mugsy_delivery_v1($1,$2,$3,'social_digest_1') as result",[digestClaim.delivery_id,digestClaim.claim_token,digestClaim.lease_version]),{eligible:true},'fresh factual social status is exempt from creative cooldown')
await db.query('update public.activity_events set read_at=now() where id=$1',[newSocial])
eq((await value("select public.revalidate_mugsy_delivery_v1($1,$2,$3,'social_digest_1') as result",[digestClaim.delivery_id,digestClaim.claim_token,digestClaim.lease_version])).eligible,false,'reading or removing digest content cancels before send')
// Shadow reservations model later collisions but neither claim a send nor debit
// live budgets. Relevance is checked before recording a would-send decision.
await value("select public.configure_mugsy_delivery_v1('shadow') as result");await db.exec(`delete from private.mugsy_attention_ledger;update private.mugsy_opportunities set status='cancelled',claim_token=null where status in('candidate','processing','reserved');
update public.visits set created_at=now()-interval '10 days' where user_id='${owner}';update private.mugsy_memory_signals set completed_at=now()-interval '10 days' where user_id='${owner}';`)
const shadowAttempts=await value('select logging_attempts as result from private.mugsy_attention_state where user_id=$1',[owner])
await add('shadow-valid','return_memory');eq((await db.query('select * from public.claim_mugsy_batch_v1()')).rows.length,0)
eq(await value("select count(*)::int as result from private.mugsy_attention_ledger where shadow"),1)
eq(await value("select count(*)::int as result from private.mugsy_attention_ledger where not shadow"),0)
eq(await value('select logging_attempts as result from private.mugsy_attention_state where user_id=$1',[owner]),shadowAttempts)
await add('shadow-collision','return_memory');await db.query('select * from public.claim_mugsy_batch_v1()')
eq(await value("select reason as result from private.mugsy_opportunities where opportunity_key='shadow-collision'"),'spacing')
// Late activation remains a new-user cohort, with maturity measured from first
// completion, and opting out never removes its intent-to-treat denominator.
await user(other);await value("select public.record_mugsy_memory_v1(gen_random_uuid(),'home',now()-interval '20 days') as result")
await db.query("update private.mugsy_preferences set experiment_enrolled_at=now()-interval '40 days',holdout=false,mugsy_enabled=false where user_id=$1",[other]);await service()
const lateActivation=(await value('select public.mugsy_retention_report_v1(array[$1::uuid]) as result',[owner])).cohorts.find(x=>x.cohort==='new')
eq(lateActivation.enrolled,1);eq(lateActivation.mature_accounts,0,'new user needs 28 days after actual first completion, not enrollment')


// A cached local grant remains idempotent, but it is not permission to bypass a
// later pause, kill switch, owner/device change or current attention policy.
await service();await value("select public.configure_mugsy_delivery_v1('pilot',array[$1::uuid]) as result",[owner])
await db.exec(`delete from private.mugsy_attention_ledger;delete from private.mugsy_direct_receipts;
update private.mugsy_preferences set paused_until=null,paused_indefinitely=false,pace='standard',window_start_minute=0,window_end_minute=1440 where user_id='${owner}';
update private.mugsy_attention_state set active_until=null,composing_until=null,automatic_pause_until=null where user_id='${owner}';
update public.user_devices set mugsy_active_until=null,mugsy_composing_until=null where user_id='${owner}';`)
const permitDevice=await value('select device_id as result from public.user_devices where id=private.mugsy_primary_device($1)',[owner])
const permitRequest='70000000-0000-4000-8000-000000000101'
await user(owner)
const grant=await value('select public.request_mugsy_nearby_permit_v1($1,$2) as result',[permitDevice,permitRequest])
eq(grant.allowed,true,'eligible initial Nearby request receives a slot')
const cached=await value('select public.request_mugsy_nearby_permit_v1($1,$2) as result',[permitDevice,permitRequest])
eq(cached.allowed,true,'same-device eligible retry excludes its own budget reservation')
eq(cached.permit_id,grant.permit_id)
eq(await value('select count(*)::int as result from private.mugsy_attention_ledger where opportunity_id=$1',[grant.permit_id]),1)
eq((await value('select public.request_mugsy_nearby_permit_v1($1,$2) as result',[device2,permitRequest])).allowed,false,'cached grant cannot replay on another account device')
const replay=()=>value('select public.request_mugsy_nearby_permit_v1($1,$2) as result',[permitDevice,permitRequest])
await service();await value("select public.configure_mugsy_delivery_v1('off') as result");await user(owner)
eq((await replay()).allowed,false,'global shutdown revokes cached grant replay')
await service();await value("select public.configure_mugsy_delivery_v1('pilot',array[$1::uuid]) as result",[owner]);await user(owner)
eq((await replay()).allowed,true,'valid retry remains idempotent after operator resumes sending')
await db.query('update public.notification_preferences set push_enabled=false where user_id=$1',[owner])
eq((await replay()).allowed,false,'master opt-out revokes cached grant replay')
await db.query('update public.notification_preferences set push_enabled=true where user_id=$1',[owner])
await db.exec("update private.mugsy_delivery_control set disabled_kinds=array['nearby']")
eq((await replay()).allowed,false,'category switch revokes cached grant replay')
await db.exec("update private.mugsy_delivery_control set disabled_kinds='{}'")
await db.query("update private.mugsy_preferences set pace='off' where user_id=$1",[owner])
eq((await replay()).allowed,false,'pace Off revokes cached grant replay')
await db.query("update private.mugsy_preferences set pace='standard' where user_id=$1",[owner])
await db.query('update public.user_devices set disabled_at=now() where user_id=$1 and device_id=$2',[owner,permitDevice])
eq((await replay()).allowed,false,'disabled installation cannot reuse cached grant')
await db.query('update public.user_devices set disabled_at=null where user_id=$1 and device_id=$2',[owner,permitDevice])
const currentRevision=await value('select revision as result from private.mugsy_preferences where user_id=$1',[owner])
await db.query('update private.mugsy_preferences set revision=revision+1 where user_id=$1',[owner])
eq((await replay()).allowed,false,'changed preference revision invalidates cached grant')
await db.query('update private.mugsy_preferences set revision=$2 where user_id=$1',[owner,currentRevision])
const currentPreferences=await value('select public.get_mugsy_preferences_v1() as result')
await value("select public.set_mugsy_preferences_v1($1,$2,$3,$4,$5,$6,now()+interval '7 days',false,$7,gen_random_uuid()) as result",
  [currentPreferences.mugsy_enabled,currentPreferences.pace,currentPreferences.preferred_minute,currentPreferences.window_start_minute,currentPreferences.window_end_minute,currentPreferences.timezone_name,currentPreferences.revision])
eq((await replay()).allowed,false,'an acknowledged pause on another device defeats an in-flight retry')
eq(await value('select count(*)::int as result from private.mugsy_attention_ledger where opportunity_id=$1',[grant.permit_id]),1,'revocation retains the original conservative charge')

await user('');await rejects(()=>value('select public.get_mugsy_preferences_v1() as result'),'28000')
console.log(`Mugsy attention contracts: ${checks} checks passed (disposable PostgreSQL; no production access).`)
}finally{await db.close()}
