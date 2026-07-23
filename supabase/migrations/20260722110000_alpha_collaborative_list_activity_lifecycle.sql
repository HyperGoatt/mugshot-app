begin;

-- Collaborative cafe lists are an alpha social surface, so their Activity
-- history must explain meaningful lifecycle changes beyond the initial invite.
-- These events are generated only from authoritative list/member mutations and
-- reuse the existing collaborative-list push preference.

-- Ownership transitions need a durable, non-client-readable receipt. The
-- epoch advances for every owner change, including succession, so only a
-- retry of the immediately committed A-to-B transition can reconcile as
-- successful. An older A-to-B receipt can never authorize a later cycle.
alter table public.cafe_lists
  add column if not exists ownership_epoch bigint not null default 0;

create table if not exists private.cafe_list_ownership_transfer_receipts (
  list_id uuid not null
    references public.cafe_lists(id) on delete cascade,
  ownership_epoch bigint not null check (ownership_epoch > 0),
  previous_owner_id uuid not null
    references public.users(id) on delete cascade,
  new_owner_id uuid not null
    references public.users(id) on delete cascade,
  completed_at timestamptz not null default now(),
  primary key (list_id, ownership_epoch),
  check (previous_owner_id <> new_owner_id)
);

alter table private.cafe_list_ownership_transfer_receipts
  enable row level security;
revoke all on table private.cafe_list_ownership_transfer_receipts
  from public, anon, authenticated;

create or replace function private.advance_cafe_list_ownership_epoch_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.owner_id is distinct from old.owner_id then
    new.ownership_epoch := old.ownership_epoch + 1;
    delete from private.cafe_list_ownership_transfer_receipts receipt
    where receipt.list_id = old.id;
  else
    -- The epoch is server-maintained and cannot be advanced independently.
    new.ownership_epoch := old.ownership_epoch;
  end if;
  return new;
end;
$$;

revoke all on function private.advance_cafe_list_ownership_epoch_v1()
  from public, anon, authenticated;

drop trigger if exists advance_cafe_list_ownership_epoch
  on public.cafe_lists;
create trigger advance_cafe_list_ownership_epoch
before update of owner_id, ownership_epoch on public.cafe_lists
for each row execute function private.advance_cafe_list_ownership_epoch_v1();

alter table public.activity_events
  drop constraint if exists activity_events_kind_check;
