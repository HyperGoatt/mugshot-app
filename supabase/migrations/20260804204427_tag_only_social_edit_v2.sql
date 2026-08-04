begin;

-- The old relation already represented ordinary post tags. Rename it so the
-- physical schema and every future query use the product language directly.
alter table public.visit_companions rename to visit_tags;
alter table public.visit_tags rename column companion_user_id to tagged_user_id;
alter table public.visit_tags rename column added_by to tagged_by;

-- Renaming a table preserves its triggers, but PL/pgSQL trigger records still
-- use the old field names. Pause them before the historical conversion so it
-- neither fails nor emits retroactive activity.
drop trigger if exists activity_from_tag on public.visit_tags;
drop trigger if exists cleanup_activity_from_tag on public.visit_tags;
drop trigger if exists enforce_visit_companion_pair_lock on public.visit_tags;

alter index if exists public.visit_companions_pkey rename to visit_tags_pkey;
alter index if exists public.visit_companions_user_created_idx
  rename to visit_tags_user_created_idx;
alter index if exists public.visit_companions_added_by_created_idx
  rename to visit_tags_tagged_by_created_idx;

drop policy if exists "Visible sip companions" on public.visit_tags;
drop policy if exists "Visible visit tags" on public.visit_tags;
create policy "Visible visit tags" on public.visit_tags
  for select to authenticated
  using (
    public.can_view_visit(visit_id, (select auth.uid()))
    and public.can_view_user(tagged_user_id, (select auth.uid()))
  );
revoke all on table public.visit_tags from public, anon, authenticated;

comment on table public.visit_tags is
  'Optional post tags. Tags do not grant ownership, consent, or post visibility.';
comment on column public.visit_tags.tagged_user_id is
  'The tagged account. The account may remove its own tag at any time.';
comment on column public.visit_tags.tagged_by is
  'The owning post author who added the tag.';

-- A revoked compatibility view keeps older private moderation/export
-- routines safe while the canonical table, public RPCs, and indexes are all
-- tag-named. No client role can query or mutate this view.
create view public.visit_companions as
select
  visit_id,
  tagged_user_id as companion_user_id,
  tagged_by as added_by,
  created_at
from public.visit_tags;
revoke all on table public.visit_companions from public, anon, authenticated;
comment on view public.visit_companions is
  'Internal compatibility view for pre-tag private routines. Not a client contract.';

-- Convert every independently authored Shared Mugshot contribution into tags
-- on the other contributions in the same memory. Existing ordinary tags win;
-- no activity trigger is invoked and no post or audience is changed.
insert into public.visit_tags (
  visit_id,
  tagged_user_id,
  tagged_by,
  created_at
)
select
  contribution.visit_id,
  other.user_id,
  contribution.user_id,
  greatest(contribution.joined_at, other.joined_at)
from public.shared_memory_contributions contribution
join public.shared_memory_contributions other
  on other.shared_memory_id = contribution.shared_memory_id
 and other.user_id <> contribution.user_id
join public.visits visit
  on visit.id = contribution.visit_id
 and visit.user_id = contribution.user_id
where not private.blocked_between(contribution.user_id, other.user_id)
on conflict (visit_id, tagged_user_id) do nothing;

create or replace function private.activity_from_tag_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.create_activity_event_v1(
    new.tagged_user_id, new.tagged_by, 'tag',
    'tag:' || new.visit_id::text || ':' || new.tagged_user_id::text,
    'You were tagged', 'You were tagged in a MugShot.', new.visit_id
  );
  return new;
end;
$$;

create or replace function private.cleanup_activity_from_tag_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_events event
  where event.kind = 'tag'
    and event.recipient_id = old.tagged_user_id
    and event.actor_user_id = old.tagged_by
    and event.visit_id = old.visit_id;
  return old;
end;
$$;

