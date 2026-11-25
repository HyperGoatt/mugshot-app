begin;

-- All new sending starts disabled. A seven-day shadow period and an explicit
-- operator transition are required before the pilot may deliver.
create table private.mugsy_delivery_control (
  singleton boolean primary key default true check(singleton),
  mode text not null default 'off' check(mode in ('off','shadow','pilot','live')),
  shadow_started_at timestamptz,
  pilot_user_ids uuid[] not null default '{}',
  disabled_kinds text[] not null default '{}',
  circuit_until timestamptz,
  consecutive_failures integer not null default 0,
  updated_at timestamptz not null default now()
);
insert into private.mugsy_delivery_control(singleton) values(true);

create table private.mugsy_preferences (
  user_id uuid primary key references public.users(id) on delete cascade,
  mugsy_enabled boolean not null default false,
  attention_managed boolean not null default false,
  pace text not null default 'standard' check(pace in ('standard','light','off')),
  preferred_minute integer not null default 660 check(preferred_minute between 0 and 1439),
  window_start_minute integer not null default 540 check(window_start_minute between 0 and 1439),
  window_end_minute integer not null default 1140 check(window_end_minute between 1 and 1440),
  timezone_name text,
  paused_until timestamptz,
  paused_indefinitely boolean not null default false,
  revision bigint not null default 0,
  consent_version integer not null default 1,
  consented_at timestamptz,
  experiment_enrolled_at timestamptz,
  -- Stable account assignment: 20% holdout. Neither app opens nor reinstall
  -- re-randomize the person. This is not a paid analytics experiment.
  holdout boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(window_end_minute > window_start_minute),
  check(preferred_minute >= window_start_minute and preferred_minute < window_end_minute)
);
create table private.mugsy_preference_requests (
  user_id uuid references public.users(id) on delete cascade,
  request_id uuid not null,
  request_body jsonb not null,
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key(user_id,request_id)
);
create table private.mugsy_memory_signals (
  user_id uuid references public.users(id) on delete cascade,
  memory_id uuid not null,
  origin text not null check(origin in ('home','canonical')),
  completed_at timestamptz not null,
  linked_visit_id uuid references public.visits(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key(user_id,memory_id)
);
create unique index mugsy_memory_signals_unique_home_link on private.mugsy_memory_signals(user_id,linked_visit_id) where origin='home' and linked_visit_id is not null;
create index mugsy_memory_signals_completed_idx on private.mugsy_memory_signals(user_id,completed_at desc);
-- A withdrawal outlives diagnostic retention. Delayed requests from another
-- device cannot recreate a memory after its deletion was acknowledged.
create table private.mugsy_withdrawals (
  user_id uuid references public.users(id) on delete cascade,
  memory_id uuid not null,
  withdrawn_at timestamptz not null default now(),
  primary key(user_id,memory_id)
);
create table private.mugsy_attention_state (
  user_id uuid primary key references public.users(id) on delete cascade,
  completion_baseline_ready boolean not null default false,
  logging_episode_at timestamptz,
  logging_resumed_at timestamptz,
  logging_attempts integer not null default 0,
  last_logging_attempt timestamptz,
  active_until timestamptz,
  composing_until timestamptz,
  last_return_at timestamptz,
  automatic_pause_until timestamptz,
  shadow_pause_until timestamptz,
  updated_at timestamptz not null default now()
);
create table private.mugsy_week_views (
  user_id uuid references public.users(id) on delete cascade,
  week_end timestamptz not null,
  viewed_at timestamptz not null default now(),
  primary key(user_id,week_end)
);
create table private.mugsy_opportunities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  opportunity_key text not null check(length(opportunity_key) <= 180),
  kind text not null check(kind in ('first_memory','second_memory','return_memory','home_memory','repeat_memory','photo_memory','weekly_pour','on_this_day','social_digest','nearby')),
  priority integer not null,
  scheduled_at timestamptz not null,
  expires_at timestamptz not null,
  week_end timestamptz,
  target_visit_id uuid references public.visits(id) on delete set null,
  device_record_id uuid references public.user_devices(id) on delete set null,
  preference_revision bigint not null,
  status text not null default 'candidate' check(status in ('candidate','shadow','reserved','processing','accepted','unknown','failed','suppressed','cancelled')),
  reason text,
  template_id text,
  deep_link text not null,
  claim_token uuid,
  lease_version bigint not null default 0,
  attempt_count integer not null default 0,
  available_at timestamptz not null default now(),
  claimed_at timestamptz,
  dispatch_started_at timestamptz,
  completed_at timestamptz,
  opened_at timestamptz,
  created_at timestamptz not null default now(),
  unique(user_id,opportunity_key),
  check(expires_at > scheduled_at)
);
create index mugsy_opportunities_ready_idx on private.mugsy_opportunities(status,available_at,priority,scheduled_at);
create index mugsy_opportunities_user_idx on private.mugsy_opportunities(user_id,created_at desc);
create table private.mugsy_attention_ledger (
  opportunity_id uuid primary key references private.mugsy_opportunities(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  kind text not null,
  device_record_id uuid references public.user_devices(id) on delete set null,
  charged_at timestamptz not null,
  shadow boolean not null default false,
  outcome text not null default 'reserved' check(outcome in ('reserved','accepted','unknown','failed','cancelled'))
);
create index mugsy_attention_ledger_user_idx on private.mugsy_attention_ledger(user_id,charged_at desc);
create table private.mugsy_direct_receipts (
  activity_event_id uuid primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  kind text not null,
  thread_key text not null,
  created_at timestamptz not null default now()
);
create index mugsy_direct_receipts_user_idx on private.mugsy_direct_receipts(user_id,created_at desc);
create table private.mugsy_opportunity_activity (
  opportunity_id uuid references private.mugsy_opportunities(id) on delete cascade,
  activity_event_id uuid references public.activity_events(id) on delete cascade,
  primary key(opportunity_id,activity_event_id)
);

alter table public.user_devices add column if not exists mugsy_capability_version integer not null default 0;
alter table public.user_devices add column if not exists mugsy_timezone_name text;
alter table public.user_devices add column if not exists mugsy_baseline_ready boolean not null default false;
alter table public.user_devices add column if not exists mugsy_active_until timestamptz;
alter table public.user_devices add column if not exists mugsy_composing_until timestamptz;

-- No direct client table access. Every application interface binds auth.uid().
do $$ declare relation text; begin
  foreach relation in array array['mugsy_delivery_control','mugsy_preferences','mugsy_preference_requests','mugsy_memory_signals','mugsy_withdrawals','mugsy_attention_state','mugsy_week_views','mugsy_opportunities','mugsy_attention_ledger','mugsy_direct_receipts','mugsy_opportunity_activity'] loop
    execute format('alter table private.%I enable row level security',relation);
    execute format('revoke all on table private.%I from public, anon, authenticated',relation);
  end loop;
end $$;

create function private.mugsy_require_actor() returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); expected_actor text; begin
  if actor is null or not private.is_live_account_as(actor) then
    raise exception 'authentication required' using errcode='28000';
  end if;
  -- The native request pins its expected owner even if the shared SDK refreshes
  -- Authorization during an account switch. The header grants no authority;
  -- it can only reject a request whose authenticated owner has changed.
  expected_actor:=nullif(current_setting('request.headers',true),'')::jsonb->>'x-mugshot-account-id';
  if expected_actor is not null and lower(expected_actor)<>actor::text then
    raise exception 'request account changed' using errcode='42501';
  end if;
  return actor;
end $$;
create function private.mugsy_require_service() returns void language plpgsql security definer set search_path='' as $$
begin if auth.role() is distinct from 'service_role' then
  raise exception 'service role required' using errcode='42501'; end if; end $$;
