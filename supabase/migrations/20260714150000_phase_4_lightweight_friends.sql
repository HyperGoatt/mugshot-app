-- Phase 4 adds small, journal-centered collaboration primitives. All writes
-- are caller-bound RPCs and every read continues to honor blocks, friendship,
-- visit visibility, and explicit list membership.

create table public.cafe_lists (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 80),
  description text check (length(coalesce(description, '')) <= 280),
  visibility text not null default 'private'
    check (visibility in ('private', 'friends', 'invited')),
  system_kind text check (system_kind in ('favorites', 'want_to_try')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (owner_id, system_kind)
);

create table public.cafe_list_members (
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  role text not null check (role in ('editor', 'viewer')),
  invitation_status text not null default 'pending'
    check (invitation_status in ('pending', 'accepted')),
  invited_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  primary key (list_id, user_id)
);

create table public.cafe_list_items (
  id uuid primary key default gen_random_uuid(),
  list_id uuid not null references public.cafe_lists(id) on delete cascade,
  cafe_id uuid not null references public.cafes(id) on delete cascade,
  position integer not null default 0 check (position >= 0),
  contributor_id uuid not null references public.users(id) on delete cascade,
  note text check (length(coalesce(note, '')) <= 280),
  created_at timestamptz not null default now(),
  unique (list_id, cafe_id)
);

