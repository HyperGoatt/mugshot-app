import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import {PGlite} from '@electric-sql/pglite'
import {createActivityLeaseFixture} from './activity-lease-fixture.mjs'
const db=new PGlite()
const owner='10000000-0000-4000-8000-000000000001',friend='10000000-0000-4000-8000-000000000002',visit='20000000-0000-4000-8000-000000000001'
try {
 await createActivityLeaseFixture(db)
 await db.exec(`alter table public.users add column display_name text,add column username text;
 insert into public.users values('${owner}','UNSCREENED NAME','synthetic'),('${friend}','Synthetic friend','friend');
 create table public.visits(id uuid primary key,user_id uuid,upload_state text,visibility text);
 insert into public.visits values('${visit}','${owner}','complete','friends');
 create table public.comments(id uuid,user_id uuid,visit_id uuid,removed_at timestamptz);
 create table public.visit_companions(visit_id uuid,companion_user_id uuid,added_by uuid);
 create table public.shared_memory_members(shared_memory_id uuid,user_id uuid,invited_by uuid,status text);
 create table public.cafe_list_members(list_id uuid,user_id uuid,invited_by uuid,invitation_status text);
 create table public.friend_requests(id uuid,from_user_id uuid,to_user_id uuid,status text);
 create table public.comment_mentions(comment_id uuid,mentioned_user_id uuid);
 alter table public.activity_events add column actor_user_id uuid,add column visit_id uuid,add column comment_id uuid,add column shared_memory_id uuid,add column cafe_list_id uuid,add column friend_request_id uuid,add column dedupe_key text,add column metadata jsonb default '{}';
 alter table public.activity_events add unique(recipient_id,dedupe_key);
 create table private.screening_jobs(subject_kind text,subject_id uuid,state text,primary key(subject_kind,subject_id));
 insert into private.screening_jobs values('user','${owner}','pending'),('visit','${visit}','pending');
 create function private.screening_approved_v1(kind text,id uuid) returns boolean language sql stable as $$select exists(select 1 from private.screening_jobs where subject_kind=$1 and subject_id=$2 and state='approved')$$;
 create function private.is_live_account_as(id uuid) returns boolean language sql stable as $$select exists(select 1 from public.users where users.id=$1)$$;
 create function private.blocked_between(uuid,uuid) returns boolean language sql stable as $$select coalesce(current_setting('test.blocked',true),'')='true'$$;
 create function private.confirmed_friends(uuid,uuid) returns boolean language sql stable as $$select true$$;
 create function private.has_active_moderation_action(kind text,id uuid,kinds text[]) returns boolean language sql stable as $$select exists(select 1 from private.moderation_actions where subject_kind=$1 and subject_id=$2 and action_kind=any($3) and revoked_at is null and starts_at<=now() and (ends_at is null or ends_at>now()))$$;
 create function private.can_socially_mutate_as(id uuid) returns boolean language sql stable as $$select private.is_live_account_as($1)$$;
 create function private.can_view_user_as(p_user_id uuid,p_viewer uuid) returns boolean language sql stable as $$select false$$;
 create function private.can_view_visit_as(p_visit_id uuid,p_viewer uuid) returns boolean language sql stable as $$select false$$;
 create function private.can_view_comment_as(p_comment_id uuid,p_viewer uuid) returns boolean language sql stable as $$select false$$;
 `)
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913042008_sprint1_screened_activity_delivery.sql',import.meta.url),'utf8'))
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913152000_sprint1_private_tag_notice_screening.sql',import.meta.url),'utf8'))
 await db.exec(`create or replace function private.can_view_user_as(p_user_id uuid,p_viewer uuid) returns boolean language sql stable as $$select private.activity_candidate_user_v1($1,$2) and private.screening_approved_v1('user',$1)$$;
 create or replace function private.can_view_visit_as(p_visit_id uuid,p_viewer uuid) returns boolean language sql stable as $$select private.activity_candidate_visit_v1($1,$2) and private.screening_approved_v1('visit',$1)$$;
 create or replace function private.can_view_comment_as(p_comment_id uuid,p_viewer uuid) returns boolean language sql stable as $$select private.activity_candidate_comment_v1($1,$2) and private.screening_approved_v1('comment',$1)$$;`)
 const event=(await db.query("select private.create_activity_event_v1($1,$2,'friend_post','synthetic-event','Untrusted title','Untrusted body',$3) as id",[friend,owner,visit])).rows[0].id
 assert.ok(event,'pending screening does not lose the durable event')
 const eventRow=(await db.query('select * from public.activity_events where id=$1',[event])).rows[0]
 assert.equal(eventRow.title,'Mugshot activity')
 assert(!JSON.stringify(eventRow).includes('UNSCREENED NAME'))
 const device=(await db.query("insert into public.user_devices(user_id,device_id,push_token,environment) values($1,gen_random_uuid(),'synthetic','sandbox') returning id",[friend])).rows[0].id
 const delivery=(await db.query('insert into private.activity_push_deliveries(activity_event_id,device_record_id) values($1,$2) returning id',[event,device])).rows[0].id
 const claim=async()=>(await db.query('select * from public.claim_activity_push_batch_v2(1)')).rows
 const state=async()=>(await db.query('select * from private.activity_push_deliveries where id=$1',[delivery])).rows[0]
 assert.deepEqual(await claim(),[])
 assert.equal((await state()).status,'pending','held rather than cancelled')
 await db.exec("update private.screening_jobs set state='approved'")
 const claimed=(await claim())[0]
 assert.equal(claimed.delivery_id,delivery)
 await db.exec("update private.screening_jobs set state='pending' where subject_kind='visit'")
 const revalidate=async(job)=>(await db.query('select public.revalidate_activity_push_delivery_v2($1,$2,$3) as eligible',[delivery,job.claim_token,job.lease_version])).rows[0].eligible
 assert.equal(await revalidate(claimed),false)
 assert.equal((await state()).status,'pending','edit during claim releases lease for later approval')
 assert.equal((await state()).attempt_count,0,'no APNs attempt was made')
 await db.exec("update private.screening_jobs set state='approved';update private.activity_push_deliveries set available_at=now()")
 const reclaimed=(await claim())[0]
 assert.notEqual(reclaimed.claim_token,claimed.claim_token)
 assert.equal(await revalidate(claimed),false,'stale worker cannot affect a reclaimed delivery')
 assert.equal(await revalidate(reclaimed),true)
 await db.exec("select set_config('test.blocked','true',false)")
 assert.equal(await revalidate(reclaimed),false)
 assert.equal((await state()).status,'cancelled','blocks still cancel immediately')
 await db.exec("select set_config('test.blocked','false',false); update private.activity_push_deliveries set status='pending'; update private.screening_jobs set state='pending'; update public.activity_events set created_at=now()-interval '25 hours'")
 assert.deepEqual(await claim(),[])
 assert.equal((await state()).status,'cancelled','old held pushes expire without a delayed burst')
 const listEvent=(await db.query("select private.create_cafe_list_lifecycle_activity_v1($1,$2,'collaborative_list_deleted','deleted-list','Private title','Private body',null,'mugshot://activity',$3) as id",[friend,owner,{reason:'list_deleted',list_id:visit,list_title:'PRIVATE LIST'}])).rows[0].id
 assert.ok(listEvent)
 assert(!JSON.stringify((await db.query('select * from public.activity_events where id=$1',[listEvent])).rows[0]).includes('PRIVATE LIST'))
 assert.equal((await db.query("select has_function_privilege('authenticated','private.activity_candidate_event_v1(public.activity_events,uuid)','execute') as allowed")).rows[0].allowed,false)
 // A Private tag notice must not wait on a provider job that must never exist.
 const privateVisit='20000000-0000-4000-8000-000000000002'
 await db.exec(`update private.screening_jobs set state='approved' where subject_kind='user';
 insert into public.visits values('${privateVisit}','${owner}','complete','private');
 insert into public.visit_companions values('${privateVisit}','${friend}','${owner}');`)
 const privateTag=(await db.query("select private.create_activity_event_v1($1,$2,'tag','private-tag','Private title','Private body',$3) as id",[friend,owner,privateVisit])).rows[0].id
 assert.ok(privateTag)
 const tagVisible=async()=>(await db.query('select private.activity_event_is_visible(e,$2) as visible from public.activity_events e where id=$1',[privateTag,friend])).rows[0].visible
 assert.equal(await tagVisible(),true,'content-free Private tag notice remains available')
 assert.equal((await db.query('select private.can_view_visit_as($1,$2) as visible',[privateVisit,friend])).rows[0].visible,false,'notice does not grant access to Private sip')
 assert.equal((await db.query("select count(*)::integer n from private.screening_jobs where subject_kind='visit' and subject_id=$1",[privateVisit])).rows[0].n,0,'Private sip stays out of screening')
 await db.query("update public.visits set visibility='friends' where id=$1",[privateVisit])
 assert.equal(await tagVisible(),false,'shared content still requires admission')
 await db.query("update public.visits set visibility='private' where id=$1",[privateVisit])
 await db.exec("select set_config('test.blocked','true',false)")
 assert.equal(await tagVisible(),false,'Private tag does not bypass blocks')
 await db.exec("select set_config('test.blocked','false',false)")
 await db.query('delete from public.visit_companions where visit_id=$1',[privateVisit])
 assert.equal(await tagVisible(),false,'removed tag revokes its notice')
 console.log('PASS screened activity: durable pending events, minimal copy, approval, edit/reclaim fencing, blocks, expiry and private list metadata')
} catch(error){console.error(error.message);process.exitCode=1} finally {await db.close()}