create function private.mugsy_ensure_preferences(p_user uuid) returns void language plpgsql security definer set search_path='' as $$
begin
  insert into private.mugsy_preferences(user_id,holdout,timezone_name)
  values(p_user,mod(abs(hashtextextended(p_user::text,1741)::numeric),5)=0,
    (select r.timezone_name from public.user_reflection_preferences r where r.user_id=p_user and r.delivery_activated
      and exists(select 1 from pg_catalog.pg_timezone_names where name=r.timezone_name))) on conflict do nothing;
  insert into private.mugsy_attention_state(user_id) values(p_user) on conflict do nothing;
  update private.mugsy_preferences set attention_managed=true where user_id=p_user and not attention_managed
    and exists(select 1 from private.mugsy_delivery_control c where c.singleton and (c.mode='live' or (c.mode='pilot' and p_user=any(c.pilot_user_ids))));
end $$;
create function private.mugsy_preferences_json(p_user uuid) returns jsonb language sql stable security definer set search_path='' as $$
  select (to_jsonb(p)-'user_id'-'created_at'-'updated_at'-'consented_at'-'experiment_enrolled_at'-'attention_managed')
    ||jsonb_build_object('delivery_mode',c.mode)
  from private.mugsy_preferences p cross join private.mugsy_delivery_control c
  where p.user_id=p_user and c.singleton
$$;
create function public.get_mugsy_preferences_v1() returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); begin
  perform private.mugsy_ensure_preferences(actor);
  return private.mugsy_preferences_json(actor);
end $$;
create function public.set_mugsy_preferences_v1(
  p_mugsy_enabled boolean,p_pace text,p_preferred_minute integer,
  p_window_start_minute integer,p_window_end_minute integer,p_timezone_name text,
  p_paused_until timestamptz,p_paused_indefinitely boolean,
  p_expected_revision bigint,p_request_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); previous private.mugsy_preferences;
  request jsonb; saved jsonb; prior private.mugsy_preference_requests;
begin
  perform private.mugsy_ensure_preferences(actor);
  select * into previous from private.mugsy_preferences where user_id=actor for update;
  request:=jsonb_build_array(p_mugsy_enabled,p_pace,p_preferred_minute,p_window_start_minute,p_window_end_minute,p_timezone_name,p_paused_until,p_paused_indefinitely,p_expected_revision);
  select * into prior from private.mugsy_preference_requests where user_id=actor and request_id=p_request_id;
  if found then
    if prior.request_body<>request then raise exception 'request identifier reused' using errcode='22023'; end if;
    return prior.response;
  end if;
  if p_request_id is null or p_expected_revision is distinct from previous.revision then
    raise exception 'preferences changed; reload before saving' using errcode='40001'; end if;
  if p_mugsy_enabled is null or p_paused_indefinitely is null
    or p_pace is null or p_pace not in ('standard','light','off')
    or p_preferred_minute is null or p_window_start_minute is null or p_window_end_minute is null
    or p_window_start_minute<0 or p_window_end_minute>1440 or p_window_end_minute<=p_window_start_minute
    or p_preferred_minute<p_window_start_minute or p_preferred_minute>=p_window_end_minute
    or not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone_name)
    or p_paused_until>now()+interval '366 days' then
      raise exception 'invalid reminder preferences' using errcode='22023'; end if;
  update private.mugsy_preferences set mugsy_enabled=p_mugsy_enabled,pace=p_pace,
    preferred_minute=p_preferred_minute,window_start_minute=p_window_start_minute,
    window_end_minute=p_window_end_minute,timezone_name=p_timezone_name,
    paused_until=p_paused_until,paused_indefinitely=p_paused_indefinitely,
    experiment_enrolled_at=case when p_mugsy_enabled then coalesce(experiment_enrolled_at,now()) else experiment_enrolled_at end,
    consented_at=case when p_mugsy_enabled then coalesce(consented_at,now()) else null end,
    revision=revision+1,updated_at=now() where user_id=actor;
  -- An explicit resumed preference may reset the logging sunset. Ordinary opens cannot.
  if p_mugsy_enabled and (not previous.mugsy_enabled or previous.paused_indefinitely or previous.pace='off' or (previous.paused_until is not null and p_paused_until is null)) then
    update private.mugsy_attention_state set automatic_pause_until=null,logging_attempts=0,last_logging_attempt=null,logging_resumed_at=now() where user_id=actor;
    update private.mugsy_opportunities set reason='explicit_resume',completed_at=coalesce(completed_at,now())
      where user_id=actor and kind in ('first_memory','second_memory','return_memory','home_memory','repeat_memory','photo_memory') and status in ('accepted','unknown');
  end if;
  update private.mugsy_opportunities set status='cancelled',reason='preferences_changed',claim_token=null
    where user_id=actor and status in ('candidate','reserved','processing','shadow');
  saved:=private.mugsy_preferences_json(actor);
  insert into private.mugsy_preference_requests values(actor,p_request_id,request,saved,now());
  return saved;
end $$;

create function public.set_mugsy_device_capability_v1(p_device_id uuid,p_timezone_name text,p_capability_version integer default 1)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); begin
  if p_device_id is null or p_capability_version not between 1 and 1000
    or not exists(select 1 from pg_catalog.pg_timezone_names where name=p_timezone_name) then
    raise exception 'invalid device capability' using errcode='22023'; end if;
  perform private.mugsy_ensure_preferences(actor);
  perform 1 from private.mugsy_preferences where user_id=actor for update;
  update public.user_devices set mugsy_capability_version=p_capability_version,
    mugsy_timezone_name=p_timezone_name,last_seen_at=now(),updated_at=now()
    where user_id=actor and device_id=p_device_id and disabled_at is null;
  if not found then return false; end if;
  -- Device timezone is operational state, not new engagement consent. Preserve
  -- existing reflection opt-ins and follow travel on the active installation.
  update private.mugsy_preferences set timezone_name=p_timezone_name,revision=revision+1,updated_at=now()
    where user_id=actor and timezone_name is distinct from p_timezone_name;
  if found then
    update private.mugsy_opportunities set status='cancelled',reason='timezone_changed',claim_token=null
      where user_id=actor and status in ('candidate','reserved','processing','shadow');
  end if;
  return true;
end $$;

create function public.record_mugsy_memory_v1(p_memory_id uuid,p_origin text,p_completed_at timestamptz,p_linked_visit_id uuid default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); existing private.mugsy_memory_signals; begin
  if p_memory_id is null or p_origin is null or p_origin not in ('home','canonical')
    or p_completed_at is null or p_completed_at>now()+interval '5 minutes' then
    raise exception 'invalid completion signal' using errcode='22023'; end if;
  -- Existing private saves may be replayed after an offline period. Clamp future
  -- clock skew, preserve first completion, and verify every canonical linkage.
  if p_origin='canonical' and not exists(select 1 from public.visits where id=p_memory_id and user_id=actor and upload_state='complete') then
    raise exception 'owned completed memory required' using errcode='42501'; end if;
  if p_linked_visit_id is not null and not exists(select 1 from public.visits where id=p_linked_visit_id and user_id=actor and upload_state='complete') then
    raise exception 'owned completed linkage required' using errcode='42501'; end if;
  perform private.mugsy_ensure_preferences(actor);
  perform 1 from private.mugsy_preferences where user_id=actor for update;
  if p_origin='home' and exists(select 1 from private.mugsy_withdrawals where user_id=actor and memory_id=p_memory_id) then
    return true;
  end if;
  select * into existing from private.mugsy_memory_signals where user_id=actor and memory_id=p_memory_id for update;
  if found and existing.origin<>p_origin then raise exception 'memory origin cannot change' using errcode='22023'; end if;
  if existing.linked_visit_id is not null and p_linked_visit_id is not null and existing.linked_visit_id<>p_linked_visit_id then
    raise exception 'memory linkage cannot change' using errcode='22023'; end if;
  insert into private.mugsy_memory_signals(user_id,memory_id,origin,completed_at,linked_visit_id)
  values(actor,p_memory_id,p_origin,least(p_completed_at,now()),p_linked_visit_id)
  on conflict(user_id,memory_id) do update set linked_visit_id=coalesce(private.mugsy_memory_signals.linked_visit_id,excluded.linked_visit_id);
  update private.mugsy_opportunities set status='cancelled',reason='memory_completed',claim_token=null
    where user_id=actor and kind in ('first_memory','second_memory','return_memory','home_memory','repeat_memory','photo_memory','nearby')
      and status in ('candidate','reserved','processing','shadow');
  if existing.memory_id is null then
    update private.mugsy_attention_state set automatic_pause_until=null,updated_at=now() where user_id=actor;
  end if;
  return true;
