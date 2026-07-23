begin;

create temp table alpha_shared_users as
select id, row_number() over (order by id) n
from (
  select profile.id
  from public.users profile
  join auth.users account on account.id = profile.id
  where account.deleted_at is null
    and not private.has_active_moderation_action(
      'user', profile.id, array['social_restricted', 'account_suspended']::text[]
    )
    and not private.account_deletion_active_as(profile.id)
  order by profile.id
  limit 3
) users;
grant select on alpha_shared_users to authenticated;

do $$ begin
  if (select count(*) from alpha_shared_users) < 3 then
    raise exception 'alpha shared-memory contract requires three existing users';
  end if;
  if not exists (select 1 from public.cafes) then
    raise exception 'alpha shared-memory contract requires one existing cafe';
  end if;
  if has_table_privilege('authenticated', 'public.shared_memories', 'SELECT')
     or has_table_privilege('authenticated', 'public.shared_memory_members', 'SELECT')
     or has_table_privilege('authenticated', 'public.shared_memory_contributions', 'SELECT') then
    raise exception 'raw shared-memory tables are exposed to authenticated clients';
  end if;
end $$;

delete from public.user_blocks
where blocker_id in (select id from alpha_shared_users)
  and blocked_id in (select id from alpha_shared_users);
delete from public.friends
where user_id in (select id from alpha_shared_users)
  and friend_user_id in (select id from alpha_shared_users);
insert into public.friends (user_id, friend_user_id)
values
  ((select id from alpha_shared_users where n = 1),
   (select id from alpha_shared_users where n = 2)),
  ((select id from alpha_shared_users where n = 2),
   (select id from alpha_shared_users where n = 1)),
  ((select id from alpha_shared_users where n = 1),
   (select id from alpha_shared_users where n = 3)),
  ((select id from alpha_shared_users where n = 3),
   (select id from alpha_shared_users where n = 1))
on conflict do nothing;

create temp table alpha_shared_visits (
  kind text primary key,
  visit_id uuid not null
);
grant select on alpha_shared_visits to authenticated;

with inserted as (
  insert into public.visits (
    user_id,
    cafe_id,
    drink_type,
    drink_subtype,
    caption,
    visibility,
    overall_score,
    context_type,
    location_name,
    upload_state
  )
  values
    (
      (select id from alpha_shared_users where n = 1),
      (select id from public.cafes order by id limit 1),
      'Coffee',
      'Alpha owner latte',
      'Owner memory',
      'everyone',
      4.5,
      'Cafe',
      'Alpha shared cafe',
      'complete'
    ),
    (
      (select id from alpha_shared_users where n = 2),
      (select id from public.cafes order by id limit 1),
      'Coffee',
      'Alpha friend latte',
      'Friend memory',
      'friends',
      4,
      'Cafe',
      'Alpha shared cafe',
      'complete'
    ),
    (
      (select id from alpha_shared_users where n = 1),
      (select id from public.cafes order by id limit 1),
      'Coffee',
      'Alpha private tag',
      'A tag must not grant access',
      'private',
      4,
      'Cafe',
      'Alpha shared cafe',
      'complete'
    ),
    (
      (select id from alpha_shared_users where n = 3),
      (select id from public.cafes order by id limit 1),
      'Coffee',
      'Alpha third latte',
      'Third memory',
      'friends',
      4.2,
      'Cafe',
      'Alpha shared cafe',
      'complete'
    )
  returning id, user_id, caption
)
insert into alpha_shared_visits(kind, visit_id)
select case caption
  when 'Owner memory' then 'owner'
  when 'Friend memory' then 'friend'
  when 'Third memory' then 'third'
  else 'private_tag'
end, id
from inserted;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);

select public.set_visit_tags_v1(
  (select visit_id from alpha_shared_visits where kind = 'private_tag'),
  array[(select id from alpha_shared_users where n = 3)]
);

