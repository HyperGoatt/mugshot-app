-- Feed/Map read paths: support stable keyset pagination, compact map
-- aggregation reads, and one-time auth evaluation inside hot RLS policies.

create index if not exists visits_visible_feed_cursor_idx
  on public.visits (visibility, upload_state, created_at desc, id desc);

create index if not exists visits_user_complete_cafe_idx
  on public.visits (user_id, cafe_id)
  include (overall_score)
  where upload_state = 'complete' and cafe_id is not null;

create index if not exists comments_user_id_idx
  on public.comments (user_id);

alter policy "Owners read their visits"
  on public.visits
  using ((select auth.uid()) = user_id);

alter policy "Friends can read friends visits"
  on public.visits
  using (
    upload_state = 'complete'
    and visibility = 'friends'
    and (select auth.uid()) is not null
    and (
      user_id = (select auth.uid())
      or exists (
        select 1
        from public.friends f
        where f.user_id = (select auth.uid())
          and f.friend_user_id = visits.user_id
      )
    )
  );

alter policy "Likes visible based on visit visibility and friendships"
  on public.likes
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1
      from public.visits v
      where v.id = likes.visit_id
        and (
          v.visibility = 'everyone'
          or v.user_id = (select auth.uid())
          or (
            v.visibility = 'friends'
            and (select auth.uid()) is not null
            and exists (
              select 1
              from public.friends f
              where f.user_id = (select auth.uid())
                and f.friend_user_id = v.user_id
            )
          )
        )
    )
  );

alter policy "Comments visible based on visit visibility and friendships"
  on public.comments
  using (
    (select auth.uid()) = user_id
    or exists (
      select 1
      from public.visits v
      where v.id = comments.visit_id
        and (
          v.visibility = 'everyone'
          or v.user_id = (select auth.uid())
          or (
            v.visibility = 'friends'
            and (select auth.uid()) is not null
            and exists (
              select 1
              from public.friends f
              where f.user_id = (select auth.uid())
                and f.friend_user_id = v.user_id
            )
          )
        )
    )
  );

alter policy "Users can view their own cafe states"
  on public.user_cafe_states
  using ((select auth.uid()) = user_id);