end $$;


create function public.withdraw_mugsy_memory_v1(p_memory_id uuid) returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); begin
  perform private.mugsy_ensure_preferences(actor);
  perform 1 from private.mugsy_preferences where user_id=actor for update;
  if p_memory_id is null then raise exception 'memory identifier required' using errcode='22023'; end if;
  insert into private.mugsy_withdrawals(user_id,memory_id) values(actor,p_memory_id) on conflict do nothing;
  delete from private.mugsy_memory_signals where user_id=actor and memory_id=p_memory_id and origin='home';
  update private.mugsy_opportunities set status='cancelled',reason='memory_removed',claim_token=null
    where user_id=actor and status in ('candidate','reserved','processing','shadow');
  return true;
end $$;

create function private.mugsy_completed_memories(p_user uuid)
returns table(memory_key uuid,completed_at timestamptz,memory_at timestamptz,origin text) language sql stable security definer set search_path='' as $$
  select coalesce(s.memory_id,v.id),coalesce(s.completed_at,cs.completed_at,v.created_at),coalesce(s.completed_at,v.created_at),'canonical'::text from public.visits v
    left join private.mugsy_memory_signals s on s.user_id=v.user_id and s.origin='home' and s.linked_visit_id=v.id
      and not exists(select 1 from private.mugsy_withdrawals w where w.user_id=s.user_id and w.memory_id=s.memory_id)
    left join private.mugsy_memory_signals cs on cs.user_id=v.user_id and cs.origin='canonical' and cs.memory_id=v.id
    where v.user_id=p_user and v.upload_state='complete'
  union all
  select s.memory_id,s.completed_at,s.completed_at,'home'::text from private.mugsy_memory_signals s
    where s.user_id=p_user and s.origin='home'
      and not exists(select 1 from private.mugsy_withdrawals w where w.user_id=s.user_id and w.memory_id=s.memory_id)
      and not exists(select 1 from public.visits v where v.user_id=p_user and v.upload_state='complete' and (v.id=s.linked_visit_id or v.id=s.memory_id))
$$;
create function public.record_mugsy_baseline_v1(p_device_id uuid,p_ready boolean)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); begin
  perform private.mugsy_ensure_preferences(actor);
  perform 1 from private.mugsy_preferences where user_id=actor for update;
  update public.user_devices set mugsy_baseline_ready=coalesce(p_ready,false),updated_at=now()
    where user_id=actor and device_id=p_device_id and disabled_at is null and mugsy_capability_version>=1;
  return found;
end $$;

create function public.record_mugsy_activity_v1(p_device_id uuid,p_active boolean,p_composing boolean)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); begin
  if not exists(select 1 from public.user_devices where user_id=actor and device_id=p_device_id and disabled_at is null) then return false; end if;
  perform private.mugsy_ensure_preferences(actor);
  perform 1 from private.mugsy_preferences where user_id=actor for update;
  update private.mugsy_attention_state set
    active_until=case when p_active then now()+interval '5 minutes' else null end,
    composing_until=case when p_composing then now()+interval '5 minutes' else null end,
    last_return_at=case when p_active then now() else last_return_at end,updated_at=now()
    where user_id=actor;
  update public.user_devices set last_seen_at=now(),mugsy_active_until=case when p_active then now()+interval '5 minutes' else null end,
    mugsy_composing_until=case when p_composing then now()+interval '5 minutes' else null end
    where user_id=actor and device_id=p_device_id and disabled_at is null;
  return true;
end $$;
create function public.record_mugsy_week_viewed_v1(p_week_end timestamptz)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); begin
  if p_week_end is null or p_week_end>now() then raise exception 'invalid completed week' using errcode='22023'; end if;
  perform private.mugsy_ensure_preferences(actor);
  perform 1 from private.mugsy_preferences where user_id=actor for update;
  insert into private.mugsy_week_views(user_id,week_end) values(actor,p_week_end) on conflict do nothing;
  update private.mugsy_opportunities set status='cancelled',reason='week_viewed',claim_token=null
    where user_id=actor and week_end=p_week_end and status in ('candidate','reserved','processing','shadow');
  return true;
end $$;

create function private.mugsy_primary_device(p_user uuid) returns uuid language sql stable security definer set search_path='' as $$
  select d.id from public.user_devices d where d.user_id=p_user and d.disabled_at is null
    and d.mugsy_capability_version>=1 and d.last_seen_at>now()-interval '30 days'
  order by d.last_seen_at desc,d.id limit 1
$$;
create function private.mugsy_has_legacy_device(p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.user_devices d where d.user_id=p_user and d.disabled_at is null
    and d.last_seen_at>now()-interval '30 days' and d.mugsy_capability_version<1)
$$;
create function private.mugsy_optional_owned(p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.mugsy_preferences where user_id=p_user and attention_managed)
$$;
create function private.mugsy_is_coordinated(p_user uuid) returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.mugsy_delivery_control c join private.mugsy_preferences p on p.user_id=p_user
    where c.singleton and c.mode in ('pilot','live')
      and c.shadow_started_at<=now()-interval '7 days'
      and (c.mode='live' or p_user=any(c.pilot_user_ids))
      and private.mugsy_primary_device(p_user) is not null
      and not private.mugsy_has_legacy_device(p_user))
$$;

-- The shared account lock is the budget transaction boundary for every optional
-- sender. A reservation is a charge; unknown sends never refund that charge.
create function private.mugsy_suppression_reason(p_user uuid,p_kind text,p_now timestamptz,p_existing uuid default null)
returns text language plpgsql security definer set search_path='' as $$
declare p private.mugsy_preferences; s private.mugsy_attention_state; c private.mugsy_delivery_control;
  local_now timestamp; minute integer; recent_count integer; last_save timestamptz; attempts integer; last_attempt timestamptz;
