begin;

create temp table alpha_list_users as
select id, row_number() over (order by id) n
from (
  select profile.id
  from public.users profile
  where private.is_live_account_as(profile.id)
    and not private.account_deletion_active_as(profile.id)
    and not private.has_active_moderation_action(
      'user', profile.id,
      array['social_restricted', 'account_suspended']::text[]
    )
  order by profile.id
  limit 4
) users;
grant select on alpha_list_users to authenticated;

create temp table alpha_list_state (
  key text primary key,
  id uuid not null
);
grant select, insert, update on alpha_list_state to authenticated;

do $$
begin
  if (select count(*) from alpha_list_users) < 4 then
    raise exception 'collaborative list suite requires four existing users';
  end if;
  if (select count(*) from public.cafes) < 3 then
    raise exception 'collaborative list suite requires three existing cafes';
  end if;
end;
$$;

delete from public.user_blocks
where blocker_id in (select id from alpha_list_users)
   or blocked_id in (select id from alpha_list_users);
delete from public.friend_requests
where from_user_id in (select id from alpha_list_users)
   or to_user_id in (select id from alpha_list_users);
delete from public.friends
where user_id in (select id from alpha_list_users)
   or friend_user_id in (select id from alpha_list_users);

insert into public.friends (user_id, friend_user_id)
select owner.id, friend.id
from alpha_list_users owner
join alpha_list_users friend on friend.n in (2, 3, 4)
where owner.n = 1
union all
select friend.id, owner.id
from alpha_list_users owner
join alpha_list_users friend on friend.n in (2, 3, 4)
where owner.n = 1
union all
select first_friend.id, second_friend.id
from alpha_list_users first_friend
join alpha_list_users second_friend on second_friend.n = 3
where first_friend.n = 2
union all
select second_friend.id, first_friend.id
from alpha_list_users first_friend
join alpha_list_users second_friend on second_friend.n = 3
where first_friend.n = 2
on conflict do nothing;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);

insert into alpha_list_state (key, id)
select 'list', (public.create_cafe_list_v2(
  'Alpha coffee plans',
  'Hydrated and collaborative',
  'invited'
)->>'id')::uuid;

select public.add_cafe_list_item_v2(
  (select id from alpha_list_state where key = 'list'),
  (select id from public.cafes order by id limit 1),
  'Start here'
);

select public.invite_cafe_list_member(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 2),
  'editor'
);

reset role;
create temp table alpha_first_invite as
select created_at
from public.cafe_list_members
where list_id = (select id from alpha_list_state where key = 'list')
  and user_id = (select id from alpha_list_users where n = 2);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.invite_cafe_list_member(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 2),
  'editor'
);

reset role;
do $$
begin
  if (
    select member.created_at is distinct from first_invite.created_at
    from public.cafe_list_members member
    cross join alpha_first_invite first_invite
    where member.list_id = (select id from alpha_list_state where key = 'list')
      and member.user_id = (select id from alpha_list_users where n = 2)
  ) then
    raise exception 'pending invitation retry rewrote created_at';
  end if;
  if not exists (
    select 1
    from public.cafe_list_members member
    where member.list_id = (select id from alpha_list_state where key = 'list')
      and member.user_id = (select id from alpha_list_users where n = 2)
      and member.invitation_status = 'pending'
      and member.expires_at > now()
      and member.expires_at <= now() + interval '14 days'
  ) then
    raise exception 'pending invitation did not receive a bounded consent window';
  end if;
  if (
    select count(*)
    from public.activity_events event
    where event.kind = 'collaborative_list_invitation'
      and event.cafe_list_id = (select id from alpha_list_state where key = 'list')
      and event.recipient_id = (select id from alpha_list_users where n = 2)
  ) <> 1 then
    raise exception 'pending invitation retry duplicated activity';
  end if;
end;
$$;

-- Account deletion deliberately crosses a transient owner_id = NULL state
-- before its immutable collaboration plan assigns a live successor. The
-- transfer guard must permit that lifecycle boundary but reject an unavailable
-- successor.
update public.cafe_lists
set owner_id = null
where id = (select id from alpha_list_state where key = 'list');

do $$ begin
  if not exists (
    select 1 from public.cafe_lists list
    where list.id = (select id from alpha_list_state where key = 'list')
      and list.owner_id is null
  ) then
    raise exception 'cafe-list lifecycle could not cross its null-owner boundary';
  end if;
end $$;

update public.cafe_lists
set owner_id = (select id from alpha_list_users where n = 1)
where id = (select id from alpha_list_state where key = 'list');

