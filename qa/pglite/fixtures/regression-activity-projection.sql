CREATE OR REPLACE FUNCTION public.list_activity_events_v1(p_limit integer DEFAULT 30, p_before_created_at timestamp with time zone DEFAULT NULL::timestamp with time zone, p_before_id uuid DEFAULT NULL::uuid)
 RETURNS TABLE(event_id uuid, kind text, actor_user_id uuid, actor_display_name text, actor_username text, actor_avatar_url text, title text, body text, visit_id uuid, comment_id uuid, shared_memory_id uuid, cafe_list_id uuid, friend_request_id uuid, deep_link text, can_open_visit boolean, can_remove_tag boolean, created_at timestamp with time zone, read_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;
CREATE OR REPLACE FUNCTION public.claim_activity_push_batch_v2(p_limit integer DEFAULT 25)
 RETURNS TABLE(delivery_id uuid, activity_event_id uuid, recipient_id uuid, device_record_id uuid, push_token text, environment text, title text, body text, deep_link text, attempt_count integer, claim_token uuid, lease_version bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
$function$;