begin
  select * into p from private.mugsy_preferences where user_id=p_user for update;
  if not found then return 'preferences_missing'; end if;
  select * into c from private.mugsy_delivery_control where singleton;
  select * into s from private.mugsy_attention_state where user_id=p_user;
  if not private.is_live_account_as(p_user) or not private.activity_recipient_is_eligible_v2(p_user)
    or exists(select 1 from private.moderation_actions a where a.subject_kind='user' and a.subject_id=p_user
      and a.action_kind='account_suspended' and a.revoked_at is null and a.starts_at<=clock_timestamp()+interval '30 seconds'
      and (a.ends_at is null or a.ends_at>clock_timestamp())) then return 'account_unavailable'; end if;
  if not exists(select 1 from public.notification_preferences n where n.user_id=p_user and n.push_enabled) then return 'master_off'; end if;
  if p.pace='off' or p.paused_indefinitely or p.paused_until>p_now or (c.mode='shadow' and s.shadow_pause_until>p_now) or (c.mode<>'shadow' and s.automatic_pause_until>p_now) then return 'paused'; end if;
  if p.timezone_name is null or not exists(select 1 from pg_catalog.pg_timezone_names where name=p.timezone_name) then return 'timezone_missing'; end if;
  if p_kind=any(c.disabled_kinds) then return 'category_disabled'; end if;
  if c.circuit_until>p_now then return 'circuit_open'; end if;
  if private.mugsy_primary_device(p_user) is null then return 'capability_missing'; end if;
  if private.mugsy_has_legacy_device(p_user) then return 'legacy_installation'; end if;
  if s.active_until>p_now or s.composing_until>p_now or exists(select 1 from public.user_devices d where d.user_id=p_user and d.disabled_at is null and (d.mugsy_active_until>p_now or d.mugsy_composing_until>p_now)) then return 'currently_active'; end if;
  local_now:=p_now at time zone p.timezone_name;
  minute:=extract(hour from local_now)::integer*60+extract(minute from local_now)::integer;
  if minute<p.window_start_minute or minute>=p.window_end_minute then return 'quiet_hours'; end if;
  if exists(select 1 from private.mugsy_direct_receipts d where d.user_id=p_user and d.created_at>p_now-interval '12 hours') then return 'recent_direct_activity'; end if;
  if exists(select 1 from private.mugsy_attention_ledger l where l.shadow=(c.mode='shadow') and l.user_id=p_user and l.opportunity_id is distinct from p_existing
    and l.charged_at>p_now-interval '48 hours') then return 'spacing'; end if;
  if exists(select 1 from private.mugsy_attention_ledger l where l.shadow=(c.mode='shadow') and l.user_id=p_user and l.opportunity_id is distinct from p_existing
    and (l.charged_at at time zone p.timezone_name)::date=local_now::date) then return 'local_day_limit'; end if;
  select count(*) into recent_count from private.mugsy_attention_ledger l where l.shadow=(c.mode='shadow') and l.user_id=p_user
    and l.opportunity_id is distinct from p_existing and l.charged_at>p_now-interval '168 hours';
  if recent_count>=(case when p.pace='light' then 1 else 3 end) then return 'weekly_budget'; end if;
  if p_kind in ('first_memory','second_memory','return_memory','home_memory','repeat_memory','photo_memory','nearby') then
    select max(m.completed_at) into last_save from private.mugsy_completed_memories(p_user) m;
    if last_save>p_now-interval '48 hours' then return 'recent_completion'; end if;
    select count(*) into recent_count from private.mugsy_attention_ledger l where l.shadow=(c.mode='shadow') and l.user_id=p_user
      and l.opportunity_id is distinct from p_existing and l.charged_at>p_now-interval '168 hours'
      and l.kind in ('first_memory','second_memory','return_memory','home_memory','repeat_memory','photo_memory','nearby');
    if recent_count>=2 then return 'logging_budget'; end if;
    if p_kind<>'nearby' then
      if not p.mugsy_enabled or p.consented_at is null then return 'engagement_consent_missing'; end if;
      if exists(select 1 from public.user_devices d where d.user_id=p_user and d.disabled_at is null and d.last_seen_at>p_now-interval '30 days' and d.mugsy_capability_version>=1 and not d.mugsy_baseline_ready) then return 'completion_baseline_missing'; end if;
      if p.holdout then return 'holdout'; end if;
      if c.mode='shadow' then
        select count(*),max(l.charged_at) into attempts,last_attempt from private.mugsy_attention_ledger l
          where l.shadow and l.user_id=p_user and l.opportunity_id is distinct from p_existing
            and l.kind in ('first_memory','second_memory','return_memory','home_memory','repeat_memory','photo_memory')
            and l.charged_at>coalesce(last_save,p.created_at);
      elsif last_save is distinct from s.logging_episode_at then
        update private.mugsy_attention_state set logging_episode_at=last_save,logging_attempts=0,last_logging_attempt=null where user_id=p_user;
        attempts:=0; last_attempt:=null;
      else attempts:=s.logging_attempts; last_attempt:=s.last_logging_attempt; end if;
      if p_existing is not null and exists(select 1 from private.mugsy_attention_ledger where opportunity_id=p_existing) then
        attempts:=greatest(attempts-1,0);
        select max(l.charged_at) into last_attempt from private.mugsy_attention_ledger l
          where l.shadow=(c.mode='shadow') and l.user_id=p_user and l.opportunity_id<>p_existing
            and l.kind in ('first_memory','second_memory','return_memory','home_memory','repeat_memory','photo_memory')
            and l.charged_at>coalesce(last_save,s.logging_resumed_at,p.created_at);
      end if;
      if p_kind='first_memory' and attempts>=1 then return 'first_memory_sunset'; end if;
      if attempts>=2 then return 'logging_sunset'; end if;
      if last_attempt>p_now-interval '7 days' then return 'logging_cooldown'; end if;
    end if;
  end if;
  select count(*) into recent_count from private.mugsy_attention_ledger l
    join private.mugsy_opportunities o on o.id=l.opportunity_id
    where l.shadow=(c.mode='shadow') and l.user_id=p_user and l.charged_at>p_now-interval '21 days'
      and l.outcome in ('accepted','unknown') and o.opened_at is null
      and l.charged_at>coalesce(s.last_return_at,'-infinity'::timestamptz)
      and l.charged_at>coalesce((select max(completed_at) from private.mugsy_completed_memories(p_user)),'-infinity'::timestamptz);
  if recent_count>=3 then
    if c.mode='shadow' then update private.mugsy_attention_state set shadow_pause_until=p_now+interval '30 days' where user_id=p_user;
    else update private.mugsy_attention_state set automatic_pause_until=p_now+interval '30 days' where user_id=p_user; end if;
    return 'automatic_pause';
  end if;
  return null;
end $$;