reset role;
create temp table alpha_tag_retry_snapshot as
select
  tag.created_at tagged_at,
  activity.id activity_id,
  activity.created_at activity_created_at
from public.visit_companions tag
left join public.activity_events activity
  on activity.kind = 'tag'
 and activity.visit_id = tag.visit_id
 and activity.recipient_id = tag.companion_user_id
 and activity.actor_user_id = tag.added_by
where tag.visit_id = (
    select visit_id from alpha_shared_visits where kind = 'private_tag'
  )
  and tag.companion_user_id = (select id from alpha_shared_users where n = 3);
grant select on alpha_tag_retry_snapshot to authenticated;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);
select public.set_visit_tags_v1(
  (select visit_id from alpha_shared_visits where kind = 'private_tag'),
  array[(select id from alpha_shared_users where n = 3)]
);

reset role;
do $$ begin
  if (select count(*) from alpha_tag_retry_snapshot) <> 1
     or (select activity_id from alpha_tag_retry_snapshot) is null
     or not exists (
       select 1
       from public.visit_companions tag
       where tag.visit_id = (
           select visit_id from alpha_shared_visits where kind = 'private_tag'
         )
         and tag.companion_user_id = (select id from alpha_shared_users where n = 3)
         and tag.created_at = (select tagged_at from alpha_tag_retry_snapshot)
     )
     or (select count(*) from public.activity_events activity
         where activity.kind = 'tag'
           and activity.visit_id = (
             select visit_id from alpha_shared_visits where kind = 'private_tag'
           )
           and activity.recipient_id = (select id from alpha_shared_users where n = 3)
           and activity.actor_user_id = (select id from alpha_shared_users where n = 1)
           and activity.id = (select activity_id from alpha_tag_retry_snapshot)
           and activity.created_at = (
             select activity_created_at from alpha_tag_retry_snapshot
           )) <> 1 then
    raise exception 'same-set tag retry churned its row or activity event';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);

do $$ begin
  if (select count(*) from public.list_visible_visit_tags_v1(
    (select visit_id from alpha_shared_visits where kind = 'private_tag')
  )) <> 1 then
    raise exception 'owner could not read ordinary tag';
  end if;
end $$;

reset role;
insert into private.moderation_actions(
  subject_kind, subject_id, action_kind, reason_code
) values (
  'user', (select id from alpha_shared_users where n = 3),
  'account_suspended', 'visible_tag_projection_contract'
);
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if exists (
    select 1 from public.list_visible_visit_tags_v1(
      (select visit_id from alpha_shared_visits where kind = 'private_tag')
    )
  ) then
    raise exception 'suspended tagged identity remained visible';
  end if;
end $$;
reset role;
delete from private.moderation_actions
where subject_kind = 'user'
  and subject_id = (select id from alpha_shared_users where n = 3)
  and reason_code = 'visible_tag_projection_contract';

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 3),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if public.can_view_visit(
    (select visit_id from alpha_shared_visits where kind = 'private_tag')
  ) then
    raise exception 'ordinary tag broadened private post audience';
  end if;
  if exists (
    select 1 from public.list_visible_visit_tags_v1(
      (select visit_id from alpha_shared_visits where kind = 'private_tag')
    )
  ) then
    raise exception 'tagged user read tags on an otherwise hidden post';
  end if;
  if not public.remove_self_visit_tag_v1(
    (select visit_id from alpha_shared_visits where kind = 'private_tag')
  ) then
    raise exception 'tagged user could not remove their own hidden-post tag';
  end if;
  begin
    perform public.set_visit_tags_v1(
      (select visit_id from alpha_shared_visits where kind = 'private_tag'),
      '{}'::uuid[]
    );
    raise exception 'non-owner changed another user tags';
  exception when sqlstate '42501' then null;
  end;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);

create temp table alpha_shared_memory as
select public.create_shared_memory_invitations_v1(
  (select visit_id from alpha_shared_visits where kind = 'owner'),
  array[
    (select id from alpha_shared_users where n = 2),
    (select id from alpha_shared_users where n = 3)
  ]
) memory_id;
grant select on alpha_shared_memory to authenticated;

