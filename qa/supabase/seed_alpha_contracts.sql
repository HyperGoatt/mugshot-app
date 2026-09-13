-- Deterministic, non-production fixtures for the MugShot remote contract suite.
-- These identities cannot sign in: they have reserved .invalid emails and no
-- password or external identity. The remote runner refuses the production ref.

begin;

insert into auth.users (
  id,
  aud,
  role,
  email,
  email_confirmed_at,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at,
  is_anonymous
)
values
  (
    '00000000-0000-4000-8000-000000000101',
    'authenticated',
    'authenticated',
    'alpha-fixture-1@example.invalid',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"displayName":"Alpha One","username":"alpha_fixture_1"}'::jsonb,
    now() - interval '4 days',
    now() - interval '4 days',
    false
  ),
  (
    '00000000-0000-4000-8000-000000000102',
    'authenticated',
    'authenticated',
    'alpha-fixture-2@example.invalid',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"displayName":"Alpha Two","username":"alpha_fixture_2"}'::jsonb,
    now() - interval '3 days',
    now() - interval '3 days',
    false
  ),
  (
    '00000000-0000-4000-8000-000000000103',
    'authenticated',
    'authenticated',
    'alpha-fixture-3@example.invalid',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"displayName":"Alpha Three","username":"alpha_fixture_3"}'::jsonb,
    now() - interval '2 days',
    now() - interval '2 days',
    false
  ),
  (
    '00000000-0000-4000-8000-000000000104',
    'authenticated',
    'authenticated',
    'alpha-fixture-4@example.invalid',
    now(),
    '{"provider":"email","providers":["email"]}'::jsonb,
    '{"displayName":"Alpha Four","username":"alpha_fixture_4"}'::jsonb,
    now() - interval '1 day',
    now() - interval '1 day',
    false
  )
on conflict (id) do nothing;

insert into public.users (id, display_name, username)
values
  ('00000000-0000-4000-8000-000000000101', 'Alpha One', 'alpha_fixture_1'),
  ('00000000-0000-4000-8000-000000000102', 'Alpha Two', 'alpha_fixture_2'),
  ('00000000-0000-4000-8000-000000000103', 'Alpha Three', 'alpha_fixture_3'),
  ('00000000-0000-4000-8000-000000000104', 'Alpha Four', 'alpha_fixture_4')
on conflict (id) do update
set display_name = excluded.display_name,
    username = excluded.username;

insert into public.cafes (
  id,
  name,
  address,
  city,
  country,
  latitude,
  longitude,
  apple_place_id
)
values
  (
    '10000000-0000-4000-8000-000000000101',
    'Alpha Contract Cafe North',
    '101 Test Avenue',
    'New York',
    'US',
    40.7411,
    -73.9897,
    'alpha-contract-cafe-north'
  ),
  (
    '10000000-0000-4000-8000-000000000102',
    'Alpha Contract Cafe South',
    '102 Test Avenue',
    'New York',
    'US',
    40.7211,
    -73.9997,
    'alpha-contract-cafe-south'
  ),
  (
    '10000000-0000-4000-8000-000000000103',
    'Alpha Contract Cafe West',
    '103 Test Avenue',
    'Jersey City',
    'US',
    40.7180,
    -74.0436,
    'alpha-contract-cafe-west'
  ),
  (
    '10000000-0000-4000-8000-000000000104',
    'Alpha Contract Cafe East',
    '104 Test Avenue',
    'Brooklyn',
    'US',
    40.7306,
    -73.9352,
    'alpha-contract-cafe-east'
  ),
  (
    '10000000-0000-4000-8000-000000000105',
    'Alpha Contract Cafe Harbor',
    '105 Test Avenue',
    'Hoboken',
    'US',
    40.7357,
    -74.0301,
    'alpha-contract-cafe-harbor'
  ),
  (
    '10000000-0000-4000-8000-000000000106',
    'Alpha Contract Cafe Heights',
    '106 Test Avenue',
    'New York',
    'US',
    40.8448,
    -73.8648,
    'alpha-contract-cafe-heights'
  ),
  (
    '10000000-0000-4000-8000-000000000107',
    'Alpha Contract Cafe Park',
    '107 Test Avenue',
    'Brooklyn',
    'US',
    40.6602,
    -73.9690,
    'alpha-contract-cafe-park'
  ),
  (
    '10000000-0000-4000-8000-000000000108',
    'Alpha Contract Cafe River',
    '108 Test Avenue',
    'Queens',
    'US',
    40.7447,
    -73.9485,
    'alpha-contract-cafe-river'
  )
