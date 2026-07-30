begin;

-- Alpha enforcement transparency keeps the moderation control plane private
-- while giving an affected person a caller-bound explanation and a durable,
-- idempotent appeal path. Reporter identity, reviewer identity, evidence
-- snapshots, and internal notes never cross these projections.

create table if not exists private.moderation_appeals (
  id uuid primary key default gen_random_uuid(),
  action_id uuid not null references private.moderation_actions(id) on delete restrict,
  appellant_id uuid not null references public.users(id) on delete cascade,
  client_appeal_id uuid not null,
  statement text not null check (char_length(statement) between 10 and 2000),
  status text not null default 'pending' check (
    status in ('pending', 'reviewing', 'upheld', 'modified', 'reversed')
  ),
  resolution_summary text check (
    char_length(coalesce(resolution_summary, '')) <= 1000
  ),
  reviewed_by uuid references public.users(id) on delete set null,
  submitted_at timestamptz not null default now(),
  reviewed_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint moderation_appeals_review_state_check check (
    (status in ('pending', 'reviewing') and reviewed_at is null)
    or (status in ('upheld', 'modified', 'reversed') and reviewed_at is not null)
  ),
  constraint moderation_appeals_resolution_check check (
    status in ('pending', 'reviewing') or nullif(trim(resolution_summary), '') is not null
  )
);

create unique index if not exists moderation_appeals_appellant_client_idx
  on private.moderation_appeals (appellant_id, client_appeal_id);

create unique index if not exists moderation_appeals_appellant_action_idx
  on private.moderation_appeals (appellant_id, action_id);

create index if not exists moderation_appeals_status_submitted_idx
  on private.moderation_appeals (status, submitted_at, id);

create table if not exists private.moderation_appeal_events (
  id uuid primary key default gen_random_uuid(),
  appeal_id uuid not null references private.moderation_appeals(id) on delete cascade,
  actor_user_id uuid references public.users(id) on delete set null,
  event_kind text not null check (
    event_kind in ('submitted', 'review_started', 'upheld', 'modified', 'reversed')
  ),
  from_status text,
  to_status text not null,
  internal_note text check (char_length(coalesce(internal_note, '')) <= 2000),
  created_at timestamptz not null default now()
);

-- Preserve who an enforcement decision belongs to even if the affected post
-- or comment is later deleted. This is private ownership metadata, not a
-- public identity projection. Account deletion nulls the pointer.
alter table private.moderation_actions
  add column if not exists subject_owner_id uuid;

update private.moderation_actions action
set subject_owner_id = case action.subject_kind
  when 'user' then action.subject_id
  when 'visit' then (
    select visit.user_id from public.visits visit where visit.id = action.subject_id
  )
  when 'comment' then (
    select comment.user_id from public.comments comment where comment.id = action.subject_id
  )
end
where action.subject_owner_id is null;

alter table private.moderation_actions
  drop constraint if exists moderation_actions_subject_owner_id_fkey,
  add constraint moderation_actions_subject_owner_id_fkey
    foreign key (subject_owner_id) references public.users(id) on delete set null not valid;

alter table private.moderation_actions
  validate constraint moderation_actions_subject_owner_id_fkey;

create or replace function private.assign_moderation_action_subject_owner()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  resolved_owner uuid;
begin
  resolved_owner := case new.subject_kind
    when 'user' then new.subject_id
    when 'visit' then (
      select visit.user_id from public.visits visit where visit.id = new.subject_id
    )
    when 'comment' then (
      select comment.user_id from public.comments comment where comment.id = new.subject_id
    )
  end;

  if resolved_owner is null then
    raise exception 'moderation subject owner is unavailable' using errcode = 'P0002';
  end if;
  if new.subject_owner_id is not null
     and new.subject_owner_id is distinct from resolved_owner then
    raise exception 'moderation subject owner does not match the subject'
      using errcode = '22023';
  end if;
  new.subject_owner_id := resolved_owner;
  return new;
end;
$$;

drop trigger if exists assign_moderation_action_subject_owner
  on private.moderation_actions;