alter table public.activity_events
  add constraint activity_events_kind_check check (kind in (
    'friend_post', 'tag', 'shared_mugshot_invitation',
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
      when 'shared_mugshot_invitation'
        then preference.shared_mugshot_invitations
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

create or replace function private.activity_event_is_visible(
  p_event public.activity_events,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not null
    and p_event.recipient_id = p_viewer
    and p_event.suppressed_at is null
    and private.activity_recipient_is_eligible_v2(p_viewer)
    and private.can_view_user_as(p_event.actor_user_id, p_viewer)
    and case p_event.kind
      when 'friend_post' then
        p_event.visit_id is not null
        and private.can_view_visit_as(p_event.visit_id, p_viewer)
      when 'tag' then
        p_event.visit_id is not null
        and exists (
          select 1
          from public.visit_companions tag
          where tag.visit_id = p_event.visit_id
            and tag.companion_user_id = p_viewer
            and tag.added_by = p_event.actor_user_id
        )
      when 'shared_mugshot_invitation' then
        p_event.shared_memory_id is not null
        and exists (
          select 1
          from public.shared_memory_members member
          where member.shared_memory_id = p_event.shared_memory_id
            and member.user_id = p_viewer
            and member.invited_by = p_event.actor_user_id
            and member.status in ('pending', 'accepted')
        )
      when 'collaborative_list_invitation' then
        p_event.cafe_list_id is not null
        and exists (
          select 1
          from public.cafe_list_members member
          where member.list_id = p_event.cafe_list_id
            and member.user_id = p_viewer
            and member.invited_by = p_event.actor_user_id
            and member.invitation_status in ('pending', 'accepted')
        )
      when 'collaborative_list_invitation_accepted' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_invitation_declined' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_invitation_cancelled' then
        p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
        and (
          p_event.cafe_list_id is not null
          or (
            p_event.cafe_list_id is null
            and p_event.metadata ->> 'reason' = 'list_deleted'
            and p_event.metadata ->> 'list_id' is not null
          )
        )
      when 'collaborative_list_role_changed' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_member_removed' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_member_left' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_ownership_transferred' then
        p_event.cafe_list_id is not null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'collaborative_list_deleted' then
        p_event.cafe_list_id is null
        and p_event.metadata ->> 'source' = 'cafe_list_lifecycle'
      when 'like' then
        p_event.visit_id is not null
        and private.can_view_visit_as(p_event.visit_id, p_viewer)
      when 'comment' then
        p_event.comment_id is not null
        and private.can_view_comment_as(p_event.comment_id, p_viewer)
      when 'comment_mention' then
        p_event.comment_id is not null
        and private.can_view_comment_as(p_event.comment_id, p_viewer)
        and exists (
          select 1 from public.comment_mentions mention
          where mention.comment_id = p_event.comment_id
            and mention.mentioned_user_id = p_viewer
        )
      when 'reaction' then
        p_event.visit_id is not null
        and private.can_view_visit_as(p_event.visit_id, p_viewer)
      when 'friend_request' then
        p_event.friend_request_id is not null
        and exists (
          select 1
          from public.friend_requests request
          where request.id = p_event.friend_request_id
            and request.to_user_id = p_viewer
            and request.from_user_id = p_event.actor_user_id
            and request.status = 'pending'
        )
      when 'friend_request_accepted' then
        p_event.friend_request_id is not null
        and exists (
          select 1
          from public.friend_requests request
          where request.id = p_event.friend_request_id
            and request.from_user_id = p_viewer
            and request.to_user_id = p_event.actor_user_id
            and request.status = 'accepted'
        )
      else false
    end;
$$;

create or replace function private.create_cafe_list_lifecycle_activity_v1(
  p_recipient uuid,
  p_actor uuid,
  p_kind text,
  p_dedupe_key text,
  p_title text,
  p_body text,
  p_cafe_list_id uuid,
  p_deep_link text,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  event_id uuid;
begin
  if p_kind not in (
    'collaborative_list_invitation_accepted',
    'collaborative_list_invitation_declined',
    'collaborative_list_invitation_cancelled',
    'collaborative_list_role_changed',
    'collaborative_list_member_removed',
    'collaborative_list_member_left',
    'collaborative_list_ownership_transferred',
    'collaborative_list_deleted'
  ) or p_recipient is null or p_actor is null or p_recipient = p_actor
     or not private.activity_recipient_is_eligible_v2(p_recipient)
     or not private.can_socially_mutate_as(p_actor)
     or not private.can_view_user_as(p_actor, p_recipient)
     or p_deep_link not in ('mugshot://activity', 'mugshot://activity/lists') then
    return null;
  end if;

  insert into public.activity_events (
    recipient_id, actor_user_id, kind, dedupe_key, title, body,
    cafe_list_id, deep_link, metadata
  ) values (
    p_recipient, p_actor, p_kind, left(p_dedupe_key, 240),
    left(btrim(p_title), 120), left(btrim(p_body), 280),
    p_cafe_list_id, p_deep_link,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'source', 'cafe_list_lifecycle'
    )
  )
  on conflict (recipient_id, dedupe_key) do nothing
  returning id into event_id;

  return event_id;
end;
$$;

create or replace function private.activity_from_cafe_list_member_lifecycle_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  list_owner uuid;
  list_title text;
  event_kind text;
begin
  if tg_op = 'DELETE' then
    select list.owner_id, list.title into list_owner, list_title
    from public.cafe_lists list
    where list.id = old.list_id;
  else
    select list.owner_id, list.title into list_owner, list_title
    from public.cafe_lists list
    where list.id = new.list_id;
  end if;
  if actor is null or list_owner is null then
    if tg_op = 'DELETE' then return old; end if;
    return new;
  end if;

  if tg_op = 'UPDATE' then
    if old.invitation_status = 'pending'
       and new.invitation_status in ('accepted', 'declined')
       and actor = new.user_id then
      event_kind := case new.invitation_status
        when 'accepted' then 'collaborative_list_invitation_accepted'
        else 'collaborative_list_invitation_declined'
      end;
      perform private.create_cafe_list_lifecycle_activity_v1(
        list_owner, actor, event_kind,
        'cafe-list-response:' || new.list_id::text || ':' || new.user_id::text
          || ':' || new.invitation_status || ':'
          || extract(epoch from new.updated_at)::text,
        case new.invitation_status
          when 'accepted' then 'Cafe list invitation accepted'
          else 'Cafe list invitation declined'
        end,
        case new.invitation_status
          when 'accepted' then 'A collaborator joined ' || list_title || '.'
          else 'A collaborator declined the invitation to ' || list_title || '.'
        end,
        new.list_id,
        case new.invitation_status
          when 'accepted' then 'mugshot://activity/lists'
          else 'mugshot://activity'
        end,
        jsonb_build_object('invitation_status', new.invitation_status)
      );
    elsif old.invitation_status = 'pending'
          and new.invitation_status = 'cancelled'
          and (
            actor = list_owner
            or actor = new.invited_by
          ) then
      perform private.create_cafe_list_lifecycle_activity_v1(
        new.user_id, actor, 'collaborative_list_invitation_cancelled',
        'cafe-list-cancelled:' || new.list_id::text || ':' || new.user_id::text
          || ':' || extract(epoch from new.updated_at)::text,
        'Cafe list invitation cancelled',
        'The invitation to ' || list_title || ' is no longer active.',
        new.list_id, 'mugshot://activity', '{}'::jsonb
      );
    elsif old.role is distinct from new.role
          and new.invitation_status = 'accepted'
          and actor = list_owner then
      perform private.create_cafe_list_lifecycle_activity_v1(
        new.user_id, actor, 'collaborative_list_role_changed',
        'cafe-list-role:' || new.list_id::text || ':' || new.user_id::text
          || ':' || new.role || ':' || extract(epoch from new.updated_at)::text,
        'Your cafe list role changed',
        'You are now ' || case new.role
          when 'editor' then 'an editor'
          else 'a viewer'
        end || ' on ' || list_title || '.',
        new.list_id, 'mugshot://activity/lists',
        jsonb_build_object('role', new.role)
      );
    end if;
    return new;
  end if;

  if old.invitation_status = 'pending'
     and actor = old.invited_by then
    perform private.create_cafe_list_lifecycle_activity_v1(
      old.user_id, actor, 'collaborative_list_invitation_cancelled',
      'cafe-list-cancelled:' || old.list_id::text || ':' || old.user_id::text
        || ':deleted:' || extract(epoch from old.updated_at)::text,
      'Cafe list invitation cancelled',
      'The invitation to ' || list_title || ' is no longer active.',
      old.list_id, 'mugshot://activity', '{}'::jsonb
    );
  elsif old.invitation_status = 'accepted' then
    if actor = list_owner then
      perform private.create_cafe_list_lifecycle_activity_v1(
        old.user_id, actor, 'collaborative_list_member_removed',
        'cafe-list-removed:' || old.list_id::text || ':' || old.user_id::text
          || ':' || extract(epoch from old.updated_at)::text,
        'Removed from a cafe list',
        'You no longer collaborate on ' || list_title || '.',
        old.list_id, 'mugshot://activity', '{}'::jsonb
      );
    elsif actor = old.user_id then
      perform private.create_cafe_list_lifecycle_activity_v1(
        list_owner, actor, 'collaborative_list_member_left',
        'cafe-list-left:' || old.list_id::text || ':' || old.user_id::text
          || ':' || extract(epoch from old.updated_at)::text,
        'A collaborator left',
        'A collaborator left ' || list_title || '.',
        old.list_id, 'mugshot://activity/lists', '{}'::jsonb
      );
    end if;
  end if;
  return old;
end;
$$;

create or replace function private.activity_from_cafe_list_owner_lifecycle_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  member public.cafe_list_members%rowtype;
begin
  if tg_op = 'UPDATE' then
    if old.owner_id is distinct from new.owner_id
       and actor = old.owner_id
       and new.owner_id is not null then
      perform private.create_cafe_list_lifecycle_activity_v1(
        new.owner_id, actor, 'collaborative_list_ownership_transferred',
        'cafe-list-owner-received:' || new.id::text || ':'
          || new.owner_id::text || ':' || extract(epoch from new.updated_at)::text,
        'You now own a cafe list',
        'Ownership of ' || new.title || ' was transferred to you.',
        new.id, 'mugshot://activity/lists',
        jsonb_build_object('direction', 'received')
      );
      perform private.create_cafe_list_lifecycle_activity_v1(
        old.owner_id, new.owner_id, 'collaborative_list_ownership_transferred',
        'cafe-list-owner-sent:' || new.id::text || ':'
          || old.owner_id::text || ':' || extract(epoch from new.updated_at)::text,
        'Cafe list ownership transferred',
        'You are now an editor on ' || new.title || '.',
        new.id, 'mugshot://activity/lists',
        jsonb_build_object('direction', 'transferred')
      );
    end if;
    return new;
  end if;

  if actor = old.owner_id and old.system_kind is null then
    for member in
      select * from public.cafe_list_members
      where list_id = old.id
        and invitation_status in ('accepted', 'pending')
    loop
      if member.invitation_status = 'accepted' then
        perform private.create_cafe_list_lifecycle_activity_v1(
          member.user_id, actor, 'collaborative_list_deleted',
          'cafe-list-deleted:' || old.id::text || ':' || member.user_id::text,
          'Cafe list deleted',
          old.title || ' was deleted by its owner.',
          null, 'mugshot://activity',
          jsonb_build_object(
            'reason', 'list_deleted',
            'list_id', old.id,
            'list_title', old.title
          )
        );
      else
        perform private.create_cafe_list_lifecycle_activity_v1(
          member.user_id, actor,
          'collaborative_list_invitation_cancelled',
          'cafe-list-deleted-invite:' || old.id::text || ':'
            || member.user_id::text,
          'Cafe list invitation cancelled',
          'The invitation to ' || old.title
            || ' ended because the list was deleted.',
          null, 'mugshot://activity',
          jsonb_build_object(
            'reason', 'list_deleted',
            'list_id', old.id,
            'list_title', old.title
          )
        );
      end if;
    end loop;
  end if;
  return old;
end;
$$;

drop trigger if exists activity_from_cafe_list_member_lifecycle
  on public.cafe_list_members;
create trigger activity_from_cafe_list_member_lifecycle
after update of invitation_status, role or delete
on public.cafe_list_members
for each row execute function private.activity_from_cafe_list_member_lifecycle_v1();

drop trigger if exists activity_from_cafe_list_owner_lifecycle
  on public.cafe_lists;
create trigger activity_from_cafe_list_owner_lifecycle
after update of owner_id on public.cafe_lists
for each row execute function private.activity_from_cafe_list_owner_lifecycle_v1();

drop trigger if exists activity_from_cafe_list_deletion
  on public.cafe_lists;
create trigger activity_from_cafe_list_deletion
before delete on public.cafe_lists
for each row execute function private.activity_from_cafe_list_owner_lifecycle_v1();

-- Transfer changes owner first so the accepted target membership can be
-- removed without being misclassified as an owner-initiated removal.
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
       and private.can_view_cafe_list_as(p_list_id, actor)
       and exists (
         select 1
         from private.cafe_list_ownership_transfer_receipts receipt
         where receipt.list_id = p_list_id
           and receipt.ownership_epoch = target_list.ownership_epoch
           and receipt.previous_owner_id = actor
           and receipt.new_owner_id = p_new_owner_id
       ) then
      return public.get_cafe_list_v2(p_list_id);
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

  return public.get_cafe_list_v2(p_list_id);
end;
$$;

-- Keep the legacy compatibility RPC safe until the minimum supported build no
-- longer calls it. Pending self-removal is a decline, not an unexplained row
-- deletion; accepted self-removal is the normal leave lifecycle.
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
  list_owner uuid;
  member_status text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select list.owner_id into list_owner
  from public.cafe_lists list
  where list.id = p_list_id
  for update;

  select member.invitation_status into member_status
  from public.cafe_list_members member
  where member.list_id = p_list_id
    and member.user_id = p_user_id
  for update;

  if actor = list_owner then
    if member_status = 'pending' then
      perform public.cancel_cafe_list_invitation_v2(p_list_id, p_user_id);
    elsif member_status is not null then
      perform public.remove_cafe_list_member_v2(p_list_id, p_user_id);
    end if;
  elsif actor = p_user_id then
    if member_status = 'pending' then
      perform public.respond_cafe_list_invitation_v2(p_list_id, 'decline');
    elsif member_status = 'accepted' then
      perform public.leave_cafe_list_v2(p_list_id);
    end if;
  else
    raise exception 'not permitted' using errcode = '42501';
  end if;
end;
$$;

revoke all on function private.activity_kind_push_enabled(uuid,text)
  from public, anon, authenticated;
revoke all on function private.activity_event_is_visible(
  public.activity_events,uuid
) from public, anon, authenticated;
revoke all on function private.create_cafe_list_lifecycle_activity_v1(
  uuid,uuid,text,text,text,text,uuid,text,jsonb
) from public, anon, authenticated;
revoke all on function private.activity_from_cafe_list_member_lifecycle_v1()
  from public, anon, authenticated;
revoke all on function private.activity_from_cafe_list_owner_lifecycle_v1()
  from public, anon, authenticated;
revoke all on function private.advance_cafe_list_ownership_epoch_v1()
  from public, anon, authenticated;
revoke all on function public.transfer_cafe_list_ownership_v2(uuid,uuid)
  from public, anon, authenticated;
revoke all on function public.revoke_cafe_list_member(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.transfer_cafe_list_ownership_v2(uuid,uuid)
  to authenticated;
grant execute on function public.revoke_cafe_list_member(uuid,uuid)
  to authenticated;

comment on function private.create_cafe_list_lifecycle_activity_v1(
  uuid,uuid,text,text,text,text,uuid,text,jsonb
) is
  'Internal-only durable Activity creation for authoritative collaborative cafe-list lifecycle changes.';
comment on column public.notification_preferences.collaborative_list_invitations is
  'Controls push for collaborative cafe-list invitations and lifecycle changes; in-app Activity remains available.';
comment on column public.cafe_lists.ownership_epoch is
  'Server-maintained owner-transition generation used to reconcile only the immediately committed transfer.';
comment on table private.cafe_list_ownership_transfer_receipts is
  'Internal transfer receipts keyed to the exact cafe-list ownership generation; never client-readable.';

commit;
