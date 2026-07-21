\set ON_ERROR_STOP on

begin;

do $$
begin
  if to_regclass('public.cafe_sessions') is null
     or to_regclass('public.cafe_sip_intentions') is null
     or to_regclass('public.cafe_experience_snapshots') is null
     or to_regclass('public.cafe_experience_corrections') is null
     or to_regclass('public.cafe_experience_public_projections') is null
     or to_regclass('public.cafe_experience_signals') is null
     or to_regclass('public.cafe_experience_signal_evidence') is null then
    raise exception 'Cafe Sessions storage contract is incomplete';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'visits'
      and column_name = 'cafe_session_id'
      and is_nullable = 'YES'
  ) then
    raise exception 'legacy-compatible nullable visit session link is missing';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'cafe_experience_snapshots'
      and column_name = 'cafe_rating'
      and is_nullable = 'YES'
  ) then
    raise exception 'Cafe Pulse snapshots must support an unrated experience';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'cafe_experience_public_projections'
      and column_name = 'snapshot_id'
      and is_nullable = 'YES'
  ) then
    raise exception 'intent-only Next Move projections must be snapshot-optional';
  end if;

  if has_column_privilege(
       'authenticated',
       'public.visits',
       'cafe_session_id',
       'INSERT'
     )
     or has_column_privilege(
       'authenticated',
       'public.visits',
       'cafe_session_role',
       'UPDATE'
     )
     or not has_column_privilege(
       'authenticated',
       'public.visits',
       'caption',
       'INSERT'
     ) then
    raise exception 'visit session linkage is not RPC-only';
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'cafe_experience_public_projections'
      and column_name in (
        'own_words',
        'responses',
        'snapshot_payload',
        'visit_mode',
        'context_overlays'
      )
  ) then
    raise exception 'lossy Cafe Pulse projection exposes private fields';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name in (
        'cafe_sessions',
        'cafe_sip_intentions',
        'cafe_experience_snapshots',
        'cafe_experience_corrections',
        'cafe_experience_public_projections',
        'cafe_experience_signals',
        'cafe_experience_signal_evidence'
      )
      and grantee = 'anon'
  ) then
    raise exception 'anonymous role can access Cafe Sessions data';
  end if;

  if exists (
    select 1
    from information_schema.role_table_grants
    where table_schema = 'public'
      and table_name in (
        'cafe_sessions',
        'cafe_sip_intentions',
        'cafe_experience_snapshots',
        'cafe_experience_corrections',
        'cafe_experience_public_projections',
        'cafe_experience_signals',
        'cafe_experience_signal_evidence'
      )
      and grantee = 'authenticated'
      and privilege_type <> 'SELECT'
  ) then
    raise exception 'authenticated clients can bypass Cafe Sessions RPCs';
  end if;

  if exists (
    select 1
    from pg_class relation
    join pg_namespace namespace
      on namespace.oid = relation.relnamespace
    where namespace.nspname = 'public'
      and relation.relname in (
        'cafe_sessions',
        'cafe_sip_intentions',
        'cafe_experience_snapshots',
        'cafe_experience_corrections',
        'cafe_experience_public_projections',
        'cafe_experience_signals',
        'cafe_experience_signal_evidence'
      )
      and not (relation.relrowsecurity and relation.relforcerowsecurity)
  ) then
    raise exception 'Cafe Sessions RLS is not enabled and forced';
  end if;

  if has_function_privilege(
       'anon',
       'public.ensure_cafe_session_v1(uuid,uuid,timestamptz,text,text[],text)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.ensure_cafe_session_v1(uuid,uuid,timestamptz,text,text[],text)',
       'EXECUTE'
     )
     or has_function_privilege(
       'anon',
       'public.publish_cafe_session_v1(uuid,text,boolean,boolean,boolean,text[],text[],timestamptz)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.publish_cafe_session_v1(uuid,text,boolean,boolean,boolean,text[],text[],timestamptz)',
       'EXECUTE'
     )
     or has_function_privilege(
       'anon',
       'public.finalize_cafe_session_sip_v1(uuid,uuid)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.finalize_cafe_session_sip_v1(uuid,uuid)',
       'EXECUTE'
     )
     or has_function_privilege(
       'anon',
       'public.get_cafe_sessions_capability_v1()',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.get_cafe_sessions_capability_v1()',
       'EXECUTE'
     ) then
    raise exception 'Cafe Sessions RPC grants are incorrect';
  end if;

  if exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace
      on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname in (
        'ensure_cafe_session_v1',
        'attach_visit_to_cafe_session_v1',
        'finalize_cafe_session_sip_v1',
        'set_cafe_session_intentions_v1',
        'record_cafe_experience_v1',
        'publish_cafe_session_v1',
        'append_cafe_session_sip_v1',
        'set_cafe_session_audience_v1',
        'append_cafe_experience_correction_v1',
        'set_cafe_experience_signal_owner_state_v1',
        'abandon_cafe_session_v1',
        'delete_cafe_session_sip_v1'
      )
      and (
        not procedure.prosecdef
        or not (
          procedure.proconfig @> array['search_path=""']
        )
      )
  ) then
    raise exception 'Cafe Sessions mutation RPC hardening is incomplete';
  end if;

  if position(
       'visit.cafe_session_id is null'
       in lower(
         pg_get_functiondef(
           'public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid)'::regprocedure
         )
       )
     ) = 0
     or position(
       'visit.cafe_session_role = ''primary'''
       in lower(
         pg_get_functiondef(
           'public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid)'::regprocedure
         )
       )
     ) = 0 then
    raise exception 'ranked feed can expose secondary sips as root cards';
  end if;
