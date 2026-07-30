-- A user's own sip should not be described as a cross-person taste match.

create or replace function public.ranked_feed(
  p_scope text default 'ranked',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_limit integer default 20,
  p_after_score double precision default null,
  p_after_created_at timestamptz default null,
  p_after_id uuid default null
)
returns table (
  visit_id uuid, user_id uuid, cafe_id uuid, caption text, drink_name text,
  overall_score double precision, poster_photo_url text, created_at timestamptz,
  author_display_name text, author_username text, author_avatar_url text,
  cafe_name text, like_count bigint, comment_count bigint,
  feed_score double precision, ranking_reason text, reason_type text
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (select auth.uid() viewer), base as (
    select v.*,u.display_name,u.username,u.avatar_url,c.name cafe_name,c.latitude,c.longitude,
      (select count(*) from public.likes l where l.visit_id=v.id) likes,
      (select count(*) from public.comments cm where cm.visit_id=v.id) comments,
      case when private.confirmed_friends(i.viewer,v.user_id) then 1.0 when v.user_id=i.viewer then 1.0 else .35 end relationship,
      exp(-extract(epoch from (now()-v.created_at))/86400/14) recency,
      case when p_latitude between -90 and 90 and p_longitude between -180 and 180 and c.latitude is not null then
        greatest(0,1-(6371*2*asin(sqrt(power(sin(radians(c.latitude-p_latitude)/2),2)+cos(radians(p_latitude))*cos(radians(c.latitude))*power(sin(radians(c.longitude-p_longitude)/2),2))))/100)
      end geo,
      exists(select 1 from public.visits mine where mine.user_id=i.viewer and coalesce(mine.drink_subtype,mine.drink_type)=coalesce(v.drink_subtype,v.drink_type)) affinity,
      exists(select 1 from public.user_cafe_states saved where saved.user_id=i.viewer and saved.cafe_id=v.cafe_id and (saved.is_favorite or saved.want_to_try)) saved_match,
      v.user_id <> i.viewer and exists(
        select 1
        from public.taste_signals mine
        join public.taste_signals theirs
          on theirs.signal_type=mine.signal_type and theirs.attribute=mine.attribute
        where mine.user_id=i.viewer and theirs.user_id=v.user_id
          and mine.owner_state<>'dismissed' and theirs.owner_state<>'dismissed'
          and mine.support_count>=3 and theirs.support_count>=3
      ) taste_match
    from public.visits v cross join input i join public.users u on u.id=v.user_id
    left join public.cafes c on c.id=v.cafe_id
    where private.can_view_visit_as(v.id,i.viewer)
      and case p_scope when 'friends' then private.confirmed_friends(i.viewer,v.user_id)
                       when 'everyone' then v.visibility='everyone'
                       when 'ranked' then true else false end
  ), scored as (
    select b.*, (.32*relationship + .23*recency + .13*least((likes+comments*2)::double precision/10,1)
      + .12*(case when affinity then 1 else 0 end)
      + .10*(case when taste_match then 1 else 0 end)
      + coalesce(.10*geo,0))
      / (case when geo is null then .90 else 1 end) score
    from base b
  )
  select s.id,s.user_id,s.cafe_id,s.caption,coalesce(s.drink_subtype,s.drink_type),s.overall_score,
    s.poster_photo_url,s.created_at,s.display_name,s.username,s.avatar_url,s.cafe_name,s.likes,s.comments,s.score,
    case when s.relationship=1 and s.user_id<>(select viewer from input) then 'A sip from your friend'
         when s.taste_match then 'Matches patterns in your Taste Identity'
         when s.saved_match then 'From a cafe you saved'
         when s.affinity then 'Inspired by drinks in your journal'
         else 'A recent sip from the Mugshot community' end,
    case when s.relationship=1 and s.user_id<>(select viewer from input) then 'friend_activity'
         when s.taste_match then 'taste_match'
         when s.saved_match then 'saved_cafe'
         when s.affinity then 'journal_evidence'
         else 'recent_community' end
  from scored s
  where p_after_score is null or (s.score,s.created_at,s.id)<(p_after_score,p_after_created_at,p_after_id)
  order by s.score desc,s.created_at desc,s.id desc
  limit least(greatest(p_limit,1),50);
$$;

revoke all on function public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid)
  from public, anon;
grant execute on function public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid)
  to authenticated;
;
