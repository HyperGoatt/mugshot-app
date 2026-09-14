import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import {PGlite} from '@electric-sql/pglite'
import {createActivityLeaseFixture} from './activity-lease-fixture.mjs'
const db=new PGlite()
const root=new URL('../../',import.meta.url)
const read=path=>fs.readFile(new URL(path,root),'utf8')
const owner='10000000-0000-4000-8000-000000000001',actor='10000000-0000-4000-8000-000000000002',other='10000000-0000-4000-8000-000000000003',visit='20000000-0000-4000-8000-000000000001'
try {
 await createActivityLeaseFixture(db)
 await db.exec(`create schema auth;create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 alter table public.users add column display_name text,add column username text,add column avatar_url text;
 alter table public.activity_events add column actor_user_id uuid,add column visit_id uuid,add column comment_id uuid,add column shared_memory_id uuid,add column cafe_list_id uuid,add column friend_request_id uuid,add column dedupe_key text,add column metadata jsonb default '{}';
 create table public.visit_companions(visit_id uuid,companion_user_id uuid,added_by uuid);
 create table public.likes(visit_id uuid,user_id uuid,reaction_kind text default 'like',created_at timestamptz default now(),primary key(visit_id,user_id));
 create function private.is_live_account_as(uuid) returns boolean language sql stable as $$select $1 is not null$$;
 create function private.can_view_visit_as(uuid,uuid) returns boolean language sql stable as $$select $1 is not null and $2 is not null and coalesce(current_setting('test.denied',true),'')!='true'$$;
 create function private.can_view_user_as(uuid,uuid) returns boolean language sql stable as $$select $1::text!=coalesce(current_setting('test.blocked',true),'')$$;
 create function private.activity_candidate_event_v1(public.activity_events,uuid) returns boolean language sql stable as $$select true$$;
 create function public.revalidate_activity_push_delivery_v3(uuid,uuid,bigint) returns jsonb language sql as $$select jsonb_build_object('eligible',false)$$;
 insert into public.users values('${owner}','Joe','joe',null),('${actor}','Amanda','amanda',null),('${other}','Sam','sam',null);
 select set_config('test.actor','${owner}',false);
 insert into public.likes(visit_id,user_id,reaction_kind,created_at) values('${visit}','${actor}','love','2026-09-01'),('${visit}','${other}','laugh','2026-09-01');
 insert into public.likes(visit_id,user_id,created_at) values('${visit}','${owner}','2026-08-01');
 insert into public.activity_events(recipient_id,actor_user_id,kind,title,body,deep_link,visit_id,dedupe_key) values('${owner}','${actor}','like','Mugshot activity','Generic','mugshot://visit/${visit}','${visit}','synthetic-like');`)
 // Exercise the real pre-repair projection and push claim definitions.
 await db.exec(await read('qa/pglite/fixtures/regression-activity-projection.sql'))
 const before=(await db.query('select to_jsonb(e) snapshot from public.activity_events e')).rows
 await db.exec(await read('supabase/migrations/20260914155145_regression_activity_and_reaction_people.sql'))
 const page=async(kind=null,cursor=null,limit=1)=>(await db.query('select public.list_visit_reaction_people_v1($1,$2,$3,$4) value',[visit,kind,cursor,limit])).rows[0].value
 let first=await page();assert.equal(first.counts.total_count,3);assert.equal(first.counts.like_count,1);assert.equal(first.people[0].user_id,other)
 let second=await page(null,first.next_cursor);assert.equal(second.people[0].user_id,actor)
 let third=await page(null,second.next_cursor);assert.equal(third.people[0].user_id,owner);assert.equal(third.next_cursor,null)
 assert.equal((await page('love')).people[0].user_id,actor)
 await db.query("select set_config('test.blocked',$1,false)",[actor]);first=await page();assert.equal(first.counts.total_count,2);assert.equal(first.counts.love_count,0)
 await db.exec("select set_config('test.denied','true',false)");await assert.rejects(page(),/post unavailable/)
 await db.exec("select set_config('test.denied','false',false);select set_config('test.actor','',false)");await assert.rejects(page(),/post unavailable/)
 await db.query("select set_config('test.actor',$1,false)",[owner]);await assert.rejects(page('invalid'),/invalid reaction/)
 const activity=(await db.query('select * from public.list_activity_events_v1()')).rows[0];assert.equal(activity.title,'Amanda loved your Mugshot');assert.equal(activity.deep_link,`mugshot://visit/${visit}`)
 assert.deepEqual((await db.query('select to_jsonb(e) snapshot from public.activity_events e')).rows,before)
 for(const [kind,title] of [['friend_post','Amanda posted a Mugshot'],['comment','Amanda commented on your Mugshot']]) {
  await db.query('update public.activity_events set kind=$1',[kind]);assert.equal((await db.query('select title from public.list_activity_events_v1()')).rows[0].title,title)
 }
 await db.exec("update public.activity_events set dedupe_key='moderation:service:synthetic'");assert.equal((await db.query('select * from public.list_activity_events_v1()')).rows.length,0)
 assert.equal((await db.query('select count(*)::int n from public.activity_events')).rows[0].n,1)
 assert.equal((await db.query("select has_function_privilege('anon','public.list_visit_reaction_people_v1(uuid,text,jsonb,integer)','execute') ok")).rows[0].ok,false)
 console.log('PASS: deterministic reaction pagination, historical Likes, filtered counts, block/access gates, actor copy, preserved event rows/routes, retired alert suppression')
} catch(error) { console.error(error.message);process.exitCode=1 } finally {await db.close()}
