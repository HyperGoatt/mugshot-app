-- Phase two turns every sip into a flexible journal entry while keeping the
-- existing visits table and visibility model authoritative.

alter table public.visits
  add column if not exists brew_details jsonb not null default '{}'::jsonb;

alter table public.visits
  drop constraint if exists visits_brew_details_object;

alter table public.visits
  add constraint visits_brew_details_object
  check (jsonb_typeof(brew_details) = 'object');

create or replace function public.resolve_cafe_summary(
  p_name text,
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_apple_place_id text default null
)
returns table (
  cafe_id uuid,
  name text,
  address text,
  city text,
  latitude double precision,
  longitude double precision,
  identity_key text,
  apple_place_id text,
  website_url text,
  average_rating double precision,
  visible_visit_count bigint,
  recent_cover text,
  is_favorite boolean,
  want_to_try boolean,
  is_visited boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  with input as (
    select
      auth.uid() as viewer,
      lower(regexp_replace(trim(coalesce(p_name, '')), '\s+', ' ', 'g')) as normalized_name,
      case
        when p_latitude between -90 and 90 then p_latitude
      end as latitude,
      case
        when p_longitude between -180 and 180 then p_longitude
      end as longitude,
      nullif(trim(coalesce(p_apple_place_id, '')), '') as apple_place_id
  ), candidates as (
    select
      c.*,
      case
        when i.latitude is null or i.longitude is null or c.latitude is null or c.longitude is null then null
        else 6371 * 2 * asin(sqrt(
          power(sin(radians(c.latitude - i.latitude) / 2), 2)
          + cos(radians(i.latitude)) * cos(radians(c.latitude))
          * power(sin(radians(c.longitude - i.longitude) / 2), 2)
        ))
      end as distance_km,
      (
        select count(*)
        from public.visits candidate_visit
        where candidate_visit.cafe_id = c.id
          and candidate_visit.upload_state = 'complete'
      ) as visible_count,
      case
        when i.apple_place_id is not null and c.apple_place_id = i.apple_place_id then 0
        when i.normalized_name = lower(regexp_replace(trim(c.name), '\s+', ' ', 'g')) then 1
        else 2
      end as match_rank
    from public.cafes c
    cross join input i
    where i.viewer is not null
      and (
        (i.apple_place_id is not null and c.apple_place_id = i.apple_place_id)
        or (
          i.normalized_name <> ''
          and i.normalized_name = lower(regexp_replace(trim(c.name), '\s+', ' ', 'g'))
          and (
            i.latitude is null
            or i.longitude is null
            or c.latitude is null
            or c.longitude is null
            or 6371 * 2 * asin(sqrt(
              power(sin(radians(c.latitude - i.latitude) / 2), 2)
              + cos(radians(i.latitude)) * cos(radians(c.latitude))
              * power(sin(radians(c.longitude - i.longitude) / 2), 2)
            )) <= 0.35
          )
        )
      )
  ), chosen as (
    select candidate.*
    from candidates candidate
    order by
      candidate.match_rank,
      candidate.visible_count desc,
      candidate.distance_km asc nulls last,
      candidate.id
    limit 1
  ), visible as (
    select visit.*
    from public.visits visit
    cross join input i
    join chosen cafe on cafe.id = visit.cafe_id
    where visit.upload_state = 'complete'
  )
  select
    cafe.id,
    cafe.name,
    cafe.address,
    cafe.city,
    cafe.latitude,
    cafe.longitude,
    cafe.identity_key,
    cafe.apple_place_id,
    cafe.website_url,
    avg(visit.overall_score),
    count(visit.id),
    (array_agg(visit.poster_photo_url order by visit.created_at desc)
      filter (where visit.poster_photo_url is not null))[1],
    coalesce(state.is_favorite, false),
    coalesce(state.want_to_try, false),
    coalesce(bool_or(visit.user_id = i.viewer), false)
  from chosen cafe
  cross join input i
  left join visible visit on true
  left join public.user_cafe_states state
    on state.cafe_id = cafe.id and state.user_id = i.viewer
  group by
    cafe.id,
    cafe.name,
    cafe.address,
    cafe.city,
    cafe.latitude,
    cafe.longitude,
    cafe.identity_key,
    cafe.apple_place_id,
    cafe.website_url,
    state.is_favorite,
    state.want_to_try,
    i.viewer;
$$;

revoke all on function public.resolve_cafe_summary(text,double precision,double precision,text)
  from public, anon;
grant execute on function public.resolve_cafe_summary(text,double precision,double precision,text)
  to authenticated;
