-- People suggestions v2. Suggestions are useful by default while preserving
-- explicit opt-outs, and ranking now includes mutual, shared-context, and
-- recent visible interaction signals. No phone or address-book data is stored.

alter table private.discovery_preferences
  alter column suggestions_enabled set default true,
  alter column mutual_explanations_enabled set default true;

create or replace function private.discovery_preferences_for_v1(p_user_id uuid)
returns private.discovery_preferences
language plpgsql stable security definer set search_path = '' as $$
declare result private.discovery_preferences;
begin
  select * into result from private.discovery_preferences where user_id = p_user_id;
  if not found then
    result.user_id := p_user_id;
    result.email_discoverable := false;
    result.suggestions_enabled := true;
    result.mutual_explanations_enabled := true;
    result.version := 0;
  end if;
  return result;
end;
$$;
revoke all on function private.discovery_preferences_for_v1(uuid)
  from public, anon, authenticated;

create index if not exists likes_people_suggestions_idx
  on public.likes(user_id, created_at desc, visit_id);
create index if not exists comments_people_suggestions_idx
  on public.comments(user_id, created_at desc, visit_id)
  where removed_at is null;
create index if not exists visit_reactions_people_suggestions_idx
  on public.visit_reactions(user_id, created_at desc, visit_id);

create or replace function public.get_people_suggestions_v1(p_limit integer default 10)
returns table (
  id uuid, display_name text, username text, avatar_url text,
  friendship_state text, mutual_friend_count bigint,
  reason text, ranking_version text
)
language sql stable security definer set search_path = '' as $$
  with actor as (
    select auth.uid() id,
      (private.discovery_preferences_for_v1(auth.uid())).suggestions_enabled suggestions_enabled,
      (private.discovery_preferences_for_v1(auth.uid())).mutual_explanations_enabled mutual_explanations_enabled
  ), engagement_edges as (
    select like_row.user_id actor_id, visit.user_id owner_id,
      like_row.visit_id, like_row.created_at
    from public.likes like_row
    join public.visits visit on visit.id = like_row.visit_id
    where like_row.created_at >= now() - interval '180 days'
    union all
    select comment.user_id, visit.user_id, comment.visit_id, comment.created_at
    from public.comments comment
    join public.visits visit on visit.id = comment.visit_id
    where comment.removed_at is null
      and comment.created_at >= now() - interval '180 days'
    union all
    select reaction.user_id, visit.user_id, reaction.visit_id, reaction.created_at
    from public.visit_reactions reaction
    join public.visits visit on visit.id = reaction.visit_id
    where reaction.created_at >= now() - interval '180 days'
  ), candidates as (
    select tag.added_by candidate_id, 0 priority, 'shared_mugshot'::text reason,
      visit.created_at signal_at
    from actor
    join public.visit_companions tag on tag.companion_user_id = actor.id
    join public.visits visit on visit.id = tag.visit_id
    where private.can_view_visit_as(tag.visit_id, actor.id)
    union all
    select theirs.user_id, 1, 'mutual_friends', now()
    from actor
    join public.friends mine on mine.user_id = actor.id
    join public.friends theirs on theirs.friend_user_id = mine.friend_user_id
      and theirs.user_id <> actor.id
    union all
    select edge.actor_id, 2, 'interacted_with_you', edge.created_at
    from actor
    join engagement_edges edge on edge.owner_id = actor.id
    where edge.actor_id <> actor.id
      and private.can_view_visit_as(edge.visit_id, actor.id)
    union all
    select edge.owner_id, 3, 'you_interacted', edge.created_at
    from actor
    join engagement_edges edge on edge.actor_id = actor.id
    where edge.owner_id <> actor.id
      and private.can_view_visit_as(edge.visit_id, actor.id)
    union all
    select other.user_id, 4, 'shared_list', now()
    from actor
    join public.cafe_list_members mine on mine.user_id = actor.id
      and mine.invitation_status = 'accepted'
    join public.cafe_list_members other on other.list_id = mine.list_id
      and other.invitation_status = 'accepted' and other.user_id <> actor.id
  ), eligible as (
    select candidate.candidate_id, min(candidate.priority) priority,
      (array_agg(candidate.reason order by candidate.priority, candidate.signal_at desc))[1] reason,
      max(candidate.signal_at) signal_at
    from candidates candidate
    cross join actor
    left join private.discovery_preferences preference
      on preference.user_id = candidate.candidate_id
    where actor.suggestions_enabled
      and coalesce(preference.suggestions_enabled, true)
      and candidate.candidate_id <> actor.id
      and private.discovery_capability_enabled_v1('suggestions')
      and private.can_view_user_as(candidate.candidate_id, actor.id)
      and not private.confirmed_friends(actor.id, candidate.candidate_id)
      and not exists(select 1 from public.friend_requests request
        where request.status = 'pending'
          and least(request.from_user_id, request.to_user_id) = least(actor.id, candidate.candidate_id)
          and greatest(request.from_user_id, request.to_user_id) = greatest(actor.id, candidate.candidate_id))
      and not exists(select 1 from private.discovery_suppressions suppression
        where suppression.viewer_id = actor.id
          and suppression.candidate_id = candidate.candidate_id
          and suppression.expires_at > now())
    group by candidate.candidate_id
  ), ranked as (
    select eligible.*, profile.display_name, profile.username, profile.avatar_url,
      case when actor.mutual_explanations_enabled then (
        select count(*) from public.friends mine
        join public.friends theirs
          on theirs.user_id = eligible.candidate_id
         and theirs.friend_user_id = mine.friend_user_id
        where mine.user_id = actor.id
          and private.can_view_user_as(mine.friend_user_id, actor.id)
          and not private.blocked_between(actor.id, mine.friend_user_id)
      ) else 0 end mutual_count,
      actor.mutual_explanations_enabled
    from eligible
    join public.users profile on profile.id = eligible.candidate_id
    cross join actor
  )
  select ranked.candidate_id, ranked.display_name, ranked.username, ranked.avatar_url,
    'none'::text, ranked.mutual_count,
    case
      when ranked.reason = 'mutual_friends' and not ranked.mutual_explanations_enabled
        then 'people_you_may_know'
      else ranked.reason
    end,
    'people_v2'::text
  from ranked
  order by ranked.priority, ranked.mutual_count desc, ranked.signal_at desc, ranked.candidate_id
  limit least(greatest(p_limit, 1), 20);
$$;

revoke all on function public.get_people_suggestions_v1(integer) from public, anon;
grant execute on function public.get_people_suggestions_v1(integer) to authenticated;
