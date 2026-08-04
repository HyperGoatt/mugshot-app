\set ON_ERROR_STOP on

begin;

do $$
begin
  if to_regprocedure(
    'public.edit_owned_visit_v2(uuid,text,text,numeric,jsonb,numeric,jsonb,text,text,text,text,jsonb,uuid[])'
  ) is null then
    raise exception 'owner edit RPC is missing';
  end if;
  if has_function_privilege(
       'anon',
       'public.edit_owned_visit_v2(uuid,text,text,numeric,jsonb,numeric,jsonb,text,text,text,text,jsonb,uuid[])',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.edit_owned_visit_v2(uuid,text,text,numeric,jsonb,numeric,jsonb,text,text,text,text,jsonb,uuid[])',
       'EXECUTE'
     ) then
    raise exception 'owner edit RPC grants are incorrect';
  end if;
  if exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'edit_owned_visit_v2'
      and (not procedure.prosecdef or not procedure.proconfig @> array['search_path=""'])
  ) then
    raise exception 'owner edit RPC is not safely isolated';
  end if;
end;
$$;

create temp table edit_sip_test_context as
with ordered_users as (
  select id, row_number() over (order by created_at, id) as position
  from public.users
)
select
  (max(id::text) filter (where position = 1))::uuid as owner_id,
  (max(id::text) filter (where position = 2))::uuid as viewer_id,
  gen_random_uuid() as visit_id,
  gen_random_uuid() as sip_criterion_id,
  gen_random_uuid() as context_criterion_id
from ordered_users;

grant select on edit_sip_test_context to authenticated;

insert into public.visits (
  id, user_id, drink_type, drink_subtype, caption, visibility, ratings,
  category_scores, overall_score, context_type, location_name, upload_state
)
select
  visit_id,
  owner_id,
  'Coffee',
  'Owner edit contract sip',
  'Before edit',
  'everyone',
  '{"Flavor":3}'::jsonb,
  '[{"name":"Flavor","score":3,"weight":1}]'::jsonb,
  3,
  'Cafe',
  'Contract Cafe',
  'complete'
from edit_sip_test_context;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from edit_sip_test_context),
    'role', 'authenticated'
  )::text,
  true
);

select *
from public.upsert_visit_v3_reflection_v1(
  p_visit_id => (select visit_id from edit_sip_test_context),
  p_context_score => 3,
  p_context_criteria => jsonb_build_array(jsonb_build_object(
    'id', (select context_criterion_id from edit_sip_test_context),
    'name', 'Atmosphere',
    'score', 3,
    'weight', 1,
    'sortOrder', 0,
    'relevanceOverride', true
  )),
  p_sip_raw_note => 'Before journal note',
  p_context_raw_note => null,
  p_raw_note_visibility => 'private'
);

select public.edit_owned_visit_v2(
  p_visit_id => (select visit_id from edit_sip_test_context),
  p_caption => 'After edit',
  p_visibility => 'friends',
  p_overall_score => 4.5,
  p_sip_criteria => jsonb_build_array(jsonb_build_object(
    'id', (select sip_criterion_id from edit_sip_test_context),
    'name', 'Sweetness',
    'score', 4.5,
    'weight', 1.5,
    'sortOrder', 0,
    'relevanceOverride', true
  )),
  p_context_score => 4,
  p_context_criteria => jsonb_build_array(jsonb_build_object(
    'id', (select context_criterion_id from edit_sip_test_context),
    'name', 'Comfort',
    'score', 4,
    'weight', 1,
    'sortOrder', 0,
    'relevanceOverride', true
  )),
  p_sip_raw_note => 'Shared journal words',
  p_context_raw_note => 'Shared context words',
  p_raw_note_visibility => 'friends',
  p_legacy_private_note => null,
  p_photo_urls => jsonb_build_array(
    'mugshot-storage://visit-photos-private/'
      || (select lower(owner_id::text) from edit_sip_test_context)
      || '/'
      || (select lower(visit_id::text) from edit_sip_test_context)
      || '/cover.jpg',
    'mugshot-storage://visit-photos-private/'
      || (select lower(owner_id::text) from edit_sip_test_context)
      || '/'
      || (select lower(visit_id::text) from edit_sip_test_context)
      || '/second.jpg'
  ),
  p_tagged_user_ids => array[(select viewer_id from edit_sip_test_context)]
);

