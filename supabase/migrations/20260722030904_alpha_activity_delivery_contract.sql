begin;

-- Alpha activity delivery is expand-first. Existing notification rows remain
-- untouched, but neither legacy push path may execute again. New activity is
-- durable in Postgres and push delivery is an explicit, secret-authenticated
-- worker concern with no credential embedded in a database trigger.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

drop trigger if exists on_notification_insert on public.notifications;
drop function if exists public.send_push_notification_trigger();
drop trigger if exists "notify-friends-on-new-visit" on public.visits;

-- ---------------------------------------------------------------------------
-- Caller-bound device registration. The raw token table remains unreachable
-- from client roles; authenticated callers can only register or remove the
-- current installation through RPCs that bind user_id to auth.uid().
-- ---------------------------------------------------------------------------

alter table public.user_devices
  add column if not exists device_id uuid,
  add column if not exists environment text,
  add column if not exists last_seen_at timestamptz,
  add column if not exists disabled_at timestamptz,
  add column if not exists failure_count integer not null default 0,
  add column if not exists last_failure_at timestamptz;

alter table public.user_devices
  drop constraint if exists user_devices_environment_check,
  add constraint user_devices_environment_check
    check (environment is null or environment in ('sandbox', 'production')),
  drop constraint if exists user_devices_failure_count_check,
  add constraint user_devices_failure_count_check check (failure_count >= 0);

create unique index if not exists user_devices_user_installation_idx
  on public.user_devices (user_id, device_id)
  where device_id is not null;

create index if not exists user_devices_push_ready_idx
  on public.user_devices (user_id, updated_at desc, id)
  where device_id is not null and disabled_at is null;

alter table public.user_devices enable row level security;
revoke all on table public.user_devices from public, anon, authenticated;

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
  normalized_token text := btrim(coalesce(p_push_token, ''));
  registered public.user_devices;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_device_id is null
     or char_length(normalized_token) not between 64 and 200
     or normalized_token !~ '^[A-Fa-f0-9]+$'
     or p_environment not in ('sandbox', 'production') then
    raise exception 'invalid device registration' using errcode = '22023';
  end if;

  -- An APNs token identifies one live installation. Reassignment is allowed
  -- only by presenting that token, and no token value is ever returned.
  delete from public.user_devices device
  where device.push_token = normalized_token
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

  return jsonb_build_object(
    'device_id', registered.device_id,
    'platform', registered.platform,
    'environment', registered.environment,
    'registered_at', coalesce(registered.last_seen_at, registered.updated_at)
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
  if p_device_id is null then
    raise exception 'device id required' using errcode = '22023';
  end if;

  delete from public.user_devices device
  where device.user_id = actor and device.device_id = p_device_id;
  get diagnostics removed_count = row_count;
  return removed_count > 0;
end;
$$;

revoke all on function public.register_user_device_v2(uuid,text,text)
  from public, anon, authenticated;
revoke all on function public.unregister_user_device_v2(uuid)
  from public, anon, authenticated;
grant execute on function public.register_user_device_v2(uuid,text,text)
  to authenticated;
grant execute on function public.unregister_user_device_v2(uuid)
  to authenticated;

-- ---------------------------------------------------------------------------
-- Durable preferences and activity history. Raw tables have no client grant;
-- all reads and writes are caller-bound projections/RPCs.
-- ---------------------------------------------------------------------------

create table public.notification_preferences (
  user_id uuid primary key references public.users(id) on delete cascade,
  push_enabled boolean not null default true,
  friend_posts boolean not null default true,
  tags boolean not null default true,
  shared_mugshot_invitations boolean not null default true,
  collaborative_list_invitations boolean not null default true,
  likes boolean not null default true,
  comments boolean not null default true,
  reactions boolean not null default true,
  friend_requests boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.activity_events (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.users(id) on delete cascade,
  actor_user_id uuid not null references public.users(id) on delete cascade,
  kind text not null check (kind in (
    'friend_post', 'tag', 'shared_mugshot_invitation',
    'collaborative_list_invitation', 'like', 'comment', 'comment_mention', 'reaction',
    'friend_request', 'friend_request_accepted'
  )),
  dedupe_key text not null check (char_length(dedupe_key) between 1 and 240),
  title text not null check (char_length(title) between 1 and 120),
  body text not null check (char_length(body) between 1 and 280),
  visit_id uuid references public.visits(id) on delete cascade,
  comment_id uuid references public.comments(id) on delete cascade,
  shared_memory_id uuid references public.shared_memories(id) on delete cascade,
  cafe_list_id uuid references public.cafe_lists(id) on delete cascade,
  friend_request_id uuid references public.friend_requests(id) on delete cascade,
  deep_link text not null check (char_length(deep_link) between 1 and 500),
  metadata jsonb not null default '{}'::jsonb
    check (jsonb_typeof(metadata) = 'object'),
  created_at timestamptz not null default now(),
  read_at timestamptz,
  suppressed_at timestamptz,
  unique (recipient_id, dedupe_key),
  check (recipient_id <> actor_user_id)
);

create table private.activity_push_deliveries (
  id uuid primary key default gen_random_uuid(),
  activity_event_id uuid not null references public.activity_events(id) on delete cascade,
  device_record_id uuid not null references public.user_devices(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'processing', 'sent', 'failed', 'cancelled')),
  attempt_count integer not null default 0 check (attempt_count >= 0),
  available_at timestamptz not null default now(),
  claimed_at timestamptz,
  completed_at timestamptz,
  last_error_code text check (char_length(coalesce(last_error_code, '')) <= 80),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (activity_event_id, device_record_id)
);

create index activity_events_recipient_created_idx
  on public.activity_events (recipient_id, created_at desc, id desc)
  where suppressed_at is null;
create index activity_events_pair_idx
  on public.activity_events (recipient_id, actor_user_id, created_at desc);
create index activity_events_visit_idx
  on public.activity_events (visit_id, created_at desc)
  where visit_id is not null;
create index activity_push_deliveries_ready_idx
  on private.activity_push_deliveries (status, available_at, created_at, id)
  where status in ('pending', 'processing');

alter table public.notification_preferences enable row level security;
alter table public.activity_events enable row level security;
alter table private.activity_push_deliveries enable row level security;

revoke all on table public.notification_preferences
  from public, anon, authenticated;
revoke all on table public.activity_events
  from public, anon, authenticated;
revoke all on table private.activity_push_deliveries
  from public, anon, authenticated;

create or replace function private.activity_kind_push_enabled(
  p_recipient uuid,
  p_kind text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select preference.push_enabled and case p_kind
      when 'friend_post' then preference.friend_posts
      when 'tag' then preference.tags
      when 'shared_mugshot_invitation'
        then preference.shared_mugshot_invitations
      when 'collaborative_list_invitation'
        then preference.collaborative_list_invitations
      when 'like' then preference.likes
      when 'comment' then preference.comments
      when 'comment_mention' then preference.comments
      when 'reaction' then preference.reactions
      when 'friend_request' then preference.friend_requests
      when 'friend_request_accepted' then preference.friend_requests
      else false
    end
    from public.notification_preferences preference
    where preference.user_id = p_recipient
  ), true);
