\set ON_ERROR_STOP on

begin;

do $$
begin
  if to_regclass('public.visit_v3_reflections') is null then
    raise exception 'V3 visit-reflection table is missing';
  end if;

  if not exists (
    select 1
    from pg_class relation
    join pg_namespace namespace on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname = 'visit_v3_reflections'
      and relation.relrowsecurity
      and relation.relforcerowsecurity
  ) then
    raise exception 'V3 visit reflections must force RLS';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'visit_v3_reflections'
      and grantee = 'anon'
  ) then
    raise exception 'anonymous role has a direct V3 reflection table grant';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name = 'visit_v3_reflections'
      and grantee = 'authenticated'
      and privilege_type <> 'SELECT'
  ) then
    raise exception 'authenticated clients can bypass the V3 reflection write RPC';
  end if;

  if has_function_privilege(
       'anon',
       'public.upsert_visit_v3_reflection_v1(uuid,integer,numeric,jsonb,text,text,text,text,text)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.upsert_visit_v3_reflection_v1(uuid,integer,numeric,jsonb,text,text,text,text,text)',
       'EXECUTE'
     )
     or has_function_privilege(
       'anon',
       'public.get_visit_v3_reflection_v1(uuid)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.get_visit_v3_reflection_v1(uuid)',
       'EXECUTE'
     )
     or has_function_privilege(
       'anon',
       'public.get_visit_v3_feed_projections_v1(uuid[])',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.get_visit_v3_feed_projections_v1(uuid[])',
       'EXECUTE'
     ) then
    raise exception 'V3 reflection RPC grants are incorrect';
  end if;

  if exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'upsert_visit_v3_reflection_v1',
        'get_visit_v3_reflection_v1',
        'get_visit_v3_feed_projections_v1'
      )
      and (not procedure.prosecdef or not procedure.proconfig @> array['search_path=""'])
  ) then
    raise exception 'V3 reflection RPC is not safely isolated';
  end if;

  if exists (
    select 1
    from pg_constraint constraint_record
    where constraint_record.conname in (
      'cafe_experience_snapshots_rating_half_step',
      'cafe_experience_public_projection_rating_half_step'
    )
  ) then
    raise exception 'legacy cafe half-step constraint remains installed';
  end if;

  if (
    select count(*)
    from pg_constraint constraint_record
    where constraint_record.conname in (
      'cafe_experience_snapshots_rating_tenth_step',
      'cafe_experience_public_projection_rating_tenth_step'
    )
      and pg_get_constraintdef(constraint_record.oid) ilike '%10%trunc%'
  ) <> 2 then
    raise exception 'cafe tenth-step constraints are incomplete';
  end if;
end;
$$;

create temp table v3_reflection_test_context as
with ordered_users as (
  select id, row_number() over (order by created_at, id) as position
  from public.users
)
select
  (max(id::text) filter (where position = 1))::uuid as owner_id,
  (max(id::text) filter (where position = 2))::uuid as viewer_id,
  gen_random_uuid() as visit_id
from ordered_users;

grant select on v3_reflection_test_context to authenticated;

do $$
begin
  if exists (
    select 1
    from v3_reflection_test_context
    where owner_id is null or viewer_id is null
  ) then
    raise exception 'V3 reflection behavior contract requires two users';
  end if;
end;
$$;

delete from public.user_blocks
where (blocker_id, blocked_id) in (
  select owner_id, viewer_id from v3_reflection_test_context
  union all
  select viewer_id, owner_id from v3_reflection_test_context
);

delete from public.friends
where (user_id, friend_user_id) in (
  select owner_id, viewer_id from v3_reflection_test_context
  union all
  select viewer_id, owner_id from v3_reflection_test_context
);

insert into public.visits (
  id,
  user_id,
  drink_type,
  drink_subtype,
  caption,
  visibility,
  ratings,
  overall_score,
  context_type,
  location_name,
  upload_state
)
select
  visit_id,
  owner_id,
  'Coffee',
  'V3 reflection contract sip',
  'Contract memory',
  'everyone',
  '{"overall":4}'::jsonb,
  4,
  'Cafe',
  'Contract Cafe',
  'complete'
from v3_reflection_test_context;

