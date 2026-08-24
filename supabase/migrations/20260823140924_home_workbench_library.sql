-- Home Workbench: owner-only coffee and equipment libraries with safe,
-- immutable visit/recipe snapshots. This migration is additive and keeps all
-- existing visits and recipe payloads backward compatible.

create table public.home_coffee_bags (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  roaster text not null default '',
  name text not null default '',
  producer text not null default '',
  origin text not null default '',
  process text not null default '',
  variety text not null default '',
  roast_level text not null default '',
  roast_date date,
  tasting_notes text not null default '',
  starting_weight_grams double precision,
  remaining_weight_grams double precision,
  status text not null default 'open',
  opened_at timestamptz,
  frozen_at timestamptz,
  private_photo_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint home_coffee_bags_identity_present
    check (nullif(btrim(roaster), '') is not null or nullif(btrim(name), '') is not null),
  constraint home_coffee_bags_status_valid
    check (status in ('unopened', 'resting', 'open', 'frozen', 'finished', 'archived')),
  constraint home_coffee_bags_starting_weight_valid
    check (starting_weight_grams is null or starting_weight_grams > 0),
  constraint home_coffee_bags_remaining_weight_valid
    check (remaining_weight_grams is null or remaining_weight_grams >= 0),
  constraint home_coffee_bags_lengths_valid check (
    char_length(roaster) <= 200 and char_length(name) <= 240 and
    char_length(producer) <= 240 and char_length(origin) <= 240 and
    char_length(process) <= 160 and char_length(variety) <= 240 and
    char_length(roast_level) <= 120 and char_length(tasting_notes) <= 2000 and
    char_length(coalesce(private_photo_path, '')) <= 1000
  )
);

create index home_coffee_bags_owner_status_updated_idx
  on public.home_coffee_bags(user_id, status, updated_at desc);

create table public.home_equipment_profiles (
  id uuid primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null,
  nickname text not null default '',
  brand text not null default '',
  model text not null default '',
  notes text not null default '',
  archived_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint home_equipment_profiles_role_valid check (
    role in ('brewer', 'grinder', 'espresso_machine', 'kettle', 'filter', 'scale', 'other')
  ),
  constraint home_equipment_profiles_identity_present check (
    nullif(btrim(nickname), '') is not null or
    nullif(btrim(brand), '') is not null or
    nullif(btrim(model), '') is not null
  ),
  constraint home_equipment_profiles_lengths_valid check (
    char_length(nickname) <= 160 and char_length(brand) <= 160 and
    char_length(model) <= 200 and char_length(notes) <= 2000
  )
);

create index home_equipment_profiles_owner_role_updated_idx
  on public.home_equipment_profiles(user_id, role, updated_at desc);

alter table public.visits
  add column home_coffee_bag_id uuid
  references public.home_coffee_bags(id) on delete set null;

create index visits_owner_home_coffee_bag_created_idx
  on public.visits(user_id, home_coffee_bag_id, created_at desc)
  where home_coffee_bag_id is not null;

alter table public.home_coffee_bags enable row level security;
alter table public.home_equipment_profiles enable row level security;

revoke all on table public.home_coffee_bags from anon, authenticated;
revoke all on table public.home_equipment_profiles from anon, authenticated;
grant select, insert, update, delete on table public.home_coffee_bags to authenticated;
grant select, insert, update, delete on table public.home_equipment_profiles to authenticated;

create policy "Owners read Home coffee bags"
on public.home_coffee_bags for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Owners create Home coffee bags"
on public.home_coffee_bags for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Owners update Home coffee bags"
on public.home_coffee_bags for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Owners delete Home coffee bags"
on public.home_coffee_bags for delete to authenticated
using ((select auth.uid()) = user_id);

create policy "Owners read Home equipment"
on public.home_equipment_profiles for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Owners create Home equipment"
on public.home_equipment_profiles for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "Owners update Home equipment"
on public.home_equipment_profiles for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "Owners delete Home equipment"
on public.home_equipment_profiles for delete to authenticated
using ((select auth.uid()) = user_id);

-- Last-write-wins is enforced at the database boundary so a delayed offline
-- retry cannot replace a newer rename, archive tombstone, or inventory edit.
create function private.keep_newest_home_library_row_v1()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.updated_at < old.updated_at then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.keep_newest_home_library_row_v1()
  from public, anon, authenticated;

create trigger home_coffee_bags_keep_newest_v1
before update on public.home_coffee_bags
for each row execute function private.keep_newest_home_library_row_v1();

