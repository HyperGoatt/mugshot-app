begin;

create temp table friend_cafe_users as
select id, row_number() over (order by id) n
from (select id from public.users order by id limit 3) users;
grant select on friend_cafe_users to authenticated;

do $$ begin
  if (select count(*) from friend_cafe_users) < 3 then
    raise exception 'friend cafe discovery contract requires three existing users';
  end if;
end $$;

delete from public.user_blocks
where blocker_id in (select id from friend_cafe_users)
  and blocked_id in (select id from friend_cafe_users);
delete from public.friends
where user_id in (select id from friend_cafe_users)
  and friend_user_id in (select id from friend_cafe_users);
delete from public.friend_requests
where from_user_id in (select id from friend_cafe_users)
  and to_user_id in (select id from friend_cafe_users);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from friend_cafe_users where n = 1),
  'role', 'authenticated'
)::text, true);
select public.send_friend_request((select id from friend_cafe_users where n = 2));

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from friend_cafe_users where n = 2),
  'role', 'authenticated'
)::text, true);
select public.respond_friend_request((
  select id
  from public.friend_requests
  where from_user_id = (select id from friend_cafe_users where n = 1)
    and to_user_id = (select id from friend_cafe_users where n = 2)
    and status = 'pending'
), true);
reset role;

create temp table friend_cafe_target(cafe_id uuid);
with inserted as (
  insert into public.cafes(name, address, latitude, longitude, identity_key)
  values (
    'Friend Cafe Contract ' || gen_random_uuid()::text,
    '1 Contract Way',
    40.4406,
    -79.9959,
    'temporary'
  )
  returning id
)
insert into friend_cafe_target select id from inserted;
grant select on friend_cafe_target to authenticated;

insert into public.visits(
  user_id, cafe_id, drink_type, caption, visibility, ratings,
  overall_score, context_type, brew_details, upload_state
)
values
  ((select id from friend_cafe_users where n = 1), (select cafe_id from friend_cafe_target),
   'Coffee', 'Owner evidence must be excluded', 'everyone', '{"Overall":1.25}'::jsonb,
   1.25, 'Cafe', '{}'::jsonb, 'complete'),
  ((select id from friend_cafe_users where n = 2), (select cafe_id from friend_cafe_target),
   'Coffee', 'Confirmed friend evidence', 'friends', '{"Overall":4.75}'::jsonb,
   4.75, 'Cafe', '{}'::jsonb, 'complete'),
  ((select id from friend_cafe_users where n = 3), (select cafe_id from friend_cafe_target),
   'Coffee', 'Stranger evidence must be excluded', 'everyone', '{"Overall":2.0}'::jsonb,
   2.0, 'Cafe', '{}'::jsonb, 'complete');

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from friend_cafe_users where n = 1),
  'role', 'authenticated'
)::text, true);

do $$
declare discovered record;
begin
  select * into discovered
  from public.discover_friend_cafes(null, null, 25, 50, null, null)
  where cafe_id = (select cafe_id from friend_cafe_target);

  if discovered.cafe_id is null then
    raise exception 'friend cafe discovery omitted a confirmed friend cafe';
  end if;
  if discovered.friend_count <> 1 or discovered.visible_visit_count <> 1 then
    raise exception 'friend cafe discovery mixed owner or stranger visits: friend_count=%, visit_count=%',
      discovered.friend_count, discovered.visible_visit_count;
  end if;
  if abs(discovered.average_rating - 4.75) > 0.0001 then
    raise exception 'friend cafe average was not friend-only';
  end if;
  if jsonb_array_length(discovered.friend_profiles) <> 1
     or discovered.friend_profiles->0->>'user_id' <> (select id::text from friend_cafe_users where n = 2) then
    raise exception 'friend cafe profiles exposed the wrong people';
  end if;
end $$;

reset role;
set local role anon;
do $$ begin
  begin
    perform * from public.discover_friend_cafes(null, null, 25, 20, null, null);
    raise exception 'anonymous friend cafe discovery unexpectedly succeeded';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;
rollback;
select 'friend_cafe_discovery_contract_passed' as result;
