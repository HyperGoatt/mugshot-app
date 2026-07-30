\set ON_ERROR_STOP on

begin;

create temp table alpha_hardening_users as
select id, row_number() over (order by id) n
from (select id from public.users order by id limit 3) users;

create temp table alpha_hardening_state (
  key text primary key,
  id uuid not null
);

grant select on alpha_hardening_users to authenticated;
grant all on alpha_hardening_state to authenticated;

do $$
begin
  if (select count(*) from alpha_hardening_users) < 3 then
    raise exception 'moderation hardening requires three local fixture users';
  end if;
end;
$$;

insert into private.moderation_operators (user_id, role, appointed_by)
values (
  (select id from alpha_hardening_users where n = 3),
  'admin',
  (select id from alpha_hardening_users where n = 3)
)
on conflict (user_id) do update set role = 'admin', is_active = true;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_hardening_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

insert into alpha_hardening_state (key, id)
select 'primary_report', (
  public.submit_report_v2(
    'aa000000-0000-4000-8000-000000000001'::uuid,
    'harassment'::public.report_reason,
    'user',
    (select id from alpha_hardening_users where n = 1),
    'Original report evidence'
  )
).id;

-- A different client request for the same unresolved target collapses and gets
-- its own durable idempotency alias.
do $$
declare receipt public.report_submission_receipt_v1;
begin
  receipt := public.submit_report_v2(
    'aa000000-0000-4000-8000-000000000002'::uuid,
    'privacy'::public.report_reason,
    'user',
    (select id from alpha_hardening_users where n = 1),
    'Collapsed duplicate evidence'
  );
  if receipt.id <> (select id from alpha_hardening_state where key = 'primary_report') then
    raise exception 'repeated target did not collapse';
  end if;
end;
$$;

-- Close the case, then prove the collapsed client ID still resolves to the
-- original allowlisted receipt instead of creating a new report.
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_hardening_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

select public.review_report_v1(
  (select id from alpha_hardening_state where key = 'primary_report'),
  'resolved'::public.report_status,
  'private_operator_resolution',
  'private operator note',
  null, null, null, null
);

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_hardening_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare payload jsonb;
begin
  payload := to_jsonb(public.submit_report_v2(
    'aa000000-0000-4000-8000-000000000002'::uuid,
    'privacy'::public.report_reason,
    'user',
    (select id from alpha_hardening_users where n = 1),
    'Collapsed duplicate evidence'
  ));

  if payload->>'id' <>
       (select id::text from alpha_hardening_state where key = 'primary_report')
     or payload->>'status' <> 'resolved'
     or payload->>'resolution_code' <> 'review_complete'
     or payload ?| array[
       'reviewed_by', 'reviewed_at', 'details', 'target_snapshot',
       'reporter_id', 'reporter_subject_id'
     ] then
    raise exception 'closed idempotent replay leaked or changed its report';
  end if;
end;
$$;

-- A JWT subject with no live Auth row cannot use central social/view helpers.
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', 'aa000000-0000-4000-8000-000000000099'::uuid,
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare stale uuid := 'aa000000-0000-4000-8000-000000000099'::uuid;
begin
  if public.can_socially_mutate(stale)
     or public.can_view_user(
       (select id from alpha_hardening_users where n = 1), stale
     ) then
    raise exception 'stale deleted-account identity remained authorized';
  end if;
end;
$$;

reset role;

-- Fill the hourly quota with closed synthetic cases. They preserve report
-- evidence invariants but do not require user-data deletion or mutation.
do $$
declare
  reporter uuid := (select id from alpha_hardening_users where n = 2);
  current_count integer;
  i integer;
  synthetic_target uuid;
begin
  select count(*) into current_count
  from public.reports report
  where report.reporter_subject_id = reporter
    and report.created_at > now() - interval '1 hour';

  for i in 1..greatest(20 - current_count, 0) loop
    synthetic_target := (
      lpad(to_hex(4096 + i), 8, '0') || '-0000-4000-8000-' ||
      lpad(to_hex(8192 + i), 12, '0')
    )::uuid;
    insert into public.reports (
      reporter_id, reporter_subject_id, target_kind, target_id,
      target_snapshot, reason, status, closed_at, resolution_code
    ) values (
      reporter, reporter, 'user', synthetic_target,
      jsonb_build_object('kind', 'user', 'id', synthetic_target),
      'spam', 'dismissed', now(), 'quota_fixture'
    );
  end loop;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_hardening_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.submit_report(
      'spam'::public.report_reason,
      'Legacy endpoint quota check',
      (select id from alpha_hardening_users where n = 3),
      null,
      null
    );
    raise exception 'legacy report endpoint bypassed quota';
  exception when sqlstate 'P0001' then
    null;
  end;

  -- Exact aliases reconcile before quota checks.
  if (public.submit_report_v2(
      'aa000000-0000-4000-8000-000000000002'::uuid,
      'privacy'::public.report_reason,
      'user',
      (select id from alpha_hardening_users where n = 1),
      'Collapsed duplicate evidence'
    )).id <> (select id from alpha_hardening_state where key = 'primary_report') then
    raise exception 'exact retry consumed or failed the quota';
  end if;