create function private.mugsy_add_opportunity(p_user uuid,p_key text,p_kind text,p_priority integer,
  p_scheduled timestamptz,p_expires timestamptz,p_deep_link text,p_week_end timestamptz default null,p_target uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; begin
  insert into private.mugsy_opportunities(user_id,opportunity_key,kind,priority,scheduled_at,expires_at,deep_link,week_end,target_visit_id,preference_revision)
  select p_user,p_key,p_kind,p_priority,p_scheduled,p_expires,p_deep_link,p_week_end,p_target,p.revision
    from private.mugsy_preferences p where p.user_id=p_user
  on conflict(user_id,opportunity_key) do nothing returning id into result;
  return result;
end $$;

create function public.enqueue_mugsy_opportunities_v1(p_now timestamptz default now())
returns integer language plpgsql security definer set search_path='' as $$
declare p private.mugsy_preferences; c private.mugsy_delivery_control; local_now timestamp; boundary timestamp;
  endpoint timestamptz; latest timestamptz; total integer; target uuid; opportunity uuid; count_added integer:=0;
  scheduled timestamptz; expires timestamptz; kind text;
begin
  perform private.mugsy_require_service();
  select * into c from private.mugsy_delivery_control where singleton;
  if c.mode='off' then return 0; end if;
  -- Reclaim is deliberately conservative: an old processing lease may have
  -- crossed APNs, so it is unknown rather than being blindly re-enqueued.
  update private.mugsy_opportunities set status='unknown',reason='lease_expired_unknown',claim_token=null,completed_at=p_now
    where status='processing' and claimed_at<p_now-interval '2 minutes';
  update private.mugsy_attention_ledger l set outcome='unknown' from private.mugsy_opportunities o
    where o.id=l.opportunity_id and o.status='unknown' and l.outcome='reserved';
  update private.mugsy_opportunities set status='cancelled',reason='expired',claim_token=null
    where status in ('candidate','reserved') and expires_at<=p_now;
  for p in select * from private.mugsy_preferences where timezone_name is not null loop
    if not exists(select 1 from pg_catalog.pg_timezone_names where name=p.timezone_name) then continue; end if;
    local_now:=p_now at time zone p.timezone_name;
    boundary:=date_trunc('day',local_now)-make_interval(days=>extract(dow from local_now)::integer)+interval '18 hours';
    if boundary>local_now then boundary:=boundary-interval '7 days'; end if;
    endpoint:=boundary at time zone p.timezone_name;
    if p_now<endpoint+interval '4 hours'
      and exists(select 1 from private.reflection_delivery_control where singleton and enabled)
      and exists(select 1 from public.user_reflection_preferences r where r.user_id=p.user_id and r.delivery_activated and r.reflection_reminders)
      and exists(select 1 from private.mugsy_completed_memories(p.user_id) m where m.memory_at>=endpoint-interval '168 hours' and m.memory_at<endpoint)
      and not exists(select 1 from private.mugsy_week_views w where w.user_id=p.user_id and w.week_end=endpoint) then
      opportunity:=private.mugsy_add_opportunity(p.user_id,'weekly:'||endpoint::text,'weekly_pour',20,endpoint,endpoint+interval '4 hours',
        'mugshot://mugsy/weekly?end='||to_char(endpoint at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),endpoint);
      if opportunity is not null then count_added:=count_added+1; end if;
    end if;
    scheduled:=(local_now::date+interval '10 hours') at time zone p.timezone_name;
    if p_now>=scheduled and p_now<scheduled+interval '6 hours'
      and exists(select 1 from private.reflection_delivery_control where singleton and enabled)
      and exists(select 1 from public.user_reflection_preferences r where r.user_id=p.user_id and r.delivery_activated and r.on_this_sip_reminders) then
      select v.id into target from public.visits v where v.user_id=p.user_id and v.upload_state='complete'
        and extract(year from v.created_at at time zone p.timezone_name)<extract(year from local_now)
        and to_char(v.created_at at time zone p.timezone_name,'MM-DD')=to_char(local_now,'MM-DD')
        order by v.created_at desc,v.id limit 1;
      if target is not null then
        opportunity:=private.mugsy_add_opportunity(p.user_id,'anniversary:'||local_now::date::text,'on_this_day',30,scheduled,scheduled+interval '6 hours',
          'mugshot://mugsy/memory/'||target::text,null,target);
        if opportunity is not null then count_added:=count_added+1; end if;
      end if;
    end if;
    scheduled:=(local_now::date+make_interval(mins=>p.preferred_minute)) at time zone p.timezone_name;
    expires:=least(scheduled+interval '2 hours',(local_now::date+make_interval(mins=>p.window_end_minute)) at time zone p.timezone_name);
    if p_now<scheduled or p_now>=expires then continue; end if;
    -- A digest is a real set of eligible unread Activity, never an invented count.
    if exists(select 1 from public.activity_events a where a.recipient_id=p.user_id and a.kind in ('friend_post','like','reaction')
      and a.read_at is null and a.created_at>p_now-interval '7 days'
      and private.activity_event_is_visible(a,p.user_id) and private.activity_kind_push_enabled(p.user_id,a.kind)
      and not exists(select 1 from private.mugsy_opportunity_activity oa join private.mugsy_opportunities o on o.id=oa.opportunity_id
        where oa.activity_event_id=a.id and (o.status in ('reserved','processing','accepted','unknown') or (c.mode='shadow' and o.status='shadow')))) then
      opportunity:=private.mugsy_add_opportunity(p.user_id,'social:'||local_now::date::text,'social_digest',40,scheduled,expires,'mugshot://mugsy/activity');
      if opportunity is not null then
        insert into private.mugsy_opportunity_activity(opportunity_id,activity_event_id)
        select opportunity,a.id from public.activity_events a where a.recipient_id=p.user_id and a.kind in ('friend_post','like','reaction')
          and a.read_at is null and a.created_at>p_now-interval '7 days'
          and private.activity_event_is_visible(a,p.user_id) and private.activity_kind_push_enabled(p.user_id,a.kind)
          and not exists(select 1 from private.mugsy_opportunity_activity prior join private.mugsy_opportunities sent on sent.id=prior.opportunity_id
            where prior.activity_event_id=a.id and (sent.status in ('reserved','processing','accepted','unknown') or (c.mode='shadow' and sent.status='shadow')));
        count_added:=count_added+1;
      end if;
    end if;
    if not p.mugsy_enabled or p.holdout then continue; end if;
    select count(*),max(completed_at) into total,latest from private.mugsy_completed_memories(p.user_id);
    kind:=null;
    if total=0 and p_now>=coalesce(p.consented_at,p.created_at)+interval '48 hours' then kind:='first_memory';
    elsif total=1 and latest<=p_now-interval '72 hours' then kind:='second_memory';
    elsif total>1 and latest<=p_now-interval '5 days' then kind:='return_memory'; end if;
    if kind='return_memory' and exists(select 1 from public.user_capture_preferences cp where cp.user_id=p.user_id and cp.cafe_home_habit='home') then kind:='home_memory'; end if;
    if kind is not null then
      opportunity:=private.mugsy_add_opportunity(p.user_id,'logging:'||coalesce(latest::text,'first')||':'||local_now::date::text,
        kind,case when kind='second_memory' then 50 else 60 end,scheduled,expires,case when kind='home_memory' then 'mugshot://mugsy/home' else 'mugshot://mugsy/log' end);
      if opportunity is not null then count_added:=count_added+1; end if;
    end if;
  end loop;
  -- Prune diagnostics, retaining minimized account state. Active deliveries and
  -- current idempotency receipts are not discarded during retries.
  delete from private.mugsy_opportunities where created_at<p_now-interval '90 days' and status not in ('processing','reserved','candidate');
  delete from private.mugsy_preference_requests where created_at<p_now-interval '90 days';
  delete from private.mugsy_direct_receipts where created_at<p_now-interval '90 days';
  return count_added;
end $$;

create function public.claim_mugsy_batch_v1(p_limit integer default 25)
returns table(delivery_id uuid,recipient_id uuid,device_record_id uuid,push_token text,environment text,
  kind text,deep_link text,week_end timestamptz,expires_at timestamptz,route_expires_at timestamptz,claim_token uuid,lease_version bigint,attempt_count integer,used_template_ids text[])
language plpgsql security definer set search_path='' as $$
declare o private.mugsy_opportunities; c private.mugsy_delivery_control; device public.user_devices; why text; begin
  perform private.mugsy_require_service();
  select * into c from private.mugsy_delivery_control where singleton;
  if c.mode='off' then return; end if;
  for o in select * from private.mugsy_opportunities q where q.status in ('candidate','reserved') and q.available_at<=now()
    and q.scheduled_at<=now() and q.expires_at>now() order by q.priority,q.scheduled_at,q.id limit least(greatest(p_limit,1),50) loop
    perform 1 from private.mugsy_preferences where user_id=o.user_id for update;
    select * into o from private.mugsy_opportunities q where q.id=o.id and q.status in ('candidate','reserved') for update skip locked;
    if not found then continue; end if;
    why:=private.mugsy_suppression_reason(o.user_id,o.kind,now(),o.id);
    if why is null and not private.mugsy_opportunity_relevance(o) then why:='no_longer_relevant'; end if;
    if why is null and c.mode='shadow' then
      insert into private.mugsy_attention_ledger(opportunity_id,user_id,kind,device_record_id,charged_at,shadow,outcome)
        values(o.id,o.user_id,o.kind,private.mugsy_primary_device(o.user_id),now(),true,'accepted') on conflict do nothing;
      update private.mugsy_opportunities set status='shadow',reason='would_send' where id=o.id;
      continue;
    end if;
    if why is null and not private.mugsy_is_coordinated(o.user_id) then why:='outside_pilot'; end if;
    if why is not null then
      update private.mugsy_opportunities set status=case when why='shadow_only' then 'shadow' else 'suppressed' end,reason=why where id=o.id;
      continue;
    end if;
    select * into device from public.user_devices d where d.id=private.mugsy_primary_device(o.user_id);
    insert into private.mugsy_attention_ledger(opportunity_id,user_id,kind,device_record_id,charged_at)
      values(o.id,o.user_id,o.kind,device.id,now()) on conflict do nothing;
    if found and o.kind in ('first_memory','second_memory','return_memory','home_memory','repeat_memory','photo_memory') then
      update private.mugsy_attention_state set logging_attempts=logging_attempts+1,last_logging_attempt=now() where user_id=o.user_id;
    end if;
    update private.mugsy_opportunities q set status='processing',device_record_id=device.id,claimed_at=now(),claim_token=gen_random_uuid(),
      lease_version=q.lease_version+1,attempt_count=q.attempt_count+1 where q.id=o.id returning * into o;
    return query select o.id,o.user_id,device.id,device.push_token,device.environment,o.kind,o.deep_link,o.week_end,o.expires_at,o.created_at+interval '90 days',
      o.claim_token,o.lease_version,o.attempt_count,
      array(select q.template_id from private.mugsy_opportunities q where q.user_id=o.user_id and q.id<>o.id and q.template_id is not null
        and q.dispatch_started_at>now()-interval '28 days');
  end loop;
end $$;

create function private.mugsy_opportunity_relevance(p_opportunity private.mugsy_opportunities) returns boolean language plpgsql security definer set search_path='' as $$
declare n integer; latest timestamptz; begin
  if p_opportunity.kind='weekly_pour' then
    return exists(select 1 from private.reflection_delivery_control where singleton and enabled)
      and exists(select 1 from public.user_reflection_preferences p where p.user_id=p_opportunity.user_id and p.delivery_activated and p.reflection_reminders)
      and not exists(select 1 from private.mugsy_week_views w where w.user_id=p_opportunity.user_id and w.week_end=p_opportunity.week_end)
      and exists(select 1 from private.mugsy_completed_memories(p_opportunity.user_id) m where m.memory_at>=p_opportunity.week_end-interval '168 hours' and m.memory_at<p_opportunity.week_end);
  elsif p_opportunity.kind='on_this_day' then
    return exists(select 1 from private.reflection_delivery_control where singleton and enabled)
      and exists(select 1 from public.user_reflection_preferences p where p.user_id=p_opportunity.user_id and p.delivery_activated and p.on_this_sip_reminders)
      and exists(select 1 from public.visits v where v.id=p_opportunity.target_visit_id and v.user_id=p_opportunity.user_id and v.upload_state='complete');
  elsif p_opportunity.kind='social_digest' then
    return exists(select 1 from private.mugsy_opportunity_activity oa join public.activity_events a on a.id=oa.activity_event_id
      where oa.opportunity_id=p_opportunity.id and a.read_at is null and private.activity_event_is_visible(a,p_opportunity.user_id)
        and private.activity_kind_push_enabled(p_opportunity.user_id,a.kind));
  elsif p_opportunity.kind='nearby' then return true;
  end if;
  select count(*),max(completed_at) into n,latest from private.mugsy_completed_memories(p_opportunity.user_id);
  if p_opportunity.kind='home_memory' and not exists(select 1 from public.user_capture_preferences cp where cp.user_id=p_opportunity.user_id and cp.cafe_home_habit='home') then return false; end if;
  return case p_opportunity.kind when 'first_memory' then n=0 when 'second_memory' then n=1 and latest<=now()-interval '72 hours'
    else n>1 and latest<=now()-interval '5 days' end;
end $$;

create function public.revalidate_mugsy_delivery_v1(p_delivery_id uuid,p_claim_token uuid,p_lease_version bigint,p_template_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare o private.mugsy_opportunities; why text; owner_id uuid; begin
  perform private.mugsy_require_service();
  select user_id into owner_id from private.mugsy_opportunities where id=p_delivery_id;
  perform 1 from private.mugsy_preferences where user_id=owner_id for update;
  select * into o from private.mugsy_opportunities where id=p_delivery_id and status='processing' and claim_token=p_claim_token
    and lease_version=p_lease_version for update;
  if not found then return jsonb_build_object('eligible',false); end if;
  why:=private.mugsy_suppression_reason(o.user_id,o.kind,now(),o.id);
  if why is null and not private.mugsy_is_coordinated(o.user_id) then why:='delivery_off'; end if;
  if why is null and o.expires_at<=now() then why:='expired'; end if;
  if why is null and o.preference_revision<>(select revision from private.mugsy_preferences where user_id=o.user_id) then why:='preferences_changed'; end if;
  if why is null and not exists(select 1 from public.user_devices d where d.id=o.device_record_id and d.user_id=o.user_id and d.disabled_at is null
    and d.id=private.mugsy_primary_device(o.user_id)) then why:='device_changed'; end if;
  if why is null and not private.mugsy_opportunity_relevance(o) then why:='no_longer_relevant'; end if;
  if why is null and (p_template_id is null or (o.kind='social_digest' and p_template_id<>'social_digest_1')
    or (o.kind<>'social_digest' and p_template_id !~ ('^'||o.kind||'_[1-4]$'))) then why:='template_invalid'; end if;
  if why is null and o.kind<>'social_digest' and exists(select 1 from private.mugsy_opportunities q where q.user_id=o.user_id and q.id<>o.id and q.template_id=p_template_id
    and q.dispatch_started_at>now()-interval '28 days') then why:='copy_cooldown'; end if;
  if why is not null then
    update private.mugsy_opportunities set status='cancelled',reason=why,claim_token=null where id=o.id;
    return jsonb_build_object('eligible',false,'reason',why);
  end if;
  update private.mugsy_opportunities set template_id=p_template_id,dispatch_started_at=now() where id=o.id;
  return jsonb_build_object('eligible',true);
end $$;

create function public.complete_mugsy_delivery_v1(p_delivery_id uuid,p_claim_token uuid,p_lease_version bigint,p_outcome text,p_error_code text default null,p_retry_after_seconds integer default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare o private.mugsy_opportunities; status_value text; begin
  perform private.mugsy_require_service();
  if p_outcome not in ('succeeded','retryable','terminal','unregistered','unknown') then raise exception 'invalid outcome' using errcode='22023'; end if;
  select * into o from private.mugsy_opportunities where id=p_delivery_id and status='processing' and claim_token=p_claim_token
    and lease_version=p_lease_version for update;
  if not found then return false; end if;
  status_value:=case when p_outcome='succeeded' then 'accepted' when p_outcome='unknown' then 'unknown'
    when p_outcome='retryable' and o.attempt_count<3 and o.expires_at>now()+make_interval(secs=>least(greatest(coalesce(p_retry_after_seconds,60),30),86400)) then 'reserved' else 'failed' end;
  update private.mugsy_opportunities set status=status_value,reason=left(coalesce(p_error_code,p_outcome),80),claim_token=null,claimed_at=null,
    available_at=now()+make_interval(secs=>least(greatest(coalesce(p_retry_after_seconds,60),30),86400)),
    completed_at=case when status_value='reserved' then null else now() end where id=o.id;
  update private.mugsy_attention_ledger set outcome=case when status_value='accepted' then 'accepted' when status_value='unknown' then 'unknown'
    when status_value='reserved' then 'reserved' else 'failed' end where opportunity_id=o.id;
  if p_outcome='unregistered' then update public.user_devices set disabled_at=now(),updated_at=now() where id=o.device_record_id and user_id=o.user_id; end if;
  update private.mugsy_delivery_control set consecutive_failures=case when p_outcome='succeeded' then 0 else consecutive_failures+1 end,
    circuit_until=case when p_outcome<>'succeeded' and consecutive_failures>=2 then now()+interval '15 minutes' else circuit_until end,
    updated_at=now() where singleton;
  return true;
end $$;

create function public.request_mugsy_nearby_permit_v1(p_device_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); opportunity private.mugsy_opportunities; why text; device uuid; begin
  perform private.mugsy_ensure_preferences(actor);
  if p_request_id is null then raise exception 'request required' using errcode='22023'; end if;
  -- Locks the same account row as remote reservations before deciding.
  perform 1 from private.mugsy_preferences where user_id=actor for update;
  select * into opportunity from private.mugsy_opportunities where user_id=actor and opportunity_key='nearby:'||p_request_id::text;
  if found then
    return jsonb_build_object('allowed',opportunity.status='accepted' and opportunity.expires_at>now(),
      'reason',coalesce(opportunity.reason,'reserved'),'permit_id',opportunity.id,'expires_at',opportunity.expires_at);
  end if;
  select id into device from public.user_devices where user_id=actor and device_id=p_device_id and disabled_at is null and id=private.mugsy_primary_device(actor);
  if device is null or not private.mugsy_is_coordinated(actor) then return jsonb_build_object('allowed',false,'reason','coordination_unavailable'); end if;
  why:=private.mugsy_suppression_reason(actor,'nearby',now());
  if why is not null then return jsonb_build_object('allowed',false,'reason',why); end if;
  insert into private.mugsy_opportunities(user_id,opportunity_key,kind,priority,scheduled_at,expires_at,device_record_id,preference_revision,status,deep_link)
    select actor,'nearby:'||p_request_id::text,'nearby',70,now(),now()+interval '60 seconds',device,revision,'accepted','mugshot://mugsy/journal'
    from private.mugsy_preferences where user_id=actor returning * into opportunity;
  insert into private.mugsy_attention_ledger(opportunity_id,user_id,kind,device_record_id,charged_at,outcome) values(opportunity.id,actor,'nearby',device,now(),'accepted');
  return jsonb_build_object('allowed',true,'reason','reserved','permit_id',opportunity.id,'expires_at',opportunity.expires_at);
end $$;

create function public.get_mugsy_notification_intent_v1(p_occurrence_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); o private.mugsy_opportunities; begin
  select * into o from private.mugsy_opportunities where id=p_occurrence_id and user_id=actor;
  if not found or o.created_at+interval '90 days'<=now() or o.status not in ('accepted','unknown','processing') then return null; end if;
  if not private.mugsy_opportunity_relevance(o) and o.kind in ('on_this_day','social_digest') then return null; end if;
  return jsonb_build_object('kind',o.kind,'deep_link',o.deep_link,'week_end',o.week_end,'memory_id',o.target_visit_id,
    'expires_at',o.created_at+interval '90 days','template_id',o.template_id);
end $$;
create function public.record_mugsy_notification_open_v1(p_occurrence_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); begin
  update private.mugsy_opportunities set opened_at=coalesce(opened_at,now()) where id=p_occurrence_id and user_id=actor;
  return found;
end $$;

-- Called from existing workers before their legacy send. Coordinated reflection
-- and ambient social opportunities are delivered only through the shared ledger.
create function public.authorize_reflection_attention_v1(p_delivery_id uuid,p_claim_token uuid,p_lease_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target record; begin
  perform private.mugsy_require_service();
  select d.id,o.user_id into target from private.reflection_reminder_deliveries d
    join private.reflection_reminder_occurrences o on o.id=d.occurrence_id
    where d.id=p_delivery_id and d.status='processing' and d.claim_token=p_claim_token and d.lease_version=p_lease_version;
  if not found then return jsonb_build_object('eligible',false); end if;
  if private.mugsy_optional_owned(target.user_id) then
    update private.reflection_reminder_deliveries set status='cancelled',claim_token=null,last_error_code='shared_attention_orchestrator',updated_at=now() where id=target.id;
    return jsonb_build_object('eligible',false,'coordinated',true);
  end if;
  return jsonb_build_object('eligible',true,'coordinated',false);
end $$;
create function public.authorize_activity_attention_v1(p_delivery_id uuid,p_claim_token uuid,p_lease_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare target record; begin
  perform private.mugsy_require_service();
  select d.id as delivery_id,a.* into target from private.activity_push_deliveries d join public.activity_events a on a.id=d.activity_event_id
    where d.id=p_delivery_id and d.status='processing' and d.claim_token=p_claim_token and d.lease_version=p_lease_version;
  if not found then return jsonb_build_object('eligible',false); end if;
  if not private.mugsy_optional_owned(target.recipient_id) then return jsonb_build_object('eligible',true,'coordinated',false); end if;
  if target.kind in ('friend_post','like','reaction') then
    update private.activity_push_deliveries set status='cancelled',claim_token=null,last_error_code='shared_activity_digest',updated_at=now() where id=p_delivery_id;
    return jsonb_build_object('eligible',false,'coordinated',true);
  end if;
  -- Comments in the same thread share a fifteen-minute interruption window.
  if target.kind in ('comment','comment_mention') and exists(select 1 from private.mugsy_direct_receipts r
    where r.user_id=target.recipient_id and r.activity_event_id<>target.id and r.kind in ('comment','comment_mention')
      and r.thread_key=split_part(target.deep_link,'?',1) and r.created_at>now()-interval '15 minutes') then
    update private.activity_push_deliveries set status='cancelled',claim_token=null,last_error_code='thread_grouped',updated_at=now() where id=p_delivery_id;
    return jsonb_build_object('eligible',false,'coordinated',true);
  end if;
  insert into private.mugsy_direct_receipts(activity_event_id,user_id,kind,thread_key)
    values(target.id,target.recipient_id,target.kind,split_part(target.deep_link,'?',1)) on conflict do nothing;
  return jsonb_build_object('eligible',true,'coordinated',true);
end $$;

create function public.mugsy_operator_report_v1() returns jsonb language plpgsql security definer set search_path='' as $$
begin perform private.mugsy_require_service(); return jsonb_build_object(
  'mode',(select mode from private.mugsy_delivery_control where singleton),
  'shadow_started_at',(select shadow_started_at from private.mugsy_delivery_control where singleton),
  'decisions',coalesce((select jsonb_agg(t) from (select kind,status,reason,count(*) as count from private.mugsy_opportunities
    where created_at>now()-interval '7 days' group by kind,status,reason) t),'[]'::jsonb),
  'guardrails',jsonb_build_object('weekly_limit',3,'light_limit',1,'spacing_hours',48,'retention_days',90)); end $$;
create function public.configure_mugsy_delivery_v1(p_mode text,p_pilot_user_ids uuid[] default '{}',p_disabled_kinds text[] default '{}')
returns boolean language plpgsql security definer set search_path='' as $$
declare c private.mugsy_delivery_control; begin
  perform private.mugsy_require_service();
  select * into c from private.mugsy_delivery_control where singleton for update;
  if p_mode is null or p_mode not in ('off','shadow','pilot','live') then raise exception 'invalid delivery mode' using errcode='22023'; end if;
  if p_mode in ('pilot','live') and (c.shadow_started_at is null or c.shadow_started_at>now()-interval '7 days') then
    raise exception 'seven-day shadow period required' using errcode='55000'; end if;
  if p_mode='pilot' and coalesce(cardinality(p_pilot_user_ids),0)=0 then raise exception 'pilot allowlist required' using errcode='22023'; end if;
  update private.mugsy_delivery_control set mode=p_mode,
    shadow_started_at=case when p_mode='shadow' then coalesce(shadow_started_at,now()) else shadow_started_at end,
    pilot_user_ids=coalesce(p_pilot_user_ids,'{}'),disabled_kinds=coalesce(p_disabled_kinds,'{}'),updated_at=now() where singleton;
  if p_mode in ('pilot','live') then
    update private.mugsy_preferences set attention_managed=true where p_mode='live' or user_id=any(coalesce(p_pilot_user_ids,'{}'));
  end if;
  if p_mode='off' then update private.mugsy_opportunities set status='cancelled',reason='delivery_off',claim_token=null where status in ('candidate','reserved','processing'); end if;
  return true;
end $$;


alter function public.revalidate_activity_push_delivery_v3(uuid,uuid,bigint) rename to mugsy_base_activity_revalidation_v3;
alter function public.mugsy_base_activity_revalidation_v3(uuid,uuid,bigint) set schema private;
alter function public.revalidate_reflection_reminder_delivery_v1(uuid,uuid,bigint) rename to mugsy_base_reflection_revalidation_v1;
alter function public.mugsy_base_reflection_revalidation_v1(uuid,uuid,bigint) set schema private;
create function public.revalidate_activity_push_delivery_v3(p_delivery_id uuid,p_claim_token uuid,p_lease_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare original jsonb; attention jsonb; begin
  perform private.mugsy_require_service();
  original:=private.mugsy_base_activity_revalidation_v3(p_delivery_id,p_claim_token,p_lease_version);
  if original->>'eligible'='true' then
    attention:=public.authorize_activity_attention_v1(p_delivery_id,p_claim_token,p_lease_version);
    if attention->>'eligible' is distinct from 'true' then return jsonb_build_object('eligible',false); end if;
  end if;
  return original;
end $$;
create function public.revalidate_reflection_reminder_delivery_v1(p_delivery_id uuid,p_claim_token uuid,p_lease_version bigint)
returns jsonb language plpgsql security definer set search_path='' as $$
declare original jsonb; attention jsonb; begin
  perform private.mugsy_require_service();
  original:=private.mugsy_base_reflection_revalidation_v1(p_delivery_id,p_claim_token,p_lease_version);
  if original->>'eligible'='true' then
    attention:=public.authorize_reflection_attention_v1(p_delivery_id,p_claim_token,p_lease_version);
    if attention->>'eligible' is distinct from 'true' then return jsonb_build_object('eligible',false); end if;
  end if;
  return original;
end $$;
revoke all on function public.revalidate_activity_push_delivery_v3(uuid,uuid,bigint) from public,anon,authenticated;
revoke all on function public.revalidate_reflection_reminder_delivery_v1(uuid,uuid,bigint) from public,anon,authenticated;
grant execute on function public.revalidate_activity_push_delivery_v3(uuid,uuid,bigint) to service_role;
grant execute on function public.revalidate_reflection_reminder_delivery_v1(uuid,uuid,bigint) to service_role;


create function public.mugsy_retention_report_v1(p_excluded_user_ids uuid[] default '{}',p_now timestamptz default now())
returns jsonb language plpgsql security definer set search_path='' as $$
begin
  perform private.mugsy_require_service();
  return jsonb_build_object('definition_version',1,'as_of',p_now,'cohorts',coalesce((
    with enrolled as (
      select p.user_id,p.holdout,p.experiment_enrolled_at,
        (select min(m.completed_at) from private.mugsy_completed_memories(p.user_id) m) as first_at
      from private.mugsy_preferences p where p.experiment_enrolled_at is not null
        and not(p.user_id=any(coalesce(p_excluded_user_ids,'{}')))
    ), classified as (
      select e.*,case when first_at is null then 'not_activated'
        when first_at>=experiment_enrolled_at-interval '7 days' then 'new' else 'existing' end as cohort
      from enrolled e
    ), measured as (
      select c.*,case when cohort='new' then first_at+interval '28 days'<=p_now
        when cohort='existing' then experiment_enrolled_at+interval '28 days'<=p_now else false end as mature,
        exists(select 1 from private.mugsy_completed_memories(c.user_id) m where m.completed_at>c.first_at and m.completed_at<=c.first_at+interval '7 days') as second_in_7d,
        exists(select 1 from private.mugsy_completed_memories(c.user_id) m where
          (cohort='new' and m.completed_at>=c.first_at+interval '14 days' and m.completed_at<c.first_at+interval '28 days')
          or(cohort='existing' and m.completed_at>=c.experiment_enrolled_at+interval '7 days' and m.completed_at<c.experiment_enrolled_at+interval '28 days')) as retained
      from classified c
    ) select jsonb_agg(t) from (select cohort,holdout,count(*) as enrolled,
        count(*) filter(where mature) as mature_accounts,
        count(*) filter(where mature and retained) as retained_accounts,
        count(*) filter(where cohort='new' and first_at+interval '7 days'<=p_now) as second_memory_denominator,
        count(*) filter(where cohort='new' and first_at+interval '7 days'<=p_now and second_in_7d) as second_memory_accounts
      from measured group by cohort,holdout order by cohort,holdout) t
  ),'[]'::jsonb));
end $$;
create function public.get_mugsy_owner_data_v1() returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.mugsy_require_actor(); begin
  return jsonb_build_object('version',1,'preferences',private.mugsy_preferences_json(actor),
    'completion_signals',coalesce((select jsonb_agg(jsonb_build_object('memory_id',memory_id,'origin',origin,'completed_at',completed_at,'linked_visit_id',linked_visit_id))
      from private.mugsy_memory_signals where user_id=actor),'[]'::jsonb),
    'withdrawals',coalesce((select jsonb_agg(jsonb_build_object('memory_id',memory_id,'withdrawn_at',withdrawn_at)) from private.mugsy_withdrawals where user_id=actor),'[]'::jsonb),
    'experiment_enrolled_at',(select experiment_enrolled_at from private.mugsy_preferences where user_id=actor));
end $$;

create function private.dispatch_mugsy_reminder_worker_v1() returns bigint language plpgsql security definer set search_path='' as $$
declare worker_url text; worker_secret text; request_id bigint; begin
  if not exists(select 1 from private.mugsy_delivery_control where singleton and mode<>'off') then return null; end if;
  select replace(decrypted_secret,'/deliver-activity','/deliver-mugsy') into strict worker_url
    from vault.decrypted_secrets where name='mugshot_activity_delivery_worker_url';
  select decrypted_secret into strict worker_secret from vault.decrypted_secrets where name='mugshot_activity_delivery_service_role';
  if worker_url !~ '^https://[a-z]{20}\.supabase\.co/functions/v1/deliver-mugsy$' or length(worker_secret) not between 32 and 512 then
    raise exception 'Mugsy scheduler configuration invalid'; end if;
  select net.http_post(url:=worker_url,headers:=jsonb_build_object('Content-Type','application/json','apikey',worker_secret),
    body:=jsonb_build_object('action','deliver_v1','protocolVersion',1,'limit',25),timeout_milliseconds:=50000) into request_id;
  return request_id;
end $$;
revoke all on function private.dispatch_mugsy_reminder_worker_v1() from public,anon,authenticated,service_role;
do $schedule$ begin
  if to_regprocedure('cron.schedule(text,text,text)') is not null then
    perform cron.schedule('mugshot-mugsy-delivery-v1','*/5 * * * *','select private.dispatch_mugsy_reminder_worker_v1();');
  end if;
end $schedule$;

-- Explicit ACLs for every new function. No anonymous execution or private
-- function execution is inherited through PUBLIC's default function grant.
do $$ declare f record; begin
  for f in select p.oid::regprocedure signature,n.nspname schema_name,p.proname name
    from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace
    where (n.nspname='private' and p.proname like 'mugsy_%')
      or (n.nspname='public' and p.proname in (
      'get_mugsy_preferences_v1','set_mugsy_preferences_v1','set_mugsy_device_capability_v1','record_mugsy_memory_v1','withdraw_mugsy_memory_v1',
      'record_mugsy_activity_v1','record_mugsy_baseline_v1','record_mugsy_week_viewed_v1','enqueue_mugsy_opportunities_v1','claim_mugsy_batch_v1',
      'revalidate_mugsy_delivery_v1','complete_mugsy_delivery_v1','request_mugsy_nearby_permit_v1',
      'get_mugsy_notification_intent_v1','record_mugsy_notification_open_v1','authorize_reflection_attention_v1',
      'authorize_activity_attention_v1','mugsy_operator_report_v1','mugsy_retention_report_v1','get_mugsy_owner_data_v1','configure_mugsy_delivery_v1')) loop
    execute format('revoke all on function %s from public, anon, authenticated',f.signature);
    if f.schema_name='private' then execute format('revoke all on function %s from service_role',f.signature); end if;
    if f.schema_name='public' then
      if f.name in ('get_mugsy_preferences_v1','get_mugsy_owner_data_v1','set_mugsy_preferences_v1','set_mugsy_device_capability_v1','record_mugsy_memory_v1','withdraw_mugsy_memory_v1',
        'record_mugsy_activity_v1','record_mugsy_baseline_v1','record_mugsy_week_viewed_v1','request_mugsy_nearby_permit_v1','get_mugsy_notification_intent_v1','record_mugsy_notification_open_v1') then
        execute format('grant execute on function %s to authenticated',f.signature);
      else execute format('grant execute on function %s to service_role',f.signature); end if;
    end if;
  end loop;
end $$;

comment on table private.mugsy_attention_ledger is 'Account-level optional-notification reservations. Charges survive ambiguous delivery and retries.';
comment on table private.mugsy_memory_signals is 'Minimal owner-scoped durable Home completion signals. No captions, notes, photos, location or analytics properties.';
comment on function public.configure_mugsy_delivery_v1(text,uuid[],text[]) is 'Operator-only release gate. Migration never enables delivery; pilot/live require seven elapsed shadow days.';

commit;
