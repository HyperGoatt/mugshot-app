\set ON_ERROR_STOP on

begin;

create temp table activity_hardening_users as
select id, row_number() over (order by id) n
from (
  select profile.id
  from public.users profile
  where private.is_live_account_as(profile.id)
    and not private.has_active_moderation_action(
      'user', profile.id, array['account_suspended']::text[]
    )
  order by profile.id
  limit 2
) available;

create temp table activity_hardening_state (
  key text primary key,
  id uuid not null
);
grant select on activity_hardening_users to authenticated;
grant select on activity_hardening_state to authenticated;

do $$
begin
  if (select count(*) from activity_hardening_users) < 2 then
    raise exception 'activity hardening suite requires two live fixture users';
  end if;
  if not exists (select 1 from public.cafes) then
    raise exception 'activity hardening suite requires one fixture cafe';
  end if;
end;
$$;

-- Token casing is normalized and a later serialized registration becomes the
-- sole owner inside the sandbox APNs namespace.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from activity_hardening_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.register_user_device_v2(
  'a2210000-0000-4000-8000-000000000001', repeat('AB', 32), 'sandbox'
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from activity_hardening_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);
select public.register_user_device_v2(
  'a2210000-0000-4000-8000-000000000002', repeat('ab', 32), 'sandbox'
);
reset role;

do $$
begin
  if (select count(*) from public.user_devices device
      where device.environment = 'sandbox'
        and device.push_token = repeat('ab', 32)) <> 1
     or not exists (
       select 1 from public.user_devices device
       where device.environment = 'sandbox'
         and device.push_token = repeat('ab', 32)
         and device.user_id = (select id from activity_hardening_users where n = 2)
     ) then
    raise exception 'normalized APNs token ownership is not deterministic';
  end if;
end;
$$;

-- A normal launch heartbeat does not spend the churn budget. Material token
-- rebinding is bounded even though each update keeps the active-device count
-- below the separate fanout cap.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from activity_hardening_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);
select public.register_user_device_v2(
  'a2210000-0000-4000-8000-000000000002', repeat('ab', 32), 'sandbox'
);
do $$
declare
  change_index integer;
begin
  for change_index in 1..19 loop
    perform public.register_user_device_v2(
      'a2210000-0000-4000-8000-000000000002',
      lpad(to_hex(change_index), 64, '0'),
      'sandbox'
    );
  end loop;

  begin
    perform public.register_user_device_v2(
      'a2210000-0000-4000-8000-000000000002',
      repeat('f', 64),
      'sandbox'
    );
    raise exception 'device registration churn was not bounded';
  exception when sqlstate '54000' then null;
  end;
end;
$$;
reset role;

do $$
begin
  if not exists (
    select 1
    from private.user_device_registration_windows window_row
    where window_row.user_id = (
      select id from activity_hardening_users where n = 2
    )
      and window_row.material_change_count = 20
  ) or not exists (
    select 1
    from public.user_devices device
    where device.user_id = (select id from activity_hardening_users where n = 2)
      and device.device_id = 'a2210000-0000-4000-8000-000000000002'
      and device.push_token = lpad(to_hex(19), 64, '0')
      and device.disabled_at is null
  ) then
    raise exception 'device registration heartbeat or churn accounting is incorrect';
  end if;
end;
$$;

insert into public.visits (
  user_id, cafe_id, drink_type, drink_subtype, caption,
  visibility, upload_state, overall_score, context_type
)
select
  (select id from activity_hardening_users where n = 2),
  (select id from public.cafes order by id limit 1),
  'Coffee', 'Activity lease', 'Activity hardening lease contract',
  'everyone', 'complete', 4, 'Cafe';

insert into activity_hardening_state (key, id)
select 'visit', visit.id
from public.visits visit
where visit.caption = 'Activity hardening lease contract'
  and visit.user_id = (select id from activity_hardening_users where n = 2)
order by visit.created_at desc, visit.id desc
limit 1;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from activity_hardening_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.toggle_visit_reaction(
  (select id from activity_hardening_state where key = 'visit'), 'cozy'
);
select public.toggle_visit_reaction(
  (select id from activity_hardening_state where key = 'visit'), 'dialed_in'
);
reset role;

do $$
begin
  if (select count(*) from public.activity_events event
      where event.kind = 'reaction'
        and event.visit_id = (select id from activity_hardening_state where key = 'visit')
        and event.actor_user_id = (select id from activity_hardening_users where n = 1)) <> 1
     or not exists (
       select 1 from public.activity_events event
       where event.kind = 'reaction'
         and event.visit_id = (select id from activity_hardening_state where key = 'visit')
         and event.metadata ->> 'reaction' = 'dialed_in'
     ) then
    raise exception 'reaction change did not retain one current activity event';
  end if;
