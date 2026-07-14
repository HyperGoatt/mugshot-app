begin;

create temp table sprint_users as
select id, row_number() over (order by id) n
from (select id from public.users order by id limit 3) users;
grant select on sprint_users to authenticated, anon;

do $$ begin
  if (select count(*) from sprint_users) < 3 then
    raise exception 'follow-up sprint suite requires three existing users';
  end if;
  if not exists (select 1 from public.cafes) then
    raise exception 'follow-up sprint suite requires an existing cafe';
  end if;
end $$;

-- The signed-out projection is executable and every aggregate is based only
-- on complete Everyone visits.
create temp table expected_public_cafe_counts as
select cafe_id, count(*)::bigint visible_visit_count
from public.visits
where visibility = 'everyone'
  and upload_state = 'complete'
  and cafe_id is not null
group by cafe_id;
grant select on expected_public_cafe_counts to anon;

set local role anon;
do $$
declare discovered record;
begin
  perform * from public.discover_public_cafes('nearby', null, null, 25, 20, null, null);
  for discovered in
    select * from public.discover_public_cafes('nearby', null, null, 25, 50, null, null)
  loop
    if discovered.visible_visit_count <> coalesce((
      select expected.visible_visit_count
      from expected_public_cafe_counts expected
      where expected.cafe_id = discovered.cafe_id
    ), 0) then
      raise exception 'signed-out discovery included non-public visit evidence';
    end if;
  end loop;
end $$;
reset role;

delete from public.user_blocks
where blocker_id in (select id from sprint_users) and blocked_id in (select id from sprint_users);
delete from public.friends
where user_id in (select id from sprint_users) and friend_user_id in (select id from sprint_users);
delete from public.friend_requests
where from_user_id in (select id from sprint_users) and to_user_id in (select id from sprint_users);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from sprint_users where n=1), 'role', 'authenticated'
)::text, true);
select public.send_friend_request((select id from sprint_users where n=2));

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from sprint_users where n=2), 'role', 'authenticated'
)::text, true);
select public.respond_friend_request((
  select id from public.friend_requests
  where from_user_id = (select id from sprint_users where n=1)
    and to_user_id = (select id from sprint_users where n=2)
    and status = 'pending'
), true);

reset role;
create temp table sprint_visits(friend_visit uuid, home_visit uuid);
grant select on sprint_visits to authenticated;
do $$
declare friend_visit_id uuid; home_visit_id uuid;
begin
  insert into public.visits(
    user_id, cafe_id, drink_type, drink_subtype, caption, visibility,
    ratings, overall_score, context_type, brew_details, upload_state
  ) values (
    (select id from sprint_users where n=1),
    (select id from public.cafes order by id limit 1),
    'Coffee', 'Sprint companion cortado', 'Shared memory', 'friends',
    '{"Taste":4.5}'::jsonb, 4.5, 'Cafe', '{}', 'complete'
  ) returning id into friend_visit_id;

  insert into public.visits(
    user_id, cafe_id, drink_type, drink_subtype, caption, visibility,
    ratings, overall_score, context_type, location_name, brew_details, upload_state
  ) values (
    (select id from sprint_users where n=1), null,
    'Coffee', 'Sprint home Chemex', 'Visible Home journal entry', 'friends',
    '{"Aroma":4.0}'::jsonb, 4, 'Home', 'Home',
    '{"privateNotes":"contract-secret-must-not-leak"}'::jsonb, 'complete'
  ) returning id into home_visit_id;

  insert into sprint_visits values (friend_visit_id, home_visit_id);
end $$;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from sprint_users where n=1), 'role', 'authenticated'
)::text, true);

select public.set_visit_companions(
  (select friend_visit from sprint_visits),
  array[(select id from sprint_users where n=2)]
);

do $$ begin
  if not exists (
    select 1 from public.visit_companions
    where visit_id = (select friend_visit from sprint_visits)
      and companion_user_id = (select id from sprint_users where n=2)
  ) then raise exception 'owner could not attach a confirmed friend'; end if;
  if not exists (
    select 1 from public.companion_suggestions(10)
    where user_id = (select id from sprint_users where n=2)
      and shared_sip_count >= 1
  ) then raise exception 'companion suggestions did not learn from prior sips'; end if;
  begin
    perform public.set_visit_companions(
      (select friend_visit from sprint_visits),
      array[(select id from sprint_users where n=3)]
    );
    raise exception 'non-friend companion unexpectedly succeeded';
  exception when sqlstate '42501' then null;
  end;
end $$;

-- Friends and Everyone retain strict reverse chronological order. Your Mix
-- remains independently ranked and exposes a reason type.
do $$ begin
  if exists (
    select 1
    from (
      select created_at,
             lag(created_at) over (order by ordinal_position) previous_created_at
      from public.ranked_feed('friends', null, null, 50, null, null, null)
           with ordinality feed(visit_id,user_id,cafe_id,caption,drink_name,overall_score,
             poster_photo_url,created_at,author_display_name,author_username,author_avatar_url,
             cafe_name,like_count,comment_count,feed_score,ranking_reason,reason_type,ordinal_position)
    ) ordered
    where previous_created_at < created_at
  ) then raise exception 'Friends feed is not reverse chronological'; end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from sprint_users where n=2), 'role', 'authenticated'
)::text, true);
do $$
declare profile_payload jsonb;
begin
  profile_payload := public.get_public_profile((select id from sprint_users where n=1));
  if not exists (
    select 1 from jsonb_array_elements(profile_payload->'visits') visit
    where visit->>'id' = (select home_visit::text from sprint_visits)
      and lower(visit->>'context_type') = 'home'
  ) then raise exception 'friend profile omitted a visible Home sip'; end if;
  if profile_payload::text ilike '%contract-secret-must-not-leak%'
     or profile_payload::text ilike '%brew_details%'
     or profile_payload::text ilike '%private_notes%' then
    raise exception 'profile projection leaked private journal fields';
  end if;
end $$;

-- A stranger cannot inspect companion links on a Friends-only sip.
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from sprint_users where n=3), 'role', 'authenticated'
)::text, true);
do $$ begin
  if exists (
    select 1 from public.visit_companions
    where visit_id = (select friend_visit from sprint_visits)
  ) then raise exception 'stranger read Friends-only companion links'; end if;
end $$;

reset role;
rollback;
select 'followup_sprint_contract_passed' as result;
