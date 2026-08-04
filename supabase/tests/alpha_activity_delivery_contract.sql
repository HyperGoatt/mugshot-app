\set ON_ERROR_STOP on

begin;

create temp table alpha_activity_users as
select id, username, row_number() over (order by id) n
from (
  select id, username
  from public.users available_user
  where not private.has_active_moderation_action(
    'user', available_user.id,
    array['social_restricted', 'account_suspended']::text[]
  )
  order by id
  limit 3
) users;

create temp table alpha_activity_state (
  key text primary key,
  id uuid not null
);

-- Privileged test-only projection for durable-row assertions. The production
-- table remains sealed; app behavior is exercised through its public RPCs.
create temp view alpha_activity_events_debug as
select * from public.activity_events;

grant select on alpha_activity_users to authenticated;
grant all on alpha_activity_state to authenticated;
grant select on alpha_activity_events_debug to authenticated;

do $$
begin
  if (select count(*) from alpha_activity_users) < 3 then
    raise exception 'activity suite requires three local fixture users';
  end if;
  if not exists (select 1 from public.cafes) then
    raise exception 'activity suite requires one local fixture cafe';
  end if;
end;
$$;

delete from public.user_blocks block
where block.blocker_id in (select id from alpha_activity_users)
  and block.blocked_id in (select id from alpha_activity_users);
delete from public.friend_requests request
where request.from_user_id in (select id from alpha_activity_users)
  and request.to_user_id in (select id from alpha_activity_users);
delete from public.friends friendship
where friendship.user_id in (select id from alpha_activity_users)
  and friendship.friend_user_id in (select id from alpha_activity_users);

insert into public.friends (user_id, friend_user_id)
values
  ((select id from alpha_activity_users where n = 1),
   (select id from alpha_activity_users where n = 2)),
  ((select id from alpha_activity_users where n = 2),
   (select id from alpha_activity_users where n = 1));

-- Defaults and device registration are account-bound, return no token, and
-- make a subsequent friend post queue eligible.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_activity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare preferences public.notification_preferences;
declare registration jsonb;
begin
  preferences := public.get_notification_preferences_v1();
  if not preferences.friend_posts or not preferences.push_enabled then
    raise exception 'alpha friend-post defaults are not enabled';
  end if;

  registration := public.register_user_device_v2(
    'a2200000-0000-4000-8000-000000000002'::uuid,
    repeat('a1', 32),
    'sandbox'
  );
  if registration ? 'push_token' or registration ? 'user_id' then
    raise exception 'device registration leaked protected identity or token data';
  end if;
end;
$$;

reset role;

insert into public.visits (
  user_id, cafe_id, drink_type, drink_subtype, caption,
  visibility, upload_state, overall_score, context_type
)
select
  (select id from alpha_activity_users where n = 1),
  (select id from public.cafes order by id limit 1),
  'Coffee', 'Activity friend post', 'Friend activity contract',
  'friends', 'complete', 4, 'Cafe'
returning id;

insert into alpha_activity_state (key, id)
select 'friend_visit', visit.id
from public.visits visit
where visit.caption = 'Friend activity contract'
  and visit.user_id = (select id from alpha_activity_users where n = 1)
order by visit.created_at desc, visit.id desc limit 1;

do $$
begin
  if not exists (
    select 1 from alpha_activity_events_debug event
    where event.recipient_id = (select id from alpha_activity_users where n = 2)
      and event.actor_user_id = (select id from alpha_activity_users where n = 1)
      and event.kind = 'friend_post'
      and event.visit_id = (select id from alpha_activity_state where key = 'friend_visit')
  ) then
    raise exception 'friend post did not create durable in-app activity';
  end if;
  if not exists (
    select 1
    from private.activity_push_deliveries delivery
    join alpha_activity_events_debug event on event.id = delivery.activity_event_id
    where event.visit_id = (select id from alpha_activity_state where key = 'friend_visit')
      and delivery.status = 'pending'
  ) then
    raise exception 'eligible friend post did not enter the local push queue';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_activity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare
  marked_count integer;
  remaining_count integer;