create temp table alpha_shared_invitation_retry as
select invitation.invitation_id, invitation.invited_at
from public.list_managed_shared_memory_invitations_v1(
  (select memory_id from alpha_shared_memory)
) invitation
where invitation.user_id = (select id from alpha_shared_users where n = 2);
grant select on alpha_shared_invitation_retry to authenticated;

reset role;
alter table alpha_shared_invitation_retry
  add column activity_id uuid,
  add column activity_created_at timestamptz;
update alpha_shared_invitation_retry snapshot
set activity_id = activity.id,
    activity_created_at = activity.created_at
from public.activity_events activity
where activity.kind = 'shared_mugshot_invitation'
  and activity.shared_memory_id = (select memory_id from alpha_shared_memory)
  and activity.recipient_id = (select id from alpha_shared_users where n = 2);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);

select public.create_shared_memory_invitations_v1(
  (select visit_id from alpha_shared_visits where kind = 'owner'),
  array[
    (select id from alpha_shared_users where n = 2),
    (select id from alpha_shared_users where n = 3)
  ]
);

do $$ begin
  if (select count(*) from alpha_shared_invitation_retry) <> 1
     or not exists (
       select 1
       from public.list_managed_shared_memory_invitations_v1(
         (select memory_id from alpha_shared_memory)
       ) invitation
       where invitation.invitation_id = (
           select invitation_id from alpha_shared_invitation_retry
         )
         and invitation.invited_at = (
           select invited_at from alpha_shared_invitation_retry
         )
         and invitation.status = 'pending'
     ) then
    raise exception 'same pending shared MugShot invitation retry churned its timestamp';
  end if;
end $$;

reset role;

-- Stewardship skips an unavailable first choice, and dissolving a grouping
-- never deletes independently owned posts.
delete from public.user_blocks
where blocker_id in (select id from alpha_shared_users)
  and blocked_id in (select id from alpha_shared_users);

create temp table alpha_shared_safety_state(
  kind text primary key,
  memory_id uuid not null,
  source_visit_id uuid not null
);
do $$
declare
  target_kind text;
  source_id uuid;
  memory_id uuid;
begin
  foreach target_kind in array array['fallback', 'dissolve', 'manual_delete']
  loop
    insert into public.visits(
      user_id, cafe_id, drink_type, drink_subtype, caption, visibility,
      overall_score, context_type, location_name, upload_state
    ) values (
      (select id from alpha_shared_users where n = 1),
      (select id from public.cafes order by id limit 1),
      'Coffee',
      'Shared safety ' || target_kind,
      'Shared safety ' || target_kind,
      'everyone',
      4.1,
      'Cafe',
      'Alpha shared cafe',
      'complete'
    ) returning id into source_id;

    insert into public.shared_memories(
      created_by, managed_by, source_visit_id, context_type, cafe_id,
      location_label, occurred_at
    ) values (
      (select id from alpha_shared_users where n = 1),
      (select id from alpha_shared_users where n = 1),
      source_id,
      'Cafe',
      (select id from public.cafes order by id limit 1),
      'Alpha shared cafe',
      now()
    ) returning id into memory_id;

    insert into public.shared_memory_members(
      shared_memory_id, user_id, invited_by, status, responded_at
    ) values (
      memory_id,
      (select id from alpha_shared_users where n = 1),
      (select id from alpha_shared_users where n = 1),
      'accepted',
      now()
    );
    insert into public.shared_memory_contributions(
      shared_memory_id, visit_id, user_id
    ) values (
      memory_id,
      source_id,
      (select id from alpha_shared_users where n = 1)
    );

    if target_kind in ('fallback', 'dissolve') then
      insert into public.shared_memory_members(
        shared_memory_id, user_id, invited_by, status, responded_at
      ) values (
        memory_id,
        (select id from alpha_shared_users where n = 2),
        (select id from alpha_shared_users where n = 1),
        'accepted',
        now() - interval '2 minutes'
      );
    end if;
    if target_kind = 'fallback' then
      insert into public.shared_memory_members(
        shared_memory_id, user_id, invited_by, status, responded_at
      ) values (
        memory_id,
        (select id from alpha_shared_users where n = 3),
        (select id from alpha_shared_users where n = 1),
        'accepted',
        now() - interval '1 minute'
      );
    end if;

    insert into alpha_shared_safety_state values (
      target_kind, memory_id, source_id
    );
  end loop;
