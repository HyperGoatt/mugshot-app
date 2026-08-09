begin;

-- The legacy PWA still writes its own notification projection after a social
-- mutation. Keep that compatibility path during alpha, but accept a row only
-- when it is backed by the authoritative like, comment, mention, or friend
-- request that the current caller actually created.

alter table public.notifications
  drop constraint if exists notifications_type_check,
  add constraint notifications_type_check check (type in (
    'like', 'comment', 'reply', 'mention', 'follow', 'friend_request',
    'friend_accept', 'friend_request_accepted', 'new_visit_from_friend'
  ));

create or replace function public.is_valid_legacy_notification_insert_v1(
  p_recipient uuid,
  p_actor uuid,
  p_type text,
  p_visit_id uuid,
  p_comment_id uuid,
  p_created_at timestamptz,
  p_read_at timestamptz
)
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$
  select auth.uid() is not null
    and p_actor = auth.uid()
    and p_recipient is not null
    and p_recipient <> p_actor
    and p_read_at is null
    and p_created_at between now() - interval '5 minutes' and now() + interval '1 minute'
    and not public.is_blocked_between(p_actor, p_recipient)
    and case p_type
      when 'like' then
        p_visit_id is not null
        and p_comment_id is null
        and exists (
          select 1
          from public.likes social_like
          join public.visits visit on visit.id = social_like.visit_id
          where social_like.user_id = p_actor
            and social_like.visit_id = p_visit_id
            and visit.user_id = p_recipient
        )
      when 'comment' then
        p_visit_id is not null
        and p_comment_id is not null
        and exists (
          select 1
          from public.comments comment
          join public.visits visit on visit.id = comment.visit_id
          where comment.id = p_comment_id
            and comment.user_id = p_actor
            and comment.visit_id = p_visit_id
            and comment.parent_comment_id is null
            and visit.user_id = p_recipient
        )
      when 'reply' then
        p_visit_id is not null
        and p_comment_id is not null
        and exists (
          select 1
          from public.comments reply
          join public.comments parent on parent.id = reply.parent_comment_id
          where reply.id = p_comment_id
            and reply.user_id = p_actor
            and reply.visit_id = p_visit_id
            and parent.visit_id = p_visit_id
            and parent.user_id = p_recipient
            and public.can_view_visit(p_visit_id, p_recipient)
        )
      when 'mention' then
        p_visit_id is not null
        and p_comment_id is not null
        and exists (
          select 1
          from public.comments comment
          join public.users recipient on recipient.id = p_recipient
          where comment.id = p_comment_id
            and comment.user_id = p_actor
            and comment.visit_id = p_visit_id
            and public.can_view_visit(p_visit_id, p_recipient)
            and (
              exists (
                select 1
                from public.comment_mentions mention
                where mention.comment_id = comment.id
                  and mention.mentioned_user_id = p_recipient
              )
              or (
                position('@[' in comment.text) > 0
                and position(recipient.username || ']' in comment.text) > 0
              )
            )
        )
      when 'friend_request' then
        p_visit_id is null
        and p_comment_id is null
        and exists (
          select 1
          from public.friend_requests request
          where request.from_user_id = p_actor
            and request.to_user_id = p_recipient
            and request.status = 'pending'
        )
      when 'friend_accept' then
        p_visit_id is null
        and p_comment_id is null
        and exists (
          select 1
          from public.friend_requests request
          where request.from_user_id = p_recipient
            and request.to_user_id = p_actor
            and request.status = 'accepted'
        )
      when 'friend_request_accepted' then
        p_visit_id is null
        and p_comment_id is null
        and exists (
          select 1
          from public.friend_requests request
          where request.from_user_id = p_recipient
            and request.to_user_id = p_actor
            and request.status = 'accepted'
        )
      else false
    end;
$$;

revoke all on function public.is_valid_legacy_notification_insert_v1(
  uuid, uuid, text, uuid, uuid, timestamptz, timestamptz
) from public, anon, authenticated;
grant execute on function public.is_valid_legacy_notification_insert_v1(
  uuid, uuid, text, uuid, uuid, timestamptz, timestamptz
) to authenticated;

drop policy if exists "Users insert notifications for their actions"
  on public.notifications;
drop policy if exists "Users read their notifications"
  on public.notifications;
drop policy if exists "Users mark notifications as read"
  on public.notifications;
drop policy if exists "Users can delete their own notifications"
  on public.notifications;

create policy "Recipients read legacy notifications"
on public.notifications for select to authenticated
using (auth.uid() = user_id);

create policy "Actors insert verified legacy notifications"
on public.notifications for insert to authenticated
with check (public.is_valid_legacy_notification_insert_v1(
  user_id,
  actor_user_id,
  type,
  visit_id,
  comment_id,
  created_at,
  read_at
));

create policy "Recipients mark legacy notifications read"
on public.notifications for update to authenticated
using (auth.uid() = user_id)
with check (auth.uid() = user_id);

create policy "Recipients delete legacy notifications"
on public.notifications for delete to authenticated
using (auth.uid() = user_id);

-- Replace table-wide client grants with the exact columns used by the PWA.
-- In particular, a recipient may only change read_at and an actor cannot
-- supply an arbitrary id, timestamp, or pre-read state during insertion.
revoke all on table public.notifications from public, anon, authenticated;
grant select, delete on table public.notifications to authenticated;
grant insert (user_id, actor_user_id, type, visit_id, comment_id)
  on table public.notifications to authenticated;
grant update (read_at) on table public.notifications to authenticated;

commit;