create trigger home_equipment_profiles_keep_newest_v1
before update on public.home_equipment_profiles
for each row execute function private.keep_newest_home_library_row_v1();

-- A visit cannot be attached to another account's bag even if a UUID is
-- guessed. The invoker-security trigger sees only the caller's owner rows.
create function private.enforce_visit_home_coffee_bag_owner_v1()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.home_coffee_bag_id is not null and not exists (
    select 1
    from public.home_coffee_bags bag
    where bag.id = new.home_coffee_bag_id
      and bag.user_id = new.user_id
  ) then
    raise exception 'Home coffee bag is unavailable' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_visit_home_coffee_bag_owner_v1()
  from public, anon, authenticated;

create trigger visits_home_coffee_bag_owner_v1
before insert or update of home_coffee_bag_id, user_id on public.visits
for each row execute function private.enforce_visit_home_coffee_bag_owner_v1();

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
) values (
  'home-coffee-bag-photos',
  'home-coffee-bag-photos',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/heic', 'image/heif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create policy "Owners read Home bag photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'home-coffee-bag-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Owners upload Home bag photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'home-coffee-bag-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Owners update Home bag photos"
on storage.objects for update to authenticated
using (
  bucket_id = 'home-coffee-bag-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'home-coffee-bag-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy "Owners delete Home bag photos"
on storage.objects for delete to authenticated
using (
  bucket_id = 'home-coffee-bag-photos'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Account deletion v3 rejects every Storage bucket it does not know how to
-- freeze, preflight, detach, and remove exactly. Extend those established
-- safety boundaries for this new owner-private bucket. CREATE OR REPLACE keeps
-- each function's owner and grants, and this migration fails closed if the
-- expected hardened definitions are unavailable.
do $home_deletion_protocol$
declare
  signature regprocedure;
  definition text;
  signatures regprocedure[] := array[
    'private.guard_account_storage_write_v3()'::regprocedure,
    'public.prepare_account_deletion_v3(uuid,uuid,uuid,text,text,uuid,text)'::regprocedure,
    'public.seal_account_deletion_storage_preflight_v3(uuid,uuid)'::regprocedure,
    'public.detach_account_storage_ownership_v3(uuid,uuid)'::regprocedure
  ];
begin
  foreach signature in array signatures loop
    definition := pg_get_functiondef(signature);
    if position('''profile-media''' in definition) = 0 then
      raise exception 'account deletion function % is missing the supported bucket boundary',
        signature;
    end if;
    if position('''home-coffee-bag-photos''' in definition) = 0 then
      definition := replace(
        definition,
        '''profile-media''',
        '''profile-media'', ''home-coffee-bag-photos'''
      );
      execute definition;
    end if;
  end loop;
end;
$home_deletion_protocol$;

-- Extend the explicit recipe projection allowlist with only accepted coffee
-- identity, public equipment labels, and brew variables. Library UUIDs,
-- inventory, OCR text, photo paths, and private notes are not present.
create or replace function public.get_recipe_projection_v1(p_recipe_version_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target record;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select
    version.id,
    version.recipe_identity_id,
    version.version_number,
    version.version_label,
    version.brew_details,
    coalesce(version.brew_method, source_visit.brew_method) brew_method,
    coalesce(version.equipment, source_visit.equipment) equipment,
    version.source_visit_id,
    version.visibility,
    version.source_kind,
    version.redistribution_allowed,
    version.source_recipe_version_id,
    version.created_at,
    identity.user_id owner_id,
    identity.name recipe_name,
    profile.display_name,
    profile.username,
    profile.avatar_url
  into target
  from public.recipe_versions version
  join public.recipe_identities identity
    on identity.id = version.recipe_identity_id
  join public.users profile on profile.id = identity.user_id
  left join public.visits source_visit on source_visit.id = version.source_visit_id
  where version.id = p_recipe_version_id;

  if not found
     or not private.can_project_recipe_version_as(p_recipe_version_id, actor) then
    return null;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'recipe_identity_id', target.recipe_identity_id,
    'recipe_version_id', target.id,
    'recipe_name', target.recipe_name,
    'version_number', target.version_number,
    'version_label', target.version_label,
    'visibility', target.visibility,
    'source_kind', target.source_kind,
    'source_recipe_version_id', case
      when target.source_recipe_version_id is null
        or private.can_project_recipe_version_as(target.source_recipe_version_id, actor)
      then target.source_recipe_version_id
    end,
    'owner', jsonb_build_object(
      'id', target.owner_id,
      'display_name', target.display_name,
      'username', target.username,
      'avatar_url', target.avatar_url
    ),
    'brew_method', target.brew_method,
    'equipment', target.equipment,
    'brew_details', jsonb_strip_nulls(jsonb_build_object(
      'beans', target.brew_details -> 'beans',
      'doseGrams', target.brew_details -> 'doseGrams',
      'yieldGrams', target.brew_details -> 'yieldGrams',
      'brewTimeSeconds', target.brew_details -> 'brewTimeSeconds',
      'beanOrigin', target.brew_details -> 'beanOrigin',
      'roastLevel', target.brew_details -> 'roastLevel',
      'grindSetting', target.brew_details -> 'grindSetting',
      'waterTemperatureCelsius', target.brew_details -> 'waterTemperatureCelsius',
      'waterNotes', target.brew_details -> 'waterNotes',
      'recipeName', target.brew_details -> 'recipeName',
      'recipeVersion', target.brew_details -> 'recipeVersion',
      'steps', target.brew_details -> 'steps',
      'additions', target.brew_details -> 'additions',
      'servingVolumeMilliliters', target.brew_details -> 'servingVolumeMilliliters',
      'espressoShotCount', target.brew_details -> 'espressoShotCount',
      'coffeeBag', target.brew_details -> 'coffeeBag',
      'equipmentSnapshots', target.brew_details -> 'equipmentSnapshots',
      'homeMethodDetails', target.brew_details -> 'homeMethodDetails'
    )),
    'can_save_and_adapt',
      target.visibility = 'everyone'
      and target.source_kind in ('original', 'adapted')
      and target.redistribution_allowed,
    'created_at', target.created_at
  ));
end;
$$;

revoke all on function public.get_recipe_projection_v1(uuid) from public, anon;
grant execute on function public.get_recipe_projection_v1(uuid) to authenticated;

-- Add Home library collections to the mature export without weakening its
-- existing owner checks or social redaction.
create or replace function public.build_owner_data_export_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
  tags jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  result := private.build_owner_data_export_with_retired_shared_v2();
  result := jsonb_set(
    result,
    '{collaboration}',
    (result -> 'collaboration')
      - 'created_shared_memories'
      - 'managed_shared_memories'
      - 'shared_memory_memberships'
      - 'shared_memory_contributions'
  );
  result := jsonb_set(
    result,
    '{export_manifest,included_collections}',
    (
      select coalesce(jsonb_agg(collection), '[]'::jsonb)
      from jsonb_array_elements(
        result #> '{export_manifest,included_collections}'
      ) collection
      where lower(collection #>> '{}') not like '%shared mugshot%'
    )
  );
  select coalesce(
    jsonb_agg(to_jsonb(tag) order by tag.created_at, tag.visit_id, tag.tagged_user_id),
    '[]'::jsonb
  ) into tags
  from public.visit_tags tag
  where tag.tagged_by = actor or tag.tagged_user_id = actor;
  result := jsonb_set(
    result,
    '{social}',
    ((result -> 'social') - 'visit_tags_added_or_received')
      || jsonb_build_object('visit_tags_added_or_received', tags)
  );
  result := jsonb_set(
    result,
    '{media_references}',
    coalesce(result -> 'media_references', '[]'::jsonb)
      || coalesce((
        select jsonb_agg(jsonb_build_object(
          'kind', 'storage',
          'bucket', object.bucket_id,
          'path', object.name,
          'access', 'private'
        ) order by object.name)
        from storage.objects object
        where object.bucket_id = 'home-coffee-bag-photos'
          and lower(pg_catalog.split_part(object.name, '/', 1)) = lower(actor::text)
      ), '[]'::jsonb)
  );
  result := jsonb_set(
    result,
    '{home_workbench}',
    jsonb_build_object(
      'coffee_bags', coalesce((
        select jsonb_agg(to_jsonb(bag) order by bag.created_at, bag.id)
        from public.home_coffee_bags bag
        where bag.user_id = actor
      ), '[]'::jsonb),
      'equipment_profiles', coalesce((
        select jsonb_agg(to_jsonb(profile) order by profile.created_at, profile.id)
        from public.home_equipment_profiles profile
        where profile.user_id = actor
      ), '[]'::jsonb)
    ),
    true
  );
  return result;
end;
$$;

revoke all on function public.build_owner_data_export_v2()
  from public, anon, authenticated;
grant execute on function public.build_owner_data_export_v2()
  to authenticated;
