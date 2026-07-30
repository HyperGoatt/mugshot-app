begin;

-- Collaborative cafe lists remain row-preserving. This migration extends the
-- invitation lifecycle, closes raw collaborator-identity reads, and exposes
-- caller-bound hydrated projections for the alpha client.

alter table public.cafe_list_members
  drop constraint if exists cafe_list_members_invitation_status_check;

alter table public.cafe_list_members
  add constraint cafe_list_members_invitation_status_check
  check (invitation_status in ('pending', 'accepted', 'declined', 'cancelled'));

alter table public.cafe_list_members
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists responded_at timestamptz;

update public.cafe_list_members
set
  updated_at = coalesce(accepted_at, created_at),
  responded_at = case
    when invitation_status = 'accepted' then accepted_at
    else responded_at
  end;

create index if not exists cafe_list_members_list_status_role_idx
  on public.cafe_list_members (list_id, invitation_status, role, created_at, user_id);

-- Pending invitations may see decision metadata, while cafe contents require
-- accepted membership (or the existing owner/friends visibility contract).
create or replace function private.can_view_cafe_list_as(
  p_list_id uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not null and exists (
    select 1
    from public.cafe_lists list
    where list.id = p_list_id
      and (
        list.owner_id is null
        or not private.blocked_between(p_viewer, list.owner_id)
      )
      and (
        list.owner_id = p_viewer
        or exists (
          select 1
          from public.cafe_list_members member
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
  );
$$;

create or replace function private.can_view_cafe_list_items_as(
  p_list_id uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not null and exists (
    select 1
    from public.cafe_lists list
    where list.id = p_list_id
      and (
        list.owner_id is null
        or not private.blocked_between(p_viewer, list.owner_id)
      )
      and (
        list.owner_id = p_viewer
        or exists (
          select 1
          from public.cafe_list_members member
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
  );
$$;

create or replace function private.can_edit_cafe_list_as(
  p_list_id uuid,
  p_actor uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_actor is not null
    and private.can_socially_mutate_as(p_actor)
    and exists (
      select 1
      from public.cafe_lists list
      where list.id = p_list_id
        and (
          list.owner_id is null
          or not private.blocked_between(p_actor, list.owner_id)
        )
        and (
          list.owner_id = p_actor
          or (
            list.owner_id is not null
            and private.can_view_user_as(list.owner_id, p_actor)
            and exists (
            select 1
            from public.cafe_list_members member
            where member.list_id = list.id
              and member.user_id = p_actor
              and member.role = 'editor'
              and member.invitation_status = 'accepted'
            )
          )
        )
    );
$$;

create or replace function private.can_manage_cafe_list_as(
  p_list_id uuid,
  p_actor uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_actor is not null
    and private.can_socially_mutate_as(p_actor)
    and exists (
      select 1
      from public.cafe_lists list
      where list.id = p_list_id
        and list.owner_id = p_actor
        and list.system_kind is null
    );
$$;

revoke all on function private.can_view_cafe_list_as(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_cafe_list_items_as(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.can_edit_cafe_list_as(uuid, uuid)
  from public, anon, authenticated;
revoke all on function private.can_manage_cafe_list_as(uuid, uuid)
  from public, anon, authenticated;

-- A blocked or unavailable collaborator keeps durable list provenance, but
-- their stable identifier and profile fields are not returned to that viewer.
create or replace function private.cafe_list_profile_json_v2(
  p_subject uuid,
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
  if p_subject is null then
    return jsonb_build_object('identity_state', 'departed');
  end if;

  if p_subject <> p_viewer
     and (
       private.blocked_between(p_subject, p_viewer)
       or not private.can_view_user_as(p_subject, p_viewer)
     ) then
    return jsonb_build_object('identity_state', 'hidden');
  end if;

  select jsonb_build_object(
    'identity_state', 'visible',
    'user_id', profile.id,
    'display_name', profile.display_name,
    'username', profile.username,
    'avatar_url', profile.avatar_url
  )
  into result
  from public.users profile
  where profile.id = p_subject;

  return coalesce(result, jsonb_build_object('identity_state', 'departed'));
end;
$$;

revoke all on function private.cafe_list_profile_json_v2(uuid, uuid)
  from public, anon, authenticated;

create or replace function private.cafe_list_summary_json_v2(
  p_list_id uuid,
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
  if p_viewer is null
     or not private.can_view_cafe_list_as(p_list_id, p_viewer) then
    return null;
  end if;

  select jsonb_build_object(
    'id', list.id,
    'title', case
      when current_member.invitation_status = 'pending'
       and list.owner_id is not null
       and not private.can_view_user_as(list.owner_id, p_viewer)
        then 'Unavailable cafe list invitation'
      else list.title
    end,
    'description', case
      when current_member.invitation_status = 'pending'
       and list.owner_id is not null
       and not private.can_view_user_as(list.owner_id, p_viewer)
        then null
      else list.description
    end,
    'visibility', list.visibility,
    'system_kind', list.system_kind,
    'created_at', list.created_at,
    'updated_at', list.updated_at,
    'owner', private.cafe_list_profile_json_v2(list.owner_id, p_viewer),
    'access_kind', case
      when list.owner_id = p_viewer then 'owner'
      when current_member.invitation_status = 'pending' then 'pending_invitation'
      when current_member.invitation_status = 'accepted' then 'member'
      when list.visibility = 'friends' then 'friend_viewer'
      else 'viewer'
    end,
    'current_role', case
      when list.owner_id = p_viewer then 'owner'
      when current_member.invitation_status = 'accepted' then current_member.role
      else 'viewer'
    end,
    'invited_role', case
      when current_member.invitation_status = 'pending' then current_member.role
      else null
    end,
    'invitation_status', current_member.invitation_status,
    'inviter', case
      when current_member.invitation_status is not null
        then private.cafe_list_profile_json_v2(current_member.invited_by, p_viewer)
      else null
    end,
    'can_view_items', private.can_view_cafe_list_items_as(list.id, p_viewer),
    'can_edit_items', private.can_edit_cafe_list_as(list.id, p_viewer),
    'can_manage', private.can_manage_cafe_list_as(list.id, p_viewer),
    'can_leave', coalesce(current_member.invitation_status = 'accepted', false),
    'can_delete', private.can_manage_cafe_list_as(list.id, p_viewer),
    'can_transfer', private.can_manage_cafe_list_as(list.id, p_viewer) and exists (
      select 1
      from public.cafe_list_members accepted
      where accepted.list_id = list.id
        and accepted.invitation_status = 'accepted'
        and not private.blocked_between(p_viewer, accepted.user_id)
    ),
    'social_actions_available', private.can_socially_mutate_as(p_viewer),
    'cafe_count', case
      when current_member.invitation_status = 'pending'
       and list.owner_id is not null
       and not private.can_view_user_as(list.owner_id, p_viewer)
        then 0
      else (
        select count(*)
        from public.cafe_list_items item
        where item.list_id = list.id
      )
    end,
    'collaborator_count', case
      when current_member.invitation_status = 'pending'
       and list.owner_id is not null
       and not private.can_view_user_as(list.owner_id, p_viewer)
        then 0
      else (
        select count(*)
        from public.cafe_list_members member
        where member.list_id = list.id
          and member.invitation_status = 'accepted'
      )
    end,
    'pending_count', case
      when list.owner_id = p_viewer then (
        select count(*)
        from public.cafe_list_members member
        where member.list_id = list.id
          and member.invitation_status = 'pending'
      )
      else 0
    end,
    'preview_photo_url', case
      when private.can_view_cafe_list_items_as(list.id, p_viewer) then (
        select visit.poster_photo_url
        from public.cafe_list_items item
        join public.visits visit on visit.cafe_id = item.cafe_id
        where item.list_id = list.id
          and nullif(btrim(visit.poster_photo_url), '') is not null
          and private.can_view_visit_as(visit.id, p_viewer)
        order by
          (visit.user_id = p_viewer) desc,
          visit.created_at desc,
          visit.id desc
        limit 1
      )
      else null
    end,
    'preview_address', case
      when private.can_view_cafe_list_items_as(list.id, p_viewer) then (
        select coalesce(nullif(btrim(cafe.address), ''), nullif(btrim(cafe.city), ''))
        from public.cafe_list_items item
        join public.cafes cafe on cafe.id = item.cafe_id
        where item.list_id = list.id
        order by item.position, item.created_at, item.id
        limit 1
      )
      else null
    end
  )
  into result
  from public.cafe_lists list
  left join public.cafe_list_members current_member
    on current_member.list_id = list.id
   and current_member.user_id = p_viewer
   and current_member.invitation_status in ('pending', 'accepted')
  where list.id = p_list_id;

  return result;
end;
$$;

revoke all on function private.cafe_list_summary_json_v2(uuid, uuid)
  from public, anon, authenticated;

create or replace function public.list_cafe_lists_v2()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with viewer as (
    select auth.uid() id
  )
  select case
    when viewer.id is null then '[]'::jsonb
    else coalesce((
      select jsonb_agg(
        private.cafe_list_summary_json_v2(list.id, viewer.id)
        order by
          case when member.invitation_status = 'pending' then 0 else 1 end,
          list.updated_at desc,
          list.id desc
      )
      from public.cafe_lists list
      left join public.cafe_list_members member
        on member.list_id = list.id
       and member.user_id = viewer.id
       and member.invitation_status in ('pending', 'accepted')
      where list.system_kind is null
        and private.can_view_cafe_list_as(list.id, viewer.id)
    ), '[]'::jsonb)
  end
  from viewer;
$$;

create or replace function public.get_cafe_list_v2(p_list_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  summary jsonb;
  item_rows jsonb := '[]'::jsonb;
  member_rows jsonb := '[]'::jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  summary := private.cafe_list_summary_json_v2(p_list_id, actor);
  if summary is null then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  if private.can_view_cafe_list_items_as(p_list_id, actor) then
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', item.id,
      'list_id', item.list_id,
      'cafe_id', cafe.id,
      'position', item.position,
      'note', item.note,
      'created_at', item.created_at,
      'cafe_name', cafe.name,
      'cafe_address', cafe.address,
      'cafe_city', cafe.city,
      'latitude', cafe.latitude,
      'longitude', cafe.longitude,
      'apple_place_id', cafe.apple_place_id,
      'website_url', cafe.website_url,
      'photo_url', photo.poster_photo_url,
      'is_favorite', coalesce(saved.is_favorite, false),
      'want_to_try', coalesce(saved.want_to_try, false),
      'saved_state', case
        when coalesce(saved.is_favorite, false) and coalesce(saved.want_to_try, false) then 'favorite_and_want_to_try'
        when coalesce(saved.is_favorite, false) then 'favorite'
        when coalesce(saved.want_to_try, false) then 'want_to_try'
        else 'none'
      end,
      'contributor', private.cafe_list_profile_json_v2(item.contributor_id, actor)
    ) order by item.position, item.created_at, item.id), '[]'::jsonb)
    into item_rows
    from public.cafe_list_items item
    join public.cafes cafe on cafe.id = item.cafe_id
    left join public.user_cafe_states saved
      on saved.user_id = actor and saved.cafe_id = item.cafe_id
    left join lateral (
      select visit.poster_photo_url
      from public.visits visit
      where visit.cafe_id = item.cafe_id
        and nullif(btrim(visit.poster_photo_url), '') is not null
        and private.can_view_visit_as(visit.id, actor)
      order by
        (visit.user_id = actor) desc,
        visit.created_at desc,
        visit.id desc
      limit 1
    ) photo on true
    where item.list_id = p_list_id;
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'role', member.role,
    'invitation_status', member.invitation_status,
    'created_at', member.created_at,
    'updated_at', member.updated_at,
    'accepted_at', member.accepted_at,
    'responded_at', member.responded_at,
    'person', private.cafe_list_profile_json_v2(member.user_id, actor),
    'inviter', private.cafe_list_profile_json_v2(member.invited_by, actor),
    'can_change_role', list.owner_id = actor
      and member.user_id <> actor
      and member.invitation_status in ('pending', 'accepted')
      and private.can_manage_cafe_list_as(list.id, actor),
    'can_remove', list.owner_id = actor
      and member.user_id <> actor
      and member.invitation_status in ('pending', 'accepted')
      and private.can_manage_cafe_list_as(list.id, actor)
  ) order by
    case member.invitation_status when 'accepted' then 0 when 'pending' then 1 else 2 end,
    coalesce(member.accepted_at, member.created_at),
    member.user_id), '[]'::jsonb)
  into member_rows
  from public.cafe_list_members member
  join public.cafe_lists list on list.id = member.list_id
  where member.list_id = p_list_id
    and (
      (list.owner_id = actor and member.invitation_status in ('pending', 'accepted'))
      or member.invitation_status = 'accepted'
      or (member.user_id = actor and member.invitation_status = 'pending')
    );

  return summary || jsonb_build_object(
    'items', item_rows,
    'members', member_rows
  );
end;
$$;

-- Legacy create/invite/respond/add/move functions keep their signatures so a
-- staged app rollout does not rewrite or discard existing rows. Their updated
-- implementations add enforcement and idempotent invitation behavior.
create or replace function public.create_cafe_list(
  p_title text,
  p_description text default null,
  p_visibility text default 'private'
)
returns public.cafe_lists
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result public.cafe_lists;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 1 and 80 then
    raise exception 'list title is required' using errcode = '22023';
  end if;
  if char_length(coalesce(p_description, '')) > 280 then
    raise exception 'list description is too long' using errcode = '22023';
  end if;
  if p_visibility not in ('private', 'friends', 'invited') then
    raise exception 'invalid list visibility' using errcode = '22023';
  end if;

  insert into public.cafe_lists (owner_id, title, description, visibility)
  values (
    actor,
    btrim(p_title),
    nullif(btrim(p_description), ''),
    p_visibility
  )
  returning * into result;
  return result;
end;
$$;

create or replace function public.create_cafe_list_v2(
  p_title text,
  p_description text default null,
  p_visibility text default 'private'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  created public.cafe_lists;
begin
  created := public.create_cafe_list(p_title, p_description, p_visibility);
  return public.get_cafe_list_v2(created.id);
end;
$$;

create or replace function public.update_cafe_list_v2(
  p_list_id uuid,
  p_title text,
  p_description text,
  p_visibility text
)
returns jsonb
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
  perform 1 from public.cafe_lists where id = p_list_id for update;
  if not found or not private.can_manage_cafe_list_as(p_list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;
  if char_length(btrim(coalesce(p_title, ''))) not between 1 and 80 then
    raise exception 'list title is required' using errcode = '22023';
  end if;
  if char_length(coalesce(p_description, '')) > 280 then
    raise exception 'list description is too long' using errcode = '22023';
  end if;
  if p_visibility not in ('private', 'friends', 'invited') then
    raise exception 'invalid list visibility' using errcode = '22023';
  end if;

  update public.cafe_lists
  set
    title = btrim(p_title),
    description = nullif(btrim(p_description), ''),
    visibility = p_visibility,
    updated_at = now()
  where id = p_list_id;

  return public.get_cafe_list_v2(p_list_id);
end;
$$;

create or replace function public.invite_cafe_list_member(
  p_list_id uuid,
  p_user_id uuid,
  p_role text default 'viewer'
)
returns public.cafe_list_members
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result public.cafe_list_members;
  target_list public.cafe_lists;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select * into target_list
  from public.cafe_lists
  where id = p_list_id
  for update;
  if not found or target_list.owner_id <> actor or target_list.system_kind is not null
     or not private.can_socially_mutate_as(actor) then
    raise exception 'only the list owner can invite' using errcode = '42501';
  end if;
  if p_role not in ('editor', 'viewer')
     or p_user_id is null
     or p_user_id = actor
     or not private.confirmed_friends(actor, p_user_id)
     or private.blocked_between(actor, p_user_id)
     or not private.can_view_user_as(p_user_id, actor) then
    raise exception 'friend unavailable' using errcode = '42501';
  end if;

  select * into result
  from public.cafe_list_members member
  where member.list_id = p_list_id and member.user_id = p_user_id
  for update;

  if not found then
    insert into public.cafe_list_members (
      list_id, user_id, role, invitation_status, invited_by,
      created_at, updated_at, accepted_at, responded_at
    ) values (
      p_list_id, p_user_id, p_role, 'pending', actor,
      now(), now(), null, null
    )
    returning * into result;
  elsif result.invitation_status = 'pending' then
    if result.role is distinct from p_role then
      update public.cafe_list_members
      set role = p_role, updated_at = now()
      where list_id = p_list_id and user_id = p_user_id
      returning * into result;
    end if;
  elsif result.invitation_status = 'accepted' then
    return result;
  else
    update public.cafe_list_members
    set
      role = p_role,
      invitation_status = 'pending',
      invited_by = actor,
      created_at = now(),
      updated_at = now(),
      accepted_at = null,
      responded_at = null
    where list_id = p_list_id and user_id = p_user_id
    returning * into result;
  end if;

  return result;
end;
$$;

create or replace function public.respond_cafe_list_invitation_v2(
  p_list_id uuid,
  p_response text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result public.cafe_list_members;
  list_owner_id uuid;
  target_status text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_response not in ('accept', 'decline') then
    raise exception 'invalid invitation response' using errcode = '22023';
  end if;
  target_status := case when p_response = 'accept' then 'accepted' else 'declined' end;

  select * into result
  from public.cafe_list_members member
  where member.list_id = p_list_id and member.user_id = actor
  for update;

  if not found then
    raise exception 'invitation unavailable' using errcode = '42501';
  end if;
  if result.invitation_status = target_status then
    return jsonb_build_object(
      'list_id', result.list_id,
      'status', result.invitation_status,
      'role', result.role
    );
  end if;
  if result.invitation_status <> 'pending' then
    raise exception 'invitation unavailable' using errcode = '42501';
  end if;

  if p_response = 'accept' then
    select list.owner_id into list_owner_id
    from public.cafe_lists list
    where list.id = p_list_id;
    if list_owner_id is null
       or private.blocked_between(actor, list_owner_id)
       or not private.can_socially_mutate_as(actor) then
      raise exception 'invitation unavailable' using errcode = '42501';
    end if;
  end if;

  update public.cafe_list_members
  set
    invitation_status = target_status,
    accepted_at = case when target_status = 'accepted' then now() else null end,
    responded_at = now(),
    updated_at = now()
  where list_id = p_list_id and user_id = actor
  returning * into result;

  return jsonb_build_object(
    'list_id', result.list_id,
    'status', result.invitation_status,
    'role', result.role
  );
end;
$$;

create or replace function public.respond_cafe_list_invitation(
  p_list_id uuid,
  p_accept boolean
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.respond_cafe_list_invitation_v2(
    p_list_id,
    case when p_accept then 'accept' else 'decline' end
  );
  return p_accept;
end;
$$;

create or replace function public.cancel_cafe_list_invitation_v2(
  p_list_id uuid,
  p_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  existing_status text;
  list_owner uuid;
  list_system_kind text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select owner_id, system_kind into list_owner, list_system_kind
  from public.cafe_lists where id = p_list_id for update;
  if not found
     or list_owner is distinct from actor
     or list_system_kind is not null then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  select invitation_status into existing_status
  from public.cafe_list_members
  where list_id = p_list_id and user_id = p_user_id
  for update;

  if existing_status = 'cancelled' then return true; end if;
  if existing_status is distinct from 'pending' then
    raise exception 'pending invitation unavailable' using errcode = '42501';
  end if;

  update public.cafe_list_members
  set invitation_status = 'cancelled', responded_at = now(), updated_at = now()
  where list_id = p_list_id and user_id = p_user_id;
  return true;
end;
$$;

create or replace function public.set_cafe_list_member_role_v2(
  p_list_id uuid,
  p_user_id uuid,
  p_role text
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
  if p_role not in ('editor', 'viewer') then
    raise exception 'invalid collaborator role' using errcode = '22023';
  end if;
  perform 1 from public.cafe_lists where id = p_list_id for update;
  if not found or not private.can_manage_cafe_list_as(p_list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  update public.cafe_list_members
  set role = p_role, updated_at = now()
  where list_id = p_list_id
    and user_id = p_user_id
    and invitation_status in ('pending', 'accepted');
  if not found then
    raise exception 'collaborator unavailable' using errcode = '42501';
  end if;
  return true;
end;
$$;

create or replace function public.remove_cafe_list_member_v2(
  p_list_id uuid,
  p_user_id uuid
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
  perform 1 from public.cafe_lists where id = p_list_id for update;
  if not found or not private.can_manage_cafe_list_as(p_list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  delete from public.cafe_list_members
  where list_id = p_list_id and user_id = p_user_id;
  return true;
end;
$$;

create or replace function public.leave_cafe_list_v2(p_list_id uuid)
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
  if exists (
    select 1 from public.cafe_lists where id = p_list_id and owner_id = actor
  ) then
    raise exception 'transfer or delete this cafe list instead' using errcode = '42501';
  end if;

  delete from public.cafe_list_members
  where list_id = p_list_id
    and user_id = actor
    and invitation_status = 'accepted';
  return true;
end;
$$;

create or replace function public.revoke_cafe_list_member(
  p_list_id uuid,
  p_user_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  owner_id uuid;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select list.owner_id into owner_id
  from public.cafe_lists list
  where list.id = p_list_id;

  if owner_id = actor then
    perform public.remove_cafe_list_member_v2(p_list_id, p_user_id);
  elsif actor = p_user_id then
    delete from public.cafe_list_members
    where list_id = p_list_id and user_id = actor;
  else
    raise exception 'not permitted' using errcode = '42501';
  end if;
end;
$$;

create or replace function public.add_cafe_list_item(
  p_list_id uuid,
  p_cafe_id uuid,
  p_note text default null
)
returns public.cafe_list_items
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  result public.cafe_list_items;
  next_position integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if char_length(coalesce(p_note, '')) > 280 then
    raise exception 'cafe note is too long' using errcode = '22023';
  end if;
  perform 1 from public.cafe_lists where id = p_list_id for update;
  if not found or not private.can_edit_cafe_list_as(p_list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;
  if not exists (select 1 from public.cafes where id = p_cafe_id) then
    raise exception 'cafe unavailable' using errcode = 'P0002';
  end if;

  select * into result
  from public.cafe_list_items item
  where item.list_id = p_list_id and item.cafe_id = p_cafe_id;
  if found then return result; end if;

  select coalesce(max(position), -1) + 1
  into next_position
  from public.cafe_list_items
  where list_id = p_list_id;

  insert into public.cafe_list_items (
    list_id, cafe_id, position, contributor_id, note
  ) values (
    p_list_id, p_cafe_id, next_position, actor, nullif(btrim(p_note), '')
  )
  returning * into result;

  update public.cafe_lists set updated_at = now() where id = p_list_id;
  return result;
end;
$$;

-- The phase-4 function returns the full table composite, including the stable
-- contributor UUID. Keep it only as an internal compatibility implementation;
-- app clients use a scalar result so a retry of an existing item cannot reveal
-- a contributor hidden by the caller-bound list projection.
create or replace function public.add_cafe_list_item_v2(
  p_list_id uuid,
  p_cafe_id uuid,
  p_note text default null
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.add_cafe_list_item(p_list_id, p_cafe_id, p_note);
  return true;
end;
$$;

create or replace function public.remove_cafe_list_item(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.cafe_list_items;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select * into target
  from public.cafe_list_items
  where id = p_item_id;
  if not found then return; end if;

  perform 1 from public.cafe_lists where id = target.list_id for update;
  if not found or not private.can_edit_cafe_list_as(target.list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  delete from public.cafe_list_items where id = p_item_id;
  update public.cafe_list_items
  set position = position - 1
  where list_id = target.list_id and position > target.position;
  update public.cafe_lists set updated_at = now() where id = target.list_id;
end;
$$;

create or replace function public.move_cafe_list_item(
  p_item_id uuid,
  p_position integer
)
returns public.cafe_list_items
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.cafe_list_items;
  old_position integer;
  new_position integer;
  last_position integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select * into target
  from public.cafe_list_items
  where id = p_item_id;
  if not found then
    raise exception 'cafe list item unavailable' using errcode = '42501';
  end if;
  perform 1 from public.cafe_lists where id = target.list_id for update;
  if not found or not private.can_edit_cafe_list_as(target.list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  select greatest(count(*) - 1, 0)
  into last_position
  from public.cafe_list_items
  where list_id = target.list_id;
  old_position := target.position;
  new_position := greatest(0, least(coalesce(p_position, old_position), last_position));

  if new_position < old_position then
    update public.cafe_list_items
    set position = position + 1
    where list_id = target.list_id
      and id <> target.id
      and position >= new_position
      and position < old_position;
  elsif new_position > old_position then
    update public.cafe_list_items
    set position = position - 1
    where list_id = target.list_id
      and id <> target.id
      and position > old_position
      and position <= new_position;
  end if;

  update public.cafe_list_items
  set position = new_position
  where id = target.id
  returning * into target;
  update public.cafe_lists set updated_at = now() where id = target.list_id;

  if target.contributor_id is not null
     and private.blocked_between(actor, target.contributor_id) then
    target.contributor_id := null;
  end if;
  return target;
end;
$$;

-- The phase-4 move function also returns the full item composite. Keep it as
-- the internal implementation and expose only a scalar result to app clients,
-- so moving an item cannot reveal hidden contributor identity.
create or replace function public.move_cafe_list_item_v2(
  p_item_id uuid,
  p_position integer
)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.move_cafe_list_item(p_item_id, p_position);
  return true;
end;
$$;

create or replace function public.transfer_cafe_list_ownership_v2(
  p_list_id uuid,
  p_new_owner_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_list public.cafe_lists;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select * into target_list
  from public.cafe_lists
  where id = p_list_id
  for update;
  if not found or target_list.owner_id <> actor
     or target_list.system_kind is not null
     or not private.can_manage_cafe_list_as(p_list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;
  if p_new_owner_id is null
     or p_new_owner_id = actor
     or private.blocked_between(actor, p_new_owner_id)
     or not exists (
       select 1
       from public.cafe_list_members member
       where member.list_id = p_list_id
         and member.user_id = p_new_owner_id
         and member.invitation_status = 'accepted'
     ) then
    raise exception 'new owner must be an accepted collaborator' using errcode = '42501';
  end if;

  delete from public.cafe_list_members
  where list_id = p_list_id and user_id = p_new_owner_id;

  update public.cafe_lists
  set owner_id = p_new_owner_id, updated_at = now()
  where id = p_list_id;

  -- A transfer must not turn a previously peer-to-peer block into an active
  -- owner/member relationship. Cafe contributions remain on the list, while
  -- the blocked memberships are revoked just like the normal block flow.
  delete from public.cafe_list_members member
  where member.list_id = p_list_id
    and member.user_id <> actor
    and private.blocked_between(p_new_owner_id, member.user_id);

  insert into public.cafe_list_members as existing (
    list_id, user_id, role, invitation_status, invited_by,
    created_at, updated_at, accepted_at, responded_at
  ) values (
    p_list_id, actor, 'editor', 'accepted', p_new_owner_id,
    now(), now(), now(), now()
  )
  on conflict (list_id, user_id) do update
  set
    role = 'editor',
    invitation_status = 'accepted',
    invited_by = p_new_owner_id,
    updated_at = now(),
    accepted_at = coalesce(existing.accepted_at, now()),
    responded_at = now();

  return public.get_cafe_list_v2(p_list_id);
end;
$$;

create or replace function public.delete_cafe_list_v2(p_list_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_list public.cafe_lists;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select * into target_list
  from public.cafe_lists
  where id = p_list_id
  for update;
  if not found then return true; end if;
  if target_list.owner_id <> actor
     or target_list.system_kind is not null
     or not private.can_manage_cafe_list_as(p_list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  delete from public.cafe_lists where id = p_list_id;
  return true;
end;
$$;

-- Direct table reads keep non-identifying compatibility fields only. Stable
-- collaborator, contributor, and inviter identifiers flow through the masked
-- caller-bound projections above.
revoke select on table public.cafe_list_members from authenticated;
grant select (
  list_id, role, invitation_status, created_at, updated_at,
  accepted_at, responded_at
) on table public.cafe_list_members to authenticated;

revoke select on table public.cafe_list_items from authenticated;
grant select (
  id, list_id, cafe_id, position, note, created_at
) on table public.cafe_list_items to authenticated;

drop policy if exists "Visible cafe list memberships" on public.cafe_list_members;
create policy "Visible cafe list memberships"
on public.cafe_list_members
for select
to authenticated
using (
  (
    user_id = (select auth.uid())
    and invitation_status in ('pending', 'accepted', 'declined', 'cancelled')
  )
  or (
    public.can_view_cafe_list(list_id, (select auth.uid()))
    and not public.is_blocked_between(user_id, (select auth.uid()))
  )
);

drop policy if exists "Visible cafe list items" on public.cafe_list_items;
create policy "Visible cafe list items"
on public.cafe_list_items
for select
to authenticated
using (public.can_view_cafe_list_items(list_id, (select auth.uid())));

revoke all on function public.list_cafe_lists_v2()
  from public, anon, authenticated;
revoke all on function public.get_cafe_list_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.create_cafe_list_v2(text, text, text)
  from public, anon, authenticated;
revoke all on function public.update_cafe_list_v2(uuid, text, text, text)
  from public, anon, authenticated;
revoke all on function public.respond_cafe_list_invitation_v2(uuid, text)
  from public, anon, authenticated;
revoke all on function public.cancel_cafe_list_invitation_v2(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.set_cafe_list_member_role_v2(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.remove_cafe_list_member_v2(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.leave_cafe_list_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.transfer_cafe_list_ownership_v2(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.delete_cafe_list_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.add_cafe_list_item(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.add_cafe_list_item_v2(uuid, uuid, text)
  from public, anon, authenticated;
revoke all on function public.move_cafe_list_item(uuid, integer)
  from public, anon, authenticated;
revoke all on function public.move_cafe_list_item_v2(uuid, integer)
  from public, anon, authenticated;

grant execute on function public.list_cafe_lists_v2() to authenticated;
grant execute on function public.get_cafe_list_v2(uuid) to authenticated;
grant execute on function public.create_cafe_list_v2(text, text, text) to authenticated;
grant execute on function public.update_cafe_list_v2(uuid, text, text, text) to authenticated;
grant execute on function public.respond_cafe_list_invitation_v2(uuid, text) to authenticated;
grant execute on function public.cancel_cafe_list_invitation_v2(uuid, uuid) to authenticated;
grant execute on function public.set_cafe_list_member_role_v2(uuid, uuid, text) to authenticated;
grant execute on function public.remove_cafe_list_member_v2(uuid, uuid) to authenticated;
grant execute on function public.leave_cafe_list_v2(uuid) to authenticated;
grant execute on function public.transfer_cafe_list_ownership_v2(uuid, uuid) to authenticated;
grant execute on function public.delete_cafe_list_v2(uuid) to authenticated;
grant execute on function public.add_cafe_list_item_v2(uuid, uuid, text) to authenticated;
grant execute on function public.move_cafe_list_item_v2(uuid, integer) to authenticated;

comment on function public.list_cafe_lists_v2() is
  'Caller-bound custom cafe-list summaries with invitation and permission state.';
comment on function public.get_cafe_list_v2(uuid) is
  'Caller-bound hydrated cafe-list detail with block-safe collaborator identity.';
comment on function public.add_cafe_list_item_v2(uuid, uuid, text) is
  'Caller-bound cafe-list item mutation with a non-identifying scalar result.';
comment on function public.move_cafe_list_item_v2(uuid, integer) is
  'Caller-bound cafe-list item reorder with a non-identifying scalar result.';

commit;
