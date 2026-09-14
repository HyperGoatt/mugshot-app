-- Ownership changes deliberately create a pending screening revision. Return a
-- content-free, client-compatible receipt instead of rolling back the mutation.
create or replace function private.cafe_list_transfer_result_v1(
  p_list_id uuid, p_previous_owner uuid, p_new_owner uuid
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.cafe_lists;
  member_role text;
begin
  select * into target from public.cafe_lists where id = p_list_id;
  if actor is null or actor is distinct from p_previous_owner
     or target.id is null or target.owner_id is distinct from p_new_owner
     or not private.is_live_account_as(actor)
     or not private.is_live_account_as(p_new_owner)
     or private.blocked_between(actor, p_new_owner)
     or not exists (
       select 1 from private.cafe_list_ownership_transfer_receipts receipt
       where receipt.list_id = target.id
         and receipt.ownership_epoch = target.ownership_epoch
         and receipt.previous_owner_id = actor
         and receipt.new_owner_id = p_new_owner
     ) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;
  if private.can_view_cafe_list_as(p_list_id, actor) then
    return public.get_cafe_list_v2(p_list_id);
  end if;
  select role into member_role from public.cafe_list_members
  where list_id = p_list_id and user_id = actor and invitation_status = 'accepted';
  return jsonb_build_object(
    'id', target.id, 'title', 'Ownership transferred',
    'description', 'This cafe list is being checked.',
    'visibility', target.visibility, 'system_kind', null,
    'created_at', target.created_at, 'updated_at', target.updated_at,
    'owner', private.cafe_list_profile_json_v2(p_new_owner, actor),
    'access_kind', case when member_role is null then 'viewer' else 'member' end,
    'current_role', coalesce(member_role, 'viewer'),
    'invited_role', null, 'invitation_status', null, 'inviter', null,
    'can_view_items', false, 'can_edit_items', false, 'can_manage', false,
    'can_leave', member_role is not null, 'can_delete', false,
    'can_transfer', false, 'social_actions_available', false,
    'cafe_count', 0, 'collaborator_count', 0, 'pending_count', 0,
    'preview_photo_url', null, 'preview_address', null,
    'items', '[]'::jsonb, 'members', '[]'::jsonb
  );
end;
$$;
revoke all on function private.cafe_list_transfer_result_v1(uuid, uuid, uuid)
  from public, anon, authenticated;

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
  changed integer;
  completed_epoch bigint;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  select * into target_list
  from public.cafe_lists
  where id = p_list_id
  for update;
  if not found or target_list.system_kind is not null then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  if target_list.owner_id is distinct from actor then
    if target_list.owner_id = p_new_owner_id
       and exists (
         select 1
         from private.cafe_list_ownership_transfer_receipts receipt
         where receipt.list_id = p_list_id
           and receipt.ownership_epoch = target_list.ownership_epoch
           and receipt.previous_owner_id = actor
           and receipt.new_owner_id = p_new_owner_id
       ) then
      return private.cafe_list_transfer_result_v1(p_list_id, actor, p_new_owner_id);
    end if;
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  if not private.can_manage_cafe_list_as(p_list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;
  if p_new_owner_id is null
     or p_new_owner_id = actor
     or private.blocked_between(actor, p_new_owner_id)
     or not private.can_socially_mutate_as(p_new_owner_id)
     or not private.can_view_user_as(p_new_owner_id, actor)
     or not exists (
       select 1
       from public.cafe_list_members member
       where member.list_id = p_list_id
         and member.user_id = p_new_owner_id
         and member.invitation_status = 'accepted'
     ) then
    raise exception 'new owner must be an accepted collaborator' using errcode = '42501';
  end if;

  update public.cafe_lists
  set owner_id = p_new_owner_id, updated_at = now()
  where id = p_list_id
  returning ownership_epoch into completed_epoch;

  delete from public.cafe_list_members
  where list_id = p_list_id and user_id = p_new_owner_id;
  get diagnostics changed = row_count;
  if changed <> 1 then
    raise exception 'new owner must remain an accepted collaborator'
      using errcode = '42501';
  end if;

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

  insert into private.cafe_list_ownership_transfer_receipts (
    list_id, ownership_epoch, previous_owner_id, new_owner_id
  ) values (
    p_list_id, completed_epoch, actor, p_new_owner_id
  );

  return private.cafe_list_transfer_result_v1(p_list_id, actor, p_new_owner_id);
end;
$$;
