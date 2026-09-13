-- Founder operations reuse durable reports, enforcement actions and appeals.
-- No report evidence or human decisions enter the screening provider queue.

create function public.get_moderation_case_v1(p_kind text,p_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
  if not private.screening_operator_v1() then raise exception 'moderation permission required' using errcode='42501'; end if;
  if p_kind='report' then
    select jsonb_build_object(
      'id',r.id,'kind','report','status',r.status,'created_at',r.created_at,
      'reason',r.reason,'statement',r.details,'resolution',r.resolution_code,
      'target_kind',r.target_kind,'target_id',r.target_id,
      'subject_text',coalesce(r.target_snapshot->>'text',r.target_snapshot->>'caption',r.target_snapshot->>'display_name',''),
      'self_review_conflict',coalesce(r.reporter_subject_id=auth.uid(),false)
        or private.owns_moderation_subject_as(r.target_kind,r.target_id,auth.uid())
        or coalesce(nullif(r.target_snapshot->>'user_id','')::uuid=auth.uid(),false),
      'history',coalesce((select jsonb_agg(to_jsonb(event)) from (
        select event_kind,internal_note,created_at from private.moderation_case_events
        where report_id=r.id order by created_at desc,id desc limit 25
      ) event),'[]'::jsonb)
    ) into result from public.reports r where r.id=p_id;
  elsif p_kind='appeal' then
    select jsonb_build_object(
      'id',a.id,'kind','appeal','status',a.status,'created_at',a.submitted_at,
      'reason',action.reason_code,'statement',a.statement,'resolution',a.resolution_summary,
      'target_kind',action.subject_kind,'target_id',action.subject_id,
      'action_kind',action.action_kind,'ends_at',action.ends_at,'revoked_at',action.revoked_at,
      'self_review_conflict',a.appellant_id=auth.uid(),
      'history',coalesce((select jsonb_agg(to_jsonb(event)) from (
        select event_kind,internal_note,created_at from private.moderation_appeal_events
        where appeal_id=a.id order by created_at desc,id desc limit 25
      ) event),'[]'::jsonb)
    ) into result from private.moderation_appeals a
    join private.moderation_actions action on action.id=a.action_id where a.id=p_id;
  else raise exception 'invalid case kind' using errcode='22023'; end if;
  return result;
end;
$$;

create function public.list_moderation_cases_v1(p_kind text,p_status text default 'pending',p_cursor jsonb default null,p_limit integer default 25)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not private.screening_operator_v1() then raise exception 'moderation permission required' using errcode='42501'; end if;
  if p_kind is null or p_kind not in ('report','appeal') or p_status is null or p_status not in ('pending','reviewing','closed') then
    raise exception 'invalid queue filter' using errcode='22023';
  end if;
  if p_cursor is not null and not(p_cursor ?& array['created_at','id']) then raise exception 'complete queue cursor required' using errcode='22023'; end if;
  return coalesce((select jsonb_agg(public.get_moderation_case_v1(p_kind,queue.id)) from (
    select id,created_at from (
      select r.id,r.created_at,r.status::text as status from public.reports r where p_kind='report'
      union all
      select a.id,a.submitted_at,a.status from private.moderation_appeals a where p_kind='appeal'
    ) cases where (status=p_status or (p_status='closed' and status not in ('pending','reviewing')))
      and (p_cursor is null or (created_at,id)>((p_cursor->>'created_at')::timestamptz,(p_cursor->>'id')::uuid))
    order by created_at,id limit greatest(1,least(coalesce(p_limit,25),100))
  ) queue),'[]'::jsonb);
end;
$$;

create function public.review_report_v2(p_report_id uuid,p_expected_status text,p_new_status text,p_resolution text,p_action text,p_actor uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare report public.reports; owner_id uuid; action_kind text:=nullif(p_action,'');
begin
  if p_actor is null or p_actor is distinct from auth.uid() then raise exception 'account changed' using errcode='28000'; end if;
  if not private.screening_operator_v1() then raise exception 'moderation permission required' using errcode='42501'; end if;
  select * into report from public.reports where id=p_report_id for update;
  if not found or report.status::text is distinct from p_expected_status then return false; end if;
  owner_id:=case report.target_kind when 'user' then report.target_id
    when 'visit' then (select user_id from public.visits where id=report.target_id)
    when 'comment' then (select user_id from public.comments where id=report.target_id) end;
  perform public.review_report_v1(p_report_id,p_new_status::public.report_status,p_resolution,null,
    action_kind,case when action_kind='content_hidden' then report.target_kind else 'user' end,
    case when action_kind='content_hidden' then report.target_id else owner_id end,null);
  return true;
end;
$$;

create function public.review_moderation_appeal_v2(p_appeal_id uuid,p_expected_status text,p_new_status text,p_resolution text,p_actor uuid,p_modified_ends_at timestamptz default null)
returns boolean language plpgsql security definer set search_path='' as $$
declare appeal private.moderation_appeals;
begin
  if p_actor is null or p_actor is distinct from auth.uid() then raise exception 'account changed' using errcode='28000'; end if;
  if not private.screening_operator_v1() then raise exception 'moderation permission required' using errcode='42501'; end if;
  select * into appeal from private.moderation_appeals where id=p_appeal_id for update;
  if not found or appeal.status is distinct from p_expected_status then return false; end if;
  perform public.review_moderation_appeal_v1(p_appeal_id,p_new_status,p_resolution,null,p_modified_ends_at);
  return true;
end;
$$;

revoke all on function public.get_moderation_case_v1(text,uuid),public.list_moderation_cases_v1(text,text,jsonb,integer),public.review_report_v2(uuid,text,text,text,text,uuid),public.review_moderation_appeal_v2(uuid,text,text,text,uuid,timestamptz) from public,anon;
grant execute on function public.get_moderation_case_v1(text,uuid),public.list_moderation_cases_v1(text,text,jsonb,integer),public.review_report_v2(uuid,text,text,text,text,uuid),public.review_moderation_appeal_v2(uuid,text,text,text,uuid,timestamptz) to authenticated;


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

    if action_subject_kind not in ('user', 'visit', 'comment') or action_subject_id is null then
      raise exception 'invalid moderation subject' using errcode = '22023';
    end if;
    if p_action_kind in ('social_restricted', 'account_suspended', 'warning')
       and action_subject_kind <> 'user' then
      raise exception 'user action requires a user subject' using errcode = '22023';
    end if;
    if p_action_kind = 'content_hidden' and action_subject_kind not in ('visit', 'comment') then
      raise exception 'content action requires a visit or comment subject' using errcode = '22023';
    end if;
    if (action_subject_kind = 'user' and not exists (
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

create or replace function public.revoke_moderation_action_v1(
  p_action_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  action private.moderation_actions;
  normalized_reason text := nullif(trim(p_reason), '');
begin
  if not private.is_live_account_as(actor) then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not exists (
    select 1
    from private.moderation_operators operator
    where operator.user_id = actor
      and operator.role = 'admin'
      and operator.is_active
  ) then
    raise exception 'moderation administrator permission required' using errcode = '42501';
  end if;
  if normalized_reason is null or char_length(normalized_reason) > 280 then
    raise exception 'revocation reason is required' using errcode = '22023';
  end if;

  select * into action
  from private.moderation_actions existing_action
  where existing_action.id = p_action_id
  for update;

  if not found then
    raise exception 'moderation action unavailable' using errcode = 'P0002';
  end if;
  if action.subject_owner_id=actor or private.owns_moderation_subject_as(action.subject_kind,action.subject_id,actor) then
    raise exception 'reviewers cannot revoke their own enforcement' using errcode='42501';
  end if;
  if action.revoked_at is null then
    update private.moderation_actions existing_action
    set revoked_at = now(), revoked_by = actor,
        revocation_reason = normalized_reason
    where existing_action.id = p_action_id
    returning * into action;

    if action.report_id is not null then
      insert into private.moderation_case_events (
        report_id, actor_user_id, event_kind, resolution_code, internal_note
      ) values (
        action.report_id, actor, 'action_revoked', action.reason_code,
        normalized_reason
      );
    end if;
  end if;

  return jsonb_build_object(
    'action_id', action.id,
    'subject_kind', action.subject_kind,
    'subject_id', action.subject_id,
    'action_kind', action.action_kind,
    'revoked_at', action.revoked_at
  );
end;
$$;
