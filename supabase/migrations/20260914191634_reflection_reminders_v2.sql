begin;

alter table public.user_reflection_preferences
  add column if not exists timezone_name text not null default 'UTC',
  add column if not exists delivery_activated boolean not null default false,
  add column if not exists delivery_activated_at timestamptz,
  add column if not exists client_capability_version integer not null default 0;

alter table public.user_reflection_preferences
  drop constraint if exists user_reflection_preferences_capability_check,
  add constraint user_reflection_preferences_capability_check
    check (client_capability_version between 0 and 1000),
  drop constraint if exists user_reflection_preferences_timezone_check,
  add constraint user_reflection_preferences_timezone_check
    check (char_length(timezone_name) between 1 and 80);

alter table public.user_devices
  add column if not exists supports_reflection_routes boolean not null default false,
  add column if not exists reflection_timezone_name text;

create or replace function public.get_owned_visit_map_scores_v1(
  p_visit_ids uuid[]
)
returns table (
  visit_id uuid,
  mugshot_score numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  requested_ids uuid[] := coalesce(p_visit_ids, '{}'::uuid[]);
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if cardinality(requested_ids) > 100 then
    raise exception 'too many map scores requested' using errcode = '22023';
  end if;
  return query
  select reflection.visit_id, reflection.mugshot_score
  from public.visit_v3_reflections reflection
  join public.visits visit
    on visit.id = reflection.visit_id
   and visit.user_id = actor
   and visit.upload_state = 'complete'
  where reflection.user_id = actor
    and reflection.visit_id = any(requested_ids);
end;
$$;

revoke all on function public.get_owned_visit_map_scores_v1(uuid[])
  from public, anon, authenticated;
grant execute on function public.get_owned_visit_map_scores_v1(uuid[])
  to authenticated;

comment on function public.get_owned_visit_map_scores_v1(uuid[]) is
  'Caller-bound score-only V3 projection for completed personal Map Mugshot averages; limited to 100 stable visit IDs per request.';

create table if not exists private.reflection_delivery_control (
  singleton boolean primary key default true check (singleton),
  enabled boolean not null default false,
  updated_at timestamptz not null default now()
);

insert into private.reflection_delivery_control(singleton, enabled)
values (true, false)
on conflict (singleton) do nothing;

create table if not exists private.reflection_reminder_occurrences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  reminder_kind text not null check (reminder_kind in ('on_this_day', 'weekly_reflection')),
  local_occurrence_date date not null,
  timezone_name text not null check (char_length(timezone_name) between 1 and 80),
  scheduled_at timestamptz not null,
  expires_at timestamptz not null,
  target_visit_id uuid references public.visits(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, reminder_kind, local_occurrence_date),
  check (expires_at > scheduled_at),
  check (
    (reminder_kind = 'on_this_day' and target_visit_id is not null)
    or (reminder_kind = 'weekly_reflection' and target_visit_id is null)
  )
);

