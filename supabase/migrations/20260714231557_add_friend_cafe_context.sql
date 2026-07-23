-- Friend-only cafe discovery for the Map. This deliberately excludes the
-- caller's own visits and broader Everyone activity so the rating, sip count,
-- and people shown in Friends mode all describe confirmed friends only.
create or replace function public.discover_friend_cafes(
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km double precision default 25,
  p_limit integer default 20,
  p_after_score double precision default null,
  p_after_id uuid default null
)
returns table (
  cafe_id uuid,
  name text,
  address text,
  city text,
  latitude double precision,
  longitude double precision,
  identity_key text,
  section text,
  ranking_score double precision,
  ranking_reason text,
  distance_km double precision,
  average_rating double precision,
  visible_visit_count bigint,
  friend_count bigint,
  top_drinks jsonb,
  recent_cover text,
  is_saved boolean,
  is_visited boolean,
  friend_profiles jsonb
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (
    select
      auth.uid() viewer,
      case
        when p_latitude between -90 and 90 and p_longitude between -180 and 180
          then p_latitude
      end lat,
      case
        when p_latitude between -90 and 90 and p_longitude between -180 and 180
          then p_longitude
      end lon,
      least(greatest(coalesce(p_radius_km, 25), 0.1), 100) radius,
      least(greatest(coalesce(p_limit, 20), 1), 50) page_size
  ), friend_visits as (
    select visit.*
    from public.visits visit
    cross join input
    where input.viewer is not null
      and visit.cafe_id is not null
      and visit.upload_state = 'complete'
      and private.confirmed_friends(input.viewer, visit.user_id)
      and private.can_view_visit_as(visit.id, input.viewer)
  ), aggregates as (
    select
      cafe.id,
      cafe.name,
      cafe.address,
      cafe.city,
      cafe.latitude,
      cafe.longitude,
      cafe.identity_key,
      case
        when input.lat is null then null
        else 6371 * 2 * asin(sqrt(
          power(sin(radians(cafe.latitude - input.lat) / 2), 2)
          + cos(radians(input.lat)) * cos(radians(cafe.latitude))
          * power(sin(radians(cafe.longitude - input.lon) / 2), 2)
        ))
      end distance,
      count(friend_visit.id) visit_count,
      avg(friend_visit.overall_score)::double precision average_score,
      count(distinct friend_visit.user_id) friend_total,
      count(friend_visit.id) filter (
        where friend_visit.created_at >= now() - interval '30 days'
      ) recent_count,
      max(friend_visit.poster_photo_url) filter (
        where friend_visit.poster_photo_url is not null
      ) recent_cover,
      coalesce((
        select jsonb_agg(
          jsonb_build_object('name', drink_counts.drink, 'count', drink_counts.total)
          order by drink_counts.total desc, drink_counts.drink
        )
        from (
          select
            coalesce(drink_visit.drink_subtype, drink_visit.drink_type_custom, drink_visit.drink_type) drink,
            count(*) total
          from friend_visits drink_visit
          where drink_visit.cafe_id = cafe.id
            and coalesce(drink_visit.drink_subtype, drink_visit.drink_type_custom, drink_visit.drink_type) is not null
          group by 1
          order by 2 desc, 1
          limit 3
        ) drink_counts
      ), '[]'::jsonb) drinks,
      coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'user_id', friend_summary.user_id,
            'display_name', profile.display_name,
            'username', profile.username,
            'avatar_url', profile.avatar_url,
            'average_rating', friend_summary.average_rating,
            'sip_count', friend_summary.sip_count
          )
          order by friend_summary.last_sip_at desc, profile.display_name, friend_summary.user_id
        )
        from (
          select
            profile_visit.user_id,
            avg(profile_visit.overall_score)::double precision average_rating,
            count(*)::integer sip_count,
            max(profile_visit.created_at) last_sip_at
          from friend_visits profile_visit
          where profile_visit.cafe_id = cafe.id
          group by profile_visit.user_id
        ) friend_summary
        join public.users profile on profile.id = friend_summary.user_id
      ), '[]'::jsonb) profiles,
      exists (
        select 1
        from public.user_cafe_states cafe_state
        where cafe_state.user_id = input.viewer
          and cafe_state.cafe_id = cafe.id
          and (cafe_state.is_favorite or cafe_state.want_to_try)
      ) saved,
      exists (
        select 1
        from public.visits own_visit
        where own_visit.user_id = input.viewer
          and own_visit.cafe_id = cafe.id
          and own_visit.upload_state = 'complete'
      ) visited,
      input.radius
    from public.cafes cafe
    cross join input
    join friend_visits friend_visit on friend_visit.cafe_id = cafe.id
    where cafe.latitude is not null and cafe.longitude is not null
    group by cafe.id, input.viewer, input.lat, input.lon, input.radius
  ), scored as (
    select
      aggregates.*,
      (
        coalesce(0.28 * greatest(0, 1 - aggregates.distance / aggregates.radius), 0)
        + 0.34 * least(aggregates.average_score / 5, 1)
        + 0.24 * least(aggregates.friend_total::double precision / 4, 1)
        + 0.14 * least(aggregates.recent_count::double precision / 5, 1)
      ) / (case when aggregates.distance is null then 0.72 else 1 end) score
    from aggregates
    where aggregates.distance is null or aggregates.distance <= aggregates.radius
  )
  select
    scored.id,
    scored.name,
    scored.address,
    scored.city,
    scored.latitude,
    scored.longitude,
    scored.identity_key,
    'loved_by_friends'::text,
    scored.score,
    case
      when scored.friend_total = 1 then 'Shared by 1 friend'
      else 'Shared by ' || scored.friend_total || ' friends'
    end,
    scored.distance,
    scored.average_score,
    scored.visit_count,
    scored.friend_total,
    scored.drinks,
    scored.recent_cover,
    scored.saved,
    scored.visited,
    scored.profiles
  from scored
  where p_after_score is null or (scored.score, scored.id) < (p_after_score, p_after_id)
  order by scored.score desc, scored.id desc
  limit (select page_size from input);
$$;

revoke all on function public.discover_friend_cafes(
  double precision,
  double precision,
  double precision,
  integer,
  double precision,
  uuid
) from public, anon, authenticated;

grant execute on function public.discover_friend_cafes(
  double precision,
  double precision,
  double precision,
  integer,
  double precision,
  uuid
) to authenticated;
;
