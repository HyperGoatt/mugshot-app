begin;
create temp table contract_ids as
select id,username,row_number() over(order by id) n
from (select id,username from public.users order by id limit 2) u;
grant select on contract_ids to authenticated;

set local role authenticated;
select set_config('request.jwt.claims',jsonb_build_object('sub',(select id from contract_ids where n=1),'role','authenticated')::text,true);

do $$
declare
  v_target uuid := (select id from contract_ids where n=2);
  v_username text := (select username from contract_ids where n=2);
  v_first public.cafes;
  v_profile jsonb;
  v_first_page uuid[];
  v_second_page uuid[];
  v_cursor_score double precision;
  v_cursor_id uuid;
begin
  -- Exact username outranks prefix/fuzzy results.
  if (select username from public.search_users(v_username,20) limit 1) <> v_username then
    raise exception 'exact username was not ranked first';
  end if;

  -- Denied/unavailable location still returns useful community discovery.
  if not exists(select 1 from public.discover_cafes('nearby',null,null,25,20,null,null)) then
    raise exception 'location-free discovery returned no cafes';
  end if;

  -- Allowed location produces bounded distances. Invalid coordinates are
  -- treated as unavailable, never persisted or rejected as a server error.
  select * into v_first from public.cafes where latitude is not null and longitude is not null limit 1;
  if exists(
    select 1 from public.discover_cafes('nearby',v_first.latitude,v_first.longitude,25,50,null,null)
    where distance_km > 25.0001
  ) then raise exception 'radius filter returned a distant cafe'; end if;
  perform * from public.discover_cafes('nearby',1000,1000,25,5,null,null);
  perform * from public.discover_cafes('nearby',0,0,25,5,null,null);

  -- MapKit selections resolve back to one canonical backend cafe with the
  -- viewer-safe aggregate contract used by map and Saved cards.
  if not exists(
    select 1
    from public.resolve_cafe_summary(
      v_first.name,
      v_first.latitude,
      v_first.longitude,
      v_first.apple_place_id
    ) resolved
    where resolved.cafe_id = v_first.id
  ) then raise exception 'canonical cafe summary did not resolve'; end if;

  -- Discovery keyset pages never overlap.
  select array_agg(cafe_id order by ranking_score desc,cafe_id desc)
    into v_first_page
  from public.discover_cafes('nearby',null,null,25,5,null,null);
  select ranking_score,cafe_id into v_cursor_score,v_cursor_id
  from public.discover_cafes('nearby',null,null,25,5,null,null)
  order by ranking_score desc,cafe_id desc offset 4 limit 1;
  select array_agg(cafe_id) into v_second_page
  from public.discover_cafes('nearby',null,null,25,5,v_cursor_score,v_cursor_id);
  if v_first_page && coalesce(v_second_page,'{}'::uuid[]) then
    raise exception 'discovery cursor returned duplicate cafes';
  end if;

  -- Profile map payloads are exclusively canonical cafe-backed visits.
  v_profile := public.get_public_profile(v_target);
  if exists(
    select 1 from jsonb_array_elements(v_profile->'visits') visit
    where visit->>'cafe_id' is null or visit->>'identity_key' is null
       or visit->>'latitude' is null or visit->>'longitude' is null
  ) then raise exception 'profile map exposed a non-cafe visit'; end if;

  -- All feed scopes execute with stable cursor contracts, including empty sets.
  perform * from public.ranked_feed('ranked',null,null,10,null,null,null);
  perform * from public.ranked_feed('friends',null,null,10,null,null,null);
  perform * from public.ranked_feed('everyone',null,null,10,null,null,null);
end $$;

reset role;
rollback;
select 'discovery_social_contract_passed' as result;
