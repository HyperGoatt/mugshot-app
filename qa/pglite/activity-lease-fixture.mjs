export async function createActivityLeaseFixture(db) {
await db.exec(String.raw`
create role anon;
create role authenticated;
create role service_role;
create schema private;
create table public.users (id uuid primary key);
create table public.user_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  device_id uuid,
  push_token text not null,
  platform text not null default 'ios',
  environment text not null,
  last_seen_at timestamptz,
  disabled_at timestamptz,
  failure_count integer not null default 0,
  last_failure_at timestamptz,
  supports_badge_sync boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table public.activity_events (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.users(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null,
  deep_link text not null,
  read_at timestamptz,
  suppressed_at timestamptz,
  created_at timestamptz not null default now()
);
create table private.activity_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  activity_event_id uuid not null references public.activity_events(id) on delete cascade,
  device_record_id uuid not null references public.user_devices(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending','processing','sent','failed','cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  available_at timestamptz not null default now(),
  claimed_at timestamptz,
  claim_token uuid,
  lease_version bigint not null default 0,
  completed_at timestamptz,
  last_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(activity_event_id, device_record_id)
);
create table private.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  subject_kind text not null,
  subject_id uuid not null,
  action_kind text not null,
  starts_at timestamptz not null,
  ends_at timestamptz,
  revoked_at timestamptz
);
create function private.activity_recipient_is_eligible_v2(p_recipient uuid)
returns boolean language sql stable as $$
  select p_recipient is not null and not exists (
    select 1 from private.moderation_actions action
    where action.subject_kind = 'user'
      and action.subject_id = p_recipient
      and action.action_kind = 'account_suspended'
      and action.revoked_at is null
      and action.starts_at <= now()
      and (action.ends_at is null or action.ends_at > now())
  )
$$;
create function private.activity_kind_push_enabled(p_recipient uuid, p_kind text)
returns boolean language sql stable as $$ select true $$;
create function private.activity_event_is_visible(
  p_event public.activity_events,
  p_viewer uuid
) returns boolean language sql stable as $$
  select p_viewer = p_event.recipient_id and p_event.suppressed_at is null
$$;
`)

}
