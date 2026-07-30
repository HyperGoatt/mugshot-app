\set ON_ERROR_STOP on

begin;

-- Transaction-isolated enforcement and appeal behavior. This requires three
-- local fixture users and rolls every report, action, and appeal back.
create temp table alpha_enforcement_users as
select id, row_number() over (order by id) n
from (
  select id
  from public.users
  order by id
  limit 3
) users;

create temp table alpha_enforcement_state (
  key text primary key,
  id uuid not null
);

grant select on alpha_enforcement_users to authenticated;
grant all on alpha_enforcement_state to authenticated;

do $$
begin
  if (select count(*) from alpha_enforcement_users) < 3 then
    raise exception 'alpha enforcement suite requires three local fixture users';
  end if;
end;
$$;

delete from private.moderation_operators operator
where operator.user_id = (select id from alpha_enforcement_users where n = 3);

insert into private.moderation_operators (user_id, role, appointed_by)
values (
  (select id from alpha_enforcement_users where n = 3),
  'admin',
  (select id from alpha_enforcement_users where n = 3)
);

-- User 2 submits a report about user 1.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_enforcement_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

insert into alpha_enforcement_state (key, id)
select 'report', (
  public.submit_report_v2(
    'ae000000-0000-4000-8000-000000000001'::uuid,
    'harassment'::public.report_reason,
    'user',
    (select id from alpha_enforcement_users where n = 1),
    'Alpha enforcement transparency contract'
  )
).id;

do $$
begin
  if (
    select count(*)
    from public.list_my_report_receipts_v1(50, null, null) receipt
    where receipt.report_id = (
      select id from alpha_enforcement_state where key = 'report'
    )
      and receipt.status = 'pending'
      and receipt.target_kind = 'user'
  ) <> 1 then
    raise exception 'reporter safe receipt projection is missing';
  end if;
end;
$$;

-- User 3 resolves the report and applies an account suspension to user 1.
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_enforcement_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

select public.review_report_v1(
  p_report_id => (select id from alpha_enforcement_state where key = 'report'),
  p_new_status => 'resolved'::public.report_status,
  p_resolution_code => 'harassment',
  p_internal_note => 'This private reviewer note must never enter a client projection.',
  p_action_kind => 'account_suspended',
  p_action_subject_kind => 'user',
  p_action_subject_id => (select id from alpha_enforcement_users where n = 1),
  p_action_ends_at => now() + interval '7 days'
);

reset role;

insert into alpha_enforcement_state (key, id)
select 'action', action.id
from private.moderation_actions action
where action.report_id = (select id from alpha_enforcement_state where key = 'report')
  and action.action_kind = 'account_suspended'
order by action.created_at desc, action.id desc
limit 1;

do $$
begin
  if not exists (
    select 1
    from private.moderation_actions action
    where action.id = (select id from alpha_enforcement_state where key = 'action')
      and action.subject_owner_id = (
        select id from alpha_enforcement_users where n = 1
      )
  ) then
    raise exception 'enforcement action did not preserve its affected owner';
  end if;
end;
$$;

-- The affected user can see the safe decision and can appeal even while the
-- social layer is suspended.
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_enforcement_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not exists (
    select 1
    from public.get_my_enforcement_state_v1() state
    where state.action_id = (
      select id from alpha_enforcement_state where key = 'action'
    )
      and state.action_kind = 'account_suspended'
      and state.subject_kind = 'user'
      and state.reason_code = 'harassment'
      and state.is_active
      and state.appeal_eligible
      and state.appeal_id is null
  ) then
    raise exception 'affected user cannot see the safe enforcement summary';
  end if;
end;
$$;

insert into alpha_enforcement_state (key, id)
select 'appeal', receipt.appeal_id
from public.submit_moderation_appeal_v1(
  (select id from alpha_enforcement_state where key = 'action'),
  'ae000000-0000-4000-8000-000000000002'::uuid,
  'This decision missed important context from the conversation.'
) receipt;

-- An exact retry returns the same durable appeal.
select public.submit_moderation_appeal_v1(
  (select id from alpha_enforcement_state where key = 'action'),
  'ae000000-0000-4000-8000-000000000002'::uuid,
  'This decision missed important context from the conversation.'
);