do $$ begin
  if not exists (
    select 1
    from public.cafe_list_members member
    where member.list_id = (select id from alpha_list_state where key = 'list')
      and member.user_id = (select id from alpha_list_users where n = 2)
      and member.invitation_status = 'cancelled'
  ) then
    raise exception 'owner lifecycle did not cancel its stale invitation';
  end if;
end $$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.invite_cafe_list_member(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 2),
  'editor'
);
reset role;

insert into private.moderation_actions (
  subject_kind,
  subject_id,
  action_kind,
  reason_code
) values (
  'user',
  (select id from alpha_list_users where n = 3),
  'social_restricted',
  'alpha_list_transfer_contract'
);

do $$ begin
  begin
    update public.cafe_lists
    set owner_id = (select id from alpha_list_users where n = 3)
    where id = (select id from alpha_list_state where key = 'list');
    raise exception 'cafe-list ownership transferred to a restricted successor';
  exception when sqlstate '42501' then null;
  end;
end $$;

delete from private.moderation_actions
where subject_kind = 'user'
  and subject_id = (select id from alpha_list_users where n = 3)
  and reason_code = 'alpha_list_transfer_contract';

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 4),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.get_cafe_list_v2(
      (select id from alpha_list_state where key = 'list')
    );
    raise exception 'stranger read an invited cafe list';
  exception when sqlstate '42501' then null;
  end;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare
  detail jsonb := public.get_cafe_list_v2(
    (select id from alpha_list_state where key = 'list')
  );
begin
  if detail->>'access_kind' <> 'pending_invitation'
     or (detail->>'can_view_items')::boolean
     or jsonb_array_length(detail->'items') <> 0 then
    raise exception 'pending invitation exposed cafe-list contents';
  end if;
  if detail#>>'{inviter,user_id}'
     <> (select id::text from alpha_list_users where n = 1) then
    raise exception 'pending invitation did not hydrate its inviter';
  end if;
end;
$$;

select public.respond_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'list'),
  'decline'
);
select public.respond_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'list'),
  'decline'
);

reset role;
do $$
begin
  if exists (
    select 1
    from public.activity_events event
    where event.kind = 'collaborative_list_invitation'
      and event.cafe_list_id = (select id from alpha_list_state where key = 'list')
      and event.recipient_id = (select id from alpha_list_users where n = 2)
  ) then
    raise exception 'declined invitation retained activity';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.invite_cafe_list_member(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 2),
  'editor'
);

reset role;
do $$
begin
  if (
    select count(*)
    from public.activity_events event
    where event.kind = 'collaborative_list_invitation'
      and event.cafe_list_id = (select id from alpha_list_state where key = 'list')
      and event.recipient_id = (select id from alpha_list_users where n = 2)
  ) <> 1 then
    raise exception 'reinvite did not produce exactly one fresh activity';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);
select public.respond_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'list'),
  'accept'
);
select public.respond_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'list'),
  'accept'
);

reset role;
do $$
begin
  if exists (
    select 1
    from public.activity_events event
    where event.kind = 'collaborative_list_invitation'
      and event.cafe_list_id = (select id from alpha_list_state where key = 'list')
      and event.recipient_id = (select id from alpha_list_users where n = 2)
  ) then
    raise exception 'accepted invitation retained activity';
  end if;
end;
$$;

-- Enforcement must hide friend-only discovery without destroying durable
-- collaboration state. Pending invitees retain only a redacted decline path,
-- accepted collaborators retain the list and cafe contents but cannot expand
-- the suspended owner's social graph, and the owner can still cancel a
-- pending invitation as a monotonic safety exit.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);

insert into alpha_list_state (key, id)
select 'friend_visibility_list', (public.create_cafe_list_v2(
  'Friends-only suspension fixture',
  'Must disappear from friend discovery while its owner is unavailable',
  'friends'
)->>'id')::uuid;

insert into alpha_list_state (key, id)
select 'suspended_owner_list', (public.create_cafe_list_v2(
  'Durable suspended-owner fixture',
  'Accepted collaborators keep durable cafe context',
  'invited'
)->>'id')::uuid;

select public.add_cafe_list_item_v2(
  (select id from alpha_list_state where key = 'friend_visibility_list'),
  (select id from public.cafes order by id limit 1),
  'Friend discovery fixture'
);
select public.add_cafe_list_item_v2(
  (select id from alpha_list_state where key = 'suspended_owner_list'),
  (select id from public.cafes order by id offset 1 limit 1),
  'Durable collaboration fixture'
);
select public.invite_cafe_list_member(
  (select id from alpha_list_state where key = 'suspended_owner_list'),
  (select id from alpha_list_users where n = 2),
  'viewer'
);
select public.invite_cafe_list_member(
  (select id from alpha_list_state where key = 'suspended_owner_list'),
  (select id from alpha_list_users where n = 3),
  'editor'
);
select public.invite_cafe_list_member(
  (select id from alpha_list_state where key = 'suspended_owner_list'),
  (select id from alpha_list_users where n = 4),
  'viewer'
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);
select public.respond_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'suspended_owner_list'),
  'accept'
);

