\set ON_ERROR_STOP on

begin;

create temp table tasting_lens_test_context (
  visit_id uuid not null,
  owner_id uuid not null,
  stranger_id uuid not null,
  snapshot_id uuid not null,
  correction_id uuid not null,
  stranger_can_view boolean not null,
  identity jsonb not null,
  responses jsonb not null,
  snapshot_payload jsonb not null,
  created_at timestamptz not null
);

insert into tasting_lens_test_context
select
  candidate.visit_id,
  candidate.owner_id,
  candidate.stranger_id,
  ids.snapshot_id,
  ids.correction_id,
  private.can_view_visit_as(candidate.visit_id, candidate.stranger_id),
  fixture.identity,
  '[]'::jsonb,
  jsonb_build_object(
    'id', ids.snapshot_id,
    'schemaVersion', 1,
    'bundleID', 'mugshot.sensory',
    'bundleContentVersion', '2026.07.16.1',
    'identity', fixture.identity,
    'personalizationScopeID', 'matcha_latte.whisked_powder',
    'depth', 'guided',
    'ownWords', 'creamy, grassy, vanilla',
    'responses', '[]'::jsonb,
    'personalEnjoyment', 4.5,
    'createdAt', to_char(clock_timestamp() at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"')
  ),
  clock_timestamp()
from lateral (
  select visit.id as visit_id, visit.user_id as owner_id, stranger.id as stranger_id
  from public.visits visit
  cross join lateral (
    select id
    from public.users
    where id <> visit.user_id
    order by created_at, id
    limit 1
  ) stranger
  where not exists (
    select 1 from public.visit_sensory_snapshots snapshot where snapshot.visit_id = visit.id
  )
  order by visit.created_at, visit.id
  limit 1
) candidate
cross join lateral (
  select gen_random_uuid() as snapshot_id, gen_random_uuid() as correction_id
) ids
cross join lateral (
  select jsonb_build_object(
    'rawName', 'Iced matcha latte',
    'family', 'matcha_latte',
    'preparation', 'whisked_powder',
    'temperature', 'iced',
    'milk', 'oat milk',
    'sweeteners', jsonb_build_array('vanilla syrup'),
    'flavors', jsonb_build_array('vanilla'),
    'additions', jsonb_build_array('vanilla syrup'),
    'modifiers', '[]'::jsonb,
    'confidence', 1.0,
    'provenance', 'user',
    'userConfirmed', true
  ) as identity
) fixture;

grant select on tasting_lens_test_context to authenticated;

do $$ begin
  if not exists (select 1 from tasting_lens_test_context) then
    raise exception 'Tasting Lens contract requires one unsnapshotted visit and two users';
  end if;
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'visit_sensory_public_projections'
      and column_name in ('own_words', 'responses', 'snapshot_payload')
  ) then
    raise exception 'lossy sensory projection exposes authored answer fields';
  end if;
end $$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from tasting_lens_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$ begin
  begin
    insert into public.visit_sensory_snapshots (
      visit_id, snapshot_id, user_id, schema_version, bundle_id,
      bundle_content_version, personalization_scope_id, depth, identity,
      responses, own_words, personal_enjoyment, snapshot_payload, payload_hash, created_at
    ) select
      visit_id, snapshot_id, owner_id, 1, 'mugshot.sensory',
      '2026.07.16.1', 'matcha_latte.whisked_powder', 'guided', identity,
      responses, 'creamy, grassy, vanilla', 4.5,
      snapshot_payload || jsonb_build_object('id', gen_random_uuid()), repeat('a', 64), created_at
    from tasting_lens_test_context;
    raise exception 'snapshot accepted contradictory canonical payload fields';
  exception when check_violation then null;
  end;
end $$;

insert into public.visit_sensory_snapshots (
  visit_id, snapshot_id, user_id, schema_version, bundle_id,
  bundle_content_version, personalization_scope_id, depth, identity,
  responses, own_words, personal_enjoyment, snapshot_payload, payload_hash, created_at
) select
  visit_id, snapshot_id, owner_id, 1, 'mugshot.sensory',
  '2026.07.16.1', 'matcha_latte.whisked_powder', 'guided', identity,
  responses, 'creamy, grassy, vanilla', 4.5, snapshot_payload, repeat('a', 64), created_at
from tasting_lens_test_context;

do $$ begin
  if not exists (
    select 1 from public.visit_sensory_snapshots snapshot
    where snapshot.snapshot_id = (select snapshot_id from tasting_lens_test_context)
      and snapshot.user_id = (select owner_id from tasting_lens_test_context)
  ) then
    raise exception 'owner snapshot insert/read failed';
  end if;

  begin
    update public.visit_sensory_snapshots
    set own_words = 'rewritten'
    where snapshot_id = (select snapshot_id from tasting_lens_test_context);
    raise exception 'authenticated owner updated immutable snapshot';
  exception when insufficient_privilege then null;
  end;

  begin
    delete from public.visit_sensory_snapshots
    where snapshot_id = (select snapshot_id from tasting_lens_test_context);
    raise exception 'authenticated owner deleted immutable snapshot';
  exception when insufficient_privilege then null;
  end;

  begin
    insert into public.visit_sensory_public_projections (
      visit_id, snapshot_id, user_id, bundle_id, bundle_content_version,
      depth, personal_enjoyment, descriptor_ids, dimension_ids
    ) select visit_id, snapshot_id, owner_id, 'mugshot.sensory', '2026.07.16.1',
      'guided', 4.6, array['descriptor.texture.creamy'], array['texture']
    from tasting_lens_test_context;
    raise exception 'projection accepted a non-half-step personal rating';
  exception when check_violation then null;
  end;

  begin
    insert into public.visit_sensory_public_projections (
      visit_id, snapshot_id, user_id, bundle_id, bundle_content_version,
      depth, personal_enjoyment, descriptor_ids, dimension_ids
    ) select visit_id, snapshot_id, owner_id, 'mugshot.sensory', '2026.07.16.1',
      'guided', 4.5, array['creamy grassy first words'], array['texture']
    from tasting_lens_test_context;
    raise exception 'projection accepted prose in an identifier field';
  exception when check_violation then null;
  end;
