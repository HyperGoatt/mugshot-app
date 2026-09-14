begin;

alter table public.users
  add column if not exists profile_username_confirmed_at timestamptz;

-- The legacy signup trigger creates a collision-safe placeholder from the
-- email-local-part and the first four account-ID characters. Accounts that
-- still carry that exact placeholder must choose or explicitly re-enter a
-- public handle. No username is changed by this migration.
update public.users profile
set profile_username_confirmed_at = profile.profile_setup_completed_at
where profile.profile_setup_completed_at is not null
  and not exists (
    select 1
    from auth.users identity
    where identity.id = profile.id
      and lower(btrim(profile.username)) ~ (
        '^'
        || lower(regexp_replace(split_part(coalesce(identity.email, ''), '@', 1), '[^a-z0-9]', '', 'g'))
        || '_'
        || substr(identity.id::text, 1, 4)
        || '[0-9]*$'
      )
  );

create or replace function public.get_profile_setup_state_v1()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select jsonb_build_object(
    'user_id', profile.id,
    'is_complete',
      profile.profile_setup_completed_at is not null
      and profile.profile_username_confirmed_at is not null,
    'completed_at', profile.profile_setup_completed_at,
    'requires_username_confirmation', profile.profile_username_confirmed_at is null
  ) into result
  from public.users profile
  where profile.id = actor;

  return coalesce(result, jsonb_build_object(
    'user_id', actor,
    'is_complete', false,
    'completed_at', null,
    'requires_username_confirmation', true
  ));
end;
$$;

create or replace function public.complete_profile_setup_v1(
  p_display_name text,
  p_username text,
  p_bio text default null,
  p_location text default null,
  p_instagram_handle text default null,
  p_website_url text default null,
  p_favorite_drink text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_name text := btrim(coalesce(p_display_name, ''));
  normalized_username text := lower(btrim(coalesce(p_username, '')));
  result jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if char_length(normalized_name) not between 1 and 80 then
    raise exception 'display name must be between 1 and 80 characters'
      using errcode = '22023';
  end if;
  if normalized_username !~ '^[a-z0-9_]{3,30}$' then
    raise exception 'handle must be 3 to 30 letters, numbers, or underscores'
      using errcode = '22023';
  end if;
  if exists (
    select 1 from public.users profile
    where lower(btrim(profile.username)) = normalized_username
      and profile.id <> actor
  ) then
    raise exception 'handle is already taken' using errcode = '23505';
  end if;

  update public.users profile
  set display_name = normalized_name,
      username = normalized_username,
      bio = nullif(btrim(coalesce(p_bio, '')), ''),
      location = nullif(btrim(coalesce(p_location, '')), ''),
      instagram_handle = nullif(
        ltrim(btrim(coalesce(p_instagram_handle, '')), '@'), ''
      ),
      website_url = nullif(btrim(coalesce(p_website_url, '')), ''),
      favorite_drink = nullif(btrim(coalesce(p_favorite_drink, '')), ''),
      profile_setup_completed_at = coalesce(profile.profile_setup_completed_at, now()),
      profile_username_confirmed_at = now()
  where profile.id = actor
  returning jsonb_build_object(
    'id', profile.id,
    'display_name', profile.display_name,
    'username', profile.username,
    'bio', profile.bio,
    'location', profile.location,
    'favorite_drink', profile.favorite_drink,
    'instagram_handle', profile.instagram_handle,
    'avatar_url', profile.avatar_url,
    'banner_url', profile.banner_url,
    'website_url', profile.website_url,
    'profile_setup_completed_at', profile.profile_setup_completed_at
  ) into result;

  if result is null then
    raise exception 'profile not found' using errcode = 'P0002';
  end if;
  return result;
end;
$$;

comment on column public.users.profile_username_confirmed_at is
  'Set only when the account explicitly submits its public username through profile setup.';

commit;
