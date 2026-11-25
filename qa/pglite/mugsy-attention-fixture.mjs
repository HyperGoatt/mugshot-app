import fs from 'node:fs/promises'
import { createActivityLeaseFixture } from './activity-lease-fixture.mjs'
export async function createMugsyFixture(db){
await createActivityLeaseFixture(db)
await db.exec(`create schema auth;
create function auth.uid() returns uuid language sql stable as $$select nullif(current_setting('test.actor',true),'')::uuid$$;
create function auth.role() returns text language sql stable as $$select nullif(current_setting('test.role',true),'')$$;
create function private.is_live_account_as(actor uuid) returns boolean language sql stable as $$select exists(select 1 from public.users where id=actor)$$;
create table public.visits(id uuid primary key,user_id uuid references public.users(id) on delete cascade,upload_state text,created_at timestamptz);
create table public.user_capture_preferences(user_id uuid primary key references public.users(id) on delete cascade,cafe_home_habit text,discovery_intents text[]);
create table public.notification_preferences(user_id uuid primary key references public.users(id) on delete cascade,push_enabled boolean not null default false);
create table public.user_reflection_preferences(user_id uuid primary key references public.users(id) on delete cascade,delivery_activated boolean default false,reflection_reminders boolean default false,on_this_sip_reminders boolean default false,client_capability_version integer default 1,timezone_name text default 'UTC');
create table private.reflection_reminder_occurrences(id uuid primary key,user_id uuid references public.users(id) on delete cascade,reminder_kind text,target_visit_id uuid,scheduled_at timestamptz,expires_at timestamptz);
create table private.reflection_reminder_deliveries(id uuid primary key,occurrence_id uuid references private.reflection_reminder_occurrences(id),status text,claim_token uuid,lease_version bigint,last_error_code text,updated_at timestamptz,device_record_id uuid);create table private.reflection_delivery_control(singleton boolean primary key,enabled boolean);
insert into private.reflection_delivery_control values(true,true);
alter table public.user_devices add column supports_reflection_routes boolean not null default true;`)

for(const [file,name] of [
 ['20260722101000_alpha_activity_delivery_hardening.sql','public.revalidate_activity_push_delivery_v2'],
 ['20260824162710_activity_push_badge_v3.sql','public.revalidate_activity_push_delivery_v3'],
 ['20260914191634_reflection_reminders_v2.sql','public.revalidate_reflection_reminder_delivery_v1']]){
 const source=await fs.readFile(new URL('../../supabase/migrations/'+file,import.meta.url),'utf8')
 const start=source.indexOf('create or replace function '+name+'(')
 const end=source.indexOf('$$;',start)+3
 if(start<0||end<3)throw new Error('Missing fixture source '+name)
 await db.exec(source.slice(start,end))
}
}