on conflict (id) do nothing;

insert into public.visits (
  id,
  user_id,
  cafe_id,
  drink_type,
  caption,
  visibility,
  ratings,
  overall_score,
  created_at,
  updated_at,
  context_type,
  category_scores,
  upload_state
)
values
  (
    '20000000-0000-4000-8000-000000000101',
    '00000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000101',
    'Latte',
    'Alpha fixture latte one',
    'everyone',
    '{"Overall":4.5}'::jsonb,
    4.5,
    now() - interval '8 days',
    now() - interval '8 days',
    'Cafe',
    '[]'::jsonb,
    'complete'
  ),
  (
    '20000000-0000-4000-8000-000000000102',
    '00000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000102',
    'Latte',
    'Alpha fixture latte two',
    'friends',
    '{"Overall":4.0}'::jsonb,
    4.0,
    now() - interval '7 days',
    now() - interval '7 days',
    'Cafe',
    '[]'::jsonb,
    'complete'
  ),
  (
    '20000000-0000-4000-8000-000000000103',
    '00000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000103',
    'Latte',
    'Alpha fixture latte three',
    'private',
    '{"Overall":3.5}'::jsonb,
    3.5,
    now() - interval '6 days',
    now() - interval '6 days',
    'Cafe',
    '[]'::jsonb,
    'complete'
  ),
  (
    '20000000-0000-4000-8000-000000000104',
    '00000000-0000-4000-8000-000000000101',
    '10000000-0000-4000-8000-000000000101',
    'Cappuccino',
    'Alpha fixture cappuccino',
    'everyone',
    '{"Overall":4.0}'::jsonb,
    4.0,
    now() - interval '5 days',
    now() - interval '5 days',
    'Cafe',
    '[]'::jsonb,
    'complete'
  ),
  (
    '20000000-0000-4000-8000-000000000105',
    '00000000-0000-4000-8000-000000000102',
    '10000000-0000-4000-8000-000000000101',
    'Espresso',
    'Alpha fixture espresso',
    'everyone',
    '{"balance":4.5}'::jsonb,
    4.5,
    now() - interval '4 days',
    now() - interval '4 days',
    'Cafe',
    '[]'::jsonb,
    'complete'
  ),
  (
    '20000000-0000-4000-8000-000000000106',
    '00000000-0000-4000-8000-000000000102',
    '10000000-0000-4000-8000-000000000102',
    'Cold Brew',
    'Alpha fixture cold brew',
    'friends',
    '{"balance":4.0}'::jsonb,
    4.0,
    now() - interval '3 days',
    now() - interval '3 days',
    'Cafe',
    '[]'::jsonb,
    'complete'
  ),
  (
    '20000000-0000-4000-8000-000000000107',
    '00000000-0000-4000-8000-000000000103',
    '10000000-0000-4000-8000-000000000103',
    'Pour Over',
    'Alpha fixture pour over',
    'everyone',
    '{"clarity":4.5}'::jsonb,
    4.5,
    now() - interval '2 days',
    now() - interval '2 days',
    'Cafe',
    '[]'::jsonb,
    'complete'
  ),
  (
    '20000000-0000-4000-8000-000000000108',
    '00000000-0000-4000-8000-000000000104',
    '10000000-0000-4000-8000-000000000101',
    'Mocha',
    'Alpha fixture mocha',
    'everyone',
    '{"sweetness":4.5}'::jsonb,
    4.5,
    now() - interval '1 day',
    now() - interval '1 day',
    'Cafe',
    '[]'::jsonb,
    'complete'
  )
