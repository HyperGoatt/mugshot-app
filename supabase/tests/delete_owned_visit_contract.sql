\set ON_ERROR_STOP on

begin;

do $$
begin
  if to_regprocedure('public.delete_owned_visit_v1(uuid)') is null then
    raise exception 'owner delete RPC is missing';
  end if;
  if has_function_privilege(
       'anon',
       'public.delete_owned_visit_v1(uuid)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.delete_owned_visit_v1(uuid)',
       'EXECUTE'
     ) then
    raise exception 'owner delete RPC grants are incorrect';
  end if;
  if exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'delete_owned_visit_v1'
      and (not procedure.prosecdef or not procedure.proconfig @> array['search_path=""'])
  ) then
    raise exception 'owner delete RPC is not safely isolated';
  end if;
end;
$$;

create temp table delete_visit_test_context as
with ordered_users as (
  select id, row_number() over (order by created_at, id) as position
  from public.users
)
select
  (max(id::text) filter (where position = 1))::uuid as owner_id,
  (max(id::text) filter (where position = 2))::uuid as other_id,
  gen_random_uuid() as deletable_visit_id,
  gen_random_uuid() as protected_visit_id
from ordered_users;

grant select on delete_visit_test_context to authenticated;

insert into public.visits (
  id, user_id, drink_type, drink_subtype, caption, visibility, ratings,
  category_scores, overall_score, context_type, location_name, upload_state,
  poster_photo_url
)
select
  visit_id,
  owner_id,
  'Coffee',
  'Owner delete contract sip',
  'Delete me',
  'everyone',
  '{"Flavor":4}'::jsonb,
  '[{"name":"Flavor","score":4,"weight":1}]'::jsonb,
  4,
  'Cafe',
  'Contract Cafe',
  'complete',
  'mugshot-storage://visit-photos-private/' || lower(owner_id::text)
    || '/' || lower(visit_id::text) || '/cover.jpg'
from delete_visit_test_context context
cross join lateral (
  values (context.deletable_visit_id), (context.protected_visit_id)
) visit(visit_id);

insert into public.visit_photos (visit_id, photo_url, sort_order)
select
  deletable_visit_id,
  'mugshot-storage://visit-photos-private/' || lower(owner_id::text)
    || '/' || lower(deletable_visit_id::text) || '/second.jpg',
  1
from delete_visit_test_context;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from delete_visit_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare
  deleted_references text[];
begin
  select array_agg(result.photo_url order by result.photo_url)
  into deleted_references
  from public.delete_owned_visit_v1(
    (select deletable_visit_id from delete_visit_test_context)
  ) result;

  if coalesce(array_length(deleted_references, 1), 0) <> 2 then
    raise exception 'owner delete did not return the complete media manifest';
  end if;
  if exists (
    select 1 from public.visits
    where id = (select deletable_visit_id from delete_visit_test_context)
  ) then
    raise exception 'owner delete left the visit behind';
  end if;
end;
$$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select other_id from delete_visit_test_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    perform public.delete_owned_visit_v1(
      (select protected_visit_id from delete_visit_test_context)
    );
    raise exception 'cross-owner delete unexpectedly succeeded';
  exception
    when sqlstate '42501' then null;
  end;
end;
$$;

reset role;

do $$
begin
  if not exists (
    select 1 from public.visits
    where id = (select protected_visit_id from delete_visit_test_context)
  ) then
    raise exception 'cross-owner delete removed the protected visit';
  end if;
end;
$$;

rollback;