end;
$$;
grant select on alpha_shared_safety_state to authenticated;

insert into private.moderation_actions(
  subject_kind, subject_id, action_kind, reason_code
) values (
  'user', (select id from alpha_shared_users where n = 2),
  'social_restricted', 'shared_stewardship_contract'
);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);

create temp table alpha_shared_leave_results(
  kind text primary key,
  left_ok boolean not null
);
insert into alpha_shared_leave_results(kind, left_ok)
values
  (
    'fallback',
    public.leave_shared_memory_v1(
      (select memory_id from alpha_shared_safety_state where kind = 'fallback')
    )
  ),
  (
    'dissolve',
    public.leave_shared_memory_v1(
      (select memory_id from alpha_shared_safety_state where kind = 'dissolve')
    )
  );

reset role;
do $$ begin
  if not (select left_ok from alpha_shared_leave_results where kind = 'fallback')
     or not exists (
    select 1 from public.shared_memories memory
    where memory.id = (
      select memory_id from alpha_shared_safety_state where kind = 'fallback'
    )
      and memory.managed_by = (select id from alpha_shared_users where n = 3)
  ) then
    raise exception 'shared MugShot stewardship did not skip unavailable successor';
  end if;

  if not (select left_ok from alpha_shared_leave_results where kind = 'dissolve')
     or exists (
    select 1 from public.shared_memories
    where id = (select memory_id from alpha_shared_safety_state where kind = 'dissolve')
  ) or not exists (
    select 1 from public.visits
    where id = (
      select source_visit_id from alpha_shared_safety_state where kind = 'dissolve'
    )
  ) then
    raise exception 'owner-only shared grouping did not dissolve independently';
  end if;
end $$;

delete from private.moderation_actions
where subject_kind = 'user'
  and subject_id = (select id from alpha_shared_users where n = 2)
  and reason_code = 'shared_stewardship_contract';

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);
delete from public.visits
where id = (
  select source_visit_id from alpha_shared_safety_state where kind = 'manual_delete'
);
reset role;
do $$ begin
  if exists (
    select 1 from public.shared_memories
    where id = (
      select memory_id from alpha_shared_safety_state where kind = 'manual_delete'
    )
  ) or not exists (
    select 1 from public.visits
    where id = (select visit_id from alpha_shared_visits where kind = 'third')
  ) then
    raise exception 'manual source deletion orphaned grouping or removed another post';
  end if;
end $$;

do $$ begin
  if (select activity_id from alpha_shared_invitation_retry) is null
     or (select count(*)
         from public.activity_events activity
         where activity.kind = 'shared_mugshot_invitation'
           and activity.shared_memory_id = (select memory_id from alpha_shared_memory)
           and activity.recipient_id = (select id from alpha_shared_users where n = 2)
           and activity.id = (select activity_id from alpha_shared_invitation_retry)
           and activity.created_at = (
             select activity_created_at from alpha_shared_invitation_retry
           )) <> 1 then
    raise exception 'same pending shared MugShot retry churned its activity event';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);

do $$ begin
  if not exists (
    select 1
    from public.list_owned_shared_memories_v1() owned
    where owned.shared_memory_id = (select memory_id from alpha_shared_memory)
      and owned.source_visit_id = (
        select visit_id from alpha_shared_visits where kind = 'owner'
      )
  ) then
    raise exception 'creator could not recover owned shared memory after relaunch';
  end if;
