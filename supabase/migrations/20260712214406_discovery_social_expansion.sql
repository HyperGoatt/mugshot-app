-- Secure discovery and social expansion.
-- Coordinates are request parameters only and are never persisted.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- Push delivery is deferred. Keep the legacy trigger installed for provenance,
-- but disabled and unreachable from the Data API.
alter table public.notifications disable trigger on_notification_insert;
revoke all on function public.send_push_notification_trigger() from public, anon, authenticated;

alter function public.update_user_devices_updated_at() set search_path = '';
alter function public.set_updated_at() set search_path = '';

create index if not exists reports_target_user_idx on public.reports (target_user_id)
  where target_user_id is not null;
create index if not exists reports_target_visit_idx on public.reports (target_visit_id)
  where target_visit_id is not null;
create index if not exists reports_target_comment_idx on public.reports (target_comment_id)
  where target_comment_id is not null;
create index if not exists likes_visit_created_idx on public.likes (visit_id, created_at desc, id desc);
create index if not exists user_cafe_states_saved_idx
  on public.user_cafe_states (user_id, updated_at desc, cafe_id)
  where is_favorite or want_to_try;

create table if not exists public.comment_mentions (
  comment_id uuid not null references public.comments(id) on delete cascade,
  mentioned_user_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (comment_id, mentioned_user_id)
);
create index if not exists comment_mentions_user_created_idx
  on public.comment_mentions (mentioned_user_id, created_at desc, comment_id);
alter table public.comment_mentions enable row level security;
revoke all on table public.comment_mentions from public, anon, authenticated;
grant select on table public.comment_mentions to authenticated;

create or replace function private.blocked_between(p_first uuid, p_second uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_first is null or p_second is null or exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = p_first and b.blocked_id = p_second)
       or (b.blocker_id = p_second and b.blocked_id = p_first)
  );
$$;

