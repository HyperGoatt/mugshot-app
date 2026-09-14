begin;

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
    'reflection:' || occurrence.id::text,
    occurrence.expires_at
  from updated
  join private.reflection_reminder_occurrences occurrence
    on occurrence.id = updated.occurrence_id
  join public.user_devices device
    on device.id = updated.device_record_id;
end;
$$;

comment on function public.claim_reflection_reminder_batch_v1(integer) is
  'Claims fenced reflection deliveries with an APNs collapse identifier bounded below 64 bytes.';

commit;
