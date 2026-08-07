begin;

-- Mugshot V1 cafe discovery is additive. Apple search results remain
-- ephemeral until a person saves, lists, imports, or logs a cafe.

-- ---------------------------------------------------------------------------
-- Stable Apple identity and private per-user discovery provenance
-- ---------------------------------------------------------------------------

alter table public.cafes
  add column if not exists apple_maps_place_id text;

create unique index if not exists cafes_apple_maps_place_id_unique_idx
  on public.cafes (apple_maps_place_id)
  where nullif(btrim(apple_maps_place_id), '') is not null;

create or replace function public.set_cafe_identity_key()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  normalized_name text := lower(regexp_replace(btrim(new.name), '\s+', ' ', 'g'));
begin
  new.apple_maps_place_id := nullif(btrim(new.apple_maps_place_id), '');
  new.identity_key := case
    when new.apple_maps_place_id is not null then
      'apple-mapkit:' || lower(new.apple_maps_place_id)
    when nullif(btrim(new.apple_place_id), '') is not null then
      'apple-legacy:' || lower(regexp_replace(btrim(new.apple_place_id), '\s+', ' ', 'g'))
    when new.latitude is not null and new.longitude is not null then
      'geo:' || normalized_name || '|' ||
      to_char(round(new.latitude::numeric, 5), 'FM999990.00000') || '|' ||
      to_char(round(new.longitude::numeric, 5), 'FM999990.00000')
    else
      'text:' || normalized_name || '|' ||
      lower(regexp_replace(btrim(coalesce(new.address, '')), '\s+', ' ', 'g'))
  end;
  return new;
end;
$$;

revoke all on function public.set_cafe_identity_key()
  from public, anon, authenticated;

drop trigger if exists cafes_set_identity_key on public.cafes;
create trigger cafes_set_identity_key
before insert or update of
  name, address, latitude, longitude, apple_maps_place_id, apple_place_id, identity_key
on public.cafes
for each row execute function public.set_cafe_identity_key();

alter table public.user_cafe_states
  add column if not exists discovery_note text,
  add column if not exists discovery_source text,
  add column if not exists discovered_at timestamptz,
  add column if not exists discovery_attribution_consumed_at timestamptz;

alter table public.user_cafe_states
  drop constraint if exists user_cafe_states_discovery_note_length,
  drop constraint if exists user_cafe_states_discovery_source_check;

alter table public.user_cafe_states
  add constraint user_cafe_states_discovery_note_length
    check (char_length(coalesce(discovery_note, '')) <= 1000),
  add constraint user_cafe_states_discovery_source_check
    check (
      discovery_source is null
      or discovery_source in (
        'for_you', 'apple_search', 'public_list', 'share_import', 'nearby_reminder'
      )
    );

create index if not exists user_cafe_states_discovery_idx
  on public.user_cafe_states (user_id, discovered_at desc, cafe_id)
  where discovery_source is not null;

-- ---------------------------------------------------------------------------
-- Discovery touches and exactly-once Mugshot attribution
-- ---------------------------------------------------------------------------

create table public.discovery_interactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  cafe_id uuid references public.cafes(id) on delete cascade,
  apple_maps_place_id text,
  source text not null check (
    source in ('for_you', 'apple_search', 'public_list', 'share_import', 'nearby_reminder')
  ),
  interaction_kind text not null check (
    interaction_kind in (
      'recommendation_opened', 'directions_requested', 'cafe_saved',
      'list_saved', 'share_imported', 'nearby_nudge_opened', 'public_list_opened'
    )
  ),
  source_list_id uuid references public.cafe_lists(id) on delete set null,
  ranking_version text,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint discovery_interactions_identity_present check (
    cafe_id is not null or nullif(btrim(apple_maps_place_id), '') is not null
  ),
  constraint discovery_interactions_metadata_object check (jsonb_typeof(metadata) = 'object'),
  constraint discovery_interactions_metadata_no_coordinates check (
    not (metadata ?| array['latitude', 'longitude', 'lat', 'lon', 'coordinates'])
  )
);

create index discovery_interactions_user_cafe_time_idx
  on public.discovery_interactions (user_id, cafe_id, occurred_at desc);
create index discovery_interactions_user_apple_time_idx
  on public.discovery_interactions (user_id, apple_maps_place_id, occurred_at desc)
  where cafe_id is null and apple_maps_place_id is not null;