insert into public.visits (
  id,
  user_id,
  drink_type,
  drink_subtype,
  caption,
  visibility,
  ratings,
  overall_score,
  context_type,
  location_name,
  upload_state
)
select
  gen_random_uuid(),
  test_context.owner_id,
  'Coffee',
  context_row.drink_name,
  'Context contract memory',
  'everyone',
  '{"overall":4}'::jsonb,
  4,
  context_row.context_type,
  context_row.location_name,
  'complete'
from v3_reflection_test_context test_context
cross join (values
  ('Home', 'Contract home sip', 'Home'),
  ('Recipe', 'Contract recipe sip', 'Home Cafe'),
  ('Elsewhere', 'Contract train sip', 'Coast Starlight')
) as context_row(context_type, drink_name, location_name);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from v3_reflection_test_context),
    'role', 'authenticated'
  )::text,
  true
);

select *
from public.upsert_visit_v3_reflection_v1(
  p_visit_id => (select visit_id from v3_reflection_test_context),
  p_schema_version => 1,
  p_context_score => 2.8,
  p_context_criteria => jsonb_build_array(jsonb_build_object(
    'id', gen_random_uuid(),
    'name', 'Atmosphere',
    'score', 2.8,
    'weight', 1.5,
    'sortOrder', 0,
    'relevanceOverride', true
  )),
  p_sip_raw_note => 'Owner sip journal words',
  p_context_raw_note => 'Owner context journal words',
  p_raw_note_visibility => 'private',
  p_photo_fallback => 'mugsy_missed_photo',
  p_home_make_again => null
);

do $$
begin
  if not exists (
    select 1
    from public.visit_v3_reflections reflection
    where reflection.visit_id = (select visit_id from v3_reflection_test_context)
      and reflection.user_id = (select owner_id from v3_reflection_test_context)
      and reflection.sip_score = 4.0
      and reflection.context_score = 2.8
      and reflection.mugshot_score = 3.4
      and reflection.sip_raw_note = 'Owner sip journal words'
  ) then
    raise exception 'owner upsert or one-decimal Mugshot derivation failed';
  end if;

  begin
    update public.visit_v3_reflections
    set context_score = 5
    where visit_id = (select visit_id from v3_reflection_test_context);
    raise exception 'owner directly updated an RPC-only V3 reflection';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from v3_reflection_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare
  profile_payload jsonb;
  expected_home_sips integer;
  expected_recipe_sips integer;
begin
  if exists (
    select 1
    from public.visit_v3_reflections
    where visit_id = (select visit_id from v3_reflection_test_context)
  ) then
    raise exception 'non-owner directly read the owner V3 reflection row';
  end if;

  if not exists (
    select 1
    from public.get_visit_v3_reflection_v1(
      (select visit_id from v3_reflection_test_context)
    ) visible
    where visible.mugshot_score = 3.4
      and visible.sip_raw_note is null
      and visible.context_raw_note is null
  ) then
    raise exception 'private raw notes were exposed or visible scores were withheld';
  end if;

  if not exists (
    select 1
    from public.get_visit_v3_feed_projections_v1(
      array[(select visit_id from v3_reflection_test_context)]
    ) projection
    where projection.mugshot_score = 3.4
      and projection.photo_fallback = 'mugsy_missed_photo'
  ) then
    raise exception 'feed-safe V3 score or photo projection was withheld';
  end if;

  profile_payload := public.get_public_profile(
    (select owner_id from v3_reflection_test_context)
  );
  select count(*) into expected_home_sips
  from public.visits visit
  where visit.user_id = (select owner_id from v3_reflection_test_context)
    and lower(coalesce(visit.context_type, '')) = 'home'
    and public.can_view_visit(
      visit.id,
      (select viewer_id from v3_reflection_test_context)
    );
  select count(*) into expected_recipe_sips
  from public.visits visit
  where visit.user_id = (select owner_id from v3_reflection_test_context)
    and lower(coalesce(visit.context_type, '')) = 'recipe'
    and public.can_view_visit(
      visit.id,
      (select viewer_id from v3_reflection_test_context)
    );
  if (profile_payload #>> '{stats,home_sips}')::integer <> expected_home_sips
     or (profile_payload #>> '{stats,recipe_sips}')::integer <> expected_recipe_sips then
    raise exception 'Home, Recipe, and Elsewhere profile counts were conflated';
  end if;

  begin
    perform 1
    from public.get_visit_v3_feed_projections_v1(
      array_fill(gen_random_uuid(), array[101])
    );
    raise exception 'feed projection accepted more than 100 visit ids';
  exception when invalid_parameter_value then
    null;
  end;

  begin
    perform public.upsert_visit_v3_reflection_v1(
      p_visit_id => (select visit_id from v3_reflection_test_context),
      p_context_score => 5,
      p_raw_note_visibility => 'private'
    );
    raise exception 'non-owner upserted another account reflection';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from v3_reflection_test_context),
    'role', 'authenticated'
  )::text,
  true
);

