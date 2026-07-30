-- Mugshot social foundation. All graph mutations are authenticated RPCs;
-- tables remain readable only to the participants allowed by RLS.

create extension if not exists pg_trgm with schema extensions;
create table if not exists public.user_blocks (
  blocker_id uuid not null references public.users(id) on delete cascade,
  blocked_id uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  constraint user_blocks_no_self check (blocker_id <> blocked_id)
);
create type public.report_reason as enum (
  'spam', 'harassment', 'inappropriate_content', 'impersonation', 'privacy', 'other'
);
create type public.report_status as enum ('pending', 'reviewing', 'resolved', 'dismissed');
create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references public.users(id) on delete cascade,
  target_user_id uuid references public.users(id) on delete cascade,
  target_visit_id uuid references public.visits(id) on delete cascade,
  target_comment_id uuid references public.comments(id) on delete cascade,
  reason public.report_reason not null,
  details text,
  status public.report_status not null default 'pending',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz,
  constraint reports_exactly_one_target check (
    num_nonnulls(target_user_id, target_visit_id, target_comment_id) = 1
  ),
  constraint reports_details_length check (char_length(coalesce(details, '')) <= 2000)
);
create index if not exists user_blocks_blocked_blocker_idx
  on public.user_blocks (blocked_id, blocker_id);
create index if not exists reports_reporter_created_idx
  on public.reports (reporter_id, created_at desc, id desc);
create index if not exists friends_reverse_lookup_idx
  on public.friends (friend_user_id, user_id);
create index if not exists friend_requests_recipient_status_created_idx
  on public.friend_requests (to_user_id, status, created_at desc, id desc);
create index if not exists friend_requests_sender_status_created_idx
  on public.friend_requests (from_user_id, status, created_at desc, id desc);
create unique index if not exists friend_requests_one_pending_pair_idx
  on public.friend_requests (least(from_user_id, to_user_id), greatest(from_user_id, to_user_id))
  where status = 'pending';
create index if not exists users_username_normalized_trgm_idx
  on public.users using gin (lower(trim(username)) extensions.gin_trgm_ops);
create index if not exists users_display_name_normalized_trgm_idx
  on public.users using gin (lower(trim(display_name)) extensions.gin_trgm_ops);
create index if not exists visits_visible_cafe_created_idx
  on public.visits (cafe_id, created_at desc, id desc)
  include (user_id, visibility, overall_score)
  where upload_state = 'complete';
create index if not exists comments_visit_parent_created_idx
  on public.comments (visit_id, parent_comment_id, created_at, id);
