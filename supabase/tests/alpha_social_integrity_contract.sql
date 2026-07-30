\set ON_ERROR_STOP on

begin;

-- This suite is transaction-isolated: it uses existing local fixture users and
-- cafes, creates its own content, and rolls every mutation back.
create temp table alpha_integrity_users as
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

create temp table alpha_integrity_state (
  key text primary key,
  id uuid not null
);

grant select on alpha_integrity_users to authenticated;
grant all on alpha_integrity_state to authenticated;

do $$
begin
  if (select count(*) from alpha_integrity_users) < 3 then
    raise exception 'alpha social integrity suite requires three local fixture users';
  end if;
  if not exists (select 1 from public.cafes) then
    raise exception 'alpha social integrity suite requires one local fixture cafe';
  end if;
end;
$$;

delete from public.user_blocks block
where block.blocker_id in (select id from alpha_integrity_users)
  and block.blocked_id in (select id from alpha_integrity_users);

insert into public.visits (
  user_id, cafe_id, drink_type, drink_subtype, caption,
  visibility, overall_score, context_type
)
select
  (select id from alpha_integrity_users where n = 1),
  (select id from public.cafes order by id limit 1),
  'Coffee', 'Integrity retention', 'Durable report target',
  'everyone', 4, 'Cafe'
returning id;

insert into alpha_integrity_state (key, id)
select 'retention_visit', id
from public.visits
where caption = 'Durable report target'
  and user_id = (select id from alpha_integrity_users where n = 1)
order by created_at desc, id desc
limit 1;

insert into public.visits (
  user_id, cafe_id, drink_type, drink_subtype, caption,
  visibility, overall_score, context_type
)
select
  (select id from alpha_integrity_users where n = 1),
  (select id from public.cafes order by id limit 1),
  'Coffee', 'Integrity moderation', 'Moderation visibility target',
  'everyone', 4, 'Cafe'
returning id;

insert into alpha_integrity_state (key, id)
select 'moderation_visit', id
from public.visits
where caption = 'Moderation visibility target'
  and user_id = (select id from alpha_integrity_users where n = 1)
order by created_at desc, id desc
limit 1;

insert into public.visits (
  user_id, cafe_id, drink_type, drink_subtype, caption,
  visibility, overall_score, context_type
)
select
  (select id from alpha_integrity_users where n = 1),
  (select id from public.cafes order by id limit 1),
  'Coffee', 'Integrity comments', 'Comment ownership target',
  'everyone', 4, 'Cafe'
returning id;

insert into alpha_integrity_state (key, id)
select 'comment_visit', id
from public.visits
where caption = 'Comment ownership target'
  and user_id = (select id from alpha_integrity_users where n = 1)
order by created_at desc, id desc
limit 1;

insert into public.visits (
  user_id, cafe_id, drink_type, drink_subtype, caption,
  visibility, overall_score, context_type
)
select
  (select id from alpha_integrity_users where n = 1),
  (select id from public.cafes order by id limit 1),
  'Coffee', 'Integrity block', 'Block coherence target',
  'everyone', 4, 'Cafe'
returning id;

insert into alpha_integrity_state (key, id)
select 'block_visit', id
from public.visits
where caption = 'Block coherence target'
  and user_id = (select id from alpha_integrity_users where n = 1)
order by created_at desc, id desc
limit 1;

-- ---------------------------------------------------------------------------
-- Idempotent reports retain immutable target identity and evidence after the
-- target row is deleted.
-- ---------------------------------------------------------------------------

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

select public.submit_report_v2(
  'a1100000-0000-4000-8000-000000000001'::uuid,
  'spam'::public.report_reason,
  'visit',
  (select id from alpha_integrity_state where key = 'retention_visit'),
  'Duplicate-safe receipt test'
);

select public.submit_report_v2(
  'a1100000-0000-4000-8000-000000000001'::uuid,
  'spam'::public.report_reason,
  'visit',
  (select id from alpha_integrity_state where key = 'retention_visit'),
  'Duplicate-safe receipt test'
);

