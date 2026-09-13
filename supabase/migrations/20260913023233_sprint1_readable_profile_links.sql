-- Stable public usernames are addresses, not bearer secrets. All content still
-- passes the existing anonymous projection and publication checks.
create table private.profile_handle_reservations (
  handle text primary key check (handle ~ '^[a-z0-9_]{3,30}$'),
  owner_id uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now()
);
alter table private.profile_handle_reservations enable row level security;
revoke all on private.profile_handle_reservations from public, anon, authenticated;
insert into private.profile_handle_reservations(handle, owner_id)
  select lower(username), id from public.users
  where lower(username) ~ '^[a-z0-9_]{3,30}$';

create function private.reserve_profile_handle_v1()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if new.username is null then return new; end if;
  if lower(new.username) !~ '^[a-z0-9_]{3,30}$' then
    raise exception 'invalid username' using errcode = '22023';
  end if;
  insert into private.profile_handle_reservations(handle, owner_id)
    values (lower(new.username), new.id)
    on conflict (handle) do update set owner_id = excluded.owner_id
    where private.profile_handle_reservations.owner_id = excluded.owner_id;
  if not found then
    raise exception 'username unavailable' using errcode = '23505';
  end if;
  return new;
end;
$$;
revoke all on function private.reserve_profile_handle_v1() from public, anon, authenticated;
create trigger reserve_profile_handle
  after insert or update of username on public.users
  for each row execute function private.reserve_profile_handle_v1();

-- @ is an internal discriminator; public URLs use /profile/username.
create function private.profile_link_owner_v1(p_slug text)
returns uuid language sql stable security definer set search_path = '' as $$
  select identity.owner_id from (
    select reservation.owner_id from private.profile_handle_reservations reservation
    where p_slug ~ '^@[A-Za-z0-9_]{3,30}$'
      and reservation.handle = lower(substr(p_slug, 2))
    union all
    select link.owner_id from public.profile_share_links link
    where p_slug ~ '^[A-Za-z0-9_-]{24,128}$'
      and link.slug = p_slug and link.revoked_at is null
  ) identity
  where private.profile_owner_visible_v2(identity.owner_id, auth.uid())
  limit 1;
$$;
revoke all on function private.profile_link_owner_v1(text) from public, anon, authenticated;

create function public.get_my_profile_username_v1()
returns text language plpgsql stable security definer set search_path = '' as $$
declare result text;
begin
  if auth.uid() is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select lower(profile.username) into result from public.users profile
    where profile.id = auth.uid()
      and private.profile_owner_visible_v2(profile.id, auth.uid());
  if result is null or result !~ '^[a-z0-9_]{3,30}$' then
    raise exception 'complete your username before sharing' using errcode = '22023';
  end if;
  return result;
end;
$$;
revoke all on function public.get_my_profile_username_v1() from public, anon;
grant execute on function public.get_my_profile_username_v1() to authenticated;

create or replace function public.get_profile_link_v1(p_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
begin
  owner_id := private.profile_link_owner_v1(p_slug);

  if owner_id is null then
    return null;
  end if;
  return private.profile_projection_v4(owner_id, null);
end;
$$;
revoke all on function public.get_profile_link_v1(text) from public;
grant execute on function public.get_profile_link_v1(text) to anon, authenticated;

create or replace function public.list_profile_link_sips_v1(
  p_slug text,
  p_limit integer default 24,
  p_after_created_at timestamptz default null,
  p_after_id uuid default null
)
returns table (
  id uuid,
  user_id uuid,
  cafe_id uuid,
  caption text,
  drink_type text,
  drink_type_custom text,
  drink_subtype text,
  visibility text,
  ratings jsonb,
  overall_score double precision,
  poster_photo_url text,
  photo_urls text[],
  context_type text,
  location_name text,
  created_at timestamptz,
  cafe_name text,
  cafe_city text,
  latitude double precision,
  longitude double precision,
  identity_key text,
  author_display_name text,
  author_username text,
  author_avatar_url text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
begin
  owner_id := private.profile_link_owner_v1(p_slug);

  if owner_id is null
     or not private.profile_owner_visible_v2(owner_id, null) then
    return;
  end if;

  return query select * from private.profile_public_sips_page_v1(
    owner_id, p_limit, p_after_created_at, p_after_id
  );
end;
$$;
revoke all on function public.list_profile_link_sips_v1(text,integer,timestamptz,uuid) from public;
grant execute on function public.list_profile_link_sips_v1(text,integer,timestamptz,uuid) to anon, authenticated;

create or replace function public.list_profile_link_cafes_v1(
  p_slug text,
  p_limit integer default 500
)
returns table (
  id uuid,
  name text,
  city text,
  address text,
  latitude double precision,
  longitude double precision,
  identity_key text,
  score double precision,
  evidence_count integer,
  sip_count integer,
  cover_photo_url text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
begin
  owner_id := private.profile_link_owner_v1(p_slug);

  if owner_id is null
     or not private.profile_owner_visible_v2(owner_id, null) then
    return;
  end if;

  return query select * from private.profile_public_cafes_v1(owner_id, p_limit);
end;
$$;
revoke all on function public.list_profile_link_cafes_v1(text,integer) from public;
grant execute on function public.list_profile_link_cafes_v1(text,integer) to anon, authenticated;

create or replace function public.list_profile_link_tagged_sips_v1(
  p_slug text,
  p_limit integer default 24,
  p_after_created_at timestamptz default null,
  p_after_id uuid default null
)
returns table (
  id uuid,
  user_id uuid,
  cafe_id uuid,
  caption text,
  drink_type text,
  drink_type_custom text,
  drink_subtype text,
  visibility text,
  ratings jsonb,
  overall_score double precision,
  poster_photo_url text,
  photo_urls text[],
  context_type text,
  location_name text,
  created_at timestamptz,
  cafe_name text,
  cafe_city text,
  latitude double precision,
  longitude double precision,
  identity_key text,
  author_display_name text,
  author_username text,
  author_avatar_url text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
begin
  owner_id := private.profile_link_owner_v1(p_slug);

  if owner_id is null
     or not private.profile_owner_visible_v2(owner_id, null) then
    return;
  end if;

  return query select * from private.profile_public_tagged_sips_page_v1(
    owner_id, p_limit, p_after_created_at, p_after_id
  );
end;
$$;
revoke all on function public.list_profile_link_tagged_sips_v1(text,integer,timestamptz,uuid) from public;
grant execute on function public.list_profile_link_tagged_sips_v1(text,integer,timestamptz,uuid) to anon, authenticated;