alter table public.user_blocks enable row level security;
alter table public.reports enable row level security;
create or replace function public.is_blocked_between(p_first uuid, p_second uuid)
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
create or replace function public.is_confirmed_friend(p_first uuid, p_second uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_first = p_second or (
    not public.is_blocked_between(p_first, p_second)
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
create or replace function public.can_view_visit(p_visit_id uuid, p_viewer uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
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
create or replace function public.send_friend_request(p_target_user_id uuid)
returns public.friend_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_request public.friend_requests;
begin
  if v_actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_target_user_id is null or p_target_user_id = v_actor then
    raise exception 'invalid friend request target' using errcode = '22023';
  end if;
  if public.is_blocked_between(v_actor, p_target_user_id) then
    raise exception 'user unavailable' using errcode = '42501';
  end if;
  if public.is_confirmed_friend(v_actor, p_target_user_id) then
    raise exception 'already friends' using errcode = '23505';
  end if;

  select * into v_request
  from public.friend_requests r
  where r.status = 'pending'
    and least(r.from_user_id, r.to_user_id) = least(v_actor, p_target_user_id)
    and greatest(r.from_user_id, r.to_user_id) = greatest(v_actor, p_target_user_id)
  for update;

  if found then return v_request; end if;

  insert into public.friend_requests (from_user_id, to_user_id, status)
  values (v_actor, p_target_user_id, 'pending')
  returning * into v_request;
  return v_request;
end;
$$;
create or replace function public.respond_friend_request(p_request_id uuid, p_accept boolean)
returns public.friend_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_request public.friend_requests;
begin
  if v_actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  select * into v_request from public.friend_requests
  where id = p_request_id for update;
  if not found or v_request.to_user_id <> v_actor then
    raise exception 'request unavailable' using errcode = '42501';
  end if;
  if v_request.status <> 'pending' then
    raise exception 'request already resolved' using errcode = '55000';
  end if;
  if public.is_blocked_between(v_request.from_user_id, v_request.to_user_id) then
    raise exception 'user unavailable' using errcode = '42501';
  end if;

  update public.friend_requests
  set status = case when p_accept then 'accepted' else 'rejected' end
  where id = p_request_id returning * into v_request;

  if p_accept then
    insert into public.friends (user_id, friend_user_id)
    values (v_request.from_user_id, v_request.to_user_id),
           (v_request.to_user_id, v_request.from_user_id)
    on conflict do nothing;
  end if;
  return v_request;
end;
$$;
create or replace function public.cancel_friend_request(p_request_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  delete from public.friend_requests
  where id = p_request_id and from_user_id = v_actor and status = 'pending';
  if not found then raise exception 'request unavailable' using errcode = '42501'; end if;
end;
$$;
create or replace function public.remove_friendship(p_other_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_other_user_id is null or p_other_user_id = v_actor then raise exception 'invalid user' using errcode = '22023'; end if;
  delete from public.friends
  where (user_id = v_actor and friend_user_id = p_other_user_id)
     or (user_id = p_other_user_id and friend_user_id = v_actor);
  delete from public.friend_requests
  where (from_user_id = v_actor and to_user_id = p_other_user_id)
     or (from_user_id = p_other_user_id and to_user_id = v_actor);
end;
$$;
create or replace function public.block_user(p_blocked_user_id uuid)
returns public.user_blocks
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor uuid := auth.uid(); v_block public.user_blocks;
begin
  if v_actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if p_blocked_user_id is null or p_blocked_user_id = v_actor then raise exception 'invalid user' using errcode = '22023'; end if;
  insert into public.user_blocks (blocker_id, blocked_id)
  values (v_actor, p_blocked_user_id)
  on conflict (blocker_id, blocked_id) do update set created_at = public.user_blocks.created_at
  returning * into v_block;
  delete from public.friends
  where (user_id = v_actor and friend_user_id = p_blocked_user_id)
     or (user_id = p_blocked_user_id and friend_user_id = v_actor);
  delete from public.friend_requests
  where (from_user_id = v_actor and to_user_id = p_blocked_user_id)
     or (from_user_id = p_blocked_user_id and to_user_id = v_actor);
  return v_block;
end;
$$;
create or replace function public.unblock_user(p_blocked_user_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare v_actor uuid := auth.uid();
begin
  if v_actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  delete from public.user_blocks where blocker_id = v_actor and blocked_id = p_blocked_user_id;
end;
$$;
-- No direct client graph mutations. The RPCs above are the sole write surface.
revoke all on table public.friends from public, anon, authenticated;
revoke all on table public.friend_requests from public, anon, authenticated;
grant select on table public.friends, public.friend_requests to authenticated;
revoke all on table public.user_blocks, public.reports from public, anon;
grant select on table public.user_blocks to authenticated;
grant select, insert on table public.reports to authenticated;
revoke all on function public.is_blocked_between(uuid, uuid) from public, anon;
revoke all on function public.is_confirmed_friend(uuid, uuid) from public, anon;
revoke all on function public.can_view_visit(uuid, uuid) from public, anon;
revoke all on function public.send_friend_request(uuid) from public, anon;
revoke all on function public.respond_friend_request(uuid, boolean) from public, anon;
revoke all on function public.cancel_friend_request(uuid) from public, anon;
revoke all on function public.remove_friendship(uuid) from public, anon;
revoke all on function public.block_user(uuid) from public, anon;
revoke all on function public.unblock_user(uuid) from public, anon;
grant execute on function public.is_blocked_between(uuid, uuid) to authenticated;
grant execute on function public.is_confirmed_friend(uuid, uuid) to authenticated;
grant execute on function public.can_view_visit(uuid, uuid) to authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid, boolean) to authenticated;
grant execute on function public.cancel_friend_request(uuid) to authenticated;
grant execute on function public.remove_friendship(uuid) to authenticated;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
drop policy if exists "Blocks are private to blocker" on public.user_blocks;
create policy "Blocks are private to blocker" on public.user_blocks
  for select to authenticated using ((select auth.uid()) = blocker_id);
drop policy if exists "Reporters create reports" on public.reports;
create policy "Reporters create reports" on public.reports
  for insert to authenticated with check (
    (select auth.uid()) = reporter_id
    and status = 'pending'
    and reviewed_at is null
  );
drop policy if exists "Reporters read own reports" on public.reports;
create policy "Reporters read own reports" on public.reports
  for select to authenticated using ((select auth.uid()) = reporter_id);
-- Replace permissive social read policies with block- and visibility-aware rules.
do $$ declare p record; begin
  for p in select policyname, tablename from pg_policies
    where schemaname = 'public' and tablename in
      ('users','friends','friend_requests','visits','likes','comments','visit_photos')
  loop execute format('drop policy if exists %I on public.%I', p.policyname, p.tablename); end loop;
end $$;
alter table public.users enable row level security;
alter table public.friends enable row level security;
alter table public.friend_requests enable row level security;
alter table public.visits enable row level security;
alter table public.likes enable row level security;
alter table public.comments enable row level security;
alter table public.visit_photos enable row level security;
create policy "Authenticated users discover nonblocked profiles" on public.users
  for select to authenticated using (
    not public.is_blocked_between((select auth.uid()), id)
  );
create policy "Users create own profile" on public.users
  for insert to authenticated with check ((select auth.uid()) = id);
create policy "Users update own profile" on public.users
  for update to authenticated using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);
create policy "Participants read friendship directions" on public.friends
  for select to authenticated using (
    ((select auth.uid()) = user_id or (select auth.uid()) = friend_user_id)
    and not public.is_blocked_between(user_id, friend_user_id)
  );
create policy "Participants read requests" on public.friend_requests
  for select to authenticated using (
    ((select auth.uid()) = from_user_id or (select auth.uid()) = to_user_id)
    and not public.is_blocked_between(from_user_id, to_user_id)
  );
create policy "Visible visits" on public.visits
  for select to authenticated using (public.can_view_visit(id, (select auth.uid())));
create policy "Owners create visits" on public.visits
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "Owners update visits" on public.visits
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Owners delete visits" on public.visits
  for delete to authenticated using ((select auth.uid()) = user_id);
create policy "Visible likes" on public.likes
  for select to authenticated using (public.can_view_visit(visit_id, (select auth.uid())));
create policy "Users create own likes on visible visits" on public.likes
  for insert to authenticated with check (
    (select auth.uid()) = user_id and public.can_view_visit(visit_id, (select auth.uid()))
  );
create policy "Users remove own likes" on public.likes
  for delete to authenticated using ((select auth.uid()) = user_id);
create policy "Visible comments" on public.comments
  for select to authenticated using (public.can_view_visit(visit_id, (select auth.uid())));
create policy "Users create own comments on visible visits" on public.comments
  for insert to authenticated with check (
    (select auth.uid()) = user_id and public.can_view_visit(visit_id, (select auth.uid()))
  );
create policy "Users update own comments" on public.comments
  for update to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id and public.can_view_visit(visit_id, (select auth.uid())));
create policy "Users delete own comments" on public.comments
  for delete to authenticated using ((select auth.uid()) = user_id);
create policy "Visible visit photos" on public.visit_photos
  for select to authenticated using (public.can_view_visit(visit_id, (select auth.uid())));
create policy "Owners create visit photos" on public.visit_photos
  for insert to authenticated with check (exists (
    select 1 from public.visits v where v.id = visit_id and v.user_id = (select auth.uid())
  ));
create policy "Owners update visit photos" on public.visit_photos
  for update to authenticated using (exists (
    select 1 from public.visits v where v.id = visit_id and v.user_id = (select auth.uid())
  )) with check (exists (
    select 1 from public.visits v where v.id = visit_id and v.user_id = (select auth.uid())
  ));
create policy "Owners delete visit photos" on public.visit_photos
  for delete to authenticated using (exists (
    select 1 from public.visits v where v.id = visit_id and v.user_id = (select auth.uid())
  ));
grant select, insert, update, delete on table public.users to authenticated;
grant select, insert, update, delete on table public.visits, public.likes, public.comments, public.visit_photos to authenticated;
