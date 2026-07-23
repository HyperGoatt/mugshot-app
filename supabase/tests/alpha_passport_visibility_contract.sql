begin;

create temp table alpha_passport_users as
select id, row_number() over (order by id) n
from (select id from public.users order by id limit 3) users;
grant select on alpha_passport_users to authenticated;

do $$ begin
  if (select count(*) from alpha_passport_users) < 3 then
    raise exception 'alpha Passport contract requires three existing users';
  end if;
  if not exists (
    select 1
    from information_schema.columns column_contract
    where column_contract.table_schema = 'public'
      and column_contract.table_name = 'users'
      and column_contract.column_name = 'taste_passport_visibility'
      and column_contract.column_default like '%everyone%'
  ) then
    raise exception 'Taste Passport does not default to Everyone';
  end if;
  if has_function_privilege(
       'anon',
       'public.get_taste_passport_visibility_v1()',
       'EXECUTE'
     ) then
    raise exception 'anonymous role can read an owner Taste Passport audience';
  end if;
end $$;

delete from public.user_blocks
where blocker_id in (select id from alpha_passport_users)
  and blocked_id in (select id from alpha_passport_users);
delete from public.friends
where user_id in (select id from alpha_passport_users)
  and friend_user_id in (select id from alpha_passport_users);

update public.users
set taste_passport_visibility = 'everyone'
where id = (select id from alpha_passport_users where n = 1);

insert into public.taste_signals (
  user_id,
  signal_type,
  attribute,
  support_count,
  confidence,
  average_score,
  evidence_visit_ids,
  calculation_version
)
values
  (
    (select id from alpha_passport_users where n = 1),
    'order_preference',
    'alpha_contract_fruit_forward',
    1,
    0.8,
    null,
    array[gen_random_uuid()],
    'alpha-contract'
  ),
  (
    (select id from alpha_passport_users where n = 1),
    'sensory_evaluation',
    'alpha_contract_clarity',
    1,
    0.75,
    4.5,
    array[gen_random_uuid()],
    'alpha-contract'
  );

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_passport_users where n = 3),
  'role', 'authenticated'
)::text, true);

do $$
declare projection jsonb;
begin
  projection := public.get_taste_passport_v1(
    (select id from alpha_passport_users where n = 1)
  );
  if coalesce((projection ->> 'is_forming')::boolean, false) is not true then
    raise exception 'low-evidence Taste Passport was not marked forming';
  end if;
  if projection -> 'descriptors' <> jsonb_build_array(
       jsonb_build_object('kind', 'order_preference', 'label', 'Taste Forming'),
       jsonb_build_object('kind', 'sensory_lens', 'label', 'Lens Forming'),
       jsonb_build_object('kind', 'ritual', 'label', 'Ritual Forming')
     )
     or projection ->> 'description' <> 'This Taste Passport is forming with each logged sip.'
     or projection -> 'updated_at' is distinct from 'null'::jsonb
     or projection::text like '%alpha_contract_fruit_forward%'
     or projection::text like '%alpha_contract_clarity%' then
    raise exception 'forming Taste Passport leaked a provisional trait or evidence timestamp';
  end if;
end $$;

reset role;
update public.taste_signals
set support_count = 3,
    evidence_visit_ids = array[
      gen_random_uuid(), gen_random_uuid(), gen_random_uuid()
    ]
where user_id = (select id from alpha_passport_users where n = 1)
  and calculation_version = 'alpha-contract';

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_passport_users where n = 3),
  'role', 'authenticated'
)::text, true);

do $$
declare projection jsonb;
begin
  projection := public.get_taste_passport_v1(
    (select id from alpha_passport_users where n = 1)
  );
  if projection is null or projection ->> 'visibility' <> 'everyone' then
    raise exception 'Everyone-default Taste Passport was not public';
  end if;
  if jsonb_array_length(projection -> 'descriptors') <> 3 then
    raise exception 'Taste Passport did not return exactly three descriptors';
  end if;
  if projection::text like '%evidence_visit_ids%'
     or projection::text like '%support_count%'
     or projection::text like '%private_note%' then
    raise exception 'Taste Passport leaked raw evidence or private fields';
  end if;
  if exists (
    select 1
    from public.taste_signals
    where user_id = (select id from alpha_passport_users where n = 1)
  ) then
    raise exception 'stranger read owner-only raw taste signals';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_passport_users where n = 1),
  'role', 'authenticated'
)::text, true);
do $$
declare owner_setting jsonb;
begin
  owner_setting := public.get_taste_passport_visibility_v1();
  if owner_setting ->> 'user_id' <> (select id::text from alpha_passport_users where n = 1)
     or owner_setting ->> 'visibility' <> 'everyone' then
    raise exception 'owner-only Taste Passport visibility read was not account-bound';
  end if;
end $$;
do $$ begin
  perform public.set_taste_passport_visibility_v1(
    'private',
    (select id from alpha_passport_users where n = 2)
  );
  raise exception 'cross-account Taste Passport audience write was accepted';
exception
  when insufficient_privilege then null;
end $$;
select public.set_taste_passport_visibility_v1(
  'friends',
  (select id from alpha_passport_users where n = 1)
);
do $$
declare owner_setting jsonb;
begin
  owner_setting := public.get_taste_passport_visibility_v1();
  if owner_setting ->> 'visibility' <> 'friends' then
    raise exception 'Taste Passport visibility read did not confirm the saved audience';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_passport_users where n = 3),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if public.get_taste_passport_v1(
    (select id from alpha_passport_users where n = 1)
  ) is not null then
    raise exception 'stranger saw Friends Taste Passport';
  end if;
end $$;

reset role;
insert into public.friends (user_id, friend_user_id)
values
  ((select id from alpha_passport_users where n = 1),
   (select id from alpha_passport_users where n = 2)),
  ((select id from alpha_passport_users where n = 2),
   (select id from alpha_passport_users where n = 1))
on conflict do nothing;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_passport_users where n = 2),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if public.get_taste_passport_v1(
    (select id from alpha_passport_users where n = 1)
  ) is null then
    raise exception 'confirmed friend could not see Friends Taste Passport';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_passport_users where n = 1),
  'role', 'authenticated'
)::text, true);
select public.set_taste_passport_visibility_v1(
  'private',
  (select id from alpha_passport_users where n = 1)
);

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_passport_users where n = 2),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if public.get_taste_passport_v1(
    (select id from alpha_passport_users where n = 1)
  ) is not null then
    raise exception 'friend saw private Taste Passport';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_passport_users where n = 1),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if public.get_taste_passport_v1(
    (select id from alpha_passport_users where n = 1)
  ) is null then
    raise exception 'owner could not see private Taste Passport';
  end if;
end $$;

select public.set_taste_passport_visibility_v1(
  'everyone',
  (select id from alpha_passport_users where n = 1)
);
reset role;
insert into public.user_blocks (blocker_id, blocked_id)
values (
  (select id from alpha_passport_users where n = 1),
  (select id from alpha_passport_users where n = 2)
);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_passport_users where n = 2),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if public.get_taste_passport_v1(
    (select id from alpha_passport_users where n = 1)
  ) is not null then
    raise exception 'block did not sever Everyone Taste Passport visibility';
  end if;
end $$;

rollback;

select 'alpha_passport_visibility_contract_passed' as result;