create table public.mugshot_discovery_attributions (
  visit_id uuid primary key references public.visits(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  interaction_id uuid references public.discovery_interactions(id) on delete set null,
  source text not null check (
    source in ('for_you', 'apple_search', 'public_list', 'share_import', 'nearby_reminder')
  ),
  attribution_kind text not null check (attribution_kind in ('within_30_days', 'saved_first_log')),
  ranking_version text,
  attributed_at timestamptz not null default now(),
  unique (user_id, cafe_id)
);

create index mugshot_discovery_attributions_user_time_idx
  on public.mugshot_discovery_attributions (user_id, attributed_at desc);

alter table public.discovery_interactions enable row level security;
alter table public.discovery_interactions force row level security;
alter table public.mugshot_discovery_attributions enable row level security;
alter table public.mugshot_discovery_attributions force row level security;

revoke all on table public.discovery_interactions from public, anon, authenticated;
revoke all on table public.mugshot_discovery_attributions from public, anon, authenticated;

create policy "Owners read discovery interactions"
on public.discovery_interactions
for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Owners read discovery attribution"
on public.mugshot_discovery_attributions
for select to authenticated
using ((select auth.uid()) = user_id);

create or replace function public.record_discovery_interaction_v1(
  p_interaction_id uuid,
  p_cafe_id uuid,
  p_apple_maps_place_id text,
  p_source text,
  p_interaction_kind text,
  p_source_list_id uuid default null,
  p_ranking_version text default null,
  p_metadata jsonb default '{}'::jsonb,
  p_occurred_at timestamptz default now()
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result uuid := coalesce(p_interaction_id, gen_random_uuid());
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.is_live_account_as(actor) then
    raise exception 'account unavailable' using errcode = '42501';
  end if;
  if p_cafe_id is null and nullif(btrim(p_apple_maps_place_id), '') is null then
    raise exception 'a cafe identity is required' using errcode = '22023';
  end if;
  if p_source not in ('for_you', 'apple_search', 'public_list', 'share_import', 'nearby_reminder')
     or p_interaction_kind not in (
       'recommendation_opened', 'directions_requested', 'cafe_saved',
       'list_saved', 'share_imported', 'nearby_nudge_opened', 'public_list_opened'
     ) then
    raise exception 'invalid discovery interaction' using errcode = '22023';
  end if;
  if jsonb_typeof(coalesce(p_metadata, '{}'::jsonb)) <> 'object'
     or coalesce(p_metadata, '{}'::jsonb) ?| array['latitude', 'longitude', 'lat', 'lon', 'coordinates'] then
    raise exception 'unsafe discovery metadata' using errcode = '22023';
  end if;
  if p_source_list_id is not null
     and not private.can_view_cafe_list_items_as(p_source_list_id, actor) then
    raise exception 'source list unavailable' using errcode = '42501';
  end if;

  insert into public.discovery_interactions (
    id, user_id, cafe_id, apple_maps_place_id, source, interaction_kind,
    source_list_id, ranking_version, metadata, occurred_at
  ) values (
    result, actor, p_cafe_id, nullif(btrim(p_apple_maps_place_id), ''),
    p_source, p_interaction_kind, p_source_list_id,
    nullif(btrim(p_ranking_version), ''), coalesce(p_metadata, '{}'::jsonb),
    least(coalesce(p_occurred_at, now()), now())
  )
  on conflict (id) do update
  set
    cafe_id = excluded.cafe_id,
    apple_maps_place_id = excluded.apple_maps_place_id,
    source = excluded.source,
    interaction_kind = excluded.interaction_kind,
    source_list_id = excluded.source_list_id,
    ranking_version = excluded.ranking_version,
    metadata = excluded.metadata,
    occurred_at = excluded.occurred_at
  where public.discovery_interactions.user_id = actor;

  if not found then
    raise exception 'interaction belongs to another account' using errcode = '42501';
  end if;
  return result;
end;
$$;

create or replace function public.consume_discovery_attribution_v1(p_visit_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_visit public.visits%rowtype;
  touch public.discovery_interactions%rowtype;
  saved public.user_cafe_states%rowtype;
  existing public.mugshot_discovery_attributions%rowtype;
  attribution_kind text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select * into target_visit
  from public.visits
  where id = p_visit_id and user_id = actor;
  if not found then
    raise exception 'Mugshot unavailable' using errcode = '42501';
  end if;

  select * into existing
  from public.mugshot_discovery_attributions attribution
  where attribution.visit_id = target_visit.id
    and attribution.user_id = actor;
  if found then
    return jsonb_build_object(
      'attributed', true,
      'kind', existing.attribution_kind,
      'source', existing.source,
      'already_recorded', true
    );
  end if;

  select * into touch
  from public.discovery_interactions interaction
  where interaction.user_id = actor
    and (
      interaction.cafe_id = target_visit.cafe_id
      or (
        interaction.cafe_id is null
        and interaction.apple_maps_place_id = (
          select cafe.apple_maps_place_id from public.cafes cafe
          where cafe.id = target_visit.cafe_id
        )
      )
    )
    and interaction.occurred_at between target_visit.created_at - interval '30 days'
                                    and target_visit.created_at + interval '5 minutes'
  order by interaction.occurred_at desc, interaction.id desc
  limit 1;

  if found then
    attribution_kind := 'within_30_days';
  else
    select * into saved
    from public.user_cafe_states state
    where state.user_id = actor
      and state.cafe_id = target_visit.cafe_id
      and state.discovery_source is not null
      and state.discovery_attribution_consumed_at is null
      and not exists (
        select 1 from public.visits earlier
        where earlier.user_id = actor
          and earlier.cafe_id = target_visit.cafe_id
          and earlier.id <> target_visit.id
          and earlier.created_at <= target_visit.created_at
      );
    if found then attribution_kind := 'saved_first_log'; end if;
  end if;

  if attribution_kind is null then
    return jsonb_build_object('attributed', false);
  end if;

  insert into public.mugshot_discovery_attributions (
    visit_id, user_id, cafe_id, interaction_id, source,
    attribution_kind, ranking_version
  ) values (
    target_visit.id, actor, target_visit.cafe_id, touch.id,
    coalesce(touch.source, saved.discovery_source), attribution_kind,
    touch.ranking_version
  )
  on conflict (visit_id) do nothing;

  update public.user_cafe_states
  set discovery_attribution_consumed_at = coalesce(discovery_attribution_consumed_at, now()),
      updated_at = now()
  where user_id = actor and cafe_id = target_visit.cafe_id;

  return jsonb_build_object(
    'attributed', true,
    'kind', attribution_kind,
    'source', coalesce(touch.source, saved.discovery_source)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Public creator lists, follows, comments, copies, and opaque share links
-- ---------------------------------------------------------------------------

alter table public.cafe_lists
  drop constraint if exists cafe_lists_visibility_check;
alter table public.cafe_lists
  add constraint cafe_lists_visibility_check
    check (visibility in ('private', 'friends', 'invited', 'public'));

alter table public.cafe_lists
  add column if not exists published_at timestamptz,
  add column if not exists comments_enabled boolean not null default true,
  add column if not exists source_list_id uuid references public.cafe_lists(id) on delete set null;

create table public.cafe_list_share_links (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  slug text not null unique check (slug ~ '^[a-f0-9]{24}$'),
  created_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  revoked_at timestamptz
);

create unique index cafe_list_share_links_one_active_idx
  on public.cafe_list_share_links (list_id)
  where revoked_at is null;

create table public.cafe_list_follows (
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (list_id, user_id)
);

create table public.cafe_list_comments (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 500),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  deleted_by uuid references public.users(id) on delete set null
);

create table public.cafe_list_comment_reports (
  id uuid primary key default gen_random_uuid(),
  comment_id uuid not null references public.cafe_list_comments(id) on delete cascade,
  reporter_id uuid not null references public.users(id) on delete cascade,
  reason text not null check (reason in ('spam', 'harassment', 'privacy', 'other')),
  details text check (char_length(coalesce(details, '')) <= 500),
  created_at timestamptz not null default now(),
  unique (comment_id, reporter_id)
);

create index cafe_list_follows_user_time_idx
  on public.cafe_list_follows (user_id, created_at desc);
create index cafe_list_comments_list_time_idx
  on public.cafe_list_comments (list_id, created_at desc, id desc)
  where deleted_at is null;

alter table public.cafe_list_share_links enable row level security;
alter table public.cafe_list_share_links force row level security;
alter table public.cafe_list_follows enable row level security;
alter table public.cafe_list_follows force row level security;
alter table public.cafe_list_comments enable row level security;
alter table public.cafe_list_comments force row level security;
alter table public.cafe_list_comment_reports enable row level security;
alter table public.cafe_list_comment_reports force row level security;

revoke all on table public.cafe_list_share_links from public, anon, authenticated;
revoke all on table public.cafe_list_follows from public, anon, authenticated;
revoke all on table public.cafe_list_comments from public, anon, authenticated;
revoke all on table public.cafe_list_comment_reports from public, anon, authenticated;

create policy "Owners read followed cafe lists"
on public.cafe_list_follows for select to authenticated
using ((select auth.uid()) = user_id);

create policy "Reporters read cafe list comment reports"
on public.cafe_list_comment_reports for select to authenticated
using ((select auth.uid()) = reporter_id);

create or replace function private.is_public_cafe_list_as(p_list_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.cafe_lists list
    where list.id = p_list_id
      and list.visibility = 'public'
      and list.published_at is not null
      and list.system_kind is null
      and private.is_live_account_as(list.owner_id)
      and not private.has_active_moderation_action(
        'user', list.owner_id, array['account_suspended']::text[]
      )
      and (
        p_viewer is null
        or (
          private.is_live_account_as(p_viewer)
          and not private.blocked_between(p_viewer, list.owner_id)
        )
      )
  );
$$;

revoke all on function private.is_public_cafe_list_as(uuid, uuid)
  from public, anon, authenticated;

create or replace function private.can_view_cafe_list_as(p_list_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_public_cafe_list_as(p_list_id, p_viewer)
    or (
      p_viewer is not null
      and exists (
        select 1
        from public.cafe_lists list
        where list.id = p_list_id
          and (list.owner_id is null or not private.blocked_between(p_viewer, list.owner_id))
          and (
            list.owner_id = p_viewer
            or exists (
              select 1 from public.cafe_list_members member
              where member.list_id = list.id
                and member.user_id = p_viewer
                and member.invitation_status in ('pending', 'accepted')
            )
            or (
              list.visibility = 'friends'
              and list.owner_id is not null
              and private.can_view_user_as(list.owner_id, p_viewer)
              and private.confirmed_friends(p_viewer, list.owner_id)
            )
          )
      )
    );
$$;

create or replace function private.can_view_cafe_list_items_as(p_list_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_public_cafe_list_as(p_list_id, p_viewer)
    or (
      p_viewer is not null
      and exists (
        select 1
        from public.cafe_lists list
        where list.id = p_list_id
          and (list.owner_id is null or not private.blocked_between(p_viewer, list.owner_id))
          and (
            list.owner_id = p_viewer
            or exists (
              select 1 from public.cafe_list_members member
              where member.list_id = list.id
                and member.user_id = p_viewer
                and member.invitation_status = 'accepted'
            )
            or (
              list.visibility = 'friends'
              and list.owner_id is not null
              and private.can_view_user_as(list.owner_id, p_viewer)
              and private.confirmed_friends(p_viewer, list.owner_id)
            )
          )
      )
    );
$$;

revoke all on function private.can_view_cafe_list_as(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_cafe_list_items_as(uuid, uuid)
  from public, anon, authenticated;

drop policy if exists "Public cafe lists" on public.cafe_lists;
create policy "Public cafe lists"
on public.cafe_lists for select to anon, authenticated
using (private.is_public_cafe_list_as(id, (select auth.uid())));

drop policy if exists "Public cafe list items" on public.cafe_list_items;
create policy "Public cafe list items"
on public.cafe_list_items for select to anon, authenticated
using (private.is_public_cafe_list_as(list_id, (select auth.uid())));

create or replace function private.public_cafe_list_profile_json_v1(
  p_subject uuid,
  p_viewer uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not private.is_live_account_as(p_subject)
      or private.has_active_moderation_action(
        'user', p_subject, array['account_suspended']::text[]
      )
      or (p_viewer is not null and private.blocked_between(p_viewer, p_subject))
      then jsonb_build_object('identity_state', 'hidden')
    else coalesce((
      select jsonb_build_object(
        'identity_state', 'visible',
        'user_id', profile.id,
        'display_name', profile.display_name,
        'username', profile.username,
        'avatar_url', profile.avatar_url
      )
      from public.users profile where profile.id = p_subject
    ), jsonb_build_object('identity_state', 'departed'))
  end;
$$;

revoke all on function private.public_cafe_list_profile_json_v1(uuid, uuid)
  from public, anon, authenticated;

create or replace function private.public_cafe_list_json_v1(
  p_list_id uuid,
  p_viewer uuid,
  p_include_items boolean default false,
  p_include_comments boolean default false
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
  if not private.is_public_cafe_list_as(p_list_id, p_viewer) then return null; end if;

  select jsonb_build_object(
    'id', list.id,
    'title', list.title,
    'description', list.description,
    'visibility', list.visibility,
    'published_at', list.published_at,
    'updated_at', list.updated_at,
    'comments_enabled', list.comments_enabled,
    'creator', private.public_cafe_list_profile_json_v1(list.owner_id, p_viewer),
    'contributors', coalesce((
      select jsonb_agg(profile order by profile->>'display_name', profile->>'username')
      from (
        select distinct private.public_cafe_list_profile_json_v1(item.contributor_id, p_viewer) profile
        from public.cafe_list_items item
        where item.list_id = list.id and item.contributor_id <> list.owner_id
      ) contributor_rows
      where profile->>'identity_state' = 'visible'
    ), '[]'::jsonb),
    'cafe_count', (select count(*) from public.cafe_list_items item where item.list_id = list.id),
    'follower_count', (select count(*) from public.cafe_list_follows follow where follow.list_id = list.id),
    'is_following', coalesce((
      select true from public.cafe_list_follows follow
      where follow.list_id = list.id and follow.user_id = p_viewer
    ), false),
    'can_comment', p_viewer is not null and list.comments_enabled
      and private.can_socially_mutate_as(p_viewer),
    'slug', (
      select link.slug from public.cafe_list_share_links link
      where link.list_id = list.id and link.revoked_at is null
      order by link.created_at desc limit 1
    ),
    'inspired_by', case when list.source_list_id is null then null else (
      select jsonb_build_object(
        'list_id', source.id,
        'title', source.title,
        'creator', private.public_cafe_list_profile_json_v1(source.owner_id, p_viewer)
      )
      from public.cafe_lists source
      where source.id = list.source_list_id
        and private.is_public_cafe_list_as(source.id, p_viewer)
    ) end,
    'items', case when p_include_items then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', item.id,
        'cafe_id', cafe.id,
        'position', item.position,
        'caption', item.note,
        'cafe_name', cafe.name,
        'cafe_address', cafe.address,
        'cafe_city', cafe.city,
        'latitude', cafe.latitude,
        'longitude', cafe.longitude,
        'apple_maps_place_id', cafe.apple_maps_place_id,
        'apple_place_id', cafe.apple_place_id,
        'website_url', cafe.website_url,
        'photo_url', photo.poster_photo_url,
        'contributor', private.public_cafe_list_profile_json_v1(item.contributor_id, p_viewer)
      ) order by item.position, item.created_at, item.id)
      from public.cafe_list_items item
      join public.cafes cafe on cafe.id = item.cafe_id
      left join lateral (
        select visit.poster_photo_url
        from public.visits visit
        where visit.cafe_id = item.cafe_id
          and visit.visibility = 'everyone'
          and visit.upload_state = 'complete'
          and nullif(btrim(visit.poster_photo_url), '') is not null
          and not private.has_active_moderation_action(
            'visit', visit.id, array['content_hidden']::text[]
          )
          and private.is_live_account_as(visit.user_id)
        order by visit.created_at desc, visit.id desc limit 1
      ) photo on true
      where item.list_id = list.id
    ), '[]'::jsonb) else null end,
    'comments', case when p_include_comments then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', comment.id,
        'body', comment.body,
        'created_at', comment.created_at,
        'author', private.public_cafe_list_profile_json_v1(comment.user_id, p_viewer),
        'can_delete', p_viewer = comment.user_id or p_viewer = list.owner_id
      ) order by comment.created_at, comment.id)
      from public.cafe_list_comments comment
      where comment.list_id = list.id
        and comment.deleted_at is null
        and not private.has_active_moderation_action(
          'cafe_list_comment', comment.id, array['content_hidden']::text[]
        )
        and (p_viewer is null or not private.blocked_between(p_viewer, comment.user_id))
        and private.is_live_account_as(comment.user_id)
    ), '[]'::jsonb) else null end
  ) into result
  from public.cafe_lists list
  where list.id = p_list_id;

  return result;
