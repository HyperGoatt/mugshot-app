-- Preserve owner-level review actions after reported content is removed.
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
  -- Server-captured evidence survives content deletion; the delegated V1 and
  -- enforcement triggers still require a live subject and matching report.
  owner_id:=coalesce(owner_id,nullif(report.target_snapshot->>'user_id','')::uuid);
  perform public.review_report_v1(p_report_id,p_new_status::public.report_status,p_resolution,null,
    action_kind,case when action_kind='content_hidden' then report.target_kind else 'user' end,
    case when action_kind='content_hidden' then report.target_id else owner_id end,null);
  return true;
end;
$$;