create table if not exists private.reflection_reminder_deliveries (
  id uuid primary key default gen_random_uuid(),
  occurrence_id uuid not null references private.reflection_reminder_occurrences(id) on delete cascade,
  device_record_id uuid not null references public.user_devices(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed', 'cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  available_at timestamptz not null default now(),
  claimed_at timestamptz,
  claim_token uuid,
  lease_version bigint not null default 0 check (lease_version >= 0),
  completed_at timestamptz,
  last_error_code text check (char_length(coalesce(last_error_code, '')) <= 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (occurrence_id, device_record_id),
  check (
    (status = 'processing' and claim_token is not null and claimed_at is not null)
    or status <> 'processing'
  )
);

create index if not exists reflection_reminder_occurrences_user_idx
  on private.reflection_reminder_occurrences(user_id, scheduled_at desc);
create index if not exists reflection_reminder_deliveries_ready_idx
  on private.reflection_reminder_deliveries(status, available_at, created_at, id)
  where status in ('pending', 'processing');

alter table private.reflection_delivery_control enable row level security;
alter table private.reflection_reminder_occurrences enable row level security;
alter table private.reflection_reminder_deliveries enable row level security;
revoke all on table private.reflection_delivery_control from public, anon, authenticated;
revoke all on table private.reflection_reminder_occurrences from public, anon, authenticated;
revoke all on table private.reflection_reminder_deliveries from public, anon, authenticated;

create or replace function public.get_reflection_preferences_v2()
returns public.user_reflection_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result public.user_reflection_preferences;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  insert into public.user_reflection_preferences(user_id)
  values(actor)
  on conflict(user_id) do nothing;
  select * into result
  from public.user_reflection_preferences preference
  where preference.user_id = actor;
  return result;
end;
$$;

create or replace function public.set_reflection_preferences_v2(
  p_monthly_recaps boolean,
  p_yearly_recaps boolean,
  p_on_this_sip_reminders boolean,
  p_reflection_reminders boolean,
  p_timezone_name text,
  p_delivery_activated boolean,
  p_client_capability_version integer
)
returns public.user_reflection_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_timezone text := btrim(coalesce(p_timezone_name, ''));
  result public.user_reflection_preferences;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_client_capability_version < 1
     or not exists (
       select 1 from pg_catalog.pg_timezone_names zone
       where zone.name = normalized_timezone
     ) then
    raise exception 'invalid reflection delivery capability' using errcode = '22023';
  end if;

  insert into public.user_reflection_preferences(
    user_id, monthly_recaps, yearly_recaps, on_this_sip_reminders,
    reflection_reminders, timezone_name, delivery_activated,
    delivery_activated_at, client_capability_version, updated_at
  ) values (
    actor, p_monthly_recaps, p_yearly_recaps, p_on_this_sip_reminders,
    p_reflection_reminders, normalized_timezone, p_delivery_activated,
    case when p_delivery_activated then now() else null end,
    p_client_capability_version, now()
  )
  on conflict(user_id) do update set
    monthly_recaps = excluded.monthly_recaps,
    yearly_recaps = excluded.yearly_recaps,
    on_this_sip_reminders = excluded.on_this_sip_reminders,
    reflection_reminders = excluded.reflection_reminders,
    timezone_name = excluded.timezone_name,
    delivery_activated = excluded.delivery_activated,
    delivery_activated_at = case
      when excluded.delivery_activated then coalesce(
        public.user_reflection_preferences.delivery_activated_at,
        now()
      )
      else null
    end,
    client_capability_version = excluded.client_capability_version,
    updated_at = now()
  returning * into result;

  if not p_delivery_activated
     or not p_on_this_sip_reminders
     or not p_reflection_reminders then
    update private.reflection_reminder_deliveries delivery
    set status = 'cancelled', claim_token = null, updated_at = now(),
        last_error_code = 'preference_disabled'
    from private.reflection_reminder_occurrences occurrence
    where delivery.occurrence_id = occurrence.id
      and occurrence.user_id = actor
      and delivery.status in ('pending', 'processing')
      and (
        not p_delivery_activated
        or (occurrence.reminder_kind = 'on_this_day' and not p_on_this_sip_reminders)
        or (occurrence.reminder_kind = 'weekly_reflection' and not p_reflection_reminders)
      );
  end if;
  return result;
end;
$$;

create or replace function public.set_reflection_device_capability_v1(
  p_device_id uuid,
  p_timezone_name text,
  p_supports_routes boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_timezone text := btrim(coalesce(p_timezone_name, ''));
  updated_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_device_id is null
     or not exists (
       select 1 from pg_catalog.pg_timezone_names zone
       where zone.name = normalized_timezone
     ) then
    raise exception 'invalid reflection device capability' using errcode = '22023';
  end if;
  update public.user_devices device
  set supports_reflection_routes = p_supports_routes,
      reflection_timezone_name = normalized_timezone,
      last_seen_at = now(),
      updated_at = now()
  where device.user_id = actor
    and device.device_id = p_device_id
    and device.disabled_at is null;
  get diagnostics updated_count = row_count;
  update public.user_reflection_preferences preference
  set timezone_name = normalized_timezone,
      updated_at = now()
  where preference.user_id = actor;
  return updated_count = 1;
end;
$$;

create or replace function public.enqueue_reflection_reminders_v1(
  p_now timestamptz default now()
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  inserted_count integer := 0;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  if not coalesce((
    select control.enabled
    from private.reflection_delivery_control control
    where control.singleton
  ), false) then
    return 0;
  end if;

  with preference_state as (
    select
      preference.user_id,
      preference.timezone_name,
      preference.on_this_sip_reminders,
      preference.reflection_reminders,
      p_now at time zone preference.timezone_name as local_now
    from public.user_reflection_preferences preference
    join public.notification_preferences notification
      on notification.user_id = preference.user_id
     and notification.push_enabled
    where preference.delivery_activated
      and preference.client_capability_version >= 1
      and private.is_live_account_as(preference.user_id)
      and (preference.on_this_sip_reminders or preference.reflection_reminders)
      and exists (
        select 1 from public.user_devices device
        where device.user_id = preference.user_id
          and device.disabled_at is null
          and device.supports_reflection_routes
      )
  ), schedule_state as (
    select state.*,
      make_timestamptz(
        extract(year from state.local_now)::integer,
        extract(month from state.local_now)::integer,
        extract(day from state.local_now)::integer,
        10, 0, 0, state.timezone_name
      ) as anniversary_at,
      make_timestamptz(
        extract(year from state.local_now)::integer,
        extract(month from state.local_now)::integer,
        extract(day from state.local_now)::integer,
        18, 0, 0, state.timezone_name
      ) as weekly_at
    from preference_state state
  ), candidates as (
    select
      state.user_id,
      'on_this_day'::text as reminder_kind,
      state.local_now::date as local_occurrence_date,
      state.timezone_name,
      state.anniversary_at as scheduled_at,
      state.anniversary_at + interval '6 hours' as expires_at,
      memory.id as target_visit_id
    from schedule_state state
    cross join lateral (
      select visit.id
      from public.visits visit
      where visit.user_id = state.user_id
        and visit.upload_state = 'complete'
        and extract(month from visit.created_at at time zone state.timezone_name)
          = extract(month from state.local_now)
        and extract(day from visit.created_at at time zone state.timezone_name)
          = extract(day from state.local_now)
        and extract(year from visit.created_at at time zone state.timezone_name)
          < extract(year from state.local_now)
      order by
        extract(year from visit.created_at at time zone state.timezone_name) desc,
        visit.created_at desc,
        visit.id desc
      limit 1
    ) memory
    where state.on_this_sip_reminders
      and p_now >= state.anniversary_at
      and p_now < state.anniversary_at + interval '6 hours'

    union all

    select
      state.user_id,
      'weekly_reflection'::text,
      state.local_now::date,
      state.timezone_name,
      state.weekly_at,
      state.weekly_at + interval '4 hours',
      null::uuid
    from schedule_state state
    where state.reflection_reminders
      and extract(dow from state.local_now) = 0
      and p_now >= state.weekly_at
      and p_now < state.weekly_at + interval '4 hours'
      and exists (
        select 1 from public.visits visit
        where visit.user_id = state.user_id
          and visit.upload_state = 'complete'
          and visit.created_at >= state.weekly_at - interval '7 days'
          and visit.created_at < state.weekly_at
      )
  ), inserted as (
    insert into private.reflection_reminder_occurrences(
      user_id, reminder_kind, local_occurrence_date, timezone_name,
      scheduled_at, expires_at, target_visit_id
    )
    select
      candidate.user_id, candidate.reminder_kind, candidate.local_occurrence_date,
      candidate.timezone_name, candidate.scheduled_at, candidate.expires_at,
      candidate.target_visit_id
    from candidates candidate
    on conflict(user_id, reminder_kind, local_occurrence_date) do nothing
    returning id, user_id
  )
  insert into private.reflection_reminder_deliveries(occurrence_id, device_record_id)
  select inserted.id, device.id
  from inserted
  join public.user_devices device
    on device.user_id = inserted.user_id
   and device.disabled_at is null
   and device.supports_reflection_routes
  on conflict(occurrence_id, device_record_id) do nothing;
  get diagnostics inserted_count = row_count;
  return inserted_count;
end;
$$;

create or replace function public.claim_reflection_reminder_batch_v1(
  p_limit integer default 25
)
returns table (
  delivery_id uuid,
  occurrence_id uuid,
  recipient_id uuid,
  device_record_id uuid,
  push_token text,
  environment text,
  title text,
  body text,
  deep_link text,
  reminder_kind text,
  attempt_count integer,
  claim_token uuid,
  lease_version bigint,
  collapse_id text,
  expires_at timestamptz
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.role() <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;

  update private.reflection_reminder_deliveries delivery
  set status = 'pending', claim_token = null, claimed_at = null,
      available_at = now(), updated_at = now(), last_error_code = 'lease_expired'
  where delivery.status = 'processing'
    and delivery.claimed_at < now() - interval '2 minutes';

  update private.reflection_reminder_deliveries delivery
  set status = 'cancelled', claim_token = null, updated_at = now(),
      last_error_code = 'delivery_window_expired'
  from private.reflection_reminder_occurrences occurrence
  where delivery.occurrence_id = occurrence.id
    and delivery.status in ('pending', 'processing')
    and occurrence.expires_at <= now();

  return query
  with claimed as (
    select delivery.id
    from private.reflection_reminder_deliveries delivery
    join private.reflection_reminder_occurrences occurrence
      on occurrence.id = delivery.occurrence_id
    where delivery.status = 'pending'
      and delivery.available_at <= now()
      and occurrence.expires_at > now()
    order by delivery.available_at, delivery.created_at, delivery.id
    for update of delivery skip locked
    limit least(greatest(coalesce(p_limit, 25), 1), 50)
  ), updated as (
    update private.reflection_reminder_deliveries delivery
    set status = 'processing', claimed_at = now(), claim_token = gen_random_uuid(),
        lease_version = delivery.lease_version + 1,
        attempt_count = delivery.attempt_count + 1, updated_at = now()
    from claimed
    where delivery.id = claimed.id
    returning delivery.*
  )
  select
    updated.id,
    occurrence.id,
    occurrence.user_id,
    updated.device_record_id,
    device.push_token,
    device.environment,
    case occurrence.reminder_kind
      when 'on_this_day' then 'A Mugshot to remember'
      else 'Your week in Mugshot'
    end,
    case occurrence.reminder_kind
      when 'on_this_day' then 'Revisit a sip you saved on this day.'
      else 'Take a moment to revisit this week''s sips.'
    end,
    case occurrence.reminder_kind
      when 'on_this_day' then 'mugshot://reflection/memory/' || occurrence.target_visit_id::text
      else 'mugshot://reflection/journal'
    end,
    occurrence.reminder_kind,
    updated.attempt_count,
    updated.claim_token,
    updated.lease_version,
    'reflection:' || occurrence.user_id::text || ':' || occurrence.reminder_kind || ':' || occurrence.local_occurrence_date::text,
    occurrence.expires_at
  from updated
  join private.reflection_reminder_occurrences occurrence
    on occurrence.id = updated.occurrence_id
  join public.user_devices device
    on device.id = updated.device_record_id;
end;
$$;

create or replace function public.revalidate_reflection_reminder_delivery_v1(
  p_delivery_id uuid,
  p_claim_token uuid,
  p_lease_version bigint
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  target record;
  eligible boolean := false;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  select occurrence.*, delivery.device_record_id
  into target
  from private.reflection_reminder_deliveries delivery
  join private.reflection_reminder_occurrences occurrence
    on occurrence.id = delivery.occurrence_id
  where delivery.id = p_delivery_id
    and delivery.status = 'processing'
    and delivery.claim_token = p_claim_token
    and delivery.lease_version = p_lease_version;
  if not found then return jsonb_build_object('eligible', false); end if;

  select exists (
    select 1
    from public.user_reflection_preferences preference
    join public.notification_preferences notification
      on notification.user_id = preference.user_id
    join public.user_devices device
      on device.id = target.device_record_id
     and device.user_id = preference.user_id
    join private.reflection_delivery_control control on control.singleton
    where preference.user_id = target.user_id
      and preference.delivery_activated
      and preference.client_capability_version >= 1
      and private.is_live_account_as(preference.user_id)
      and notification.push_enabled
      and control.enabled
      and device.disabled_at is null
      and device.supports_reflection_routes
      and target.expires_at > now()
      and (
        (target.reminder_kind = 'on_this_day'
          and preference.on_this_sip_reminders
          and exists (
            select 1 from public.visits visit
            where visit.id = target.target_visit_id
              and visit.user_id = target.user_id
              and visit.upload_state = 'complete'
          ))
        or
        (target.reminder_kind = 'weekly_reflection'
          and preference.reflection_reminders
          and exists (
            select 1 from public.visits visit
            where visit.user_id = target.user_id
              and visit.upload_state = 'complete'
              and visit.created_at >= target.scheduled_at - interval '7 days'
              and visit.created_at < target.scheduled_at
          ))
      )
  ) into eligible;

  if not eligible then
    update private.reflection_reminder_deliveries
    set status = 'cancelled', claim_token = null, updated_at = now(),
        last_error_code = 'no_longer_eligible'
    where id = p_delivery_id
      and claim_token = p_claim_token
      and lease_version = p_lease_version;
  end if;
  return jsonb_build_object('eligible', eligible);
end;
$$;

create or replace function public.complete_reflection_reminder_delivery_v1(
  p_delivery_id uuid,
  p_claim_token uuid,
  p_lease_version bigint,
  p_outcome text,
  p_error_code text default null,
  p_retry_after_seconds integer default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target record;
  next_status text;
  next_available timestamptz;
begin
  if auth.role() <> 'service_role' then
    raise exception 'service role required' using errcode = '42501';
  end if;
  if p_outcome not in ('succeeded', 'retryable', 'terminal', 'unregistered') then
    raise exception 'invalid delivery outcome' using errcode = '22023';
  end if;
  select delivery.*, occurrence.expires_at
  into target
  from private.reflection_reminder_deliveries delivery
  join private.reflection_reminder_occurrences occurrence
    on occurrence.id = delivery.occurrence_id
  where delivery.id = p_delivery_id
    and delivery.status = 'processing'
    and delivery.claim_token = p_claim_token
    and delivery.lease_version = p_lease_version
  for update of delivery;
  if not found then return false; end if;

  if p_outcome = 'succeeded' then
    next_status := 'sent';
  elsif p_outcome = 'retryable'
        and target.attempt_count < 5
        and now() < target.expires_at then
    next_status := 'pending';
    next_available := least(
      target.expires_at,
      now() + make_interval(secs => least(greatest(coalesce(p_retry_after_seconds, 60), 30), 900))
    );
  else
    next_status := 'failed';
  end if;

  update private.reflection_reminder_deliveries
  set status = next_status,
      available_at = coalesce(next_available, available_at),
      completed_at = case when next_status in ('sent', 'failed') then now() else null end,
      claim_token = null,
      claimed_at = null,
      last_error_code = left(coalesce(p_error_code, p_outcome), 80),
      updated_at = now()
  where id = p_delivery_id;

  if p_outcome = 'unregistered' then
    update public.user_devices
    set disabled_at = now(), updated_at = now()
    where id = target.device_record_id;
  end if;
  return true;
end;
$$;

revoke all on function public.get_reflection_preferences_v2() from public, anon;
revoke all on function public.set_reflection_preferences_v2(boolean,boolean,boolean,boolean,text,boolean,integer) from public, anon;
revoke all on function public.set_reflection_device_capability_v1(uuid,text,boolean) from public, anon;
grant execute on function public.get_reflection_preferences_v2() to authenticated;
grant execute on function public.set_reflection_preferences_v2(boolean,boolean,boolean,boolean,text,boolean,integer) to authenticated;
grant execute on function public.set_reflection_device_capability_v1(uuid,text,boolean) to authenticated;

revoke all on function public.enqueue_reflection_reminders_v1(timestamptz) from public, anon, authenticated;
revoke all on function public.claim_reflection_reminder_batch_v1(integer) from public, anon, authenticated;
revoke all on function public.revalidate_reflection_reminder_delivery_v1(uuid,uuid,bigint) from public, anon, authenticated;
revoke all on function public.complete_reflection_reminder_delivery_v1(uuid,uuid,bigint,text,text,integer) from public, anon, authenticated;
grant execute on function public.enqueue_reflection_reminders_v1(timestamptz) to service_role;
grant execute on function public.claim_reflection_reminder_batch_v1(integer) to service_role;
grant execute on function public.revalidate_reflection_reminder_delivery_v1(uuid,uuid,bigint) to service_role;
grant execute on function public.complete_reflection_reminder_delivery_v1(uuid,uuid,bigint,text,text,integer) to service_role;

comment on table private.reflection_delivery_control is
  'Server rollback switch for reflection delivery. The initial migration leaves it disabled.';
comment on table private.reflection_reminder_occurrences is
  'Private account-bound reminder occurrences deduplicated by local date and reminder kind.';
comment on table private.reflection_reminder_deliveries is
  'Private per-installation reflection delivery receipts kept outside Activity events and badges.';
comment on function public.set_reflection_preferences_v2(boolean,boolean,boolean,boolean,text,boolean,integer) is
  'Caller-bound versioned reflection preferences. Delivery activates only after an explicit compatible-client save.';

create or replace function private.dispatch_reflection_reminder_worker_v1()
returns bigint
language plpgsql
security definer
set search_path = ''
as $$
declare
  activity_worker_url text;
  worker_url text;
  worker_secret text;
  request_id bigint;
begin
  if not coalesce((
    select control.enabled
    from private.reflection_delivery_control control
    where control.singleton
  ), false) then
    return null;
  end if;
  select decrypted_secret into strict activity_worker_url
  from vault.decrypted_secrets
  where name = 'mugshot_activity_delivery_worker_url';
  select decrypted_secret into strict worker_secret
  from vault.decrypted_secrets
  where name = 'mugshot_activity_delivery_service_role';
  worker_url := replace(activity_worker_url, '/deliver-activity', '/deliver-reflections');
  if worker_url !~ '^https://[a-z]{20}\.supabase\.co/functions/v1/deliver-reflections$'
     or length(worker_secret) not between 32 and 512 then
    raise exception 'reflection delivery scheduler configuration invalid';
  end if;
  select net.http_post(
    url := worker_url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'apikey', worker_secret),
    body := jsonb_build_object('action', 'deliver_v1', 'protocolVersion', 1, 'limit', 25),
    timeout_milliseconds := 50000
  ) into request_id;
  return request_id;
end;
$$;

revoke all on function private.dispatch_reflection_reminder_worker_v1()
  from public, anon, authenticated, service_role;

do $schedule$
declare
  existing_job record;
begin
  if to_regprocedure('cron.schedule(text,text,text)') is null
     or to_regprocedure('cron.unschedule(bigint)') is null
     or to_regprocedure('net.http_post(text,jsonb,jsonb,jsonb,integer)') is null then
    raise exception 'pg_cron and pg_net are required for reflection reminders';
  end if;
  for existing_job in
    select jobid from cron.job where jobname = 'mugshot-reflection-delivery-v1'
  loop
    perform cron.unschedule(existing_job.jobid);
  end loop;
  perform cron.schedule(
    'mugshot-reflection-delivery-v1',
    '*/5 * * * *',
    'select private.dispatch_reflection_reminder_worker_v1();'
  );
end;
$schedule$;

commit;
