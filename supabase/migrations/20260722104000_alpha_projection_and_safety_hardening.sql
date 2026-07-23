begin;

-- Final alpha cross-feature hardening. Public and social projections all use
-- the same live-account and enforcement boundaries, while decline, leave,
-- cancel, block, and manual-delete exits remain available without expanding
-- anyone's access.

-- ---------------------------------------------------------------------------
-- Signed-out Map discovery and authenticated people projections
-- ---------------------------------------------------------------------------

create or replace function private.is_public_visit_discoverable_v3(
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
      and visit.visibility = 'everyone'
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

revoke all on function private.is_public_visit_discoverable_v3(uuid)
  from public, anon, authenticated;

create or replace function public.discover_public_cafes(
  p_section text default 'nearby',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km double precision default 25,
  p_limit integer default 20,
  p_after_score double precision default null,
  p_after_id uuid default null
)
returns table (
  cafe_id uuid, name text, address text, city text, latitude double precision,
  longitude double precision, identity_key text, section text,
  ranking_score double precision, ranking_reason text, distance_km double precision,
  average_rating double precision, visible_visit_count bigint, friend_count bigint,
  top_drinks jsonb, recent_cover text, is_saved boolean, is_visited boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (
    select
      case when p_latitude between -90 and 90 and p_longitude between -180 and 180
        then p_latitude end lat,
      case when p_latitude between -90 and 90 and p_longitude between -180 and 180
        then p_longitude end lon,
      least(greatest(coalesce(p_radius_km, 25), 1), 100) radius,
      least(greatest(coalesce(p_limit, 20), 1), 50) page_size
  ), public_visits as (
    select visit.*
    from public.visits visit
    where visit.cafe_id is not null
      and private.is_public_visit_discoverable_v3(visit.id)
  ), aggregates as (
    select
      cafe.id, cafe.name, cafe.address, cafe.city, cafe.latitude, cafe.longitude,
      cafe.identity_key,
      case when input.lat is null then null else
        6371 * 2 * asin(sqrt(
          power(sin(radians(cafe.latitude - input.lat) / 2), 2)
          + cos(radians(input.lat)) * cos(radians(cafe.latitude))
          * power(sin(radians(cafe.longitude - input.lon) / 2), 2)
        ))
      end distance,
      count(visit.id) visit_count,
      avg(visit.overall_score)::double precision avg_rating,
      count(visit.id) filter (
        where visit.created_at >= now() - interval '30 days'
      ) recent_count,
      max(visit.poster_photo_url) filter (
        where visit.poster_photo_url is not null
      ) recent_cover,
      coalesce((
        select jsonb_agg(
          jsonb_build_object('name', drinks.drink, 'count', drinks.n)
          order by drinks.n desc, drinks.drink
        )
        from (
          select coalesce(
                   drink_visit.drink_subtype,
                   drink_visit.drink_type_custom,
                   drink_visit.drink_type
                 ) drink,
                 count(*) n
          from public_visits drink_visit
          where drink_visit.cafe_id = cafe.id
            and coalesce(
              drink_visit.drink_subtype,
              drink_visit.drink_type_custom,
              drink_visit.drink_type
            ) is not null
          group by 1
          order by 2 desc, 1
          limit 3
        ) drinks
      ), '[]'::jsonb) drinks,
      input.radius
    from public.cafes cafe
    cross join input
    join public_visits visit on visit.cafe_id = cafe.id
    where cafe.latitude is not null and cafe.longitude is not null
    group by cafe.id, input.lat, input.lon, input.radius
  ), scored as (
    select aggregates.*,
      (
        coalesce(.42 * greatest(0, 1 - aggregates.distance / aggregates.radius), 0)
        + .30 * least(coalesce(aggregates.avg_rating, 0) / 5, 1)
        + .18 * least(aggregates.visit_count::double precision / 8, 1)
        + .10 * least(aggregates.recent_count::double precision / 4, 1)
      ) / (case when aggregates.distance is null then .58 else 1 end) score
    from aggregates
  ), filtered as (
    select scored.*,
      case p_section
        when 'popular_drinks' then 'Popular drinks from the Mugshot community'
        when 'trending' then 'Recently remembered by the Mugshot community'
        else case when scored.distance is null
          then 'Loved by the Mugshot community'
          else 'A community pick nearby'
        end
      end reason
    from scored
    where (scored.distance is null or scored.distance <= scored.radius)
      and case p_section
        when 'nearby' then true
        when 'popular_drinks' then scored.drinks <> '[]'::jsonb
        when 'trending' then scored.recent_count > 0
        else false
      end
  )
  select
    filtered.id, filtered.name, filtered.address, filtered.city,
    filtered.latitude, filtered.longitude, filtered.identity_key, p_section,
    filtered.score, filtered.reason, filtered.distance, filtered.avg_rating,
    filtered.visit_count, 0::bigint, filtered.drinks, filtered.recent_cover,
    false, false
  from filtered
  where p_after_score is null
     or (filtered.score, filtered.id) < (p_after_score, p_after_id)
  order by filtered.score desc, filtered.id desc
  limit (select page_size from input);
$$;

revoke all on function public.discover_public_cafes(
  text,double precision,double precision,double precision,integer,double precision,uuid
) from public, anon, authenticated;
grant execute on function public.discover_public_cafes(
  text,double precision,double precision,double precision,integer,double precision,uuid
) to anon, authenticated;

create or replace function public.companion_suggestions(p_limit integer default 50)
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
  with input as (select auth.uid() actor)
  select friend.id, friend.display_name, friend.username, friend.avatar_url,
    count(companion.visit_id)::integer,
    max(companion.created_at)
  from input
  join public.users friend
    on friend.id <> input.actor
   and private.confirmed_friends(input.actor, friend.id)
   and private.can_view_user_as(friend.id, input.actor)
  left join public.visit_companions companion
    on companion.companion_user_id = friend.id
   and companion.added_by = input.actor
  where input.actor is not null
  group by friend.id
  order by count(companion.visit_id) desc,
           max(companion.created_at) desc nulls last,
           friend.display_name,
           friend.id
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

revoke all on function public.companion_suggestions(integer)
  from public, anon, authenticated;
grant execute on function public.companion_suggestions(integer) to authenticated;

create or replace function public.friend_compatibility(p_friend_id uuid)
returns table(
  evidence_level text,
  shared_signal_count integer,
  shared_attributes text[],
  explanation text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  shared text[];
  count_shared integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.confirmed_friends(actor, p_friend_id)
     or not private.can_view_taste_passport_as(p_friend_id, actor) then
    raise exception 'taste compatibility unavailable' using errcode = '42501';
  end if;

  select array_agg(
           replace(a.attribute, '_', ' ')
           order by least(a.support_count, b.support_count) desc, a.attribute
         ),
         count(*)
  into shared, count_shared
  from public.taste_signals a
  join public.taste_signals b
    on b.user_id = p_friend_id
   and b.signal_type = a.signal_type
   and b.attribute = a.attribute
  where a.user_id = actor
    and a.support_count >= 3
    and b.support_count >= 3
    and a.owner_state = 'active'
    and b.owner_state = 'active';

  count_shared := coalesce(count_shared, 0);
  return query select
    case
      when count_shared >= 4 then 'strong_overlap'
      when count_shared >= 2 then 'some_overlap'
      else 'still_learning'
    end,
    count_shared,
    coalesce(shared[1:3], '{}'::text[]),
    case
      when count_shared >= 4 then 'Several journal patterns overlap.'
      when count_shared >= 2 then 'A few journal patterns overlap.'
      else 'Mugshot needs more shared journal evidence.'
    end;
end;
$$;

revoke all on function public.friend_compatibility(uuid)
  from public, anon, authenticated;
grant execute on function public.friend_compatibility(uuid) to authenticated;

create or replace function public.list_visible_visit_tags_v1(p_visit_id uuid)
returns table (
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  tagged_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    profile.id,
    profile.display_name,
    profile.username,
    profile.avatar_url,
    tag.created_at
  from input
  join public.visit_companions tag on tag.visit_id = p_visit_id
  join public.users profile on profile.id = tag.companion_user_id
  where input.actor is not null
    and private.can_view_visit_as(p_visit_id, input.actor)
    and private.can_view_user_as(profile.id, input.actor)
  order by tag.created_at, profile.id;
$$;

revoke all on function public.list_visible_visit_tags_v1(uuid)
  from public, anon;
grant execute on function public.list_visible_visit_tags_v1(uuid) to authenticated;

-- A visible post may name a recipe whose independent blueprint audience does
-- not include the viewer. Return identity only so the client can render an
-- honest locked state without selecting visits.brew_details or weakening the
-- caller-bound full recipe projection.
create or replace function public.get_recipe_identity_for_visit_v1(p_visit_id uuid)
returns table (
  recipe_identity_id uuid,
  recipe_version_id uuid,
  recipe_name text,
  version_number integer,
  version_label text,
  owner_id uuid,
  owner_display_name text,
  owner_username text,
  owner_avatar_url text
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    identity.id,
    version.id,
    identity.name,
    version.version_number,
    version.version_label,
    owner.id,
    owner.display_name,
    owner.username,
    owner.avatar_url
  from input
  join public.visits visit on visit.id = p_visit_id
  join public.recipe_versions version on version.id = visit.recipe_version_id
  join public.recipe_identities identity
    on identity.id = version.recipe_identity_id
  join public.users owner on owner.id = identity.user_id
  where input.actor is not null
    and private.can_view_visit_as(p_visit_id, input.actor)
    and private.can_view_user_as(owner.id, input.actor);
$$;

revoke all on function public.get_recipe_identity_for_visit_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.get_recipe_identity_for_visit_v1(uuid)
  to authenticated;

comment on function public.get_recipe_identity_for_visit_v1(uuid) is
  'Identity-only recipe attribution for an independently visible post; never returns brew instructions, method, equipment, rights, or source payload.';

-- ---------------------------------------------------------------------------
-- Shared MugShot identity masking and monotonic lifecycle exits
-- ---------------------------------------------------------------------------

create or replace function public.list_pending_shared_memory_invitations_v1()
returns table (
  invitation_id uuid,
  shared_memory_id uuid,
  inviter_id uuid,
  inviter_display_name text,
  inviter_username text,
  inviter_avatar_url text,
  context_type text,
  cafe_id uuid,
  location_label text,
  occurred_at timestamptz,
  invited_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    member.id,
    memory.id,
    inviter.id,
    inviter.display_name,
    inviter.username,
    inviter.avatar_url,
    memory.context_type,
    memory.cafe_id,
    memory.location_label,
    memory.occurred_at,
    member.created_at
  from input
  join public.shared_memory_members member
    on member.user_id = input.actor and member.status = 'pending'
  join public.shared_memories memory on memory.id = member.shared_memory_id
  join public.users inviter on inviter.id = member.invited_by
  where input.actor is not null
    and private.can_view_user_as(inviter.id, input.actor)
  order by member.created_at desc, member.id desc;
$$;

create or replace function public.list_managed_shared_memory_invitations_v1(
  p_shared_memory_id uuid
)
returns table (
  invitation_id uuid,
  user_id uuid,
  display_name text,
  username text,
  avatar_url text,
  status text,
  invited_at timestamptz,
  responded_at timestamptz,
  left_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    member.id,
    case when private.can_view_user_as(profile.id, input.actor)
      then profile.id end,
    case when private.can_view_user_as(profile.id, input.actor)
      then profile.display_name end,
    case when private.can_view_user_as(profile.id, input.actor)
      then profile.username end,
    case when private.can_view_user_as(profile.id, input.actor)
      then profile.avatar_url end,
    member.status,
    member.created_at,
    member.responded_at,
    member.left_at
  from input
  join public.shared_memories memory
    on memory.id = p_shared_memory_id
   and memory.managed_by = input.actor
  join public.shared_memory_members member
    on member.shared_memory_id = memory.id
   and member.user_id <> input.actor
  join public.users profile on profile.id = member.user_id
  where input.actor is not null
  order by member.created_at, member.id;
$$;

create or replace function public.list_my_shared_memory_memberships_v1()
returns table (
  membership_id uuid,
  shared_memory_id uuid,
  status text,
  inviter_id uuid,
  inviter_display_name text,
  inviter_username text,
  inviter_avatar_url text,
  relationship_available boolean,
  context_type text,
  cafe_id uuid,
  location_label text,
  occurred_at timestamptz,
  invited_at timestamptz,
  responded_at timestamptz
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() actor)
  select
    member.id,
    memory.id,
    member.status,
    case when private.can_view_user_as(inviter.id, input.actor) then inviter.id end,
    case when private.can_view_user_as(inviter.id, input.actor)
      then inviter.display_name end,
    case when private.can_view_user_as(inviter.id, input.actor)
      then inviter.username end,
    case when private.can_view_user_as(inviter.id, input.actor)
      then inviter.avatar_url end,
    coalesce(private.can_view_user_as(inviter.id, input.actor), false),
    memory.context_type,
    memory.cafe_id,
    memory.location_label,
    memory.occurred_at,
    member.created_at,
    member.responded_at
  from input
  join public.shared_memory_members member
    on member.user_id = input.actor
   and member.status in ('pending', 'accepted')
  join public.shared_memories memory on memory.id = member.shared_memory_id
  left join public.users inviter on inviter.id = member.invited_by
  where input.actor is not null
    and memory.managed_by is distinct from input.actor
  order by
    (member.status = 'pending') desc,
    member.created_at desc,
    member.id desc;
$$;

revoke all on function public.list_pending_shared_memory_invitations_v1()
  from public, anon, authenticated;
revoke all on function public.list_managed_shared_memory_invitations_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.list_my_shared_memory_memberships_v1()
  from public, anon, authenticated;
grant execute on function public.list_pending_shared_memory_invitations_v1()
  to authenticated;
grant execute on function public.list_managed_shared_memory_invitations_v1(uuid)
  to authenticated;
grant execute on function public.list_my_shared_memory_memberships_v1()
  to authenticated;

create or replace function public.leave_shared_memory_v1(p_shared_memory_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  memory public.shared_memories%rowtype;
  successor uuid;
  changed_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select * into memory
  from public.shared_memories
  where id = p_shared_memory_id
  for update;
  if not found or not exists (
    select 1
    from public.shared_memory_members member
    where member.shared_memory_id = p_shared_memory_id
      and member.user_id = actor
      and member.status = 'accepted'
  ) then
    return false;
  end if;

  if memory.managed_by = actor then
    select member.user_id into successor
    from public.shared_memory_members member
    where member.shared_memory_id = p_shared_memory_id
      and member.user_id <> actor
      and member.status = 'accepted'
      and private.can_socially_mutate_as(member.user_id)
      and not private.account_deletion_active_as(member.user_id)
      and not private.blocked_between(actor, member.user_id)
    order by
      coalesce(member.responded_at, member.created_at),
      member.created_at,
      member.user_id
    limit 1;

    if successor is null then
      delete from public.shared_memories where id = p_shared_memory_id;
      return true;
    end if;
    update public.shared_memories
    set managed_by = successor, updated_at = now()
    where id = p_shared_memory_id;
  end if;

  update public.shared_memory_members
  set status = 'left',
      left_at = now(),
      responded_at = coalesce(responded_at, now())
  where shared_memory_id = p_shared_memory_id
    and user_id = actor
    and status = 'accepted';
  get diagnostics changed_count = row_count;

  if changed_count > 0 then
    delete from public.shared_memory_contributions
    where shared_memory_id = p_shared_memory_id and user_id = actor;
    update public.shared_memories
    set updated_at = now()
    where id = p_shared_memory_id;
  end if;
  return changed_count > 0;
end;
$$;

revoke all on function public.leave_shared_memory_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.leave_shared_memory_v1(uuid) to authenticated;

-- A manual post deletion dissolves only its shared grouping; every person's
-- independently owned post remains. Account deletion has an active frozen
-- succession plan and therefore keeps the grouping for its finalizer.
create or replace function private.dissolve_manual_shared_memory_source_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.account_deletion_active_as(old.user_id) then
    delete from public.shared_memories memory
    where memory.source_visit_id = old.id;
  end if;
  return old;
end;
$$;

revoke all on function private.dissolve_manual_shared_memory_source_v3()
  from public, anon, authenticated;

drop trigger if exists dissolve_manual_shared_memory_source_v3 on public.visits;
create trigger dissolve_manual_shared_memory_source_v3
before delete on public.visits
for each row execute function private.dissolve_manual_shared_memory_source_v3();

-- ---------------------------------------------------------------------------
-- Recommendation visibility
-- ---------------------------------------------------------------------------

create or replace function public.can_project_recipe_version(
  p_recipe_version_id uuid,
  p_viewer uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer = (select auth.uid())
    and private.can_project_recipe_version_as(p_recipe_version_id, p_viewer);
$$;

revoke all on function public.can_project_recipe_version(uuid,uuid)
  from public, anon;
grant execute on function public.can_project_recipe_version(uuid,uuid)
  to authenticated;

drop policy if exists "Recommendation participants read"
  on public.trusted_recommendations;
create policy "Recommendation participants read"
on public.trusted_recommendations for select to authenticated
using (
  (
    sender_id = (select auth.uid())
    and public.can_view_user(sender_id, (select auth.uid()))
  )
  or (
    recipient_id = (select auth.uid())
    and public.can_view_user(recipient_id, (select auth.uid()))
    and public.can_view_user(sender_id, (select auth.uid()))
    and case target_kind
      when 'cafe' then target_cafe_id is not null and exists (
        select 1 from public.cafes cafe where cafe.id = target_cafe_id
      )
      when 'visit' then target_visit_id is not null
        and public.can_view_visit(target_visit_id, (select auth.uid()))
      when 'recipe' then target_recipe_version_id is not null
        and public.can_project_recipe_version(
          target_recipe_version_id,
          (select auth.uid())
        )
      else false
    end
  )
);

comment on function private.is_public_visit_discoverable_v3(uuid) is
  'Anon-safe eligibility for complete Everyone posts from live, non-suspended authors whose post is not hidden.';
comment on function public.friend_compatibility(uuid) is
  'Friend compatibility is available only when the target Taste Passport audience permits the caller.';
comment on function private.dissolve_manual_shared_memory_source_v3() is
  'Dissolves a manual source-post grouping while preserving frozen account-deletion succession and independent posts.';
comment on function public.can_project_recipe_version(uuid,uuid) is
  'Caller-bound RLS wrapper for recipe recommendation visibility.';

commit;
