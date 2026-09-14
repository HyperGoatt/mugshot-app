-- Private collaboration keeps its existing explicit invitation boundary.
-- Private list data is never queued for external screening or made public.


create or replace function private.can_view_cafe_list_as(p_list_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (exists(select 1 from public.cafe_lists where id=p_list_id and (owner_id=p_viewer or visibility='private')) or private.screening_approved_v1('list',p_list_id))
    and (private.is_public_cafe_list_as(p_list_id, p_viewer)
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
    ));
$$;

create or replace function private.can_view_cafe_list_items_as(p_list_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (exists(select 1 from public.cafe_lists where id=p_list_id and (owner_id=p_viewer or visibility='private')) or private.screening_approved_v1('list',p_list_id))
    and (private.is_public_cafe_list_as(p_list_id, p_viewer)
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
    ));
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
    where item.list_id = p_list_id and (item.contributor_id=actor or private.screening_approved_v1('list_item',item.id) or exists(select 1 from public.cafe_lists where id=p_list_id and visibility='private'));
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

alter policy screening_lists_read on public.cafe_lists
  using(owner_id=(select auth.uid()) or visibility='private' or public.content_screening_approved_v1('list',id));
alter policy screening_list_items_read on public.cafe_list_items
  using(contributor_id=(select auth.uid()) or public.content_screening_approved_v1('list_item',id)
    or exists(select 1 from public.cafe_lists list where list.id=list_id and list.visibility='private'));
-- These are restrictive screening policies. Existing permissive audience/member
-- policies and the definer RPC's member checks still determine who may read.
