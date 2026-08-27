-- Editorial Atlas profile contracts.
--
-- Existing profile v3, highlight, and viewer-authorized sip contracts remain
-- available to older clients. New v4/profile-public endpoints publish Everyone
-- Mugshots plus Friends Mugshots when the profile owner leaves the default-on
-- preference enabled. Private Mugshots are never included.

create table public.profile_visibility_preferences (
  user_id uuid primary key references public.users(id) on delete cascade,
  show_friends_on_public_profile boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profile_visibility_preferences enable row level security;
alter table public.profile_visibility_preferences force row level security;
revoke all on table public.profile_visibility_preferences
  from public, anon, authenticated;

create table public.profile_favorite_spots (
  user_id uuid not null references public.users(id) on delete cascade,
  position smallint not null check (position between 0 and 2),
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  descriptor text not null check (
    char_length(btrim(descriptor)) between 1 and 30
    and descriptor = btrim(descriptor)
  ),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, position),
  unique (user_id, cafe_id)
);

create index profile_favorite_spots_cafe_idx
  on public.profile_favorite_spots(cafe_id);

alter table public.profile_favorite_spots enable row level security;
alter table public.profile_favorite_spots force row level security;
revoke all on table public.profile_favorite_spots
  from public, anon, authenticated;

create table public.profile_tagged_post_hides (
  user_id uuid not null references public.users(id) on delete cascade,
  visit_id uuid not null references public.visits(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, visit_id)
);

create index profile_tagged_post_hides_visit_idx
  on public.profile_tagged_post_hides(visit_id);

alter table public.profile_tagged_post_hides enable row level security;
alter table public.profile_tagged_post_hides force row level security;
revoke all on table public.profile_tagged_post_hides
  from public, anon, authenticated;

create or replace function private.profile_shows_friends_v1(p_owner uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select preference.show_friends_on_public_profile
    from public.profile_visibility_preferences preference
    where preference.user_id = p_owner
  ), true);
$$;

create or replace function private.profile_visit_published_v1(
  p_visit_id uuid,
  p_profile_owner uuid
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
      and private.profile_owner_visible_v2(visit.user_id, null)
      and not private.has_active_moderation_action(
        'visit', visit.id, array['content_hidden']::text[]
      )
      and (
        lower(visit.visibility) = 'everyone'
        or (
          lower(visit.visibility) = 'friends'
          and private.profile_shows_friends_v1(p_profile_owner)
        )
      )
  );
$$;

revoke all on function private.profile_shows_friends_v1(uuid)
  from public, anon, authenticated;
revoke all on function private.profile_visit_published_v1(uuid,uuid)
  from public, anon, authenticated;

create or replace function private.profile_favorite_spots_v1(p_owner uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'position', spot.position,
        'descriptor', spot.descriptor,
        'cafe_id', cafe.id,
        'name', cafe.name,
        'city', cafe.city,
        'address', cafe.address,
        'latitude', cafe.latitude,
        'longitude', cafe.longitude,
        'identity_key', cafe.identity_key,
        'cover_photo_url', cover.photo_url
      )
      order by spot.position
    ),
    '[]'::jsonb
  )
  from public.profile_favorite_spots spot
  join public.cafes cafe on cafe.id = spot.cafe_id
  left join lateral (
    select coalesce(
      nullif(btrim(visit.poster_photo_url), ''),
      gallery.photo_url
    ) photo_url
    from public.visits visit
    left join lateral (
      select photo.photo_url
      from public.visit_photos photo
      where photo.visit_id = visit.id
        and nullif(btrim(photo.photo_url), '') is not null
      order by photo.sort_order, photo.created_at, photo.id
      limit 1
    ) gallery on true
    join public.cafes visit_cafe on visit_cafe.id = visit.cafe_id
    where private.profile_visit_published_v1(visit.id, p_owner)
      and coalesce(
        nullif(btrim(visit_cafe.identity_key), ''),
        visit_cafe.id::text
      ) = coalesce(nullif(btrim(cafe.identity_key), ''), cafe.id::text)
      and coalesce(
        nullif(btrim(visit.poster_photo_url), ''),
        gallery.photo_url
      ) is not null
    order by visit.created_at desc, visit.id desc
    limit 1
  ) cover on true
  where spot.user_id = p_owner;
$$;

revoke all on function private.profile_favorite_spots_v1(uuid)
  from public, anon, authenticated;