do $$
begin
  if (
    select count(*)
    from public.get_report_receipt_v1(
      'a1100000-0000-4000-8000-000000000001'::uuid
    ) receipt
  ) <> 1 then
    raise exception 'idempotent report submission created duplicate rows';
  end if;
  if not exists (
    select 1
    from public.get_report_receipt_v1(
      'a1100000-0000-4000-8000-000000000001'::uuid
    ) receipt
    where receipt.status = 'pending'
  ) then
    raise exception 'report receipt was unavailable to its reporter';
  end if;

  begin
    perform public.submit_report_v2(
      'a1100000-0000-4000-8000-000000000001'::uuid,
      'harassment'::public.report_reason,
      'visit',
      (select id from alpha_integrity_state where key = 'retention_visit'),
      'Different evidence'
    );
    raise exception 'reused client report id accepted different evidence';
  exception when sqlstate '22023' then
    null;
  end;

  begin
    perform public.submit_report_v2(
      'a1100000-0000-4000-8000-000000000002'::uuid,
      'other'::public.report_reason,
      'visit',
      (select id from alpha_integrity_state where key = 'retention_visit'),
      null
    );
    raise exception 'other report accepted missing details';
  exception when sqlstate '22023' then
    null;
  end;

  begin
    perform public.submit_report_v2(
      'a1100000-0000-4000-8000-000000000003'::uuid,
      'harassment'::public.report_reason,
      'visit',
      (select id from alpha_integrity_state where key = 'retention_visit'),
      repeat('x', 2001)
    );
    raise exception 'report accepted details longer than 2000 characters';
  exception when sqlstate '22023' then
    null;
  end;
end;
$$;

reset role;

delete from public.visits
where id = (select id from alpha_integrity_state where key = 'retention_visit');

do $$
declare
  expected_target uuid := (
    select id from alpha_integrity_state where key = 'retention_visit'
  );
begin
  if not exists (
    select 1
    from public.reports report
    where report.client_report_id = 'a1100000-0000-4000-8000-000000000001'::uuid
      and report.target_kind = 'visit'
      and report.target_id = expected_target
      and report.target_visit_id is null
      and report.target_snapshot->>'id' = expected_target::text
      and report.target_snapshot->>'caption' = 'Durable report target'
  ) then
    raise exception 'report evidence did not survive target deletion';
  end if;

  begin
    update public.reports
    set target_snapshot = '{}'::jsonb
    where client_report_id = 'a1100000-0000-4000-8000-000000000001'::uuid;
    raise exception 'immutable report evidence was updated';
  exception when sqlstate '55000' then
    null;
  end;
end;
$$;

insert into private.moderation_operators (user_id, role, appointed_by)
values (
  (select id from alpha_integrity_users where n = 3),
  'admin',
  (select id from alpha_integrity_users where n = 3)
)
on conflict (user_id) do update
set role = 'admin', is_active = true, updated_at = now();

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

insert into alpha_integrity_state (key, id)
select 'suspension_report', (
  public.submit_report_v2(
    'a1100000-0000-4000-8000-000000000007'::uuid,
    'impersonation'::public.report_reason,
    'user',
    (select id from alpha_integrity_users where n = 1),
    'Suspension visibility contract test'
  )
).id;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

select public.review_report_v1(
  (select id from alpha_integrity_state where key = 'suspension_report'),
  'resolved'::public.report_status,
  'account_suspended',
  'Suspension projection check',
  'account_suspended',
  null,
  null,
  null
);

reset role;

insert into alpha_integrity_state (key, id)
select 'suspension_action', action.id
from private.moderation_actions action
where action.report_id = (
  select id from alpha_integrity_state where key = 'suspension_report'
)
order by action.created_at desc, action.id desc
limit 1;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare
  suspended_user uuid := (select id from alpha_integrity_users where n = 1);
  suspended_username text := (select username from alpha_integrity_users where n = 1);
begin
  if public.can_view_user(
    suspended_user,
    (select id from alpha_integrity_users where n = 2)
  ) then
    raise exception 'suspended profile remained directly visible';
  end if;
  if exists (
    select 1 from public.search_users(suspended_username, 20)
    where id = suspended_user
  ) then
    raise exception 'suspended profile leaked through user search';
  end if;
  if public.can_view_visit(
    (select id from alpha_integrity_state where key = 'moderation_visit'),
    (select id from alpha_integrity_users where n = 2)
  ) then
    raise exception 'suspended account content remained visible';
  end if;
  begin
    perform public.get_public_profile(suspended_user);
    raise exception 'suspended profile leaked through profile projection';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform public.submit_report_v2(
      'a1100000-0000-4000-8000-000000000008'::uuid,
      'impersonation'::public.report_reason,
      'user',
      suspended_user,
      'Suspended identity probe'
    );
    raise exception 'suspended user remained reportable by raw identifier';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

