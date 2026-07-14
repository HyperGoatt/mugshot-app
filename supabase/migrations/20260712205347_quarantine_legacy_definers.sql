-- Trigger functions are invoked by Postgres, never through the Data API.
revoke all on function public.create_friendship_on_request_accept() from public, anon, authenticated;

revoke all on function public.handle_new_user() from public, anon, authenticated;

revoke all on function public.send_push_notification_trigger() from public, anon, authenticated;

-- The legacy mutual-friend RPC accepts an arbitrary "current" user and bypasses
-- RLS. It has no current client caller; quarantine it until it is replaced by a
-- caller-bound implementation.
revoke all on function public.get_mutual_friends(uuid, uuid) from public, anon, authenticated;

-- Cafe aggregates must be computed over rows visible to the caller so private
-- and friends-only visits cannot leak into anonymous/global counts.
alter function public.get_cafe_aggregate_stats(uuid) security invoker;

revoke all on function public.get_cafe_aggregate_stats(uuid) from public, anon;

grant execute on function public.get_cafe_aggregate_stats(uuid) to authenticated;

-- Internal visibility helpers may only answer questions involving the caller.
-- They remain executable by authenticated because RLS policies call them.
create or replace function public.is_blocked_between(p_first uuid, p_second uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_first is null
    or p_second is null
    or (
      ((select auth.uid()) = p_first or (select auth.uid()) = p_second)
      and exists (
        select 1 from public.user_blocks b
        where (b.blocker_id = p_first and b.blocked_id = p_second)
           or (b.blocker_id = p_second and b.blocked_id = p_first)
      )
    );
$$;
create or replace function public.is_confirmed_friend(p_first uuid, p_second uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    ((select auth.uid()) = p_first or (select auth.uid()) = p_second)
    and (
      p_first = p_second
      or (
        not public.is_blocked_between(p_first, p_second)
        and exists (
          select 1 from public.friends f
          where f.user_id = p_first and f.friend_user_id = p_second
        )
        and exists (
          select 1 from public.friends f
          where f.user_id = p_second and f.friend_user_id = p_first
        )
      )
    );
$$;

create or replace function public.can_view_visit(p_visit_id uuid, p_viewer uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    p_viewer = (select auth.uid())
    and exists (
      select 1
      from public.visits v
      where v.id = p_visit_id
        and (v.upload_state = 'complete' or v.user_id = p_viewer)
        and not public.is_blocked_between(p_viewer, v.user_id)
        and (
          v.user_id = p_viewer
          or v.visibility = 'everyone'
          or (v.visibility = 'friends' and public.is_confirmed_friend(p_viewer, v.user_id))
        )
    );
$$;
