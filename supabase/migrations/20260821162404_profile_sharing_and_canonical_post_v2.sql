begin;

-- ---------------------------------------------------------------------------
-- Profile setup, durable highlights, and opaque profile links
-- ---------------------------------------------------------------------------

alter table public.users
  add column if not exists profile_setup_completed_at timestamptz;

-- Accounts that predate this contract already have usable identities. New
-- rows intentionally receive NULL until complete_profile_setup_v1 succeeds.
update public.users
set profile_setup_completed_at = coalesce(profile_setup_completed_at, now());

create unique index if not exists users_username_case_insensitive_unique_idx
  on public.users (lower(btrim(username)));

create table public.profile_highlights (
  user_id uuid primary key references public.users(id) on delete cascade,
  highlight_type text not null check (highlight_type in ('sip', 'cafe')),
  visit_id uuid references public.visits(id) on delete cascade,
  cafe_id uuid references public.cafes(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint profile_highlights_exact_target check (
    (highlight_type = 'sip' and visit_id is not null and cafe_id is null)
    or (highlight_type = 'cafe' and cafe_id is not null and visit_id is null)
  )
);

create index profile_highlights_visit_idx
  on public.profile_highlights(visit_id) where visit_id is not null;
create index profile_highlights_cafe_idx
  on public.profile_highlights(cafe_id) where cafe_id is not null;

alter table public.profile_highlights enable row level security;
alter table public.profile_highlights force row level security;
revoke all on table public.profile_highlights from public, anon, authenticated;

create table public.profile_share_links (
  owner_id uuid primary key references public.users(id) on delete cascade,
  slug text not null unique check (slug ~ '^[A-Za-z0-9_-]{24,128}$'),
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create index profile_share_links_active_slug_idx
  on public.profile_share_links(slug) where revoked_at is null;

alter table public.profile_share_links enable row level security;
alter table public.profile_share_links force row level security;
revoke all on table public.profile_share_links from public, anon, authenticated;

create or replace function private.profile_owner_visible_v2(
  p_owner uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_owner)
    and (
      p_viewer is null
      or (
        private.is_live_account_as(p_viewer)
        and not private.blocked_between(p_viewer, p_owner)
      )
    )
    and (
      p_viewer = p_owner
      or not private.has_active_moderation_action(
        'user', p_owner, array['account_suspended']::text[]
      )
    );
$$;

create or replace function private.profile_visit_visible_v2(
  p_visit_id uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and visit.upload_state = 'complete'
      and private.profile_owner_visible_v2(visit.user_id, p_viewer)
      and not private.has_active_moderation_action(
        'visit', visit.id, array['content_hidden']::text[]
      )
      and (
        visit.user_id = p_viewer
        or visit.visibility = 'everyone'
        or (
          p_viewer is not null
          and visit.visibility = 'friends'
          and private.confirmed_friends(p_viewer, visit.user_id)
        )
      )
  );
$$;

revoke all on function private.profile_owner_visible_v2(uuid,uuid)
  from public, anon, authenticated;
revoke all on function private.profile_visit_visible_v2(uuid,uuid)
  from public, anon, authenticated;

create or replace function private.profile_top_cafes_v2(
  p_owner uuid,
  p_viewer uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with visible_sips as (
    select visit.*
    from public.visits visit
    where visit.user_id = p_owner
      and visit.cafe_id is not null
      and lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
      and private.profile_visit_visible_v2(visit.id, p_viewer)
  ),
  sip_scores as (
    select
      visit.cafe_id,
      avg(visit.overall_score)::double precision sip_average,
      count(*)::integer sip_count,
      max(visit.created_at) latest_sip_at
    from visible_sips visit
    group by visit.cafe_id
  ),
  pulse_scores as (
    select
      projection.cafe_id,
      avg(projection.cafe_rating)::double precision pulse_average,
      count(*)::integer pulse_count
    from public.cafe_experience_public_projections projection
    join visible_sips visit on visit.id = projection.primary_visit_id
    where projection.user_id = p_owner
      and projection.includes_cafe_rating
      and projection.cafe_rating is not null
    group by projection.cafe_id
  ),
  ranked as (
    select
      cafe.id,
      cafe.name,
      cafe.city,
      cafe.address,
      cafe.latitude,
      cafe.longitude,
      cafe.identity_key,
      coalesce(pulse.pulse_average, sip.sip_average) score,
      case when pulse.pulse_average is not null
        then 'cafe_pulse' else 'sip_average' end basis,
      coalesce(pulse.pulse_count, sip.sip_count) evidence_count,
      sip.sip_count,
      (
        select coalesce(
          nullif(btrim(photo_visit.poster_photo_url), ''),
          (
            select nullif(btrim(photo.photo_url), '')
            from public.visit_photos photo
            where photo.visit_id = photo_visit.id
              and nullif(btrim(photo.photo_url), '') is not null
            order by photo.sort_order, photo.created_at, photo.id
            limit 1
          )
        )
        from visible_sips photo_visit
        where photo_visit.cafe_id = cafe.id
        order by photo_visit.created_at desc, photo_visit.id desc
        limit 1
      ) cover_photo_url,
      sip.latest_sip_at
    from sip_scores sip
    join public.cafes cafe on cafe.id = sip.cafe_id
    left join pulse_scores pulse on pulse.cafe_id = sip.cafe_id
    order by
      (pulse.pulse_average is not null) desc,
      coalesce(pulse.pulse_average, sip.sip_average) desc,
      coalesce(pulse.pulse_count, sip.sip_count) desc,
      sip.latest_sip_at desc,
      cafe.id
    limit 5
  )
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ranked.id,
        'name', ranked.name,
        'city', ranked.city,
        'address', ranked.address,
        'latitude', ranked.latitude,
        'longitude', ranked.longitude,
        'identity_key', ranked.identity_key,
        'score', ranked.score,
        'basis', ranked.basis,
        'evidence_count', ranked.evidence_count,
        'sip_count', ranked.sip_count,
        'cover_photo_url', ranked.cover_photo_url
      )
      order by
        (ranked.basis = 'cafe_pulse') desc,
        ranked.score desc,
        ranked.evidence_count desc,
        ranked.latest_sip_at desc,
        ranked.id
    ),
    '[]'::jsonb
  )
  from ranked;