create trigger assign_moderation_action_subject_owner
before insert or update of subject_kind, subject_id
on private.moderation_actions
for each row execute function private.assign_moderation_action_subject_owner();

revoke all on function private.assign_moderation_action_subject_owner()
  from public, anon, authenticated;

create index if not exists moderation_appeal_events_appeal_created_idx
  on private.moderation_appeal_events (appeal_id, created_at, id);

alter table private.moderation_appeals enable row level security;
alter table private.moderation_appeal_events enable row level security;

revoke all on table private.moderation_appeals
  from public, anon, authenticated;
revoke all on table private.moderation_appeal_events
  from public, anon, authenticated;

create or replace function private.owns_moderation_subject_as(
  p_subject_kind text,
  p_subject_id uuid,
  p_actor uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_actor is not null and case p_subject_kind
    when 'user' then p_subject_id = p_actor
    when 'visit' then exists (
      select 1
      from public.visits visit
      where visit.id = p_subject_id and visit.user_id = p_actor
    )
    when 'comment' then exists (
      select 1
      from public.comments comment
      where comment.id = p_subject_id and comment.user_id = p_actor
    )
    else false
  end;
$$;

revoke all on function private.owns_moderation_subject_as(text,uuid,uuid)
  from public, anon, authenticated;

create or replace function public.get_my_enforcement_state_v1()
returns table (
  action_id uuid,
  action_kind text,
  subject_kind text,
  subject_id uuid,
  reason_code text,
  starts_at timestamptz,
  ends_at timestamptz,
  revoked_at timestamptz,
  is_active boolean,
  appeal_eligible boolean,
  appeal_id uuid,
  appeal_status text,
  appeal_submitted_at timestamptz,
  appeal_reviewed_at timestamptz,
  appeal_resolution_summary text
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (
    select auth.uid() as actor, now() as requested_at
  )
  select
    action.id,
    action.action_kind,
    action.subject_kind,
    action.subject_id,
    action.reason_code,
    action.starts_at,
    action.ends_at,
    action.revoked_at,
    action.revoked_at is null
      and action.starts_at <= input.requested_at
      and (action.ends_at is null or action.ends_at > input.requested_at),
    appeal.id is null
      and action.revoked_at is null
      and (
        action.ends_at is null
        or action.ends_at >= input.requested_at - interval '90 days'
      ),
    appeal.id,
    appeal.status,
    appeal.submitted_at,
    appeal.reviewed_at,
    appeal.resolution_summary
  from private.moderation_actions action
  cross join input
  left join private.moderation_appeals appeal
    on appeal.action_id = action.id
   and appeal.appellant_id = input.actor
  where (
      action.subject_owner_id = input.actor
      or private.owns_moderation_subject_as(
        action.subject_kind, action.subject_id, input.actor
      )
    )
    and (
      action.revoked_at is null
      or action.revoked_at >= input.requested_at - interval '180 days'
      or action.created_at >= input.requested_at - interval '180 days'
    )
  order by
    (action.revoked_at is null
      and action.starts_at <= input.requested_at
      and (action.ends_at is null or action.ends_at > input.requested_at)) desc,
    action.created_at desc,
    action.id desc;
$$;

create or replace function public.submit_moderation_appeal_v1(
  p_action_id uuid,
  p_client_appeal_id uuid,
  p_statement text
)
returns table (
  appeal_id uuid,
  action_id uuid,
  status text,
  submitted_at timestamptz,
  reviewed_at timestamptz,
  resolution_summary text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_statement text := nullif(trim(p_statement), '');
  action private.moderation_actions;
  result private.moderation_appeals;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_action_id is null or p_client_appeal_id is null then
    raise exception 'action and client appeal id are required' using errcode = '22023';
  end if;
  if char_length(coalesce(normalized_statement, '')) not between 10 and 2000 then
    raise exception 'appeal statement must be between 10 and 2000 characters'
      using errcode = '22023';
  end if;

  select * into action
  from private.moderation_actions existing_action
  where existing_action.id = p_action_id;

  if not found
     or not (
       coalesce(action.subject_owner_id = actor, false)
       or private.owns_moderation_subject_as(
         action.subject_kind, action.subject_id, actor
       )
     ) then
    raise exception 'enforcement action unavailable' using errcode = '42501';
  end if;

  select * into result
  from private.moderation_appeals existing_appeal
  where existing_appeal.appellant_id = actor
    and existing_appeal.client_appeal_id = p_client_appeal_id;

  if found then
    if result.action_id is distinct from p_action_id
       or result.statement is distinct from normalized_statement then
      raise exception 'client appeal id was already used for different evidence'
        using errcode = '22023';
    end if;
    return query select result.id, result.action_id, result.status,
      result.submitted_at, result.reviewed_at, result.resolution_summary;
    return;
  end if;

  select * into result
  from private.moderation_appeals existing_appeal
  where existing_appeal.appellant_id = actor
    and existing_appeal.action_id = p_action_id;

  if found then
    if result.statement is distinct from normalized_statement then
      raise exception 'this action already has an appeal' using errcode = '55000';
    end if;
    return query select result.id, result.action_id, result.status,
      result.submitted_at, result.reviewed_at, result.resolution_summary;
    return;
  end if;

  if action.revoked_at is not null
     or (
       action.ends_at is not null
       and action.ends_at < now() - interval '90 days'
     ) then
    raise exception 'this action is no longer eligible for appeal' using errcode = '55000';
  end if;

  insert into private.moderation_appeals (
    action_id, appellant_id, client_appeal_id, statement
  ) values (
    p_action_id, actor, p_client_appeal_id, normalized_statement
  )
  on conflict do nothing
  returning * into result;

  if result.id is null then
    select * into result
    from private.moderation_appeals existing_appeal
    where existing_appeal.appellant_id = actor
      and existing_appeal.client_appeal_id = p_client_appeal_id;

    if found then
      if result.action_id is distinct from p_action_id
         or result.statement is distinct from normalized_statement then
        raise exception 'client appeal id was already used for different evidence'
          using errcode = '22023';
      end if;
      return query select result.id, result.action_id, result.status,
        result.submitted_at, result.reviewed_at, result.resolution_summary;
      return;
    end if;

    select * into result
    from private.moderation_appeals existing_appeal
    where existing_appeal.appellant_id = actor
      and existing_appeal.action_id = p_action_id;

    if found then
      if result.statement is distinct from normalized_statement then
        raise exception 'this action already has an appeal' using errcode = '55000';
      end if;
      return query select result.id, result.action_id, result.status,
        result.submitted_at, result.reviewed_at, result.resolution_summary;
      return;
    end if;

    raise exception 'appeal retry could not be reconciled' using errcode = '40001';
  end if;

  insert into private.moderation_appeal_events (
    appeal_id, actor_user_id, event_kind, to_status
  ) values (
    result.id, actor, 'submitted', result.status
  );

  return query select result.id, result.action_id, result.status,
    result.submitted_at, result.reviewed_at, result.resolution_summary;
end;
$$;

-- Keep a reporter informed without disclosing the specific enforcement taken
-- on another person. The signature remains backward compatible; the final
-- resolution value is intentionally generic.
create or replace function public.get_report_receipt_v1(p_client_report_id uuid)
returns table (
  report_id uuid,
  status public.report_status,
  created_at timestamptz,
  closed_at timestamptz,
  resolution_code text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    report.id,
    report.status,
    report.created_at,
    report.closed_at,
    case
      when report.status in ('resolved', 'dismissed') then 'review_complete'
      else null
    end
  from public.reports report
  where report.reporter_subject_id = (select auth.uid())
    and report.client_report_id = p_client_report_id;
$$;

create or replace function public.review_moderation_appeal_v1(
  p_appeal_id uuid,
  p_new_status text,
  p_resolution_summary text default null,
  p_internal_note text default null,
  p_modified_ends_at timestamptz default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  appeal_before private.moderation_appeals;
  appeal_after private.moderation_appeals;
  action private.moderation_actions;
  normalized_summary text := nullif(trim(p_resolution_summary), '');
  normalized_note text := nullif(trim(p_internal_note), '');
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not exists (
    select 1
    from private.moderation_operators operator
    where operator.user_id = actor and operator.is_active
  ) then
    raise exception 'moderation permission required' using errcode = '42501';
  end if;
  if p_new_status not in ('reviewing', 'upheld', 'modified', 'reversed') then
    raise exception 'invalid appeal transition' using errcode = '22023';
  end if;
  if char_length(coalesce(normalized_note, '')) > 2000
     or char_length(coalesce(normalized_summary, '')) > 1000 then
    raise exception 'appeal review text is too long' using errcode = '22023';
  end if;
  if p_new_status in ('upheld', 'modified', 'reversed')
     and normalized_summary is null then
    raise exception 'a user-facing resolution is required' using errcode = '22023';
  end if;

  select * into appeal_before
  from private.moderation_appeals appeal
  where appeal.id = p_appeal_id
  for update;

  if not found then
    raise exception 'appeal unavailable' using errcode = 'P0002';
  end if;
  if appeal_before.appellant_id = actor then
    raise exception 'reviewers cannot review their own appeal' using errcode = '42501';
  end if;
  if appeal_before.status in ('upheld', 'modified', 'reversed') then
    raise exception 'appeal is already closed' using errcode = '55000';
  end if;
  if p_new_status = 'reviewing' and appeal_before.status = 'reviewing' then
    raise exception 'appeal is already under review' using errcode = '55000';
  end if;

  select * into action
  from private.moderation_actions existing_action
  where existing_action.id = appeal_before.action_id
  for update;

  if not found then
    raise exception 'enforcement action unavailable' using errcode = 'P0002';
  end if;

  if p_new_status = 'modified' then
    if p_modified_ends_at is null or p_modified_ends_at <= now() then
      raise exception 'a future end time is required for a modified action'
        using errcode = '22023';
    end if;
    if action.revoked_at is not null then
      raise exception 'a revoked action cannot be modified' using errcode = '55000';
    end if;
    if action.ends_at is not null and p_modified_ends_at >= action.ends_at then
      raise exception 'an appeal modification must shorten the action'
        using errcode = '22023';
    end if;
    update private.moderation_actions existing_action
    set ends_at = p_modified_ends_at
    where existing_action.id = action.id;
  elsif p_new_status = 'reversed' and action.revoked_at is null then
    update private.moderation_actions existing_action
    set revoked_at = now(), revoked_by = actor,
        revocation_reason = left(normalized_summary, 280)
    where existing_action.id = action.id;
  end if;

  update private.moderation_appeals appeal
  set
    status = p_new_status,
    resolution_summary = case
      when p_new_status = 'reviewing' then appeal.resolution_summary
      else normalized_summary
    end,
    reviewed_by = case
      when p_new_status = 'reviewing' then appeal.reviewed_by
      else actor
    end,
    reviewed_at = case
      when p_new_status = 'reviewing' then null
      else now()
    end,
    updated_at = now()
  where appeal.id = appeal_before.id
  returning * into appeal_after;

  insert into private.moderation_appeal_events (
    appeal_id,
    actor_user_id,
    event_kind,
    from_status,
    to_status,
    internal_note
  ) values (
    appeal_after.id,
    actor,
    case p_new_status
      when 'reviewing' then 'review_started'
      when 'upheld' then 'upheld'
      when 'modified' then 'modified'
      else 'reversed'
    end,
    appeal_before.status,
    appeal_after.status,
    normalized_note
  );

  return jsonb_build_object(
    'appeal_id', appeal_after.id,
    'action_id', appeal_after.action_id,
    'status', appeal_after.status,
    'reviewed_at', appeal_after.reviewed_at
  );
end;
$$;

create or replace function public.list_my_report_receipts_v1(
  p_limit integer default 50,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
)
returns table (
  report_id uuid,
  target_kind text,
  target_id uuid,
  reason public.report_reason,
  status public.report_status,
  created_at timestamptz,
  closed_at timestamptz,
  resolution_code text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    report.id,
    report.target_kind,
    report.target_id,
    report.reason,
    report.status,
    report.created_at,
    report.closed_at,
    case
      when report.status in ('resolved', 'dismissed') then 'review_complete'
      else null
    end
  from public.reports report
  where report.reporter_subject_id = (select auth.uid())
    and (
      p_before_created_at is null
      or (report.created_at, report.id) < (p_before_created_at, p_before_id)
    )
  order by report.created_at desc, report.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

create or replace function public.build_owner_enforcement_export_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  return jsonb_build_object(
    'enforcement_decisions', coalesce((
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'action_id', action.id,
        'action_kind', action.action_kind,
        'subject_kind', action.subject_kind,
        'subject_id', action.subject_id,
        'reason_code', action.reason_code,
        'starts_at', action.starts_at,
        'ends_at', action.ends_at,
        'revoked_at', action.revoked_at,
        'is_active', action.revoked_at is null
          and action.starts_at <= now()
          and (action.ends_at is null or action.ends_at > now()),
        'appeal_eligible', appeal.id is null
          and action.revoked_at is null
          and (action.ends_at is null or action.ends_at >= now() - interval '90 days'),
        'appeal_id', appeal.id,
        'appeal_status', appeal.status,
        'appeal_submitted_at', appeal.submitted_at,
        'appeal_reviewed_at', appeal.reviewed_at,
        'appeal_resolution_summary', appeal.resolution_summary
      )) order by action.starts_at, action.id)
      from private.moderation_actions action
      left join private.moderation_appeals appeal
        on appeal.action_id = action.id and appeal.appellant_id = actor
      where action.subject_owner_id = actor
         or (
           action.subject_owner_id is null
           and private.owns_moderation_subject_as(
             action.subject_kind, action.subject_id, actor
           )
         )
    ), '[]'::jsonb),
    'appeals', coalesce((
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'id', appeal.id,
        'action_id', appeal.action_id,
        'client_appeal_id', appeal.client_appeal_id,
        'statement', appeal.statement,
        'status', appeal.status,
        'resolution_summary', appeal.resolution_summary,
        'submitted_at', appeal.submitted_at,
        'reviewed_at', appeal.reviewed_at,
        'updated_at', appeal.updated_at
      )) order by appeal.submitted_at, appeal.id)
      from private.moderation_appeals appeal
      where appeal.appellant_id = actor
    ), '[]'::jsonb)
  );