end;
$$;

create temp table cafe_sessions_test_context (
  owner_id uuid not null,
  stranger_id uuid not null,
  cafe_id uuid not null,
  session_id uuid not null,
  primary_visit_id uuid not null,
  secondary_visit_id uuid not null,
  snapshot_id uuid not null,
  correction_id uuid not null,
  started_at timestamptz not null,
  responses jsonb not null
);

insert into cafe_sessions_test_context
select
  owner.id,
  stranger.id,
  cafe.id,
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  gen_random_uuid(),
  clock_timestamp(),
  jsonb_build_array(
    jsonb_build_object(
      'dimensionID', 'atmosphere',
      'observationID', 'cafe.observation.atmosphere.warm',
      'state', 'observed',
      'impact', 'lifted',
      'descriptorIDs', jsonb_build_array(
        'cafe.descriptor.atmosphere.warm'
      )
    ),
    jsonb_build_object(
      'dimensionID', 'comfort_practicality',
      'state', 'not_observed'
    )
  )
from (
  select id
  from public.users
  order by created_at, id
  limit 1
) owner
cross join lateral (
  select id
  from public.users
  where id <> owner.id
  order by created_at, id
  limit 1
) stranger
cross join lateral (
  select id
  from public.cafes
  order by created_at, id
  limit 1
) cafe;

grant select on cafe_sessions_test_context to authenticated;

do $$
begin
  if not exists (select 1 from cafe_sessions_test_context) then
    raise exception 'Cafe Sessions contract requires two users and one cafe';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from cafe_sessions_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare
  capability jsonb;
