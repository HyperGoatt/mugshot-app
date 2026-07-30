-- Phase 2 makes Journal the canonical owner surface and gives repeatable
-- recipes immutable identities and versions. Existing visits remain the
-- authoritative sip record.

create table if not exists public.visit_bookmarks (
  user_id uuid not null references auth.users(id) on delete cascade,
  visit_id uuid not null references public.visits(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, visit_id)
);

alter table public.visit_bookmarks enable row level security;

drop policy if exists "Owners read journal bookmarks" on public.visit_bookmarks;
create policy "Owners read journal bookmarks"
on public.visit_bookmarks for select
to authenticated
using (user_id = auth.uid());

drop policy if exists "Owners add journal bookmarks" on public.visit_bookmarks;
create policy "Owners add journal bookmarks"
on public.visit_bookmarks for insert
to authenticated
with check (
  user_id = auth.uid()
  and exists (
    select 1 from public.visits visit
    where visit.id = visit_id and visit.user_id = auth.uid()
  )
);

drop policy if exists "Owners remove journal bookmarks" on public.visit_bookmarks;
create policy "Owners remove journal bookmarks"
on public.visit_bookmarks for delete
to authenticated
using (user_id = auth.uid());

revoke all on public.visit_bookmarks from public, anon;
grant select, insert, delete on public.visit_bookmarks to authenticated;

create index if not exists visit_bookmarks_owner_created_idx
  on public.visit_bookmarks (user_id, created_at desc);

create table if not exists public.recipe_identities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 120),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.recipe_versions (
  id uuid primary key default gen_random_uuid(),
  recipe_identity_id uuid not null references public.recipe_identities(id) on delete cascade,
  version_number integer not null check (version_number > 0),
  version_label text,
  brew_details jsonb not null default '{}'::jsonb check (jsonb_typeof(brew_details) = 'object'),
  source_visit_id uuid unique references public.visits(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (recipe_identity_id, version_number)
);

alter table public.visits
  add column if not exists recipe_version_id uuid references public.recipe_versions(id) on delete set null;

create index if not exists recipe_identities_owner_updated_idx
  on public.recipe_identities (user_id, updated_at desc);
create index if not exists recipe_versions_identity_number_idx
  on public.recipe_versions (recipe_identity_id, version_number desc);
create index if not exists visits_recipe_version_idx
  on public.visits (recipe_version_id) where recipe_version_id is not null;

alter table public.recipe_identities enable row level security;
alter table public.recipe_versions enable row level security;

drop policy if exists "Owners manage recipe identities" on public.recipe_identities;
create policy "Owners manage recipe identities"
on public.recipe_identities for all
to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid());

drop policy if exists "Owners read recipe versions" on public.recipe_versions;
create policy "Owners read recipe versions"
on public.recipe_versions for select
to authenticated
using (
  exists (
    select 1 from public.recipe_identities identity
    where identity.id = recipe_identity_id and identity.user_id = auth.uid()
  )
);

revoke all on public.recipe_identities, public.recipe_versions from public, anon;
grant select, insert, update, delete on public.recipe_identities to authenticated;
grant select on public.recipe_versions to authenticated;

create or replace function public.materialize_visit_recipe_version(p_visit_id uuid)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  target public.visits%rowtype;
  identity_id uuid;
  version_id uuid;
  next_version integer;
  recipe_name text;
  version_label text;
begin
  select * into target from public.visits where id = p_visit_id for update;
  if not found or target.recipe_version_id is not null then
    return target.recipe_version_id;
  end if;

  recipe_name := nullif(trim(coalesce(target.brew_details ->> 'recipeName', '')), '');
  if lower(coalesce(target.context_type, '')) <> 'recipe' and recipe_name is null then
    return null;
  end if;
  recipe_name := coalesce(recipe_name, nullif(trim(target.drink_subtype), ''), 'Saved recipe');
  version_label := nullif(trim(coalesce(target.brew_details ->> 'recipeVersion', '')), '');

  begin
    identity_id := nullif(target.brew_details ->> 'recipeIdentityID', '')::uuid;
  exception when invalid_text_representation then
    identity_id := null;
  end;

  if identity_id is not null and exists (
    select 1 from public.recipe_identities identity
    where identity.id = identity_id and identity.user_id <> target.user_id
  ) then
    identity_id := null;
  end if;
  identity_id := coalesce(identity_id, gen_random_uuid());

  insert into public.recipe_identities (id, user_id, name)
  values (identity_id, target.user_id, recipe_name)
  on conflict (id) do update
    set name = excluded.name, updated_at = now()
    where public.recipe_identities.user_id = excluded.user_id;

  select coalesce(max(version_number), 0) + 1
    into next_version
    from public.recipe_versions
    where recipe_identity_id = identity_id;

  insert into public.recipe_versions (
    recipe_identity_id, version_number, version_label, brew_details, source_visit_id
  ) values (
    identity_id, next_version, version_label, target.brew_details, target.id
  )
  returning id into version_id;

  update public.visits
  set recipe_version_id = version_id,
      brew_details = jsonb_set(
        brew_details,
        '{recipeIdentityID}',
        to_jsonb(identity_id::text),
        true
      )
  where id = target.id;

  return version_id;
end;
$$;

revoke all on function public.materialize_visit_recipe_version(uuid) from public, anon, authenticated;

create or replace function public.materialize_new_visit_recipe_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.materialize_visit_recipe_version(new.id);
  return new;
end;
$$;

drop trigger if exists materialize_visit_recipe_version_after_insert on public.visits;
create trigger materialize_visit_recipe_version_after_insert
after insert on public.visits
for each row execute function public.materialize_new_visit_recipe_version();

do $$
declare
  visit_row record;
begin
  for visit_row in
    select id from public.visits
    where recipe_version_id is null
      and (
        lower(coalesce(context_type, '')) = 'recipe'
        or nullif(trim(coalesce(brew_details ->> 'recipeName', '')), '') is not null
      )
    order by created_at, id
  loop
    perform public.materialize_visit_recipe_version(visit_row.id);
  end loop;
end;
$$;

;