end;
$$;

revoke all on function private.public_cafe_list_json_v1(uuid, uuid, boolean, boolean)
  from public, anon, authenticated;

create or replace function public.browse_public_cafe_lists_v1(
  p_limit integer default 20,
  p_before timestamptz default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
  bounded_limit integer := least(greatest(coalesce(p_limit, 20), 1), 50);
begin
  return coalesce((
    select jsonb_agg(private.public_cafe_list_json_v1(list.id, viewer, false, false)
      order by list.updated_at desc, list.id desc)
    from (
      select candidate.id, candidate.updated_at
      from public.cafe_lists candidate
      where private.is_public_cafe_list_as(candidate.id, viewer)
        and (p_before is null or candidate.updated_at < p_before)
      order by candidate.updated_at desc, candidate.id desc
      limit bounded_limit
    ) list
  ), '[]'::jsonb);
end;
$$;

create or replace function public.get_public_cafe_list_v1(p_slug text)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
  target_list uuid;
begin
  if p_slug is null or p_slug !~ '^[a-f0-9]{24}$' then
    raise exception 'public cafe list unavailable' using errcode = '22023';
  end if;
  select link.list_id into target_list
  from public.cafe_list_share_links link
  where link.slug = p_slug and link.revoked_at is null;
  if target_list is null or not private.is_public_cafe_list_as(target_list, viewer) then
    raise exception 'public cafe list unavailable' using errcode = '42501';
  end if;
  return private.public_cafe_list_json_v1(target_list, viewer, true, true);
end;
$$;

create or replace function public.set_cafe_list_publication_v1(
  p_list_id uuid,
  p_is_public boolean,
  p_comments_enabled boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  slug text;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.can_manage_cafe_list_as(p_list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  if p_is_public then
    update public.cafe_lists
    set visibility = 'public', published_at = coalesce(published_at, now()),
        comments_enabled = coalesce(p_comments_enabled, true), updated_at = now()
    where id = p_list_id and owner_id = actor and system_kind is null;

    select link.slug into slug
    from public.cafe_list_share_links link
    where link.list_id = p_list_id and link.revoked_at is null;
    if slug is null then
      slug := left(replace(gen_random_uuid()::text, '-', ''), 24);
      insert into public.cafe_list_share_links (list_id, slug, created_by)
      values (p_list_id, slug, actor);
    end if;
  else
    update public.cafe_lists
    set visibility = 'private', published_at = null,
        comments_enabled = coalesce(p_comments_enabled, comments_enabled), updated_at = now()
    where id = p_list_id and owner_id = actor and system_kind is null;
    update public.cafe_list_share_links
    set revoked_at = coalesce(revoked_at, now())
    where list_id = p_list_id and revoked_at is null;
  end if;

  return public.get_cafe_list_v2(p_list_id);
end;
$$;

create or replace function public.follow_cafe_list_v1(p_list_id uuid, p_follow boolean default true)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.can_socially_mutate_as(actor)
     or not private.is_public_cafe_list_as(p_list_id, actor) then
    raise exception 'public cafe list unavailable' using errcode = '42501';
  end if;
  if p_follow then
    insert into public.cafe_list_follows (list_id, user_id)
    values (p_list_id, actor) on conflict do nothing;
  else
    delete from public.cafe_list_follows where list_id = p_list_id and user_id = actor;
  end if;
  return p_follow;
end;
$$;

create or replace function public.copy_public_cafe_list_v1(p_list_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  source public.cafe_lists%rowtype;
  copied public.cafe_lists%rowtype;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.can_socially_mutate_as(actor)
     or not private.is_public_cafe_list_as(p_list_id, actor) then
    raise exception 'public cafe list unavailable' using errcode = '42501';
  end if;
  select * into source from public.cafe_lists where id = p_list_id;
  insert into public.cafe_lists (
    owner_id, title, description, visibility, comments_enabled, source_list_id
  ) values (
    actor, left(source.title || ' — Copy', 80), source.description,
    'private', true, source.id
  ) returning * into copied;

  insert into public.cafe_list_items (
    list_id, cafe_id, position, contributor_id, note
  )
  select copied.id, item.cafe_id, item.position, actor, item.note
  from public.cafe_list_items item
  where item.list_id = source.id
  order by item.position, item.created_at, item.id;

  return public.get_cafe_list_v2(copied.id);
end;
$$;

create or replace function public.comment_on_cafe_list_v1(
  p_list_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  created public.cafe_list_comments%rowtype;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.can_socially_mutate_as(actor)
     or not private.is_public_cafe_list_as(p_list_id, actor)
     or not exists (
       select 1 from public.cafe_lists list
       where list.id = p_list_id and list.comments_enabled
     ) then
    raise exception 'comments are unavailable' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_body, ''))) not between 1 and 500 then
    raise exception 'comment must be between 1 and 500 characters' using errcode = '22023';
  end if;
  if (
    select count(*) from public.cafe_list_comments comment
    where comment.user_id = actor and comment.created_at > now() - interval '1 minute'
  ) >= 5 then
    raise exception 'please wait before commenting again' using errcode = '42900';
  end if;

  insert into public.cafe_list_comments (list_id, user_id, body)
  values (p_list_id, actor, btrim(p_body)) returning * into created;
  return jsonb_build_object(
    'id', created.id,
    'body', created.body,
    'created_at', created.created_at,
    'author', private.public_cafe_list_profile_json_v1(actor, actor),
    'can_delete', true
  );
end;
$$;

create or replace function public.delete_cafe_list_comment_v1(p_comment_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  update public.cafe_list_comments comment
  set deleted_at = coalesce(comment.deleted_at, now()), deleted_by = actor, updated_at = now()
  from public.cafe_lists list
  where comment.id = p_comment_id
    and list.id = comment.list_id
    and (comment.user_id = actor or list.owner_id = actor)
    and comment.deleted_at is null;
  if not found then raise exception 'comment unavailable' using errcode = '42501'; end if;
  return true;
end;
$$;

create or replace function public.report_cafe_list_comment_v1(
  p_comment_id uuid,
  p_reason text,
  p_details text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid(); result uuid;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'reporting unavailable' using errcode = '42501';
  end if;
  if p_reason not in ('spam', 'harassment', 'privacy', 'other')
     or char_length(coalesce(p_details, '')) > 500 then
    raise exception 'invalid report' using errcode = '22023';
  end if;
  if not exists (
    select 1 from public.cafe_list_comments comment
    where comment.id = p_comment_id
      and comment.deleted_at is null
      and comment.user_id <> actor
      and private.is_public_cafe_list_as(comment.list_id, actor)
  ) then
    raise exception 'comment unavailable' using errcode = '42501';
  end if;
  insert into public.cafe_list_comment_reports (comment_id, reporter_id, reason, details)
  values (p_comment_id, actor, p_reason, nullif(btrim(p_details), ''))
  on conflict (comment_id, reporter_id) do update
  set reason = excluded.reason, details = excluded.details
  returning id into result;
  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Bounded, caller-safe enrichment for ephemeral Apple candidates
-- ---------------------------------------------------------------------------

create or replace function public.enrich_discovery_candidates_v1(p_candidates jsonb)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if jsonb_typeof(p_candidates) <> 'array'
     or jsonb_array_length(p_candidates) > 100 then
    raise exception 'candidate batch must contain at most 100 cafes' using errcode = '22023';
  end if;

  return coalesce((
    with input as (
      select
        ordinal::integer candidate_index,
        nullif(btrim(candidate->>'apple_maps_place_id'), '') apple_maps_place_id,
        nullif(btrim(candidate->>'name'), '') name,
        case when candidate->>'latitude' ~ '^-?[0-9]+(\.[0-9]+)?$'
          then (candidate->>'latitude')::double precision end latitude,
        case when candidate->>'longitude' ~ '^-?[0-9]+(\.[0-9]+)?$'
          then (candidate->>'longitude')::double precision end longitude
      from jsonb_array_elements(p_candidates) with ordinality source(candidate, ordinal)
    ), matched as (
      select input.*, cafe.id cafe_id
      from input
      left join lateral (
        select candidate.id
        from public.cafes candidate
        where (
          input.apple_maps_place_id is not null
          and candidate.apple_maps_place_id = input.apple_maps_place_id
        ) or (
          input.apple_maps_place_id is null
          and input.name is not null
          and lower(regexp_replace(btrim(candidate.name), '\s+', ' ', 'g')) =
              lower(regexp_replace(btrim(input.name), '\s+', ' ', 'g'))
          and input.latitude is not null and input.longitude is not null
          and candidate.latitude between input.latitude - 0.001 and input.latitude + 0.001
          and candidate.longitude between input.longitude - 0.001 and input.longitude + 0.001
        )
        order by (candidate.apple_maps_place_id = input.apple_maps_place_id) desc,
          abs(candidate.latitude - input.latitude) + abs(candidate.longitude - input.longitude),
          candidate.id
        limit 1
      ) cafe on true
    )
    select jsonb_agg(jsonb_build_object(
      'candidate_index', matched.candidate_index,
      'apple_maps_place_id', matched.apple_maps_place_id,
      'cafe_id', matched.cafe_id,
      'is_favorite', coalesce(saved.is_favorite, false),
      'want_to_try', coalesce(saved.want_to_try, false),
      'friend_evidence', coalesce(friend_evidence.rows, '[]'::jsonb),
      'public_list_evidence', coalesce(list_evidence.rows, '[]'::jsonb),
      'practical_evidence', coalesce(practical.rows, '[]'::jsonb)
    ) order by matched.candidate_index)
    from matched
    left join public.user_cafe_states saved
      on saved.user_id = actor and saved.cafe_id = matched.cafe_id
    left join lateral (
      select jsonb_agg(jsonb_build_object(
        'visit_id', evidence.id,
        'author', private.public_cafe_list_profile_json_v1(evidence.user_id, actor),
        'drink', coalesce(nullif(btrim(evidence.drink_subtype), ''),
                          nullif(btrim(evidence.drink_type_custom), ''),
                          nullif(btrim(evidence.drink_type), '')),
        'score', evidence.overall_score,
        'photo_url', evidence.poster_photo_url
      ) order by evidence.created_at desc) rows
      from (
        select visit.*
        from public.visits visit
        where visit.cafe_id = matched.cafe_id
          and visit.user_id <> actor
          and private.confirmed_friends(actor, visit.user_id)
          and private.can_view_visit_as(visit.id, actor)
        order by visit.created_at desc, visit.id desc
        limit 5
      ) evidence
    ) friend_evidence on true
    left join lateral (
      select jsonb_agg(jsonb_build_object(
        'list_id', list.id,
        'title', list.title,
        'creator', private.public_cafe_list_profile_json_v1(list.owner_id, actor)
      ) order by list.updated_at desc) rows
      from public.cafe_list_items item
      join public.cafe_lists list on list.id = item.list_id
      join public.cafe_list_follows follow
        on follow.list_id = list.id and follow.user_id = actor
      where item.cafe_id = matched.cafe_id
        and private.is_public_cafe_list_as(list.id, actor)
    ) list_evidence on true
    left join lateral (
      select jsonb_agg(jsonb_build_object(
        'descriptor_id', counted.descriptor_id,
        'session_count', counted.session_count,
        'contributor_count', counted.contributor_count
      ) order by counted.contributor_count desc, counted.session_count desc,
                 counted.descriptor_id) rows
      from (
        -- A shared facet alone does not prove a positive quality. Count only
        -- observations the contributor explicitly marked as lifting their
        -- experience, and return only a thresholded aggregate.
        select descriptor.descriptor_id,
          count(distinct projection.session_id)::integer session_count,
          count(distinct projection.user_id)::integer contributor_count
        from public.cafe_experience_public_projections projection
        join public.cafe_experience_snapshots snapshot
          on snapshot.session_id = projection.session_id
         and snapshot.snapshot_id = projection.snapshot_id
         and snapshot.user_id = projection.user_id
        join public.visits visit on visit.id = projection.primary_visit_id
        cross join lateral jsonb_array_elements(snapshot.responses) response
        cross join lateral jsonb_array_elements_text(
          coalesce(response->'descriptorIDs', '[]'::jsonb)
        ) descriptor(descriptor_id)
        where projection.cafe_id = matched.cafe_id
          and visit.visibility = 'everyone'
          and visit.upload_state = 'complete'
          and response->>'state' = 'observed'
          and response->>'impact' = 'lifted'
          and descriptor.descriptor_id = any(projection.descriptor_ids)
          and descriptor.descriptor_id in (
            'cafe.descriptor.music_and_sound.volume',
            'cafe.descriptor.music_and_sound.conversation_noise',
            'cafe.descriptor.music_and_sound.calm_or_stimulation',
            'cafe.descriptor.comfort_and_practicality.seating',
            'cafe.descriptor.comfort_and_practicality.wifi',
            'cafe.descriptor.comfort_and_practicality.outlets',
            'cafe.descriptor.comfort_and_practicality.table_space',
            'cafe.descriptor.comfort_and_practicality.accessibility',
            'cafe.descriptor.comfort_and_practicality.group_seating'
          )
          and private.is_live_account_as(projection.user_id)
          and not private.has_active_moderation_action(
            'visit', visit.id, array['content_hidden']::text[]
          )
        group by descriptor.descriptor_id
        having count(distinct projection.user_id) >= 3
           and count(distinct projection.session_id) >= 5

        union all

        -- Work suitability is grounded in deliberate work/study visits plus
        -- positive practical observations; it is never inferred from a lone
        -- Wi-Fi or outlet mention.
        select 'cafe.fit.work_study' descriptor_id,
          count(distinct projection.session_id)::integer session_count,
          count(distinct projection.user_id)::integer contributor_count
        from public.cafe_experience_public_projections projection
        join public.cafe_experience_snapshots snapshot
          on snapshot.session_id = projection.session_id
         and snapshot.snapshot_id = projection.snapshot_id
         and snapshot.user_id = projection.user_id
        join public.cafe_sessions session on session.id = projection.session_id
        join public.visits visit on visit.id = projection.primary_visit_id
        where projection.cafe_id = matched.cafe_id
          and session.visit_mode = 'work_study'
          and visit.visibility = 'everyone'
          and visit.upload_state = 'complete'
          and private.is_live_account_as(projection.user_id)
          and not private.has_active_moderation_action(
            'visit', visit.id, array['content_hidden']::text[]
          )
          and exists (
            select 1
            from jsonb_array_elements(snapshot.responses) response
            cross join lateral jsonb_array_elements_text(
              coalesce(response->'descriptorIDs', '[]'::jsonb)
            ) descriptor(descriptor_id)
            where response->>'state' = 'observed'
              and response->>'impact' = 'lifted'
              and descriptor.descriptor_id = any(projection.descriptor_ids)
              and descriptor.descriptor_id in (
                'cafe.descriptor.comfort_and_practicality.seating',
                'cafe.descriptor.comfort_and_practicality.wifi',
                'cafe.descriptor.comfort_and_practicality.outlets',
                'cafe.descriptor.comfort_and_practicality.table_space'
              )
          )
        having count(distinct projection.user_id) >= 3
           and count(distinct projection.session_id) >= 5
      ) counted
    ) practical on true
  ), '[]'::jsonb);
end;
$$;

revoke all on function public.record_discovery_interaction_v1(
  uuid, uuid, text, text, text, uuid, text, jsonb, timestamptz
) from public, anon, authenticated;
revoke all on function public.consume_discovery_attribution_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.browse_public_cafe_lists_v1(integer, timestamptz)
  from public, anon, authenticated;
revoke all on function public.get_public_cafe_list_v1(text)
  from public, anon, authenticated;
revoke all on function public.set_cafe_list_publication_v1(uuid, boolean, boolean)
  from public, anon, authenticated;
revoke all on function public.follow_cafe_list_v1(uuid, boolean)
  from public, anon, authenticated;
revoke all on function public.copy_public_cafe_list_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.comment_on_cafe_list_v1(uuid, text)
  from public, anon, authenticated;
revoke all on function public.delete_cafe_list_comment_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.report_cafe_list_comment_v1(uuid, text, text)
  from public, anon, authenticated;
revoke all on function public.enrich_discovery_candidates_v1(jsonb)
  from public, anon, authenticated;

grant execute on function public.record_discovery_interaction_v1(
  uuid, uuid, text, text, text, uuid, text, jsonb, timestamptz
) to authenticated;
grant execute on function public.consume_discovery_attribution_v1(uuid) to authenticated;
grant execute on function public.browse_public_cafe_lists_v1(integer, timestamptz)
  to anon, authenticated;
grant execute on function public.get_public_cafe_list_v1(text) to anon, authenticated;
grant execute on function public.set_cafe_list_publication_v1(uuid, boolean, boolean)
  to authenticated;
grant execute on function public.follow_cafe_list_v1(uuid, boolean) to authenticated;
grant execute on function public.copy_public_cafe_list_v1(uuid) to authenticated;
grant execute on function public.comment_on_cafe_list_v1(uuid, text) to authenticated;
grant execute on function public.delete_cafe_list_comment_v1(uuid) to authenticated;
grant execute on function public.report_cafe_list_comment_v1(uuid, text, text)
  to authenticated;
grant execute on function public.enrich_discovery_candidates_v1(jsonb) to authenticated;

comment on function public.enrich_discovery_candidates_v1(jsonb) is
  'Caller-bound, bounded discovery enrichment; never returns private notes or raw Cafe Pulse snapshots.';
comment on function public.consume_discovery_attribution_v1(uuid) is
  'Attributes a caller-owned Mugshot once using a 30-day touch or unconsumed first-log save.';
comment on function public.get_public_cafe_list_v1(text) is
  'Anonymous-safe public list detail addressed by an opaque, revocable slug.';

commit;
