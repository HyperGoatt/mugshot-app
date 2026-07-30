do $$
begin
  if not exists (
    select 1
    from storage.buckets
    where id = 'visit-photos-private'
      and name = 'visit-photos-private'
      and not public
      and file_size_limit = 10485760
      and allowed_mime_types @> array[
        'image/jpeg',
        'image/png',
        'image/gif',
        'image/webp',
        'image/heic'
      ]
  ) then
    raise exception 'private visit-photo bucket settings are incorrect';
  end if;

  if (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'Owners upload private visit photos',
        'Owners update private visit photos',
        'Owners delete private visit photos',
        'Visit audiences read private visit photos',
        'Anonymous viewers read Everyone private visit photos'
      )
  ) <> 5 then
    raise exception 'private visit-photo Storage policies are incomplete';
  end if;

  if exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'Owners upload private visit photos',
        'Owners update private visit photos',
        'Owners delete private visit photos',
        'Visit audiences read private visit photos'
      )
      and roles <> '{authenticated}'::name[]
  ) then
    raise exception 'private visit-photo policy has a role broader than authenticated';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Owners upload private visit photos'
      and cmd = 'INSERT'
      and with_check ilike '%auth.uid%'
      and with_check ilike '%storage.foldername%'
      and with_check ilike '%visits%'
      and with_check ilike '%storage.extension%'
  ) then
    raise exception 'private visit-photo upload ownership contract is incomplete';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Visit audiences read private visit photos'
      and cmd = 'SELECT'
      and qual ilike '%auth.uid%'
      and qual ilike '%can_view_visit_photo_object%'
  ) then
    raise exception 'private visit-photo audience contract is incomplete';
  end if;

  if not exists (
    select 1
    from storage.buckets
    where id = 'visit-photos'
      and public
  ) then
    raise exception 'legacy visit-photo compatibility bucket changed visibility';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Anonymous viewers read Everyone private visit photos'
      and cmd = 'SELECT'
      and roles = '{anon}'::name[]
      and qual ilike '%can_view_visit_photo_object%'
  ) then
    raise exception 'private visit-photo anonymous Everyone policy is incomplete';
  end if;

  if not has_function_privilege(
    'anon',
    'public.can_view_visit_photo_object(text)',
    'EXECUTE'
  ) or not has_function_privilege(
    'authenticated',
    'public.can_view_visit_photo_object(text)',
    'EXECUTE'
  ) then
    raise exception 'visit-photo audience helper grants are incomplete';
  end if;

  if not exists (
    select 1
    from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public'
      and procedure.proname = 'can_view_visit_photo_object'
      and procedure.prosecdef
      and procedure.proconfig @> array['search_path=""']
  ) then
    raise exception 'visit-photo audience helper is not safely isolated';
  end if;
end $$;

select 'private_visit_photo_storage_contract_passed' as result;

begin;

create temp table private_visit_photo_behavior_context as
with ordered_users as (
  select id, row_number() over (order by id) as n
  from public.users
)
select
  (max(id::text) filter (where n = 1))::uuid as owner_id,
  (max(id::text) filter (where n = 2))::uuid as viewer_id,
  gen_random_uuid() as visit_id,
  null::text as object_name
from ordered_users
where n <= 2;

update private_visit_photo_behavior_context
set object_name = lower(owner_id::text)
  || '/'
  || lower(visit_id::text)
  || '/private-contract-'
  || gen_random_uuid()::text
  || '.jpg';

grant all on private_visit_photo_behavior_context to authenticated;
grant select on private_visit_photo_behavior_context to anon;

do $$
begin
  if exists (
    select 1
    from private_visit_photo_behavior_context
    where owner_id is null or viewer_id is null
  ) then
    raise exception 'private visit-photo behavior suite requires two users';
  end if;
end $$;

