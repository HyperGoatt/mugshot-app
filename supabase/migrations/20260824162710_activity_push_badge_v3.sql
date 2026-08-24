begin;

-- Badge synchronization is opt-in per installation. Rows created by the v2
-- registration contract remain false so older TestFlight builds continue to
-- receive the existing payload without an app-icon badge.
alter table public.user_devices
  add column if not exists supports_badge_sync boolean not null default false;

alter table public.user_devices enable row level security;
revoke all on table public.user_devices from public, anon, authenticated;

-- Badge-aware registration.
create or replace function public.register_user_device_v3(
  p_device_id uuid,
  p_push_token text,
  p_environment text,
  p_supports_badge_sync boolean
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  registration jsonb;
  updated_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_supports_badge_sync is null then
    raise exception 'badge capability required' using errcode = '22023';
  end if;

  -- v2 remains the single source for validation, account eligibility, token
  -- ownership, churn limits, and the active-device cap.
  registration := public.register_user_device_v2(
    p_device_id,
    p_push_token,
    p_environment
  );

  update public.user_devices device
  set
    supports_badge_sync = p_supports_badge_sync,
    updated_at = now()
  where device.user_id = actor
    and device.device_id = p_device_id;
  get diagnostics updated_count = row_count;

  if updated_count <> 1 then
    raise exception 'device registration unavailable' using errcode = 'P0001';
  end if;

  return registration || jsonb_build_object(
    'supports_badge_sync', p_supports_badge_sync
  );
end;
$$;

revoke all on function public.register_user_device_v3(uuid,text,text,boolean)
  from public, anon, authenticated, service_role;
grant execute on function public.register_user_device_v3(uuid,text,text,boolean)
  to authenticated;

comment on function public.register_user_device_v3(uuid,text,text,boolean) is
  'Caller-bound APNs registration that preserves all v2 protections and records whether this installation accepts authoritative unread-count badges.';

-- Badge-aware final revalidation.
create or replace function public.revalidate_activity_push_delivery_v3(
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
  is_eligible boolean;
  recipient uuid;
  badge_capable boolean := false;
  unread_count integer := 0;
begin
  -- v2 performs the fenced lease check and the final visibility, moderation,
  -- preference, account, and device checks. It also cancels a delivery that
  -- became ineligible. Keeping that behavior in one function prevents drift.
  is_eligible := public.revalidate_activity_push_delivery_v2(
    p_delivery_id,
    p_claim_token,
    p_lease_version
  );

  if not coalesce(is_eligible, false) then
    return jsonb_build_object(
      'eligible', false,
      'unread_count', 0,
      'supports_badge_sync', false
    );
  end if;

  select
    event.recipient_id,
    device.supports_badge_sync
  into recipient, badge_capable
  from private.activity_push_deliveries delivery
  join public.activity_events event
    on event.id = delivery.activity_event_id
  join public.user_devices device
    on device.id = delivery.device_record_id
  where delivery.id = p_delivery_id
    and delivery.status = 'processing'
    and delivery.claim_token = p_claim_token
    and delivery.lease_version = p_lease_version;

  if not found then
    return jsonb_build_object(
      'eligible', false,
      'unread_count', 0,
      'supports_badge_sync', false
    );
  end if;

  select count(*)::integer into unread_count
  from public.activity_events event
  where event.recipient_id = recipient
    and event.read_at is null
    and private.activity_event_is_visible(event, recipient);

  return jsonb_build_object(
    'eligible', true,
    'unread_count', unread_count,
    'supports_badge_sync', coalesce(badge_capable, false)
  );
end;
$$;

revoke all on function public.revalidate_activity_push_delivery_v3(
  uuid,uuid,bigint
) from public, anon, authenticated, service_role;
grant execute on function public.revalidate_activity_push_delivery_v3(
  uuid,uuid,bigint
) to service_role;

comment on function public.revalidate_activity_push_delivery_v3(
  uuid,uuid,bigint
) is
  'Service-only fenced final delivery check returning eligibility, authoritative visible unread count, and the installation badge capability immediately before APNs.';

-- Backend capability contract.
create or replace function public.get_backend_capabilities_v1()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'contract_version', 1,
    'schema_release', '2026-08-24-activity-push-badge-v3',
    'capabilities', jsonb_build_object(
      'taste_passport',
        to_regprocedure('public.get_taste_passport_v1(uuid)') is not null,
      'taste_passport_audience',
        to_regprocedure('public.get_taste_passport_visibility_v1()') is not null
        and to_regprocedure('public.set_taste_passport_visibility_v1(text,uuid)') is not null,
      'independent_recipe_visibility',
        to_regprocedure('public.get_recipe_projection_for_visit_v1(uuid)') is not null
        and to_regprocedure('public.get_recipe_identity_for_visit_v1(uuid)') is not null,
      'visit_tags', true,
      'shared_mugshots', false,
      'public_mugshot_sharing',
        to_regprocedure('public.create_visit_share_link_v1(uuid)') is not null
        and to_regprocedure('public.get_public_mugshot_share_v1(text)') is not null,
      'activity_center',
        to_regprocedure(
          'public.list_activity_events_v1(integer,timestamp with time zone,uuid)'
        ) is not null
        and to_regprocedure('public.activity_unread_count_v1()') is not null,
      'notification_preferences',
        to_regprocedure('public.get_notification_preferences_v1()') is not null,
      'push_registration',
        to_regprocedure('public.register_user_device_v2(uuid,text,text)') is not null,
      'push_badge_sync',
        to_regprocedure(
          'public.register_user_device_v3(uuid,text,text,boolean)'
        ) is not null
        and to_regprocedure(
          'public.revalidate_activity_push_delivery_v3(uuid,uuid,bigint)'
        ) is not null,
      'social_safety',
        to_regprocedure(
          'public.submit_report_v2(uuid,public.report_reason,text,uuid,text)'
        ) is not null
        and to_regprocedure('public.block_user_v2(uuid,boolean)') is not null,
      'moderation_transparency',
        to_regprocedure('public.get_my_enforcement_state_v1()') is not null,
      'collaborative_cafe_lists',
        to_regprocedure('public.list_cafe_lists_v2()') is not null
        and to_regprocedure('public.get_cafe_list_v2(uuid)') is not null,
      'account_deletion_v3',
        to_regprocedure(
          'public.begin_account_deletion_step_up_v3(uuid,uuid,uuid,text,text)'
        ) is not null
        and to_regprocedure(
          'public.prepare_account_deletion_v3(uuid,uuid,uuid,text,text,uuid,text)'
        ) is not null
    )
  );
$$;

revoke all on function public.get_backend_capabilities_v1() from public;
grant execute on function public.get_backend_capabilities_v1()
  to anon, authenticated;

commit;