end $$;

do $$ begin
  if not public.cancel_shared_memory_invitation_v1((
    select invitation.invitation_id
    from public.list_managed_shared_memory_invitations_v1(
      (select memory_id from alpha_shared_memory)
    ) invitation
    where invitation.user_id = (select id from alpha_shared_users where n = 2)
  )) then
    raise exception 'inviter could not cancel pending invitation';
  end if;
end $$;

select public.create_shared_memory_invitations_v1(
  (select visit_id from alpha_shared_visits where kind = 'owner'),
  array[(select id from alpha_shared_users where n = 2)]
);

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 2),
  'role', 'authenticated'
)::text, true);

do $$ begin
  if (select count(*) from public.list_pending_shared_memory_invitations_v1()) <> 1 then
    raise exception 'invitee did not receive safe pending invitation metadata';
  end if;
  begin
    perform public.attach_shared_memory_contribution_v1(
      (select memory_id from alpha_shared_memory),
      (select visit_id from alpha_shared_visits where kind = 'friend')
    );
    raise exception 'pending invitee contributed without consent';
  exception when sqlstate '42501' then null;
  end;
end $$;

select public.respond_shared_memory_invitation_v1(
  (select invitation_id from public.list_pending_shared_memory_invitations_v1()),
  false
);

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);
select public.create_shared_memory_invitations_v1(
  (select visit_id from alpha_shared_visits where kind = 'owner'),
  array[(select id from alpha_shared_users where n = 2)]
);

reset role;
insert into private.moderation_actions(
  subject_kind, subject_id, action_kind, reason_code
) values (
  'user', (select id from alpha_shared_users where n = 1),
  'account_suspended', 'shared_inviter_projection_contract'
);
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 2),
  'role', 'authenticated'
)::text, true);

do $$
declare target_invitation uuid;
begin
  if exists (
    select 1 from public.list_pending_shared_memory_invitations_v1()
  ) or not exists (
    select 1 from public.list_my_shared_memory_memberships_v1() membership
    where membership.shared_memory_id = (select memory_id from alpha_shared_memory)
      and membership.status = 'pending'
      and not membership.relationship_available
      and membership.inviter_id is null
  ) then
    raise exception 'suspended inviter was not masked behind a decline safety exit';
  end if;

  select membership.membership_id into target_invitation
  from public.list_my_shared_memory_memberships_v1() membership
  where membership.shared_memory_id = (select memory_id from alpha_shared_memory)
    and membership.status = 'pending';

  begin
    perform public.respond_shared_memory_invitation_v1(target_invitation, true);
    raise exception 'suspended inviter invitation was accepted';
  exception when sqlstate '42501' then null;
  end;
  if public.respond_shared_memory_invitation_v1(target_invitation, false)
       <> 'declined' then
    raise exception 'masked shared MugShot invitation could not be declined';
  end if;
end;
$$;

reset role;
delete from private.moderation_actions
where subject_kind = 'user'
  and subject_id = (select id from alpha_shared_users where n = 1)
  and reason_code = 'shared_inviter_projection_contract';
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);
select public.create_shared_memory_invitations_v1(
  (select visit_id from alpha_shared_visits where kind = 'owner'),
  array[(select id from alpha_shared_users where n = 2)]
);
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 2),
  'role', 'authenticated'
)::text, true);
select public.respond_shared_memory_invitation_v1(
  (select invitation_id from public.list_pending_shared_memory_invitations_v1()),
  true
);
do $$ begin
  if not exists (
    select 1
    from public.list_my_shared_memory_memberships_v1() membership
    where membership.shared_memory_id = (select memory_id from alpha_shared_memory)
      and membership.status = 'accepted'
      and membership.relationship_available
  ) then
    raise exception 'accepted membership was not recoverable after relaunch';
  end if;
end $$;
select public.attach_shared_memory_contribution_v1(
  (select memory_id from alpha_shared_memory),
  (select visit_id from alpha_shared_visits where kind = 'friend')
);

