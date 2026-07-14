-- Follow-up product sprint: signed-out discovery, chronological social feeds,
-- account-bound sip companions, richer public tasting journals, and correction
-- cleanup. All SECURITY DEFINER functions use an empty search path and expose
-- only intentionally selected fields.

create index if not exists visits_everyone_complete_cafe_created_idx
  on public.visits (cafe_id, created_at desc, id desc)
  where visibility = 'everyone' and upload_state = 'complete' and cafe_id is not null;

-- Signed-out discovery is deliberately community-only. It never calls the
-- viewer-aware visibility helper and therefore cannot include Friends or
-- Private journal entries.
create or replace function public.discover_public_cafes(
  p_section text default 'nearby',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km double precision default 25,
  p_limit integer default 20,
  p_after_score double precision default null,
  p_after_id uuid default null
)
returns table (
  cafe_id uuid, name text, address text, city text, latitude double precision,
  longitude double precision, identity_key text, section text,
  ranking_score double precision, ranking_reason text, distance_km double precision,
  average_rating double precision, visible_visit_count bigint, friend_count bigint,
  top_drinks jsonb, recent_cover text, is_saved boolean, is_visited boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (
    select
      case when p_latitude between -90 and 90 and p_longitude between -180 and 180 then p_latitude end lat,
      case when p_latitude between -90 and 90 and p_longitude between -180 and 180 then p_longitude end lon,
      least(greatest(coalesce(p_radius_km, 25), 1), 100) radius,
      least(greatest(coalesce(p_limit, 20), 1), 50) page_size
  ), public_visits as (
    select visit.*
    from public.visits visit
    where visit.visibility = 'everyone'
      and visit.upload_state = 'complete'
      and visit.cafe_id is not null
  ), aggregates as (
    select
      cafe.id, cafe.name, cafe.address, cafe.city, cafe.latitude, cafe.longitude, cafe.identity_key,
      case when input.lat is null then null else
        6371 * 2 * asin(sqrt(
          power(sin(radians(cafe.latitude - input.lat) / 2), 2)
          + cos(radians(input.lat)) * cos(radians(cafe.latitude))
          * power(sin(radians(cafe.longitude - input.lon) / 2), 2)
        ))
      end distance,
      count(visit.id) visit_count,
      avg(visit.overall_score)::double precision avg_rating,
      count(visit.id) filter (where visit.created_at >= now() - interval '30 days') recent_count,
      max(visit.poster_photo_url) filter (where visit.poster_photo_url is not null) recent_cover,
      coalesce((
        select jsonb_agg(jsonb_build_object('name', drinks.drink, 'count', drinks.n)
                         order by drinks.n desc, drinks.drink)
        from (
          select coalesce(drink_visit.drink_subtype, drink_visit.drink_type_custom, drink_visit.drink_type) drink,
                 count(*) n
          from public_visits drink_visit
          where drink_visit.cafe_id = cafe.id
            and coalesce(drink_visit.drink_subtype, drink_visit.drink_type_custom, drink_visit.drink_type) is not null
          group by 1
          order by 2 desc, 1
          limit 3
        ) drinks
      ), '[]'::jsonb) drinks,
      input.radius
    from public.cafes cafe
    cross join input
    join public_visits visit on visit.cafe_id = cafe.id
    where cafe.latitude is not null and cafe.longitude is not null
    group by cafe.id, input.lat, input.lon, input.radius
  ), scored as (
    select aggregates.*,
      (
        coalesce(.42 * greatest(0, 1 - aggregates.distance / aggregates.radius), 0)
        + .30 * least(coalesce(aggregates.avg_rating, 0) / 5, 1)
        + .18 * least(aggregates.visit_count::double precision / 8, 1)
        + .10 * least(aggregates.recent_count::double precision / 4, 1)
      ) / (case when aggregates.distance is null then .58 else 1 end) score
    from aggregates
  ), filtered as (
    select scored.*,
      case p_section
        when 'popular_drinks' then 'Popular drinks from the Mugshot community'
        when 'trending' then 'Recently remembered by the Mugshot community'
        else case when scored.distance is null
          then 'Loved by the Mugshot community'
          else 'A community pick nearby'
        end
      end reason
    from scored
    where (scored.distance is null or scored.distance <= scored.radius)
      and case p_section
        when 'nearby' then true
        when 'popular_drinks' then scored.drinks <> '[]'::jsonb
        when 'trending' then scored.recent_count > 0
        else false
      end
  )
  select
    filtered.id, filtered.name, filtered.address, filtered.city,
    filtered.latitude, filtered.longitude, filtered.identity_key, p_section,
    filtered.score, filtered.reason, filtered.distance, filtered.avg_rating,
    filtered.visit_count, 0::bigint, filtered.drinks, filtered.recent_cover,
    false, false
  from filtered
  where p_after_score is null or (filtered.score, filtered.id) < (p_after_score, p_after_id)
  order by filtered.score desc, filtered.id desc
  limit (select page_size from input);
$$;

revoke all on function public.discover_public_cafes(text,double precision,double precision,double precision,integer,double precision,uuid)
  from public, anon, authenticated;
grant execute on function public.discover_public_cafes(text,double precision,double precision,double precision,integer,double precision,uuid)
  to anon, authenticated;

-- Friends and Everyone are intentionally chronological. Your Mix is the only
-- ranked scope and balances recency, trust, taste, nearby/saved context,
-- personal journal affinity, and light social proof. Repeated authors, cafes,
-- and drinks receive a small diversity penalty.
create or replace function public.ranked_feed(
  p_scope text default 'ranked',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_limit integer default 20,
  p_after_score double precision default null,
  p_after_created_at timestamptz default null,
  p_after_id uuid default null
)
returns table (
  visit_id uuid, user_id uuid, cafe_id uuid, caption text, drink_name text,
  overall_score double precision, poster_photo_url text, created_at timestamptz,
  author_display_name text, author_username text, author_avatar_url text,
  cafe_name text, like_count bigint, comment_count bigint,
  feed_score double precision, ranking_reason text, reason_type text
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (
    select auth.uid() viewer
  ), base as (
    select
      visit.*,
      author.display_name,
      author.username,
      author.avatar_url,
      cafe.name cafe_name,
      cafe.latitude,
      cafe.longitude,
      (select count(*) from public.likes likes where likes.visit_id = visit.id) likes,
      (select count(*) from public.comments comments where comments.visit_id = visit.id) comments,
      case
        when visit.user_id = input.viewer then .85
        when private.confirmed_friends(input.viewer, visit.user_id) then 1.0
        else .15
      end trust,
      exp(-extract(epoch from (now() - visit.created_at)) / 86400 / 12) recency,
      case
        when p_latitude between -90 and 90 and p_longitude between -180 and 180
             and cafe.latitude is not null and cafe.longitude is not null then
          greatest(0, 1 - (
            6371 * 2 * asin(sqrt(
              power(sin(radians(cafe.latitude - p_latitude) / 2), 2)
              + cos(radians(p_latitude)) * cos(radians(cafe.latitude))
              * power(sin(radians(cafe.longitude - p_longitude) / 2), 2)
            ))
          ) / 50)
      end geo,
      exists (
        select 1
        from public.user_cafe_states saved
        where saved.user_id = input.viewer
          and saved.cafe_id = visit.cafe_id
          and (saved.is_favorite or saved.want_to_try)
      ) saved_match,
      exists (
        select 1
        from public.visits mine
        where mine.user_id = input.viewer
          and mine.upload_state = 'complete'
          and coalesce(mine.drink_subtype, mine.drink_type_custom, mine.drink_type)
              = coalesce(visit.drink_subtype, visit.drink_type_custom, visit.drink_type)
      ) journal_affinity,
      visit.user_id <> input.viewer and exists (
        select 1
        from public.taste_signals mine
        join public.taste_signals theirs
          on theirs.signal_type = mine.signal_type
         and theirs.attribute = mine.attribute
        where mine.user_id = input.viewer
          and theirs.user_id = visit.user_id
          and mine.owner_state <> 'dismissed'
          and theirs.owner_state <> 'dismissed'
          and mine.support_count >= 3
          and theirs.support_count >= 3
      ) taste_match
    from public.visits visit
    cross join input
    join public.users author on author.id = visit.user_id
    left join public.cafes cafe on cafe.id = visit.cafe_id
    where input.viewer is not null
      and visit.upload_state = 'complete'
      and private.can_view_visit_as(visit.id, input.viewer)
      and case p_scope
        when 'friends' then visit.user_id = input.viewer
          or (visit.visibility in ('friends', 'everyone') and private.confirmed_friends(input.viewer, visit.user_id))
        when 'everyone' then visit.visibility = 'everyone'
        when 'ranked' then true
        else false
      end
  ), diversified as (
    select base.*,
      row_number() over (partition by base.user_id order by base.created_at desc, base.id desc) author_rank,
      row_number() over (partition by base.cafe_id order by base.created_at desc, base.id desc) cafe_rank,
      row_number() over (
        partition by coalesce(base.drink_subtype, base.drink_type_custom, base.drink_type)
        order by base.created_at desc, base.id desc
      ) drink_rank
    from base
  ), scored as (
    select diversified.*,
      greatest(0,
        .35 * diversified.recency
        + .25 * diversified.trust
        + .15 * (case when diversified.taste_match then 1 else 0 end)
        + .10 * greatest(case when diversified.saved_match then 1 else 0 end, coalesce(diversified.geo, 0))
        + .10 * (case when diversified.journal_affinity then 1 else 0 end)
        + .05 * least((diversified.likes + diversified.comments * 2)::double precision / 10, 1)
        - least(greatest(diversified.author_rank - 1, 0), 2) * .035
        - least(greatest(diversified.cafe_rank - 1, 0), 2) * .020
        - least(greatest(diversified.drink_rank - 1, 0), 2) * .015
      ) score
    from diversified
  )
  select
    scored.id, scored.user_id, scored.cafe_id, scored.caption,
    coalesce(scored.drink_subtype, scored.drink_type_custom, scored.drink_type),
    scored.overall_score, scored.poster_photo_url, scored.created_at,
    scored.display_name, scored.username, scored.avatar_url, scored.cafe_name,
    scored.likes, scored.comments,
    case when p_scope = 'ranked' then scored.score else 1::double precision end,
    case
      when p_scope <> 'ranked' then null
      when scored.user_id <> (select viewer from input) and scored.trust = 1 then 'A recent sip from your friend'
      when scored.taste_match then 'Matches patterns in your tasting passport'
      when scored.saved_match then 'From a cafe you saved'
      when coalesce(scored.geo, 0) >= .65 then 'A sip from a cafe near you'
      when scored.journal_affinity then 'Inspired by drinks in your journal'
      else 'A recent sip from the Mugshot community'
    end,
    case
      when p_scope <> 'ranked' then null
      when scored.user_id <> (select viewer from input) and scored.trust = 1 then 'friend_activity'
      when scored.taste_match then 'taste_match'
      when scored.saved_match then 'saved_cafe'
      when coalesce(scored.geo, 0) >= .65 then 'nearby_cafe'
      when scored.journal_affinity then 'journal_evidence'
      else 'recent_community'
    end
  from scored
  where case
    when p_scope = 'ranked' then
      p_after_score is null
      or (scored.score, scored.created_at, scored.id) < (p_after_score, p_after_created_at, p_after_id)
    else
      p_after_created_at is null
      or (scored.created_at, scored.id) < (p_after_created_at, p_after_id)
  end
  order by
    case when p_scope = 'ranked' then scored.score end desc,
    scored.created_at desc,
    scored.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

revoke all on function public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid)
  from public, anon, authenticated;
grant execute on function public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid)
  to authenticated;

