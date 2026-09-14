-- Production already has this field, but the recorded history omitted it.
-- Restore reproducible profile projections without rewriting existing values.
alter table public.users add column if not exists website_url text;

-- Website text is also part of the outward profile, so include it in screening.
create or replace function private.refresh_profile_screening_v1(p_owner uuid)
returns void language plpgsql security definer set search_path='' as $$
declare payload jsonb;
begin
  select jsonb_build_object(
    'text',concat_ws(E'\n',profile.display_name,profile.username,profile.bio,profile.location,
      profile.favorite_drink,profile.instagram_handle,profile.website_url,
      (select string_agg(spot.descriptor,E'\n' order by spot.position) from public.profile_favorite_spots spot where spot.user_id=profile.id)),
    'images',to_jsonb(array_remove(array[nullif(profile.avatar_url,''),nullif(profile.banner_url,'')],null))
  ) into payload from public.users profile where profile.id=p_owner;
  perform private.enqueue_screening_v1('user',p_owner,p_owner,payload);
end;
$$;
select private.refresh_profile_screening_v1(id) from public.users;