do $$
declare projection jsonb;
begin
  projection := public.get_shared_memory_projection_v1(
    (select visit_id from alpha_shared_visits where kind = 'friend')
  );
  if jsonb_array_length(projection -> 'contributions') <> 2 then
    raise exception 'accepted participant did not see both independently visible contributions';
  end if;
end $$;

reset role;
insert into private.moderation_actions(
  subject_kind, subject_id, action_kind, reason_code
) values (
  'user', (select id from alpha_shared_users where n = 3),
  'account_suspended', 'shared_roster_projection_contract'
);
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if not exists (
    select 1
    from public.list_managed_shared_memory_invitations_v1(
      (select memory_id from alpha_shared_memory)
    ) invitation
    where invitation.status = 'pending'
      and invitation.user_id is null
      and invitation.username is null
  ) then
    raise exception 'suspended shared MugShot member identity was not masked';
  end if;
end $$;
reset role;
delete from private.moderation_actions
where subject_kind = 'user'
  and subject_id = (select id from alpha_shared_users where n = 3)
  and reason_code = 'shared_roster_projection_contract';
set local role authenticated;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 3),
  'role', 'authenticated'
)::text, true);

select public.respond_shared_memory_invitation_v1(
  (select invitation_id from public.list_pending_shared_memory_invitations_v1()),
  true
);
select public.attach_shared_memory_contribution_v1(
  (select memory_id from alpha_shared_memory),
  (select visit_id from alpha_shared_visits where kind = 'third')
);

do $$
declare projection jsonb;
begin
  projection := public.get_shared_memory_projection_v1(
    (select visit_id from alpha_shared_visits where kind = 'third')
  );
  if projection is null
     or jsonb_array_length(projection -> 'contributions') <> 2
     or exists (
       select 1
       from jsonb_array_elements(projection -> 'contributions') contribution
       where contribution ->> 'user_id' =
         (select id::text from alpha_shared_users where n = 2)
     ) then
    raise exception 'third participant did not receive the audience-safe A+C group';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 1),
  'role', 'authenticated'
)::text, true);
select public.block_user((select id from alpha_shared_users where n = 2));

do $$
declare projection jsonb;
begin
  projection := public.get_shared_memory_projection_v1(
    (select visit_id from alpha_shared_visits where kind = 'owner')
  );
  if projection is null
     or jsonb_array_length(projection -> 'contributions') <> 2
     or exists (
       select 1
       from jsonb_array_elements(projection -> 'contributions') contribution
       where contribution ->> 'user_id' =
         (select id::text from alpha_shared_users where n = 2)
     ) then
    raise exception 'block did not preserve only the audience-safe A+C group';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_shared_users where n = 2),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if exists (
    select 1
    from public.list_my_shared_memory_memberships_v1() membership
    where membership.shared_memory_id = (select memory_id from alpha_shared_memory)
  ) then
    raise exception 'block did not sever the shared MugShot membership';
  end if;
  if not public.can_view_visit(
    (select visit_id from alpha_shared_visits where kind = 'friend')
  ) then
    raise exception 'block removed the blocked participant''s independent visit';
  end if;
  if public.get_shared_memory_projection_v1(
    (select visit_id from alpha_shared_visits where kind = 'friend')
  ) is not null then
    raise exception 'single visible contribution still rendered as a shared group after block';
  end if;
  if public.get_shared_memory_projection_v1(
    (select visit_id from alpha_shared_visits where kind = 'friend')
  ) is not null then
    raise exception 'blocking retained a discoverable contribution link';
  end if;
end $$;

reset role;
do $$ begin
  if (select count(*)
      from public.visits visit
      where visit.id in (
        select visit_id from alpha_shared_visits where kind in ('owner', 'friend', 'third')
      )) <> 3 then
    raise exception 'block or shared presentation removed an independently owned visit';
  end if;
end $$;

rollback;

select 'alpha_tags_shared_memory_contract_passed' as result;
