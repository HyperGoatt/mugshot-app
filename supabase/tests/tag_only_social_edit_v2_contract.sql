\set ON_ERROR_STOP on

begin;

do $$
declare
  shared_endpoint text;
begin
  if to_regclass('public.visit_tags') is null
     or (select relkind from pg_class where oid = 'public.visit_tags'::regclass) <> 'r' then
    raise exception 'canonical visit_tags table is missing';
  end if;
  if to_regclass('public.visit_companions') is null
     or (select relkind from pg_class where oid = 'public.visit_companions'::regclass) <> 'v' then
    raise exception 'revoked companion compatibility view is missing';
  end if;
  if has_table_privilege('authenticated', 'public.visit_tags', 'SELECT')
     or has_table_privilege('authenticated', 'public.visit_companions', 'SELECT') then
    raise exception 'raw tag storage is client-readable';
  end if;

  foreach shared_endpoint in array array[
    'public.create_shared_memory_invitations_v1(uuid,uuid[])',
    'public.list_pending_shared_memory_invitations_v1()',
    'public.list_managed_shared_memory_invitations_v1(uuid)',
    'public.list_my_shared_memory_memberships_v1()',
    'public.list_owned_shared_memories_v1()',
    'public.respond_shared_memory_invitation_v1(uuid,boolean)',
    'public.attach_shared_memory_contribution_v1(uuid,uuid)',
    'public.cancel_shared_memory_invitation_v1(uuid)',
    'public.leave_shared_memory_v1(uuid)',
    'public.get_shared_memory_projection_v1(uuid)'
  ] loop
    if to_regprocedure(shared_endpoint) is not null then
      raise exception 'retired Shared Mugshot endpoint remains: %', shared_endpoint;
    end if;
  end loop;

  if exists (
    select 1
    from public.activity_events
    where kind = 'shared_mugshot_invitation'
  ) then
    raise exception 'retired Shared Mugshot activity remains';
  end if;
  if exists (
    select 1
    from pg_trigger trigger_row
    join pg_class relation on relation.oid = trigger_row.tgrelid
    where not trigger_row.tgisinternal
      and relation.oid in (
        'public.shared_memories'::regclass,
        'public.shared_memory_members'::regclass,
        'public.shared_memory_contributions'::regclass
      )
  ) then
    raise exception 'retired Shared Mugshot trigger remains';
  end if;
  if exists (select 1 from public.shared_memories)
     or exists (select 1 from public.shared_memory_members)
     or exists (select 1 from public.shared_memory_contributions) then
    raise exception 'retired Shared Mugshot rows remain';
  end if;

  if to_regprocedure('public.set_visit_tags_v1(uuid,uuid[])') is null
     or to_regprocedure('public.list_visible_visit_tags_v1(uuid)') is null
     or to_regprocedure('public.remove_self_visit_tag_v1(uuid)') is null
     or to_regprocedure('public.visit_tag_suggestions_v1(integer)') is null
     or to_regprocedure(
       'public.get_journal_people_counts_v1(timestamp with time zone,timestamp with time zone,integer)'
     ) is null then
    raise exception 'tag-only RPC surface is incomplete';
  end if;
  if to_regprocedure('public.companion_suggestions(integer)') is not null
     or to_regprocedure('public.set_visit_companions(uuid,uuid[])') is not null then
    raise exception 'legacy companion endpoint remains';
  end if;
  if has_function_privilege(
       'anon', 'public.set_visit_tags_v1(uuid,uuid[])', 'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated', 'public.set_visit_tags_v1(uuid,uuid[])', 'EXECUTE'
     ) then
    raise exception 'tag mutation grants are incorrect';
  end if;
  if to_regprocedure(
       'public.set_notification_preferences_v1(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean)'
     ) is null
     or to_regprocedure(
       'public.set_notification_preferences_v1(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean)'
     ) is not null then
    raise exception 'retired notification preference remains in the write contract';
  end if;
  if (public.get_backend_capabilities_v1() #>> '{capabilities,shared_mugshots}')::boolean then
    raise exception 'backend still reports Shared Mugshots available';
  end if;
end;
$$;

create temp table tag_only_context as
with ordered_users as (
  select id, row_number() over (order by created_at, id) position
  from public.users
  limit 4
)
select
  (max(id::text) filter (where position = 1))::uuid owner_id,
  (max(id::text) filter (where position = 2))::uuid amanda_id,
  (max(id::text) filter (where position = 3))::uuid paul_id,
  (max(id::text) filter (where position = 4))::uuid jake_id,
  gen_random_uuid() visit_id,
  gen_random_uuid() second_visit_id
from ordered_users;

grant select on tag_only_context to authenticated;

insert into public.visits (
  id, user_id, drink_type, drink_subtype, caption, visibility,
  ratings, category_scores, overall_score, context_type, location_name,
  upload_state, created_at
)
select
  visit_id, owner_id, 'Coffee', 'Tag contract one', 'Coffee with people',
  'everyone', '{}'::jsonb, '[]'::jsonb, 4, 'Cafe', 'Contract Cafe',
  'complete', now() - interval '10 days'
from tag_only_context
union all
select
  second_visit_id, owner_id, 'Coffee', 'Tag contract two', 'Another coffee',
  'everyone', '{}'::jsonb, '[]'::jsonb, 4, 'Cafe', 'Contract Cafe',
  'complete', now() - interval '2 days'
from tag_only_context;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from tag_only_context),
    'role', 'authenticated'
  )::text,
  true
);