create table if not exists public.visit_companions (
  visit_id uuid not null references public.visits(id) on delete cascade,
  companion_user_id uuid not null references public.users(id) on delete cascade,
  added_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (visit_id, companion_user_id),
  check (companion_user_id <> added_by)
);

create index if not exists visit_companions_user_created_idx
  on public.visit_companions (companion_user_id, created_at desc, visit_id);
create index if not exists visit_companions_added_by_created_idx
  on public.visit_companions (added_by, created_at desc, visit_id);

alter table public.visit_companions enable row level security;
revoke all on table public.visit_companions from public, anon, authenticated;
grant select on table public.visit_companions to authenticated;

drop policy if exists "Visible sip companions" on public.visit_companions;
create policy "Visible sip companions" on public.visit_companions
  for select to authenticated
  using (
    private.can_view_visit_as(visit_id, (select auth.uid()))
    and not private.blocked_between((select auth.uid()), companion_user_id)
  );

create or replace function public.set_visit_companions(
  p_visit_id uuid,
  p_companion_user_ids uuid[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  companion_id uuid;
  distinct_ids uuid[];
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not exists (
    select 1 from public.visits visit
    where visit.id = p_visit_id and visit.user_id = actor
  ) then
    raise exception 'visit ownership required' using errcode = '42501';
  end if;

  select coalesce(array_agg(distinct requested_id), '{}'::uuid[])
  into distinct_ids
  from unnest(coalesce(p_companion_user_ids, '{}'::uuid[])) requested_id
  where requested_id is not null and requested_id <> actor;

  if cardinality(distinct_ids) > 12 then
    raise exception 'a sip can include at most 12 companions' using errcode = '22023';
  end if;
  foreach companion_id in array distinct_ids loop
    if not private.confirmed_friends(actor, companion_id) then
      raise exception 'companions must be confirmed friends' using errcode = '42501';
    end if;
  end loop;

  delete from public.visit_companions companion
  where companion.visit_id = p_visit_id and companion.added_by = actor;

  insert into public.visit_companions (visit_id, companion_user_id, added_by)
  select p_visit_id, requested_id, actor
  from unnest(distinct_ids) requested_id
  on conflict (visit_id, companion_user_id) do update
    set added_by = excluded.added_by, created_at = now();
end;
$$;

create or replace function public.companion_suggestions(p_limit integer default 50)
returns table (
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  shared_sip_count integer,
  last_shared_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select friend.id, friend.display_name, friend.username, friend.avatar_url,
    count(companion.visit_id)::integer,
    max(companion.created_at)
  from input
  join public.users friend
    on friend.id <> input.actor
   and private.confirmed_friends(input.actor, friend.id)
   and not private.blocked_between(input.actor, friend.id)
  left join public.visit_companions companion
    on companion.companion_user_id = friend.id and companion.added_by = input.actor
  where input.actor is not null
  group by friend.id
  order by count(companion.visit_id) desc, max(companion.created_at) desc nulls last,
           friend.display_name, friend.id
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke all on function public.set_visit_companions(uuid,uuid[]) from public, anon, authenticated;
revoke all on function public.companion_suggestions(integer) from public, anon, authenticated;
grant execute on function public.set_visit_companions(uuid,uuid[]) to authenticated;
grant execute on function public.companion_suggestions(integer) to authenticated;

-- Public profile payloads include Home and Recipe sips visible to the viewer,
-- but intentionally omit private notes, brew details, analysis output, and
-- private taste-signal evidence.
create or replace function public.get_public_profile(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
  result jsonb;
begin
  if viewer is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if private.blocked_between(viewer, p_user_id) then
    raise exception 'profile unavailable' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'profile', to_jsonb(profile),
    'friendship_state', case
      when viewer = p_user_id then 'self'
      when private.confirmed_friends(viewer, p_user_id) then 'friends'
      when exists (
        select 1 from public.friend_requests request
        where request.from_user_id = viewer and request.to_user_id = p_user_id and request.status = 'pending'
      ) then 'outgoing'
      when exists (
        select 1 from public.friend_requests request
        where request.from_user_id = p_user_id and request.to_user_id = viewer and request.status = 'pending'
      ) then 'incoming'
      else 'none'
    end,
    'stats', jsonb_build_object(
      'visible_visits', (
        select count(*) from public.visits visit
        where visit.user_id = p_user_id and private.can_view_visit_as(visit.id, viewer)
      ),
      'friends', (select count(*) from public.friends friend where friend.user_id = p_user_id),
      'cafes', (
        select count(distinct visit.cafe_id) from public.visits visit
        where visit.user_id = p_user_id and visit.cafe_id is not null
          and private.can_view_visit_as(visit.id, viewer)
      ),
      'home_sips', (
        select count(*) from public.visits visit
        where visit.user_id = p_user_id
          and lower(coalesce(visit.context_type, 'cafe')) <> 'cafe'
          and private.can_view_visit_as(visit.id, viewer)
      ),
      'recipe_sips', (
        select count(*) from public.visits visit
        where visit.user_id = p_user_id
          and lower(coalesce(visit.context_type, '')) = 'recipe'
          and private.can_view_visit_as(visit.id, viewer)
      )
    ),
    'visits', coalesce((
      select jsonb_agg(to_jsonb(visible_visit) order by visible_visit.created_at desc, visible_visit.id desc)
      from (
        select
          visit.id, visit.user_id, visit.cafe_id, visit.caption,
          visit.drink_type, visit.drink_type_custom, visit.drink_subtype,
          visit.visibility, visit.ratings, visit.overall_score,
          visit.poster_photo_url, visit.context_type, visit.location_name,
          visit.created_at, cafe.name cafe_name, cafe.city cafe_city,
          cafe.latitude, cafe.longitude, cafe.identity_key
        from public.visits visit
        left join public.cafes cafe on cafe.id = visit.cafe_id
        where visit.user_id = p_user_id
          and private.can_view_visit_as(visit.id, viewer)
        order by visit.created_at desc, visit.id desc
        limit 50
      ) visible_visit
    ), '[]'::jsonb)
  )
  into result
  from public.users profile
  where profile.id = p_user_id;

  if result is null then
    raise exception 'profile unavailable' using errcode = 'P0002';
  end if;
  return result;
end;
$$;

revoke all on function public.get_public_profile(uuid) from public, anon, authenticated;
grant execute on function public.get_public_profile(uuid) to authenticated;

-- Changing a non-espresso preparation clears any stale shot override so a
-- corrected matcha or tea can never continue displaying espresso controls.
create or replace function public.request_visit_drink_analysis_correction(
  p_visit_id uuid,
  p_overrides jsonb
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  allowed_keys constant text[] := array[
    'canonical_family', 'preparation', 'temperature',
    'espresso_shot_count', 'serving_volume_ml'
  ];
  clean_overrides jsonb := coalesce(p_overrides, '{}'::jsonb);
  espresso_preparations constant text[] := array[
    'espresso', 'americano', 'latte', 'cappuccino',
    'cortado', 'flat_white', 'mocha', 'macchiato'
  ];
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if jsonb_typeof(clean_overrides) <> 'object' then
    raise exception 'overrides must be an object' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_object_keys(clean_overrides) key
    where not (key = any(allowed_keys))
  ) then
    raise exception 'unsupported drink-analysis override' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.visits visit
    where visit.id = p_visit_id and visit.user_id = actor
  ) then
    raise exception 'visit ownership required' using errcode = '42501';
  end if;

  if clean_overrides ? 'preparation'
     and not ((clean_overrides ->> 'preparation') = any(espresso_preparations)) then
    clean_overrides := clean_overrides - 'espresso_shot_count';
    update public.visit_drink_analyses
    set user_overrides = coalesce(user_overrides, '{}'::jsonb) - 'espresso_shot_count'
    where visit_id = p_visit_id and user_id = actor;
  end if;

  update public.visit_drink_analyses
  set user_overrides = coalesce(user_overrides, '{}'::jsonb) || clean_overrides,
      processing_status = 'pending',
      estimated_caffeine_mg = null,
      caffeine_calculation_basis = null,
      caffeine_coverage = 'excluded',
      updated_at = now()
  where visit_id = p_visit_id and user_id = actor;
end;
$$;

revoke all on function public.request_visit_drink_analysis_correction(uuid,jsonb)
  from public, anon, authenticated;
grant execute on function public.request_visit_drink_analysis_correction(uuid,jsonb)
  to authenticated;