end;
$$;

-- Report rows contain immutable evidence snapshots and moderation metadata.
-- Authenticated clients receive only caller-bound receipt projections.
revoke select on table public.reports from authenticated;
drop policy if exists "Reporters read own report receipts" on public.reports;

revoke all on function public.get_my_enforcement_state_v1()
  from public, anon, authenticated;
revoke all on function public.get_report_receipt_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.submit_moderation_appeal_v1(uuid,uuid,text)
  from public, anon, authenticated;
revoke all on function public.review_moderation_appeal_v1(uuid,text,text,text,timestamptz)
  from public, anon, authenticated;
revoke all on function public.list_my_report_receipts_v1(integer,timestamptz,uuid)
  from public, anon, authenticated;
revoke all on function public.build_owner_enforcement_export_v1()
  from public, anon, authenticated;

grant execute on function public.get_my_enforcement_state_v1()
  to authenticated;
grant execute on function public.get_report_receipt_v1(uuid)
  to authenticated;
grant execute on function public.submit_moderation_appeal_v1(uuid,uuid,text)
  to authenticated;
grant execute on function public.review_moderation_appeal_v1(uuid,text,text,text,timestamptz)
  to authenticated;
grant execute on function public.list_my_report_receipts_v1(integer,timestamptz,uuid)
  to authenticated;
grant execute on function public.build_owner_enforcement_export_v1()
  to authenticated;

comment on function public.get_my_enforcement_state_v1() is
  'Caller-bound enforcement summary without reporter, reviewer, evidence, or internal-note disclosure.';

comment on function public.submit_moderation_appeal_v1(uuid,uuid,text) is
  'Durable idempotent appeal submission for an enforcement action owned by the caller.';

comment on function public.list_my_report_receipts_v1(integer,timestamptz,uuid) is
  'Caller-bound safe report history without evidence snapshots or moderator identity.';

comment on function public.build_owner_enforcement_export_v1() is
  'Caller-sealed export of the affected person’s safe enforcement decisions and own appeal statements without reviewer or internal moderation data.';

commit;