select * from public.upsert_visit_v3_reflection_v1(
  p_visit_id => (select visit_id from v3_reflection_test_context),
  p_context_score => 2.8,
  p_context_criteria => '[]'::jsonb,
  p_sip_raw_note => 'Everyone can read this sip note',
  p_context_raw_note => 'Everyone can read this context note',
  p_raw_note_visibility => 'everyone'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from v3_reflection_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not exists (
    select 1
    from public.get_visit_v3_reflection_v1(
      (select visit_id from v3_reflection_test_context)
    ) visible
    where visible.sip_raw_note = 'Everyone can read this sip note'
      and visible.context_raw_note = 'Everyone can read this context note'
  ) then
    raise exception 'Everyone raw-note audience was not honored';
  end if;
end;
$$;

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from v3_reflection_test_context),
    'role', 'authenticated'
  )::text,
  true
);

select * from public.upsert_visit_v3_reflection_v1(
  p_visit_id => (select visit_id from v3_reflection_test_context),
  p_context_score => 2.8,
  p_context_criteria => '[]'::jsonb,
  p_sip_raw_note => 'Friends can read this sip note',
  p_context_raw_note => 'Friends can read this context note',
  p_raw_note_visibility => 'friends'
);

reset role;
set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from v3_reflection_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not exists (
    select 1
    from public.get_visit_v3_reflection_v1(
      (select visit_id from v3_reflection_test_context)
    ) visible
    where visible.sip_raw_note is null
      and visible.context_raw_note is null
  ) then
    raise exception 'Friends raw notes leaked to a non-friend';
  end if;
end;
$$;

reset role;

insert into public.friends (user_id, friend_user_id)
select owner_id, viewer_id from v3_reflection_test_context
on conflict do nothing;
insert into public.friends (user_id, friend_user_id)
select viewer_id, owner_id from v3_reflection_test_context
on conflict do nothing;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from v3_reflection_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not exists (
    select 1
    from public.get_visit_v3_reflection_v1(
      (select visit_id from v3_reflection_test_context)
    ) visible
    where visible.sip_raw_note = 'Friends can read this sip note'
      and visible.context_raw_note = 'Friends can read this context note'
  ) then
    raise exception 'confirmed friend could not read Friends raw notes';
  end if;
end;
$$;

reset role;

insert into public.user_blocks (blocker_id, blocked_id)
select owner_id, viewer_id from v3_reflection_test_context;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from v3_reflection_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if exists (
    select 1
    from public.get_visit_v3_reflection_v1(
      (select visit_id from v3_reflection_test_context)
    )
  ) then
    raise exception 'blocked viewer received a V3 reflection';
  end if;

  if exists (
    select 1
    from public.get_visit_v3_feed_projections_v1(
      array[(select visit_id from v3_reflection_test_context)]
    )
  ) then
    raise exception 'blocked viewer received a V3 feed projection';
  end if;
end;
$$;

reset role;

delete from public.user_blocks
where (blocker_id, blocked_id) in (
  select owner_id, viewer_id from v3_reflection_test_context
  union all
  select viewer_id, owner_id from v3_reflection_test_context
);

update public.visits
set visibility = 'friends'
where id = (select visit_id from v3_reflection_test_context);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from v3_reflection_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.upsert_visit_v3_reflection_v1(
      p_visit_id => (select visit_id from v3_reflection_test_context),
      p_context_score => 2.8,
      p_context_criteria => '[]'::jsonb,
      p_sip_raw_note => 'Must not broaden past the post',
      p_raw_note_visibility => 'everyone'
    );
    raise exception 'raw-note audience broadened past visit audience';
  exception when invalid_parameter_value then
    null;
  end;
end;
$$;

rollback;

select 'v3_visit_reflections_contract_passed' as result;
