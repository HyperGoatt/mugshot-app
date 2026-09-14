import assert from 'node:assert/strict';import fs from 'node:fs/promises';import {PGlite} from '@electric-sql/pglite';
const db=new PGlite();const a='10000000-0000-4000-8000-000000000001',b='10000000-0000-4000-8000-000000000002',v='20000000-0000-4000-8000-000000000001',n='20000000-0000-4000-8000-000000000002';
try{
 await db.exec(`create role anon;create role authenticated;create schema auth;create schema private;
 create table public.users(id uuid primary key);insert into public.users values('${a}'),('${b}');
 create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
 create function private.is_live_account_as(uuid) returns boolean language sql stable as $$select $1 is not null$$;
 create table public.profile_visibility_preferences(user_id uuid primary key,show_friends_on_public_profile boolean not null default true,created_at timestamptz default now(),updated_at timestamptz default now());
 create table public.visits(id uuid primary key,user_id uuid,visibility text,upload_state text,created_at timestamptz default now());
 create table public.visit_tags(visit_id uuid,tagged_user_id uuid);
 create table public.profile_tagged_post_hides(user_id uuid,visit_id uuid,primary key(user_id,visit_id));
 create function private.profile_owner_visible_v2(uuid,uuid) returns boolean language sql as $$select true$$;
 create function private.has_active_moderation_action(text,uuid,text[]) returns boolean language sql as $$select false$$;
 create function private.screening_approved_v1(text,uuid) returns boolean language sql as $$select true$$;
 insert into public.visits(id,user_id,visibility,upload_state) values('${v}','${a}','friends','complete');insert into public.visit_tags values('${v}','${b}');`);
 for(const f of ['20260913020258_sprint1_profile_consent.sql','20260914043621_profile_publication_preferences.sql'])await db.exec(await fs.readFile(new URL('../../supabase/migrations/'+f,import.meta.url),'utf8'));
 const actor=async id=>db.query("select set_config('test.actor',$1,false)",[id]);const visible=async(id,profile)=>(await db.query('select private.profile_visit_published_v1($1,$2) ok',[id,profile])).rows[0].ok;
 await actor(a);assert.equal((await db.query('select public.get_profile_publication_policy_v1() p')).rows[0].p.show_friends,true);
 await db.query('select public.acknowledge_profile_publication_v1(false)');assert.equal(await visible(v,a),false,'historical Friends do not become public');
 await db.query("insert into public.visits(id,user_id,visibility,upload_state,created_at) values($1,$2,'friends','complete','2020-01-01')",[n,a]);await db.query('insert into public.visit_tags values($1,$2)',[n,b]);
 assert.equal(await visible(n,a),true,'new publication independent of backdated sip date');assert.equal(await visible(n,b),true,'tagged profile publishes');
 await db.query('select public.set_profile_tagged_post_hidden_v1($1,true)',[n]);assert.equal(await visible(n,a),false);assert.equal(await visible(n,b),true,'author hide is profile-local');
 await actor(b);await db.query('select public.set_profile_tagged_post_hidden_v1($1,true)',[n]);assert.equal(await visible(n,b),false);
 await db.query('select public.set_profile_tagged_post_hidden_v1($1,false)',[n]);await db.query("update public.visits set visibility='private' where id=$1",[n]);assert.equal(await visible(n,b),false,'Private never public');
 await actor(a);await db.query('select public.acknowledge_profile_publication_v1(true)');assert.equal(await visible(v,a),true,'explicit historical inclusion');
 await db.query('select public.set_profile_friends_visibility_v3(false)');await db.query('select public.acknowledge_profile_publication_v1(false)');assert.equal(await visible(v,a),false,'explicit opt-out preserved');
 console.log('PASS publication migration: notice, historical choice, per-profile hides, backdated new posts, Private exclusion, opt-out');
}finally{await db.close();}
