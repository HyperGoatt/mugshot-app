-- Preserve the existing content-free Private tag notice without queueing or
-- publishing the Private sip. Actor screening, blocks, recipient and tag
-- membership checks remain mandatory. Other activity keeps revision screening.
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
    and (
      p_event.visit_id is null
      or private.screening_approved_v1('visit',p_event.visit_id)
      -- Private sips never enter screening. A canonical tag can still produce
      -- a content-free notice with self-removal; it does not grant sip access.
      or (p_event.kind='tag' and exists (
        select 1 from public.visits tagged_visit
        where tagged_visit.id=p_event.visit_id
          and tagged_visit.user_id=p_event.actor_user_id
          and tagged_visit.visibility='private'
          and tagged_visit.upload_state='complete'
      ))
    )
    and (p_event.comment_id is null or private.screening_approved_v1('comment',p_event.comment_id))
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

