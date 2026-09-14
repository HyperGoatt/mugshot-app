-- Candidate checks preserve existing audience, relationship and enforcement rules
-- while allowing a durable notification to wait for screening. They are never
-- used by public readers or the actual push eligibility check.


create or replace function private.activity_candidate_user_v1(p_user_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_viewer)
    and private.is_live_account_as(p_user_id)
    and not private.blocked_between(p_viewer, p_user_id)
    and (
      p_user_id = p_viewer
      or not private.has_active_moderation_action(
        'user', p_user_id, array['account_suspended']::text[]
      )
    );
$$;

create or replace function private.activity_candidate_visit_v1(p_visit_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_viewer) and exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and (visit.upload_state = 'complete' or visit.user_id = p_viewer)
      and private.activity_candidate_user_v1(visit.user_id, p_viewer)
      and (
        visit.user_id = p_viewer
        or not private.has_active_moderation_action(
          'visit', visit.id, array['content_hidden']::text[]
        )
      )
      and (
        visit.user_id = p_viewer
        or visit.visibility = 'everyone'
        or (
          visit.visibility = 'friends'
          and private.confirmed_friends(p_viewer, visit.user_id)
        )
      )
  );
$$;

create or replace function private.activity_candidate_comment_v1(p_comment_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_viewer) and exists (
    select 1
    from public.comments comment
    where comment.id = p_comment_id
      and comment.removed_at is null
      and not private.has_active_moderation_action(
        'comment', comment.id, array['content_hidden']::text[]
      )
      and private.activity_candidate_visit_v1(comment.visit_id, p_viewer)
      and private.activity_candidate_user_v1(comment.user_id, p_viewer)
  );
$$;

create or replace function private.activity_candidate_event_v1(
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
    and private.activity_candidate_user_v1(p_event.actor_user_id, p_viewer)
    and case p_event.kind
      when 'friend_post' then
        p_event.visit_id is not null
        and private.activity_candidate_visit_v1(p_event.visit_id, p_viewer)
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
      when 'collaborative_list_invitation_accepted' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_invitation_declined' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_invitation_cancelled' then
        p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
        and (
          p_event.cafe_list_id is not null
          or (
            p_event.cafe_list_id is null
            and p_event.metadata ->> 'reason' = 'list_deleted'
            and p_event.metadata ->> 'list_id' is not null
          )
        )
      when 'collaborative_list_role_changed' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_member_removed' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_member_left' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_ownership_transferred' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_deleted' then
        p_event.cafe_list_id is null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'like' then
        p_event.visit_id is not null
        and private.activity_candidate_visit_v1(p_event.visit_id, p_viewer)
      when 'comment' then
        p_event.comment_id is not null
        and private.activity_candidate_comment_v1(p_event.comment_id, p_viewer)
      when 'comment_mention' then
        p_event.comment_id is not null
        and private.activity_candidate_comment_v1(p_event.comment_id, p_viewer)
        and exists (
          select 1 from public.comment_mentions mention
          where mention.comment_id = p_event.comment_id
            and mention.mentioned_user_id = p_viewer
        )
      when 'reaction' then
        p_event.visit_id is not null
        and private.activity_candidate_visit_v1(p_event.visit_id, p_viewer)
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

revoke all on function private.activity_candidate_user_v1(uuid,uuid),private.activity_candidate_visit_v1(uuid,uuid),private.activity_candidate_comment_v1(uuid,uuid),private.activity_candidate_event_v1(public.activity_events,uuid) from public,anon,authenticated;

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
    and (p_event.visit_id is null or private.screening_approved_v1('visit',p_event.visit_id))
    and (p_event.comment_id is null or private.screening_approved_v1('comment',p_event.comment_id))
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
      when 'collaborative_list_invitation_accepted' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_invitation_declined' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_invitation_cancelled' then
        p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
        and (
          p_event.cafe_list_id is not null
          or (
            p_event.cafe_list_id is null
            and p_event.metadata ->> 'reason' = 'list_deleted'
            and p_event.metadata ->> 'list_id' is not null
          )
        )
      when 'collaborative_list_role_changed' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_member_removed' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_member_left' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_ownership_transferred' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_deleted' then
        p_event.cafe_list_id is null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
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
     or not private.activity_candidate_user_v1(p_actor, p_recipient) then
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
         or not private.activity_candidate_visit_v1(p_visit_id, p_recipient) then
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
      if private.activity_candidate_visit_v1(p_visit_id, p_recipient) then
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
         or not private.activity_candidate_visit_v1(p_visit_id, p_recipient) then return null; end if;
      resolved_title := left(actor_label || ' liked your MugShot', 120);
      resolved_body := 'Your sip got a little love.';
      resolved_deep_link := 'mugshot://activity/visit/' || p_visit_id::text;
    when 'comment' then
      if p_visit_id is null or p_comment_id is null
         or not private.activity_candidate_comment_v1(p_comment_id, p_recipient) then return null; end if;
      resolved_title := left(actor_label || ' joined the conversation', 120);
      resolved_body := 'There is a new comment on a MugShot you can see.';
      resolved_deep_link := 'mugshot://activity/visit/' || p_visit_id::text;
    when 'comment_mention' then
      if p_visit_id is null or p_comment_id is null
         or not private.activity_candidate_comment_v1(p_comment_id, p_recipient)
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
         or not private.activity_candidate_visit_v1(p_visit_id, p_recipient) then return null; end if;
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
    'Mugshot activity', 'Open Mugshot to see what changed.', p_visit_id, p_comment_id,
    p_shared_memory_id, p_cafe_list_id, p_friend_request_id,
    resolved_deep_link, (coalesce(p_metadata, '{}'::jsonb) - 'list_title')
  )
  on conflict (recipient_id, dedupe_key) do nothing
  returning id into event_id;

  return event_id;