reset role;

do $$
declare
  target_visit public.visits%rowtype;
  reflection public.visit_v3_reflections%rowtype;
  ordered_photos text[];
begin
  select visit.* into target_visit
  from public.visits visit
  where visit.id = (select visit_id from edit_sip_test_context);

  if target_visit.caption <> 'After edit'
     or target_visit.visibility <> 'friends'
     or target_visit.overall_score <> 4.5
     or target_visit.ratings <> '{"Sweetness":4.5}'::jsonb
     or target_visit.category_scores <> '[{"name":"Sweetness","score":4.5,"weight":1.5}]'::jsonb then
    raise exception 'canonical visit edit was not applied coherently';
  end if;

  select array_agg(photo.photo_url order by photo.sort_order) into ordered_photos
  from public.visit_photos photo
  where photo.visit_id = target_visit.id;
  if array_length(ordered_photos, 1) <> 2
     or ordered_photos[1] <> target_visit.poster_photo_url
     or ordered_photos[2] not like '%/second.jpg' then
    raise exception 'photo order and cover were not persisted';
  end if;

  select row_value.* into reflection
  from public.visit_v3_reflections row_value
  where row_value.visit_id = target_visit.id;
  if reflection.sip_score <> 4.5
     or reflection.context_score <> 4
     or reflection.mugshot_score <> 4.3
     or reflection.raw_note_visibility <> 'friends'
     or reflection.sip_raw_note <> 'Shared journal words'
     or reflection.context_raw_note <> 'Shared context words' then
    raise exception 'journal and reflection edit was not applied coherently';
  end if;
  if not exists (
    select 1 from public.visit_tags tag
    where tag.visit_id = target_visit.id
      and tag.tagged_user_id = (select viewer_id from edit_sip_test_context)
      and tag.tagged_by = (select owner_id from edit_sip_test_context)
  ) then
    raise exception 'tag replacement did not commit with the edit';
  end if;
end;
$$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from edit_sip_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.edit_owned_visit_v2(
      p_visit_id => (select visit_id from edit_sip_test_context),
      p_caption => 'Must roll back',
      p_visibility => 'private',
      p_overall_score => 4.5,
      p_sip_criteria => '[]'::jsonb,
      p_context_score => 4,
      p_context_criteria => '[]'::jsonb,
      p_raw_note_visibility => 'everyone',
      p_photo_urls => '[]'::jsonb,
      p_tagged_user_ids => '{}'::uuid[]
    );
    raise exception 'broader journal audience unexpectedly succeeded';
  exception
    when sqlstate '22023' then null;
  end;
end;
$$;

do $$
begin
  if (select caption from public.visits where id = (select visit_id from edit_sip_test_context))
     <> 'After edit' then
    raise exception 'failed edit partially mutated the visit';
  end if;
  if not exists (
    select 1 from public.list_visible_visit_tags_v1(
      (select visit_id from edit_sip_test_context)
    ) tag
    where tag.user_id = (select viewer_id from edit_sip_test_context)
  ) then
    raise exception 'failed edit partially mutated tags';
  end if;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from edit_sip_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.edit_owned_visit_v2(
      p_visit_id => (select visit_id from edit_sip_test_context),
      p_caption => 'Cross-owner edit',
      p_visibility => 'friends',
      p_overall_score => 4,
      p_sip_criteria => '[]'::jsonb,
      p_context_score => 4,
      p_context_criteria => '[]'::jsonb,
      p_raw_note_visibility => 'private',
      p_photo_urls => '[]'::jsonb,
      p_tagged_user_ids => '{}'::uuid[]
    );
    raise exception 'cross-owner edit unexpectedly succeeded';
  exception
    when sqlstate '42501' then null;
  end;
end;
$$;

rollback;
