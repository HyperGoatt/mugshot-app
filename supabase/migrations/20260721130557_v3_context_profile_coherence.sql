begin;

-- Keep Home, Recipe, and Elsewhere as distinct first-class contexts in public
-- profile stats, and never hydrate stale cafe data for a non-cafe memory.
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
        where visit.user_id = p_user_id
          and visit.cafe_id is not null
          and lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
          and private.can_view_visit_as(visit.id, viewer)
      ),
      'home_sips', (
        select count(*) from public.visits visit
        where visit.user_id = p_user_id
          and lower(coalesce(visit.context_type, '')) = 'home'
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
        left join public.cafes cafe
          on cafe.id = visit.cafe_id
         and lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
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

revoke all on function public.get_public_profile(uuid)
  from public, anon, authenticated;
grant execute on function public.get_public_profile(uuid)
  to authenticated;

comment on function public.get_public_profile(uuid) is
  'Caller-bound public profile with exact Cafe, Home, Recipe, and Elsewhere context semantics.';

commit;
