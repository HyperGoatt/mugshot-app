-- Reports retain historical evidence; this separately locates the current
-- shared revision. Private/deleted content has no screening job to preview.
create function public.get_report_screening_target_v1(p_report_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
  if not private.screening_operator_v1() then raise exception 'moderation permission required' using errcode='42501'; end if;
  return (select jsonb_build_object('subject_kind',job.subject_kind,'subject_id',job.subject_id,
    'revision',job.revision,'state',job.state,'reason',job.reason,'updated_at',job.updated_at)
    from public.reports report join private.screening_jobs job
      on job.subject_id=report.target_id and job.subject_kind=case report.target_kind
        when 'cafe_list_comment' then 'list_comment' else report.target_kind end
    where report.id=p_report_id);
end;
$$;
revoke all on function public.get_report_screening_target_v1(uuid) from public,anon;
grant execute on function public.get_report_screening_target_v1(uuid) to authenticated;
