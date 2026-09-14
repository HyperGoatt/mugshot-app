begin;

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

  -- Older clients prefill the generated signup placeholder. Keep the server as
  -- the final guard so those clients cannot accidentally confirm it unchanged.
  if exists (
    select 1
    from public.users profile
    join auth.users identity on identity.id = profile.id
    where profile.id = actor
      and profile.profile_username_confirmed_at is null
      and lower(btrim(profile.username)) = normalized_username
      and normalized_username ~ (
        '^'
        || lower(regexp_replace(split_part(coalesce(identity.email, ''), '@', 1), '[^a-z0-9]', '', 'g'))
        || '_'
        || substr(identity.id::text, 1, 4)
        || '[0-9]*$'
      )
  ) then
    raise exception 'choose a public username before continuing'
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

commit;