end;
$$;

reset role;

-- An enforcement action linked to a report may target only the reported object
-- or its server-derived owner.
create temp table alpha_unrelated_report (id uuid primary key);

with inserted as (
  insert into public.reports (
    reporter_id, reporter_subject_id, target_kind, target_id, target_user_id,
    target_snapshot, reason
  )
  select
    reporter.id, reporter.id, 'user', target.id, target.id,
    jsonb_build_object('kind', 'user', 'id', target.id), 'harassment'
  from (select id from alpha_hardening_users where n = 2) reporter,
       (select id from alpha_hardening_users where n = 1) target
  returning id
)
insert into alpha_unrelated_report select id from inserted;

grant select on alpha_unrelated_report to authenticated;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_hardening_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.review_report_v1(
      (select id from alpha_unrelated_report),
      'resolved'::public.report_status,
      'confirmed', null,
      'account_suspended', 'user',
      (select id from alpha_hardening_users where n = 2),
      now() + interval '1 day'
    );
    raise exception 'report applied enforcement to an unrelated subject';
  exception when sqlstate '42501' then
    null;
  end;

end;
$$;

reset role;

-- Reviewers may uphold an appeal, but only admins may modify or reverse the
-- underlying enforcement decision.
insert into private.moderation_operators (user_id, role, appointed_by)
values (
  (select id from alpha_hardening_users where n = 2),
  'reviewer',
  (select id from alpha_hardening_users where n = 3)
)
on conflict (user_id) do update set role = 'reviewer', is_active = true;

create temp table alpha_role_appeals (key text primary key, id uuid not null);
grant select on alpha_role_appeals to authenticated;

with action as (
  insert into private.moderation_actions (
    subject_kind, subject_id, action_kind, reason_code, ends_at
  ) values (
    'user', (select id from alpha_hardening_users where n = 1),
    'warning', 'role_test', now() + interval '7 days'
  ) returning id
), appeal as (
  insert into private.moderation_appeals (
    action_id, appellant_id, client_appeal_id, statement
  )
  select id, (select id from alpha_hardening_users where n = 1),
    'aa000000-0000-4000-8000-000000000010'::uuid,
    'This appeal exists to verify reviewer and administrator boundaries.'
  from action
  returning id
)
insert into alpha_role_appeals select 'reviewer_case', id from appeal;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_hardening_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.review_moderation_appeal_v1(
      (select id from alpha_role_appeals where key = 'reviewer_case'),
      'reversed', 'Reviewer must not reverse this action.', null, null
    );
    raise exception 'reviewer reversed an enforcement action';
  exception when sqlstate '42501' then
    null;
  end;
end;
$$;

select public.review_moderation_appeal_v1(
  (select id from alpha_role_appeals where key = 'reviewer_case'),
  'upheld', 'The original decision remains in place.', null, null
);

reset role;

with action as (
  insert into private.moderation_actions (
    subject_kind, subject_id, action_kind, reason_code, ends_at
  ) values (
    'user', (select id from alpha_hardening_users where n = 1),
    'warning', 'role_test_admin', now() + interval '7 days'
  ) returning id
), appeal as (
  insert into private.moderation_appeals (
    action_id, appellant_id, client_appeal_id, statement
  )
  select id, (select id from alpha_hardening_users where n = 1),
    'aa000000-0000-4000-8000-000000000011'::uuid,
    'This second appeal exists to verify administrator reversal authority.'
  from action
  returning id
)
insert into alpha_role_appeals select 'admin_case', id from appeal;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_hardening_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

select public.review_moderation_appeal_v1(
  (select id from alpha_role_appeals where key = 'admin_case'),
  'reversed', 'An administrator reversed this decision.', null, null
);

reset role;

-- Block serialization triggers reject representative post-block writes.
insert into public.user_blocks (blocker_id, blocked_id)
select
  (select id from alpha_hardening_users where n = 2),
  (select id from alpha_hardening_users where n = 1)
on conflict do nothing;

do $$
begin
  begin
    insert into public.friend_requests (from_user_id, to_user_id, status)
    values (
      (select id from alpha_hardening_users where n = 2),
      (select id from alpha_hardening_users where n = 1),
      'pending'
    );
    raise exception 'post-block friend request was inserted';
  exception when sqlstate '42501' then
    null;
  end;
end;
$$;

-- A restricted participant cannot attach, but this migration does not wrap or
-- remove decline, cancel, or leave RPCs.
insert into private.moderation_actions (
  subject_kind, subject_id, action_kind, reason_code, starts_at
)
values (
  'user', (select id from alpha_hardening_users where n = 2),
  'social_restricted', 'alpha_test', now()
);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_hardening_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.attach_shared_memory_contribution_v1(
      gen_random_uuid(), gen_random_uuid()
    );
    raise exception 'restricted participant reached shared attachment mutation';
  exception when sqlstate '42501' then
    null;
  end;
end;
$$;

rollback;

select 'alpha_moderation_integrity_hardening_contract_passed' as result;
