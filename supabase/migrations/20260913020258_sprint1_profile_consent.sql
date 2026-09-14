-- Legacy preferences are not evidence of informed public publication consent.
alter table public.profile_visibility_preferences
  alter column show_friends_on_public_profile set default false,
  add column public_consent_version integer,
  add column public_consented_at timestamptz;

create or replace function private.profile_shows_friends_v1(p_owner uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.profile_visibility_preferences preference
    where preference.user_id = p_owner
      and preference.show_friends_on_public_profile
      and preference.public_consent_version = 1
      and preference.public_consented_at is not null
  );
$$;

create or replace function private.profile_visit_published_v1(
  p_visit_id uuid, p_profile_owner uuid
)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.visits visit
    where visit.id = p_visit_id
      and visit.upload_state = 'complete'
      and private.profile_owner_visible_v2(visit.user_id, null)
      and not private.has_active_moderation_action(
        'visit', visit.id, array['content_hidden']::text[]
      )
      and (
        lower(visit.visibility) = 'everyone'
        or (lower(visit.visibility) = 'friends'
          and private.profile_shows_friends_v1(visit.user_id)
          and private.profile_shows_friends_v1(p_profile_owner))
      )
  );
$$;

create or replace function public.get_profile_friends_visibility_v2()
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  return private.profile_shows_friends_v1(actor);
end;
$$;

create or replace function public.set_profile_friends_visibility_v2(
  p_enabled boolean, p_consent_version integer
)
returns boolean language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_enabled is null or (p_enabled and p_consent_version is distinct from 1) then
    raise exception 'current public profile consent is required' using errcode = '22023';
  end if;
  insert into public.profile_visibility_preferences (
    user_id, show_friends_on_public_profile, public_consent_version, public_consented_at
  ) values (
    actor, p_enabled, case when p_enabled then 1 end,
    case when p_enabled then now() end
  ) on conflict (user_id) do update
    set show_friends_on_public_profile = excluded.show_friends_on_public_profile,
        public_consent_version = excluded.public_consent_version,
        public_consented_at = excluded.public_consented_at,
        updated_at = now();
  return p_enabled;
end;
$$;

-- An old client can withdraw publication but cannot manufacture consent.
create or replace function public.set_profile_friends_visibility_v1(p_enabled boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if p_enabled is distinct from false then
    raise exception 'update Mugshot to consent to public profile publication'
      using errcode = '22023';
  end if;
  return public.set_profile_friends_visibility_v2(false, null);
end;
$$;

revoke all on function public.set_profile_friends_visibility_v2(boolean,integer)
  from public, anon;
revoke all on function public.get_profile_friends_visibility_v2()
  from public, anon;
grant execute on function public.get_profile_friends_visibility_v2()
  to authenticated;
grant execute on function public.set_profile_friends_visibility_v2(boolean,integer)
  to authenticated;
comment on function public.set_profile_friends_visibility_v2(boolean,integer) is
  'Caller-bound, versioned opt-in for existing and future Friends posts on public profiles.';