create or replace function private.profile_public_stats_v1(p_owner uuid)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select jsonb_build_object(
    'friends', (
      select count(*) from public.friends friend
      where friend.user_id = p_owner
    ),
    'sips', (
      select count(*)
      from public.visits visit
      where visit.user_id = p_owner
        and private.profile_visit_published_v1(visit.id, p_owner)
    ),
    'cafes', (
      select count(distinct coalesce(
        nullif(btrim(cafe.identity_key), ''),
        cafe.id::text
      ))
      from public.visits visit
      join public.cafes cafe on cafe.id = visit.cafe_id
      where visit.user_id = p_owner
        and lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
        and private.profile_visit_published_v1(visit.id, p_owner)
    )
  );
$$;

revoke all on function private.profile_public_stats_v1(uuid)
  from public, anon, authenticated;

create or replace function private.profile_projection_v4(
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

  result := private.profile_projection_v3(p_owner, p_viewer);
  if result is null then
    return null;
  end if;

  return jsonb_set(
    jsonb_set(
      jsonb_set(
        jsonb_set(
          result - 'highlight',
          '{stats}',
          private.profile_public_stats_v1(p_owner),
          true
        ),
        '{favorite_spots}',
        private.profile_favorite_spots_v1(p_owner),
        true
      ),
      '{friends_on_profile}',
      to_jsonb(private.profile_shows_friends_v1(p_owner)),
      true
    ),
    '{profile_contract_version}',
    '4'::jsonb,
    true
  );
end;
$$;

revoke all on function private.profile_projection_v4(uuid,uuid)
  from public, anon, authenticated;

create or replace function public.get_profile_projection_v4(p_user_id uuid)
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

  result := private.profile_projection_v4(p_user_id, actor);
  if result is null then
    raise exception 'profile unavailable' using errcode = 'P0002';
  end if;
  return result;
end;
$$;

create or replace function public.get_profile_share_v3(p_slug text)
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
  return private.profile_projection_v4(owner_id, null);
end;
$$;

create or replace function private.profile_public_sips_page_v1(
  p_owner uuid,
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
  identity_key text,
  author_display_name text,
  author_username text,
  author_avatar_url text
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
    cafe.identity_key,
    owner.display_name,
    owner.username,
    owner.avatar_url
  from public.visits visit
  join public.users owner on owner.id = visit.user_id
  left join public.cafes cafe on cafe.id = visit.cafe_id
  left join lateral (
    select array_agg(
      photo.photo_url order by photo.sort_order, photo.created_at, photo.id
    ) photo_urls
    from public.visit_photos photo
    where photo.visit_id = visit.id
      and nullif(btrim(photo.photo_url), '') is not null
  ) gallery on true
  where visit.user_id = p_owner
    and private.profile_visit_published_v1(visit.id, p_owner)
    and (
      p_after_created_at is null
      or p_after_id is null
      or (visit.created_at, visit.id) < (p_after_created_at, p_after_id)
    )
  order by visit.created_at desc, visit.id desc
  limit least(greatest(coalesce(p_limit, 24), 1), 60);
$$;

revoke all on function private.profile_public_sips_page_v1(
  uuid,integer,timestamptz,uuid
) from public, anon, authenticated;

create or replace function public.list_profile_public_sips_v1(
  p_user_id uuid,
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
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.profile_owner_visible_v2(p_user_id, actor) then
    raise exception 'profile unavailable' using errcode = 'P0002';
  end if;

  return query select * from private.profile_public_sips_page_v1(
    p_user_id, p_limit, p_after_created_at, p_after_id
  );
end;
$$;

create or replace function public.list_profile_share_sips_v2(
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

  return query select * from private.profile_public_sips_page_v1(
    owner_id, p_limit, p_after_created_at, p_after_id
  );
end;
$$;

create or replace function public.list_profile_public_cafes_v1(
  p_user_id uuid,
  p_limit integer default 200
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
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.profile_owner_visible_v2(p_user_id, actor) then
    raise exception 'profile unavailable' using errcode = 'P0002';
  end if;

  return query
  with visible_visits as (
    select
      visit.*,
      cafe.name cafe_name,
      cafe.city cafe_city,
      cafe.address cafe_address,
      cafe.latitude cafe_latitude,
      cafe.longitude cafe_longitude,
      cafe.identity_key cafe_identity_key,
      coalesce(
        nullif(btrim(cafe.identity_key), ''),
        cafe.id::text
      ) group_key
    from public.visits visit
    join public.cafes cafe on cafe.id = visit.cafe_id
    where visit.user_id = p_user_id
      and lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
      and private.profile_visit_published_v1(visit.id, p_user_id)
  ), ranked_representatives as (
    select
      visible.*,
      row_number() over (
        partition by visible.group_key
        order by visible.created_at desc, visible.id desc
      ) representative_rank
    from visible_visits visible
  ), aggregates as (
    select
      visible.group_key,
      avg(visible.overall_score) filter (
        where visible.overall_score > 0
      ) average_score,
      count(*) filter (
        where visible.overall_score > 0
      )::integer evidence_count,
      count(*)::integer sip_count,
      max(visible.created_at) latest_at
    from visible_visits visible
    group by visible.group_key
  )
  select
    representative.cafe_id,
    representative.cafe_name,
    representative.cafe_city,
    representative.cafe_address,
    representative.cafe_latitude,
    representative.cafe_longitude,
    representative.cafe_identity_key,
    coalesce(aggregate.average_score, 0)::double precision,
    aggregate.evidence_count,
    aggregate.sip_count,
    cover.photo_url
  from aggregates aggregate
  join ranked_representatives representative
    on representative.group_key = aggregate.group_key
   and representative.representative_rank = 1
  left join lateral (
    select coalesce(
      nullif(btrim(visit.poster_photo_url), ''),
      gallery.photo_url
    ) photo_url
    from visible_visits visit
    left join lateral (
      select photo.photo_url
      from public.visit_photos photo
      where photo.visit_id = visit.id
        and nullif(btrim(photo.photo_url), '') is not null
      order by photo.sort_order, photo.created_at, photo.id
      limit 1
    ) gallery on true
    where visit.group_key = aggregate.group_key
      and coalesce(
        nullif(btrim(visit.poster_photo_url), ''),
        gallery.photo_url
      ) is not null
    order by visit.created_at desc, visit.id desc
    limit 1
  ) cover on true
  order by aggregate.sip_count desc, aggregate.latest_at desc, representative.cafe_id
  limit least(greatest(coalesce(p_limit, 200), 1), 500);
end;
$$;

create or replace function private.profile_public_cafes_v1(
  p_owner uuid,
  p_limit integer
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
language sql
stable
security definer
set search_path = ''
as $$
  with visible_visits as (
    select
      visit.*,
      cafe.name cafe_name,
      cafe.city cafe_city,
      cafe.address cafe_address,
      cafe.latitude cafe_latitude,
      cafe.longitude cafe_longitude,
      cafe.identity_key cafe_identity_key,
      coalesce(nullif(btrim(cafe.identity_key), ''), cafe.id::text) group_key
    from public.visits visit
    join public.cafes cafe on cafe.id = visit.cafe_id
    where visit.user_id = p_owner
      and lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
      and private.profile_visit_published_v1(visit.id, p_owner)
  ), ranked_representatives as (
    select
      visible.*,
      row_number() over (
        partition by visible.group_key
        order by visible.created_at desc, visible.id desc
      ) representative_rank
    from visible_visits visible
  ), aggregates as (
    select
      visible.group_key,
      avg(visible.overall_score) filter (
        where visible.overall_score > 0
      ) average_score,
      count(*) filter (
        where visible.overall_score > 0
      )::integer evidence_count,
      count(*)::integer sip_count,
      max(visible.created_at) latest_at
    from visible_visits visible
    group by visible.group_key
  )
  select
    representative.cafe_id,
    representative.cafe_name,
    representative.cafe_city,
    representative.cafe_address,
    representative.cafe_latitude,
    representative.cafe_longitude,
    representative.cafe_identity_key,
    coalesce(aggregate.average_score, 0)::double precision,
    aggregate.evidence_count,
    aggregate.sip_count,
    cover.photo_url
  from aggregates aggregate
  join ranked_representatives representative
    on representative.group_key = aggregate.group_key
   and representative.representative_rank = 1
  left join lateral (
    select coalesce(nullif(btrim(visit.poster_photo_url), ''), gallery.photo_url) photo_url
    from visible_visits visit
    left join lateral (
      select photo.photo_url
      from public.visit_photos photo
      where photo.visit_id = visit.id
        and nullif(btrim(photo.photo_url), '') is not null
      order by photo.sort_order, photo.created_at, photo.id
      limit 1
    ) gallery on true
    where visit.group_key = aggregate.group_key
      and coalesce(nullif(btrim(visit.poster_photo_url), ''), gallery.photo_url) is not null
    order by visit.created_at desc, visit.id desc
    limit 1
  ) cover on true
  order by aggregate.sip_count desc, aggregate.latest_at desc, representative.cafe_id
  limit least(greatest(coalesce(p_limit, 500), 1), 500);
$$;

revoke all on function private.profile_public_cafes_v1(uuid,integer)
  from public, anon, authenticated;

create or replace function public.list_profile_share_cafes_v1(
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

  return query select * from private.profile_public_cafes_v1(owner_id, p_limit);
end;
$$;

create or replace function private.profile_public_tagged_sips_page_v1(
  p_profile_user uuid,
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
  identity_key text,
  author_display_name text,
  author_username text,
  author_avatar_url text
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
    cafe.identity_key,
    owner.display_name,
    owner.username,
    owner.avatar_url
  from public.visit_tags tag
  join public.visits visit on visit.id = tag.visit_id
  join public.users owner on owner.id = visit.user_id
  left join public.cafes cafe on cafe.id = visit.cafe_id
  left join lateral (
    select array_agg(
      photo.photo_url order by photo.sort_order, photo.created_at, photo.id
    ) photo_urls
    from public.visit_photos photo
    where photo.visit_id = visit.id
      and nullif(btrim(photo.photo_url), '') is not null
  ) gallery on true
  where tag.tagged_user_id = p_profile_user
    and private.profile_visit_published_v1(visit.id, p_profile_user)
    and not exists (
      select 1
      from public.profile_tagged_post_hides hidden
      where hidden.user_id = p_profile_user
        and hidden.visit_id = visit.id
    )
    and (
      p_after_created_at is null
      or p_after_id is null
      or (visit.created_at, visit.id) < (p_after_created_at, p_after_id)
    )
  order by visit.created_at desc, visit.id desc
  limit least(greatest(coalesce(p_limit, 24), 1), 60);
$$;

revoke all on function private.profile_public_tagged_sips_page_v1(
  uuid,integer,timestamptz,uuid
) from public, anon, authenticated;

create or replace function public.list_profile_public_tagged_sips_v1(
  p_user_id uuid,
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
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.profile_owner_visible_v2(p_user_id, actor) then
    raise exception 'profile unavailable' using errcode = 'P0002';
  end if;

  return query select * from private.profile_public_tagged_sips_page_v1(
    p_user_id, p_limit, p_after_created_at, p_after_id
  );
end;
$$;

create or replace function public.list_profile_share_tagged_sips_v1(
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

  return query select * from private.profile_public_tagged_sips_page_v1(
    owner_id, p_limit, p_after_created_at, p_after_id
  );
end;
$$;

create or replace function public.list_profile_friends_v1(
  p_user_id uuid,
  p_limit integer default 100
)
returns table (
  relationship_id uuid,
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  created_at timestamptz,
  friendship_state text
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
  if not private.profile_owner_visible_v2(p_user_id, actor) then
    raise exception 'profile unavailable' using errcode = 'P0002';
  end if;

  return query
  select
    friendship.id,
    connected.id,
    connected.display_name,
    connected.username,
    connected.avatar_url,
    friendship.created_at,
    case
      when actor = connected.id then 'self'
      when private.confirmed_friends(actor, connected.id) then 'friends'
      when exists (
        select 1 from public.friend_requests request
        where request.from_user_id = actor
          and request.to_user_id = connected.id
          and request.status = 'pending'
      ) then 'outgoing'
      when exists (
        select 1 from public.friend_requests request
        where request.from_user_id = connected.id
          and request.to_user_id = actor
          and request.status = 'pending'
      ) then 'incoming'
      else 'none'
    end
  from public.friends friendship
  join public.users connected on connected.id = friendship.friend_user_id
  where friendship.user_id = p_user_id
    and private.can_view_user_as(connected.id, actor)
    and not private.blocked_between(actor, connected.id)
  order by lower(connected.display_name), lower(connected.username), connected.id
  limit least(greatest(coalesce(p_limit, 100), 1), 250);
end;
$$;

create or replace function public.get_profile_friends_visibility_v1()
returns boolean
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
  return private.profile_shows_friends_v1(actor);
end;
$$;

create or replace function public.set_profile_friends_visibility_v1(
  p_enabled boolean
)
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
  if p_enabled is null then
    raise exception 'profile visibility is required' using errcode = '22023';
  end if;

  insert into public.profile_visibility_preferences (
    user_id,
    show_friends_on_public_profile,
    created_at,
    updated_at
  ) values (
    actor,
    p_enabled,
    now(),
    now()
  )
  on conflict (user_id) do update
  set show_friends_on_public_profile = excluded.show_friends_on_public_profile,
      updated_at = now();

  return p_enabled;
end;
$$;

create or replace function public.set_profile_favorite_spots_v1(p_spots jsonb)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  spot_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_spots is null or jsonb_typeof(p_spots) <> 'array' then
    raise exception 'spots must be an array' using errcode = '22023';
  end if;

  spot_count := jsonb_array_length(p_spots);
  if spot_count > 3 then
    raise exception 'a profile can feature at most 3 cafes' using errcode = '22023';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_spots) item
    where nullif(btrim(item->>'cafe_id'), '') is null
      or nullif(btrim(item->>'descriptor'), '') is null
      or char_length(btrim(item->>'descriptor')) > 30
  ) then
    raise exception 'each spot requires a cafe and 1 to 30 character descriptor'
      using errcode = '22023';
  end if;
  if (
    select count(distinct (item->>'cafe_id')::uuid)
    from jsonb_array_elements(p_spots) item
  ) <> spot_count then
    raise exception 'favorite cafes must be unique' using errcode = '22023';
  end if;
  if exists (
    select 1
    from jsonb_array_elements(p_spots) item
    where not exists (
      select 1 from public.cafes cafe
      where cafe.id = (item->>'cafe_id')::uuid
    )
  ) then
    raise exception 'favorite cafe is unavailable' using errcode = 'P0002';
  end if;

  delete from public.profile_favorite_spots spot
  where spot.user_id = actor;

  insert into public.profile_favorite_spots (
    user_id, position, cafe_id, descriptor, created_at, updated_at
  )
  select
    actor,
    (item.ordinality - 1)::smallint,
    (item.value->>'cafe_id')::uuid,
    btrim(item.value->>'descriptor'),
    now(),
    now()
  from jsonb_array_elements(p_spots) with ordinality item(value, ordinality);

  return private.profile_favorite_spots_v1(actor);
end;
$$;

create or replace function public.set_profile_tagged_post_hidden_v1(
  p_visit_id uuid,
  p_hidden boolean default true
)
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
  if p_visit_id is null then
    raise exception 'visit is required' using errcode = '22023';
  end if;
  if not exists (
    select 1
    from public.visit_tags tag
    where tag.visit_id = p_visit_id
      and tag.tagged_user_id = actor
  ) then
    raise exception 'tag is unavailable' using errcode = 'P0002';
  end if;

  if coalesce(p_hidden, true) then
    insert into public.profile_tagged_post_hides(user_id, visit_id)
    values (actor, p_visit_id)
    on conflict (user_id, visit_id) do nothing;
    return true;
  end if;

  delete from public.profile_tagged_post_hides hidden
  where hidden.user_id = actor
    and hidden.visit_id = p_visit_id;
  return false;
end;
$$;

create or replace function public.build_owner_data_export_v3()
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

  result := public.build_owner_data_export_v2();
  return result || jsonb_build_object(
    'profile_editorial_atlas', jsonb_build_object(
      'favorite_spots', coalesce((
        select jsonb_agg(to_jsonb(spot) order by spot.position)
        from public.profile_favorite_spots spot
        where spot.user_id = actor
      ), '[]'::jsonb),
      'hidden_tagged_posts', coalesce((
        select jsonb_agg(to_jsonb(hidden) order by hidden.created_at, hidden.visit_id)
        from public.profile_tagged_post_hides hidden
        where hidden.user_id = actor
      ), '[]'::jsonb),
      'show_friends_on_public_profile', private.profile_shows_friends_v1(actor)
    )
  );
end;
$$;

revoke all on function public.get_profile_projection_v4(uuid)
  from public, anon, authenticated;
revoke all on function public.get_profile_share_v3(text)
  from public, anon, authenticated;
revoke all on function public.list_profile_public_sips_v1(
  uuid,integer,timestamptz,uuid
) from public, anon, authenticated;
revoke all on function public.list_profile_share_sips_v2(
  text,integer,timestamptz,uuid
) from public, anon, authenticated;
revoke all on function public.list_profile_public_cafes_v1(uuid,integer)
  from public, anon, authenticated;
revoke all on function public.list_profile_share_cafes_v1(text,integer)
  from public, anon, authenticated;
revoke all on function public.list_profile_public_tagged_sips_v1(
  uuid,integer,timestamptz,uuid
) from public, anon, authenticated;
revoke all on function public.list_profile_share_tagged_sips_v1(
  text,integer,timestamptz,uuid
) from public, anon, authenticated;
revoke all on function public.list_profile_friends_v1(uuid,integer)
  from public, anon, authenticated;
revoke all on function public.get_profile_friends_visibility_v1()
  from public, anon, authenticated;
revoke all on function public.set_profile_friends_visibility_v1(boolean)
  from public, anon, authenticated;
revoke all on function public.set_profile_favorite_spots_v1(jsonb)
  from public, anon, authenticated;
revoke all on function public.set_profile_tagged_post_hidden_v1(uuid,boolean)
  from public, anon, authenticated;
revoke all on function public.build_owner_data_export_v3()
  from public, anon, authenticated;

grant execute on function public.get_profile_projection_v4(uuid)
  to authenticated;
grant execute on function public.get_profile_share_v3(text)
  to anon, authenticated;
grant execute on function public.list_profile_public_sips_v1(
  uuid,integer,timestamptz,uuid
) to authenticated;
grant execute on function public.list_profile_share_sips_v2(
  text,integer,timestamptz,uuid
) to anon, authenticated;
grant execute on function public.list_profile_public_cafes_v1(uuid,integer)
  to authenticated;
grant execute on function public.list_profile_share_cafes_v1(text,integer)
  to anon, authenticated;
grant execute on function public.list_profile_public_tagged_sips_v1(
  uuid,integer,timestamptz,uuid
) to authenticated;
grant execute on function public.list_profile_share_tagged_sips_v1(
  text,integer,timestamptz,uuid
) to anon, authenticated;
grant execute on function public.list_profile_friends_v1(uuid,integer)
  to authenticated;
grant execute on function public.get_profile_friends_visibility_v1()
  to authenticated;
grant execute on function public.set_profile_friends_visibility_v1(boolean)
  to authenticated;
grant execute on function public.set_profile_favorite_spots_v1(jsonb)
  to authenticated;
grant execute on function public.set_profile_tagged_post_hidden_v1(uuid,boolean)
  to authenticated;
grant execute on function public.build_owner_data_export_v3()
  to authenticated;

comment on table public.profile_favorite_spots is
  'Three ordered cafe identities and owner-authored descriptors explicitly published on a profile.';
comment on table public.profile_tagged_post_hides is
  'Caller-owned presentation suppressions for public Mugshots in which the caller is tagged.';
comment on table public.profile_visibility_preferences is
  'Sealed owner preference controlling whether Friends Mugshots also publish on the owner public profile.';
comment on function public.get_profile_projection_v4(uuid) is
  'Public profile projection with owner-controlled Friends inclusion, aggregate counts, and explicitly published Favorite Spots.';
comment on function public.list_profile_public_sips_v1(uuid,integer,timestamptz,uuid) is
  'Cursor-paginated profile-published Mugshots authored by the requested visible profile; Private is always excluded.';
comment on function public.list_profile_share_sips_v2(text,integer,timestamptz,uuid) is
  'Anonymous profile-link Mugshots using the owner Friends-on-profile preference while always excluding Private.';
comment on function public.list_profile_share_cafes_v1(text,integer) is
  'Canonical cafe aggregates derived only from Everyone Mugshots for an active profile share link.';
comment on function public.list_profile_public_tagged_sips_v1(uuid,integer,timestamptz,uuid) is
  'Cursor-paginated profile-published Mugshots tagging the requested visible profile, excluding Private and profile hides.';
comment on function public.set_profile_friends_visibility_v1(boolean) is
  'Caller-bound switch controlling whether Friends Mugshots also appear on the caller public profile.';
comment on function public.set_profile_favorite_spots_v1(jsonb) is
  'Atomically replaces the caller profile three-slot public Favorite Spots list.';
comment on function public.set_profile_tagged_post_hidden_v1(uuid,boolean) is
  'Caller-bound profile presentation control for a Mugshot that currently tags the caller.';