create or replace function private.confirmed_friends(p_first uuid, p_second uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_first = p_second or (
    not private.blocked_between(p_first, p_second)
    and exists (
      select 1 from public.friends f
      where f.user_id = p_first and f.friend_user_id = p_second
    )
    and exists (
      select 1 from public.friends f
      where f.user_id = p_second and f.friend_user_id = p_first
    )
  );
$$;

create or replace function private.can_view_visit_as(p_visit_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.visits v
    where v.id = p_visit_id
      and (v.upload_state = 'complete' or v.user_id = p_viewer)
      and not private.blocked_between(p_viewer, v.user_id)
      and (
        v.user_id = p_viewer
        or v.visibility = 'everyone'
        or (v.visibility = 'friends' and private.confirmed_friends(p_viewer, v.user_id))
      )
  );
$$;

revoke all on function private.blocked_between(uuid, uuid) from public, anon, authenticated;
revoke all on function private.confirmed_friends(uuid, uuid) from public, anon, authenticated;
revoke all on function private.can_view_visit_as(uuid, uuid) from public, anon, authenticated;

create or replace function public.is_blocked_between(p_first uuid, p_second uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    ((select auth.uid()) = p_first or (select auth.uid()) = p_second)
    and private.blocked_between(p_first, p_second);
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
    and private.confirmed_friends(p_first, p_second);
$$;

create or replace function public.can_view_visit(p_visit_id uuid, p_viewer uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer = (select auth.uid())
    and private.can_view_visit_as(p_visit_id, p_viewer);
$$;

create policy "Visible comment mentions" on public.comment_mentions
  for select to authenticated using (
    exists (
      select 1 from public.comments c
      where c.id = comment_id
        and public.can_view_visit(c.visit_id, (select auth.uid()))
        and not public.is_blocked_between((select auth.uid()), mentioned_user_id)
    )
  );

create or replace function public.submit_report(
  p_reason public.report_reason,
  p_details text default null,
  p_target_user_id uuid default null,
  p_target_visit_id uuid default null,
  p_target_comment_id uuid default null
)
returns public.reports
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_report public.reports;
begin
  if v_actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if num_nonnulls(p_target_user_id, p_target_visit_id, p_target_comment_id) <> 1 then
    raise exception 'exactly one report target is required' using errcode = '22023';
  end if;
  if p_target_user_id = v_actor then raise exception 'cannot report yourself' using errcode = '22023'; end if;
  if p_target_visit_id is not null and not private.can_view_visit_as(p_target_visit_id, v_actor) then
    raise exception 'target unavailable' using errcode = '42501';
  end if;
  if p_target_comment_id is not null and not exists (
    select 1 from public.comments c
    where c.id = p_target_comment_id and private.can_view_visit_as(c.visit_id, v_actor)
  ) then raise exception 'target unavailable' using errcode = '42501'; end if;

  insert into public.reports (
    reporter_id, target_user_id, target_visit_id, target_comment_id, reason, details
  ) values (
    v_actor, p_target_user_id, p_target_visit_id, p_target_comment_id,
    p_reason, nullif(trim(p_details), '')
  ) returning * into v_report;
  return v_report;
end;
$$;

create or replace function public.enforce_one_level_comment_reply()
returns trigger
language plpgsql
set search_path = ''
as $$
declare v_parent public.comments;
begin
  if new.parent_comment_id is null then return new; end if;
  select * into v_parent from public.comments where id = new.parent_comment_id;
  if not found or v_parent.visit_id <> new.visit_id then
    raise exception 'reply parent must belong to the same visit' using errcode = '23514';
  end if;
  if v_parent.parent_comment_id is not null then
    raise exception 'comment replies are limited to one level' using errcode = '23514';
  end if;
  return new;
end;
$$;

drop trigger if exists comments_enforce_one_level_reply on public.comments;
create trigger comments_enforce_one_level_reply
  before insert or update of parent_comment_id, visit_id on public.comments
  for each row execute function public.enforce_one_level_comment_reply();
revoke all on function public.enforce_one_level_comment_reply() from public, anon, authenticated;

create or replace function public.create_comment(
  p_visit_id uuid,
  p_text text,
  p_parent_comment_id uuid default null,
  p_mentioned_user_ids uuid[] default '{}'::uuid[]
)
returns public.comments
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_comment public.comments;
  v_mentioned uuid;
begin
  if v_actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if char_length(trim(coalesce(p_text, ''))) not between 1 and 2000 then
    raise exception 'comment must be between 1 and 2000 characters' using errcode = '22023';
  end if;
  if not private.can_view_visit_as(p_visit_id, v_actor) then
    raise exception 'visit unavailable' using errcode = '42501';
  end if;

  insert into public.comments (user_id, visit_id, text, parent_comment_id)
  values (v_actor, p_visit_id, trim(p_text), p_parent_comment_id)
  returning * into v_comment;

  foreach v_mentioned in array coalesce(p_mentioned_user_ids, '{}'::uuid[]) loop
    if not exists (select 1 from public.users u where u.id = v_mentioned)
       or private.blocked_between(v_actor, v_mentioned)
       or not private.can_view_visit_as(p_visit_id, v_mentioned) then
      raise exception 'invalid mention target' using errcode = '42501';
    end if;
    insert into public.comment_mentions (comment_id, mentioned_user_id)
    values (v_comment.id, v_mentioned) on conflict do nothing;
  end loop;
  return v_comment;
end;
$$;

create or replace function public.search_users(
  p_query text,
  p_limit integer default 20,
  p_after_rank integer default null,
  p_after_score real default null,
  p_after_username text default null,
  p_after_id uuid default null
)
returns table (
  id uuid, display_name text, username text, bio text, location text,
  favorite_drink text, avatar_url text, banner_url text,
  friendship_state text, mutual_friend_count bigint,
  rank_bucket integer, match_score real
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (
    select lower(trim(p_query)) q, least(greatest(p_limit, 1), 50) page_size,
           (select auth.uid()) viewer
  ), ranked as (
    select u.*,
      case
        when lower(trim(u.username)) = i.q then 0
        when lower(trim(u.username)) like i.q || '%' then 1
        when lower(trim(u.display_name)) like i.q || '%' then 2
        else 3
      end rank_bucket,
      greatest(
        extensions.similarity(lower(trim(u.username)), i.q),
        extensions.similarity(lower(trim(u.display_name)), i.q)
      )::real match_score,
      case
        when private.confirmed_friends(i.viewer, u.id) then 'friends'
        when exists (select 1 from public.friend_requests r where r.from_user_id=i.viewer and r.to_user_id=u.id and r.status='pending') then 'outgoing'
        when exists (select 1 from public.friend_requests r where r.from_user_id=u.id and r.to_user_id=i.viewer and r.status='pending') then 'incoming'
        else 'none'
      end friendship_state,
      (select count(*) from public.friends mine
       join public.friends theirs on theirs.user_id=u.id and theirs.friend_user_id=mine.friend_user_id
       where mine.user_id=i.viewer
         and not private.blocked_between(i.viewer, mine.friend_user_id)) mutual_friend_count
    from public.users u cross join input i
    where i.viewer is not null and u.id <> i.viewer
      and not private.blocked_between(i.viewer, u.id)
      and (i.q <> '')
      and (
        lower(trim(u.username)) like i.q || '%'
        or lower(trim(u.display_name)) like i.q || '%'
        or extensions.similarity(lower(trim(u.username)), i.q) >= 0.2
        or extensions.similarity(lower(trim(u.display_name)), i.q) >= 0.2
      )
  )
  select r.id, r.display_name, r.username, r.bio, r.location,
         r.favorite_drink, r.avatar_url, r.banner_url,
         r.friendship_state, r.mutual_friend_count, r.rank_bucket, r.match_score
  from ranked r, input i
  where p_after_rank is null or
    (r.rank_bucket, -r.match_score, lower(r.username), r.id) >
    (p_after_rank, -coalesce(p_after_score,0), lower(coalesce(p_after_username,'')), p_after_id)
  order by r.rank_bucket, r.match_score desc, lower(r.username), r.id
  limit (select page_size from input);
$$;

create or replace function public.list_social_connections(
  p_kind text,
  p_limit integer default 30,
  p_after_created_at timestamptz default null,
  p_after_id uuid default null
)
returns table (
  relationship_id uuid, user_id uuid, display_name text, username text,
  avatar_url text, created_at timestamptz, kind text
)
language sql
stable
security definer
set search_path = ''
as $$
  with viewer as (select auth.uid() id), rows as (
    select f.id relationship_id, f.friend_user_id user_id, u.display_name, u.username,
      u.avatar_url, f.created_at, 'friends'::text kind
    from public.friends f join viewer v on f.user_id=v.id
    join public.users u on u.id=f.friend_user_id
    where p_kind='friends' and not private.blocked_between(v.id,u.id)
    union all
    select r.id, r.from_user_id, u.display_name, u.username, u.avatar_url, r.created_at, 'incoming'
    from public.friend_requests r join viewer v on r.to_user_id=v.id
    join public.users u on u.id=r.from_user_id
    where p_kind='incoming' and r.status='pending' and not private.blocked_between(v.id,u.id)
    union all
    select r.id, r.to_user_id, u.display_name, u.username, u.avatar_url, r.created_at, 'outgoing'
    from public.friend_requests r join viewer v on r.from_user_id=v.id
    join public.users u on u.id=r.to_user_id
    where p_kind='outgoing' and r.status='pending' and not private.blocked_between(v.id,u.id)
    union all
    select u.id, b.blocked_id, u.display_name, u.username, u.avatar_url, b.created_at, 'blocked'
    from public.user_blocks b join viewer v on b.blocker_id=v.id
    join public.users u on u.id=b.blocked_id
    where p_kind='blocked'
  )
  select * from rows
  where p_after_created_at is null or (created_at,relationship_id) < (p_after_created_at,p_after_id)
  order by created_at desc, relationship_id desc
  limit least(greatest(p_limit,1),50);
$$;

create or replace function public.get_public_profile(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare v_viewer uuid := auth.uid(); v_result jsonb;
begin
  if v_viewer is null then raise exception 'authentication required' using errcode='28000'; end if;
  if private.blocked_between(v_viewer,p_user_id) then raise exception 'profile unavailable' using errcode='42501'; end if;
  select jsonb_build_object(
    'profile', to_jsonb(u),
    'friendship_state', case
      when v_viewer=p_user_id then 'self'
      when private.confirmed_friends(v_viewer,p_user_id) then 'friends'
      when exists(select 1 from public.friend_requests r where r.from_user_id=v_viewer and r.to_user_id=p_user_id and r.status='pending') then 'outgoing'
      when exists(select 1 from public.friend_requests r where r.from_user_id=p_user_id and r.to_user_id=v_viewer and r.status='pending') then 'incoming'
      else 'none' end,
    'stats', jsonb_build_object(
      'visible_visits', (select count(*) from public.visits v where v.user_id=p_user_id and private.can_view_visit_as(v.id,v_viewer)),
      'friends', (select count(*) from public.friends f where f.user_id=p_user_id),
      'cafes', (select count(distinct v.cafe_id) from public.visits v where v.user_id=p_user_id and v.cafe_id is not null and private.can_view_visit_as(v.id,v_viewer))
    ),
    'visits', coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc)
      from (select v.id,v.cafe_id,v.caption,v.drink_type,v.drink_subtype,v.overall_score,v.poster_photo_url,v.created_at,
                   c.name cafe_name,c.latitude,c.longitude,c.identity_key
            from public.visits v join public.cafes c on c.id=v.cafe_id
            where v.user_id=p_user_id and v.cafe_id is not null
              and private.can_view_visit_as(v.id,v_viewer)
            order by v.created_at desc,v.id desc limit 50) x), '[]'::jsonb)
  ) into v_result from public.users u where u.id=p_user_id;
  if v_result is null then raise exception 'profile unavailable' using errcode='P0002'; end if;
  return v_result;
end;
$$;

create or replace function public.discover_cafes(
  p_section text default 'nearby',
  p_latitude double precision default null,
  p_longitude double precision default null,
  p_radius_km double precision default 25,
  p_limit integer default 20,
  p_after_score double precision default null,
  p_after_id uuid default null
)
returns table (
  cafe_id uuid, name text, address text, city text, latitude double precision,
  longitude double precision, identity_key text, section text,
  ranking_score double precision, ranking_reason text, distance_km double precision,
  average_rating double precision, visible_visit_count bigint, friend_count bigint,
  top_drinks jsonb, recent_cover text, is_saved boolean, is_visited boolean
)
language sql
stable
security definer
set search_path = ''
as $$
  with input as (
    select auth.uid() viewer,
      case when p_latitude between -90 and 90 and p_longitude between -180 and 180 then p_latitude end lat,
      case when p_latitude between -90 and 90 and p_longitude between -180 and 180 then p_longitude end lon,
      least(greatest(coalesce(p_radius_km,25),1),100) radius,
      least(greatest(p_limit,1),50) page_size
  ), visible as (
    select v.* from public.visits v,input i
    where v.cafe_id is not null and private.can_view_visit_as(v.id,i.viewer)
  ), own_affinity as (
    select coalesce(v.drink_subtype,v.drink_type) drink, count(*) n
    from public.visits v,input i where v.user_id=i.viewer and v.upload_state='complete'
    group by coalesce(v.drink_subtype,v.drink_type)
  ), aggregates as (
    select c.*,
      case when i.lat is null then null else
        6371 * 2 * asin(sqrt(
          power(sin(radians(c.latitude-i.lat)/2),2) + cos(radians(i.lat))*cos(radians(c.latitude))*power(sin(radians(c.longitude-i.lon)/2),2)
        )) end distance,
      count(v.id) visit_count,
      avg(v.overall_score) avg_rating,
      count(v.id) filter(where v.created_at >= now()-interval '30 days') recent_count,
      count(distinct v.user_id) filter(where private.confirmed_friends(i.viewer,v.user_id)) friend_count,
      max(v.poster_photo_url) filter(where v.poster_photo_url is not null) recent_cover,
      coalesce(bool_or(s.user_id=i.viewer and (s.is_favorite or s.want_to_try)),false) saved,
      coalesce(bool_or(v.user_id=i.viewer),false) visited,
      coalesce((select jsonb_agg(jsonb_build_object('name',d.drink,'count',d.n) order by d.n desc,d.drink)
        from (select coalesce(vd.drink_subtype,vd.drink_type) drink,count(*) n from visible vd
              where vd.cafe_id=c.id and coalesce(vd.drink_subtype,vd.drink_type) is not null
              group by 1 order by 2 desc,1 limit 3) d),'[]'::jsonb) drinks,
      exists(select 1 from visible va join own_affinity oa on oa.drink=coalesce(va.drink_subtype,va.drink_type) where va.cafe_id=c.id) affinity
    from public.cafes c cross join input i
    left join visible v on v.cafe_id=c.id
    left join public.user_cafe_states s on s.cafe_id=c.id and s.user_id=i.viewer
    where i.viewer is not null and c.latitude is not null and c.longitude is not null
    group by c.id,i.viewer,i.lat,i.lon
  ), scored as (
    select a.*,
      ((case when a.distance is null then 0 else .35*greatest(0,1-a.distance/i.radius) end)
       + .25*least(a.friend_count::double precision/3,1)
       + .20*((coalesce(a.avg_rating,3.5)*a.visit_count + 17.5)/(a.visit_count+5)/5)
       + .15*least(a.recent_count::double precision/5,1)
       + (case when exists(select 1 from own_affinity) then .05*(case when a.affinity then 1 else 0 end) else 0 end))
      / nullif((case when a.distance is null then 0 else .35 end)+.25+.20+.15+
               (case when exists(select 1 from own_affinity) then .05 else 0 end),0) score,
      i.radius
    from aggregates a cross join input i
  ), filtered as (
    select s.*, case
      when p_section='loved_by_friends' then 'Loved by friends'
      when p_section='popular_drinks' then 'Popular drinks here'
      when p_section='trending' then 'Trending this month'
      when p_section='saved' then 'Saved for later'
      when p_section='visited' then 'From your coffee journal'
      when s.distance is null then 'Popular with the Mugshot community'
      else 'Great match nearby' end reason
    from scored s
    where (s.distance is null or s.distance <= s.radius)
      and case p_section
        when 'nearby' then true
        when 'loved_by_friends' then s.friend_count>0
        when 'popular_drinks' then s.drinks<>'[]'::jsonb
        when 'trending' then s.recent_count>0
        when 'saved' then s.saved
        when 'visited' then s.visited
        else false end
  )
  select f.id,f.name,f.address,f.city,f.latitude,f.longitude,f.identity_key,p_section,
    f.score,f.reason,f.distance,f.avg_rating,f.visit_count,f.friend_count,
    f.drinks,f.recent_cover,f.saved,f.visited
  from filtered f
  where p_after_score is null or (f.score,f.id) < (p_after_score,p_after_id)
  order by f.score desc,f.id desc
  limit (select page_size from input);
$$;

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
  feed_score double precision, ranking_reason text
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
      exists(select 1 from public.visits mine where mine.user_id=i.viewer and coalesce(mine.drink_subtype,mine.drink_type)=coalesce(v.drink_subtype,v.drink_type)) affinity
    from public.visits v cross join input i join public.users u on u.id=v.user_id
    left join public.cafes c on c.id=v.cafe_id
    where private.can_view_visit_as(v.id,i.viewer)
      and case p_scope when 'friends' then private.confirmed_friends(i.viewer,v.user_id)
                       when 'everyone' then v.visibility='everyone'
                       when 'ranked' then true else false end
  ), scored as (
    select b.*, (.35*relationship + .25*recency + .15*least((likes+comments*2)::double precision/10,1)
      + .15*(case when affinity then 1 else 0 end) + coalesce(.10*geo,0))
      / (case when geo is null then .90 else 1 end) score
    from base b
  )
  select s.id,s.user_id,s.cafe_id,s.caption,coalesce(s.drink_subtype,s.drink_type),s.overall_score,
    s.poster_photo_url,s.created_at,s.display_name,s.username,s.avatar_url,s.cafe_name,s.likes,s.comments,s.score,
    case when s.relationship=1 then 'From a friend' when s.likes+s.comments>0 then 'Coffee people are talking' else 'Fresh from the community' end
  from scored s
  where p_after_score is null or (s.score,s.created_at,s.id)<(p_after_score,p_after_created_at,p_after_id)
  order by s.score desc,s.created_at desc,s.id desc
  limit least(greatest(p_limit,1),50);
$$;

-- Caller-bound RPCs are the only mutation surface for reports, comments, and
-- relationships. Read APIs are signed-in only and enforce mutual invisibility.
revoke all on function public.submit_report(public.report_reason,text,uuid,uuid,uuid) from public, anon;
revoke all on function public.create_comment(uuid,text,uuid,uuid[]) from public, anon;
revoke all on function public.search_users(text,integer,integer,real,text,uuid) from public, anon;
revoke all on function public.list_social_connections(text,integer,timestamptz,uuid) from public, anon;
revoke all on function public.get_public_profile(uuid) from public, anon;
revoke all on function public.discover_cafes(text,double precision,double precision,double precision,integer,double precision,uuid) from public, anon;
revoke all on function public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid) from public, anon;
grant execute on function public.submit_report(public.report_reason,text,uuid,uuid,uuid) to authenticated;
grant execute on function public.create_comment(uuid,text,uuid,uuid[]) to authenticated;
grant execute on function public.search_users(text,integer,integer,real,text,uuid) to authenticated;
grant execute on function public.list_social_connections(text,integer,timestamptz,uuid) to authenticated;
grant execute on function public.get_public_profile(uuid) to authenticated;
grant execute on function public.discover_cafes(text,double precision,double precision,double precision,integer,double precision,uuid) to authenticated;
grant execute on function public.ranked_feed(text,double precision,double precision,integer,double precision,timestamptz,uuid) to authenticated;

-- Direct comment inserts cannot create durable, validated mention links.
revoke insert on table public.comments from authenticated;
revoke insert on table public.reports from authenticated;

-- Comments and likes remain mutually invisible when the actor is blocked, even
-- if legacy data somehow references otherwise visible content.
drop policy if exists "Visible comments" on public.comments;
create policy "Visible comments" on public.comments for select to authenticated using (
  public.can_view_visit(visit_id,(select auth.uid()))
  and not public.is_blocked_between((select auth.uid()),user_id)
);
drop policy if exists "Visible likes" on public.likes;
create policy "Visible likes" on public.likes for select to authenticated using (
  public.can_view_visit(visit_id,(select auth.uid()))
  and not public.is_blocked_between((select auth.uid()),user_id)
);
;