on conflict (id) do update
set ratings = excluded.ratings,
    category_scores = excluded.category_scores,
    overall_score = excluded.overall_score,
    visibility = excluded.visibility,
    upload_state = excluded.upload_state;

select public.refresh_taste_signals(fixture.id)
from (
  values
    ('00000000-0000-4000-8000-000000000101'::uuid),
    ('00000000-0000-4000-8000-000000000102'::uuid),
    ('00000000-0000-4000-8000-000000000103'::uuid),
    ('00000000-0000-4000-8000-000000000104'::uuid)
) as fixture(id);

-- These reserved fixtures represent already-admitted public profiles/content.
-- Tests creating or editing shared content still need an explicit review step;
-- no trigger auto-approves later test mutations. No provider request is made.
do $fixtures$
declare
  fixture_owner uuid;
  fixture_index integer;
  job private.screening_jobs;
  owners uuid[] := array[
    '00000000-0000-4000-8000-000000000101'::uuid,
    '00000000-0000-4000-8000-000000000102'::uuid,
    '00000000-0000-4000-8000-000000000103'::uuid,
    '00000000-0000-4000-8000-000000000104'::uuid
  ];
  fixture_visit_ids uuid[] := array[
    '20000000-0000-4000-8000-000000000101'::uuid,
    '20000000-0000-4000-8000-000000000102'::uuid,
    '20000000-0000-4000-8000-000000000103'::uuid,
    '20000000-0000-4000-8000-000000000104'::uuid,
    '20000000-0000-4000-8000-000000000105'::uuid,
    '20000000-0000-4000-8000-000000000106'::uuid,
    '20000000-0000-4000-8000-000000000107'::uuid,
    '20000000-0000-4000-8000-000000000108'::uuid
  ];
begin
  if current_setting('mugshot.qa_contract', true) is distinct from 'isolated' then
    raise exception 'Explicit isolated QA mode is required for fixture admission';
  end if;
  for fixture_index in 1..array_length(owners,1) loop
    fixture_owner:=owners[fixture_index];
    if not exists(select 1 from auth.users where id=fixture_owner
      and email='alpha-fixture-'||fixture_index||'@example.invalid') then
      raise exception 'Reserved non-sign-in QA identity is missing';
    end if;
    perform set_config('request.jwt.claims',jsonb_build_object('sub',fixture_owner,'role','authenticated')::text,true);
    perform public.set_profile_friends_visibility_v2(true,1);
  end loop;
  -- Simulate completion of the exact queued revision, preserving the real
  -- publication transition and its downstream activity handling.
  for job in select * from private.screening_jobs
    where (subject_kind='user' and subject_id=any(owners))
      or (subject_kind='visit' and subject_id=any(fixture_visit_ids)) loop
    if not (job.owner_id=any(owners)) then
      raise exception 'Fixture content belongs to a non-fixture owner';
    end if;
    if job.state='approved' then continue;end if;
    if job.state<>'pending' then raise exception 'Fixture has an unexpected review state';end if;
    update private.screening_jobs set lease_token=gen_random_uuid(),
      lease_until=now()+interval '1 minute',attempts=greatest(attempts,1)
      where subject_kind=job.subject_kind and subject_id=job.subject_id
      returning * into job;
    if not public.finish_screening_job_v1(job.subject_kind,job.subject_id,job.revision,
      job.lease_token,'approved','{"categories":{"sexual":false}}'::jsonb) then
      raise exception 'Synthetic fixture review did not finish';
    end if;
  end loop;
  if exists(select 1 from public.users where id=any(owners)
      and not private.screening_approved_v1('user',id))
    or exists(select 1 from public.visits where id=any(fixture_visit_ids) and visibility<>'private'
      and not private.screening_approved_v1('visit',id))
    or exists(select 1 from private.screening_jobs q join public.visits v on v.id=q.subject_id
      where q.subject_kind='visit' and v.id=any(fixture_visit_ids) and v.visibility='private') then
    raise exception 'Fixture admission or Private exclusion is incomplete';
  end if;
  perform set_config('request.jwt.claims','{}',true);
end;
$fixtures$;

commit;