select public.revoke_moderation_action_v1(
  (select id from alpha_integrity_state where key = 'suspension_action'),
  'Suspension contract rollback'
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not public.can_view_user(
    (select id from alpha_integrity_users where n = 1),
    (select id from alpha_integrity_users where n = 2)
  ) then
    raise exception 'revoked account suspension remained enforced';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Moderation is operator-bound, audited, enforceable, and reversible.
-- ---------------------------------------------------------------------------

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

insert into alpha_integrity_state (key, id)
select 'moderation_report', (
  public.submit_report_v2(
    'a1100000-0000-4000-8000-000000000003'::uuid,
    'inappropriate_content'::public.report_reason,
    'visit',
    (select id from alpha_integrity_state where key = 'moderation_visit'),
    'Moderation contract test'
  )
).id;

do $$
begin
  begin
    perform public.review_report_v1(
      (select id from alpha_integrity_state where key = 'moderation_report'),
      'resolved'::public.report_status,
      'policy_violation'
    );
    raise exception 'non-operator reviewed a report';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;

insert into private.moderation_operators (user_id, role, appointed_by)
values (
  (select id from alpha_integrity_users where n = 3),
  'admin',
  (select id from alpha_integrity_users where n = 3)
)
on conflict (user_id) do update
set role = 'admin', is_active = true, updated_at = now();

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

select public.review_report_v1(
  (select id from alpha_integrity_state where key = 'moderation_report'),
  'resolved'::public.report_status,
  'policy_violation',
  'Focused local contract test',
  'content_hidden',
  null,
  null,
  null
);

reset role;

insert into alpha_integrity_state (key, id)
select 'moderation_action', action.id
from private.moderation_actions action
where action.report_id = (
  select id from alpha_integrity_state where key = 'moderation_report'
)
order by action.created_at desc, action.id desc
limit 1;

do $$
begin
  if not exists (
    select 1 from private.moderation_case_events event
    where event.report_id = (
      select id from alpha_integrity_state where key = 'moderation_report'
    )
      and event.event_kind = 'report_resolved'
  ) or not exists (
    select 1 from private.moderation_case_events event
    where event.report_id = (
      select id from alpha_integrity_state where key = 'moderation_report'
    )
      and event.event_kind = 'action_applied'
  ) then
    raise exception 'moderation review did not create a complete audit trail';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if public.can_view_visit(
    (select id from alpha_integrity_state where key = 'moderation_visit'),
    (select id from alpha_integrity_users where n = 2)
  ) then
    raise exception 'moderated visit remained visible to another user';
  end if;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

select public.revoke_moderation_action_v1(
  (select id from alpha_integrity_state where key = 'moderation_action'),
  'Contract rollback check'
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not public.can_view_visit(
    (select id from alpha_integrity_state where key = 'moderation_visit'),
    (select id from alpha_integrity_users where n = 2)
  ) then
    raise exception 'revoked moderation action remained enforced';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Comment edits are author-only; removal is available to the author or post
-- owner and hides the root plus its one-level replies.
-- ---------------------------------------------------------------------------

insert into alpha_integrity_state (key, id)
select 'owned_comment', (
  public.create_comment(
    (select id from alpha_integrity_state where key = 'comment_visit'),
    'Original comment text',
    null,
    '{}'::uuid[]
  )
).id;

select public.update_comment_v1(
  (select id from alpha_integrity_state where key = 'owned_comment'),
  'Edited comment text'
);

do $$
begin
  begin
    update public.comments
    set text = 'Bypassed ownership'
    where id = (select id from alpha_integrity_state where key = 'owned_comment');
    raise exception 'direct comment update unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

insert into alpha_integrity_state (key, id)
select 'owned_reply', (
  public.create_comment(
    (select id from alpha_integrity_state where key = 'comment_visit'),
    'One-level reply',
    (select id from alpha_integrity_state where key = 'owned_comment'),
    '{}'::uuid[]
  )
).id;

do $$
begin
  begin
    perform public.remove_comment_v1(
      (select id from alpha_integrity_state where key = 'owned_comment'),
      'stranger_attempt'
    );
    raise exception 'stranger removed another person comment';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);

select public.remove_comment_v1(
  (select id from alpha_integrity_state where key = 'owned_comment'),
  'post_owner_removed'
);

reset role;

do $$
begin
  if (
    select count(*)
    from public.comments comment
    where comment.id in (
      (select id from alpha_integrity_state where key = 'owned_comment'),
      (select id from alpha_integrity_state where key = 'owned_reply')
    )
      and comment.removed_at is not null
      and comment.removal_reason = 'post_owner_removed'
  ) <> 2 then
    raise exception 'comment removal did not redact the complete one-level thread';
  end if;
  if not exists (
    select 1 from public.comments comment
    where comment.id = (select id from alpha_integrity_state where key = 'owned_comment')
      and comment.text = 'Edited comment text'
  ) or not exists (
    select 1 from public.comments comment
    where comment.id = (select id from alpha_integrity_state where key = 'owned_reply')
      and comment.text = 'One-level reply'
  ) then
    raise exception 'comment tombstone destroyed stored audit text';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if exists (
    select 1 from public.comments comment
    where comment.id = (select id from alpha_integrity_state where key = 'owned_comment')
  ) then
    raise exception 'tombstoned comment remained visible to its former author';
  end if;
  begin
    perform public.submit_report_v2(
      'a1100000-0000-4000-8000-000000000005'::uuid,
      'harassment'::public.report_reason,
      'comment',
      (select id from alpha_integrity_state where key = 'owned_comment'),
      'Removed comment must not be reportable through an ID probe'
    );
    raise exception 'removed comment remained reportable by raw identifier';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;

-- ---------------------------------------------------------------------------
-- Blocking severs current pairwise edges while preserving reports and accepted
-- shared-memory ownership. Pending shared invitations are cancelled.
-- ---------------------------------------------------------------------------

insert into public.friends (user_id, friend_user_id)
values
  (
    (select id from alpha_integrity_users where n = 1),
    (select id from alpha_integrity_users where n = 2)
  ),
  (
    (select id from alpha_integrity_users where n = 2),
    (select id from alpha_integrity_users where n = 1)
  )
on conflict do nothing;

insert into public.likes (user_id, visit_id)
values (
  (select id from alpha_integrity_users where n = 2),
  (select id from alpha_integrity_state where key = 'block_visit')
)
on conflict do nothing;

insert into public.visit_reactions (visit_id, user_id, reaction)
values (
  (select id from alpha_integrity_state where key = 'block_visit'),
  (select id from alpha_integrity_users where n = 2),
  'great_find'
)
on conflict (visit_id, user_id) do update set reaction = excluded.reaction;

insert into public.visit_companions (visit_id, companion_user_id, added_by)
values (
  (select id from alpha_integrity_state where key = 'block_visit'),
  (select id from alpha_integrity_users where n = 2),
  (select id from alpha_integrity_users where n = 1)
)
on conflict (visit_id, companion_user_id) do update set added_by = excluded.added_by;

insert into public.trusted_recommendations (
  sender_id, recipient_id, target_kind, target_cafe_id, note
)
values (
  (select id from alpha_integrity_users where n = 1),
  (select id from alpha_integrity_users where n = 2),
  'cafe',
  (select id from public.cafes order by id limit 1),
  'Block coherence recommendation'
);

insert into public.cafe_lists (owner_id, title, visibility)
select
  (select id from alpha_integrity_users where n = 1),
  'Block coherence list',
  'invited'
where not exists (
  select 1
  from public.cafe_lists existing_list
  where existing_list.owner_id = (
    select id from alpha_integrity_users where n = 1
  )
    and existing_list.system_kind is null
)
returning id;

insert into alpha_integrity_state (key, id)
select 'block_list', list.id
from public.cafe_lists list
where list.owner_id = (select id from alpha_integrity_users where n = 1)
  and list.system_kind is null
order by list.created_at desc, list.id desc
limit 1;

insert into public.cafe_list_members (
  list_id, user_id, role, invitation_status, invited_by, accepted_at
)
values (
  (select id from alpha_integrity_state where key = 'block_list'),
  (select id from alpha_integrity_users where n = 2),
  'editor', 'accepted',
  (select id from alpha_integrity_users where n = 1),
  now()
)
on conflict (list_id, user_id) do update
set role = 'editor', invitation_status = 'accepted',
    invited_by = excluded.invited_by, accepted_at = now();

insert into public.cafe_list_items (
  list_id, cafe_id, contributor_id, note
)
values (
  (select id from alpha_integrity_state where key = 'block_list'),
  (select id from public.cafes order by id limit 1),
  (select id from alpha_integrity_users where n = 2),
  'Blocked collaborator contribution'
)
on conflict (list_id, cafe_id) do update
set contributor_id = excluded.contributor_id,
    note = excluded.note;

insert into public.shared_memories (
  created_by, source_visit_id, context_type, cafe_id,
  location_label, occurred_at
)
values (
  (select id from alpha_integrity_users where n = 1),
  (select id from alpha_integrity_state where key = 'block_visit'),
  'Cafe',
  (select id from public.cafes order by id limit 1),
  'Block coherence cafe',
  now()
)
returning id;

insert into alpha_integrity_state (key, id)
select 'shared_memory', memory.id
from public.shared_memories memory
where memory.source_visit_id = (
  select id from alpha_integrity_state where key = 'block_visit'
);

insert into public.shared_memory_members (
  shared_memory_id, user_id, invited_by, status
)
values (
  (select id from alpha_integrity_state where key = 'shared_memory'),
  (select id from alpha_integrity_users where n = 2),
  (select id from alpha_integrity_users where n = 1),
  'pending'
);

with accepted_memory as (
  insert into public.shared_memories (
    created_by, source_visit_id, context_type, cafe_id,
    location_label, occurred_at
  ) values (
    (select id from alpha_integrity_users where n = 1),
    null,
    'Cafe',
    (select id from public.cafes order by id limit 1),
    'Accepted block coherence cafe',
    now()
  )
  returning id
)
insert into alpha_integrity_state (key, id)
select 'accepted_shared_memory', id from accepted_memory;

insert into public.shared_memory_members (
  shared_memory_id, user_id, invited_by, status, responded_at
)
values
(
  (select id from alpha_integrity_state where key = 'accepted_shared_memory'),
  (select id from alpha_integrity_users where n = 2),
  (select id from alpha_integrity_users where n = 1),
  'accepted', now()
),
(
  (select id from alpha_integrity_state where key = 'accepted_shared_memory'),
  (select id from alpha_integrity_users where n = 3),
  (select id from alpha_integrity_users where n = 1),
  'accepted', now()
);

select set_config('request.jwt.claims', '{}'::jsonb::text, true);

with source_identity as (
  insert into public.recipe_identities (user_id, name)
  values (
    (select id from alpha_integrity_users where n = 2),
    'Blocked source recipe'
  )
  returning id
)
insert into alpha_integrity_state (key, id)
select 'blocked_source_recipe_identity', id from source_identity;

with source_version as (
  insert into public.recipe_versions (
    recipe_identity_id, version_number, brew_details,
    visibility, source_kind, redistribution_allowed,
    public_reuse_acknowledged_at
  ) values (
    (select id from alpha_integrity_state where key = 'blocked_source_recipe_identity'),
    1, '{}'::jsonb, 'everyone', 'original', true, now()
  )
  returning id
)
insert into alpha_integrity_state (key, id)
select 'blocked_source_recipe_version', id from source_version;

with saved_identity as (
  insert into public.recipe_identities (user_id, name)
  values (
    (select id from alpha_integrity_users where n = 1),
    'Saved adaptation from blocked account'
  )
  returning id
)
insert into alpha_integrity_state (key, id)
select 'saved_blocked_recipe_identity', id from saved_identity;

insert into public.recipe_versions (
  recipe_identity_id, version_number, brew_details,
  visibility, source_kind, redistribution_allowed,
  source_recipe_version_id
)
values (
  (select id from alpha_integrity_state where key = 'saved_blocked_recipe_identity'),
  1, '{}'::jsonb, 'private', 'adapted', false,
  (select id from alpha_integrity_state where key = 'blocked_source_recipe_version')
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

insert into alpha_integrity_state (key, id)
select 'block_comment', (
  public.create_comment(
    (select id from alpha_integrity_state where key = 'block_visit'),
    'Interaction removed by block',
    null,
    array[(select id from alpha_integrity_users where n = 1)]::uuid[]
  )
).id;

select public.submit_report_v2(
  'a1100000-0000-4000-8000-000000000004'::uuid,
  'harassment'::public.report_reason,
  'user',
  (select id from alpha_integrity_users where n = 1),
  'Report must outlive a later block'
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);

select public.block_user_v2(
  (select id from alpha_integrity_users where n = 2)
);

reset role;

do $$
declare
  first_user uuid := (select id from alpha_integrity_users where n = 1);
  second_user uuid := (select id from alpha_integrity_users where n = 2);
  block_visit uuid := (select id from alpha_integrity_state where key = 'block_visit');
  block_list uuid := (select id from alpha_integrity_state where key = 'block_list');
begin
  if not exists (
    select 1 from public.user_blocks block
    where block.blocker_id = first_user and block.blocked_id = second_user
  ) then raise exception 'block row was not created'; end if;
  if exists (
    select 1 from public.friends friendship
    where friendship.user_id in (first_user, second_user)
      and friendship.friend_user_id in (first_user, second_user)
  ) then raise exception 'block preserved friendship edges'; end if;
  if exists (
    select 1 from public.likes like_row
    where like_row.visit_id = block_visit and like_row.user_id = second_user
  ) then raise exception 'block preserved a cross-pair like'; end if;
  if exists (
    select 1 from public.visit_reactions reaction
    where reaction.visit_id = block_visit and reaction.user_id = second_user
  ) then raise exception 'block preserved a cross-pair reaction'; end if;
  if exists (
    select 1 from public.visit_companions companion
    where companion.visit_id = block_visit
      and companion.companion_user_id = second_user
  ) then raise exception 'block preserved an ordinary tag'; end if;
  if exists (
    select 1 from public.trusted_recommendations recommendation
    where recommendation.sender_id in (first_user, second_user)
      and recommendation.recipient_id in (first_user, second_user)
  ) then raise exception 'block preserved a trusted recommendation'; end if;
  if exists (
    select 1 from public.cafe_list_members member
    where member.list_id = block_list and member.user_id = second_user
  ) then raise exception 'block preserved a collaborative-list membership'; end if;
  if not exists (
    select 1 from public.cafe_list_items item
    where item.list_id = block_list and item.contributor_id = second_user
  ) then raise exception 'block destroyed a durable collaborator cafe contribution'; end if;
  if not exists (
    select 1 from public.comments comment
    where comment.id = (select id from alpha_integrity_state where key = 'block_comment')
      and comment.removed_at is not null
      and comment.removal_reason = 'relationship_blocked'
      and comment.text = 'Interaction removed by block'
  ) then raise exception 'block did not redact pairwise comments'; end if;
  if not exists (
    select 1 from public.shared_memory_members member
    where member.shared_memory_id = (
      select id from alpha_integrity_state where key = 'shared_memory'
    )
      and member.user_id = second_user
      and member.status = 'cancelled'
  ) then raise exception 'block did not cancel a pending shared invitation'; end if;
  if not exists (
    select 1 from public.shared_memories memory
    where memory.id = (
      select id from alpha_integrity_state where key = 'accepted_shared_memory'
    )
  ) then raise exception 'block deleted an accepted shared MugShot grouping'; end if;
  if not exists (
    select 1 from public.shared_memory_members member
    where member.shared_memory_id = (
      select id from alpha_integrity_state where key = 'accepted_shared_memory'
    )
      and member.user_id = second_user
      and member.status = 'left'
  ) then raise exception 'block preserved blocked accepted shared presentation'; end if;
  if not exists (
    select 1 from public.shared_memory_members member
    where member.shared_memory_id = (
      select id from alpha_integrity_state where key = 'accepted_shared_memory'
    )
      and member.user_id = (select id from alpha_integrity_users where n = 3)
      and member.status = 'accepted'
  ) then raise exception 'block detached an unrelated shared MugShot participant'; end if;
  if not exists (
    select 1 from public.recipe_identities identity
    where identity.id = (
      select id from alpha_integrity_state where key = 'saved_blocked_recipe_identity'
    )
  ) then raise exception 'default block removed a saved recipe copy without consent'; end if;
  if not exists (
    select 1 from public.reports report
    where report.client_report_id = 'a1100000-0000-4000-8000-000000000004'::uuid
      and report.reporter_subject_id = second_user
  ) then raise exception 'block destroyed retained report evidence'; end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);

select public.block_user_v2(
  (select id from alpha_integrity_users where n = 2),
  true
);

reset role;

do $$
begin
  if exists (
    select 1 from public.recipe_identities identity
    where identity.id = (
      select id from alpha_integrity_state where key = 'saved_blocked_recipe_identity'
    )
  ) then
    raise exception 'explicit block choice did not remove saved recipe copy';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.submit_report_v2(
      'a1100000-0000-4000-8000-000000000006'::uuid,
      'harassment'::public.report_reason,
      'user',
      (select id from alpha_integrity_users where n = 1),
      'Blocked identity probe'
    );
    raise exception 'blocked user remained reportable by raw identifier';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_integrity_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if exists (
    select 1 from public.comments comment
    where comment.id = (select id from alpha_integrity_state where key = 'block_comment')
  ) then
    raise exception 'removed block interaction remained visible to a third party';
  end if;
end;
$$;

reset role;
rollback;

select 'alpha_social_integrity_contract_passed' as result;