begin
  capability := public.get_cafe_sessions_capability_v1();
  if (capability ->> 'schema_version')::integer is distinct from 1
     or not (capability #>> '{features,cafe_pulse}')::boolean
     or not (capability #>> '{features,independent_share_fields}')::boolean
     or not (capability #>> '{features,session_safe_finalization}')::boolean then
    raise exception 'Cafe Sessions capability response is incomplete';
  end if;

  if public.derive_cafe_next_move('yes', 'yes')
       <> 'come_back_for_this'
     or public.derive_cafe_next_move('yes', 'no')
       <> 'come_back_try_another'
     or public.derive_cafe_next_move('no', 'yes')
       <> 'this_drink_elsewhere'
     or public.derive_cafe_next_move('no', 'no')
       <> 'probably_not_again'
     or public.derive_cafe_next_move('maybe', 'yes')
       <> 'not_sure_yet'
     or public.derive_cafe_next_move('yes', null)
       <> 'not_sure_yet' then
    raise exception 'Next Move derivation changed';
  end if;
end;
$$;

do $$
declare
  intent_session_id uuid := gen_random_uuid();
  intent_visit_id uuid := gen_random_uuid();
  fixture cafe_sessions_test_context%rowtype;
begin
  select * into fixture from cafe_sessions_test_context;

  perform public.ensure_cafe_session_v1(
    intent_session_id,
    fixture.cafe_id,
    fixture.started_at,
    'grab_and_go',
    '{}'::text[],
    'private'
  );

  insert into public.visits (
    id,
    user_id,
    cafe_id,
    drink_type,
    caption,
    visibility,
    ratings,
    overall_score,
    context_type,
    upload_state
  )
  values (
    intent_visit_id,
    fixture.owner_id,
    fixture.cafe_id,
    'Coffee',
    'Intent-only Cafe Session fixture',
    'private',
    '{}'::jsonb,
    4,
    'Cafe',
    'uploading'
  );

  perform public.attach_visit_to_cafe_session_v1(
    intent_session_id,
    intent_visit_id,
    0::smallint,
    'primary'
  );
  perform public.finalize_cafe_session_sip_v1(
    intent_session_id,
    intent_visit_id
  );
  perform public.set_cafe_session_intentions_v1(
    intent_session_id,
    intent_visit_id,
    'yes',
    'no'
  );
  perform public.publish_cafe_session_v1(
    intent_session_id,
    'everyone',
    true,
    false,
    true,
    '{}'::text[],
    '{}'::text[],
    fixture.started_at + interval '15 minutes'
  );

  if exists (
    select 1
    from public.cafe_experience_snapshots snapshot
    where snapshot.session_id = intent_session_id
  ) then
    raise exception 'intent-only publication manufactured a Cafe Pulse snapshot';
  end if;

  if not exists (
    select 1
    from public.cafe_experience_public_projections projection
    where projection.session_id = intent_session_id
      and projection.snapshot_id is null
      and projection.includes_next_move
      and not projection.includes_cafe_rating
      and projection.cafe_rating is null
      and projection.next_move = 'come_back_try_another'
      and cardinality(projection.dimension_ids) = 0
      and cardinality(projection.descriptor_ids) = 0
  ) then
    raise exception 'intent-only Next Move projection was not published safely';
  end if;

  perform public.publish_cafe_session_v1(
    intent_session_id,
    'everyone',
    true,
    false,
    true,
    '{}'::text[],
    '{}'::text[],
    fixture.started_at + interval '1 hour'
  );
  if (
    select count(*)
    from public.cafe_experience_public_projections projection
    where projection.session_id = intent_session_id
  ) <> 1 or not exists (
    select 1
    from public.cafe_sessions session
    where session.id = intent_session_id
      and session.ended_at = fixture.started_at + interval '15 minutes'
  ) then
    raise exception 'intent-only publication retry changed physical history';
  end if;

  perform public.set_cafe_session_intentions_v1(
    intent_session_id,
    intent_visit_id,
    'no',
    'yes'
  );
  if not exists (
    select 1
    from public.cafe_experience_public_projections projection
    where projection.session_id = intent_session_id
      and projection.snapshot_id is null
      and projection.next_move = 'this_drink_elsewhere'
  ) then
    raise exception 'intent-only Next Move projection did not follow explicit intentions';
  end if;

  begin
    perform public.publish_cafe_session_v1(
      intent_session_id,
      'everyone',
      true,
      true,
      false,
      '{}'::text[],
      '{}'::text[],
      fixture.started_at + interval '15 minutes'
    );
    raise exception 'snapshotless cafe stars were accepted';
  exception when check_violation then
    null;
  end;

  begin
    perform public.publish_cafe_session_v1(
      intent_session_id,
      'everyone',
      true,
      false,
      false,
      array['atmosphere'],
      '{}'::text[],
      fixture.started_at + interval '15 minutes'
    );
    raise exception 'snapshotless Cafe Pulse observations were accepted';
  exception when check_violation then
    null;
  end;

  perform public.delete_cafe_session_sip_v1(
    intent_session_id,
    intent_visit_id
  );
  if exists (
    select 1
    from public.cafe_sessions session
    where session.id = intent_session_id
  ) or exists (
    select 1
    from public.cafe_experience_public_projections projection
    where projection.session_id = intent_session_id
  ) then
    raise exception 'intent-only Cafe Session fixture cleanup failed';
  end if;
end;
$$;

select public.ensure_cafe_session_v1(
  session_id,
  cafe_id,
  started_at,
  'work_study',
  array['outdoor'],
  'private'
)
from cafe_sessions_test_context;

-- The exact same client-generated identifier is an idempotent retry.
select public.ensure_cafe_session_v1(
  session_id,
  cafe_id,
  started_at,
  'work_study',
  array['outdoor'],
  'private'
)
from cafe_sessions_test_context;

insert into public.visits (
  id,
  user_id,
  cafe_id,
  drink_type,
  drink_subtype,
  caption,
  visibility,
  ratings,
  overall_score,
  context_type,
  upload_state
)
select
  primary_visit_id,
  owner_id,
  cafe_id,
  'Coffee',
  'Cortado',
  'Cafe Sessions primary fixture',
  'private',
  '{}'::jsonb,
  4.5,
  'Cafe',
  'uploading'
from cafe_sessions_test_context;

select public.attach_visit_to_cafe_session_v1(
  session_id,
  primary_visit_id,
  0::smallint,
  'primary'
)
from cafe_sessions_test_context;

select public.finalize_cafe_session_sip_v1(
  session_id,
  primary_visit_id
)
from cafe_sessions_test_context;

do $$
begin
  if not exists (
    select 1
    from public.cafe_sessions session
    join cafe_sessions_test_context fixture
      on fixture.session_id = session.id
    join public.visits visit
      on visit.id = fixture.primary_visit_id
    where session.status = 'active'
      and visit.upload_state = 'complete'
  ) then
    raise exception 'session-safe sip finalization failed';
  end if;
end;
$$;

do $$
declare
  abandoned_session_id uuid := gen_random_uuid();
  abandoned_primary_id uuid := gen_random_uuid();
  abandoned_secondary_id uuid := gen_random_uuid();
  fixture cafe_sessions_test_context%rowtype;
begin
  select * into fixture from cafe_sessions_test_context;

  perform public.ensure_cafe_session_v1(
    abandoned_session_id,
    fixture.cafe_id,
    fixture.started_at,
    'grab_and_go',
    '{}'::text[],
    'private'
  );

  insert into public.visits (
    id,
    user_id,
    cafe_id,
    drink_type,
    caption,
    visibility,
    ratings,
    overall_score,
    context_type,
    upload_state
  )
  values
    (
      abandoned_primary_id,
      fixture.owner_id,
      fixture.cafe_id,
      'Coffee',
      'Abandoned primary fixture',
      'private',
      '{}'::jsonb,
      3,
      'Cafe',
      'uploading'
    ),
    (
      abandoned_secondary_id,
      fixture.owner_id,
      fixture.cafe_id,
      'Coffee',
      'Abandoned secondary fixture',
      'private',
      '{}'::jsonb,
      3,
      'Cafe',
      'uploading'
    );

  perform public.attach_visit_to_cafe_session_v1(
    abandoned_session_id,
    abandoned_primary_id,
    0::smallint,
    'primary'
  );
  perform public.attach_visit_to_cafe_session_v1(
    abandoned_session_id,
    abandoned_secondary_id,
    1::smallint,
    'secondary'
  );
  perform public.abandon_cafe_session_v1(abandoned_session_id);
  perform public.delete_cafe_session_sip_v1(
    abandoned_session_id,
    abandoned_primary_id
  );

  if not exists (
    select 1
    from public.cafe_sessions session
    join public.visits visit
      on visit.cafe_session_id = session.id
    where session.id = abandoned_session_id
      and session.status = 'abandoned'
      and session.primary_visit_id is null
      and visit.id = abandoned_secondary_id
      and visit.cafe_session_role = 'secondary'
  ) then
    raise exception 'abandoned session primary deletion was not reconciled';
  end if;

  perform public.delete_cafe_session_sip_v1(
    abandoned_session_id,
    abandoned_secondary_id
  );
  if exists (
    select 1
    from public.cafe_sessions
    where id = abandoned_session_id
  ) then
    raise exception 'empty abandoned session was not deleted';
  end if;
end;
$$;

select public.record_cafe_experience_v1(
  session_id,
  snapshot_id,
  1,
  'mugshot.cafe-pulse',
  '2026.07.17.1',
  'deep',
  3.0,
  'different',
  responses,
  'Warm room, difficult seating.',
  'no',
  'yes',
  jsonb_build_object(
    'id', snapshot_id,
    'sessionID', session_id,
    'ownerUserID', owner_id,
    'cafeID', cafe_id,
    'schemaVersion', 1,
    'createdAt', started_at,
    'depth', 'deep',
    'cafeRating', 3.0,
    'repeatComparison', 'different',
    'visitContext', jsonb_build_object(
      'mode', 'work_study',
      'overlays', jsonb_build_array('outdoor_seating')
    ),
    'observations', jsonb_build_array(
      jsonb_build_object(
        'id', snapshot_id,
        'dimension', 'atmosphere',
        'facet', 'atmosphere.design',
        'state', 'observed',
        'impact', 'lifted',
        'privateNote', 'Warm on arrival'
      )
    ),
    'ownWords', 'Warm room, difficult seating.',
    'returnIntention', 'no',
    'privateNotes', 'Try the window seat next time.'
  ),
  repeat('a', 64),
  started_at
)
from cafe_sessions_test_context;

-- The identical immutable payload is safe to retry.
select public.record_cafe_experience_v1(
  session_id,
  snapshot_id,
  1,
  'mugshot.cafe-pulse',
  '2026.07.17.1',
  'deep',
  3.0,
  'different',
  responses,
  'Warm room, difficult seating.',
  'no',
  'yes',
  jsonb_build_object(
    'id', snapshot_id,
    'sessionID', session_id,
    'ownerUserID', owner_id,
    'cafeID', cafe_id,
    'schemaVersion', 1,
    'createdAt', started_at,
    'depth', 'deep',
    'cafeRating', 3.0,
    'repeatComparison', 'different',
    'visitContext', jsonb_build_object(
      'mode', 'work_study',
      'overlays', jsonb_build_array('outdoor_seating')
    ),
    'observations', jsonb_build_array(
      jsonb_build_object(
        'id', snapshot_id,
        'dimension', 'atmosphere',
        'facet', 'atmosphere.design',
        'state', 'observed',
        'impact', 'lifted',
        'privateNote', 'Warm on arrival'
      )
    ),
    'ownWords', 'Warm room, difficult seating.',
    'returnIntention', 'no',
    'privateNotes', 'Try the window seat next time.'
  ),
  repeat('a', 64),
  started_at
)
from cafe_sessions_test_context;

select public.publish_cafe_session_v1(
  session_id,
  'everyone',
  true,
  true,
  false,
  array['atmosphere'],
  array['cafe.descriptor.atmosphere.warm'],
  started_at + interval '45 minutes'
)
from cafe_sessions_test_context;

-- A compact reference from a later sip may omit the original context.
-- Creation fields remain write-once, finalization preserves the current
-- session audience, and the original physical-visit end time is stable.
select public.ensure_cafe_session_v1(
  session_id,
  cafe_id,
  started_at,
  'stay_a_while',
  '{}'::text[],
  'private'
)
from cafe_sessions_test_context;

select public.attach_visit_to_cafe_session_v1(
  session_id,
  primary_visit_id,
  0::smallint,
  'primary'
)
from cafe_sessions_test_context;

select public.finalize_cafe_session_sip_v1(
  session_id,
  primary_visit_id
)
from cafe_sessions_test_context;

select public.publish_cafe_session_v1(
  session_id,
  'everyone',
  true,
  true,
  false,
  array['atmosphere'],
  array['cafe.descriptor.atmosphere.warm'],
  started_at + interval '2 hours'
)
from cafe_sessions_test_context;

do $$
begin
  if (select count(*)
      from public.cafe_experience_snapshots snapshot
      join cafe_sessions_test_context fixture
        on fixture.session_id = snapshot.session_id) <> 1 then
    raise exception 'idempotent Cafe Pulse retry duplicated history';
  end if;

  if not exists (
    select 1
    from public.cafe_experience_public_projections projection
    join cafe_sessions_test_context fixture
      on fixture.session_id = projection.session_id
    where projection.includes_cafe_rating
      and not projection.includes_next_move
      and projection.cafe_rating = 3.0
      and projection.next_move is null
  ) then
    raise exception 'independent projection share choices were not honored';
  end if;

  if not exists (
    select 1
    from public.cafe_sessions session
    join cafe_sessions_test_context fixture
      on fixture.session_id = session.id
    where session.ended_at = fixture.started_at + interval '45 minutes'
  ) then
    raise exception 'publication retry changed the physical visit end time';
  end if;

  begin
    update public.visits
    set visibility = 'friends'
    where id = (
      select primary_visit_id from cafe_sessions_test_context
    );
    raise exception 'linked sip audience drift was accepted';
  exception when check_violation then
    null;
  end;
end;
$$;

insert into public.visits (
  id,
  user_id,
  cafe_id,
  drink_type,
  drink_subtype,
  caption,
  visibility,
  ratings,
  overall_score,
  context_type,
  upload_state
)
select
  secondary_visit_id,
  owner_id,
  cafe_id,
  'Matcha',
  'Iced matcha latte',
  'Cafe Sessions secondary fixture',
  'private',
  '{}'::jsonb,
  3.5,
  'Cafe',
  'complete'
from cafe_sessions_test_context;

select public.append_cafe_session_sip_v1(
  session_id,
  secondary_visit_id,
  1::smallint,
  'no'
)
from cafe_sessions_test_context;

do $$
declare
  summary jsonb;
  batch jsonb;
  exported jsonb;
begin
  summary := public.get_cafe_session_summary_v1(
    (select session_id from cafe_sessions_test_context)
  );
  if (summary ->> 'sip_count')::integer <> 2
     or (summary ->> 'cafe_rating')::numeric <> 3.0
     or summary ->> 'next_move' <> 'this_drink_elsewhere' then
    raise exception 'paired Cafe Session summary is incorrect';
  end if;

  batch := public.get_cafe_experience_summaries_v1(
    array[(select cafe_id from cafe_sessions_test_context)],
    'personal'
  );
  if jsonb_array_length(batch) <> 1
     or batch #>> '{0,relationship_stage}' <> 'first_impression'
     or (batch #>> '{0,physical_session_count}')::integer <> 1 then
    raise exception 'batch personal cafe summary is incorrect';
  end if;

  exported := public.build_owner_data_export_v2();
  if (exported ->> 'schema_version')::integer <> 2
     or jsonb_typeof(exported -> 'cafe_sessions') <> 'array'
     or jsonb_typeof(exported -> 'cafe_experience_snapshots') <> 'array'
     or not exists (
       select 1
       from jsonb_array_elements(
         exported -> 'cafe_experience_snapshots'
       ) entry
       where entry ->> 'snapshot_id' = (
         select snapshot_id::text from cafe_sessions_test_context
       )
     ) then
    raise exception 'owner export v2 omitted Cafe Sessions data';
  end if;
end;
$$;

select public.append_cafe_experience_correction_v1(
  correction_id,
  snapshot_id,
  'cafe.descriptor.atmosphere.warm',
  'selected_by_mistake',
  '{}'::jsonb
)
from cafe_sessions_test_context;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select stranger_id from cafe_sessions_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if exists (
    select 1
    from public.cafe_sessions session
    where session.id = (
      select session_id from cafe_sessions_test_context
    )
  ) then
    raise exception 'private cafe session leaked to another user';
  end if;

  if exists (
    select 1
    from public.cafe_experience_snapshots snapshot
    where snapshot.snapshot_id = (
      select snapshot_id from cafe_sessions_test_context
    )
  ) then
    raise exception 'full Cafe Pulse snapshot leaked to another user';
  end if;

  begin
    perform public.ensure_cafe_session_v1(
      (select session_id from cafe_sessions_test_context),
      (select cafe_id from cafe_sessions_test_context),
      clock_timestamp(),
      null,
      '{}'::text[],
      'private'
    );
    raise exception 'stranger claimed another owner session identifier';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;

reset role;

do $$
begin
  begin
    update public.cafe_experience_snapshots
    set own_words = 'rewritten'
    where snapshot_id = (
      select snapshot_id from cafe_sessions_test_context
    );
    raise exception 'privileged update rewrote immutable Cafe Pulse history';
  exception when sqlstate '55000' then
    null;
  end;

  begin
    update public.cafe_experience_corrections
    set reason = 'other'
    where id = (
      select correction_id from cafe_sessions_test_context
    );
    raise exception 'privileged update rewrote Cafe Pulse correction history';
  exception when sqlstate '55000' then
    null;
  end;
end;
$$;

rollback;

select 'cafe_sessions_contract_passed' as result;
