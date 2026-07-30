begin;

-- Activity delivery hardening is deliberately isolated from product data.
-- Device tokens are normalized and serialized inside their real APNs
-- namespace (sandbox or production), delivery workers use fenced leases, and
-- account suspension suppresses social activity without disabling devices.

-- ---------------------------------------------------------------------------
-- One deterministic owner per normalized APNs token namespace, plus a strict
-- active-device cap so a registration loop cannot create unbounded fanout.
-- ---------------------------------------------------------------------------

-- Preserve the freshest binding if legacy rows differ only by token casing.
with ranked as (
  select
    device.id,
    row_number() over (
      partition by device.environment, lower(btrim(device.push_token))
      order by
        (device.disabled_at is null) desc,
        coalesce(device.last_seen_at, device.updated_at, device.created_at) desc,
        device.id desc
    ) as position
  from public.user_devices device
  where device.environment in ('sandbox', 'production')
)
delete from public.user_devices device
using ranked
where device.id = ranked.id and ranked.position > 1;

-- The legacy table may have a global raw-token constraint. APNs development
-- and production are separate namespaces, so remove only that one-column
-- constraint before normalizing values that can legitimately match cross-env.
do $$
declare constraint_row record;
begin
  for constraint_row in
    select constraint_definition.conname
    from pg_constraint constraint_definition
    where constraint_definition.conrelid = 'public.user_devices'::regclass
      and constraint_definition.contype = 'u'
      and pg_get_constraintdef(constraint_definition.oid)
        ~* '^UNIQUE \(push_token\)$'
  loop
    execute format(
      'alter table public.user_devices drop constraint %I',
      constraint_row.conname
    );
  end loop;
end;
$$;

update public.user_devices device
set
  push_token = lower(btrim(device.push_token)),
  disabled_at = case
    when device.environment not in ('sandbox', 'production')
      or char_length(lower(btrim(device.push_token))) not between 64 and 200
      or lower(btrim(device.push_token)) !~ '^[a-f0-9]+$'
      then coalesce(device.disabled_at, now())
    else device.disabled_at
  end,
  updated_at = now()
where device.push_token is distinct from lower(btrim(device.push_token))
   or (
     device.disabled_at is null
     and (
       device.environment not in ('sandbox', 'production')
       or char_length(lower(btrim(device.push_token))) not between 64 and 200
       or lower(btrim(device.push_token)) !~ '^[a-f0-9]+$'
     )
   );

-- An APNs device token is scoped to the development/production endpoint. The
-- worker maps that server-owned environment to an allowlisted sandbox or
-- production topic; the registration API never accepts a topic from a client.
drop index if exists public.user_devices_apns_token_namespace_idx;
create unique index user_devices_apns_token_namespace_idx
  on public.user_devices (environment, push_token)
  where environment in ('sandbox', 'production');

alter table public.user_devices
  drop constraint if exists user_devices_normalized_token_check,
  add constraint user_devices_normalized_token_check check (
    push_token = lower(btrim(push_token))
    and (
      disabled_at is not null
      or (
        environment in ('sandbox', 'production')
        and char_length(push_token) between 64 and 200
        and push_token ~ '^[a-f0-9]+$'
      )
    )
  );

-- Idempotent heartbeats remain cheap, but repeated device/token/environment
-- rebinding is bounded. The active-device cap limits fanout; this window also
-- prevents a signed-in client from turning registration churn into unbounded
-- write amplification.
create table if not exists private.user_device_registration_windows (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null default now(),
  material_change_count integer not null default 0
    check (material_change_count between 0 and 20),
  updated_at timestamptz not null default now()
);

alter table private.user_device_registration_windows enable row level security;
revoke all on table private.user_device_registration_windows
  from public, anon, authenticated;