$$;

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

revoke all on function private.activity_kind_push_enabled(uuid,text)
  from public, anon, authenticated;
revoke all on function private.activity_event_is_visible(public.activity_events,uuid)
  from public, anon, authenticated;

create or replace function private.create_activity_event_v1(
  p_recipient uuid,
  p_actor uuid,
  p_kind text,
  p_dedupe_key text,
  p_title text,
  p_body text,
  p_visit_id uuid default null,
  p_comment_id uuid default null,
  p_shared_memory_id uuid default null,
  p_cafe_list_id uuid default null,
  p_friend_request_id uuid default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_id uuid;
  resolved_title text := left(btrim(coalesce(p_title, 'Activity')), 120);
  resolved_body text := left(btrim(coalesce(p_body, 'Open Mugshot to see what changed.')), 280);
  resolved_deep_link text := 'mugshot://activity';
  actor_label text;
begin
  if p_recipient is null or p_actor is null or p_recipient = p_actor
     or not private.can_socially_mutate_as(p_actor)
     or not private.can_view_user_as(p_actor, p_recipient) then
    return null;
  end if;

  select coalesce(
    nullif(btrim(profile.display_name), ''),
    '@' || profile.username,
    'Someone'
  ) into actor_label
  from public.users profile
  where profile.id = p_actor;

  if actor_label is null then return null; end if;

  case p_kind
    when 'friend_post' then
      if p_visit_id is null
         or not private.confirmed_friends(p_recipient, p_actor)
         or not private.can_view_visit_as(p_visit_id, p_recipient) then
        return null;
      end if;
      resolved_title := left(actor_label || ' posted a MugShot', 120);
      resolved_body := 'A fresh friend sip is waiting in Feed.';
      resolved_deep_link := 'mugshot://activity/visit/' || p_visit_id::text;
    when 'tag' then
      if p_visit_id is null or not exists (
        select 1 from public.visit_companions tag
        where tag.visit_id = p_visit_id
          and tag.companion_user_id = p_recipient
          and tag.added_by = p_actor
      ) then return null; end if;
      resolved_title := 'You were tagged';
      if private.can_view_visit_as(p_visit_id, p_recipient) then
        resolved_body := left(actor_label || ' tagged you in a MugShot.', 280);
        resolved_deep_link := 'mugshot://activity/visit/' || p_visit_id::text;
      else
        resolved_body := left(
          actor_label || ' tagged you in a MugShot you can''t view.', 280
        );
        resolved_deep_link := 'mugshot://activity';
      end if;
    when 'shared_mugshot_invitation' then
      if p_shared_memory_id is null or not exists (
        select 1 from public.shared_memory_members member
        where member.shared_memory_id = p_shared_memory_id
          and member.user_id = p_recipient
          and member.invited_by = p_actor
          and member.status = 'pending'
      ) then return null; end if;
      resolved_title := 'Share this MugShot memory?';
      resolved_body := left(actor_label || ' invited you to join a shared MugShot.', 280);
      -- Consent belongs on the invitation-management surface. Do not route
      -- directly into the source post before the recipient has accepted.
      resolved_deep_link := 'mugshot://activity/shared';
    when 'collaborative_list_invitation' then
      if p_cafe_list_id is null or not exists (
        select 1 from public.cafe_list_members member
        where member.list_id = p_cafe_list_id
          and member.user_id = p_recipient
          and member.invited_by = p_actor
          and member.invitation_status = 'pending'
      ) then return null; end if;
      resolved_title := 'Cafe list invitation';
      resolved_body := left(actor_label || ' invited you to plan cafes together.', 280);
      resolved_deep_link := 'mugshot://activity/lists';
    when 'like' then
      if p_visit_id is null
         or not private.can_view_visit_as(p_visit_id, p_recipient) then return null; end if;
      resolved_title := left(actor_label || ' liked your MugShot', 120);
      resolved_body := 'Your sip got a little love.';
      resolved_deep_link := 'mugshot://activity/visit/' || p_visit_id::text;
    when 'comment' then
      if p_visit_id is null or p_comment_id is null
         or not private.can_view_comment_as(p_comment_id, p_recipient) then return null; end if;
      resolved_title := left(actor_label || ' joined the conversation', 120);
      resolved_body := 'There is a new comment on a MugShot you can see.';
      resolved_deep_link := 'mugshot://activity/visit/' || p_visit_id::text;
    when 'comment_mention' then
      if p_visit_id is null or p_comment_id is null
         or not private.can_view_comment_as(p_comment_id, p_recipient)
         or not exists (
           select 1 from public.comment_mentions mention
           where mention.comment_id = p_comment_id
             and mention.mentioned_user_id = p_recipient
         ) then return null; end if;
      resolved_title := left(actor_label || ' mentioned you', 120);
      resolved_body := 'You were mentioned in a MugShot conversation.';
      resolved_deep_link := 'mugshot://activity/visit/' || p_visit_id::text;
    when 'reaction' then
      if p_visit_id is null
         or not private.can_view_visit_as(p_visit_id, p_recipient) then return null; end if;
      resolved_title := left(actor_label || ' reacted to your MugShot', 120);
      resolved_body := 'Open your sip to see the reaction.';
      resolved_deep_link := 'mugshot://activity/visit/' || p_visit_id::text;
    when 'friend_request' then
      if p_friend_request_id is null or not exists (
        select 1 from public.friend_requests request
        where request.id = p_friend_request_id
          and request.from_user_id = p_actor
          and request.to_user_id = p_recipient
          and request.status = 'pending'
      ) then return null; end if;
      resolved_title := left(actor_label || ' wants to connect', 120);
      resolved_body := 'You have a new friend request.';
      resolved_deep_link := 'mugshot://activity/people/' || p_actor::text;
    when 'friend_request_accepted' then
      if p_friend_request_id is null or not exists (
        select 1 from public.friend_requests request
        where request.id = p_friend_request_id
          and request.to_user_id = p_actor
          and request.from_user_id = p_recipient
          and request.status = 'accepted'
      ) then return null; end if;
      resolved_title := left(actor_label || ' accepted your request', 120);
      resolved_body := 'You are friends on Mugshot now.';
      resolved_deep_link := 'mugshot://activity/people/' || p_actor::text;
    else
      return null;
  end case;

  insert into public.activity_events (
    recipient_id, actor_user_id, kind, dedupe_key, title, body,
    visit_id, comment_id, shared_memory_id, cafe_list_id,
    friend_request_id, deep_link, metadata
  ) values (
    p_recipient, p_actor, p_kind, left(p_dedupe_key, 240),
    resolved_title, resolved_body, p_visit_id, p_comment_id,
    p_shared_memory_id, p_cafe_list_id, p_friend_request_id,
    resolved_deep_link, coalesce(p_metadata, '{}'::jsonb)
  )
  on conflict (recipient_id, dedupe_key) do nothing
  returning id into event_id;

  return event_id;
end;
$$;

revoke all on function private.create_activity_event_v1(
  uuid,uuid,text,text,text,text,uuid,uuid,uuid,uuid,uuid,jsonb
) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Event generation from authoritative social rows.
-- ---------------------------------------------------------------------------

create or replace function private.activity_from_visit_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare recipient uuid;
begin
  if new.upload_state <> 'complete'
     or lower(new.visibility) not in ('friends', 'everyone') then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.upload_state = 'complete'
     and lower(old.visibility) <> 'private' then return new; end if;

  for recipient in
    select friendship.friend_user_id
    from public.friends friendship
    where friendship.user_id = new.user_id
      and exists (
        select 1 from public.friends reciprocal
        where reciprocal.user_id = friendship.friend_user_id
          and reciprocal.friend_user_id = new.user_id
      )
  loop
    perform private.create_activity_event_v1(
      recipient, new.user_id, 'friend_post',
      'friend-post:' || new.id::text,
      'Friend post', 'A friend posted a MugShot.', new.id
    );
  end loop;
  return new;
end;
$$;

create or replace function private.activity_from_tag_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.create_activity_event_v1(
    new.companion_user_id, new.added_by, 'tag',
    'tag:' || new.visit_id::text || ':' || new.companion_user_id::text,
    'You were tagged', 'You were tagged in a MugShot.', new.visit_id
  );
  return new;
end;
$$;

create or replace function private.activity_from_comment_mention_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  comment_author uuid;
  target_visit uuid;
begin
  select comment.user_id, comment.visit_id
  into comment_author, target_visit
  from public.comments comment
  where comment.id = new.comment_id;

  perform private.create_activity_event_v1(
    new.mentioned_user_id, comment_author, 'comment_mention',
    'comment-mention:' || new.comment_id::text || ':' || new.mentioned_user_id::text,
    'You were mentioned', 'You were mentioned in a conversation.',
    target_visit, new.comment_id
  );
  return new;
end;
$$;

create or replace function private.cleanup_activity_from_comment_mention_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_events event
  where event.kind = 'comment_mention'
    and event.recipient_id = old.mentioned_user_id
    and event.comment_id = old.comment_id;
  return old;
end;
$$;

create or replace function private.cleanup_activity_from_tag_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_events event
  where event.kind = 'tag'
    and event.recipient_id = old.companion_user_id
    and event.actor_user_id = old.added_by
    and event.visit_id = old.visit_id;
  return old;
end;
$$;

create or replace function private.activity_from_shared_memory_invitation_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare source_visit uuid;
begin
  if new.status <> 'pending' or new.invited_by is null then return new; end if;
  if tg_op = 'UPDATE' then
    if old.status = 'pending' then
      -- An ambiguous client retry may refresh the membership row. Preserve the
      -- original activity instead of notifying the same pending invitation twice.
      return new;
    end if;
  end if;
  select memory.source_visit_id into source_visit
  from public.shared_memories memory
  where memory.id = new.shared_memory_id;
  perform private.create_activity_event_v1(
    new.user_id, new.invited_by, 'shared_mugshot_invitation',
    'shared-mugshot-invitation:' || new.id::text || ':'
      || extract(epoch from new.created_at)::text,
    'Shared MugShot invitation', 'Join a shared MugShot.',
    source_visit, null, new.shared_memory_id
  );
  return new;
end;
$$;

create or replace function private.cleanup_activity_from_shared_memory_invitation_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.activity_events event
    where event.kind = 'shared_mugshot_invitation'
      and event.recipient_id = old.user_id
      and event.actor_user_id = old.invited_by
      and event.shared_memory_id = old.shared_memory_id;
    return old;
  elsif old.status = 'pending' and new.status <> 'pending' then
    delete from public.activity_events event
    where event.kind = 'shared_mugshot_invitation'
      and event.recipient_id = old.user_id
      and event.actor_user_id = old.invited_by
      and event.shared_memory_id = old.shared_memory_id;
  end if;
  return new;
end;
$$;

create or replace function private.activity_from_cafe_list_invitation_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.invitation_status <> 'pending' then return new; end if;
  if tg_op = 'UPDATE' then
    if old.invitation_status = 'pending' then
      -- Keep a still-pending invitation idempotent even if its legacy RPC
      -- rewrites created_at during an ambiguous retry.
      return new;
    end if;
  end if;
  perform private.create_activity_event_v1(
    new.user_id, new.invited_by, 'collaborative_list_invitation',
    'cafe-list-invitation:' || new.list_id::text || ':' || new.user_id::text
      || ':' || extract(epoch from new.created_at)::text,
    'Cafe list invitation', 'Plan cafes together.',
    null, null, null, new.list_id
  );
  return new;
end;
$$;

create or replace function private.cleanup_activity_from_cafe_list_invitation_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.activity_events event
    where event.kind = 'collaborative_list_invitation'
      and event.recipient_id = old.user_id
      and event.actor_user_id = old.invited_by
      and event.cafe_list_id = old.list_id;
    return old;
  elsif old.invitation_status = 'pending'
        and new.invitation_status <> 'pending' then
    delete from public.activity_events event
    where event.kind = 'collaborative_list_invitation'
      and event.recipient_id = old.user_id
      and event.actor_user_id = old.invited_by
      and event.cafe_list_id = old.list_id;
  end if;
  return new;
end;
$$;

create or replace function private.activity_from_like_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare owner_id uuid;
begin
  select visit.user_id into owner_id from public.visits visit where visit.id = new.visit_id;
  perform private.create_activity_event_v1(
    owner_id, new.user_id, 'like', 'like:' || new.id::text,
    'New like', 'Someone liked your MugShot.', new.visit_id
  );
  return new;
end;
$$;

create or replace function private.cleanup_activity_from_like_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_events event
  where event.kind = 'like' and event.dedupe_key = 'like:' || old.id::text;
  return old;
end;
$$;

create or replace function private.activity_from_comment_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
  parent_owner_id uuid;
begin
  select visit.user_id into owner_id from public.visits visit where visit.id = new.visit_id;
  if owner_id is distinct from new.user_id then
    perform private.create_activity_event_v1(
      owner_id, new.user_id, 'comment',
      'comment:' || new.id::text || ':post-owner',
      'New comment', 'Someone commented on your MugShot.',
      new.visit_id, new.id
    );
  end if;

  if new.parent_comment_id is not null then
    select comment.user_id into parent_owner_id
    from public.comments comment where comment.id = new.parent_comment_id;
    if parent_owner_id is distinct from new.user_id
       and parent_owner_id is distinct from owner_id then
      perform private.create_activity_event_v1(
        parent_owner_id, new.user_id, 'comment',
        'comment:' || new.id::text || ':reply-owner',
        'New reply', 'Someone replied in a MugShot conversation.',
        new.visit_id, new.id
      );
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.suppress_activity_from_comment_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.removed_at is not null and old.removed_at is null then
    update public.activity_events event
    set suppressed_at = now()
    where event.kind in ('comment', 'comment_mention')
      and event.comment_id = new.id;
  end if;
  return new;
end;
$$;

create or replace function private.activity_from_reaction_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare owner_id uuid;
begin
  select visit.user_id into owner_id from public.visits visit where visit.id = new.visit_id;
  perform private.create_activity_event_v1(
    owner_id, new.user_id, 'reaction',
    'reaction:' || new.visit_id::text || ':' || new.user_id::text || ':'
      || extract(epoch from new.created_at)::text,
    'New reaction', 'Someone reacted to your MugShot.', new.visit_id,
    null, null, null, null,
    jsonb_build_object('reaction', new.reaction)
  );
  return new;
end;
$$;

create or replace function private.cleanup_activity_from_reaction_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_events event
  where event.kind = 'reaction'
    and event.visit_id = old.visit_id
    and event.actor_user_id = old.user_id;
  return old;
end;
$$;

create or replace function private.activity_from_friend_request_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    perform private.create_activity_event_v1(
      new.to_user_id, new.from_user_id, 'friend_request',
      'friend-request:' || new.id::text,
      'Friend request', 'Someone wants to connect.',
      null, null, null, null, new.id
    );
  elsif tg_op = 'UPDATE' then
    if new.status = 'pending' and old.status is distinct from 'pending' then
      perform private.create_activity_event_v1(
        new.to_user_id, new.from_user_id, 'friend_request',
        'friend-request:' || new.id::text,
        'Friend request', 'Someone wants to connect.',
        null, null, null, null, new.id
      );
    elsif old.status = 'pending' and new.status = 'accepted' then
      perform private.create_activity_event_v1(
        new.from_user_id, new.to_user_id, 'friend_request_accepted',
        'friend-request-accepted:' || new.id::text,
        'Friend request accepted', 'You are friends now.',
        null, null, null, null, new.id
      );
    end if;
  end if;
  return new;
end;
$$;

revoke all on function private.activity_from_visit_v1()
  from public, anon, authenticated;
revoke all on function private.activity_from_tag_v1()
  from public, anon, authenticated;
revoke all on function private.cleanup_activity_from_tag_v1()
  from public, anon, authenticated;
revoke all on function private.activity_from_shared_memory_invitation_v1()
  from public, anon, authenticated;
revoke all on function private.cleanup_activity_from_shared_memory_invitation_v1()
  from public, anon, authenticated;
revoke all on function private.activity_from_cafe_list_invitation_v1()
  from public, anon, authenticated;
revoke all on function private.cleanup_activity_from_cafe_list_invitation_v1()
  from public, anon, authenticated;
revoke all on function private.activity_from_like_v1()
  from public, anon, authenticated;
revoke all on function private.cleanup_activity_from_like_v1()
  from public, anon, authenticated;
revoke all on function private.activity_from_comment_v1()
  from public, anon, authenticated;
revoke all on function private.suppress_activity_from_comment_v1()
  from public, anon, authenticated;
revoke all on function private.activity_from_comment_mention_v1()
  from public, anon, authenticated;
revoke all on function private.cleanup_activity_from_comment_mention_v1()
  from public, anon, authenticated;
revoke all on function private.activity_from_reaction_v1()
  from public, anon, authenticated;
revoke all on function private.cleanup_activity_from_reaction_v1()
  from public, anon, authenticated;
revoke all on function private.activity_from_friend_request_v1()
  from public, anon, authenticated;

drop trigger if exists activity_from_visit on public.visits;
create trigger activity_from_visit
after insert or update of upload_state, visibility on public.visits
for each row execute function private.activity_from_visit_v1();

drop trigger if exists activity_from_tag on public.visit_companions;
create trigger activity_from_tag
after insert or update of created_at, added_by on public.visit_companions
for each row execute function private.activity_from_tag_v1();
drop trigger if exists cleanup_activity_from_tag on public.visit_companions;
create trigger cleanup_activity_from_tag
after delete on public.visit_companions
for each row execute function private.cleanup_activity_from_tag_v1();

drop trigger if exists activity_from_shared_memory_invitation on public.shared_memory_members;
create trigger activity_from_shared_memory_invitation
after insert or update of status, invited_by, created_at
on public.shared_memory_members
for each row execute function private.activity_from_shared_memory_invitation_v1();
drop trigger if exists cleanup_activity_from_shared_memory_invitation on public.shared_memory_members;
create trigger cleanup_activity_from_shared_memory_invitation
after update of status on public.shared_memory_members
for each row execute function private.cleanup_activity_from_shared_memory_invitation_v1();
drop trigger if exists cleanup_deleted_activity_from_shared_memory_invitation on public.shared_memory_members;
create trigger cleanup_deleted_activity_from_shared_memory_invitation
after delete on public.shared_memory_members
for each row execute function private.cleanup_activity_from_shared_memory_invitation_v1();

drop trigger if exists activity_from_cafe_list_invitation on public.cafe_list_members;
create trigger activity_from_cafe_list_invitation
after insert or update of invitation_status, invited_by, created_at
on public.cafe_list_members
for each row execute function private.activity_from_cafe_list_invitation_v1();
drop trigger if exists cleanup_activity_from_cafe_list_invitation on public.cafe_list_members;
create trigger cleanup_activity_from_cafe_list_invitation
after delete on public.cafe_list_members
for each row execute function private.cleanup_activity_from_cafe_list_invitation_v1();
drop trigger if exists cleanup_activity_from_cafe_list_invitation_status on public.cafe_list_members;
create trigger cleanup_activity_from_cafe_list_invitation_status
after update of invitation_status on public.cafe_list_members
for each row execute function private.cleanup_activity_from_cafe_list_invitation_v1();

drop trigger if exists activity_from_like on public.likes;
create trigger activity_from_like
after insert on public.likes
for each row execute function private.activity_from_like_v1();
drop trigger if exists cleanup_activity_from_like on public.likes;
create trigger cleanup_activity_from_like
after delete on public.likes
for each row execute function private.cleanup_activity_from_like_v1();

drop trigger if exists activity_from_comment on public.comments;
create trigger activity_from_comment
after insert on public.comments
for each row execute function private.activity_from_comment_v1();
drop trigger if exists suppress_activity_from_comment on public.comments;
create trigger suppress_activity_from_comment
after update of removed_at on public.comments
for each row execute function private.suppress_activity_from_comment_v1();

drop trigger if exists activity_from_comment_mention on public.comment_mentions;
create trigger activity_from_comment_mention
after insert on public.comment_mentions
for each row execute function private.activity_from_comment_mention_v1();
drop trigger if exists cleanup_activity_from_comment_mention on public.comment_mentions;
create trigger cleanup_activity_from_comment_mention
after delete on public.comment_mentions
for each row execute function private.cleanup_activity_from_comment_mention_v1();

drop trigger if exists activity_from_reaction on public.visit_reactions;
create trigger activity_from_reaction
after insert on public.visit_reactions
for each row execute function private.activity_from_reaction_v1();
drop trigger if exists cleanup_activity_from_reaction on public.visit_reactions;
create trigger cleanup_activity_from_reaction
after delete on public.visit_reactions
for each row execute function private.cleanup_activity_from_reaction_v1();

drop trigger if exists activity_from_friend_request on public.friend_requests;
create trigger activity_from_friend_request
after insert or update of status on public.friend_requests
for each row execute function private.activity_from_friend_request_v1();

-- ---------------------------------------------------------------------------
-- Blocking, visibility, and moderation suppression are enforced both when an
-- event is read/claimed and proactively when the authoritative state changes.
-- ---------------------------------------------------------------------------

create or replace function private.cleanup_blocked_pair_activity_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_events event
  where (event.recipient_id = new.blocker_id and event.actor_user_id = new.blocked_id)
     or (event.recipient_id = new.blocked_id and event.actor_user_id = new.blocker_id);

  -- Preserve all unrelated legacy rows while honoring the approved pairwise
  -- block consequence for notifications created before this migration.
  delete from public.notifications notification
  where (notification.user_id = new.blocker_id
         and notification.actor_user_id = new.blocked_id)
     or (notification.user_id = new.blocked_id
         and notification.actor_user_id = new.blocker_id);
  return new;
end;
$$;

create or replace function private.suppress_moderated_activity_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.revoked_at is not null
     or new.starts_at > now()
     or (new.ends_at is not null and new.ends_at <= now()) then
    return new;
  end if;

  if new.subject_kind = 'user'
     and new.action_kind in ('social_restricted', 'account_suspended') then
    update public.activity_events event
    set suppressed_at = coalesce(event.suppressed_at, now())
    where event.actor_user_id = new.subject_id;
  elsif new.subject_kind = 'visit' and new.action_kind = 'content_hidden' then
    update public.activity_events event
    set suppressed_at = coalesce(event.suppressed_at, now())
    where event.visit_id = new.subject_id;
  elsif new.subject_kind = 'comment' and new.action_kind = 'content_hidden' then
    update public.activity_events event
    set suppressed_at = coalesce(event.suppressed_at, now())
    where event.comment_id = new.subject_id;
  end if;
  return new;
end;
$$;

create or replace function private.suppress_invisible_visit_activity_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.upload_state is distinct from old.upload_state
     or new.visibility is distinct from old.visibility then
    update public.activity_events event
    set suppressed_at = coalesce(event.suppressed_at, now())
    where event.visit_id = new.id
      and event.kind <> 'tag'
      and not private.activity_event_is_visible(event, event.recipient_id);
  end if;
  return new;
end;
$$;

revoke all on function private.cleanup_blocked_pair_activity_v1()
  from public, anon, authenticated;
revoke all on function private.suppress_moderated_activity_v1()
  from public, anon, authenticated;
revoke all on function private.suppress_invisible_visit_activity_v1()
  from public, anon, authenticated;

drop trigger if exists cleanup_blocked_pair_activity on public.user_blocks;
create trigger cleanup_blocked_pair_activity
after insert on public.user_blocks
for each row execute function private.cleanup_blocked_pair_activity_v1();

drop trigger if exists suppress_moderated_activity on private.moderation_actions;
create trigger suppress_moderated_activity
after insert or update of revoked_at, starts_at, ends_at, action_kind
on private.moderation_actions
for each row execute function private.suppress_moderated_activity_v1();

drop trigger if exists suppress_invisible_visit_activity on public.visits;
create trigger suppress_invisible_visit_activity
after update of upload_state, visibility on public.visits
for each row execute function private.suppress_invisible_visit_activity_v1();

-- ---------------------------------------------------------------------------
-- Push queue. Database triggers only create local queue rows. A separately
-- authenticated Edge worker claims and completes them; APNs credentials never
-- enter SQL, client responses, or database webhook definitions.
-- ---------------------------------------------------------------------------

create or replace function private.enqueue_activity_push_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.suppressed_at is not null
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
  on conflict (activity_event_id, device_record_id) do nothing;
  return new;
end;
$$;

revoke all on function private.enqueue_activity_push_v1()
  from public, anon, authenticated;

drop trigger if exists enqueue_activity_push on public.activity_events;
create trigger enqueue_activity_push
after insert on public.activity_events
for each row execute function private.enqueue_activity_push_v1();

create or replace function public.claim_activity_push_batch_v1(p_limit integer default 25)
returns table (
  delivery_id uuid,
  activity_event_id uuid,
  device_record_id uuid,
  push_token text,
  environment text,
  title text,
  body text,
  deep_link text,
  attempt_count integer
)
language plpgsql
security definer
set search_path = ''
as $$
begin
  update private.activity_push_deliveries delivery
  set status = 'pending', claimed_at = null, updated_at = now()
  where delivery.status = 'processing'
    and delivery.claimed_at < now() - interval '10 minutes';

  update private.activity_push_deliveries delivery
  set status = 'cancelled', completed_at = now(), updated_at = now(),
      last_error_code = 'no_longer_deliverable'
  from public.activity_events event, public.user_devices device
  where delivery.activity_event_id = event.id
    and delivery.device_record_id = device.id
    and delivery.status = 'pending'
    and (
      device.disabled_at is not null
      or not private.activity_event_is_visible(event, event.recipient_id)
      or not private.activity_kind_push_enabled(event.recipient_id, event.kind)
    );

  return query
  with claimed as (
    select delivery.id
    from private.activity_push_deliveries delivery
    where delivery.status = 'pending' and delivery.available_at <= now()
    order by delivery.created_at, delivery.id
    for update skip locked
    limit least(greatest(coalesce(p_limit, 25), 1), 100)
  ), updated as (
    update private.activity_push_deliveries delivery
    set status = 'processing', claimed_at = now(),
        attempt_count = delivery.attempt_count + 1, updated_at = now()
    where delivery.id in (select claimed.id from claimed)
    returning delivery.*
  )
  select
    updated.id,
    event.id,
    device.id,
    device.push_token,
    device.environment,
    event.title,
    event.body,
    event.deep_link,
    updated.attempt_count
  from updated
  join public.activity_events event on event.id = updated.activity_event_id
  join public.user_devices device on device.id = updated.device_record_id
  order by updated.created_at, updated.id;
end;
$$;

create or replace function public.complete_activity_push_delivery_v1(
  p_delivery_id uuid,
  p_succeeded boolean,
  p_error_code text default null,
  p_disable_device boolean default false
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_device uuid;
begin
  update private.activity_push_deliveries delivery
  set
    status = case
      when p_succeeded then 'sent'
      when delivery.attempt_count >= 3 then 'failed'
      else 'pending'
    end,
    available_at = case
      when p_succeeded or delivery.attempt_count >= 3 then delivery.available_at
      else now() + make_interval(secs => least(60 * delivery.attempt_count, 300))
    end,
    completed_at = case
      when p_succeeded or delivery.attempt_count >= 3 then now()
      else null
    end,
    claimed_at = null,
    last_error_code = left(nullif(btrim(p_error_code), ''), 80),
    updated_at = now()
  where delivery.id = p_delivery_id and delivery.status = 'processing'
  returning delivery.device_record_id into target_device;

  if target_device is null then return false; end if;

  if p_succeeded then
    update public.user_devices device
    set failure_count = 0, last_failure_at = null, updated_at = now()
    where device.id = target_device;
  else
    update public.user_devices device
    set failure_count = device.failure_count + 1,
        last_failure_at = now(),
        disabled_at = case when p_disable_device then now() else device.disabled_at end,
        updated_at = now()
    where device.id = target_device;
  end if;
  return true;
end;
$$;

revoke all on function public.claim_activity_push_batch_v1(integer)
  from public, anon, authenticated;
revoke all on function public.complete_activity_push_delivery_v1(uuid,boolean,text,boolean)
  from public, anon, authenticated;
grant execute on function public.claim_activity_push_batch_v1(integer)
  to service_role;
grant execute on function public.complete_activity_push_delivery_v1(uuid,boolean,text,boolean)
  to service_role;

-- ---------------------------------------------------------------------------
-- Caller-bound activity and preference APIs.
-- ---------------------------------------------------------------------------

create or replace function public.get_notification_preferences_v1()
returns public.notification_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result public.notification_preferences;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  insert into public.notification_preferences (user_id)
  values (actor)
  on conflict (user_id) do nothing;
  select * into result from public.notification_preferences where user_id = actor;
  return result;
end;
$$;

create or replace function public.set_notification_preferences_v1(
  p_push_enabled boolean,
  p_friend_posts boolean,
  p_tags boolean,
  p_shared_mugshot_invitations boolean,
  p_collaborative_list_invitations boolean,
  p_likes boolean,
  p_comments boolean,
  p_reactions boolean,
  p_friend_requests boolean
)
returns public.notification_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result public.notification_preferences;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  insert into public.notification_preferences (
    user_id, push_enabled, friend_posts, tags,
    shared_mugshot_invitations, collaborative_list_invitations,
    likes, comments, reactions, friend_requests
  ) values (
    actor, p_push_enabled, p_friend_posts, p_tags,
    p_shared_mugshot_invitations, p_collaborative_list_invitations,
    p_likes, p_comments, p_reactions, p_friend_requests
  )
  on conflict (user_id) do update set
    push_enabled = excluded.push_enabled,
    friend_posts = excluded.friend_posts,
    tags = excluded.tags,
    shared_mugshot_invitations = excluded.shared_mugshot_invitations,
    collaborative_list_invitations = excluded.collaborative_list_invitations,
    likes = excluded.likes,
    comments = excluded.comments,
    reactions = excluded.reactions,
    friend_requests = excluded.friend_requests,
    updated_at = now()
  returning * into result;

  update private.activity_push_deliveries delivery
  set status = 'cancelled', completed_at = now(), updated_at = now(),
      last_error_code = 'preference_disabled'
  from public.activity_events event
  where delivery.activity_event_id = event.id
    and event.recipient_id = actor
    and delivery.status = 'pending'
    and not private.activity_kind_push_enabled(actor, event.kind);
  return result;
end;
$$;

create or replace function public.list_activity_events_v1(
  p_limit integer default 30,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
)
returns table (
  event_id uuid,
  kind text,
  actor_user_id uuid,
  actor_display_name text,
  actor_username text,
  actor_avatar_url text,
  title text,
  body text,
  visit_id uuid,
  comment_id uuid,
  shared_memory_id uuid,
  cafe_list_id uuid,
  friend_request_id uuid,
  deep_link text,
  can_open_visit boolean,
  can_remove_tag boolean,
  created_at timestamptz,
  read_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor), visible as (
    select
      event.*,
      private.can_view_visit_as(event.visit_id, input.actor) can_open,
      event.kind = 'tag' and exists (
        select 1 from public.visit_companions tag
        where tag.visit_id = event.visit_id
          and tag.companion_user_id = input.actor
          and tag.added_by = event.actor_user_id
      ) can_remove
    from input
    join public.activity_events event on event.recipient_id = input.actor
    where input.actor is not null
      and private.activity_event_is_visible(event, input.actor)
      and (
        p_before_created_at is null
        or event.created_at < p_before_created_at
        or (
          event.created_at = p_before_created_at
          and (p_before_id is null or event.id < p_before_id)
        )
      )
    order by event.created_at desc, event.id desc
    limit least(greatest(coalesce(p_limit, 30), 1), 50)
  )
  select
    visible.id,
    visible.kind,
    actor.id,
    actor.display_name,
    actor.username,
    actor.avatar_url,
    visible.title,
    case
      when visible.kind = 'tag' and not visible.can_open then
        left(coalesce(nullif(btrim(actor.display_name), ''), '@' || actor.username)
          || ' tagged you in a MugShot you can''t view.', 280)
      else visible.body
    end,
    visible.visit_id,
    visible.comment_id,
    visible.shared_memory_id,
    visible.cafe_list_id,
    visible.friend_request_id,
    case
      when visible.kind = 'tag' and not visible.can_open then 'mugshot://activity'
      else visible.deep_link
    end,
    visible.can_open,
    visible.can_remove,
    visible.created_at,
    visible.read_at
  from visible
  join public.users actor on actor.id = visible.actor_user_id
  order by visible.created_at desc, visible.id desc;
$$;

create or replace function public.activity_unread_count_v1()
returns integer
language sql
stable
security definer
set search_path = ''
as $$
  select count(*)::integer
  from public.activity_events event
  where event.recipient_id = auth.uid()
    and event.read_at is null
    and private.activity_event_is_visible(event, auth.uid());
$$;

create or replace function public.mark_activity_read_v1(p_event_id uuid default null)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  updated_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  update public.activity_events event
  set read_at = coalesce(event.read_at, now())
  where event.recipient_id = actor
    and event.read_at is null
    and (p_event_id is null or event.id = p_event_id)
    and private.activity_event_is_visible(event, actor);
  get diagnostics updated_count = row_count;
  return updated_count;
end;
$$;

revoke all on function public.get_notification_preferences_v1()
  from public, anon, authenticated;
revoke all on function public.set_notification_preferences_v1(
  boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean
) from public, anon, authenticated;
revoke all on function public.list_activity_events_v1(integer,timestamptz,uuid)
  from public, anon, authenticated;
revoke all on function public.activity_unread_count_v1()
  from public, anon, authenticated;
revoke all on function public.mark_activity_read_v1(uuid)
  from public, anon, authenticated;

grant execute on function public.get_notification_preferences_v1()
  to authenticated;
grant execute on function public.set_notification_preferences_v1(
  boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean
) to authenticated;
grant execute on function public.list_activity_events_v1(integer,timestamptz,uuid)
  to authenticated;
grant execute on function public.activity_unread_count_v1()
  to authenticated;
grant execute on function public.mark_activity_read_v1(uuid)
  to authenticated;

create or replace function public.build_owner_activity_export_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select jsonb_build_object(
    'notification_preferences', coalesce((
      select jsonb_build_object(
        'push_enabled', preference.push_enabled,
        'friend_posts', preference.friend_posts,
        'tags', preference.tags,
        'shared_mugshot_invitations', preference.shared_mugshot_invitations,
        'collaborative_list_invitations', preference.collaborative_list_invitations,
        'likes', preference.likes,
        'comments', preference.comments,
        'reactions', preference.reactions,
        'friend_requests', preference.friend_requests,
        'updated_at', preference.updated_at
      )
      from public.notification_preferences preference
      where preference.user_id = actor
    ), jsonb_build_object(
      'push_enabled', true,
      'friend_posts', true,
      'tags', true,
      'shared_mugshot_invitations', true,
      'collaborative_list_invitations', true,
      'likes', true,
      'comments', true,
      'reactions', true,
      'friend_requests', true
    )),
    'activity_events', coalesce((
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'event_id', event.id,
        'kind', event.kind,
        'actor_user_id', event.actor_user_id,
        'title', event.title,
        'body', case
          when event.kind = 'tag'
               and not private.can_view_visit_as(event.visit_id, actor) then
            left(coalesce(nullif(btrim(profile.display_name), ''), '@' || profile.username)
              || ' tagged you in a MugShot you can''t view.', 280)
          else event.body
        end,
        'visit_id', case
          when event.kind = 'tag'
               and not private.can_view_visit_as(event.visit_id, actor) then null
          else event.visit_id
        end,
        'comment_id', event.comment_id,
        'shared_memory_id', event.shared_memory_id,
        'cafe_list_id', event.cafe_list_id,
        'friend_request_id', event.friend_request_id,
        'deep_link', case
          when event.kind = 'tag'
               and not private.can_view_visit_as(event.visit_id, actor)
            then 'mugshot://activity'
          else event.deep_link
        end,
        'created_at', event.created_at,
        'read_at', event.read_at
      )) order by event.created_at, event.id)
      from public.activity_events event
      join public.users profile on profile.id = event.actor_user_id
      where event.recipient_id = actor
        and private.activity_event_is_visible(event, actor)
    ), '[]'::jsonb),
    'registered_device_summary', jsonb_build_object(
      'registered_count', (
        select count(*) from public.user_devices device
        where device.user_id = actor and device.device_id is not null
      ),
      'active_count', (
        select count(*) from public.user_devices device
        where device.user_id = actor
          and device.device_id is not null and device.disabled_at is null
      ),
      'platform_environments', coalesce((
        select jsonb_agg(jsonb_build_object(
          'platform', grouped.platform,
          'environment', grouped.environment,
          'count', grouped.device_count
        ) order by grouped.platform, grouped.environment)
        from (
          select device.platform, device.environment, count(*) device_count
          from public.user_devices device
          where device.user_id = actor and device.device_id is not null
          group by device.platform, device.environment
        ) grouped
      ), '[]'::jsonb)
    )
  ) into result;

  return result;
end;
$$;

revoke all on function public.build_owner_activity_export_v1()
  from public, anon, authenticated;
grant execute on function public.build_owner_activity_export_v1()
  to authenticated;

comment on table public.activity_events is
  'Durable caller-projected in-app activity. Direct client reads are prohibited.';
comment on table public.notification_preferences is
  'Push category preferences. Friend-post delivery defaults on for the alpha experiment; in-app activity remains durable.';
comment on function public.register_user_device_v2(uuid,text,text) is
  'Caller-bound APNs token registration. The raw token is never returned or client-readable.';
comment on function public.list_activity_events_v1(integer,timestamptz,uuid) is
  'Visibility, blocking, moderation, and tag-audience-safe activity projection.';
comment on function public.build_owner_activity_export_v1() is
  'Caller-sealed activity export. Device tokens, device identifiers, and private delivery state are excluded.';

commit;
