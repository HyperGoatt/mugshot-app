do $$
begin
  if not exists (
    select 1
    from storage.buckets
    where id = 'visit-photos'
      and name = 'visit-photos'
      and public
      and file_size_limit = 10485760
  ) then
    raise exception 'visit-photos bucket settings are incorrect';
  end if;

  if (
    select count(*)
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'Authenticated users can upload visit photos',
        'Users can update their own visit photos',
        'Users can delete their own visit photos',
        'Owners can read their visit photo objects',
        'View photos based on completed visit visibility'
      )
  ) <> 5 then
    raise exception 'visit-photo Storage policies are incomplete';
  end if;

  if exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname in (
        'Authenticated users can upload visit photos',
        'Users can update their own visit photos',
        'Users can delete their own visit photos'
      )
      and roles <> '{authenticated}'::name[]
  ) then
    raise exception 'visit-photo mutation policy has a role broader than authenticated';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Authenticated users can upload visit photos'
      and with_check ilike '%visit-photos%'
      and with_check ilike '%auth.uid%'
      and with_check ilike '%storage.extension%'
  ) then
    raise exception 'visit-photo upload ownership or file-type guard is missing';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Users can delete their own visit photos'
      and qual ilike '%visit-photos%'
      and qual ilike '%auth.uid%'
  ) then
    raise exception 'visit-photo delete ownership guard is missing';
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'storage'
      and tablename = 'objects'
      and policyname = 'Owners can read their visit photo objects'
      and roles = '{authenticated}'::name[]
      and qual ilike '%visit-photos%'
      and qual ilike '%auth.uid%'
  ) then
    raise exception 'visit-photo owner cleanup read guard is missing';
  end if;
end $$;

select 'visit_photo_storage_contract_passed' as result;

begin;

create temp table visit_photo_behavior_context as
with ordered_users as (
  select id, row_number() over (order by id) as n
  from public.users
)
select
  (max(id::text) filter (where n = 1))::uuid as owner_id,
  (max(id::text) filter (where n = 2))::uuid as stranger_id,
  gen_random_uuid() as visit_id,
  null::text as object_name
from ordered_users
where n <= 2;

update visit_photo_behavior_context
set object_name = lower(owner_id::text)
  || '/'
  || lower(visit_id::text)
  || '/contract-'
  || gen_random_uuid()::text
  || '.jpg';

grant all on visit_photo_behavior_context to authenticated;

do $$
begin
  if exists (
    select 1
    from visit_photo_behavior_context
    where owner_id is null or stranger_id is null
  ) then
    raise exception 'visit-photo behavior suite requires two users';
  end if;
end $$;

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
  'Storage contract brew',
  '',
  'private',
  '{"overall":4}'::jsonb,
  4,
  'Home',
  'Storage contract',
  'uploading'
from visit_photo_behavior_context;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  begin
    insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    select
      'visit-photos',
      lower(stranger_id::text) || '/' || lower(visit_id::text) || '/wrong-owner.jpg',
      owner_id,
      owner_id::text,
      '{"mimetype":"image/jpeg"}'::jsonb
    from visit_photo_behavior_context;
    raise exception 'owner uploaded into another user folder';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
    select
      'visit-photos',
      lower(owner_id::text) || '/' || lower(visit_id::text) || '/invalid.txt',
      owner_id,
      owner_id::text,
      '{"mimetype":"text/plain"}'::jsonb
    from visit_photo_behavior_context;
    raise exception 'owner uploaded a disallowed file type';
  exception when insufficient_privilege then
    null;
  end;
end $$;

insert into storage.objects (bucket_id, name, owner, owner_id, metadata)
select
  'visit-photos',
  object_name,
  owner_id,
  owner_id::text,
  '{"mimetype":"image/jpeg"}'::jsonb
from visit_photo_behavior_context;

reset role;

update public.visits visit
set poster_photo_url = 'https://example.test/storage/v1/object/public/visit-photos/' || context.object_name
from visit_photo_behavior_context context
where visit.id = context.visit_id;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare affected integer;
begin
  if (
    select count(*)
    from storage.objects
    where bucket_id = 'visit-photos'
      and name = (select object_name from visit_photo_behavior_context)
  ) <> 1 then
    raise exception 'owner could not read attached visit photo metadata';
  end if;

  update storage.objects
  set metadata = coalesce(metadata, '{}'::jsonb) || '{"contract":"owner-update"}'::jsonb
  where bucket_id = 'visit-photos'
    and name = (select object_name from visit_photo_behavior_context);
  get diagnostics affected = row_count;
  if affected <> 1 then
    raise exception 'owner could not update visit photo';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select stranger_id from visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
declare affected integer;
begin
  if exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos'
      and name = (select object_name from visit_photo_behavior_context)
  ) then
    raise exception 'stranger read private visit photo metadata';
  end if;

  update storage.objects
  set metadata = coalesce(metadata, '{}'::jsonb) || '{"contract":"stranger-update"}'::jsonb
  where bucket_id = 'visit-photos'
    and name = (select object_name from visit_photo_behavior_context);
  get diagnostics affected = row_count;
  if affected <> 0 then
    raise exception 'stranger updated another user visit photo';
  end if;
end $$;

reset role;

delete from public.visits
where id = (select visit_id from visit_photo_behavior_context);

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select owner_id from visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if (
    select count(*)
    from storage.objects
    where bucket_id = 'visit-photos'
      and name = (select object_name from visit_photo_behavior_context)
  ) <> 1 then
    raise exception 'owner could not read orphan metadata for durable cleanup';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select stranger_id from visit_photo_behavior_context),
    'role', 'authenticated'
  )::text,
  true
);

do $$
begin
  if exists (
    select 1
    from storage.objects
    where bucket_id = 'visit-photos'
      and name = (select object_name from visit_photo_behavior_context)
  ) then
    raise exception 'stranger read orphan visit photo metadata';
  end if;
end $$;

reset role;
rollback;

select 'visit_photo_storage_behavior_passed' as result;