do $$
begin
  if (
    select count(*)
    from public.get_my_enforcement_state_v1() state
    where state.action_id = (
      select id from alpha_enforcement_state where key = 'action'
    )
      and state.appeal_id = (
        select id from alpha_enforcement_state where key = 'appeal'
      )
  ) <> 1 then
    raise exception 'exact appeal retry created a duplicate';
  end if;

  begin
    perform public.submit_moderation_appeal_v1(
      (select id from alpha_enforcement_state where key = 'action'),
      'ae000000-0000-4000-8000-000000000002'::uuid,
      'The same client id must not accept different appeal evidence.'
    );
    raise exception 'client appeal id accepted different evidence';
  exception when sqlstate '22023' then
    null;
  end;

  begin
    perform public.submit_moderation_appeal_v1(
      (select id from alpha_enforcement_state where key = 'action'),
      'ae000000-0000-4000-8000-000000000003'::uuid,
      'A second appeal for the same action should not be created.'
    );
    raise exception 'one action accepted a second appeal';
  exception when sqlstate '55000' then
    null;
  end;
end;
$$;

-- Another user cannot see or appeal user 1's action.
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_enforcement_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if exists (
    select 1
    from public.get_my_enforcement_state_v1() state
    where state.action_id = (
      select id from alpha_enforcement_state where key = 'action'
    )
  ) then
    raise exception 'enforcement summary leaked to another user';
  end if;

  begin
    perform public.submit_moderation_appeal_v1(
      (select id from alpha_enforcement_state where key = 'action'),
      'ae000000-0000-4000-8000-000000000004'::uuid,
      'Another user must not appeal this enforcement action.'
    );
    raise exception 'another user appealed an enforcement action';
  exception when sqlstate '42501' then
    null;
  end;
end;
$$;

-- The moderator reverses the decision with a user-facing explanation. The
-- private note stays only in the private audit event.
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_enforcement_users where n = 3),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.review_moderation_appeal_v1(
      p_appeal_id => (select id from alpha_enforcement_state where key = 'appeal'),
      p_new_status => 'modified',
      p_resolution_summary => 'This invalid modification would extend the decision.',
      p_internal_note => null,
      p_modified_ends_at => now() + interval '30 days'
    );
    raise exception 'appeal review extended an enforcement action';
  exception when sqlstate '22023' then
    null;
  end;
end;
$$;

select public.review_moderation_appeal_v1(
  p_appeal_id => (select id from alpha_enforcement_state where key = 'appeal'),
  p_new_status => 'reversed',
  p_resolution_summary => 'We reviewed the additional context and reversed this decision.',
  p_internal_note => 'Private appeal review note.',
  p_modified_ends_at => null
);

-- User 1 sees only the safe outcome and the action is no longer active.
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_enforcement_users where n = 1),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not exists (
    select 1
    from public.get_my_enforcement_state_v1() state
    where state.action_id = (
      select id from alpha_enforcement_state where key = 'action'
    )
      and not state.is_active
      and state.revoked_at is not null
      and state.appeal_status = 'reversed'
      and state.appeal_resolution_summary =
        'We reviewed the additional context and reversed this decision.'
  ) then
    raise exception 'safe reversed-appeal outcome is missing';
  end if;

  if not (
    public.build_owner_enforcement_export_v1()
      -> 'appeals' @> jsonb_build_array(jsonb_build_object(
        'id', (select id from alpha_enforcement_state where key = 'appeal'),
        'statement', 'This decision missed important context from the conversation.',
        'status', 'reversed'
      ))
  ) then
    raise exception 'owner export omitted the caller’s appeal evidence';
  end if;

  if public.build_owner_enforcement_export_v1()::text ilike '%private appeal review note%'
     or public.build_owner_enforcement_export_v1()::text ilike '%reviewed_by%'
     or public.build_owner_enforcement_export_v1()::text ilike '%internal_note%'
     or public.build_owner_enforcement_export_v1()::text ilike '%subject_owner_id%' then
    raise exception 'owner export leaked private moderation metadata';
  end if;
end;
$$;

-- The reporter receives a review-complete receipt, not the target’s specific
-- enforcement kind or the moderator’s reasoning.
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select id from alpha_enforcement_users where n = 2),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not exists (
    select 1
    from public.get_report_receipt_v1(
      'ae000000-0000-4000-8000-000000000001'::uuid
    ) receipt
    where receipt.status = 'resolved'
      and receipt.resolution_code = 'review_complete'
  ) then
    raise exception 'reporter did not receive a privacy-safe final receipt';
  end if;

  if exists (
    select 1
    from public.list_my_report_receipts_v1(50, null, null) receipt
    where receipt.report_id = (
      select id from alpha_enforcement_state where key = 'report'
    )
      and receipt.resolution_code in ('harassment', 'account_suspended')
  ) then
    raise exception 'reporter receipt disclosed target enforcement detail';
  end if;
end;
$$;

rollback;

select 'alpha_enforcement_transparency_contract_passed' as result;