end $$;

insert into public.visit_sensory_public_projections (
  visit_id, snapshot_id, user_id, bundle_id, bundle_content_version,
  depth, personal_enjoyment, descriptor_ids, dimension_ids
) select visit_id, snapshot_id, owner_id, 'mugshot.sensory', '2026.07.16.1',
  'guided', 4.5,
  array['descriptor.texture.creamy', 'descriptor.green_botanical.grassy'],
  array['texture', 'flavor', 'unexpected']
from tasting_lens_test_context;

insert into public.tasting_lens_preferences (user_id, schema_version, payload)
select owner_id, 1, jsonb_build_object('userID', owner_id, 'defaultDepth', 'guided')
from tasting_lens_test_context
on conflict (user_id) do update
set schema_version = excluded.schema_version,
    payload = excluded.payload,
    updated_at = now();

insert into public.tasting_lens_corrections (
  id, user_id, snapshot_id, target_id, scope_id, reason
) select correction_id, owner_id, snapshot_id,
  'descriptor.green_botanical.grassy', 'matcha_latte.whisked_powder', 'selected_by_mistake'
from tasting_lens_test_context;

do $$
declare payload jsonb;
begin
  begin
    update public.tasting_lens_corrections
    set reason = 'other'
    where id = (select correction_id from tasting_lens_test_context);
    raise exception 'authenticated owner rewrote correction history';
  exception when insufficient_privilege then null;
  end;

  begin
    delete from public.tasting_lens_corrections
    where id = (select correction_id from tasting_lens_test_context);
    raise exception 'authenticated owner deleted correction history';
  exception when insufficient_privilege then null;
  end;

  payload := public.build_owner_data_export();
  if (payload ->> 'schema_version')::integer is distinct from 1 then
    raise exception 'owner export schema version changed or disappeared';
  end if;
  if jsonb_typeof(payload -> 'tasting_lens_snapshots') is distinct from 'array' then
    raise exception 'owner export sensory history key is missing or not an array';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(payload -> 'tasting_lens_snapshots') entry
    where entry ->> 'snapshot_id' = (select snapshot_id::text from tasting_lens_test_context)
  ) then
    raise exception 'owner export omitted fixture sensory history';
  end if;
  if jsonb_typeof(payload -> 'tasting_lens_corrections') is distinct from 'array' then
    raise exception 'owner export sensory correction key is missing or not an array';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(payload -> 'tasting_lens_corrections') entry
    where entry ->> 'id' = (select correction_id::text from tasting_lens_test_context)
  ) then
    raise exception 'owner export omitted fixture sensory correction';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select stranger_id from tasting_lens_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare forged_snapshot_id uuid := gen_random_uuid();
begin
  if exists (
    select 1 from public.visit_sensory_snapshots snapshot
    where snapshot.snapshot_id = (select snapshot_id from tasting_lens_test_context)
  ) then
    raise exception 'full sensory snapshot leaked to another user';
  end if;
  if exists (
    select 1 from public.tasting_lens_preferences preference
    where preference.user_id = (select owner_id from tasting_lens_test_context)
  ) then
    raise exception 'Tasting Lens preferences leaked to another user';
  end if;
  if exists (
    select 1 from public.tasting_lens_corrections correction
    where correction.id = (select correction_id from tasting_lens_test_context)
  ) then
    raise exception 'Tasting Lens correction leaked to another user';
  end if;
  if (exists (
      select 1 from public.visit_sensory_public_projections projection
      where projection.snapshot_id = (select snapshot_id from tasting_lens_test_context)
    )) is distinct from (select stranger_can_view from tasting_lens_test_context) then
    raise exception 'lossy projection visibility does not match visit visibility';
  end if;

  begin
    insert into public.visit_sensory_snapshots (
      visit_id, snapshot_id, user_id, schema_version, bundle_id,
      bundle_content_version, personalization_scope_id, depth, identity,
      responses, own_words, personal_enjoyment, snapshot_payload, payload_hash, created_at
    ) select
      gen_random_uuid(), forged_snapshot_id, owner_id, 1, 'mugshot.sensory',
      '2026.07.16.1', 'matcha_latte.whisked_powder', 'guided', identity,
      responses, 'forged', 4.5,
      snapshot_payload || jsonb_build_object('id', forged_snapshot_id, 'ownWords', 'forged'),
      repeat('b', 64), created_at
    from tasting_lens_test_context;
    raise exception 'stranger forged an owner-scoped sensory snapshot';
  exception when insufficient_privilege then null;
  end;
end $$;

reset role;

do $$ begin
  begin
    update public.visit_sensory_snapshots
    set own_words = 'service rewrite'
    where snapshot_id = (select snapshot_id from tasting_lens_test_context);
    raise exception 'immutable snapshot trigger did not reject privileged update';
  exception when sqlstate '55000' then null;
  end;

  begin
    update public.tasting_lens_corrections
    set reason = 'other'
    where id = (select correction_id from tasting_lens_test_context);
    raise exception 'append-only correction trigger did not reject privileged update';
  exception when sqlstate '55000' then null;
  end;
end $$;

rollback;

select 'tasting_lens_2_contract_passed' as result;