end;
$$;

-- Keep unrelated fixture deliveries outside this focused lease claim. The
-- transaction rolls the scheduling change back with the rest of the suite.
update private.activity_push_deliveries delivery
set available_at = now() + interval '1 day'
from public.activity_events event
where event.id = delivery.activity_event_id
  and delivery.status = 'pending'
  and not (
    event.kind = 'reaction'
    and event.visit_id = (select id from activity_hardening_state where key = 'visit')
    and event.actor_user_id = (select id from activity_hardening_users where n = 1)
  );

create temp table first_claim as
select claim.*
from public.claim_activity_push_batch_v2(50) claim;

update private.activity_push_deliveries delivery
set claimed_at = now() - interval '3 minutes'
where delivery.id = (
  select claim.delivery_id
  from first_claim claim
  where claim.activity_event_id = (
    select event.id from public.activity_events event
    where event.kind = 'reaction'
      and event.visit_id = (select id from activity_hardening_state where key = 'visit')
  )
);

create temp table second_claim as
select claim.*
from public.claim_activity_push_batch_v2(50) claim;

do $$
declare stale first_claim;
declare current_lease second_claim;
begin
  select * into stale from first_claim claim
  where claim.activity_event_id = (
    select event.id from public.activity_events event
    where event.kind = 'reaction'
      and event.visit_id = (select id from activity_hardening_state where key = 'visit')
  );
  select * into current_lease from second_claim claim
  where claim.delivery_id = stale.delivery_id;

  if current_lease.lease_version <= stale.lease_version then
    raise exception 'reclaimed delivery did not advance its lease version';
  end if;
  if public.complete_activity_push_delivery_v2(
       stale.delivery_id, stale.claim_token, stale.lease_version,
       'unregistered', 'Unregistered', null
     ) then
    raise exception 'stale lease completed or disabled a newer delivery';
  end if;
  if not public.complete_activity_push_delivery_v2(
       current_lease.delivery_id, current_lease.claim_token,
       current_lease.lease_version, 'retryable', 'ServiceUnavailable', 900
     ) then
    raise exception 'current retryable lease was not completed';
  end if;
end;
$$;

do $$
begin
  if not exists (
    select 1
    from private.activity_push_deliveries delivery
    join public.activity_events event on event.id = delivery.activity_event_id
    where event.kind = 'reaction'
      and event.visit_id = (select id from activity_hardening_state where key = 'visit')
      and delivery.status = 'pending'
      and delivery.attempt_count = 2
      and delivery.available_at > now()
  ) or exists (
    select 1 from public.user_devices device
    where device.user_id = (select id from activity_hardening_users where n = 2)
      and device.disabled_at is not null
  ) then
    raise exception 'retry scheduling or stale-worker device fencing failed';
  end if;
end;
$$;

-- A suspension suppresses the recipient's in-app event and cancels its
-- delivery without invalidating the installation. Export access remains.
update private.activity_push_deliveries delivery
set available_at = now()
from public.activity_events event
where event.id = delivery.activity_event_id
  and event.kind = 'reaction'
  and event.visit_id = (select id from activity_hardening_state where key = 'visit');

insert into private.moderation_actions (
  subject_kind, subject_id, action_kind, reason_code
) values (
  'user', (select id from activity_hardening_users where n = 2),
  'account_suspended', 'activity_hardening_contract'
);

do $$
begin
  if exists (
    select 1 from public.activity_events event
    where event.recipient_id = (select id from activity_hardening_users where n = 2)
      and event.suppressed_at is null
  ) or exists (
    select 1
    from private.activity_push_deliveries delivery
    join public.activity_events event on event.id = delivery.activity_event_id
    where event.recipient_id = (select id from activity_hardening_users where n = 2)
      and delivery.status in ('pending', 'processing')
  ) or exists (
    select 1 from public.user_devices device
    where device.user_id = (select id from activity_hardening_users where n = 2)
      and device.disabled_at is not null
  ) then
    raise exception 'suspension did not suppress activity safely';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from activity_hardening_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);
do $$
begin
  if public.activity_unread_count_v1() <> 0
     or exists (select 1 from public.list_activity_events_v1())
     or public.build_owner_activity_export_v1() is null then
    raise exception 'suspended recipient visibility or export access is incorrect';
  end if;
end;
$$;
reset role;

rollback;

select 'alpha_activity_delivery_hardening_contract_passed' as result;
