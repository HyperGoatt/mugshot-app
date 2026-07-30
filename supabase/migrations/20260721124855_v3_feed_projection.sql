begin;

create or replace function public.get_visit_v3_feed_projections_v1(
  p_visit_ids uuid[]
)
returns table (
  visit_id uuid,
  mugshot_score numeric,
  photo_fallback text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  requested_ids uuid[] := coalesce(p_visit_ids, '{}'::uuid[]);
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if cardinality(requested_ids) > 100 then
    raise exception 'too many visit projections requested' using errcode = '22023';
  end if;

  return query
  select
    reflection.visit_id,
    reflection.mugshot_score,
    reflection.photo_fallback
  from public.visit_v3_reflections reflection
  where reflection.visit_id = any(requested_ids)
    and public.can_view_visit(reflection.visit_id, actor);
end;
$$;

revoke all on function public.get_visit_v3_feed_projections_v1(uuid[])
  from public, anon, authenticated;
grant execute on function public.get_visit_v3_feed_projections_v1(uuid[])
  to authenticated;

comment on function public.get_visit_v3_feed_projections_v1(uuid[]) is
  'Caller-bound, feed-safe V3 score and Mugsy placeholder projection.';

commit;;
