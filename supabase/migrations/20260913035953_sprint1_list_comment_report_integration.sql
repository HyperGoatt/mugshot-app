-- Route legacy list-comment reports into the existing durable review and appeal system.
create or replace function private.screening_approved_v1(p_kind text,p_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists(select 1 from private.screening_jobs
    where subject_kind=p_kind and subject_id=p_id and state='approved')
    and (p_kind<>'list_comment' or not private.has_active_moderation_action('cafe_list_comment',p_id,array['content_hidden']::text[]));
$$;

create function private.bridge_list_comment_report_v1(p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
begin
  insert into public.reports(id,reporter_id,reporter_subject_id,target_kind,target_id,target_snapshot,reason,details,created_at)
  select r.id,r.reporter_id,r.reporter_id,'cafe_list_comment',r.comment_id,
    jsonb_build_object('kind','cafe_list_comment','id',r.comment_id,'user_id',c.user_id,
      'text',c.body,'list_id',c.list_id,'captured_at',now()),
    r.reason::public.report_reason,r.details,r.created_at
  from public.cafe_list_comment_reports r join public.cafe_list_comments c on c.id=r.comment_id
  where r.id=p_id on conflict(id) do nothing;
end;
$$;

create function private.bridge_list_comment_report_trigger_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  perform private.bridge_list_comment_report_v1(new.id);
  return new;
end;
$$;
create trigger bridge_list_comment_report after insert on public.cafe_list_comment_reports
for each row execute function private.bridge_list_comment_report_trigger_v1();
revoke all on function private.bridge_list_comment_report_v1(uuid),private.bridge_list_comment_report_trigger_v1() from public,anon,authenticated;
alter table public.reports drop constraint reports_target_kind_check,
  add constraint reports_target_kind_check check(target_kind in ('user','visit','comment','cafe_list_comment'));
alter table private.moderation_actions drop constraint moderation_actions_subject_kind_check,
  add constraint moderation_actions_subject_kind_check check(subject_kind in ('user','visit','comment','cafe_list_comment'));


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
    when 'cafe_list_comment' then (select user_id from public.cafe_list_comments where id=new.subject_id)
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
    when 'cafe_list_comment' then exists(select 1 from public.cafe_list_comments where id=p_subject_id and user_id=p_actor)
    when 'comment' then exists (
      select 1
      from public.comments comment
      where comment.id = p_subject_id and comment.user_id = p_actor
    )
    else false
  end;
$$;

create or replace function private.enforce_moderation_action_report_subject_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_report public.reports;
  reported_owner uuid;
begin
  if new.report_id is null then
    return new;
  end if;

  select * into source_report
  from public.reports report
  where report.id = new.report_id;

  if not found then
    raise exception 'report unavailable' using errcode = 'P0002';
  end if;

  reported_owner := case source_report.target_kind
    when 'user' then source_report.target_id
    when 'visit' then coalesce(
      nullif(source_report.target_snapshot->>'user_id', '')::uuid,
      (select visit.user_id from public.visits visit
       where visit.id = source_report.target_id)
    )
    when 'cafe_list_comment' then coalesce(nullif(source_report.target_snapshot->>'user_id','')::uuid,(select user_id from public.cafe_list_comments where id=source_report.target_id))
    when 'comment' then coalesce(
      nullif(source_report.target_snapshot->>'user_id', '')::uuid,
      (select comment.user_id from public.comments comment
       where comment.id = source_report.target_id)
    )
  end;

  if not (
    (new.subject_kind = source_report.target_kind
      and new.subject_id = source_report.target_id)
    or (new.subject_kind = 'user' and new.subject_id = reported_owner)
  ) then
    raise exception 'moderation subject is unrelated to the report'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create or replace function public.review_report_v1(
  p_report_id uuid,
  p_new_status public.report_status,
  p_resolution_code text default null,
  p_internal_note text default null,
  p_action_kind text default null,
  p_action_subject_kind text default null,
  p_action_subject_id uuid default null,
  p_action_ends_at timestamptz default null
)
returns public.reports
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  report_before public.reports;
  report_after public.reports;
  normalized_resolution text := nullif(trim(p_resolution_code), '');
  normalized_note text := nullif(trim(p_internal_note), '');
  action_subject_kind text;
  action_subject_id uuid;
begin
  if not private.is_live_account_as(actor) then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not exists (
    select 1
    from private.moderation_operators operator
    where operator.user_id = actor and operator.is_active
  ) then
    raise exception 'moderation permission required' using errcode = '42501';
  end if;
  if char_length(coalesce(normalized_note, '')) > 2000 then
    raise exception 'internal note is too long' using errcode = '22023';
  end if;

  select * into report_before
  from public.reports report
  where report.id = p_report_id
  for update;

  if not found then
    raise exception 'report unavailable' using errcode = 'P0002';
  end if;
  if report_before.reporter_subject_id = actor then
    raise exception 'reviewers cannot resolve their own report' using errcode = '42501';
  end if;
  if private.owns_moderation_subject_as(report_before.target_kind,report_before.target_id,actor)
     or nullif(report_before.target_snapshot->>'user_id','')::uuid=actor then
    raise exception 'reviewers cannot resolve reports about their own content' using errcode='42501';
  end if;
  if report_before.status in ('resolved', 'dismissed') then
    raise exception 'report is already closed' using errcode = '55000';
  end if;
  if p_new_status not in ('reviewing', 'resolved', 'dismissed') then
    raise exception 'invalid report transition' using errcode = '22023';
  end if;
  if report_before.status = 'reviewing' and p_new_status = 'reviewing' then
    raise exception 'report is already under review' using errcode = '55000';
  end if;
  if p_new_status in ('resolved', 'dismissed') and normalized_resolution is null then
    raise exception 'resolution code is required to close a report' using errcode = '22023';
  end if;

  if p_action_kind is not null then
    if p_new_status <> 'resolved' then
      raise exception 'an enforcement action requires a resolved report' using errcode = '22023';
    end if;
    if p_action_kind not in ('warning', 'content_hidden', 'social_restricted', 'account_suspended') then
      raise exception 'invalid moderation action' using errcode = '22023';
    end if;

    action_subject_kind := coalesce(p_action_subject_kind, report_before.target_kind);
    action_subject_id := coalesce(p_action_subject_id, report_before.target_id);

    if action_subject_kind not in ('user', 'visit', 'comment', 'cafe_list_comment') or action_subject_id is null then
      raise exception 'invalid moderation subject' using errcode = '22023';
    end if;
    if p_action_kind in ('social_restricted', 'account_suspended', 'warning')
       and action_subject_kind <> 'user' then
      raise exception 'user action requires a user subject' using errcode = '22023';
    end if;
    if p_action_kind = 'content_hidden' and action_subject_kind not in ('visit', 'comment', 'cafe_list_comment') then
      raise exception 'content action requires a visit or comment subject' using errcode = '22023';
    end if;
    if (action_subject_kind = 'cafe_list_comment' and not exists(select 1 from public.cafe_list_comments where id=action_subject_id))
       or (action_subject_kind = 'user' and not exists (
         select 1 from public.users subject where subject.id = action_subject_id
       ))
       or (action_subject_kind = 'visit' and not exists (
         select 1 from public.visits subject where subject.id = action_subject_id
       ))
       or (action_subject_kind = 'comment' and not exists (
         select 1 from public.comments subject where subject.id = action_subject_id
       )) then
      raise exception 'moderation subject unavailable' using errcode = 'P0002';
    end if;
    if p_action_ends_at is not null and p_action_ends_at <= now() then
      raise exception 'moderation action must end in the future' using errcode = '22023';
    end if;
  end if;

  update public.reports report
  set
    status = p_new_status,
    reviewed_by = actor,
    reviewed_at = coalesce(report.reviewed_at, now()),
    resolution_code = case
      when p_new_status in ('resolved', 'dismissed') then normalized_resolution
      else report.resolution_code
    end,
    closed_at = case
      when p_new_status in ('resolved', 'dismissed') then now()
      else null
    end
  where report.id = p_report_id
  returning * into report_after;

  insert into private.moderation_case_events (
    report_id,
    actor_user_id,
    event_kind,
    from_status,
    to_status,
    resolution_code,
    internal_note
  ) values (
    report_after.id,
    actor,
    case p_new_status
      when 'reviewing' then 'review_started'
      when 'resolved' then 'report_resolved'
      else 'report_dismissed'
    end,
    report_before.status,
    report_after.status,
    normalized_resolution,
    normalized_note
  );

  if p_action_kind is not null then
    insert into private.moderation_actions (
      report_id,
      subject_kind,
      subject_id,
      action_kind,
      reason_code,
      internal_note,
      ends_at,
      created_by
    ) values (
      report_after.id,
      action_subject_kind,
      action_subject_id,
      p_action_kind,
      normalized_resolution,
      normalized_note,
      p_action_ends_at,
      actor
    );

    insert into private.moderation_case_events (
      report_id,
      actor_user_id,
      event_kind,
      from_status,
      to_status,
      resolution_code,
      internal_note
    ) values (
      report_after.id,
      actor,
      'action_applied',
      report_after.status,
      report_after.status,
      normalized_resolution,
      normalized_note
    );
  end if;

  return report_after;
end;
$$;

create or replace function public.review_report_v2(p_report_id uuid,p_expected_status text,p_new_status text,p_resolution text,p_action text,p_actor uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare report public.reports; owner_id uuid; action_kind text:=nullif(p_action,'');
begin
  if p_actor is null or p_actor is distinct from auth.uid() then raise exception 'account changed' using errcode='28000'; end if;
  if not private.screening_operator_v1() then raise exception 'moderation permission required' using errcode='42501'; end if;
  select * into report from public.reports where id=p_report_id for update;
  if not found or report.status::text is distinct from p_expected_status then return false; end if;
  owner_id:=case report.target_kind when 'user' then report.target_id
    when 'visit' then (select user_id from public.visits where id=report.target_id)
    when 'comment' then (select user_id from public.comments where id=report.target_id)
    when 'cafe_list_comment' then (select user_id from public.cafe_list_comments where id=report.target_id) end;
  perform public.review_report_v1(p_report_id,p_new_status::public.report_status,p_resolution,null,
    action_kind,case when action_kind='content_hidden' then report.target_kind else 'user' end,
    case when action_kind='content_hidden' then report.target_id else owner_id end,null);
  return true;
end;
$$;

create or replace function public.report_cafe_list_comment_v1(
  p_comment_id uuid,
  p_reason text,
  p_details text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); result uuid;
begin
  if not private.is_live_account_as(actor) then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'reporting unavailable' using errcode = '42501';
  end if;
  if p_reason not in ('spam', 'harassment', 'privacy', 'other')
     or char_length(coalesce(p_details, '')) > 500 then
    raise exception 'invalid report' using errcode = '22023';
  end if;
  select id into result from public.cafe_list_comment_reports where comment_id=p_comment_id and reporter_id=actor;
  if found then return result; end if;
  if not exists (
    select 1 from public.cafe_list_comments comment
    where comment.id = p_comment_id
      and comment.deleted_at is null
      and comment.user_id <> actor
      and private.is_public_cafe_list_as(comment.list_id, actor)
  ) then
    raise exception 'comment unavailable' using errcode = '42501';
  end if;
  insert into public.cafe_list_comment_reports (comment_id, reporter_id, reason, details)
  values (p_comment_id, actor, p_reason, nullif(btrim(p_details), ''))
  on conflict (comment_id, reporter_id) do nothing
  returning id into result;
  if result is null then
    select id into result from public.cafe_list_comment_reports where comment_id=p_comment_id and reporter_id=actor;
  end if;
  return result;
end;
$$;

-- Preserve the original receipt IDs while capturing currently available legacy evidence.
select private.bridge_list_comment_report_v1(id) from public.cafe_list_comment_reports;