reset role;
insert into private.moderation_actions (
  subject_kind,
  subject_id,
  action_kind,
  reason_code
) values (
  'user',
  (select id from alpha_list_users where n = 1),
  'account_suspended',
  'alpha_list_suspended_owner_contract'
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);
do $$
declare
  lists jsonb := public.list_cafe_lists_v2();
begin
  if exists (
    select 1
    from jsonb_array_elements(lists) item
    where item->>'id' = (
      select id::text from alpha_list_state where key = 'friend_visibility_list'
    )
  ) then
    raise exception 'suspended owner remained visible through friend-only discovery';
  end if;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 4),
    'role', 'authenticated'
  )::text,
  true
);
do $$
declare
  detail jsonb := public.get_cafe_list_v2(
    (select id from alpha_list_state where key = 'suspended_owner_list')
  );
begin
  if detail->>'title' <> 'Unavailable cafe list invitation'
     or detail->>'description' is not null
     or detail->>'access_kind' <> 'pending_invitation'
     or (detail->>'can_view_items')::boolean
     or (detail->>'cafe_count')::integer <> 0
     or (detail->>'collaborator_count')::integer <> 0
     or detail#>>'{owner,identity_state}' <> 'hidden'
     or jsonb_array_length(detail->'items') <> 0 then
    raise exception 'pending invitation exposed a suspended owner or cafe contents';
  end if;
end;
$$;
select public.respond_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'suspended_owner_list'),
  'decline'
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.cancel_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'suspended_owner_list'),
  (select id from alpha_list_users where n = 2)
);
do $$
begin
  begin
    perform public.invite_cafe_list_member(
      (select id from alpha_list_state where key = 'suspended_owner_list'),
      (select id from alpha_list_users where n = 4),
      'viewer'
    );
    raise exception 'suspended owner expanded a cafe-list collaboration';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform public.update_cafe_list_v2(
      (select id from alpha_list_state where key = 'suspended_owner_list'),
      'Suspended owner mutation',
      null,
      'invited'
    );
    raise exception 'suspended owner edited a cafe list';
  exception when sqlstate '42501' then null;
  end;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);
do $$
declare
  detail jsonb := public.get_cafe_list_v2(
    (select id from alpha_list_state where key = 'suspended_owner_list')
  );
begin
  if detail->>'title' <> 'Durable suspended-owner fixture'
     or detail->>'access_kind' <> 'member'
     or not (detail->>'can_view_items')::boolean
     or (detail->>'can_edit_items')::boolean
     or detail#>>'{owner,identity_state}' <> 'hidden'
     or jsonb_array_length(detail->'items') <> 1 then
    raise exception 'accepted collaborator lost durable context or retained edit access';
  end if;
  begin
    perform public.add_cafe_list_item_v2(
      (select id from alpha_list_state where key = 'suspended_owner_list'),
      (select id from public.cafes order by id offset 2 limit 1),
      'Must not be added'
    );
    raise exception 'accepted collaborator edited for a suspended owner';
  exception when sqlstate '42501' then null;
  end;
end;
$$;
select public.leave_cafe_list_v2(
  (select id from alpha_list_state where key = 'suspended_owner_list')
);

reset role;
do $$
begin
  if exists (
    select 1
    from public.cafe_list_members member
    where member.list_id = (
      select id from alpha_list_state where key = 'suspended_owner_list'
    )
      and member.user_id = (select id from alpha_list_users where n = 3)
  ) then
    raise exception 'accepted collaborator could not leave a suspended owner';
  end if;
  if not exists (
    select 1
    from public.cafe_list_members member
    where member.list_id = (
      select id from alpha_list_state where key = 'suspended_owner_list'
    )
      and member.user_id = (select id from alpha_list_users where n = 2)
      and member.invitation_status = 'cancelled'
  ) then
    raise exception 'suspended owner could not cancel a pending invitation';
  end if;
end;
$$;

delete from private.moderation_actions
where subject_kind = 'user'
  and subject_id = (select id from alpha_list_users where n = 1)
  and reason_code = 'alpha_list_suspended_owner_contract';

-- Cancel and reinvite use the same durable membership row and one activity
-- cycle. The accepted viewer cannot mutate cafe items.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.invite_cafe_list_member(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 4),
  'viewer'
);
select public.cancel_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 4)
);
select public.cancel_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 4)
);
select public.invite_cafe_list_member(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 4),
  'viewer'
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 4),
    'role', 'authenticated'
  )::text,
  true
);
select public.respond_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'list'),
  'accept'
);
do $$
begin
  begin
    perform public.add_cafe_list_item_v2(
      (select id from alpha_list_state where key = 'list'),
      (select id from public.cafes order by id offset 1 limit 1),
      null
    );
    raise exception 'viewer added a cafe-list item';
  exception when sqlstate '42501' then null;
  end;