create or replace function private.enforce_visit_companion_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  visit_owner uuid;
begin
  select visit.user_id into visit_owner
  from public.visits visit
  where visit.id = new.visit_id;

  if visit_owner is null then
    raise exception 'visit unavailable' using errcode = 'P0002';
  end if;
  perform private.lock_social_pairs_v1(
    new.tagged_by, array[visit_owner, new.tagged_user_id], true
  );
  return new;
end;
$$;

revoke all on function private.activity_from_tag_v1()
  from public, anon, authenticated;
revoke all on function private.cleanup_activity_from_tag_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_visit_companion_pair_lock_v1()
  from public, anon, authenticated;

create trigger activity_from_tag
after insert or update of created_at, tagged_by on public.visit_tags
for each row execute function private.activity_from_tag_v1();
create trigger cleanup_activity_from_tag
after delete on public.visit_tags
for each row execute function private.cleanup_activity_from_tag_v1();
create trigger enforce_visit_companion_pair_lock
before insert or update of visit_id, tagged_user_id, tagged_by
on public.visit_tags
for each row execute function private.enforce_visit_companion_pair_lock_v1();

create or replace function public.set_visit_tags_v1(
  p_visit_id uuid,
  p_tagged_user_ids uuid[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  requested_tagged_user_id uuid;
  distinct_ids uuid[];
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and visit.user_id = actor
      and visit.upload_state = 'complete'
  ) then
    raise exception 'published visit ownership required' using errcode = '42501';
  end if;

  select coalesce(array_agg(distinct requested_id), '{}'::uuid[])
  into distinct_ids
  from unnest(coalesce(p_tagged_user_ids, '{}'::uuid[])) requested_id
  where requested_id is not null and requested_id <> actor;

  if cardinality(distinct_ids) > 12 then
    raise exception 'a post can include at most 12 tags' using errcode = '22023';
  end if;

  foreach requested_tagged_user_id in array distinct_ids loop
    if not exists (
         select 1 from public.users profile
         where profile.id = requested_tagged_user_id
       )
       or private.blocked_between(actor, requested_tagged_user_id) then
      raise exception 'tagged account is unavailable' using errcode = '42501';
    end if;
  end loop;

  delete from public.visit_tags tag
  where tag.visit_id = p_visit_id
    and tag.tagged_by = actor
    and tag.tagged_user_id <> all(distinct_ids);

  insert into public.visit_tags (visit_id, tagged_user_id, tagged_by)
  select p_visit_id, requested_id, actor
  from unnest(distinct_ids) requested_id
  on conflict (visit_id, tagged_user_id) do nothing;
end;
$$;

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
  join public.visit_tags tag on tag.visit_id = p_visit_id
  join public.users profile on profile.id = tag.tagged_user_id
  where input.actor is not null
    and private.can_view_visit_as(p_visit_id, input.actor)
    and private.can_view_user_as(profile.id, input.actor)
    and not private.blocked_between(input.actor, profile.id)
  order by tag.created_at, profile.id;
$$;

create or replace function public.remove_self_visit_tag_v1(p_visit_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  removed_count integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  delete from public.visit_tags
  where visit_id = p_visit_id and tagged_user_id = actor;
  get diagnostics removed_count = row_count;
  return removed_count > 0;
end;
$$;

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
  with input as (select auth.uid() actor)
  select
    profile.id,
    profile.display_name,
    profile.username,
    profile.avatar_url,
    count(tag.visit_id)::integer,
    max(visit.created_at)
  from input
  join public.users profile
    on profile.id <> input.actor
   and private.can_view_user_as(profile.id, input.actor)
   and not private.blocked_between(input.actor, profile.id)
  left join public.visit_tags tag
    on tag.tagged_user_id = profile.id
   and tag.tagged_by = input.actor
  left join public.visits visit
    on visit.id = tag.visit_id
   and visit.user_id = input.actor
   and visit.upload_state = 'complete'
  where input.actor is not null
  group by profile.id
  order by count(visit.id) desc,
           max(visit.created_at) desc nulls last,
           profile.id
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

create or replace function public.get_journal_people_counts_v1(
  p_start_at timestamptz,
  p_end_at timestamptz,
  p_limit integer default 3
)
returns table (
  account_id uuid,
  display_name text,
  username text,
  avatar_url text,
  sip_count integer,
  latest_shared_sip_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  bounded_limit integer := least(greatest(coalesce(p_limit, 3), 1), 25);
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_start_at is null or p_end_at is null or p_end_at <= p_start_at then
    raise exception 'a valid half-open date range is required' using errcode = '22023';
  end if;
  if p_end_at - p_start_at > interval '370 days' then
    raise exception 'date range cannot exceed 370 days' using errcode = '22023';
  end if;

  return query
  select
    profile.id,
    profile.display_name,
    profile.username,
    profile.avatar_url,
    count(visit.id)::integer,
    max(visit.created_at)
  from public.visits visit
  join public.visit_tags tag on tag.visit_id = visit.id
  join public.users profile on profile.id = tag.tagged_user_id
  where visit.user_id = actor
    and visit.upload_state = 'complete'
    and visit.created_at >= p_start_at
    and visit.created_at < p_end_at
    and not private.blocked_between(actor, profile.id)
    and private.can_view_user_as(profile.id, actor)
  group by profile.id
  order by count(visit.id) desc, max(visit.created_at) desc, profile.id
  limit bounded_limit;
end;
$$;

revoke all on function public.set_visit_tags_v1(uuid, uuid[])
  from public, anon, authenticated;
revoke all on function public.list_visible_visit_tags_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.remove_self_visit_tag_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.visit_tag_suggestions_v1(integer)
  from public, anon, authenticated;
revoke all on function public.get_journal_people_counts_v1(timestamptz,timestamptz,integer)
  from public, anon, authenticated;
grant execute on function public.set_visit_tags_v1(uuid, uuid[]) to authenticated;
grant execute on function public.list_visible_visit_tags_v1(uuid) to authenticated;
grant execute on function public.remove_self_visit_tag_v1(uuid) to authenticated;
grant execute on function public.visit_tag_suggestions_v1(integer) to authenticated;
grant execute on function public.get_journal_people_counts_v1(timestamptz,timestamptz,integer)
  to authenticated;

comment on function public.get_journal_people_counts_v1(timestamptz,timestamptz,integer) is
  'Owner-private, date-bounded counts of completed authored visits by current tag. Returns identity and aggregate counts only.';

-- The content helper and tag replacement participate in this single outer
-- transaction. Any validation or write failure rolls the entire edit back.
create or replace function public.edit_owned_visit_v2(
  p_visit_id uuid,
  p_caption text,
  p_visibility text,
  p_overall_score numeric,
  p_sip_criteria jsonb default '[]'::jsonb,
  p_context_score numeric default null,
  p_context_criteria jsonb default '[]'::jsonb,
  p_sip_raw_note text default null,
  p_context_raw_note text default null,
  p_raw_note_visibility text default 'private',
  p_legacy_private_note text default null,
  p_photo_urls jsonb default '[]'::jsonb,
  p_tagged_user_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  edited_visit_id uuid;
begin
  edited_visit_id := private.edit_owned_visit_content_v2(
    p_visit_id,
    p_caption,
    p_visibility,
    p_overall_score,
    p_sip_criteria,
    p_context_score,
    p_context_criteria,
    p_sip_raw_note,
    p_context_raw_note,
    p_raw_note_visibility,
    p_legacy_private_note,
    p_photo_urls
  );
  perform public.set_visit_tags_v1(p_visit_id, p_tagged_user_ids);
  return edited_visit_id;
end;
$$;

revoke all on function public.edit_owned_visit_v2(
  uuid, text, text, numeric, jsonb, numeric, jsonb, text, text, text, text, jsonb, uuid[]
) from public, anon, authenticated;
grant execute on function public.edit_owned_visit_v2(
  uuid, text, text, numeric, jsonb, numeric, jsonb, text, text, text, text, jsonb, uuid[]
) to authenticated, service_role;

comment on function public.edit_owned_visit_v2(
  uuid, text, text, numeric, jsonb, numeric, jsonb, text, text, text, text, jsonb, uuid[]
) is
  'Atomically edits an owned published visit, reflection, audiences, ordered photos, and current tags.';

-- Shared Mugshots are no longer a product capability. Remove every public
-- mutation/projection endpoint and every trigger before clearing the retired
-- grouping rows. Independently owned visits and their audiences remain.
do $$
declare
  trigger_record record;
begin
  for trigger_record in
    select namespace.nspname, relation.relname, trigger.tgname
    from pg_catalog.pg_trigger trigger
    join pg_catalog.pg_class relation on relation.oid = trigger.tgrelid
    join pg_catalog.pg_namespace namespace on namespace.oid = relation.relnamespace
    where not trigger.tgisinternal
      and namespace.nspname = 'public'
      and relation.relname in (
        'shared_memories', 'shared_memory_members', 'shared_memory_contributions'
      )
  loop
    execute format(
      'drop trigger %I on %I.%I',
      trigger_record.tgname,
      trigger_record.nspname,
      trigger_record.relname
    );
  end loop;
end;
$$;

drop function if exists public.create_shared_memory_invitations_v1(uuid, uuid[]) cascade;
drop function if exists public.list_pending_shared_memory_invitations_v1() cascade;
drop function if exists public.list_managed_shared_memory_invitations_v1(uuid) cascade;
drop function if exists public.list_my_shared_memory_memberships_v1() cascade;
drop function if exists public.list_owned_shared_memories_v1() cascade;
drop function if exists public.respond_shared_memory_invitation_v1(uuid, boolean) cascade;
drop function if exists public.attach_shared_memory_contribution_v1(uuid, uuid) cascade;
drop function if exists public.cancel_shared_memory_invitation_v1(uuid) cascade;
drop function if exists public.leave_shared_memory_v1(uuid) cascade;
drop function if exists public.get_shared_memory_projection_v1(uuid) cascade;
drop function if exists public.can_view_shared_memory(uuid) cascade;
drop function if exists private.activity_from_shared_memory_invitation_v1() cascade;
drop function if exists private.cleanup_activity_from_shared_memory_invitation_v1() cascade;
drop function if exists private.create_shared_memory_invitations_v1(uuid, uuid[]) cascade;
drop function if exists private.respond_shared_memory_invitation_v1(uuid, boolean) cascade;
drop function if exists private.attach_shared_memory_contribution_v1(uuid, uuid) cascade;
drop function if exists private.can_view_shared_memory_as(uuid, uuid) cascade;
drop function if exists private.dissolve_manual_shared_memory_source_v3() cascade;

delete from public.activity_events where kind = 'shared_mugshot_invitation';
delete from public.shared_memories;
revoke all on table public.shared_memory_contributions from public, anon, authenticated;
revoke all on table public.shared_memory_members from public, anon, authenticated;
revoke all on table public.shared_memories from public, anon, authenticated;

comment on table public.shared_memories is
  'Retired empty storage shell kept only until the account-lifecycle internals are replaced. It has no rows, client grants, triggers, or public API.';
comment on table public.shared_memory_members is
  'Retired empty storage shell with no client grants, triggers, or public API.';
comment on table public.shared_memory_contributions is
  'Retired empty storage shell with no client grants, triggers, or public API.';

drop function if exists public.set_visit_companions(uuid, uuid[]);
drop function if exists private.set_visit_companions(uuid, uuid[]);
drop function if exists public.companion_suggestions(integer);

alter table public.activity_events
  drop constraint if exists activity_events_kind_check;
alter table public.activity_events
  add constraint activity_events_kind_check check (kind in (
    'friend_post', 'tag',
    'collaborative_list_invitation',
    'collaborative_list_invitation_accepted',
    'collaborative_list_invitation_declined',
    'collaborative_list_invitation_cancelled',
    'collaborative_list_role_changed',
    'collaborative_list_member_removed',
    'collaborative_list_member_left',
    'collaborative_list_ownership_transferred',
    'collaborative_list_deleted',
    'like', 'comment', 'comment_mention', 'reaction',
    'friend_request', 'friend_request_accepted'
  ));

create or replace function private.activity_kind_push_enabled(
  p_recipient uuid,
  p_kind text
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce((
    select preference.push_enabled and case p_kind
      when 'friend_post' then preference.friend_posts
      when 'tag' then preference.tags
      when 'collaborative_list_invitation'
        then preference.collaborative_list_invitations
      when 'collaborative_list_invitation_accepted'
        then preference.collaborative_list_invitations
      when 'collaborative_list_invitation_declined'
        then preference.collaborative_list_invitations
      when 'collaborative_list_invitation_cancelled'
        then preference.collaborative_list_invitations
      when 'collaborative_list_role_changed'
        then preference.collaborative_list_invitations
      when 'collaborative_list_member_removed'
        then preference.collaborative_list_invitations
      when 'collaborative_list_member_left'
        then preference.collaborative_list_invitations
      when 'collaborative_list_ownership_transferred'
        then preference.collaborative_list_invitations
      when 'collaborative_list_deleted'
        then preference.collaborative_list_invitations
      when 'like' then preference.likes
      when 'comment' then preference.comments
      when 'comment_mention' then preference.comments
      when 'reaction' then preference.reactions
      when 'friend_request' then preference.friend_requests
      when 'friend_request_accepted' then preference.friend_requests
      else false
    end
    from public.notification_preferences preference
    where preference.user_id = p_recipient
  ), true);
$$;

drop function if exists public.set_notification_preferences_v1(
  boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean
);
comment on column public.notification_preferences.shared_mugshot_invitations is
  'Retired compatibility column. Current clients cannot read or update this preference.';

create or replace function public.set_notification_preferences_v1(
  p_push_enabled boolean,
  p_friend_posts boolean,
  p_tags boolean,
  p_collaborative_list_invitations boolean,
  p_likes boolean,
  p_comments boolean,
  p_reactions boolean,
  p_friend_requests boolean
)
returns public.notification_preferences
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result public.notification_preferences;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  insert into public.notification_preferences (
    user_id, push_enabled, friend_posts, tags,
    collaborative_list_invitations, likes, comments, reactions, friend_requests
  ) values (
    actor, p_push_enabled, p_friend_posts, p_tags,
    p_collaborative_list_invitations, p_likes, p_comments,
    p_reactions, p_friend_requests
  )
  on conflict (user_id) do update set
    push_enabled = excluded.push_enabled,
    friend_posts = excluded.friend_posts,
    tags = excluded.tags,
    collaborative_list_invitations = excluded.collaborative_list_invitations,
    likes = excluded.likes,
    comments = excluded.comments,
    reactions = excluded.reactions,
    friend_requests = excluded.friend_requests,
    updated_at = now()
  returning * into result;

  update private.activity_push_deliveries delivery
  set status = 'cancelled', completed_at = now(), updated_at = now(),
      last_error_code = 'preference_disabled'
  from public.activity_events event
  where delivery.activity_event_id = event.id
    and event.recipient_id = actor
    and delivery.status = 'pending'
    and not private.activity_kind_push_enabled(actor, event.kind);
  return result;
end;
$$;

revoke all on function public.set_notification_preferences_v1(
  boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean
) from public, anon, authenticated;
grant execute on function public.set_notification_preferences_v1(
  boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean
) to authenticated;

create or replace function public.build_owner_activity_export_v1()
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
    'notification_preferences', coalesce((
      select jsonb_build_object(
        'push_enabled', preference.push_enabled,
        'friend_posts', preference.friend_posts,
        'tags', preference.tags,
        'collaborative_list_invitations', preference.collaborative_list_invitations,
        'likes', preference.likes,
        'comments', preference.comments,
        'reactions', preference.reactions,
        'friend_requests', preference.friend_requests,
        'updated_at', preference.updated_at
      )
      from public.notification_preferences preference
      where preference.user_id = actor
    ), jsonb_build_object(
      'push_enabled', true,
      'friend_posts', true,
      'tags', true,
      'collaborative_list_invitations', true,
      'likes', true,
      'comments', true,
      'reactions', true,
      'friend_requests', true
    )),
    'activity_events', coalesce((
      select jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
        'event_id', event.id,
        'kind', event.kind,
        'actor_user_id', event.actor_user_id,
        'title', event.title,
        'body', case
          when event.kind = 'tag'
               and not private.can_view_visit_as(event.visit_id, actor) then
            left(coalesce(nullif(btrim(profile.display_name), ''), '@' || profile.username)
              || ' tagged you in a MugShot you can''t view.', 280)
          else event.body
        end,
        'visit_id', case
          when event.kind = 'tag'
               and not private.can_view_visit_as(event.visit_id, actor) then null
          else event.visit_id
        end,
        'comment_id', event.comment_id,
        'cafe_list_id', event.cafe_list_id,
        'friend_request_id', event.friend_request_id,
        'deep_link', case
          when event.kind = 'tag'
               and not private.can_view_visit_as(event.visit_id, actor)
            then 'mugshot://activity'
          else event.deep_link
        end,
        'created_at', event.created_at,
        'read_at', event.read_at
      )) order by event.created_at, event.id)
      from public.activity_events event
      join public.users profile on profile.id = event.actor_user_id
      where event.recipient_id = actor
        and private.activity_event_is_visible(event, actor)
    ), '[]'::jsonb),
    'registered_device_summary', jsonb_build_object(
      'registered_count', (
        select count(*) from public.user_devices device
        where device.user_id = actor and device.device_id is not null
      ),
      'active_count', (
        select count(*) from public.user_devices device
        where device.user_id = actor
          and device.device_id is not null and device.disabled_at is null
      ),
      'platform_environments', coalesce((
        select jsonb_agg(jsonb_build_object(
          'platform', grouped.platform,
          'environment', grouped.environment,
          'count', grouped.device_count
        ) order by grouped.platform, grouped.environment)
        from (
          select device.platform, device.environment, count(*) device_count
          from public.user_devices device
          where device.user_id = actor and device.device_id is not null
          group by device.platform, device.environment
        ) grouped
      ), '[]'::jsonb)
    )
  ) into result;
  return result;
end;
$$;

-- Preserve the mature owner export implementation, but strip retired shared
-- grouping records and replace legacy companion-shaped tag rows.
alter function public.build_owner_data_export_v2()
  rename to build_owner_data_export_with_retired_shared_v2;
alter function public.build_owner_data_export_with_retired_shared_v2()
  set schema private;
revoke all on function private.build_owner_data_export_with_retired_shared_v2()
  from public, anon, authenticated;

create function public.build_owner_data_export_v2()
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result jsonb;
  tags jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  result := private.build_owner_data_export_with_retired_shared_v2();
  result := jsonb_set(
    result,
    '{collaboration}',
    (result -> 'collaboration')
      - 'created_shared_memories'
      - 'managed_shared_memories'
      - 'shared_memory_memberships'
      - 'shared_memory_contributions'
  );
  result := jsonb_set(
    result,
    '{export_manifest,included_collections}',
    (
      select coalesce(jsonb_agg(collection), '[]'::jsonb)
      from jsonb_array_elements(
        result #> '{export_manifest,included_collections}'
      ) collection
      where lower(collection #>> '{}') not like '%shared mugshot%'
    )
  );
  select coalesce(
    jsonb_agg(to_jsonb(tag) order by tag.created_at, tag.visit_id, tag.tagged_user_id),
    '[]'::jsonb
  ) into tags
  from public.visit_tags tag
  where tag.tagged_by = actor or tag.tagged_user_id = actor;
  result := jsonb_set(
    result,
    '{social}',
    ((result -> 'social') - 'visit_tags_added_or_received')
      || jsonb_build_object('visit_tags_added_or_received', tags)
  );
  return result;
end;
$$;

revoke all on function public.build_owner_data_export_v2()
  from public, anon, authenticated;
grant execute on function public.build_owner_data_export_v2()
  to authenticated;

-- Supabase grants new public-schema functions to its API roles through
-- default privileges. Seal the owner-only share-link controls explicitly;
-- anonymous clients retain only the allowlisted public projection and metric
-- endpoint below.
revoke all on function public.create_visit_share_link_v1(uuid)
  from public, anon;
revoke all on function public.get_visit_share_slug_v1(uuid)
  from public, anon;
revoke all on function public.revoke_visit_share_link_v1(uuid)
  from public, anon;
grant execute on function public.create_visit_share_link_v1(uuid)
  to authenticated;
grant execute on function public.get_visit_share_slug_v1(uuid)
  to authenticated;
grant execute on function public.revoke_visit_share_link_v1(uuid)
  to authenticated;

create or replace function public.get_backend_capabilities_v1()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'contract_version', 1,
    'schema_release', '2026-08-04-tag-only-edit-v2',
    'capabilities', jsonb_build_object(
      'taste_passport',
        to_regprocedure('public.get_taste_passport_v1(uuid)') is not null,
      'taste_passport_audience',
        to_regprocedure('public.get_taste_passport_visibility_v1()') is not null
        and to_regprocedure('public.set_taste_passport_visibility_v1(text,uuid)') is not null,
      'independent_recipe_visibility',
        to_regprocedure('public.get_recipe_projection_for_visit_v1(uuid)') is not null
        and to_regprocedure('public.get_recipe_identity_for_visit_v1(uuid)') is not null,
      'visit_tags', true,
      'shared_mugshots', false,
      'public_mugshot_sharing',
        to_regprocedure('public.create_visit_share_link_v1(uuid)') is not null
        and to_regprocedure('public.get_public_mugshot_share_v1(text)') is not null,
      'activity_center',
        to_regprocedure(
          'public.list_activity_events_v1(integer,timestamp with time zone,uuid)'
        ) is not null
        and to_regprocedure('public.activity_unread_count_v1()') is not null,
      'notification_preferences',
        to_regprocedure('public.get_notification_preferences_v1()') is not null,
      'push_registration',
        to_regprocedure('public.register_user_device_v2(uuid,text,text)') is not null,
      'social_safety',
        to_regprocedure(
          'public.submit_report_v2(uuid,public.report_reason,text,uuid,text)'
        ) is not null
        and to_regprocedure('public.block_user_v2(uuid,boolean)') is not null,
      'moderation_transparency',
        to_regprocedure('public.get_my_enforcement_state_v1()') is not null,
      'collaborative_cafe_lists',
        to_regprocedure('public.list_cafe_lists_v2()') is not null
        and to_regprocedure('public.get_cafe_list_v2(uuid)') is not null,
      'account_deletion_v3',
        to_regprocedure(
          'public.begin_account_deletion_step_up_v3(uuid,uuid,uuid,text,text)'
        ) is not null
        and to_regprocedure(
          'public.prepare_account_deletion_v3(uuid,uuid,uuid,text,text,uuid,text)'
        ) is not null
    )
  );
$$;

revoke all on function public.get_backend_capabilities_v1() from public;
grant execute on function public.get_backend_capabilities_v1() to anon, authenticated;

commit;