create or replace function public.register_user_device_v2(
  p_device_id uuid,
  p_push_token text,
  p_environment text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_token text := lower(btrim(coalesce(p_push_token, '')));
  registered public.user_devices;
  existing public.user_devices;
  active_device_count integer;
  registration_window private.user_device_registration_windows;
  is_material_change boolean;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_live_account_as(actor) then
    raise exception 'account unavailable' using errcode = '42501';
  end if;
  if p_device_id is null
     or char_length(normalized_token) not between 64 and 200
     or normalized_token !~ '^[a-f0-9]+$'
     or p_environment not in ('sandbox', 'production') then
    raise exception 'invalid device registration' using errcode = '22023';
  end if;

  -- Serialize both per-account cap enforcement and ownership of this exact
  -- APNs namespace. If two accounts race with one token, the later serialized
  -- registration becomes its sole owner instead of producing two bindings.
  perform pg_advisory_xact_lock(
    hashtextextended('mugshot-device-account:' || actor::text, 0)
  );
  perform pg_advisory_xact_lock(
    hashtextextended('mugshot-device-installation:' || p_device_id::text, 0)
  );
  perform pg_advisory_xact_lock(
    hashtextextended(
      'mugshot-apns-token:' || p_environment || ':' || normalized_token,
      0
    )
  );

  select device.* into existing
  from public.user_devices device
  where device.user_id = actor and device.device_id = p_device_id
  for update;

  is_material_change := existing.id is null
    or existing.push_token is distinct from normalized_token
    or existing.environment is distinct from p_environment
    or existing.platform is distinct from 'ios'
    or existing.disabled_at is not null;

  if is_material_change then
    insert into private.user_device_registration_windows (user_id)
    values (actor)
    on conflict (user_id) do nothing;

    select window_row.* into registration_window
    from private.user_device_registration_windows window_row
    where window_row.user_id = actor
    for update;

    if registration_window.window_started_at <= now() - interval '1 hour' then
      update private.user_device_registration_windows
      set
        window_started_at = now(),
        material_change_count = 1,
        updated_at = now()
      where user_id = actor
      returning * into registration_window;
    elsif registration_window.material_change_count >= 20 then
      raise exception 'too many device registration changes'
        using errcode = '54000';
    else
      update private.user_device_registration_windows
      set
        material_change_count = material_change_count + 1,
        updated_at = now()
      where user_id = actor
      returning * into registration_window;
    end if;
  end if;

  delete from public.user_devices device
  where (
      device.device_id = p_device_id
      or (
        device.environment = p_environment
        and device.push_token = normalized_token
      )
    )
    and (device.user_id, device.device_id)
      is distinct from (actor, p_device_id);

  insert into public.user_devices (
    user_id, device_id, push_token, platform, environment,
    last_seen_at, disabled_at, failure_count, last_failure_at
  ) values (
    actor, p_device_id, normalized_token, 'ios', p_environment,
    now(), null, 0, null
  )
  on conflict (user_id, device_id) where device_id is not null
  do update set
    push_token = excluded.push_token,
    platform = 'ios',
    environment = excluded.environment,
    last_seen_at = now(),
    disabled_at = null,
    failure_count = 0,
    last_failure_at = null,
    updated_at = now()
  returning * into registered;

  -- Five installations cover normal phone/tablet/test-device use while
  -- bounding both retained rows and per-event push fanout. Oldest bindings are
  -- removed (and their unsent deliveries cascade) rather than accumulating.
  with excess as (
    select device.id
    from public.user_devices device
    where device.user_id = actor
      and device.platform = 'ios'
      and device.device_id is not null
      and device.environment in ('sandbox', 'production')
      and device.disabled_at is null
    order by
      (device.id = registered.id) desc,
      coalesce(device.last_seen_at, device.updated_at, device.created_at) desc,
      device.id desc
    offset 5
  )
  delete from public.user_devices device
  using excess
  where device.id = excess.id;

  -- Retain at most five disabled records for diagnostics/re-registration. This
  -- keeps repeated token rotation plus APNs invalidation from growing storage
  -- without bound while the five active-device fanout cap remains unchanged.
  with excess as (
    select device.id
    from public.user_devices device
    where device.user_id = actor
      and device.platform = 'ios'
      and device.device_id is not null
    order by
      (device.id = registered.id) desc,
      (device.disabled_at is null) desc,
      coalesce(device.last_seen_at, device.updated_at, device.created_at) desc,
      device.id desc
    offset 10
  )
  delete from public.user_devices device
  using excess
  where device.id = excess.id;

  select count(*)::integer into active_device_count
  from public.user_devices device
  where device.user_id = actor
    and device.platform = 'ios'
    and device.device_id is not null
    and device.environment in ('sandbox', 'production')
    and device.disabled_at is null;

  return jsonb_build_object(
    'device_id', registered.device_id,
    'platform', registered.platform,
    'environment', registered.environment,
    'registered_at', coalesce(registered.last_seen_at, registered.updated_at),
    'active_device_count', active_device_count,
    'active_device_limit', 5
  );
end;
$$;

create or replace function public.unregister_user_device_v2(p_device_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  removed_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_live_account_as(actor) then
    raise exception 'account unavailable' using errcode = '42501';
  end if;
  if p_device_id is null then
    raise exception 'device id required' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('mugshot-device-account:' || actor::text, 0)
  );
  delete from public.user_devices device
  where device.user_id = actor and device.device_id = p_device_id;
  get diagnostics removed_count = row_count;
  return removed_count > 0;
end;
$$;

-- A device changes account ownership while APNs is still disabled locally.
-- The random installation identifier and last known token form an
-- installation-scoped capability; claiming deletes only stale push bindings
-- and never grants access to the previous account's data.
create or replace function public.claim_user_device_installation_v2(
  p_device_id uuid,
  p_environment text,
  p_known_push_token text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_token text := lower(btrim(coalesce(p_known_push_token, '')));
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_live_account_as(actor) then
    raise exception 'account unavailable' using errcode = '42501';
  end if;
  if p_device_id is null
     or p_environment not in ('sandbox', 'production')
     or (
       normalized_token <> '' and (
         char_length(normalized_token) not between 64 and 200
         or normalized_token !~ '^[a-f0-9]+$'
       )
     ) then
    raise exception 'invalid device claim' using errcode = '22023';
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('mugshot-device-installation:' || p_device_id::text, 0)
  );
  if normalized_token <> '' then
    perform pg_advisory_xact_lock(
      hashtextextended(
        'mugshot-apns-token:' || p_environment || ':' || normalized_token,
        0
      )
    );
  end if;

  delete from public.user_devices device
  where device.user_id <> actor
    and (
      device.device_id = p_device_id
      or (
        normalized_token <> ''
        and device.environment = p_environment
        and device.push_token = normalized_token
      )
    );

  return true;
end;
$$;

revoke all on function public.register_user_device_v2(uuid,text,text)
  from public, anon, authenticated;
revoke all on function public.unregister_user_device_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.claim_user_device_installation_v2(uuid,text,text)
  from public, anon, authenticated;
grant execute on function public.register_user_device_v2(uuid,text,text)
  to authenticated;
grant execute on function public.unregister_user_device_v2(uuid)
  to authenticated;
grant execute on function public.claim_user_device_installation_v2(uuid,text,text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Suspended accounts keep settings, appeals, and export access, but neither
-- receive new social activity nor surface old social activity while suspended.
-- ---------------------------------------------------------------------------

alter table private.activity_push_deliveries
  add column if not exists claim_token uuid,
  add column if not exists lease_version bigint not null default 0;

create or replace function private.activity_recipient_is_eligible_v2(
  p_recipient uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_recipient)
    and not private.has_active_moderation_action(
      'user', p_recipient, array['account_suspended']::text[]
    );
$$;

revoke all on function private.activity_recipient_is_eligible_v2(uuid)
  from public, anon, authenticated;

create or replace function private.activity_event_is_visible(
  p_event public.activity_events,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not null
    and p_event.recipient_id = p_viewer
    and p_event.suppressed_at is null
    and private.activity_recipient_is_eligible_v2(p_viewer)
    and private.can_view_user_as(p_event.actor_user_id, p_viewer)
    and case p_event.kind
      when 'friend_post' then
        p_event.visit_id is not null
        and private.can_view_visit_as(p_event.visit_id, p_viewer)
      when 'tag' then
        p_event.visit_id is not null
        and exists (
          select 1
          from public.visit_companions tag
          where tag.visit_id = p_event.visit_id
            and tag.companion_user_id = p_viewer
            and tag.added_by = p_event.actor_user_id
        )
      when 'shared_mugshot_invitation' then
        p_event.shared_memory_id is not null
        and exists (
          select 1
          from public.shared_memory_members member
          where member.shared_memory_id = p_event.shared_memory_id
            and member.user_id = p_viewer
            and member.invited_by = p_event.actor_user_id
            and member.status in ('pending', 'accepted')
        )
      when 'collaborative_list_invitation' then
        p_event.cafe_list_id is not null
        and exists (
          select 1
          from public.cafe_list_members member
          where member.list_id = p_event.cafe_list_id
            and member.user_id = p_viewer
            and member.invited_by = p_event.actor_user_id
            and member.invitation_status in ('pending', 'accepted')
        )
      when 'like' then
        p_event.visit_id is not null
        and private.can_view_visit_as(p_event.visit_id, p_viewer)
      when 'comment' then
        p_event.comment_id is not null
        and private.can_view_comment_as(p_event.comment_id, p_viewer)
      when 'comment_mention' then
        p_event.comment_id is not null
        and private.can_view_comment_as(p_event.comment_id, p_viewer)
        and exists (
          select 1 from public.comment_mentions mention
          where mention.comment_id = p_event.comment_id
            and mention.mentioned_user_id = p_viewer
        )
      when 'reaction' then
        p_event.visit_id is not null
        and private.can_view_visit_as(p_event.visit_id, p_viewer)
      when 'friend_request' then
        p_event.friend_request_id is not null
        and exists (
          select 1
          from public.friend_requests request
          where request.id = p_event.friend_request_id
            and request.to_user_id = p_viewer
            and request.from_user_id = p_event.actor_user_id
            and request.status = 'pending'
        )
      when 'friend_request_accepted' then
        p_event.friend_request_id is not null
        and exists (
          select 1
          from public.friend_requests request
          where request.id = p_event.friend_request_id
            and request.from_user_id = p_viewer
            and request.to_user_id = p_event.actor_user_id
            and request.status = 'accepted'
        )
      else false
    end;
$$;

revoke all on function private.activity_event_is_visible(public.activity_events,uuid)
  from public, anon, authenticated;

create or replace function private.guard_activity_recipient_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.activity_recipient_is_eligible_v2(new.recipient_id) then
    return null;
  end if;
  return new;
end;
$$;

create or replace function private.suppress_suspended_recipient_activity_v2()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.subject_kind = 'user'
     and new.action_kind = 'account_suspended'
     and new.revoked_at is null
     and new.starts_at <= now()
     and (new.ends_at is null or new.ends_at > now()) then
    update public.activity_events event
    set suppressed_at = coalesce(event.suppressed_at, now())
    where event.recipient_id = new.subject_id;

    update private.activity_push_deliveries delivery
    set
      status = 'cancelled',
      completed_at = now(),
      claimed_at = null,
      claim_token = null,
      last_error_code = 'recipient_suspended',
      updated_at = now()
    from public.activity_events event
    where delivery.activity_event_id = event.id
      and event.recipient_id = new.subject_id
      and delivery.status in ('pending', 'processing');
  end if;
  return new;
end;
$$;

revoke all on function private.guard_activity_recipient_v2()
  from public, anon, authenticated;
revoke all on function private.suppress_suspended_recipient_activity_v2()
  from public, anon, authenticated;

drop trigger if exists guard_suspended_activity_recipient on public.activity_events;
create trigger guard_suspended_activity_recipient
before insert on public.activity_events
for each row execute function private.guard_activity_recipient_v2();

drop trigger if exists suppress_suspended_recipient_activity
  on private.moderation_actions;

-- ---------------------------------------------------------------------------
-- Reaction state has one stable event per (visit, actor). A change replaces the
-- prior event so metadata and notification content cannot contradict the row.
-- ---------------------------------------------------------------------------

with ranked as (
  select
    event.id,
    row_number() over (
      partition by event.recipient_id, event.actor_user_id, event.visit_id
      order by event.created_at desc, event.id desc
    ) as position
  from public.activity_events event
  where event.kind = 'reaction'
)
delete from public.activity_events event
using ranked
where event.id = ranked.id and ranked.position > 1;

update public.activity_events event
set
  dedupe_key = 'reaction:' || event.visit_id::text || ':'
    || event.actor_user_id::text,
  metadata = jsonb_build_object('reaction', reaction.reaction)
from public.visit_reactions reaction
where event.kind = 'reaction'
  and event.visit_id = reaction.visit_id
  and event.actor_user_id = reaction.user_id;

delete from public.activity_events event
where event.kind = 'reaction'
  and not exists (
    select 1
    from public.visit_reactions reaction
    where reaction.visit_id = event.visit_id
      and reaction.user_id = event.actor_user_id
  );

create or replace function private.activity_from_reaction_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare owner_id uuid;
begin
  select visit.user_id into owner_id
  from public.visits visit
  where visit.id = new.visit_id;

  delete from public.activity_events event
  where event.kind = 'reaction'
    and event.visit_id = new.visit_id
    and event.actor_user_id = new.user_id;

  perform private.create_activity_event_v1(
    owner_id, new.user_id, 'reaction',
    'reaction:' || new.visit_id::text || ':' || new.user_id::text,
    'New reaction', 'Someone reacted to your MugShot.', new.visit_id,
    null, null, null, null,
    jsonb_build_object('reaction', new.reaction)
  );
  return new;
end;
$$;

revoke all on function private.activity_from_reaction_v1()
  from public, anon, authenticated;

drop trigger if exists activity_from_reaction on public.visit_reactions;
create trigger activity_from_reaction
after insert or update of reaction on public.visit_reactions
for each row execute function private.activity_from_reaction_v1();

-- ---------------------------------------------------------------------------
-- Fenced push leases and durable delivery classification.
-- ---------------------------------------------------------------------------

update private.activity_push_deliveries delivery
set
  status = 'pending',
  claimed_at = null,
  claim_token = null,
  updated_at = now()
where delivery.status = 'processing';

alter table private.activity_push_deliveries
  drop constraint if exists activity_push_delivery_lease_version_check,
  add constraint activity_push_delivery_lease_version_check
    check (lease_version >= 0),
  drop constraint if exists activity_push_delivery_claim_state_check,
  add constraint activity_push_delivery_claim_state_check check (
    (
      status = 'processing'
      and claimed_at is not null
      and claim_token is not null
    )
    or (
      status <> 'processing'
      and claimed_at is null
      and claim_token is null
    )
  );

create or replace function private.enqueue_activity_push_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.suppressed_at is not null
     or not private.activity_recipient_is_eligible_v2(new.recipient_id)
     or not private.activity_kind_push_enabled(new.recipient_id, new.kind) then
    return new;
  end if;

  insert into private.activity_push_deliveries (
    activity_event_id, device_record_id
  )
  select new.id, device.id
  from public.user_devices device
  where device.user_id = new.recipient_id
    and device.platform = 'ios'
    and device.device_id is not null
    and device.environment in ('sandbox', 'production')
    and device.disabled_at is null
  order by coalesce(device.last_seen_at, device.updated_at, device.created_at) desc,
           device.id desc
  limit 5
  on conflict (activity_event_id, device_record_id) do nothing;
  return new;
end;
$$;

revoke all on function private.enqueue_activity_push_v1()
  from public, anon, authenticated;

create or replace function public.claim_activity_push_batch_v2(
  p_limit integer default 25
)
returns table (
  delivery_id uuid,
  activity_event_id uuid,
  recipient_id uuid,
  device_record_id uuid,
  push_token text,
  environment text,
  title text,
  body text,
  deep_link text,
  attempt_count integer,
  claim_token uuid,
  lease_version bigint
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Edge requests time out after ten seconds. Two minutes allows receipt write
  -- latency while still recovering a crashed worker promptly.
  update private.activity_push_deliveries delivery
  set
    status = 'pending',
    claimed_at = null,
    claim_token = null,
    updated_at = now(),
    last_error_code = 'lease_expired'
  where delivery.status = 'processing'
    and delivery.claimed_at < now() - interval '2 minutes';

  update private.activity_push_deliveries delivery
  set
    status = 'cancelled',
    completed_at = now(),
    claimed_at = null,
    claim_token = null,
    updated_at = now(),
    last_error_code = case
      when not private.activity_recipient_is_eligible_v2(event.recipient_id)
        then 'recipient_unavailable'
      else 'no_longer_deliverable'
    end
  from public.activity_events event, public.user_devices device
  where delivery.activity_event_id = event.id
    and delivery.device_record_id = device.id
    and delivery.status = 'pending'
    and (
      device.disabled_at is not null
      or not private.activity_recipient_is_eligible_v2(event.recipient_id)
      or not private.activity_event_is_visible(event, event.recipient_id)
      or not private.activity_kind_push_enabled(event.recipient_id, event.kind)
    );

  return query
  with claimed as (
    select delivery.id
    from private.activity_push_deliveries delivery
    join public.activity_events event on event.id = delivery.activity_event_id
    join public.user_devices device on device.id = delivery.device_record_id
    where delivery.status = 'pending'
      and delivery.available_at <= now()
      and device.disabled_at is null
      and private.activity_recipient_is_eligible_v2(event.recipient_id)
      and private.activity_event_is_visible(event, event.recipient_id)
      and private.activity_kind_push_enabled(event.recipient_id, event.kind)
    order by delivery.available_at, delivery.created_at, delivery.id
    for update of delivery skip locked
    limit least(greatest(coalesce(p_limit, 25), 1), 50)
  ), updated as (
    update private.activity_push_deliveries delivery
    set
      status = 'processing',
      claimed_at = now(),
      claim_token = gen_random_uuid(),
      lease_version = delivery.lease_version + 1,
      attempt_count = delivery.attempt_count + 1,
      updated_at = now()
    where delivery.id in (select claimed.id from claimed)
    returning delivery.*
  )
  select
    updated.id,
    event.id,
    event.recipient_id,
    device.id,
    device.push_token,
    device.environment,
    event.title,
    event.body,
    event.deep_link,
    updated.attempt_count,
    updated.claim_token,
    updated.lease_version
  from updated
  join public.activity_events event on event.id = updated.activity_event_id
  join public.user_devices device on device.id = updated.device_record_id
  order by updated.created_at, updated.id;
end;
$$;

create or replace function public.revalidate_activity_push_delivery_v2(
  p_delivery_id uuid,
  p_claim_token uuid,
  p_lease_version bigint
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target private.activity_push_deliveries%rowtype;
  event_row public.activity_events%rowtype;
  device_disabled_at timestamptz;
  cancellation_code text;
  suspension_imminent boolean := false;
begin
  if p_delivery_id is null or p_claim_token is null or p_lease_version is null then
    raise exception 'delivery lease required' using errcode = '22023';
  end if;

  select delivery.* into target
  from private.activity_push_deliveries delivery
  where delivery.id = p_delivery_id
    and delivery.status = 'processing'
    and delivery.claim_token = p_claim_token
    and delivery.lease_version = p_lease_version
  for update of delivery;

  -- A stale or reclaimed worker must never affect the current delivery. The
  -- next claim pass will recover an expired lease; this worker simply stops.
  if not found or target.claimed_at < now() - interval '2 minutes' then
    return false;
  end if;

  select event.* into event_row
  from public.activity_events event
  where event.id = target.activity_event_id;
  select device.disabled_at into device_disabled_at
  from public.user_devices device
  where device.id = target.device_record_id;
  if event_row.id is null then return false; end if;

  -- APNs transport is bounded at ten seconds. Hold any delivery whose account
  -- suspension begins inside a conservative thirty-second dispatch horizon so
  -- wall-clock activation cannot race the final authorization check.
  select exists (
    select 1
    from private.moderation_actions action
    where action.subject_kind = 'user'
      and action.subject_id = event_row.recipient_id
      and action.action_kind = 'account_suspended'
      and action.revoked_at is null
      and action.starts_at <= clock_timestamp() + interval '30 seconds'
      and (action.ends_at is null or action.ends_at > clock_timestamp())
  ) into suspension_imminent;

  if device_disabled_at is null
     and not suspension_imminent
     and private.activity_recipient_is_eligible_v2(event_row.recipient_id)
     and private.activity_event_is_visible(event_row, event_row.recipient_id)
     and private.activity_kind_push_enabled(event_row.recipient_id, event_row.kind) then
    return true;
  end if;

  cancellation_code := case
    when suspension_imminent then 'recipient_suspension_imminent'
    when not private.activity_recipient_is_eligible_v2(event_row.recipient_id)
      then 'recipient_became_ineligible'
    when device_disabled_at is not null then 'device_became_unavailable'
    else 'activity_became_undeliverable'
  end;
  update private.activity_push_deliveries delivery
  set status = 'cancelled', completed_at = now(), claimed_at = null,
      claim_token = null, last_error_code = cancellation_code,
      updated_at = now()
  where delivery.id = p_delivery_id
    and delivery.status = 'processing'
    and delivery.claim_token = p_claim_token
    and delivery.lease_version = p_lease_version;
  return false;
end;
$$;

create or replace function public.complete_activity_push_delivery_v2(
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
  target private.activity_push_deliveries;
  final_status text;
  retry_base_seconds integer;
  retry_jitter_seconds integer;
begin
  if p_delivery_id is null or p_claim_token is null or p_lease_version is null then
    raise exception 'delivery lease required' using errcode = '22023';
  end if;
  if p_outcome not in ('succeeded', 'retryable', 'terminal', 'unregistered') then
    raise exception 'invalid delivery outcome' using errcode = '22023';
  end if;
  if p_retry_after_seconds is not null
     and p_retry_after_seconds not between 0 and 86400 then
    raise exception 'invalid retry delay' using errcode = '22023';
  end if;

  select delivery.* into target
  from private.activity_push_deliveries delivery
  where delivery.id = p_delivery_id
    and delivery.status = 'processing'
    and delivery.claim_token = p_claim_token
    and delivery.lease_version = p_lease_version
  for update;

  -- A late worker cannot mark or disable anything after a newer lease exists.
  if target.id is null then return false; end if;

  if p_outcome = 'succeeded' then
    final_status := 'sent';
  elsif p_outcome in ('terminal', 'unregistered') or target.attempt_count >= 12 then
    final_status := 'failed';
  else
    final_status := 'pending';
  end if;

  if final_status = 'pending' then
    retry_base_seconds := greatest(
      coalesce(p_retry_after_seconds, 0),
      least(
        (60 * power(2::numeric, least(target.attempt_count - 1, 8)))::integer,
        21600
      )
    );
    retry_jitter_seconds := mod(
      hashtextextended(target.id::text || ':' || target.lease_version::text, 0)
        & 2147483647,
      greatest((retry_base_seconds / 5)::bigint, 1)
    )::integer;
  else
    retry_base_seconds := 0;
    retry_jitter_seconds := 0;
  end if;

  update private.activity_push_deliveries delivery
  set
    status = final_status,
    available_at = case
      when final_status = 'pending' then
        now() + make_interval(secs => retry_base_seconds + retry_jitter_seconds)
      else delivery.available_at
    end,
    completed_at = case when final_status = 'pending' then null else now() end,
    claimed_at = null,
    claim_token = null,
    last_error_code = left(
      coalesce(nullif(btrim(p_error_code), ''), p_outcome),
      80
    ),
    updated_at = now()
  where delivery.id = target.id;

  if p_outcome = 'succeeded' then
    update public.user_devices device
    set failure_count = 0, last_failure_at = null, updated_at = now()
    where device.id = target.device_record_id;
  else
    update public.user_devices device
    set
      failure_count = device.failure_count + 1,
      last_failure_at = now(),
      disabled_at = case
        when p_outcome = 'unregistered' then now()
        else device.disabled_at
      end,
      updated_at = now()
    where device.id = target.device_record_id;
  end if;

  if p_outcome = 'unregistered' then
    update private.activity_push_deliveries delivery
    set
      status = 'cancelled',
      completed_at = now(),
      claimed_at = null,
      claim_token = null,
      last_error_code = 'device_unregistered',
      updated_at = now()
    where delivery.device_record_id = target.device_record_id
      and delivery.id <> target.id
      and delivery.status in ('pending', 'processing');
  end if;

  return true;
end;
$$;

-- The unfenced protocol cannot be used by any service after this migration.
revoke all on function public.claim_activity_push_batch_v1(integer)
  from public, anon, authenticated, service_role;
revoke all on function public.complete_activity_push_delivery_v1(uuid,boolean,text,boolean)
  from public, anon, authenticated, service_role;
revoke all on function public.claim_activity_push_batch_v2(integer)
  from public, anon, authenticated, service_role;
revoke all on function public.revalidate_activity_push_delivery_v2(uuid,uuid,bigint)
  from public, anon, authenticated, service_role;
revoke all on function public.complete_activity_push_delivery_v2(
  uuid,uuid,bigint,text,text,integer
) from public, anon, authenticated, service_role;
grant execute on function public.claim_activity_push_batch_v2(integer)
  to service_role;
grant execute on function public.revalidate_activity_push_delivery_v2(uuid,uuid,bigint)
  to service_role;
grant execute on function public.complete_activity_push_delivery_v2(
  uuid,uuid,bigint,text,text,integer
) to service_role;

create trigger suppress_suspended_recipient_activity
after insert or update of revoked_at, starts_at, ends_at, action_kind
on private.moderation_actions
for each row execute function private.suppress_suspended_recipient_activity_v2();

comment on function public.register_user_device_v2(uuid,text,text) is
  'Caller-bound normalized APNs registration; one owner per environment token, at most five active devices, and bounded material registration churn.';
comment on function public.claim_activity_push_batch_v2(integer) is
  'Service-only fenced lease claim; returns the token and version required for completion.';
comment on function public.revalidate_activity_push_delivery_v2(uuid,uuid,bigint) is
  'Service-only final eligibility and lease check immediately before APNs. It cancels ineligible deliveries but cannot recall a request after APNs transmission begins.';
comment on function public.complete_activity_push_delivery_v2(uuid,uuid,bigint,text,text,integer) is
  'Service-only fenced completion with durable retry, terminal, and Unregistered outcomes.';

commit;