end;
$$;

-- A second editor contributes a cafe. A block between collaborators keeps the
-- cafe but masks the blocked member and contributor identity in projection.
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.invite_cafe_list_member(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 3),
  'editor'
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);
select public.respond_cafe_list_invitation_v2(
  (select id from alpha_list_state where key = 'list'),
  'accept'
);
select public.add_cafe_list_item_v2(
  (select id from alpha_list_state where key = 'list'),
  (select id from public.cafes order by id offset 1 limit 1),
  'Blocked contributor remains durable'
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);
select public.add_cafe_list_item_v2(
  (select id from alpha_list_state where key = 'list'),
  (select id from public.cafes order by id offset 2 limit 1),
  'Editor contribution'
);
select public.block_user_v2((select id from alpha_list_users where n = 3));

do $$
declare
  detail jsonb := public.get_cafe_list_v2(
    (select id from alpha_list_state where key = 'list')
  );
begin
  if not exists (
    select 1
    from jsonb_array_elements(detail->'members') member
    where member#>>'{person,identity_state}' = 'hidden'
      and not (member->'person' ? 'user_id')
  ) then
    raise exception 'blocked collaborator identity was not masked';
  end if;
  if not exists (
    select 1
    from jsonb_array_elements(detail->'items') item
    where item->>'note' = 'Blocked contributor remains durable'
      and item#>>'{contributor,identity_state}' = 'hidden'
      and not (item->'contributor' ? 'user_id')
  ) then
    raise exception 'blocked item provenance was removed or exposed';
  end if;
  if not exists (
    select 1
    from jsonb_array_elements(detail->'items') item
    where item->>'cafe_name' = (
      select name from public.cafes order by id offset 1 limit 1
    )
  ) then
    raise exception 'hydrated cafe identity was unavailable';
  end if;
end;
$$;

-- Owner management, role changes, contiguous removal, and transfer lifecycle.
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.move_cafe_list_item_v2(
  (
    select item.id
    from public.cafe_list_items item
    where item.list_id = (select id from alpha_list_state where key = 'list')
      and item.note = 'Blocked contributor remains durable'
  ),
  0
);
select public.set_cafe_list_member_role_v2(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 2),
  'viewer'
);
select public.set_cafe_list_member_role_v2(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 2),
  'editor'
);

select public.remove_cafe_list_item_v2((
  select item.id
  from public.cafe_list_items item
  where item.list_id = (select id from alpha_list_state where key = 'list')
  order by item.position
  limit 1
));

reset role;
do $$
begin
  if exists (
    select 1
    from (
      select position, row_number() over (order by position, id) - 1 expected
      from public.cafe_list_items
      where list_id = (select id from alpha_list_state where key = 'list')
    ) positions
    where position <> expected
  ) then
    raise exception 'removing a cafe left non-contiguous positions';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);
select public.transfer_cafe_list_ownership_v2(
  (select id from alpha_list_state where key = 'list'),
  (select id from alpha_list_users where n = 2)
);

reset role;
do $$
begin
  if not exists (
    select 1
    from public.cafe_lists list
    where list.id = (select id from alpha_list_state where key = 'list')
      and list.owner_id = (select id from alpha_list_users where n = 2)
  ) then
    raise exception 'ownership transfer did not update stewardship';
  end if;
  if not exists (
    select 1
    from public.cafe_list_members member
    where member.list_id = (select id from alpha_list_state where key = 'list')
      and member.user_id = (select id from alpha_list_users where n = 1)
      and member.role = 'editor'
      and member.invitation_status = 'accepted'
  ) then
    raise exception 'former owner did not retain editor access';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_list_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);
do $$
begin
  begin
    perform public.leave_cafe_list_v2(
      (select id from alpha_list_state where key = 'list')
    );
    raise exception 'current owner left without transferring or deleting';
  exception when sqlstate '42501' then null;
  end;
end;
$$;
select public.delete_cafe_list_v2(
  (select id from alpha_list_state where key = 'list')
);
select public.delete_cafe_list_v2(
  (select id from alpha_list_state where key = 'list')
);

reset role;
do $$
begin
  if exists (
    select 1 from public.cafe_lists
    where id = (select id from alpha_list_state where key = 'list')
  ) then
    raise exception 'owner delete left the cafe list behind';
  end if;
end;
$$;

rollback;

select 'alpha_collaborative_cafe_lists_contract_passed' as result;
