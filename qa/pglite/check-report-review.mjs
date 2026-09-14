import assert from 'node:assert/strict'
import fs from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'
const db = new PGlite()
const owner='10000000-0000-4000-8000-000000000001'
const reporter='10000000-0000-4000-8000-000000000002'
const moderator='10000000-0000-4000-8000-000000000003'
const visit='20000000-0000-4000-8000-000000000001'
const report='30000000-0000-4000-8000-000000000001'
const listComment='50000000-0000-4000-8000-000000000001'
const listReport='30000000-0000-4000-8000-000000000002'
const appeal='40000000-0000-4000-8000-000000000001'
try {
 await db.exec(`create role anon; create role authenticated; create schema private; create schema auth;
 create type public.report_reason as enum ('spam','harassment','privacy','other');
 create type public.report_status as enum ('pending','reviewing','resolved','dismissed');
 create table public.users(id uuid primary key);
 insert into public.users values('${owner}'),('${reporter}'),('${moderator}');
 create table public.visits(id uuid primary key,user_id uuid); insert into public.visits values('${visit}','${owner}');
 create table public.comments(id uuid primary key,user_id uuid);
 create table private.moderation_operators(user_id uuid,role text,is_active boolean);
 insert into private.moderation_operators values('${moderator}','admin',true),('${owner}','reviewer',true),('${reporter}','reviewer',true);
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 create function private.is_live_account_as(id uuid) returns boolean language sql stable as $$select exists(select 1 from public.users where users.id=$1)$$;
 create function private.screening_operator_v1() returns boolean language sql stable as $$select private.is_live_account_as(auth.uid()) and exists(select 1 from private.moderation_operators where user_id=auth.uid() and is_active)$$;

 create table public.reports(id uuid primary key,reporter_id uuid,reporter_subject_id uuid,target_kind text constraint reports_target_kind_check check(target_kind in ('user','visit','comment')),target_id uuid,target_snapshot jsonb,
 reason text,details text,status public.report_status default 'pending',created_at timestamptz default now(),reviewed_by uuid,reviewed_at timestamptz,resolution_code text,closed_at timestamptz);
 create table private.moderation_actions(id uuid primary key default gen_random_uuid(),report_id uuid,subject_kind text constraint moderation_actions_subject_kind_check check(subject_kind in ('user','visit','comment')),subject_id uuid,subject_owner_id uuid,
 action_kind text,reason_code text,internal_note text,starts_at timestamptz default now(),ends_at timestamptz,created_by uuid,created_at timestamptz default now(),revoked_at timestamptz,revoked_by uuid,revocation_reason text);
 create table private.moderation_case_events(id uuid default gen_random_uuid(),report_id uuid,actor_user_id uuid,event_kind text,from_status public.report_status,to_status public.report_status,resolution_code text,internal_note text,created_at timestamptz default now());
 create table private.moderation_appeals(id uuid primary key,action_id uuid,appellant_id uuid,statement text,status text default 'pending',resolution_summary text,reviewed_by uuid,submitted_at timestamptz default now(),reviewed_at timestamptz,updated_at timestamptz default now());
 create table public.cafe_list_comments(id uuid primary key,user_id uuid,list_id uuid,body text,deleted_at timestamptz);
 create table public.cafe_list_comment_reports(id uuid primary key default gen_random_uuid(),comment_id uuid references public.cafe_list_comments(id) on delete cascade,reporter_id uuid,reason text,details text,created_at timestamptz default now(),unique(comment_id,reporter_id));
 insert into public.cafe_list_comments values('${listComment}','${owner}',gen_random_uuid(),'Synthetic list comment',null);
 insert into public.cafe_list_comment_reports(id,comment_id,reporter_id,reason,details) values('${listReport}','${listComment}','${reporter}','spam','First report context');
 create table private.screening_jobs(subject_kind text,subject_id uuid,state text,revision uuid default gen_random_uuid(),reason text,updated_at timestamptz default now());
 insert into private.screening_jobs(subject_kind,subject_id,state) values('list_comment','${listComment}','approved');
 create function private.has_active_moderation_action(kind text,id uuid,kinds text[],at timestamptz default now()) returns boolean language sql stable as $$select exists(select 1 from private.moderation_actions where subject_kind=$1 and subject_id=$2 and action_kind=any($3) and starts_at<=$4 and (ends_at is null or ends_at>$4) and revoked_at is null)$$;
 create function private.can_socially_mutate_as(actor uuid) returns boolean language sql stable as $$select private.is_live_account_as($1)$$;
 create function private.is_public_cafe_list_as(id uuid,actor uuid) returns boolean language sql stable as $$select true$$;
 create table private.moderation_appeal_events(id uuid default gen_random_uuid(),appeal_id uuid,actor_user_id uuid,event_kind text,from_status text,to_status text,internal_note text,created_at timestamptz default now());
 insert into public.reports(id,reporter_subject_id,target_kind,target_id,target_snapshot,reason,details)
 values('${report}','${reporter}','visit','${visit}',jsonb_build_object('user_id','${owner}','caption','Synthetic report evidence','private_notes','Never project'),'spam','Synthetic reporter context');`)
 const historicalFunction=async(file,name)=>{
  const sql=await fs.readFile(new URL('../../supabase/migrations/'+file,import.meta.url),'utf8')
  const start=sql.indexOf('create or replace function '+name+'(')
  assert.ok(start>=0,name+' exists in migration source')
  const end=sql.indexOf('$$;',sql.indexOf('as $$',start))+3
  await db.exec(sql.slice(start,end))
 }
 await historicalFunction('20260722033000_alpha_enforcement_transparency_contract.sql','private.owns_moderation_subject_as')
 await historicalFunction('20260722033000_alpha_enforcement_transparency_contract.sql','private.assign_moderation_action_subject_owner')
 await historicalFunction('20260722100000_alpha_moderation_integrity_hardening.sql','private.enforce_moderation_action_report_subject_v1')
 await db.exec(`create trigger assign_moderation_action_subject_owner before insert or update of subject_kind,subject_id on private.moderation_actions for each row execute function private.assign_moderation_action_subject_owner();
 create trigger enforce_report_subject before insert or update on private.moderation_actions for each row execute function private.enforce_moderation_action_report_subject_v1();`)
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913035050_sprint1_report_review_operations.sql',import.meta.url),'utf8'))
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913035953_sprint1_list_comment_report_integration.sql',import.meta.url),'utf8'))
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913040822_sprint1_report_content_preview.sql',import.meta.url),'utf8'))
 await db.exec(await fs.readFile(new URL('../../supabase/migrations/20260913054240_sprint1_deleted_report_owner_resolution.sql',import.meta.url),'utf8'))
 const actor=id=>db.query("select set_config('test.actor',$1,false)",[id])
 const queue=async(kind='report',cursor=null)=>(await db.query('select public.list_moderation_cases_v1($1,\'pending\',$2,1) as items',[kind,cursor])).rows[0].items
 const decide=async(actorID=moderator,expected='pending')=>(await db.query("select public.review_report_v2($1,$2,'resolved','policy_violation','content_hidden',$3) as applied",[report,expected,actorID])).rows[0].applied
 await actor('')
 await assert.rejects(queue(),/moderation permission required/)
 await actor(moderator)
 const first=(await queue())[0]
 assert.equal(first.subject_text,'Synthetic report evidence')
 assert.equal(first.self_review_conflict,false)
 assert.equal('reporter_subject_id' in first,false)
 assert.equal(JSON.stringify(first).includes('Never project'),false)
 assert.equal((await queue('report',{created_at:first.created_at,id:first.id}))[0].id,listReport)
 await assert.rejects(queue('report',{id:first.id}),/complete queue cursor/)
 await assert.rejects(decide(owner),/account changed/)
 await actor(owner)
 assert.equal((await queue())[0].self_review_conflict,true)
 await assert.rejects(decide(owner),/own content/)
 await actor(reporter)
 await assert.rejects(decide(reporter),/own report/)
 await actor(moderator)
 assert.equal(await decide(moderator,'reviewing'),false)
 assert.equal(await decide(),true)
 assert.equal(await decide(),false,'stale duplicate does not create a second action')
 const actions=(await db.query('select * from private.moderation_actions')).rows
 assert.equal(actions.length,1)
 assert.equal(actions[0].subject_id,visit)
 assert.equal(actions[0].subject_owner_id,owner,'real ownership trigger preserves the enforcement appeal owner')
 assert.equal(actions[0].action_kind,'content_hidden')
 assert.equal((await db.query('select count(*)::int as count from private.moderation_case_events')).rows[0].count,2)
 await db.query('insert into private.moderation_appeals(id,action_id,appellant_id,statement) values($1,$2,$3,$4)',[appeal,actions[0].id,owner,'Synthetic appeal statement'])
 const appealDecision=async(expected,actorID)=>(await db.query("select public.review_moderation_appeal_v2($1,$2,'reversed','Synthetic reconsideration',$3) as applied",[appeal,expected,actorID])).rows[0].applied
 await actor(owner)
 await assert.rejects(appealDecision('pending',owner),/own appeal/)
 await actor(moderator)
 assert.equal((await queue('appeal'))[0].action_kind,'content_hidden')
 assert.equal(await appealDecision('reviewing',moderator),false)
 assert.equal(await appealDecision('pending',moderator),true)
 assert.equal(await appealDecision('pending',moderator),false)
 assert.ok((await db.query('select revoked_at from private.moderation_actions')).rows[0].revoked_at)
 assert.equal((await db.query('select count(*)::int as count from private.moderation_appeal_events')).rows[0].count,1)
 // A legacy list-comment receipt joins the same moderation/appeal lifecycle.
 const listCase=(await queue())[0]
 assert.equal(listCase.id,listReport)
 assert.equal(listCase.target_kind,'cafe_list_comment')
 assert.equal(listCase.subject_text,'Synthetic list comment')
 const reportTarget=async()=>(await db.query('select public.get_report_screening_target_v1($1) as target',[listReport])).rows[0].target
 const previewTarget=await reportTarget()
 assert.equal(previewTarget.subject_kind,'list_comment')
 assert.equal(previewTarget.subject_id,listComment)
 assert.equal('payload' in previewTarget,false,'report navigation reveals no raw payload or lease')

 const admitted=async()=>(await db.query("select private.screening_approved_v1('list_comment',$1) as visible",[listComment])).rows[0].visible
 assert.equal(await admitted(),true)
 await actor(reporter)
 assert.equal((await db.query("select public.report_cafe_list_comment_v1($1,'other','Changed duplicate') as receipt",[listComment])).rows[0].receipt,listReport)
 assert.equal((await db.query('select details from public.reports where id=$1',[listReport])).rows[0].details,'First report context','retries retain immutable original evidence')
 await actor(owner)
 await assert.rejects(db.query("select public.review_report_v2($1,'pending','resolved','policy_violation','content_hidden',$2)",[listReport,owner]),/own content/)
 await actor(moderator)
 assert.equal((await db.query("select public.review_report_v2($1,'pending','resolved','policy_violation','content_hidden',$2) as applied",[listReport,moderator])).rows[0].applied,true)
 assert.equal(await admitted(),false,'a human hide gates an otherwise approved list comment')
 const listAction=(await db.query('select * from private.moderation_actions where report_id=$1',[listReport])).rows[0]
 assert.equal(listAction.subject_owner_id,owner)
 const listAppeal='40000000-0000-4000-8000-000000000002'
 await db.query('insert into private.moderation_appeals(id,action_id,appellant_id,statement) values($1,$2,$3,$4)',[listAppeal,listAction.id,owner,'Synthetic list comment appeal'])
 assert.equal((await db.query("select public.review_moderation_appeal_v2($1,'pending','reversed','Synthetic reversal',$2) as applied",[listAppeal,moderator])).rows[0].applied,true)
 assert.equal(await admitted(),true,'appeal reversal restores the screening gate without changing approval')
 await db.query('delete from public.cafe_list_comments where id=$1',[listComment])
 assert.equal((await db.query('select count(*)::int as count from public.cafe_list_comment_reports where comment_id=$1',[listComment])).rows[0].count,0)
 assert.equal((await db.query('select target_snapshot from public.reports where id=$1',[listReport])).rows[0].target_snapshot.text,'Synthetic list comment','deletion retains durable report evidence')
 await db.query("delete from private.screening_jobs where subject_kind='list_comment' and subject_id=$1",[listComment])
 assert.equal(await reportTarget(),null,'withdrawn/deleted shared revisions have no report preview')
 await actor(reporter)
 const newComment=(await db.query("insert into public.cafe_list_comments(id,user_id,list_id,body) values(gen_random_uuid(),$1,gen_random_uuid(),'New synthetic comment') returning id",[owner])).rows[0].id
 const freshReceipt=(await db.query("select public.report_cafe_list_comment_v1($1,'spam','Fresh report') as id",[newComment])).rows[0].id
 assert.equal((await db.query('select target_id from public.reports where id=$1',[freshReceipt])).rows[0].target_id,newComment,'new legacy RPC writes enter the durable queue through the bridge trigger')
 await actor(moderator)
 await db.query('delete from public.cafe_list_comments where id=$1',[newComment])
 await assert.rejects(db.query("select public.review_report_v2($1,'pending','resolved','policy_violation','content_hidden',$2)",[freshReceipt,moderator]),/moderation subject unavailable/)
 await actor(owner)
 await assert.rejects(db.query("select public.review_report_v2($1,'pending','resolved','policy_violation','warning',$2)",[freshReceipt,owner]),/own content/)
 await actor(moderator)
 assert.equal((await db.query("select public.review_report_v2($1,'pending','resolved','policy_violation','warning',$2) as applied",[freshReceipt,moderator])).rows[0].applied,true,'deleted content retains an owner warning path from sealed report evidence')
 const warning=(await db.query('select subject_id,subject_owner_id from private.moderation_actions where report_id=$1',[freshReceipt])).rows[0]
 assert.equal(warning.subject_id,owner)
 assert.equal(warning.subject_owner_id,owner)
 await db.query('update private.moderation_operators set is_active=false where user_id=$1',[moderator])
 await assert.rejects(queue(),/moderation permission required/)
 await assert.rejects(reportTarget(),/moderation permission required/)
 await assert.rejects(db.query('select public.get_moderation_case_v1($1,$2)',['report',report]),/moderation permission required/)
 assert.equal((await db.query("select has_function_privilege('anon','public.get_moderation_case_v1(text,uuid)','execute') as allowed")).rows[0].allowed,false)
 console.log('PASS operator report/appeal projections, role revocation, self-review, account switches, stale decisions, enforcement, reversal and durable list-comment integration')
} catch(error) { console.error(error.message); process.exitCode=1 }
finally { await db.close() }
