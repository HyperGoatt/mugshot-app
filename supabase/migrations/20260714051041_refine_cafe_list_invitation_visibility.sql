-- Pending invitees may inspect list metadata before accepting, but invited-only
-- contents remain private until acceptance.

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
          where m.list_id = l.id and m.user_id = p_viewer
        )
        or (l.visibility = 'friends' and private.confirmed_friends(p_viewer, l.owner_id))
      )
  );
$$;

create or replace function private.can_view_cafe_list_items_as(p_list_id uuid, p_viewer uuid)
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

revoke all on function private.can_view_cafe_list_as(uuid, uuid) from public, anon, authenticated;
revoke all on function private.can_view_cafe_list_items_as(uuid, uuid) from public, anon, authenticated;

drop policy if exists "Visible cafe list items" on public.cafe_list_items;
create policy "Visible cafe list items" on public.cafe_list_items for select to authenticated
  using (private.can_view_cafe_list_items_as(list_id, (select auth.uid())));
;