select public.set_visit_tags_v1(
  (select visit_id from tag_only_context),
  array[
    (select amanda_id from tag_only_context),
    (select amanda_id from tag_only_context),
    (select owner_id from tag_only_context)
  ]
);
select public.set_visit_tags_v1(
  (select second_visit_id from tag_only_context),
  array[
    (select amanda_id from tag_only_context),
    (select paul_id from tag_only_context),
    (select jake_id from tag_only_context)
  ]
);

do $$
declare
  first_person record;
begin
  if (
    select count(*)
    from public.list_visible_visit_tags_v1((select visit_id from tag_only_context))
  ) <> 1 then
    raise exception 'tag normalization did not remove self and duplicates';
  end if;

  select * into first_person
  from public.get_journal_people_counts_v1(
    now() - interval '30 days', now() + interval '1 day', 3
  )
  limit 1;
  if first_person.account_id <> (select amanda_id from tag_only_context)
     or first_person.sip_count <> 2 then
    raise exception 'people recap count or primary ordering is incorrect';
  end if;

  begin
    perform public.get_journal_people_counts_v1(
      now() - interval '371 days', now(), 3
    );
    raise exception 'oversized recap range unexpectedly succeeded';
  exception when sqlstate '22023' then null;
  end;

  begin
    perform public.set_visit_tags_v1(
      (select visit_id from tag_only_context),
      array[
        gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
        gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
        gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
        gen_random_uuid(), gen_random_uuid(), gen_random_uuid(),
        gen_random_uuid()
      ]
    );
    raise exception 'thirteen tags unexpectedly succeeded';
  exception when sqlstate '22023' then null;
  end;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select amanda_id from tag_only_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.set_visit_tags_v1(
      (select visit_id from tag_only_context),
      array[(select paul_id from tag_only_context)]
    );
    raise exception 'cross-owner tag edit unexpectedly succeeded';
  exception when sqlstate '42501' then null;
  end;
  if not public.remove_self_visit_tag_v1(
    (select visit_id from tag_only_context)
  ) then
    raise exception 'tagged person could not remove their own tag';
  end if;
end;
$$;

reset role;

do $$
declare
  exported jsonb;
begin
  if exists (
    select 1 from public.visit_tags tag
    where tag.visit_id = (select visit_id from tag_only_context)
      and tag.tagged_user_id = (select amanda_id from tag_only_context)
  ) then
    raise exception 'self-removal did not delete the canonical tag';
  end if;

  perform set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', (select owner_id from tag_only_context),
      'role', 'authenticated'
    )::text,
    true
  );
  exported := public.build_owner_data_export_v2();
  if exported #> '{collaboration,created_shared_memories}' is not null
     or exported #> '{collaboration,shared_memory_memberships}' is not null
     or exported::text ilike '%shared MugShot%' then
    raise exception 'owner export retains retired Shared Mugshot content';
  end if;
  if exported #> '{social,visit_tags_added_or_received}' is null
     or exported::text not like '%tagged_user_id%' then
    raise exception 'owner export did not adopt tag-oriented fields';
  end if;
end;
$$;

rollback;

select 'tag_only_social_edit_v2_contract_passed' as result;
