begin;

-- This migration closes the final alpha moderation and social-integrity races
-- without rewriting or deleting existing user data. Public callers receive
-- only explicit projections; raw evidence and operator metadata stay private.

-- ---------------------------------------------------------------------------
-- Live-account boundary for stale access tokens
-- ---------------------------------------------------------------------------

create or replace function private.is_live_account_as(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_user_id is not null and exists (
    select 1
    from auth.users account
    where account.id = p_user_id
      and account.deleted_at is null
  );
$$;

revoke all on function private.is_live_account_as(uuid)
  from public, anon, authenticated;

create or replace function private.can_socially_mutate_as(p_actor uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_actor)
    and not private.has_active_moderation_action(
      'user', p_actor, array['social_restricted', 'account_suspended']::text[]
    );
$$;

create or replace function private.can_view_user_as(p_user_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_viewer)
    and private.is_live_account_as(p_user_id)
    and not private.blocked_between(p_viewer, p_user_id)
    and (
      p_user_id = p_viewer
      or not private.has_active_moderation_action(
        'user', p_user_id, array['account_suspended']::text[]
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
  select private.is_live_account_as(p_viewer) and exists (
    select 1
    from public.visits visit
    where visit.id = p_visit_id
      and (visit.upload_state = 'complete' or visit.user_id = p_viewer)
      and private.can_view_user_as(visit.user_id, p_viewer)
      and (
        visit.user_id = p_viewer
        or not private.has_active_moderation_action(
          'visit', visit.id, array['content_hidden']::text[]
        )
      )
      and (
        visit.user_id = p_viewer
        or visit.visibility = 'everyone'
        or (
          visit.visibility = 'friends'
          and private.confirmed_friends(p_viewer, visit.user_id)
        )
      )
  );
$$;

create or replace function private.can_view_comment_as(p_comment_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_viewer) and exists (
    select 1
    from public.comments comment
    where comment.id = p_comment_id
      and comment.removed_at is null
      and not private.has_active_moderation_action(
        'comment', comment.id, array['content_hidden']::text[]
      )
      and private.can_view_visit_as(comment.visit_id, p_viewer)
      and private.can_view_user_as(comment.user_id, p_viewer)
  );
$$;

create or replace function private.can_view_shared_memory_as(
  p_shared_memory_id uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.is_live_account_as(p_viewer) and (
    exists (
      select 1
      from public.shared_memory_members member
      where member.shared_memory_id = p_shared_memory_id
        and member.user_id = p_viewer
        and member.status in ('pending', 'accepted')
    )
    or exists (
      select 1
      from public.shared_memory_contributions contribution
      where contribution.shared_memory_id = p_shared_memory_id
        and private.can_view_visit_as(contribution.visit_id, p_viewer)
        and not private.blocked_between(p_viewer, contribution.user_id)
    )
  );
$$;

revoke all on function private.can_socially_mutate_as(uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_user_as(uuid,uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_visit_as(uuid,uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_comment_as(uuid,uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_shared_memory_as(uuid,uuid)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Canonical pair serialization for blocking and cross-user writes
-- ---------------------------------------------------------------------------

create or replace function private.social_pair_lock_key_v1(
  p_first uuid,
  p_second uuid
)
returns text
language sql
immutable
security definer
set search_path = ''
as $$
  select least(p_first::text, p_second::text)
    || ':' || greatest(p_first::text, p_second::text);
$$;

create or replace function private.lock_social_pairs_v1(
  p_actor uuid,
  p_counterpart_ids uuid[],
  p_require_unblocked boolean default true
)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
declare
  counterpart uuid;
  lock_key text;
begin
  if not private.is_live_account_as(p_actor) then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  for counterpart, lock_key in
    select requested_id,
           private.social_pair_lock_key_v1(p_actor, requested_id)
    from (
      select distinct requested_id
      from unnest(coalesce(p_counterpart_ids, '{}'::uuid[])) requested_id
      where requested_id is not null and requested_id <> p_actor
    ) requested
    order by private.social_pair_lock_key_v1(p_actor, requested_id)
  loop
    if not private.is_live_account_as(counterpart) then
      raise exception 'account unavailable' using errcode = '42501';
    end if;

    -- This is deliberately identical to the lock used by block_user_v2.
    perform pg_catalog.pg_advisory_xact_lock(
      pg_catalog.hashtextextended(lock_key, 0)
    );

    if coalesce(p_require_unblocked, true)
       and private.blocked_between(p_actor, counterpart) then
      raise exception 'social relationship unavailable' using errcode = '42501';
    end if;
  end loop;
end;
$$;

create or replace function private.enforce_user_block_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.lock_social_pairs_v1(
    new.blocker_id, array[new.blocked_id], false
  );
  return new;
end;
$$;

create or replace function private.enforce_friend_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.lock_social_pairs_v1(
    new.user_id, array[new.friend_user_id], true
  );
  return new;
end;
$$;

create or replace function private.enforce_friend_request_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.lock_social_pairs_v1(
    new.from_user_id,
    array[new.to_user_id],
    new.status in ('pending', 'accepted')
  );
  return new;
end;
$$;

create or replace function private.enforce_visit_actor_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  visit_owner uuid;
begin
  select visit.user_id into visit_owner
  from public.visits visit
  where visit.id = new.visit_id;

  if visit_owner is null then
    raise exception 'visit unavailable' using errcode = 'P0002';
  end if;
  perform private.lock_social_pairs_v1(
    new.user_id, array[visit_owner], true
  );
  return new;
end;
$$;

create or replace function private.enforce_comment_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  visit_owner uuid;
  parent_author uuid;
begin
  select visit.user_id into visit_owner
  from public.visits visit
  where visit.id = new.visit_id;

  if new.parent_comment_id is not null then
    select comment.user_id into parent_author
    from public.comments comment
    where comment.id = new.parent_comment_id
      and comment.visit_id = new.visit_id;
  end if;

  if visit_owner is null
     or (new.parent_comment_id is not null and parent_author is null) then
    raise exception 'comment target unavailable' using errcode = 'P0002';
  end if;

  perform private.lock_social_pairs_v1(
    new.user_id, array[visit_owner, parent_author], true
  );
  return new;
end;
$$;

create or replace function private.enforce_comment_mention_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  comment_author uuid;
begin
  select comment.user_id into comment_author
  from public.comments comment
  where comment.id = new.comment_id;

  if comment_author is null then
    raise exception 'comment unavailable' using errcode = 'P0002';
  end if;
  perform private.lock_social_pairs_v1(
    comment_author, array[new.mentioned_user_id], true
  );
  return new;
end;
$$;

create or replace function private.enforce_visit_companion_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  visit_owner uuid;
begin
  select visit.user_id into visit_owner
  from public.visits visit
  where visit.id = new.visit_id;

  if visit_owner is null then
    raise exception 'visit unavailable' using errcode = 'P0002';
  end if;
  perform private.lock_social_pairs_v1(
    new.added_by, array[visit_owner, new.companion_user_id], true
  );
  return new;
end;
$$;

create or replace function private.enforce_recommendation_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.lock_social_pairs_v1(
    new.sender_id, array[new.recipient_id], true
  );
  return new;
end;
$$;

create or replace function private.enforce_shared_member_pair_lock_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.invited_by is null then
    if new.status in ('pending', 'accepted') then
      raise exception 'shared MugShot inviter is unavailable' using errcode = '42501';
    end if;
    return new;
  end if;

  perform private.lock_social_pairs_v1(
    new.invited_by,
    array[new.user_id],
    new.status in ('pending', 'accepted')
  );
  return new;
end;
$$;

revoke all on function private.social_pair_lock_key_v1(uuid,uuid)
  from public, anon, authenticated;
revoke all on function private.lock_social_pairs_v1(uuid,uuid[],boolean)
  from public, anon, authenticated;
revoke all on function private.enforce_user_block_pair_lock_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_friend_pair_lock_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_friend_request_pair_lock_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_visit_actor_pair_lock_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_comment_pair_lock_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_comment_mention_pair_lock_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_visit_companion_pair_lock_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_recommendation_pair_lock_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_shared_member_pair_lock_v1()
  from public, anon, authenticated;

drop trigger if exists enforce_user_block_pair_lock on public.user_blocks;
create trigger enforce_user_block_pair_lock
before insert or update of blocker_id, blocked_id on public.user_blocks
for each row execute function private.enforce_user_block_pair_lock_v1();

drop trigger if exists enforce_friend_pair_lock on public.friends;
create trigger enforce_friend_pair_lock
before insert or update of user_id, friend_user_id on public.friends
for each row execute function private.enforce_friend_pair_lock_v1();

drop trigger if exists enforce_friend_request_pair_lock on public.friend_requests;
create trigger enforce_friend_request_pair_lock
before insert or update of from_user_id, to_user_id, status
on public.friend_requests
for each row execute function private.enforce_friend_request_pair_lock_v1();

drop trigger if exists enforce_like_pair_lock on public.likes;
create trigger enforce_like_pair_lock
before insert or update of user_id, visit_id on public.likes
for each row execute function private.enforce_visit_actor_pair_lock_v1();

drop trigger if exists enforce_reaction_pair_lock on public.visit_reactions;
create trigger enforce_reaction_pair_lock
before insert or update of user_id, visit_id on public.visit_reactions
for each row execute function private.enforce_visit_actor_pair_lock_v1();

drop trigger if exists enforce_comment_pair_lock on public.comments;
create trigger enforce_comment_pair_lock
before insert on public.comments
for each row execute function private.enforce_comment_pair_lock_v1();

drop trigger if exists enforce_comment_mention_pair_lock on public.comment_mentions;
create trigger enforce_comment_mention_pair_lock
before insert or update of comment_id, mentioned_user_id
on public.comment_mentions
for each row execute function private.enforce_comment_mention_pair_lock_v1();

drop trigger if exists enforce_visit_companion_pair_lock on public.visit_companions;
create trigger enforce_visit_companion_pair_lock
before insert or update of visit_id, companion_user_id, added_by
on public.visit_companions
for each row execute function private.enforce_visit_companion_pair_lock_v1();

drop trigger if exists enforce_recommendation_pair_lock
  on public.trusted_recommendations;
create trigger enforce_recommendation_pair_lock
before insert or update of sender_id, recipient_id
on public.trusted_recommendations
for each row execute function private.enforce_recommendation_pair_lock_v1();

drop trigger if exists enforce_shared_member_pair_lock
  on public.shared_memory_members;
create trigger enforce_shared_member_pair_lock
before insert or update of user_id, invited_by, status
on public.shared_memory_members
for each row execute function private.enforce_shared_member_pair_lock_v1();

-- ---------------------------------------------------------------------------
-- Safe report receipts, dedupe, and server-side abuse limits
-- ---------------------------------------------------------------------------

create table private.report_client_receipts (
  reporter_subject_id uuid not null,
  client_report_id uuid not null,
  report_id uuid not null references public.reports(id) on delete restrict,
  reason public.report_reason not null,
  details text,
  target_kind text not null check (target_kind in ('user', 'visit', 'comment')),
  target_id uuid not null,
  created_at timestamptz not null default now(),
  primary key (reporter_subject_id, client_report_id),
  constraint report_client_receipts_details_length_check
    check (char_length(coalesce(details, '')) <= 2000)
);

create index report_client_receipts_report_idx
  on private.report_client_receipts (report_id, created_at, client_report_id);

alter table private.report_client_receipts enable row level security;
revoke all on table private.report_client_receipts
  from public, anon, authenticated;

create type public.report_submission_receipt_v1 as (
  id uuid,
  status public.report_status,
  created_at timestamptz,
  closed_at timestamptz,
  resolution_code text
);

create or replace function private.safe_report_submission_receipt_v1(
  p_report public.reports
)
returns public.report_submission_receipt_v1
language sql
stable
security definer
set search_path = ''
as $$
  select row(
    p_report.id,
    p_report.status,
    p_report.created_at,
    p_report.closed_at,
    case
      when p_report.status in ('resolved', 'dismissed') then 'review_complete'
      else null
    end
  )::public.report_submission_receipt_v1;
$$;

create or replace function private.lock_report_submission_actor_v1(p_actor uuid)
returns void
language plpgsql
volatile
security definer
set search_path = ''
as $$
begin
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('reporter:' || p_actor::text, 0)
  );
end;
$$;

revoke all on function private.safe_report_submission_receipt_v1(public.reports)
  from public, anon, authenticated;
revoke all on function private.lock_report_submission_actor_v1(uuid)
  from public, anon, authenticated;

create or replace function private.submit_report_internal(
  p_actor uuid,
  p_reason public.report_reason,
  p_details text,
  p_target_kind text,
  p_target_id uuid,
  p_client_report_id uuid,
  p_require_other_details boolean
)
returns public.reports
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_details text := nullif(trim(p_details), '');
  target_snapshot jsonb;
  result public.reports;
  client_receipt private.report_client_receipts;
  reports_last_hour integer;
  reports_last_day integer;
begin
  if not private.is_live_account_as(p_actor) then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_target_kind not in ('user', 'visit', 'comment') or p_target_id is null then
    raise exception 'a valid report target is required' using errcode = '22023';
  end if;
  if p_require_other_details and p_reason = 'other' and normalized_details is null then
    raise exception 'details are required for other reports' using errcode = '22023';
  end if;
  if char_length(coalesce(normalized_details, '')) > 2000 then
    raise exception 'report details cannot exceed 2000 characters' using errcode = '22023';
  end if;

  -- One reporter lock makes the idempotency, target-collapse, quota, and insert
  -- decision atomic. Exact retries are resolved before either quota is read.
  perform private.lock_report_submission_actor_v1(p_actor);

  if p_client_report_id is not null then
    select * into client_receipt
    from private.report_client_receipts receipt
    where receipt.reporter_subject_id = p_actor
      and receipt.client_report_id = p_client_report_id;

    if found then
      if client_receipt.reason is distinct from p_reason
         or client_receipt.details is distinct from normalized_details
         or client_receipt.target_kind is distinct from p_target_kind
         or client_receipt.target_id is distinct from p_target_id then
        raise exception 'client report id was already used for different evidence'
          using errcode = '22023';
      end if;
      select * into strict result
      from public.reports report
      where report.id = client_receipt.report_id;
      return result;
    end if;

    select * into result
    from public.reports report
    where report.reporter_subject_id = p_actor
      and report.client_report_id = p_client_report_id
    for update;

    if found then
      if result.reason is distinct from p_reason
         or result.details is distinct from normalized_details
         or result.target_kind is distinct from p_target_kind
         or result.target_id is distinct from p_target_id then
        raise exception 'client report id was already used for different evidence'
          using errcode = '22023';
      end if;

      insert into private.report_client_receipts (
        reporter_subject_id, client_report_id, report_id,
        reason, details, target_kind, target_id
      ) values (
        p_actor, p_client_report_id, result.id,
        p_reason, normalized_details, p_target_kind, p_target_id
      ) on conflict do nothing;
      return result;
    end if;
  end if;

  -- Repeated submissions for an unresolved target collapse to the first case.
  -- A closed case may be reported again if new conduct occurs later.
  select * into result
  from public.reports report
  where report.reporter_subject_id = p_actor
    and report.target_kind = p_target_kind
    and report.target_id = p_target_id
    and report.status in ('pending', 'reviewing')
  order by report.created_at desc, report.id desc
  limit 1
  for update;

  if found then
    if (p_target_kind = 'user' and (
          p_target_id = p_actor
          or not private.can_view_user_as(p_target_id, p_actor)
        ))
       or (p_target_kind = 'visit'
           and not private.can_view_visit_as(p_target_id, p_actor))
       or (p_target_kind = 'comment'
           and not private.can_view_comment_as(p_target_id, p_actor)) then
      raise exception 'target unavailable' using errcode = '42501';
    end if;

    if p_client_report_id is not null then
      insert into private.report_client_receipts (
        reporter_subject_id, client_report_id, report_id,
        reason, details, target_kind, target_id
      ) values (
        p_actor, p_client_report_id, result.id,
        p_reason, normalized_details, p_target_kind, p_target_id
      );
    end if;
    return result;
  end if;

  select
    count(*) filter (where report.created_at > now() - interval '1 hour'),
    count(*) filter (where report.created_at > now() - interval '24 hours')
  into reports_last_hour, reports_last_day
  from public.reports report
  where report.reporter_subject_id = p_actor
    and report.created_at > now() - interval '24 hours';

  if reports_last_hour >= 20 or reports_last_day >= 100 then
    raise exception 'report submission limit reached'
      using errcode = 'P0001',
            detail = 'report_rate_limited',
            hint = 'Wait before submitting another distinct report.';
  end if;

  case p_target_kind
    when 'user' then
      if p_target_id = p_actor then
        raise exception 'cannot report yourself' using errcode = '22023';
      end if;
      select jsonb_strip_nulls(jsonb_build_object(
        'kind', 'user',
        'id', reported_user.id,
        'display_name', reported_user.display_name,
        'username', reported_user.username
      ))
      into target_snapshot
      from public.users reported_user
      where reported_user.id = p_target_id
        and private.can_view_user_as(reported_user.id, p_actor);
    when 'visit' then
      if not private.can_view_visit_as(p_target_id, p_actor) then
        raise exception 'target unavailable' using errcode = '42501';
      end if;
      select jsonb_strip_nulls(jsonb_build_object(
        'kind', 'visit',
        'id', visit.id,
        'user_id', visit.user_id,
        'cafe_id', visit.cafe_id,
        'caption', visit.caption,
        'visibility', visit.visibility,
        'created_at', visit.created_at
      ))
      into target_snapshot
      from public.visits visit
      where visit.id = p_target_id;
    when 'comment' then
      select jsonb_strip_nulls(jsonb_build_object(
        'kind', 'comment',
        'id', comment.id,
        'user_id', comment.user_id,
        'visit_id', comment.visit_id,
        'parent_comment_id', comment.parent_comment_id,
        'text', comment.text,
        'created_at', comment.created_at
      ))
      into target_snapshot
      from public.comments comment
      where comment.id = p_target_id
        and private.can_view_comment_as(comment.id, p_actor);
  end case;

  if target_snapshot is null then
    raise exception 'target unavailable' using errcode = '42501';
  end if;

  insert into public.reports (
    reporter_id,
    reporter_subject_id,
    target_kind,
    target_id,
    target_user_id,
    target_visit_id,
    target_comment_id,
    target_snapshot,
    client_report_id,
    reason,
    details
  ) values (
    p_actor,
    p_actor,
    p_target_kind,
    p_target_id,
    case when p_target_kind = 'user' then p_target_id end,
    case when p_target_kind = 'visit' then p_target_id end,
    case when p_target_kind = 'comment' then p_target_id end,
    target_snapshot,
    p_client_report_id,
    p_reason,
    normalized_details
  )
  on conflict (reporter_subject_id, client_report_id)
    where client_report_id is not null
  do nothing
  returning * into result;

  if result.id is null and p_client_report_id is not null then
    select * into result
    from public.reports report
    where report.reporter_subject_id = p_actor
      and report.client_report_id = p_client_report_id;

    if result.reason is distinct from p_reason
       or result.details is distinct from normalized_details
       or result.target_kind is distinct from p_target_kind
       or result.target_id is distinct from p_target_id then
      raise exception 'client report id was already used for different evidence'
        using errcode = '22023';
    end if;
  end if;

  if p_client_report_id is not null then
    insert into private.report_client_receipts (
      reporter_subject_id, client_report_id, report_id,
      reason, details, target_kind, target_id
    ) values (
      p_actor, p_client_report_id, result.id,
      p_reason, normalized_details, p_target_kind, p_target_id
    )
    on conflict (reporter_subject_id, client_report_id) do nothing;
  end if;

  if not exists (
    select 1
    from private.moderation_case_events event
    where event.report_id = result.id and event.event_kind = 'report_submitted'
  ) then
    insert into private.moderation_case_events (
      report_id, actor_user_id, event_kind, to_status
    ) values (
      result.id, p_actor, 'report_submitted', result.status
    );
  end if;

  return result;
end;
$$;

revoke all on function private.submit_report_internal(
  uuid,public.report_reason,text,text,uuid,uuid,boolean
) from public, anon, authenticated;

drop function public.submit_report_v2(
  uuid,public.report_reason,text,uuid,text
);

create function public.submit_report_v2(
  p_client_report_id uuid,
  p_reason public.report_reason,
  p_target_kind text,
  p_target_id uuid,
  p_details text default null
)
returns public.report_submission_receipt_v1
language plpgsql
security definer
set search_path = ''
as $$
declare
  result public.reports;
begin
  if p_client_report_id is null then
    raise exception 'client report id is required' using errcode = '22023';
  end if;
  result := private.submit_report_internal(
    auth.uid(), p_reason, p_details, p_target_kind, p_target_id,
    p_client_report_id, true
  );
  return private.safe_report_submission_receipt_v1(result);
end;
$$;

drop function public.submit_report(
  public.report_reason,text,uuid,uuid,uuid
);

create function public.submit_report(
  p_reason public.report_reason,
  p_details text default null,
  p_target_user_id uuid default null,
  p_target_visit_id uuid default null,
  p_target_comment_id uuid default null
)
returns public.report_submission_receipt_v1
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_kind text;
  target_id uuid;
  result public.reports;
begin
  if num_nonnulls(p_target_user_id, p_target_visit_id, p_target_comment_id) <> 1 then
    raise exception 'exactly one report target is required' using errcode = '22023';
  end if;

  target_kind := case
    when p_target_user_id is not null then 'user'
    when p_target_visit_id is not null then 'visit'
    else 'comment'
  end;
  target_id := coalesce(p_target_user_id, p_target_visit_id, p_target_comment_id);

  result := private.submit_report_internal(
    auth.uid(), p_reason, p_details, target_kind, target_id, null, false
  );
  return private.safe_report_submission_receipt_v1(result);
end;
$$;

revoke all on function public.submit_report_v2(
  uuid,public.report_reason,text,uuid,text
) from public, anon, authenticated;
revoke all on function public.submit_report(
  public.report_reason,text,uuid,uuid,uuid
) from public, anon, authenticated;
grant execute on function public.submit_report_v2(
  uuid,public.report_reason,text,uuid,text
) to authenticated;
grant execute on function public.submit_report(
  public.report_reason,text,uuid,uuid,uuid
) to authenticated;

create or replace function public.get_report_receipt_v1(p_client_report_id uuid)
returns table (
  report_id uuid,
  status public.report_status,
  created_at timestamptz,
  closed_at timestamptz,
  resolution_code text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    report.id,
    report.status,
    report.created_at,
    report.closed_at,
    case
      when report.status in ('resolved', 'dismissed') then 'review_complete'
      else null
    end
  from public.reports report
  where private.is_live_account_as((select auth.uid()))
    and report.reporter_subject_id = (select auth.uid())
    and report.client_report_id = p_client_report_id;
$$;

create or replace function public.list_my_report_receipts_v1(
  p_limit integer default 50,
  p_before_created_at timestamptz default null,
  p_before_id uuid default null
)
returns table (
  report_id uuid,
  target_kind text,
  target_id uuid,
  reason public.report_reason,
  status public.report_status,
  created_at timestamptz,
  closed_at timestamptz,
  resolution_code text
)
language sql
stable
security definer
set search_path = ''
as $$
  select
    report.id,
    report.target_kind,
    report.target_id,
    report.reason,
    report.status,
    report.created_at,
    report.closed_at,
    case
      when report.status in ('resolved', 'dismissed') then 'review_complete'
      else null
    end
  from public.reports report
  where private.is_live_account_as((select auth.uid()))
    and report.reporter_subject_id = (select auth.uid())
    and (
      p_before_created_at is null
      or (report.created_at, report.id) < (p_before_created_at, p_before_id)
    )
  order by report.created_at desc, report.id desc
  limit least(greatest(coalesce(p_limit, 50), 1), 100);
$$;

-- ---------------------------------------------------------------------------
-- Server-related enforcement subjects and consistent operator roles
-- ---------------------------------------------------------------------------

create or replace function private.enforce_moderation_action_report_subject_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  source_report public.reports;
  reported_owner uuid;
begin
  if new.report_id is null then
    return new;
  end if;

  select * into source_report
  from public.reports report
  where report.id = new.report_id;

  if not found then
    raise exception 'report unavailable' using errcode = 'P0002';
  end if;

  reported_owner := case source_report.target_kind
    when 'user' then source_report.target_id
    when 'visit' then coalesce(
      nullif(source_report.target_snapshot->>'user_id', '')::uuid,
      (select visit.user_id from public.visits visit
       where visit.id = source_report.target_id)
    )
    when 'comment' then coalesce(
      nullif(source_report.target_snapshot->>'user_id', '')::uuid,
      (select comment.user_id from public.comments comment
       where comment.id = source_report.target_id)
    )
  end;

  if not (
    (new.subject_kind = source_report.target_kind
      and new.subject_id = source_report.target_id)
    or (new.subject_kind = 'user' and new.subject_id = reported_owner)
  ) then
    raise exception 'moderation subject is unrelated to the report'
      using errcode = '42501';
  end if;

  return new;
end;
$$;

create or replace function private.enforce_moderation_action_admin_update_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if new.ends_at is distinct from old.ends_at
     or new.revoked_at is distinct from old.revoked_at
     or new.revoked_by is distinct from old.revoked_by
     or new.revocation_reason is distinct from old.revocation_reason then
    if actor is not null and not exists (
      select 1
      from private.moderation_operators operator
      where operator.user_id = actor
        and operator.role = 'admin'
        and operator.is_active
        and private.is_live_account_as(actor)
    ) then
      raise exception 'moderation administrator permission required'
        using errcode = '42501';
    end if;
  end if;
  return new;
end;
$$;

create or replace function private.enforce_moderation_appeal_operator_role_v1()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  operator_role text;
begin
  if new.status is not distinct from old.status or actor is null then
    return new;
  end if;

  select operator.role into operator_role
  from private.moderation_operators operator
  where operator.user_id = actor
    and operator.is_active
    and private.is_live_account_as(actor);

  if operator_role is null then
    raise exception 'moderation permission required' using errcode = '42501';
  end if;
  if new.status in ('modified', 'reversed') and operator_role <> 'admin' then
    raise exception 'moderation administrator permission required'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_moderation_action_report_subject_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_moderation_action_admin_update_v1()
  from public, anon, authenticated;
revoke all on function private.enforce_moderation_appeal_operator_role_v1()
  from public, anon, authenticated;

drop trigger if exists enforce_moderation_action_report_subject
  on private.moderation_actions;
create trigger enforce_moderation_action_report_subject
before insert or update of report_id, subject_kind, subject_id
on private.moderation_actions
for each row execute function private.enforce_moderation_action_report_subject_v1();

drop trigger if exists enforce_moderation_action_admin_update
  on private.moderation_actions;
create trigger enforce_moderation_action_admin_update
before update of ends_at, revoked_at, revoked_by, revocation_reason
on private.moderation_actions
for each row execute function private.enforce_moderation_action_admin_update_v1();

drop trigger if exists enforce_moderation_appeal_operator_role
  on private.moderation_appeals;
create trigger enforce_moderation_appeal_operator_role
before update of status on private.moderation_appeals
for each row execute function private.enforce_moderation_appeal_operator_role_v1();

-- ---------------------------------------------------------------------------
-- Restore the moderation check lost when account-lifecycle V2 replaced attach
-- ---------------------------------------------------------------------------

create or replace function public.attach_shared_memory_contribution_v1(
  p_shared_memory_id uuid,
  p_visit_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  memory public.shared_memories%rowtype;
  target public.visits%rowtype;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;

  select * into memory
  from public.shared_memories
  where id = p_shared_memory_id
  for update;
  if not found then
    raise exception 'shared MugShot not found' using errcode = 'P0002';
  end if;
  if memory.managed_by is null
     or private.blocked_between(actor, memory.managed_by)
     or not exists (
       select 1
       from public.shared_memory_members member
       where member.shared_memory_id = memory.id
         and member.user_id = actor
         and member.status = 'accepted'
     ) then
    raise exception 'accepted participation required' using errcode = '42501';
  end if;

  select * into target
  from public.visits
  where id = p_visit_id and user_id = actor
  for update;
  if not found then
    raise exception 'visit ownership required' using errcode = '42501';
  end if;
  if target.upload_state <> 'complete' or target.cafe_session_role = 'secondary' then
    raise exception 'a complete primary post is required' using errcode = '22023';
  end if;
  if actor = memory.created_by and target.id <> memory.source_visit_id then
    raise exception 'shared MugShot creator contribution is the immutable source post'
      using errcode = '55000';
  end if;
  if exists (
    select 1
    from public.shared_memories existing_memory
    where existing_memory.source_visit_id = target.id
      and existing_memory.id <> memory.id
  ) then
    raise exception 'post already anchors another shared MugShot' using errcode = '23505';
  end if;
  if (case
       when lower(btrim(coalesce(target.context_type, ''))) = 'cafe'
         or (nullif(btrim(target.context_type), '') is null and target.cafe_id is not null)
         then 'cafe'
       when lower(btrim(coalesce(target.context_type, ''))) = 'home' then 'home'
       when lower(btrim(coalesce(target.context_type, ''))) = 'recipe' then 'recipe'
       else 'elsewhere'
     end) <> lower(btrim(memory.context_type)) then
    raise exception 'post context does not match the shared MugShot' using errcode = '22023';
  end if;
  if lower(btrim(memory.context_type)) = 'cafe'
     and target.cafe_id is distinct from memory.cafe_id then
    raise exception 'post cafe does not match the shared MugShot' using errcode = '22023';
  end if;
  if abs(extract(epoch from (target.created_at - memory.occurred_at)))
       > 12 * 60 * 60 then
    raise exception 'post time does not match the shared MugShot'
      using errcode = '22023';
  end if;

  insert into public.shared_memory_contributions (
    shared_memory_id, visit_id, user_id
  ) values (
    memory.id, target.id, actor
  )
  on conflict (shared_memory_id, user_id) do update
    set visit_id = excluded.visit_id,
        joined_at = now();

  update public.shared_memories
  set updated_at = now()
  where id = memory.id;

  return target.id;
end;
$$;

revoke all on function public.attach_shared_memory_contribution_v1(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.attach_shared_memory_contribution_v1(uuid,uuid)
  to authenticated;

comment on function private.is_live_account_as(uuid) is
  'True only while the Auth identity exists and is not soft-deleted; stale deleted-account JWTs fail closed.';
comment on function public.submit_report_v2(
  uuid,public.report_reason,text,uuid,text
) is
  'Idempotent caller-bound report submission returning an allowlisted receipt; unresolved repeated targets collapse and new distinct reports are rate-limited.';
comment on function public.submit_report(
  public.report_reason,text,uuid,uuid,uuid
) is
  'Legacy caller-bound report submission using the same target collapse, quotas, and allowlisted receipt as V2.';
comment on function public.attach_shared_memory_contribution_v1(uuid,uuid) is
  'Attaches an accepted participant post only while that caller may make social mutations; decline, cancel, and leave remain separate safety exits.';

commit;