create table public.trusted_recommendations (
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references public.users(id) on delete cascade,
  recipient_id uuid not null references public.users(id) on delete cascade,
  target_kind text not null check (target_kind in ('cafe', 'visit', 'recipe')),
  target_cafe_id uuid references public.cafes(id) on delete cascade,
  target_visit_id uuid references public.visits(id) on delete cascade,
  target_recipe_version_id uuid references public.recipe_versions(id) on delete cascade,
  note text check (length(coalesce(note, '')) <= 280),
  status text not null default 'sent' check (status in ('sent', 'seen', 'saved', 'dismissed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (sender_id <> recipient_id),
  check (
    (target_kind = 'cafe' and target_cafe_id is not null and target_visit_id is null and target_recipe_version_id is null)
    or (target_kind = 'visit' and target_cafe_id is null and target_visit_id is not null and target_recipe_version_id is null)
    or (target_kind = 'recipe' and target_cafe_id is null and target_visit_id is null and target_recipe_version_id is not null)
  )
);

create table public.visit_reactions (
  visit_id uuid not null references public.visits(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  reaction text not null check (reaction in ('want_to_try', 'great_find', 'dialed_in', 'cozy')),
  created_at timestamptz not null default now(),
  primary key (visit_id, user_id)
);

create index cafe_lists_owner_updated_idx on public.cafe_lists(owner_id, updated_at desc);
create index cafe_list_members_user_status_idx on public.cafe_list_members(user_id, invitation_status, created_at desc);
create index cafe_list_items_list_position_idx on public.cafe_list_items(list_id, position, created_at, id);
create index trusted_recommendations_recipient_idx on public.trusted_recommendations(recipient_id, status, created_at desc);
create index trusted_recommendations_sender_idx on public.trusted_recommendations(sender_id, created_at desc);
create index visit_reactions_visit_reaction_idx on public.visit_reactions(visit_id, reaction);

alter table public.cafe_lists enable row level security;
alter table public.cafe_list_members enable row level security;
alter table public.cafe_list_items enable row level security;
alter table public.trusted_recommendations enable row level security;
alter table public.visit_reactions enable row level security;

create or replace function private.can_view_cafe_list_as(p_list_id uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.cafe_lists l
    where l.id = p_list_id
      and not private.blocked_between(p_viewer, l.owner_id)
      and (
        l.owner_id = p_viewer
        or exists (
          select 1 from public.cafe_list_members m
          where m.list_id = l.id and m.user_id = p_viewer and m.invitation_status = 'accepted'
        )
        or (l.visibility = 'friends' and private.confirmed_friends(p_viewer, l.owner_id))
      )
  );
$$;

create or replace function private.can_edit_cafe_list_as(p_list_id uuid, p_actor uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.cafe_lists l
    where l.id = p_list_id
      and not private.blocked_between(p_actor, l.owner_id)
      and (
        l.owner_id = p_actor
        or exists (
          select 1 from public.cafe_list_members m
          where m.list_id = l.id and m.user_id = p_actor
            and m.role = 'editor' and m.invitation_status = 'accepted'
        )
      )
  );
$$;

revoke all on function private.can_view_cafe_list_as(uuid, uuid) from public, anon, authenticated;
revoke all on function private.can_edit_cafe_list_as(uuid, uuid) from public, anon, authenticated;

create policy "Visible cafe lists" on public.cafe_lists for select to authenticated
  using (private.can_view_cafe_list_as(id, (select auth.uid())));
create policy "Visible cafe list memberships" on public.cafe_list_members for select to authenticated
  using (
    user_id = (select auth.uid())
    or private.can_view_cafe_list_as(list_id, (select auth.uid()))
  );
create policy "Visible cafe list items" on public.cafe_list_items for select to authenticated
  using (private.can_view_cafe_list_as(list_id, (select auth.uid())));
create policy "Recommendation participants read" on public.trusted_recommendations for select to authenticated
  using (
    (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()))
    and not private.blocked_between(sender_id, recipient_id)
  );
create policy "Visible visit reactions" on public.visit_reactions for select to authenticated
  using (
    private.can_view_visit_as(visit_id, (select auth.uid()))
    and not private.blocked_between(user_id, (select auth.uid()))
  );

-- A recipe is visible only to its owner or to the recipient of an explicit,
-- active recommendation for that exact immutable version. Security-definer
-- helpers avoid recursive RLS evaluation between identities and versions.
create or replace function private.can_view_recipe_identity_as(p_identity_id uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.recipe_identities identity
    where identity.id = p_identity_id
      and (
        identity.user_id = p_viewer
        or exists (
          select 1
          from public.recipe_versions version
          join public.trusted_recommendations recommendation
            on recommendation.target_recipe_version_id = version.id
          where version.recipe_identity_id = identity.id
            and recommendation.target_kind = 'recipe'
            and recommendation.recipient_id = p_viewer
            and recommendation.status <> 'dismissed'
            and not private.blocked_between(recommendation.sender_id, recommendation.recipient_id)
        )
      )
  );
$$;

create or replace function private.can_view_recipe_version_as(p_version_id uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.recipe_versions version
    join public.recipe_identities identity on identity.id = version.recipe_identity_id
    where version.id = p_version_id
      and (
        identity.user_id = p_viewer
        or exists (
          select 1 from public.trusted_recommendations recommendation
          where recommendation.target_recipe_version_id = version.id
            and recommendation.target_kind = 'recipe'
            and recommendation.recipient_id = p_viewer
            and recommendation.status <> 'dismissed'
            and not private.blocked_between(recommendation.sender_id, recommendation.recipient_id)
        )
      )
  );
$$;
revoke all on function private.can_view_recipe_identity_as(uuid, uuid) from public, anon, authenticated;
revoke all on function private.can_view_recipe_version_as(uuid, uuid) from public, anon, authenticated;

drop policy if exists "Owners manage recipe identities" on public.recipe_identities;
create policy "Owners manage recipe identities" on public.recipe_identities for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Recipients read explicitly shared recipe identities" on public.recipe_identities for select to authenticated
  using (private.can_view_recipe_identity_as(id, (select auth.uid())));

drop policy if exists "Owners read recipe versions" on public.recipe_versions;
create policy "Owners read recipe versions" on public.recipe_versions for select to authenticated
  using (private.can_view_recipe_version_as(id, (select auth.uid())));
create policy "Recipients read explicitly shared recipe versions" on public.recipe_versions for select to authenticated
  using (private.can_view_recipe_version_as(id, (select auth.uid())));

revoke all on public.cafe_lists, public.cafe_list_members, public.cafe_list_items,
  public.trusted_recommendations, public.visit_reactions from public, anon;
grant select on public.cafe_lists, public.cafe_list_members, public.cafe_list_items,
  public.trusted_recommendations, public.visit_reactions to authenticated;

create or replace function public.create_cafe_list(
  p_title text,
  p_description text default null,
  p_visibility text default 'private'
) returns public.cafe_lists language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.cafe_lists;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if length(trim(coalesce(p_title, ''))) not between 1 and 80 then
    raise exception 'list title is required' using errcode = '22023';
  end if;
  if p_visibility not in ('private', 'friends', 'invited') then
    raise exception 'invalid list visibility' using errcode = '22023';
  end if;
  insert into public.cafe_lists(owner_id, title, description, visibility)
  values(actor, trim(p_title), nullif(trim(p_description), ''), p_visibility)
  returning * into result;
  return result;
end; $$;

create or replace function public.invite_cafe_list_member(
  p_list_id uuid, p_user_id uuid, p_role text default 'viewer'
) returns public.cafe_list_members language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.cafe_list_members; owner uuid;
begin
  select owner_id into owner from public.cafe_lists where id = p_list_id;
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if owner <> actor then raise exception 'only the list owner can invite' using errcode = '42501'; end if;
  if p_role not in ('editor', 'viewer') or p_user_id = actor
     or not private.confirmed_friends(actor, p_user_id) then
    raise exception 'friend unavailable' using errcode = '42501';
  end if;
  insert into public.cafe_list_members(list_id, user_id, role, invited_by)
  values(p_list_id, p_user_id, p_role, actor)
  on conflict(list_id, user_id) do update
    set role = excluded.role, invitation_status = 'pending', invited_by = actor,
        accepted_at = null, created_at = now()
  returning * into result;
  return result;
end; $$;

create or replace function public.respond_cafe_list_invitation(p_list_id uuid, p_accept boolean)
returns boolean language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid();
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_accept then
    update public.cafe_list_members set invitation_status = 'accepted', accepted_at = now()
      where list_id = p_list_id and user_id = actor and invitation_status = 'pending';
    if not found then raise exception 'invitation unavailable' using errcode = '42501'; end if;
  else
    delete from public.cafe_list_members
      where list_id = p_list_id and user_id = actor and invitation_status = 'pending';
    if not found then raise exception 'invitation unavailable' using errcode = '42501'; end if;
  end if;
  return p_accept;
end; $$;

create or replace function public.revoke_cafe_list_member(p_list_id uuid, p_user_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); owner uuid;
begin
  select owner_id into owner from public.cafe_lists where id = p_list_id;
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if actor <> owner and actor <> p_user_id then raise exception 'not permitted' using errcode = '42501'; end if;
  delete from public.cafe_list_members where list_id = p_list_id and user_id = p_user_id;
end; $$;

create or replace function public.add_cafe_list_item(
  p_list_id uuid, p_cafe_id uuid, p_note text default null
) returns public.cafe_list_items language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.cafe_list_items; next_position integer;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.can_edit_cafe_list_as(p_list_id, actor) then
    raise exception 'list unavailable' using errcode = '42501';
  end if;
  select coalesce(max(position), -1) + 1 into next_position
    from public.cafe_list_items where list_id = p_list_id;
  insert into public.cafe_list_items(list_id, cafe_id, position, contributor_id, note)
  values(p_list_id, p_cafe_id, next_position, actor, nullif(trim(p_note), ''))
  on conflict(list_id, cafe_id) do update set note = excluded.note
  returning * into result;
  update public.cafe_lists set updated_at = now() where id = p_list_id;
  return result;
end; $$;

create or replace function public.remove_cafe_list_item(p_item_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); target_list uuid;
begin
  select list_id into target_list from public.cafe_list_items where id = p_item_id;
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.can_edit_cafe_list_as(target_list, actor) then
    raise exception 'list unavailable' using errcode = '42501';
  end if;
  delete from public.cafe_list_items where id = p_item_id;
  update public.cafe_lists set updated_at = now() where id = target_list;
end; $$;

create or replace function public.send_trusted_recommendation(
  p_recipient_id uuid,
  p_target_kind text,
  p_target_id uuid,
  p_note text default null
) returns public.trusted_recommendations language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.trusted_recommendations;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.confirmed_friends(actor, p_recipient_id) then
    raise exception 'friend unavailable' using errcode = '42501';
  end if;
  if p_target_kind = 'cafe' and not exists(select 1 from public.cafes where id = p_target_id) then
    raise exception 'cafe unavailable' using errcode = '42501';
  elsif p_target_kind = 'visit' and (
    not private.can_view_visit_as(p_target_id, actor)
    or not private.can_view_visit_as(p_target_id, p_recipient_id)
  ) then raise exception 'sip unavailable' using errcode = '42501';
  elsif p_target_kind = 'recipe' and not exists(
    select 1 from public.recipe_versions version
    join public.recipe_identities identity on identity.id = version.recipe_identity_id
    where version.id = p_target_id and identity.user_id = actor
  ) then raise exception 'recipe unavailable' using errcode = '42501';
  elsif p_target_kind not in ('cafe', 'visit', 'recipe') then
    raise exception 'invalid recommendation type' using errcode = '22023';
  end if;

  insert into public.trusted_recommendations(
    sender_id, recipient_id, target_kind, target_cafe_id, target_visit_id,
    target_recipe_version_id, note
  ) values (
    actor, p_recipient_id, p_target_kind,
    case when p_target_kind = 'cafe' then p_target_id end,
    case when p_target_kind = 'visit' then p_target_id end,
    case when p_target_kind = 'recipe' then p_target_id end,
    nullif(trim(p_note), '')
  ) returning * into result;
  return result;
end; $$;

create or replace function public.update_trusted_recommendation(
  p_recommendation_id uuid, p_status text
) returns public.trusted_recommendations language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result public.trusted_recommendations;
begin
  if p_status not in ('seen', 'saved', 'dismissed') then
    raise exception 'invalid recommendation status' using errcode = '22023';
  end if;
  update public.trusted_recommendations
    set status = p_status, updated_at = now()
    where id = p_recommendation_id and recipient_id = actor
    returning * into result;
  if not found then raise exception 'recommendation unavailable' using errcode = '42501'; end if;
  return result;
end; $$;

create or replace function public.toggle_visit_reaction(p_visit_id uuid, p_reaction text)
returns text language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); existing text;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_reaction not in ('want_to_try', 'great_find', 'dialed_in', 'cozy') then
    raise exception 'invalid reaction' using errcode = '22023';
  end if;
  if not private.can_view_visit_as(p_visit_id, actor) then
    raise exception 'sip unavailable' using errcode = '42501';
  end if;
  select reaction into existing from public.visit_reactions
    where visit_id = p_visit_id and user_id = actor;
  if existing = p_reaction then
    delete from public.visit_reactions where visit_id = p_visit_id and user_id = actor;
    return null;
  end if;
  insert into public.visit_reactions(visit_id, user_id, reaction)
  values(p_visit_id, actor, p_reaction)
  on conflict(visit_id, user_id) do update set reaction = excluded.reaction, created_at = now();
  return p_reaction;
end; $$;

create or replace function public.friend_compatibility(p_friend_id uuid)
returns table(
  evidence_level text,
  shared_signal_count integer,
  shared_attributes text[],
  explanation text
) language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := auth.uid(); shared text[]; count_shared integer;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.confirmed_friends(actor, p_friend_id) then
    raise exception 'friend unavailable' using errcode = '42501';
  end if;
  select array_agg(replace(a.attribute, '_', ' ') order by least(a.support_count, b.support_count) desc, a.attribute), count(*)
    into shared, count_shared
  from public.taste_signals a
  join public.taste_signals b on b.user_id = p_friend_id
    and b.signal_type = a.signal_type and b.attribute = a.attribute
  where a.user_id = actor
    and a.support_count >= 3 and b.support_count >= 3
    and a.owner_state = 'active' and b.owner_state = 'active';
  count_shared := coalesce(count_shared, 0);
  return query select
    case when count_shared >= 4 then 'strong_overlap'
         when count_shared >= 2 then 'some_overlap'
         else 'still_learning' end,
    count_shared,
    coalesce(shared[1:3], '{}'::text[]),
    case when count_shared >= 4 then 'Several journal patterns overlap.'
         when count_shared >= 2 then 'A few journal patterns overlap.'
         else 'Mugshot needs more shared journal evidence.' end;
end; $$;

revoke all on function public.create_cafe_list(text,text,text) from public, anon;
revoke all on function public.invite_cafe_list_member(uuid,uuid,text) from public, anon;
revoke all on function public.respond_cafe_list_invitation(uuid,boolean) from public, anon;
revoke all on function public.revoke_cafe_list_member(uuid,uuid) from public, anon;
revoke all on function public.add_cafe_list_item(uuid,uuid,text) from public, anon;
revoke all on function public.remove_cafe_list_item(uuid) from public, anon;
revoke all on function public.send_trusted_recommendation(uuid,text,uuid,text) from public, anon;
revoke all on function public.update_trusted_recommendation(uuid,text) from public, anon;
revoke all on function public.toggle_visit_reaction(uuid,text) from public, anon;
revoke all on function public.friend_compatibility(uuid) from public, anon;
grant execute on function public.create_cafe_list(text,text,text) to authenticated;
grant execute on function public.invite_cafe_list_member(uuid,uuid,text) to authenticated;
grant execute on function public.respond_cafe_list_invitation(uuid,boolean) to authenticated;
grant execute on function public.revoke_cafe_list_member(uuid,uuid) to authenticated;
grant execute on function public.add_cafe_list_item(uuid,uuid,text) to authenticated;
grant execute on function public.remove_cafe_list_item(uuid) to authenticated;
grant execute on function public.send_trusted_recommendation(uuid,text,uuid,text) to authenticated;
grant execute on function public.update_trusted_recommendation(uuid,text) to authenticated;
grant execute on function public.toggle_visit_reaction(uuid,text) to authenticated;
grant execute on function public.friend_compatibility(uuid) to authenticated;
