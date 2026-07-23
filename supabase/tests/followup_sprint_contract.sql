begin;

create temp table sprint_users as
select id, row_number() over (order by id) n
from (
  select profile.id
  from public.users profile
  join auth.users account on account.id = profile.id
  where account.deleted_at is null
    and not private.has_active_moderation_action(
      'user', profile.id, array['account_suspended']::text[]
    )
    and not private.account_deletion_active_as(profile.id)
  order by profile.id
  limit 3
) users;
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
where private.is_public_visit_discoverable_v3(id)
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

-- A signed-out cafe aggregate, cover, and drink disappear atomically while
-- its only post or author is enforced, then return after revocation.
create temp table sprint_public_projection_target(cafe_id uuid, visit_id uuid, cover text);
with cafe as (
  insert into public.cafes(name, address, latitude, longitude, identity_key)
  values (
    'Projection Cafe ' || gen_random_uuid()::text,
    '1 Projection Way',
    11.12345,
    22.54321,
    'temporary'
  )
  returning id
), visit as (
  insert into public.visits(
    user_id, cafe_id, drink_type, drink_subtype, caption, visibility,
    ratings, overall_score, context_type, brew_details, upload_state,
    poster_photo_url
  )
  select
    (select id from sprint_users where n = 1),
    cafe.id,
    'Coffee',
    'Projection cortado',
    'Projection contract',
    'everyone',
    '{"Overall":4.6}'::jsonb,
    4.6,
    'Cafe',
    '{}'::jsonb,
    'complete',
    'https://example.invalid/projection-cover.jpg'
  from cafe
  returning id, cafe_id, poster_photo_url
)
insert into sprint_public_projection_target
select cafe_id, id, poster_photo_url from visit;
grant select on sprint_public_projection_target to anon;

set local role anon;
do $$
declare discovered record;
begin
  select * into discovered
  from public.discover_public_cafes(
    'nearby', 11.12345, 22.54321, 1, 50, null, null
  )
  where cafe_id = (select cafe_id from sprint_public_projection_target);
  if discovered.cafe_id is null
     or discovered.visible_visit_count <> 1
     or discovered.recent_cover <>
       (select cover from sprint_public_projection_target) then
    raise exception 'eligible signed-out projection fixture is incomplete';
  end if;
end;
$$;
reset role;

insert into private.moderation_actions(
  subject_kind, subject_id, action_kind, reason_code
) values (
  'user', (select id from sprint_users where n = 1),
  'account_suspended', 'public_projection_contract'
);
set local role anon;
do $$ begin
  if exists (
    select 1 from public.discover_public_cafes(
      'nearby', 11.12345, 22.54321, 1, 50, null, null
    )
    where cafe_id = (select cafe_id from sprint_public_projection_target)
  ) then
    raise exception 'suspended author still drives signed-out Map discovery';
  end if;
end $$;
reset role;
delete from private.moderation_actions
where subject_kind = 'user'
  and subject_id = (select id from sprint_users where n = 1)
  and reason_code = 'public_projection_contract';

insert into private.moderation_actions(
  subject_kind, subject_id, action_kind, reason_code
) values (
  'visit', (select visit_id from sprint_public_projection_target),
  'content_hidden', 'public_projection_contract'
);
set local role anon;
do $$ begin
  if exists (
    select 1 from public.discover_public_cafes(
      'nearby', 11.12345, 22.54321, 1, 50, null, null
    )
    where cafe_id = (select cafe_id from sprint_public_projection_target)
  ) then
    raise exception 'hidden post still drives signed-out Map discovery';
  end if;
end $$;
reset role;
delete from private.moderation_actions
where subject_kind = 'visit'
  and subject_id = (select visit_id from sprint_public_projection_target)
  and reason_code = 'public_projection_contract';

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

reset role;
insert into private.moderation_actions(
  subject_kind, subject_id, action_kind, reason_code
) values (
  'user', (select id from sprint_users where n = 2),
  'account_suspended', 'companion_projection_contract'
);
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from sprint_users where n=1), 'role', 'authenticated'
)::text, true);
do $$ begin
  if exists (
    select 1 from public.companion_suggestions(10)
    where user_id = (select id from sprint_users where n = 2)
  ) then
    raise exception 'suspended companion remained selectable';
  end if;
end $$;
reset role;
delete from private.moderation_actions
where subject_kind = 'user'
  and subject_id = (select id from sprint_users where n = 2)
  and reason_code = 'companion_projection_contract';
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from sprint_users where n=1), 'role', 'authenticated'
)::text, true);
do $$ begin
  if not exists (
    select 1 from public.companion_suggestions(10)
    where user_id = (select id from sprint_users where n = 2)
  ) then
    raise exception 'companion did not return after suspension revocation';
  end if;
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