$$;

create or replace function private.profile_highlight_v2(
  p_owner uuid,
  p_viewer uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  target public.profile_highlights%rowtype;
  result jsonb;
begin
  select * into target
  from public.profile_highlights highlight
  where highlight.user_id = p_owner;

  if not found then
    return null;
  end if;

  if target.highlight_type = 'sip' then
    if not private.profile_visit_visible_v2(target.visit_id, p_viewer) then
      return null;
    end if;

    select jsonb_build_object(
      'type', 'sip',
      'sip', jsonb_build_object(
        'id', visit.id,
        'caption', visit.caption,
        'drink_name', coalesce(
          nullif(btrim(visit.drink_subtype), ''),
          nullif(btrim(visit.drink_type_custom), ''),
          nullif(btrim(visit.drink_type), ''),
          'Coffee memory'
        ),
        'score', visit.overall_score,
        'cover_photo_url', coalesce(
          nullif(btrim(visit.poster_photo_url), ''),
          (
            select nullif(btrim(photo.photo_url), '')
            from public.visit_photos photo
            where photo.visit_id = visit.id
              and nullif(btrim(photo.photo_url), '') is not null
            order by photo.sort_order, photo.created_at, photo.id
            limit 1
          )
        ),
        'created_at', visit.created_at
      )
    ) into result
    from public.visits visit
    where visit.id = target.visit_id;
  else
    select jsonb_build_object(
      'type', 'cafe',
      'cafe', jsonb_build_object(
        'id', cafe.id,
        'name', cafe.name,
        'city', cafe.city,
        'address', cafe.address,
        'latitude', cafe.latitude,
        'longitude', cafe.longitude,
        'identity_key', cafe.identity_key,
        'cover_photo_url', (
          select coalesce(
            nullif(btrim(visit.poster_photo_url), ''),
            (
              select nullif(btrim(photo.photo_url), '')
              from public.visit_photos photo
              where photo.visit_id = visit.id
                and nullif(btrim(photo.photo_url), '') is not null
              order by photo.sort_order, photo.created_at, photo.id
              limit 1
            )
          )
          from public.visits visit
          where visit.user_id = p_owner
            and visit.cafe_id = cafe.id
            and private.profile_visit_visible_v2(visit.id, p_viewer)
          order by visit.created_at desc, visit.id desc
          limit 1
        )
      )
    ) into result
    from public.cafes cafe
    where cafe.id = target.cafe_id;
  end if;

  return result;
end;
$$;

revoke all on function private.profile_top_cafes_v2(uuid,uuid)
  from public, anon, authenticated;
revoke all on function private.profile_highlight_v2(uuid,uuid)
  from public, anon, authenticated;

create or replace function private.can_view_taste_passport_v2(
  p_owner uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.profile_owner_visible_v2(p_owner, p_viewer)
    and exists (
      select 1
      from public.users owner
      where owner.id = p_owner
        and (
          owner.taste_passport_visibility = 'everyone'
          or owner.id = p_viewer
          or (
            p_viewer is not null
            and owner.taste_passport_visibility = 'friends'
            and private.confirmed_friends(p_viewer, owner.id)
          )
        )
    );
$$;

create or replace function private.taste_passport_projection_v2(
  p_owner uuid,
  p_viewer uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  owner_visibility text;
  order_attribute text;
  order_label text;
  order_support integer := 0;
  order_confidence numeric := 0;
  sensory_attribute text;
  sensory_label text;
  sensory_support integer := 0;
  sensory_confidence numeric := 0;
  complete_visits integer := 0;
  home_visits integer := 0;
  cafe_visits integer := 0;
  recipe_visits integer := 0;
  distinct_cafes integer := 0;
  repeated_cafe_visits integer := 0;
  ritual_label text;
  confidence_band text;
  description text;
  passport_is_forming boolean;
  latest_signal_at timestamptz;
begin
  if not private.can_view_taste_passport_v2(p_owner, p_viewer) then
    return null;
  end if;

  select profile.taste_passport_visibility into owner_visibility
  from public.users profile where profile.id = p_owner;

  select
    signal.attribute,
    coalesce(
      nullif(btrim(signal.owner_label), ''),
      initcap(replace(signal.attribute, '_', ' '))
    ),
    signal.support_count,
    signal.confidence
  into order_attribute, order_label, order_support, order_confidence
  from public.taste_signals signal
  where signal.user_id = p_owner
    and signal.signal_type = 'order_preference'
    and signal.owner_state in ('active', 'corrected')
  order by
    (signal.owner_state = 'corrected') desc,
    signal.support_count desc,
    signal.confidence desc,
    signal.updated_at desc,
    signal.id
  limit 1;

  select
    signal.attribute,
    coalesce(
      nullif(btrim(signal.owner_label), ''),
      initcap(replace(signal.attribute, '_', ' '))
    ),
    signal.support_count,
    signal.confidence
  into sensory_attribute, sensory_label, sensory_support, sensory_confidence
  from public.taste_signals signal
  where signal.user_id = p_owner
    and signal.signal_type = 'sensory_evaluation'
    and signal.owner_state in ('active', 'corrected')
  order by
    (signal.owner_state = 'corrected') desc,
    signal.support_count desc,
    signal.confidence desc,
    signal.updated_at desc,
    signal.id
  limit 1;

  select
    count(*)::integer,
    count(*) filter (
      where lower(coalesce(visit.context_type, '')) = 'home'
    )::integer,
    count(*) filter (
      where lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
    )::integer,
    count(*) filter (
      where lower(coalesce(visit.context_type, '')) = 'recipe'
    )::integer,
    count(distinct visit.cafe_id) filter (
      where visit.cafe_id is not null
    )::integer
  into complete_visits, home_visits, cafe_visits, recipe_visits, distinct_cafes
  from public.visits visit
  where visit.user_id = p_owner
    and visit.upload_state = 'complete';

  select coalesce(max(grouped.visit_count), 0)::integer
  into repeated_cafe_visits
  from (
    select count(*) visit_count
    from public.visits visit
    where visit.user_id = p_owner
      and visit.upload_state = 'complete'
      and visit.cafe_id is not null
    group by visit.cafe_id
  ) grouped;

  select max(signal.updated_at) into latest_signal_at
  from public.taste_signals signal
  where signal.user_id = p_owner
    and signal.owner_state in ('active', 'corrected');

  ritual_label := case
    when recipe_visits >= 2 then 'Recipe Builder'
    when home_visits > cafe_visits and home_visits >= 2 then 'Home Dialer'
    when repeated_cafe_visits >= 3 then 'Neighborhood Regular'
    when distinct_cafes >= 3 then 'Cafe Explorer'
    when home_visits > 0 and cafe_visits > 0 then 'Ritual Mixer'
    when cafe_visits > 0 then 'Cafe Explorer'
    else 'Memory Keeper'
  end;

  confidence_band := case
    when greatest(
      coalesce(order_confidence, 0), coalesce(sensory_confidence, 0)
    ) >= 0.75 then 'established'
    when greatest(
      coalesce(order_confidence, 0), coalesce(sensory_confidence, 0)
    ) >= 0.40 then 'growing'
    else 'emerging'
  end;

  description := case
    when order_attribute is not null and sensory_attribute is not null then
      'Often reaches for ' || lower(order_label)
        || ' and tends to notice ' || lower(sensory_label) || '.'
    when order_attribute is not null then
      'Often reaches for ' || lower(order_label)
        || '. More sensory detail is still forming.'
    when sensory_attribute is not null then
      'Tends to notice ' || lower(sensory_label)
        || '. Order patterns are still forming.'
    else 'This Taste Passport is forming with each logged sip.'
  end;

  passport_is_forming := greatest(
    coalesce(order_support, 0), coalesce(sensory_support, 0)
  ) < 3;

  if passport_is_forming then
    order_label := 'Taste Forming';
    sensory_label := 'Lens Forming';
    ritual_label := 'Ritual Forming';
    confidence_band := 'emerging';
    description := 'This Taste Passport is forming with each logged sip.';
    latest_signal_at := null;
  end if;

  return jsonb_build_object(
    'user_id', p_owner,
    'visibility', owner_visibility,
    'descriptors', jsonb_build_array(
      jsonb_build_object(
        'kind', 'order_preference',
        'label', coalesce(order_label, 'Taste Forming')
      ),
      jsonb_build_object(
        'kind', 'sensory_lens',
        'label', coalesce(sensory_label, 'Lens Forming')
      ),
      jsonb_build_object('kind', 'ritual', 'label', ritual_label)
    ),
    'description', description,
    'is_forming', passport_is_forming,
    'confidence_band', confidence_band,
    'calculation_version', 'taste-passport-1',
    'updated_at', latest_signal_at
  );
end;
$$;

revoke all on function private.can_view_taste_passport_v2(uuid,uuid)
  from public, anon, authenticated;
revoke all on function private.taste_passport_projection_v2(uuid,uuid)
  from public, anon, authenticated;

create or replace function public.get_taste_passport_v1(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select private.taste_passport_projection_v2(p_user_id, auth.uid());
$$;

create or replace function private.profile_projection_v2(
  p_owner uuid,
  p_viewer uuid
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not private.profile_owner_visible_v2(p_owner, p_viewer) then
    return null;
  end if;

  select jsonb_build_object(
    'profile', jsonb_build_object(
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
      'taste_passport_visibility', profile.taste_passport_visibility
    ),
    'friendship_state', case
      when p_viewer is null then 'none'
      when p_viewer = p_owner then 'self'
      when private.confirmed_friends(p_viewer, p_owner) then 'friends'
      when exists (
        select 1 from public.friend_requests request
        where request.from_user_id = p_viewer
          and request.to_user_id = p_owner
          and request.status = 'pending'
      ) then 'outgoing'
      when exists (
        select 1 from public.friend_requests request
        where request.from_user_id = p_owner
          and request.to_user_id = p_viewer
          and request.status = 'pending'
      ) then 'incoming'
      else 'none'
    end,
    'stats', jsonb_build_object(
      'sips', (
        select count(*)
        from public.visits visit
        where visit.user_id = p_owner
          and private.profile_visit_visible_v2(visit.id, p_viewer)
      ),
      'friends', (
        select count(*) from public.friends friend
        where friend.user_id = p_owner
      ),
      'cafes', (
        select count(distinct visit.cafe_id)
        from public.visits visit
        where visit.user_id = p_owner
          and visit.cafe_id is not null
          and lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
          and private.profile_visit_visible_v2(visit.id, p_viewer)
      )
    ),
    'highlight', private.profile_highlight_v2(p_owner, p_viewer),
    'top_cafes', private.profile_top_cafes_v2(p_owner, p_viewer),
    'taste_passport_visible', (
      profile.taste_passport_visibility = 'everyone'
      or (
        p_viewer is not null
        and (
          p_viewer = p_owner
          or (
            profile.taste_passport_visibility = 'friends'
            and private.confirmed_friends(p_viewer, p_owner)
          )
        )
      )
    ),
    'taste_passport', private.taste_passport_projection_v2(p_owner, p_viewer),
    'viewer_projection', case when p_viewer is null then 'everyone' else 'signed_in' end
  ) into result
  from public.users profile
  where profile.id = p_owner;

  return result;
end;
$$;

revoke all on function private.profile_projection_v2(uuid,uuid)
  from public, anon, authenticated;

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
    'is_complete', profile.profile_setup_completed_at is not null,
    'completed_at', profile.profile_setup_completed_at
  ) into result
  from public.users profile
  where profile.id = actor;

  return coalesce(result, jsonb_build_object(
    'user_id', actor,
    'is_complete', false,
    'completed_at', null
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
      profile_setup_completed_at = coalesce(profile.profile_setup_completed_at, now())
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

create or replace function public.get_profile_projection_v2(
  p_user_id uuid,
  p_as_everyone boolean default false
)
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
  if p_as_everyone and actor <> p_user_id then
    raise exception 'only the owner may preview as Everyone' using errcode = '42501';
  end if;

  result := private.profile_projection_v2(
    p_user_id,
    case when p_as_everyone then null else actor end
  );
  if result is null then
    raise exception 'profile unavailable' using errcode = 'P0002';
  end if;
  return result;
end;
$$;

create or replace function public.set_profile_highlight_v1(
  p_highlight_type text,
  p_target_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_type text := lower(btrim(coalesce(p_highlight_type, '')));
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if normalized_type not in ('sip', 'cafe') or p_target_id is null then
    raise exception 'invalid profile highlight' using errcode = '22023';
  end if;
  if normalized_type = 'sip' and not exists (
    select 1 from public.visits visit
    where visit.id = p_target_id
      and visit.user_id = actor
      and visit.upload_state = 'complete'
  ) then
    raise exception 'sip is unavailable' using errcode = '42501';
  end if;
  if normalized_type = 'cafe' and not exists (
    select 1 from public.cafes cafe where cafe.id = p_target_id
  ) then
    raise exception 'cafe is unavailable' using errcode = 'P0002';
  end if;

  insert into public.profile_highlights as highlight (
    user_id, highlight_type, visit_id, cafe_id, created_at, updated_at
  ) values (
    actor,
    normalized_type,
    case when normalized_type = 'sip' then p_target_id else null end,
    case when normalized_type = 'cafe' then p_target_id else null end,
    now(),
    now()
  )
  on conflict (user_id) do update
    set highlight_type = excluded.highlight_type,
        visit_id = excluded.visit_id,
        cafe_id = excluded.cafe_id,
        updated_at = now();

  return private.profile_highlight_v2(actor, actor);
end;
$$;

create or replace function public.clear_profile_highlight_v1()
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  delete from public.profile_highlights where user_id = actor;
  return found;
end;
$$;

create or replace function public.create_profile_share_link_v1()
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  existing_slug text;
  generated_slug text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.profile_owner_visible_v2(actor, actor) then
    raise exception 'profile unavailable' using errcode = '42501';
  end if;

  select link.slug into existing_slug
  from public.profile_share_links link
  where link.owner_id = actor and link.revoked_at is null;
  if existing_slug is not null then
    return existing_slug;
  end if;

  loop
    generated_slug := encode(extensions.gen_random_bytes(24), 'hex');
    begin
      insert into public.profile_share_links as link (
        owner_id, slug, created_at, revoked_at
      ) values (actor, generated_slug, now(), null)
      on conflict (owner_id) do update
        set slug = excluded.slug,
            created_at = excluded.created_at,
            revoked_at = null;
      exit;
    exception when unique_violation then
      -- Retry with a new opaque value.
    end;
  end loop;
  return generated_slug;
end;
$$;

create or replace function public.get_profile_share_slug_v1()
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select link.slug
  from public.profile_share_links link
  where link.owner_id = auth.uid()
    and link.revoked_at is null;
$$;

create or replace function public.revoke_profile_share_link_v1()
returns boolean
language sql
security definer
set search_path = ''
as $$
  update public.profile_share_links link
  set revoked_at = now()
  where link.owner_id = auth.uid()
    and link.revoked_at is null
  returning true;
$$;

create or replace function public.resolve_profile_share_link_v1(p_slug text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select link.owner_id
  from public.profile_share_links link
  where length(coalesce(p_slug, '')) between 24 and 128
    and p_slug ~ '^[A-Za-z0-9_-]+$'
    and link.slug = p_slug
    and link.revoked_at is null
    and private.profile_owner_visible_v2(link.owner_id, auth.uid());
$$;

create or replace function public.get_profile_share_v1(p_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
begin
  select link.owner_id into owner_id
  from public.profile_share_links link
  where length(coalesce(p_slug, '')) between 24 and 128
    and p_slug ~ '^[A-Za-z0-9_-]+$'
    and link.slug = p_slug
    and link.revoked_at is null;

  if owner_id is null then
    return null;
  end if;
  return private.profile_projection_v2(owner_id, null);
end;
$$;

-- ---------------------------------------------------------------------------
-- Cursor-paginated profile photo grid
-- ---------------------------------------------------------------------------

create or replace function private.profile_sips_page_v2(
  p_owner uuid,
  p_viewer uuid,
  p_limit integer,
  p_after_created_at timestamptz,
  p_after_id uuid
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
  identity_key text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    visit.id,
    visit.user_id,
    visit.cafe_id,
    visit.caption,
    visit.drink_type,
    visit.drink_type_custom,
    visit.drink_subtype,
    visit.visibility,
    visit.ratings,
    visit.overall_score,
    visit.poster_photo_url,
    coalesce(gallery.photo_urls, '{}'::text[]),
    visit.context_type,
    visit.location_name,
    visit.created_at,
    cafe.name,
    cafe.city,
    cafe.latitude,
    cafe.longitude,
    cafe.identity_key
  from public.visits visit
  left join public.cafes cafe on cafe.id = visit.cafe_id
  left join lateral (
    select array_agg(photo.photo_url order by photo.sort_order, photo.created_at, photo.id) photo_urls
    from public.visit_photos photo
    where photo.visit_id = visit.id
      and nullif(btrim(photo.photo_url), '') is not null
  ) gallery on true
  where visit.user_id = p_owner
    and private.profile_visit_visible_v2(visit.id, p_viewer)
    and (
      p_after_created_at is null
      or p_after_id is null
      or (visit.created_at, visit.id) < (p_after_created_at, p_after_id)
    )
  order by visit.created_at desc, visit.id desc
  limit least(greatest(coalesce(p_limit, 24), 1), 60);
$$;

revoke all on function private.profile_sips_page_v2(
  uuid,uuid,integer,timestamptz,uuid
) from public, anon, authenticated;

create or replace function public.list_profile_sips_v2(
  p_user_id uuid,
  p_limit integer default 24,
  p_after_created_at timestamptz default null,
  p_after_id uuid default null,
  p_as_everyone boolean default false
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
  identity_key text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_as_everyone and actor <> p_user_id then
    raise exception 'only the owner may preview as Everyone' using errcode = '42501';
  end if;
  if not private.profile_owner_visible_v2(
    p_user_id,
    case when p_as_everyone then null else actor end
  ) then
    raise exception 'profile unavailable' using errcode = 'P0002';
  end if;

  return query select * from private.profile_sips_page_v2(
    p_user_id,
    case when p_as_everyone then null else actor end,
    p_limit,
    p_after_created_at,
    p_after_id
  );
end;
$$;

create or replace function public.list_profile_share_sips_v1(
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
  identity_key text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
begin
  select link.owner_id into owner_id
  from public.profile_share_links link
  where length(coalesce(p_slug, '')) between 24 and 128
    and p_slug ~ '^[A-Za-z0-9_-]+$'
    and link.slug = p_slug
    and link.revoked_at is null;

  if owner_id is null
     or not private.profile_owner_visible_v2(owner_id, null) then
    return;
  end if;

  return query select * from private.profile_sips_page_v2(
    owner_id, null, p_limit, p_after_created_at, p_after_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Canonical post projection and opaque slug resolution
-- ---------------------------------------------------------------------------

create or replace function public.resolve_visit_share_link_v2(p_slug text)
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select link.visit_id
  from public.visit_share_links link
  where length(coalesce(p_slug, '')) between 24 and 128
    and p_slug ~ '^[A-Za-z0-9_-]+$'
    and link.slug = p_slug
    and link.revoked_at is null
    and private.profile_visit_visible_v2(link.visit_id, auth.uid());
$$;

create or replace function public.get_canonical_post_v1(
  p_visit_id uuid,
  p_slug text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
  result jsonb;
begin
  if p_slug is not null and not exists (
    select 1 from public.visit_share_links link
    where link.visit_id = p_visit_id
      and link.slug = p_slug
      and link.revoked_at is null
  ) then
    return null;
  end if;
  if not private.profile_visit_visible_v2(p_visit_id, viewer) then
    return null;
  end if;

  select jsonb_build_object(
    'visit', jsonb_build_object(
      'id', visit.id,
      'user_id', visit.user_id,
      'cafe_id', visit.cafe_id,
      'caption', visit.caption,
      'drink_type', visit.drink_type,
      'drink_type_custom', visit.drink_type_custom,
      'drink_subtype', visit.drink_subtype,
      'visibility', visit.visibility,
      'ratings', visit.ratings,
      'category_scores', visit.category_scores,
      'overall_score', visit.overall_score,
      'poster_photo_url', visit.poster_photo_url,
      'context_type', visit.context_type,
      'location_name', visit.location_name,
      'city_state', visit.city_state,
      'brew_method', case when visit.brew_method_visible then visit.brew_method else null end,
      'equipment', case when visit.equipment_visible then visit.equipment else null end,
      'created_at', visit.created_at
    ),
    'author', jsonb_build_object(
      'id', author.id,
      'display_name', author.display_name,
      'username', author.username,
      'avatar_url', author.avatar_url
    ),
    'cafe', case when cafe.id is null then null else jsonb_build_object(
      'id', cafe.id,
      'name', cafe.name,
      'city', cafe.city,
      'address', cafe.address,
      'latitude', cafe.latitude,
      'longitude', cafe.longitude,
      'identity_key', cafe.identity_key
    ) end,
    'photo_urls', case
      when nullif(btrim(visit.poster_photo_url), '') is null
        then coalesce(gallery.photo_urls, '{}'::text[])
      else array_prepend(
        nullif(btrim(visit.poster_photo_url), ''),
        coalesce((
          select array_agg(url order by ordinal)
          from unnest(coalesce(gallery.photo_urls, '{}'::text[]))
            with ordinality item(url, ordinal)
          where item.url <> nullif(btrim(visit.poster_photo_url), '')
        ), '{}'::text[])
      )
    end,
    'journal_note', case when reflection.visit_id is null then null else jsonb_build_object(
      'sip_note', case when
        viewer = visit.user_id
        or reflection.raw_note_visibility = 'everyone'
        or (
          viewer is not null
          and reflection.raw_note_visibility = 'friends'
          and private.confirmed_friends(viewer, visit.user_id)
        )
        then reflection.sip_raw_note else null end,
      'context_note', case when
        viewer = visit.user_id
        or reflection.raw_note_visibility = 'everyone'
        or (
          viewer is not null
          and reflection.raw_note_visibility = 'friends'
          and private.confirmed_friends(viewer, visit.user_id)
        )
        then reflection.context_raw_note else null end,
      'visibility', reflection.raw_note_visibility,
      'sip_score', reflection.sip_score,
      'context_score', reflection.context_score,
      'criteria', reflection.context_criteria,
      'mugshot_score', reflection.mugshot_score
    ) end,
    'counts', jsonb_build_object(
      'likes', (
        select count(*) from public.likes reaction
        where reaction.visit_id = visit.id
      ),
      'comments', (
        select count(*) from public.comments comment
        where comment.visit_id = visit.id
          and comment.removed_at is null
          and not private.has_active_moderation_action(
            'comment', comment.id, array['content_hidden']::text[]
          )
          and private.profile_owner_visible_v2(comment.user_id, viewer)
      )
    ),
    'viewer_state', jsonb_build_object(
      'liked', viewer is not null and exists (
        select 1 from public.likes reaction
        where reaction.visit_id = visit.id and reaction.user_id = viewer
      ),
      'saved', viewer is not null and exists (
        select 1 from public.visit_bookmarks bookmark
        where bookmark.visit_id = visit.id and bookmark.user_id = viewer
      )
    )
  ) into result
  from public.visits visit
  join public.users author on author.id = visit.user_id
  left join public.cafes cafe on cafe.id = visit.cafe_id
  left join public.visit_v3_reflections reflection on reflection.visit_id = visit.id
  left join lateral (
    select array_agg(photo.photo_url order by photo.sort_order, photo.created_at, photo.id) photo_urls
    from public.visit_photos photo
    where photo.visit_id = visit.id
      and nullif(btrim(photo.photo_url), '') is not null
  ) gallery on true
  where visit.id = p_visit_id;

  return result;
end;
$$;

-- Preserve the v1 response shape for established builds while enforcing the
-- same current viewer rules as the canonical projection. A Friends link now
-- requires a signed-in confirmed mutual friend; Everyone remains public.
drop function public.get_public_mugshot_share_v1(text);

create function public.get_public_mugshot_share_v1(p_slug text)
returns table (
  visit_id uuid,
  slug text,
  author_name text,
  author_username text,
  author_avatar_url text,
  drink_name text,
  context_name text,
  rating double precision,
  ratings jsonb,
  caption text,
  cover_photo_url text,
  photo_urls text[],
  created_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    visit.id,
    link.slug,
    coalesce(nullif(btrim(author.display_name), ''), author.username),
    author.username,
    nullif(btrim(author.avatar_url), ''),
    coalesce(
      nullif(btrim(visit.drink_subtype), ''),
      nullif(btrim(visit.drink_type_custom), ''),
      nullif(btrim(visit.drink_type), ''),
      'Coffee memory'
    ),
    case
      when visit.cafe_id is not null
        then coalesce(nullif(btrim(cafe.name), ''), 'Cafe')
      when lower(coalesce(visit.context_type, '')) = 'home' then 'Home'
      when lower(coalesce(visit.context_type, '')) = 'recipe' then 'Recipe'
      else 'Elsewhere'
    end,
    visit.overall_score::double precision,
    coalesce(visit.ratings, '{}'::jsonb),
    nullif(btrim(visit.caption), ''),
    coalesce(nullif(btrim(visit.poster_photo_url), ''), gallery.photo_urls[1]),
    case
      when nullif(btrim(visit.poster_photo_url), '') is null
        then gallery.photo_urls
      else array_prepend(
        nullif(btrim(visit.poster_photo_url), ''),
        coalesce((
          select array_agg(url order by ordinal)
          from unnest(gallery.photo_urls) with ordinality item(url, ordinal)
          where item.url <> nullif(btrim(visit.poster_photo_url), '')
        ), '{}'::text[])
      )
    end,
    visit.created_at
  from public.visit_share_links link
  join public.visits visit on visit.id = link.visit_id
  join public.users author on author.id = visit.user_id
  left join public.cafes cafe on cafe.id = visit.cafe_id
  left join lateral (
    select coalesce(
      array_agg(photo.photo_url order by photo.sort_order, photo.created_at, photo.id),
      '{}'::text[]
    ) photo_urls
    from public.visit_photos photo
    where photo.visit_id = visit.id
      and nullif(btrim(photo.photo_url), '') is not null
  ) gallery on true
  where length(coalesce(p_slug, '')) between 24 and 128
    and p_slug ~ '^[A-Za-z0-9_-]+$'
    and link.slug = p_slug
    and link.revoked_at is null
    and private.profile_visit_visible_v2(visit.id, auth.uid());
$$;

-- People suggestions are intentionally bounded to confirmed friends and
-- accounts the owner has previously tagged in a completed authored sip.
create or replace function public.visit_tag_suggestions_v1(p_limit integer default 50)
returns table (
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  shared_sip_count integer,
  last_shared_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor),
  prior_tags as (
    select
      tag.tagged_user_id,
      count(*)::integer shared_sip_count,
      max(visit.created_at) last_shared_at
    from input
    join public.visit_tags tag on tag.tagged_by = input.actor
    join public.visits visit
      on visit.id = tag.visit_id
     and visit.user_id = input.actor
     and visit.upload_state = 'complete'
    group by tag.tagged_user_id
  )
  select
    profile.id,
    profile.display_name,
    profile.username,
    profile.avatar_url,
    coalesce(prior.shared_sip_count, 0),
    prior.last_shared_at
  from input
  join public.users profile
    on profile.id <> input.actor
   and private.can_view_user_as(profile.id, input.actor)
   and not private.blocked_between(input.actor, profile.id)
  left join prior_tags prior on prior.tagged_user_id = profile.id
  where input.actor is not null
    and (
      private.confirmed_friends(input.actor, profile.id)
      or prior.tagged_user_id is not null
    )
  order by
    private.confirmed_friends(input.actor, profile.id) desc,
    coalesce(prior.shared_sip_count, 0) desc,
    prior.last_shared_at desc nulls last,
    lower(profile.display_name),
    profile.id
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

-- ---------------------------------------------------------------------------
-- Data API grants: the two state tables stay sealed; clients use only RPCs.
-- ---------------------------------------------------------------------------

revoke all on function public.get_profile_setup_state_v1()
  from public, anon, authenticated;
revoke all on function public.complete_profile_setup_v1(
  text,text,text,text,text,text,text
) from public, anon, authenticated;
revoke all on function public.get_profile_projection_v2(uuid,boolean)
  from public, anon, authenticated;
revoke all on function public.set_profile_highlight_v1(text,uuid)
  from public, anon, authenticated;
revoke all on function public.clear_profile_highlight_v1()
  from public, anon, authenticated;
revoke all on function public.create_profile_share_link_v1()
  from public, anon, authenticated;
revoke all on function public.get_profile_share_slug_v1()
  from public, anon, authenticated;
revoke all on function public.revoke_profile_share_link_v1()
  from public, anon, authenticated;
revoke all on function public.resolve_profile_share_link_v1(text)
  from public, anon, authenticated;
revoke all on function public.get_profile_share_v1(text)
  from public, anon, authenticated;
revoke all on function public.list_profile_sips_v2(
  uuid,integer,timestamptz,uuid,boolean
) from public, anon, authenticated;
revoke all on function public.list_profile_share_sips_v1(
  text,integer,timestamptz,uuid
) from public, anon, authenticated;
revoke all on function public.resolve_visit_share_link_v2(text)
  from public, anon, authenticated;
revoke all on function public.get_canonical_post_v1(uuid,text)
  from public, anon, authenticated;
revoke all on function public.get_taste_passport_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.get_public_mugshot_share_v1(text)
  from public, anon, authenticated;
revoke all on function public.visit_tag_suggestions_v1(integer)
  from public, anon, authenticated;

grant execute on function public.get_profile_setup_state_v1()
  to authenticated;
grant execute on function public.complete_profile_setup_v1(
  text,text,text,text,text,text,text
) to authenticated;
grant execute on function public.get_profile_projection_v2(uuid,boolean)
  to authenticated;
grant execute on function public.set_profile_highlight_v1(text,uuid)
  to authenticated;
grant execute on function public.clear_profile_highlight_v1()
  to authenticated;
grant execute on function public.create_profile_share_link_v1()
  to authenticated;
grant execute on function public.get_profile_share_slug_v1()
  to authenticated;
grant execute on function public.revoke_profile_share_link_v1()
  to authenticated;
grant execute on function public.resolve_profile_share_link_v1(text)
  to anon, authenticated;
grant execute on function public.get_profile_share_v1(text)
  to anon, authenticated;
grant execute on function public.list_profile_sips_v2(
  uuid,integer,timestamptz,uuid,boolean
) to authenticated;
grant execute on function public.list_profile_share_sips_v1(
  text,integer,timestamptz,uuid
) to anon, authenticated;
grant execute on function public.resolve_visit_share_link_v2(text)
  to anon, authenticated;
grant execute on function public.get_canonical_post_v1(uuid,text)
  to anon, authenticated;
grant execute on function public.get_taste_passport_v1(uuid)
  to anon, authenticated;
grant execute on function public.get_public_mugshot_share_v1(text)
  to anon, authenticated;
grant execute on function public.visit_tag_suggestions_v1(integer)
  to authenticated;

comment on column public.users.profile_setup_completed_at is
  'Server-confirmed completion marker for the required first-account identity setup.';
comment on table public.profile_highlights is
  'Owner-selected pinned sip or favorite cafe. Client roles have no direct table access.';
comment on table public.profile_share_links is
  'Revocable opaque profile capabilities containing no profile content.';
comment on function public.get_profile_projection_v2(uuid,boolean) is
  'Viewer-authorized shared profile header, stats, highlight, Top cafes, and exact Everyone preview.';
comment on function public.list_profile_sips_v2(uuid,integer,timestamptz,uuid,boolean) is
  'Cursor-paginated viewer-authorized sip grid for the shared native profile.';
comment on function public.get_canonical_post_v1(uuid,text) is
  'Canonical post projection shared by native and PWA; journal notes are nulled outside their explicit audience.';
comment on function public.get_taste_passport_v1(uuid) is
  'Audience-authorized Taste Passport summary. Everyone is public; Friends requires a confirmed mutual friend; Private is owner-only.';

commit;