delete from public.user_blocks
where (blocker_id, blocked_id) in (
  select owner_id, viewer_id from private_visit_photo_behavior_context
  union all
  select viewer_id, owner_id from private_visit_photo_behavior_context
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
  'Private storage contract brew',
  '',
  'private',
  '{"overall":4}'::jsonb,
  4,
  'Home',
  'Private storage contract',
  'uploading'
from private_visit_photo_behavior_context;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from private_visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    select
      'visit-photos-private',
      lower(viewer_id::text) || '/' || lower(visit_id::text) || '/wrong-owner.jpg',
      owner_id,
      owner_id::text,
      '{"mimetype":"image/jpeg"}'::jsonb
    from private_visit_photo_behavior_context;
    raise exception 'owner uploaded a private photo into another user folder';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    select
      'visit-photos-private',
      lower(owner_id::text) || '/' || gen_random_uuid()::text || '/wrong-visit.jpg',
      owner_id,
      owner_id::text,
      '{"mimetype":"image/jpeg"}'::jsonb
    from private_visit_photo_behavior_context;
    raise exception 'owner uploaded a private photo outside an owned visit';
  exception when insufficient_privilege then
    null;
  end;
end $$;

insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
select
  'visit-photos-private',
  object_name,
  owner_id,
  owner_id::text,
  '{"mimetype":"image/jpeg"}'::jsonb
from private_visit_photo_behavior_context;

do $$
begin
  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos-private'
      and name = (select object_name from private_visit_photo_behavior_context)
  ) then
    raise exception 'owner could not read a private upload';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from private_visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos-private'
      and name = (select object_name from private_visit_photo_behavior_context)
  ) then
    raise exception 'non-owner read a private in-progress visit photo';
  end if;
end $$;

reset role;
set local role anon;
select set_config(
  'request.jwt.claims',
  jsonb_build_object('role', 'anon')::text,
  true
);

do $$
begin
  if exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos-private'
      and name = (select object_name from private_visit_photo_behavior_context)
  ) then
    raise exception 'anonymous viewer read a private in-progress visit photo';
  end if;
end $$;

reset role;

insert into public.friends (user_id, friend_user_id)
select owner_id, viewer_id from private_visit_photo_behavior_context
on conflict do nothing;

insert into public.friends (user_id, friend_user_id)
select viewer_id, owner_id from private_visit_photo_behavior_context
on conflict do nothing;

update public.visits
set visibility = 'friends', upload_state = 'complete'
where id = (select visit_id from private_visit_photo_behavior_context);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from private_visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos-private'
      and name = (select object_name from private_visit_photo_behavior_context)
  ) then
    raise exception 'confirmed friend could not read a friends-only visit photo';
  end if;
end $$;

reset role;

update public.visits
set visibility = 'private'
where id = (select visit_id from private_visit_photo_behavior_context);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from private_visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos-private'
      and name = (select object_name from private_visit_photo_behavior_context)
  ) then
    raise exception 'friend read a private visit photo';
  end if;
end $$;

reset role;

update public.visits
set visibility = 'everyone'
where id = (select visit_id from private_visit_photo_behavior_context);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from private_visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos-private'
      and name = (select object_name from private_visit_photo_behavior_context)
  ) then
    raise exception 'signed-in viewer could not read an everyone visit photo';
  end if;
end $$;

reset role;
set local role anon;
select set_config(
  'request.jwt.claims',
  jsonb_build_object('role', 'anon')::text,
  true
);

do $$
begin
  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos-private'
      and name = (select object_name from private_visit_photo_behavior_context)
  ) then
    raise exception 'anonymous viewer could not read an Everyone visit photo';
  end if;
end $$;

reset role;

delete from public.visits
where id = (select visit_id from private_visit_photo_behavior_context);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from private_visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if not exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos-private'
      and name = (select object_name from private_visit_photo_behavior_context)
  ) then
    raise exception 'owner could not read orphan metadata for cleanup';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select viewer_id from private_visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos-private'
      and name = (select object_name from private_visit_photo_behavior_context)
  ) then
    raise exception 'non-owner read orphan private visit-photo metadata';
  end if;
end $$;

reset role;
rollback;

select 'private_visit_photo_storage_behavior_passed' as result;
