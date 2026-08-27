-- Add expressive post reactions without replacing the historical
-- coffee-specific visit_reactions contract. Existing likes remain Likes.

alter table public.likes
  add column if not exists reaction_kind text not null default 'like';

alter table public.likes
  drop constraint if exists likes_reaction_kind_check;

alter table public.likes
  add constraint likes_reaction_kind_check
  check (reaction_kind in ('like', 'love', 'laugh', 'yummy'));

create index if not exists likes_visit_reaction_kind_idx
  on public.likes (visit_id, reaction_kind);

create or replace function public.set_visit_reaction_v1(
  p_visit_id uuid,
  p_reaction_kind text default null
)
returns table (
  viewer_reaction text,
  like_count bigint,
  love_count bigint,
  laugh_count bigint,
  yummy_count bigint,
  total_count bigint
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  normalized_reaction text := nullif(lower(btrim(p_reaction_kind)), '');
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  if p_visit_id is null then
    raise exception 'visit is required' using errcode = '22023';
  end if;

  if not public.can_socially_mutate(actor)
     or not public.can_view_visit(p_visit_id, actor) then
    raise exception 'visit is unavailable' using errcode = '42501';
  end if;

  if normalized_reaction is not null
     and normalized_reaction not in ('like', 'love', 'laugh', 'yummy') then
    raise exception 'invalid reaction' using errcode = '22023';
  end if;

  if normalized_reaction is null then
    delete from public.likes reaction
    where reaction.visit_id = p_visit_id
      and reaction.user_id = actor;
  else
    insert into public.likes (user_id, visit_id, reaction_kind)
    values (actor, p_visit_id, normalized_reaction)
    on conflict (user_id, visit_id) do update
      set reaction_kind = excluded.reaction_kind;
  end if;

  return query
  select
    (
      select reaction.reaction_kind
      from public.likes reaction
      where reaction.visit_id = p_visit_id
        and reaction.user_id = actor
    ) as viewer_reaction,
    count(*) filter (where reaction.reaction_kind = 'like') as like_count,
    count(*) filter (where reaction.reaction_kind = 'love') as love_count,
    count(*) filter (where reaction.reaction_kind = 'laugh') as laugh_count,
    count(*) filter (where reaction.reaction_kind = 'yummy') as yummy_count,
    count(*) as total_count
  from public.likes reaction
  where reaction.visit_id = p_visit_id
    and public.can_view_user(reaction.user_id, actor);
end;
$$;

revoke all on function public.set_visit_reaction_v1(uuid,text)
  from public, anon;
grant execute on function public.set_visit_reaction_v1(uuid,text)
  to authenticated;

-- The legacy activity kind stays `like`, preserving old clients and activity
-- preferences. Its metadata carries the expressive selection. Updates reuse
-- the existing actor/post event instead of creating another notification.
create or replace function private.activity_from_like_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  owner_id uuid;
  keeper_id uuid;
begin
  select visit.user_id into owner_id
  from public.visits visit
  where visit.id = new.visit_id;

  select event.id into keeper_id
  from public.activity_events event
  where event.kind = 'like'
    and event.visit_id = new.visit_id
    and event.actor_user_id = new.user_id
  order by event.created_at, event.id
  limit 1;

  if keeper_id is null then
    keeper_id := private.create_activity_event_v1(
      owner_id,
      new.user_id,
      'like',
      'like:' || new.visit_id::text || ':' || new.user_id::text,
      'New reaction',
      'Someone reacted to your MugShot.',
      new.visit_id,
      null,
      null,
      null,
      null,
      jsonb_build_object('reaction_kind', new.reaction_kind)
    );
  end if;

  -- A concurrent insert can win the deterministic dedupe key after the first
  -- lookup but before create_activity_event_v1. Re-read the winner so this
  -- transaction still updates the single canonical event.
  if keeper_id is null then
    select event.id into keeper_id
    from public.activity_events event
    where event.kind = 'like'
      and event.visit_id = new.visit_id
      and event.actor_user_id = new.user_id
    order by event.created_at, event.id
    limit 1;
  end if;

  if keeper_id is not null then
    update public.activity_events event
    set metadata = coalesce(event.metadata, '{}'::jsonb)
        || jsonb_build_object('reaction_kind', new.reaction_kind),
        body = case new.reaction_kind
          when 'love' then 'Your sip got some love.'
          when 'laugh' then 'Your sip made someone laugh.'
          when 'yummy' then 'Someone called your sip yummy.'
          else 'Your sip got a like.'
        end
    where event.id = keeper_id;

    delete from public.activity_events event
    where event.kind = 'like'
      and event.visit_id = new.visit_id
      and event.actor_user_id = new.user_id
      and event.id <> keeper_id;
  end if;

  return new;
end;
$$;

create or replace function private.cleanup_activity_from_like_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from public.activity_events event
  where event.kind = 'like'
    and event.visit_id = old.visit_id
    and event.actor_user_id = old.user_id;
  return old;
end;
$$;

revoke all on function private.activity_from_like_v1()
  from public, anon, authenticated;
revoke all on function private.cleanup_activity_from_like_v1()
  from public, anon, authenticated;

drop trigger if exists activity_from_like on public.likes;
create trigger activity_from_like
after insert or update of reaction_kind on public.likes
for each row execute function private.activity_from_like_v1();

drop trigger if exists cleanup_activity_from_like on public.likes;
create trigger cleanup_activity_from_like
after delete on public.likes
for each row execute function private.cleanup_activity_from_like_v1();
