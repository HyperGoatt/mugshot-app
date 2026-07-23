-- Map pins keep Cafe and Sip evidence independent. This caller-bound batch
-- function supplies a session-balanced friend Sip fallback only when no
-- shared friend Cafe Pulse rating exists.

begin;
create or replace function public.get_friend_map_sip_summaries_v1(
  p_cafe_ids uuid[]
)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_cafe_ids is null or cardinality(p_cafe_ids) > 100 then
    raise exception 'friend map summaries require at most 100 cafe identifiers'
      using errcode = '22023';
  end if;
  if array_position(p_cafe_ids, null) is not null then
    raise exception 'friend map cafe identifiers cannot contain null'
      using errcode = '22023';
  end if;

  with requested as (
    select requested.cafe_id, requested.ordinality
    from unnest(p_cafe_ids) with ordinality requested(cafe_id, ordinality)
  ), eligible_sips as (
    select
      visit.id,
      visit.user_id,
      visit.cafe_id,
      visit.cafe_session_id,
      visit.overall_score
    from public.visits visit
    join requested on requested.cafe_id = visit.cafe_id
    where visit.user_id <> actor
      and visit.upload_state = 'complete'
      and visit.overall_score > 0
      and public.is_confirmed_friend(actor, visit.user_id)
  ), physical_sessions as (
    select
      eligible.cafe_id,
      eligible.user_id,
      coalesce(eligible.cafe_session_id, eligible.id) physical_session_id,
      avg(eligible.overall_score)::double precision session_sip_average,
      count(*)::integer sip_count
    from eligible_sips eligible
    group by
      eligible.cafe_id,
      eligible.user_id,
      coalesce(eligible.cafe_session_id, eligible.id)
  ), summaries as (
    select
      session.cafe_id,
      avg(session.session_sip_average)::double precision average_sip_rating,
      coalesce(sum(session.sip_count), 0)::integer sip_count,
      count(*)::integer physical_session_count,
      count(distinct session.user_id)::integer contributor_count
    from physical_sessions session
    group by session.cafe_id
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'cafe_id', requested.cafe_id,
        'average_sip_rating', summary.average_sip_rating,
        'sip_count', coalesce(summary.sip_count, 0),
        'physical_session_count', coalesce(summary.physical_session_count, 0),
        'contributor_count', coalesce(summary.contributor_count, 0)
      )
      order by requested.ordinality
    ),
    '[]'::jsonb
  )
  into result
  from requested
  left join summaries summary on summary.cafe_id = requested.cafe_id;

  return result;
end;
$$;
revoke all on function public.get_friend_map_sip_summaries_v1(uuid[])
  from public, anon, authenticated;
grant execute on function public.get_friend_map_sip_summaries_v1(uuid[])
  to authenticated;
commit;