begin
  if public.activity_unread_count_v1() <> 1 then
    raise exception 'unread count is not caller-bound';
  end if;
  if not exists (
    select 1 from public.list_activity_events_v1() activity
    where activity.kind = 'friend_post'
      and activity.can_open_visit
      and activity.deep_link = 'mugshot://activity/visit/'
        || (select id::text from alpha_activity_state where key = 'friend_visit')
  ) then
    raise exception 'friend activity projection or deep link is incorrect';
  end if;
  -- Evaluate the mutation before the stable read. PostgreSQL may otherwise
  -- reorder the operands of a boolean expression.
  marked_count := public.mark_activity_read_v1(null);
  remaining_count := public.activity_unread_count_v1();
  if marked_count <> 1 or remaining_count <> 0 then
    raise exception 'mark-all-read did not update caller activity';
  end if;
end;
$$;

reset role;

-- A private post tag generates only a minimal safe notice. The recipient can
-- remove the tag without gaining post visibility or receiving a forbidden link.
insert into public.visits (
  user_id, cafe_id, drink_type, drink_subtype, caption,
  visibility, upload_state, overall_score, context_type
)
select
  (select id from alpha_activity_users where n = 1),
  (select id from public.cafes order by id limit 1),
  'Coffee', 'Secret test drink', 'DO NOT LEAK PRIVATE CAPTION',
  'private', 'complete', 4, 'Cafe'
returning id;

insert into alpha_activity_state (key, id)
select 'private_tag_visit', visit.id
from public.visits visit
where visit.caption = 'DO NOT LEAK PRIVATE CAPTION'
  and visit.user_id = (select id from alpha_activity_users where n = 1)
order by visit.created_at desc, visit.id desc limit 1;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_activity_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.set_visit_tags_v1(
  (select id from alpha_activity_state where key = 'private_tag_visit'),
  array[(select id from alpha_activity_users where n = 3)]
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_activity_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare projected record;
begin
  select * into projected
  from public.list_activity_events_v1() activity
  where activity.kind = 'tag'
    and activity.visit_id = (select id from alpha_activity_state where key = 'private_tag_visit');
  if not found then raise exception 'private tag notice is missing'; end if;
  if projected.can_open_visit or not projected.can_remove_tag
     or projected.deep_link <> 'mugshot://activity'
     or projected.body not like '%tagged you in a MugShot you can''t view.' then
    raise exception 'private tag notice leaks access or lacks self-removal';
  end if;
  if projected.body ilike '%secret test drink%'
     or projected.body ilike '%do not leak%' then
    raise exception 'private tag notice leaked post content';
  end if;
end;
$$;

select public.remove_self_visit_tag_v1(
  (select id from alpha_activity_state where key = 'private_tag_visit')
);

do $$
begin
  if exists (
    select 1 from public.list_activity_events_v1() activity
    where activity.kind = 'tag'
      and activity.visit_id = (select id from alpha_activity_state where key = 'private_tag_visit')
  ) then
    raise exception 'removed tag activity remained visible';
  end if;
end;
$$;

reset role;

-- Shared Mugshot invitations are retired. Continue with the owner-bound
-- collaborative-list activity contract.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_activity_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);

insert into alpha_activity_state (key, id)
select 'activity_cafe_list', (public.create_cafe_list(
  'Activity contract list', null, 'invited'
)).id;

select public.invite_cafe_list_member(
  (select id from alpha_activity_state where key = 'activity_cafe_list'),
  (select id from alpha_activity_users where n = 2),
  'editor'
);

insert into alpha_activity_state (key, id)
select 'list_event_first', event.id
from alpha_activity_events_debug event
where event.kind = 'collaborative_list_invitation'
  and event.cafe_list_id = (select id from alpha_activity_state where key = 'activity_cafe_list')
order by event.created_at desc, event.id desc limit 1;

