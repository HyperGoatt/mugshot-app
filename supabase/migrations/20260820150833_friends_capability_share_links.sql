begin;

-- Owner-created share URLs are capabilities, not ambient audience grants.
-- Everyone visits remain discoverable through the normal public projections;
-- Friends visits become anonymous-readable only when the caller presents an
-- active opaque slug. Private visits never qualify.
create or replace function private.is_capability_shareable_visit_v1(
  p_visit_id uuid
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
      and visit.visibility in ('everyone', 'friends')
      and visit.upload_state = 'complete'
      and private.is_live_account_as(visit.user_id)
      and not private.has_active_moderation_action(
        'user', visit.user_id, array['account_suspended']::text[]
      )
      and not private.has_active_moderation_action(
        'visit', visit.id, array['content_hidden']::text[]
      )
  );
$$;

revoke all on function private.is_capability_shareable_visit_v1(uuid)
  from public, anon, authenticated;

create or replace function public.create_visit_share_link_v1(
  p_visit_id uuid
)
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
    raise exception 'authentication required' using errcode = '42501';
  end if;

  if not exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and visit.user_id = actor
      and private.is_capability_shareable_visit_v1(visit.id)
  ) then
    raise exception 'visit is not available for link sharing'
      using errcode = '42501';
  end if;

  select link.slug
  into existing_slug
  from public.visit_share_links link
  where link.visit_id = p_visit_id
    and link.owner_id = actor
    and link.revoked_at is null;

  if existing_slug is not null then
    return existing_slug;
  end if;

  loop
    generated_slug := encode(extensions.gen_random_bytes(24), 'hex');
    begin
      insert into public.visit_share_links (
        visit_id, owner_id, slug, created_at, revoked_at
      )
      values (p_visit_id, actor, generated_slug, now(), null)
      on conflict (visit_id) do update
        set slug = excluded.slug,
            owner_id = excluded.owner_id,
            created_at = excluded.created_at,
            revoked_at = null
        where public.visit_share_links.owner_id = actor;
      exit;
    exception when unique_violation then
      -- Generate a new opaque value without revealing the visit identifier.
    end;
  end loop;

  return generated_slug;
end;
$$;

create or replace function public.get_visit_share_slug_v1(
  p_visit_id uuid
)
returns text
language sql
stable
security definer
set search_path = ''
as $$
  select link.slug
  from public.visit_share_links link
  where link.visit_id = p_visit_id
    and link.owner_id = auth.uid()
    and link.revoked_at is null
    and private.is_capability_shareable_visit_v1(link.visit_id);
$$;

-- The row type expands to the complete safe post surface used by native and
-- web capability viewers. It remains deliberately separate from the normal
-- visit/detail RPCs so private notes, precise locations, recipe data, social
-- graphs, and Taste Passport evidence have no path into the response.
drop function public.get_public_mugshot_share_v1(text);

create function public.get_public_mugshot_share_v1(
  p_slug text
)
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
    coalesce(
      nullif(btrim(visit.poster_photo_url), ''),
      gallery.photo_urls[1]
    ),
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
      array_agg(
        nullif(btrim(photo.photo_url), '')
        order by photo.sort_order, photo.created_at, photo.id
      ),
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
    and private.is_capability_shareable_visit_v1(visit.id);
$$;

create or replace function public.record_public_mugshot_share_event_v1(
  p_slug text,
  p_event_name text
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_visit_id uuid;
begin
  if p_event_name not in ('landing_visit', 'app_open')
     or length(coalesce(p_slug, '')) not between 24 and 128
     or p_slug !~ '^[A-Za-z0-9_-]+$' then
    return false;
  end if;

  select link.visit_id
  into target_visit_id
  from public.visit_share_links link
  where link.slug = p_slug
    and link.revoked_at is null
    and private.is_capability_shareable_visit_v1(link.visit_id);

  if target_visit_id is null then
    return false;
  end if;

  insert into public.visit_share_link_metrics (
    visit_id, landing_visits, app_opens, updated_at
  )
  values (
    target_visit_id,
    case when p_event_name = 'landing_visit' then 1 else 0 end,
    case when p_event_name = 'app_open' then 1 else 0 end,
    now()
  )
  on conflict (visit_id) do update
    set landing_visits = public.visit_share_link_metrics.landing_visits
          + case when p_event_name = 'landing_visit' then 1 else 0 end,
        app_opens = public.visit_share_link_metrics.app_opens
          + case when p_event_name = 'app_open' then 1 else 0 end,
        updated_at = now();

  return true;
end;
$$;

revoke all on function public.create_visit_share_link_v1(uuid)
  from public, anon;
revoke all on function public.get_visit_share_slug_v1(uuid)
  from public, anon;
revoke all on function public.get_public_mugshot_share_v1(text)
  from public;
revoke all on function public.record_public_mugshot_share_event_v1(text,text)
  from public;

grant execute on function public.create_visit_share_link_v1(uuid)
  to authenticated;
grant execute on function public.get_visit_share_slug_v1(uuid)
  to authenticated;
grant execute on function public.get_public_mugshot_share_v1(text)
  to anon, authenticated;
grant execute on function public.record_public_mugshot_share_event_v1(text,text)
  to anon, authenticated;

comment on function private.is_capability_shareable_visit_v1(uuid) is
  'Canonical live-state boundary for opaque Everyone/Friends visit capability links. Private visits never qualify.';
comment on function public.create_visit_share_link_v1(uuid) is
  'Creates or resolves an owner-only opaque capability link for a complete Everyone or Friends visit.';
comment on function public.get_public_mugshot_share_v1(text) is
  'Anonymous capability projection for the real shared post. Returns only explicitly allowlisted post fields and media references.';

commit;