end;
$$;

create or replace function private.create_cafe_list_lifecycle_activity_v1(
  p_recipient uuid,
  p_actor uuid,
  p_kind text,
  p_dedupe_key text,
  p_title text,
  p_body text,
  p_cafe_list_id uuid,
  p_deep_link text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_id uuid;
begin
  if p_kind not in (
    'collaborative_list_invitation_accepted',
    'collaborative_list_invitation_declined',
    'collaborative_list_invitation_cancelled',
    'collaborative_list_role_changed',
    'collaborative_list_member_removed',
    'collaborative_list_member_left',
    'collaborative_list_ownership_transferred',
    'collaborative_list_deleted'
  ) or p_recipient is null or p_actor is null or p_recipient = p_actor
     or not private.activity_recipient_is_eligible_v2(p_recipient)
     or not private.can_socially_mutate_as(p_actor)
     or not private.activity_candidate_user_v1(p_actor, p_recipient)
     or p_deep_link not in ('mugshot://activity', 'mugshot://activity/lists') then
    return null;
  end if;

  insert into public.activity_events (
    recipient_id, actor_user_id, kind, dedupe_key, title, body,
    cafe_list_id, deep_link, metadata
  ) values (
    p_recipient, p_actor, p_kind, left(p_dedupe_key, 240),
    'Cafe list activity', 'Open Mugshot to see what changed.',
    p_cafe_list_id, p_deep_link,
    (coalesce(p_metadata, '{}'::jsonb) - 'list_title') || jsonb_build_object(
      'source', 'cafe_list_lifecycle'
    )
  )
  on conflict (recipient_id, dedupe_key) do nothing
  returning id into event_id;

  return event_id;
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
      and not private.activity_candidate_event_v1(event, event.recipient_id);
  end if;
  return new;
end;
$$;

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
      or (not private.activity_event_is_visible(event, event.recipient_id)
        and (not private.activity_candidate_event_v1(event,event.recipient_id)
          or event.created_at < now()-interval '24 hours'))
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

  -- A content edit may begin screening after this worker claimed delivery.
  -- Release this lease without sending; approval can make it eligible again.
  if device_disabled_at is null and not suspension_imminent
     and private.activity_recipient_is_eligible_v2(event_row.recipient_id)
     and private.activity_kind_push_enabled(event_row.recipient_id,event_row.kind)
     and private.activity_candidate_event_v1(event_row,event_row.recipient_id)
     and event_row.created_at >= now()-interval '24 hours' then
    update private.activity_push_deliveries set status='pending',claimed_at=null,
      claim_token=null,available_at=now()+interval '1 minute',updated_at=now(),
      attempt_count=greatest(attempt_count-1,0),last_error_code='awaiting_screening'
      where id=p_delivery_id and claim_token=p_claim_token and lease_version=p_lease_version;
    return false;
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

-- Generated notification copy is not a durable store for names or deleted list
-- titles. Preserve event identity, receipts, read state and delivery history.
update public.activity_events set title='Mugshot activity',
  body='Open Mugshot to see what changed.',metadata=metadata-'list_title'
where title is distinct from 'Mugshot activity'
   or body is distinct from 'Open Mugshot to see what changed.' or metadata ? 'list_title';