select public.invite_cafe_list_member(
  (select id from alpha_activity_state where key = 'activity_cafe_list'),
  (select id from alpha_activity_users where n = 2),
  'editor'
);

do $$
begin
  if (select count(*) from alpha_activity_events_debug event
      where event.kind = 'collaborative_list_invitation'
        and event.cafe_list_id = (select id from alpha_activity_state where key = 'activity_cafe_list')) <> 1
     or not exists (
       select 1 from alpha_activity_events_debug event
       where event.id = (select id from alpha_activity_state where key = 'list_event_first')
     ) then
    raise exception 'pending cafe list retry re-notified';
  end if;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_activity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);
select public.respond_cafe_list_invitation(
  (select id from alpha_activity_state where key = 'activity_cafe_list'),
  false
);

reset role;

do $$
begin
  if exists (
    select 1 from alpha_activity_events_debug event
    where event.kind = 'collaborative_list_invitation'
      and event.cafe_list_id = (select id from alpha_activity_state where key = 'activity_cafe_list')
  ) then
    raise exception 'declined cafe list activity was not cleaned up';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_activity_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.invite_cafe_list_member(
  (select id from alpha_activity_state where key = 'activity_cafe_list'),
  (select id from alpha_activity_users where n = 2),
  'editor'
);
reset role;

do $$
begin
  if (select count(*) from alpha_activity_events_debug event
      where event.kind = 'collaborative_list_invitation'
        and event.cafe_list_id = (select id from alpha_activity_state where key = 'activity_cafe_list')) <> 1
     or exists (
       select 1 from alpha_activity_events_debug event
       where event.id = (select id from alpha_activity_state where key = 'list_event_first')
     ) then
    raise exception 'deliberate cafe list reinvite did not create one fresh event';
  end if;
end;
$$;

-- Actual interaction rows generate activity, and moderation suppresses an
-- actor's already-created event before it can be read or delivered.
insert into public.visits (
  user_id, cafe_id, drink_type, drink_subtype, caption,
  visibility, upload_state, overall_score, context_type
)
select
  (select id from alpha_activity_users where n = 1),
  (select id from public.cafes order by id limit 1),
  'Coffee', 'Activity interactions', 'Interaction activity contract',
  'everyone', 'complete', 4, 'Cafe'
returning id;

insert into alpha_activity_state (key, id)
select 'interaction_visit', visit.id
from public.visits visit
where visit.caption = 'Interaction activity contract'
  and visit.user_id = (select id from alpha_activity_users where n = 1)
order by visit.created_at desc, visit.id desc limit 1;

insert into public.likes (user_id, visit_id)
values (
  (select id from alpha_activity_users where n = 3),
  (select id from alpha_activity_state where key = 'interaction_visit')
);

insert into private.moderation_actions (
  subject_kind, subject_id, action_kind, reason_code
) values (
  'user', (select id from alpha_activity_users where n = 3),
  'social_restricted', 'activity_contract'
);

do $$
begin
  if not exists (
    select 1 from alpha_activity_events_debug event
    where event.kind = 'like'
      and event.actor_user_id = (select id from alpha_activity_users where n = 3)
      and event.suppressed_at is not null
  ) then
    raise exception 'moderation did not suppress existing actor activity';
  end if;
end;
$$;

-- Blocking removes both new and legacy pairwise notifications while leaving
-- unrelated history untouched.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_activity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);
select public.block_user_v2((select id from alpha_activity_users where n = 1));
reset role;

do $$
begin
  if exists (
    select 1 from alpha_activity_events_debug event
    where (event.recipient_id, event.actor_user_id) in (
      ((select id from alpha_activity_users where n = 1),
       (select id from alpha_activity_users where n = 2)),
      ((select id from alpha_activity_users where n = 2),
       (select id from alpha_activity_users where n = 1))
    )
  ) then
    raise exception 'blocking did not remove pairwise activity';
  end if;
end;
$$;

rollback;

select 'alpha_activity_delivery_contract_passed' as result;
