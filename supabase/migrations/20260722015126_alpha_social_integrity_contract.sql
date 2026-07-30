begin;

-- Alpha social integrity is expand-first. Existing rows and RPC signatures stay
-- valid while reports gain durable evidence, moderation gains an auditable
-- private control plane, blocks sever cross-user social edges, and comments
-- become caller-bound, editable, and removable without destroying evidence.

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Durable reports and idempotent receipts
-- ---------------------------------------------------------------------------

alter table public.reports
  add column if not exists reporter_subject_id uuid,
  add column if not exists target_kind text,
  add column if not exists target_id uuid,
  add column if not exists target_snapshot jsonb not null default '{}'::jsonb,
  add column if not exists client_report_id uuid,
  add column if not exists reviewed_by uuid,
  add column if not exists resolution_code text,
  add column if not exists closed_at timestamptz;

update public.reports report
set
  reporter_subject_id = coalesce(report.reporter_subject_id, report.reporter_id),
  target_kind = coalesce(
    report.target_kind,
    case
      when report.target_user_id is not null then 'user'
      when report.target_visit_id is not null then 'visit'
      when report.target_comment_id is not null then 'comment'
    end
  ),
  target_id = coalesce(
    report.target_id,
    report.target_user_id,
    report.target_visit_id,
    report.target_comment_id
  ),
  target_snapshot = case
    when report.target_snapshot <> '{}'::jsonb then report.target_snapshot
    when report.target_user_id is not null then coalesce((
      select jsonb_strip_nulls(jsonb_build_object(
        'kind', 'user',
        'id', reported_user.id,
        'display_name', reported_user.display_name,
        'username', reported_user.username
      ))
      from public.users reported_user
      where reported_user.id = report.target_user_id
    ), jsonb_build_object('kind', 'user', 'id', report.target_user_id))
    when report.target_visit_id is not null then coalesce((
      select jsonb_strip_nulls(jsonb_build_object(
        'kind', 'visit',
        'id', visit.id,
        'user_id', visit.user_id,
        'cafe_id', visit.cafe_id,
        'caption', visit.caption,
        'visibility', visit.visibility,
        'created_at', visit.created_at
      ))
      from public.visits visit
      where visit.id = report.target_visit_id
    ), jsonb_build_object('kind', 'visit', 'id', report.target_visit_id))
    when report.target_comment_id is not null then coalesce((
      select jsonb_strip_nulls(jsonb_build_object(
        'kind', 'comment',
        'id', comment.id,
        'user_id', comment.user_id,
        'visit_id', comment.visit_id,
        'parent_comment_id', comment.parent_comment_id,
        'text', comment.text,
        'created_at', comment.created_at
      ))
      from public.comments comment
      where comment.id = report.target_comment_id
    ), jsonb_build_object('kind', 'comment', 'id', report.target_comment_id))
    else report.target_snapshot
  end
where report.reporter_subject_id is null
   or report.target_kind is null
   or report.target_id is null
   or report.target_snapshot = '{}'::jsonb;

alter table public.reports
  drop constraint if exists reports_exactly_one_target,
  drop constraint if exists reports_reporter_id_fkey,
  drop constraint if exists reports_target_user_id_fkey,
  drop constraint if exists reports_target_visit_id_fkey,
  drop constraint if exists reports_target_comment_id_fkey,
  alter column reporter_id drop not null,
  alter column reporter_subject_id set not null,
  alter column target_kind set not null,
  alter column target_id set not null;

alter table public.reports
  add constraint reports_reporter_id_fkey
    foreign key (reporter_id) references public.users(id) on delete set null not valid,
  add constraint reports_target_user_id_fkey
    foreign key (target_user_id) references public.users(id) on delete set null not valid,
  add constraint reports_target_visit_id_fkey
    foreign key (target_visit_id) references public.visits(id) on delete set null not valid,
  add constraint reports_target_comment_id_fkey
    foreign key (target_comment_id) references public.comments(id) on delete set null not valid,
  add constraint reports_reviewed_by_fkey
    foreign key (reviewed_by) references public.users(id) on delete set null not valid,
  add constraint reports_target_kind_check
    check (target_kind in ('user', 'visit', 'comment')),
  add constraint reports_reporter_pointer_consistency
    check (reporter_id is null or reporter_id = reporter_subject_id),
  add constraint reports_target_pointer_consistency check (
    num_nonnulls(target_user_id, target_visit_id, target_comment_id) <= 1
    and (target_user_id is null or (target_kind = 'user' and target_user_id = target_id))
    and (target_visit_id is null or (target_kind = 'visit' and target_visit_id = target_id))
    and (target_comment_id is null or (target_kind = 'comment' and target_comment_id = target_id))
  ),
  add constraint reports_target_snapshot_object_check
    check (jsonb_typeof(target_snapshot) = 'object'),
  add constraint reports_target_snapshot_identity_check check (
    target_snapshot->>'kind' = target_kind
    and target_snapshot->>'id' = target_id::text
  ),
  add constraint reports_resolution_code_length_check
    check (char_length(coalesce(resolution_code, '')) <= 80);

alter table public.reports validate constraint reports_reporter_id_fkey;
alter table public.reports validate constraint reports_target_user_id_fkey;
alter table public.reports validate constraint reports_target_visit_id_fkey;
alter table public.reports validate constraint reports_target_comment_id_fkey;
alter table public.reports validate constraint reports_reviewed_by_fkey;

create unique index if not exists reports_reporter_client_receipt_idx
  on public.reports (reporter_subject_id, client_report_id)
  where client_report_id is not null;

create index if not exists reports_status_created_idx
  on public.reports (status, created_at, id);

create index if not exists reports_target_identity_idx
  on public.reports (target_kind, target_id, created_at desc);

-- Add comment lifecycle columns before compiling visibility helpers that use
-- them. Constraints and indexes are installed with the comment APIs below.
alter table public.comments
  add column if not exists edited_at timestamptz,
  add column if not exists removed_at timestamptz,
  add column if not exists removed_by uuid,
  add column if not exists removal_reason text;

-- ---------------------------------------------------------------------------
-- Private moderation control plane
-- ---------------------------------------------------------------------------

create table if not exists private.moderation_operators (
  user_id uuid primary key references public.users(id) on delete cascade,
  role text not null check (role in ('reviewer', 'admin')),
  is_active boolean not null default true,
  appointed_by uuid references public.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists private.moderation_case_events (
  id uuid primary key default gen_random_uuid(),
  report_id uuid not null references public.reports(id) on delete restrict,
  actor_user_id uuid references public.users(id) on delete set null,
  event_kind text not null check (event_kind in (
    'report_submitted', 'review_started', 'report_resolved',
    'report_dismissed', 'action_applied', 'action_revoked'
  )),
  from_status public.report_status,
  to_status public.report_status,
  resolution_code text check (char_length(coalesce(resolution_code, '')) <= 80),
  internal_note text check (char_length(coalesce(internal_note, '')) <= 2000),
  created_at timestamptz not null default now()
);

create table if not exists private.moderation_actions (
  id uuid primary key default gen_random_uuid(),
  report_id uuid references public.reports(id) on delete set null,
  subject_kind text not null check (subject_kind in ('user', 'visit', 'comment')),
  subject_id uuid not null,
  action_kind text not null check (action_kind in (
    'warning', 'content_hidden', 'social_restricted', 'account_suspended'
  )),
  reason_code text not null check (char_length(reason_code) between 1 and 80),
  internal_note text check (char_length(coalesce(internal_note, '')) <= 2000),
  starts_at timestamptz not null default now(),
  ends_at timestamptz,
  created_by uuid references public.users(id) on delete set null,
  revoked_at timestamptz,
  revoked_by uuid references public.users(id) on delete set null,
  revocation_reason text check (char_length(coalesce(revocation_reason, '')) <= 280),
  created_at timestamptz not null default now(),
  constraint moderation_actions_time_check
    check (ends_at is null or ends_at > starts_at),
  constraint moderation_actions_revocation_check
    check ((revoked_at is null and revoked_by is null) or revoked_at is not null)
);

create index if not exists moderation_case_events_report_created_idx
  on private.moderation_case_events (report_id, created_at, id);

create index if not exists moderation_actions_active_subject_idx
  on private.moderation_actions (subject_kind, subject_id, action_kind, starts_at desc)
  where revoked_at is null;

alter table private.moderation_operators enable row level security;
alter table private.moderation_case_events enable row level security;
alter table private.moderation_actions enable row level security;

revoke all on table private.moderation_operators from public, anon, authenticated;
revoke all on table private.moderation_case_events from public, anon, authenticated;
revoke all on table private.moderation_actions from public, anon, authenticated;

create or replace function private.has_active_moderation_action(
  p_subject_kind text,
  p_subject_id uuid,
  p_action_kinds text[],
  p_at timestamptz default now()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.moderation_actions action
    where action.subject_kind = p_subject_kind
      and action.subject_id = p_subject_id
      and action.action_kind = any(coalesce(p_action_kinds, '{}'::text[]))
      and action.starts_at <= p_at
      and (action.ends_at is null or action.ends_at > p_at)
      and action.revoked_at is null
  );
$$;

create or replace function private.can_socially_mutate_as(p_actor uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_actor is not null
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
  select p_user_id is not null
    and p_viewer is not null
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
  select exists (
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
  select exists (
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

revoke all on function private.has_active_moderation_action(text,uuid,text[],timestamptz)
  from public, anon, authenticated;
revoke all on function private.can_socially_mutate_as(uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_user_as(uuid,uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_visit_as(uuid,uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_comment_as(uuid,uuid)
  from public, anon, authenticated;

create or replace function public.can_socially_mutate(p_actor uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_actor = (select auth.uid())
    and private.can_socially_mutate_as(p_actor);
$$;

create or replace function public.can_view_user(
  p_user_id uuid,
  p_viewer uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer = (select auth.uid())
    and private.can_view_user_as(p_user_id, p_viewer);
$$;

create or replace function public.can_view_visit(
  p_visit_id uuid,
  p_viewer uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer = (select auth.uid())
    and private.can_view_visit_as(p_visit_id, p_viewer);
$$;

create or replace function public.can_view_comment(
  p_comment_id uuid,
  p_viewer uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer = (select auth.uid())
    and private.can_view_comment_as(p_comment_id, p_viewer);
$$;

revoke all on function public.can_socially_mutate(uuid) from public, anon;
revoke all on function public.can_view_user(uuid,uuid) from public, anon;
revoke all on function public.can_view_visit(uuid,uuid) from public, anon;
revoke all on function public.can_view_comment(uuid,uuid) from public, anon;
grant execute on function public.can_socially_mutate(uuid) to authenticated;
grant execute on function public.can_view_user(uuid,uuid) to authenticated;
grant execute on function public.can_view_visit(uuid,uuid) to authenticated;
grant execute on function public.can_view_comment(uuid,uuid) to authenticated;

-- The identity/consent contract is intentionally earlier in migration order.
-- Wrap only its creation/acceptance surfaces with moderation enforcement;
-- decline, cancel, leave, and self-untag remain available as safety exits.
alter function public.set_visit_tags_v1(uuid,uuid[]) set schema private;
alter function public.create_shared_memory_invitations_v1(uuid,uuid[]) set schema private;
alter function public.respond_shared_memory_invitation_v1(uuid,boolean) set schema private;
alter function public.attach_shared_memory_contribution_v1(uuid,uuid) set schema private;

revoke all on function private.set_visit_tags_v1(uuid,uuid[])
  from public, anon, authenticated;
revoke all on function private.create_shared_memory_invitations_v1(uuid,uuid[])
  from public, anon, authenticated;
revoke all on function private.respond_shared_memory_invitation_v1(uuid,boolean)
  from public, anon, authenticated;
revoke all on function private.attach_shared_memory_contribution_v1(uuid,uuid)
  from public, anon, authenticated;

create function public.set_visit_tags_v1(
  p_visit_id uuid,
  p_tagged_user_ids uuid[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if exists (
    select 1
    from unnest(coalesce(p_tagged_user_ids, '{}'::uuid[])) requested_id
    where requested_id is not null and requested_id <> actor
  ) and not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  perform private.set_visit_tags_v1(p_visit_id, p_tagged_user_ids);
end;
$$;

create function public.create_shared_memory_invitations_v1(
  p_visit_id uuid,
  p_invitee_ids uuid[] default '{}'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  return private.create_shared_memory_invitations_v1(p_visit_id, p_invitee_ids);
end;
$$;

create function public.respond_shared_memory_invitation_v1(
  p_invitation_id uuid,
  p_accept boolean
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if coalesce(p_accept, false) and not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  return private.respond_shared_memory_invitation_v1(p_invitation_id, p_accept);
end;
$$;

create function public.attach_shared_memory_contribution_v1(
  p_shared_memory_id uuid,
  p_visit_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  return private.attach_shared_memory_contribution_v1(
    p_shared_memory_id, p_visit_id
  );
end;
$$;

revoke all on function public.set_visit_tags_v1(uuid,uuid[])
  from public, anon, authenticated;
revoke all on function public.create_shared_memory_invitations_v1(uuid,uuid[])
  from public, anon, authenticated;
revoke all on function public.respond_shared_memory_invitation_v1(uuid,boolean)
  from public, anon, authenticated;
revoke all on function public.attach_shared_memory_contribution_v1(uuid,uuid)
  from public, anon, authenticated;
grant execute on function public.set_visit_tags_v1(uuid,uuid[]) to authenticated;
grant execute on function public.create_shared_memory_invitations_v1(uuid,uuid[])
  to authenticated;
grant execute on function public.respond_shared_memory_invitation_v1(uuid,boolean)
  to authenticated;
grant execute on function public.attach_shared_memory_contribution_v1(uuid,uuid)
  to authenticated;

comment on function public.set_visit_tags_v1(uuid,uuid[]) is
  'Creates ordinary no-consent tags only while the caller may make social mutations.';
comment on function public.create_shared_memory_invitations_v1(uuid,uuid[]) is
  'Creates consent-required shared-memory invitations while preserving independent posts.';

-- Apply the same enforcement to the established relationship, recommendation,
-- and legacy tag RPCs. Rejections and empty-tag clears remain safety exits.
alter function public.send_friend_request(uuid) set schema private;
alter function public.respond_friend_request(uuid,boolean) set schema private;
alter function public.send_trusted_recommendation(uuid,text,uuid,text) set schema private;
alter function public.set_visit_companions(uuid,uuid[]) set schema private;

revoke all on function private.send_friend_request(uuid)
  from public, anon, authenticated;
revoke all on function private.respond_friend_request(uuid,boolean)
  from public, anon, authenticated;
revoke all on function private.send_trusted_recommendation(uuid,text,uuid,text)
  from public, anon, authenticated;
revoke all on function private.set_visit_companions(uuid,uuid[])
  from public, anon, authenticated;

create function public.send_friend_request(p_target_user_id uuid)
returns public.friend_requests
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  return private.send_friend_request(p_target_user_id);
end;
$$;

create function public.respond_friend_request(
  p_request_id uuid,
  p_accept boolean
)
returns public.friend_requests
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if coalesce(p_accept, false) and not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  return private.respond_friend_request(p_request_id, p_accept);
end;
$$;

create function public.send_trusted_recommendation(
  p_recipient_id uuid,
  p_target_kind text,
  p_target_id uuid,
  p_note text default null
)
returns public.trusted_recommendations
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  return private.send_trusted_recommendation(
    p_recipient_id, p_target_kind, p_target_id, p_note
  );
end;
$$;

create function public.set_visit_companions(
  p_visit_id uuid,
  p_companion_user_ids uuid[] default '{}'
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if exists (
    select 1
    from unnest(coalesce(p_companion_user_ids, '{}'::uuid[])) requested_id
    where requested_id is not null and requested_id <> actor
  ) and not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  perform private.set_visit_companions(p_visit_id, p_companion_user_ids);
end;
$$;

revoke all on function public.send_friend_request(uuid)
  from public, anon, authenticated;
revoke all on function public.respond_friend_request(uuid,boolean)
  from public, anon, authenticated;
revoke all on function public.send_trusted_recommendation(uuid,text,uuid,text)
  from public, anon, authenticated;
revoke all on function public.set_visit_companions(uuid,uuid[])
  from public, anon, authenticated;
grant execute on function public.send_friend_request(uuid) to authenticated;
grant execute on function public.respond_friend_request(uuid,boolean) to authenticated;
grant execute on function public.send_trusted_recommendation(uuid,text,uuid,text)
  to authenticated;
grant execute on function public.set_visit_companions(uuid,uuid[]) to authenticated;

create or replace function private.enforce_report_evidence_immutability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.reporter_subject_id is distinct from old.reporter_subject_id
     or new.target_kind is distinct from old.target_kind
     or new.target_id is distinct from old.target_id
     or new.target_snapshot is distinct from old.target_snapshot
     or new.client_report_id is distinct from old.client_report_id then
    raise exception 'report evidence is immutable' using errcode = '55000';
  end if;
  return new;
end;
$$;

drop trigger if exists reports_evidence_is_immutable on public.reports;
create trigger reports_evidence_is_immutable
  before update on public.reports
  for each row execute function private.enforce_report_evidence_immutability();

revoke all on function private.enforce_report_evidence_immutability()
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
begin
  if p_actor is null then
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

  if p_client_report_id is not null then
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
      return result;
    end if;
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
    return result;
  end if;

  insert into private.moderation_case_events (
    report_id, actor_user_id, event_kind, to_status
  ) values (
    result.id, p_actor, 'report_submitted', result.status
  );

  return result;
end;
$$;

revoke all on function private.submit_report_internal(
  uuid,public.report_reason,text,text,uuid,uuid,boolean
) from public, anon, authenticated;

create or replace function public.submit_report_v2(
  p_client_report_id uuid,
  p_reason public.report_reason,
  p_target_kind text,
  p_target_id uuid,
  p_details text default null
)
returns public.reports
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_client_report_id is null then
    raise exception 'client report id is required' using errcode = '22023';
  end if;
  return private.submit_report_internal(
    auth.uid(), p_reason, p_details, p_target_kind, p_target_id,
    p_client_report_id, true
  );
end;
$$;

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
  target_kind text;
  target_id uuid;
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

  return private.submit_report_internal(
    auth.uid(), p_reason, p_details, target_kind, target_id, null, false
  );
end;
$$;

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
  select report.id, report.status, report.created_at, report.closed_at,
         report.resolution_code
  from public.reports report
  where report.reporter_subject_id = (select auth.uid())
    and report.client_report_id = p_client_report_id;
$$;

create or replace function public.review_report_v1(
  p_report_id uuid,
  p_new_status public.report_status,
  p_resolution_code text default null,
  p_internal_note text default null,
  p_action_kind text default null,
  p_action_subject_kind text default null,
  p_action_subject_id uuid default null,
  p_action_ends_at timestamptz default null
)
returns public.reports
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  report_before public.reports;
  report_after public.reports;
  normalized_resolution text := nullif(trim(p_resolution_code), '');
  normalized_note text := nullif(trim(p_internal_note), '');
  action_subject_kind text;
  action_subject_id uuid;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not exists (
    select 1
    from private.moderation_operators operator
    where operator.user_id = actor and operator.is_active
  ) then
    raise exception 'moderation permission required' using errcode = '42501';
  end if;
  if char_length(coalesce(normalized_note, '')) > 2000 then
    raise exception 'internal note is too long' using errcode = '22023';
  end if;

  select * into report_before
  from public.reports report
  where report.id = p_report_id
  for update;

  if not found then
    raise exception 'report unavailable' using errcode = 'P0002';
  end if;
  if report_before.reporter_subject_id = actor then
    raise exception 'reviewers cannot resolve their own report' using errcode = '42501';
  end if;
  if report_before.status in ('resolved', 'dismissed') then
    raise exception 'report is already closed' using errcode = '55000';
  end if;
  if p_new_status not in ('reviewing', 'resolved', 'dismissed') then
    raise exception 'invalid report transition' using errcode = '22023';
  end if;
  if report_before.status = 'reviewing' and p_new_status = 'reviewing' then
    raise exception 'report is already under review' using errcode = '55000';
  end if;
  if p_new_status in ('resolved', 'dismissed') and normalized_resolution is null then
    raise exception 'resolution code is required to close a report' using errcode = '22023';
  end if;

  if p_action_kind is not null then
    if p_new_status <> 'resolved' then
      raise exception 'an enforcement action requires a resolved report' using errcode = '22023';
    end if;
    if p_action_kind not in ('warning', 'content_hidden', 'social_restricted', 'account_suspended') then
      raise exception 'invalid moderation action' using errcode = '22023';
    end if;

    action_subject_kind := coalesce(p_action_subject_kind, report_before.target_kind);
    action_subject_id := coalesce(p_action_subject_id, report_before.target_id);

    if action_subject_kind not in ('user', 'visit', 'comment') or action_subject_id is null then
      raise exception 'invalid moderation subject' using errcode = '22023';
    end if;
    if p_action_kind in ('social_restricted', 'account_suspended', 'warning')
       and action_subject_kind <> 'user' then
      raise exception 'user action requires a user subject' using errcode = '22023';
    end if;
    if p_action_kind = 'content_hidden' and action_subject_kind not in ('visit', 'comment') then
      raise exception 'content action requires a visit or comment subject' using errcode = '22023';
    end if;
    if (action_subject_kind = 'user' and not exists (
         select 1 from public.users subject where subject.id = action_subject_id
       ))
       or (action_subject_kind = 'visit' and not exists (
         select 1 from public.visits subject where subject.id = action_subject_id
       ))
       or (action_subject_kind = 'comment' and not exists (
         select 1 from public.comments subject where subject.id = action_subject_id
       )) then
      raise exception 'moderation subject unavailable' using errcode = 'P0002';
    end if;
    if p_action_ends_at is not null and p_action_ends_at <= now() then
      raise exception 'moderation action must end in the future' using errcode = '22023';
    end if;
  end if;

  update public.reports report
  set
    status = p_new_status,
    reviewed_by = actor,
    reviewed_at = coalesce(report.reviewed_at, now()),
    resolution_code = case
      when p_new_status in ('resolved', 'dismissed') then normalized_resolution
      else report.resolution_code
    end,
    closed_at = case
      when p_new_status in ('resolved', 'dismissed') then now()
      else null
    end
  where report.id = p_report_id
  returning * into report_after;

  insert into private.moderation_case_events (
    report_id,
    actor_user_id,
    event_kind,
    from_status,
    to_status,
    resolution_code,
    internal_note
  ) values (
    report_after.id,
    actor,
    case p_new_status
      when 'reviewing' then 'review_started'
      when 'resolved' then 'report_resolved'
      else 'report_dismissed'
    end,
    report_before.status,
    report_after.status,
    normalized_resolution,
    normalized_note
  );

  if p_action_kind is not null then
    insert into private.moderation_actions (
      report_id,
      subject_kind,
      subject_id,
      action_kind,
      reason_code,
      internal_note,
      ends_at,
      created_by
    ) values (
      report_after.id,
      action_subject_kind,
      action_subject_id,
      p_action_kind,
      normalized_resolution,
      normalized_note,
      p_action_ends_at,
      actor
    );

    insert into private.moderation_case_events (
      report_id,
      actor_user_id,
      event_kind,
      from_status,
      to_status,
      resolution_code,
      internal_note
    ) values (
      report_after.id,
      actor,
      'action_applied',
      report_after.status,
      report_after.status,
      normalized_resolution,
      normalized_note
    );
  end if;

  return report_after;
end;
$$;

create or replace function public.revoke_moderation_action_v1(
  p_action_id uuid,
  p_reason text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  action private.moderation_actions;
  normalized_reason text := nullif(trim(p_reason), '');
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not exists (
    select 1
    from private.moderation_operators operator
    where operator.user_id = actor
      and operator.role = 'admin'
      and operator.is_active
  ) then
    raise exception 'moderation administrator permission required' using errcode = '42501';
  end if;
  if normalized_reason is null or char_length(normalized_reason) > 280 then
    raise exception 'revocation reason is required' using errcode = '22023';
  end if;

  select * into action
  from private.moderation_actions existing_action
  where existing_action.id = p_action_id
  for update;

  if not found then
    raise exception 'moderation action unavailable' using errcode = 'P0002';
  end if;
  if action.revoked_at is null then
    update private.moderation_actions existing_action
    set revoked_at = now(), revoked_by = actor,
        revocation_reason = normalized_reason
    where existing_action.id = p_action_id
    returning * into action;

    if action.report_id is not null then
      insert into private.moderation_case_events (
        report_id, actor_user_id, event_kind, resolution_code, internal_note
      ) values (
        action.report_id, actor, 'action_revoked', action.reason_code,
        normalized_reason
      );
    end if;
  end if;

  return jsonb_build_object(
    'action_id', action.id,
    'subject_kind', action.subject_kind,
    'subject_id', action.subject_id,
    'action_kind', action.action_kind,
    'revoked_at', action.revoked_at
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Caller-bound comment ownership and removal
-- ---------------------------------------------------------------------------

alter table public.comments
  drop constraint if exists comments_removed_by_fkey,
  add constraint comments_removed_by_fkey
    foreign key (removed_by) references public.users(id) on delete set null not valid,
  add constraint comments_removal_reason_length_check
    check (char_length(coalesce(removal_reason, '')) <= 120),
  add constraint comments_removal_state_check
    check (
      (removed_at is null and removed_by is null and removal_reason is null)
      or (removed_at is not null and removal_reason is not null)
    );

alter table public.comments validate constraint comments_removed_by_fkey;

create index if not exists comments_visible_visit_created_idx
  on public.comments (visit_id, created_at, id)
  where removed_at is null;

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
  actor uuid := auth.uid();
  result public.comments;
  parent_author uuid;
  mentioned_user uuid;
  distinct_mentions uuid[];
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  if char_length(trim(coalesce(p_text, ''))) not between 1 and 2000 then
    raise exception 'comment must be between 1 and 2000 characters' using errcode = '22023';
  end if;
  if not private.can_view_visit_as(p_visit_id, actor) then
    raise exception 'visit unavailable' using errcode = '42501';
  end if;

  if p_parent_comment_id is not null then
    select comment.user_id into parent_author
    from public.comments comment
    where comment.id = p_parent_comment_id
      and comment.visit_id = p_visit_id
      and comment.parent_comment_id is null
      and comment.removed_at is null
      and not private.has_active_moderation_action(
        'comment', comment.id, array['content_hidden']::text[]
      );

    if parent_author is null or private.blocked_between(actor, parent_author) then
      raise exception 'reply parent unavailable' using errcode = '42501';
    end if;
  end if;

  select coalesce(array_agg(distinct requested_id), '{}'::uuid[])
  into distinct_mentions
  from unnest(coalesce(p_mentioned_user_ids, '{}'::uuid[])) requested_id
  where requested_id is not null and requested_id <> actor;

  if cardinality(distinct_mentions) > 20 then
    raise exception 'a comment can mention at most 20 people' using errcode = '22023';
  end if;

  insert into public.comments (user_id, visit_id, text, parent_comment_id)
  values (actor, p_visit_id, trim(p_text), p_parent_comment_id)
  returning * into result;

  foreach mentioned_user in array distinct_mentions loop
    if not private.can_view_user_as(mentioned_user, actor)
       or private.blocked_between(actor, mentioned_user)
       or not private.can_view_visit_as(p_visit_id, mentioned_user) then
      raise exception 'invalid mention target' using errcode = '42501';
    end if;

    insert into public.comment_mentions (comment_id, mentioned_user_id)
    values (result.id, mentioned_user)
    on conflict do nothing;
  end loop;

  return result;
end;
$$;

create or replace function public.update_comment_v1(
  p_comment_id uuid,
  p_text text
)
returns public.comments
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.comments;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  if char_length(trim(coalesce(p_text, ''))) not between 1 and 2000 then
    raise exception 'comment must be between 1 and 2000 characters' using errcode = '22023';
  end if;

  select * into target
  from public.comments comment
  where comment.id = p_comment_id
  for update;

  if not found or target.user_id <> actor or target.removed_at is not null
     or not private.can_view_visit_as(target.visit_id, actor) then
    raise exception 'comment unavailable' using errcode = '42501';
  end if;

  update public.comments comment
  set text = trim(p_text), edited_at = now()
  where comment.id = p_comment_id
  returning * into target;

  return target;
end;
$$;

create or replace function public.remove_comment_v1(
  p_comment_id uuid,
  p_reason text default 'removed_by_user'
)
returns public.comments
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.comments;
  visit_owner uuid;
  removed_time timestamptz := clock_timestamp();
  normalized_reason text := coalesce(nullif(trim(p_reason), ''), 'removed_by_user');
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if char_length(normalized_reason) > 120 then
    raise exception 'removal reason is too long' using errcode = '22023';
  end if;

  select comment.*
  into target
  from public.comments comment
  where comment.id = p_comment_id
  for update;

  if not found then
    raise exception 'comment unavailable' using errcode = '42501';
  end if;

  select visit.user_id into visit_owner
  from public.visits visit
  where visit.id = target.visit_id;

  if visit_owner is null or actor not in (target.user_id, visit_owner) then
    raise exception 'comment unavailable' using errcode = '42501';
  end if;
  if target.removed_at is not null then
    return target;
  end if;

  with comments_to_remove as (
    select comment.id
    from public.comments comment
    where comment.id = p_comment_id
       or comment.parent_comment_id = p_comment_id
  )
  update public.comments comment
  set
    removed_at = removed_time,
    removed_by = actor,
    removal_reason = normalized_reason
  where comment.id in (select id from comments_to_remove);

  delete from public.comment_mentions mention
  using public.comments comment
  where mention.comment_id = comment.id
    and comment.removed_at = removed_time
    and comment.removed_by = actor;

  select * into target
  from public.comments comment
  where comment.id = p_comment_id;

  return target;
end;
$$;

-- ---------------------------------------------------------------------------
-- Coherent blocking across the existing alpha social graph
-- ---------------------------------------------------------------------------

create or replace function public.block_user_v2(
  p_blocked_user_id uuid,
  p_remove_saved_recipe_copies boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  pair_key text;
  removed_time timestamptz := clock_timestamp();
  friendship_count integer := 0;
  request_count integer := 0;
  comment_count integer := 0;
  mention_count integer := 0;
  like_count integer := 0;
  reaction_count integer := 0;
  companion_count integer := 0;
  recommendation_count integer := 0;
  list_member_count integer := 0;
  shared_invitation_count integer := 0;
  shared_memory_count integer := 0;
  recipe_copy_count integer := 0;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_blocked_user_id is null or p_blocked_user_id = actor then
    raise exception 'invalid user' using errcode = '22023';
  end if;
  if not exists (select 1 from public.users where id = p_blocked_user_id) then
    raise exception 'user unavailable' using errcode = 'P0002';
  end if;

  pair_key := least(actor::text, p_blocked_user_id::text)
    || ':' || greatest(actor::text, p_blocked_user_id::text);
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(pair_key, 0)
  );

  insert into public.user_blocks (blocker_id, blocked_id)
  values (actor, p_blocked_user_id)
  on conflict (blocker_id, blocked_id) do nothing;

  delete from public.friends friendship
  where (friendship.user_id = actor and friendship.friend_user_id = p_blocked_user_id)
     or (friendship.user_id = p_blocked_user_id and friendship.friend_user_id = actor);
  get diagnostics friendship_count = row_count;

  delete from public.friend_requests request
  where (request.from_user_id = actor and request.to_user_id = p_blocked_user_id)
     or (request.from_user_id = p_blocked_user_id and request.to_user_id = actor);
  get diagnostics request_count = row_count;

  with directly_involved as (
    select comment.id
    from public.comments comment
    join public.visits visit on visit.id = comment.visit_id
    left join public.comments parent on parent.id = comment.parent_comment_id
    where comment.removed_at is null
      and (
        (comment.user_id = actor and visit.user_id = p_blocked_user_id)
        or (comment.user_id = p_blocked_user_id and visit.user_id = actor)
        or (comment.user_id = actor and parent.user_id = p_blocked_user_id)
        or (comment.user_id = p_blocked_user_id and parent.user_id = actor)
      )
  ), thread_comments as (
    select involved.id from directly_involved involved
    union
    select reply.id
    from public.comments reply
    join directly_involved involved on involved.id = reply.parent_comment_id
  )
  update public.comments comment
  set
    removed_at = removed_time,
    removed_by = actor,
    removal_reason = 'relationship_blocked'
  where comment.id in (select id from thread_comments)
    and comment.removed_at is null;
  get diagnostics comment_count = row_count;

  delete from public.comment_mentions mention
  using public.comments comment, public.visits visit
  where mention.comment_id = comment.id
    and visit.id = comment.visit_id
    and (
      (comment.user_id = actor and mention.mentioned_user_id = p_blocked_user_id)
      or (comment.user_id = p_blocked_user_id and mention.mentioned_user_id = actor)
      or (visit.user_id = actor and mention.mentioned_user_id = p_blocked_user_id)
      or (visit.user_id = p_blocked_user_id and mention.mentioned_user_id = actor)
      or (comment.removed_at = removed_time and comment.removed_by = actor)
    );
  get diagnostics mention_count = row_count;

  delete from public.likes like_row
  using public.visits visit
  where like_row.visit_id = visit.id
    and (
      (like_row.user_id = actor and visit.user_id = p_blocked_user_id)
      or (like_row.user_id = p_blocked_user_id and visit.user_id = actor)
    );
  get diagnostics like_count = row_count;

  delete from public.visit_reactions reaction
  using public.visits visit
  where reaction.visit_id = visit.id
    and (
      (reaction.user_id = actor and visit.user_id = p_blocked_user_id)
      or (reaction.user_id = p_blocked_user_id and visit.user_id = actor)
    );
  get diagnostics reaction_count = row_count;

  delete from public.visit_companions companion
  using public.visits visit
  where companion.visit_id = visit.id
    and (
      (visit.user_id = actor and companion.companion_user_id = p_blocked_user_id)
      or (visit.user_id = p_blocked_user_id and companion.companion_user_id = actor)
      or (companion.added_by = actor and companion.companion_user_id = p_blocked_user_id)
      or (companion.added_by = p_blocked_user_id and companion.companion_user_id = actor)
    );
  get diagnostics companion_count = row_count;

  delete from public.trusted_recommendations recommendation
  where (recommendation.sender_id = actor and recommendation.recipient_id = p_blocked_user_id)
     or (recommendation.sender_id = p_blocked_user_id and recommendation.recipient_id = actor);
  get diagnostics recommendation_count = row_count;

  -- List contributions are durable cafe data. Revoke collaboration access but
  -- retain the contributed cafe for the list owner and audit/export history.
  delete from public.cafe_list_members member
  using public.cafe_lists list
  where member.list_id = list.id
    and (
      (list.owner_id = actor and member.user_id = p_blocked_user_id)
      or (list.owner_id = p_blocked_user_id and member.user_id = actor)
    );
  get diagnostics list_member_count = row_count;

  -- Pending pairwise invitations are invalidated by a block.
  update public.shared_memory_members member
  set status = 'cancelled', responded_at = now()
  where member.status = 'pending'
    and (
      (member.invited_by = actor and member.user_id = p_blocked_user_id)
      or (member.invited_by = p_blocked_user_id and member.user_id = actor)
    );
  get diagnostics shared_invitation_count = row_count;

  -- Shared presentation is severed without deleting either person's journal
  -- post. The blocker leaves memories owned by someone else; when the blocker
  -- owns the memory, only the blocked participant is detached so unrelated
  -- accepted participants keep their grouping.
  with pair_memories as (
    select memory.id,
      case when memory.created_by = actor
        then p_blocked_user_id else actor end detached_user_id
    from public.shared_memories memory
    where (
      memory.created_by = actor
      or exists (
        select 1 from public.shared_memory_members member
        where member.shared_memory_id = memory.id
          and member.user_id = actor
          and member.status = 'accepted'
      )
      or exists (
        select 1 from public.shared_memory_contributions contribution
        where contribution.shared_memory_id = memory.id
          and contribution.user_id = actor
      )
    ) and (
      memory.created_by = p_blocked_user_id
      or exists (
        select 1 from public.shared_memory_members member
        where member.shared_memory_id = memory.id
          and member.user_id = p_blocked_user_id
          and member.status = 'accepted'
      )
      or exists (
        select 1 from public.shared_memory_contributions contribution
        where contribution.shared_memory_id = memory.id
          and contribution.user_id = p_blocked_user_id
      )
    )
  )
  delete from public.shared_memory_contributions contribution
  using pair_memories pair
  where contribution.shared_memory_id = pair.id
    and contribution.user_id = pair.detached_user_id;

  with pair_memories as (
    select memory.id,
      case when memory.created_by = actor
        then p_blocked_user_id else actor end detached_user_id
    from public.shared_memories memory
    where (
      memory.created_by in (actor, p_blocked_user_id)
      or exists (
        select 1 from public.shared_memory_members first_member
        where first_member.shared_memory_id = memory.id
          and first_member.user_id = actor
          and first_member.status = 'accepted'
      )
    ) and (
      memory.created_by = p_blocked_user_id
      or exists (
        select 1 from public.shared_memory_members second_member
        where second_member.shared_memory_id = memory.id
          and second_member.user_id = p_blocked_user_id
          and second_member.status = 'accepted'
      )
    )
  )
  update public.shared_memory_members member
  set status = 'left',
      responded_at = coalesce(member.responded_at, now()),
      left_at = now()
  from pair_memories pair
  where member.shared_memory_id = pair.id
    and member.user_id = pair.detached_user_id
    and member.status = 'accepted';
  get diagnostics shared_memory_count = row_count;

  if coalesce(p_remove_saved_recipe_copies, false) then
    delete from public.recipe_identities identity
    where identity.user_id = actor
      and exists (
        select 1
        from public.recipe_versions saved_version
        join public.recipe_versions source_version
          on source_version.id = saved_version.source_recipe_version_id
        join public.recipe_identities source_identity
          on source_identity.id = source_version.recipe_identity_id
        where saved_version.recipe_identity_id = identity.id
          and source_identity.user_id = p_blocked_user_id
      );
    get diagnostics recipe_copy_count = row_count;
  end if;

  return jsonb_build_object(
    'blocker_id', actor,
    'blocked_id', p_blocked_user_id,
    'blocked_at', now(),
    'severed', jsonb_build_object(
      'friendships', friendship_count,
      'friend_requests', request_count,
      'comments', comment_count,
      'mentions', mention_count,
      'likes', like_count,
      'reactions', reaction_count,
      'companions', companion_count,
      'recommendations', recommendation_count,
      'list_memberships', list_member_count,
      'shared_invitations', shared_invitation_count,
      'shared_memories', shared_memory_count,
      'saved_recipe_copies', recipe_copy_count
    )
  );
end;
$$;

create or replace function public.block_user(p_blocked_user_id uuid)
returns public.user_blocks
language plpgsql
security definer
set search_path = ''
as $$
declare
  result public.user_blocks;
begin
  perform public.block_user_v2(p_blocked_user_id, false);
  select * into result
  from public.user_blocks block
  where block.blocker_id = auth.uid()
    and block.blocked_id = p_blocked_user_id;
  return result;
end;
$$;

-- Existing reaction clients keep their signature while enforcement becomes
-- effective immediately.
create or replace function public.toggle_visit_reaction(
  p_visit_id uuid,
  p_reaction text
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  existing text;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_socially_mutate_as(actor) then
    raise exception 'social interactions are unavailable' using errcode = '42501';
  end if;
  if p_reaction not in ('want_to_try', 'great_find', 'dialed_in', 'cozy') then
    raise exception 'invalid reaction' using errcode = '22023';
  end if;
  if not private.can_view_visit_as(p_visit_id, actor) then
    raise exception 'sip unavailable' using errcode = '42501';
  end if;

  select reaction.reaction into existing
  from public.visit_reactions reaction
  where reaction.visit_id = p_visit_id and reaction.user_id = actor;

  if existing = p_reaction then
    delete from public.visit_reactions reaction
    where reaction.visit_id = p_visit_id and reaction.user_id = actor;
    return null;
  end if;

  insert into public.visit_reactions (visit_id, user_id, reaction)
  values (p_visit_id, actor, p_reaction)
  on conflict (visit_id, user_id) do update
    set reaction = excluded.reaction, created_at = now();
  return p_reaction;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS and aggregate coherence
-- ---------------------------------------------------------------------------

drop policy if exists "Authenticated users discover nonblocked profiles" on public.users;
create policy "Authenticated users discover available profiles" on public.users
  for select to authenticated
  using (public.can_view_user(id, (select auth.uid())));

-- Enforcement blocks shared publishing while leaving private journal capture
-- available. A restricted owner can still make an existing post private or
-- delete it through the existing owner-delete policy.
drop policy if exists "Owners create visits" on public.visits;
create policy "Owners create visits" on public.visits
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and (
      visibility = 'private'
      or public.can_socially_mutate((select auth.uid()))
    )
  );

drop policy if exists "Owners update visits" on public.visits;
create policy "Owners update visits" on public.visits
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (
      visibility = 'private'
      or public.can_socially_mutate((select auth.uid()))
    )
  );

drop policy if exists "Visible comments" on public.comments;
create policy "Visible comments" on public.comments
  for select to authenticated
  using (public.can_view_comment(id, (select auth.uid())));

drop policy if exists "Users update own comments" on public.comments;
drop policy if exists "Users delete own comments" on public.comments;

drop policy if exists "Users create own likes on visible visits" on public.likes;
create policy "Users create own likes on visible visits" on public.likes
  for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and public.can_socially_mutate((select auth.uid()))
    and public.can_view_visit(visit_id, (select auth.uid()))
  );

drop policy if exists "Visible likes" on public.likes;
create policy "Visible likes" on public.likes
  for select to authenticated
  using (
    public.can_view_visit(visit_id, (select auth.uid()))
    and public.can_view_user(user_id, (select auth.uid()))
  );

drop policy if exists "Visible visit reactions" on public.visit_reactions;
create policy "Visible visit reactions" on public.visit_reactions
  for select to authenticated
  using (
    public.can_view_visit(visit_id, (select auth.uid()))
    and public.can_view_user(user_id, (select auth.uid()))
  );

drop policy if exists "Visible sip companions" on public.visit_companions;
create policy "Visible sip companions" on public.visit_companions
  for select to authenticated
  using (
    public.can_view_visit(visit_id, (select auth.uid()))
    and public.can_view_user(companion_user_id, (select auth.uid()))
  );

drop policy if exists "Visible comment mentions" on public.comment_mentions;
create policy "Visible comment mentions" on public.comment_mentions
  for select to authenticated
  using (
    exists (
      select 1
      from public.comments comment
      where comment.id = comment_id
        and public.can_view_comment(comment.id, (select auth.uid()))
        and public.can_view_user(mentioned_user_id, (select auth.uid()))
    )
  );

-- Security-definer discovery functions must apply the same suspension rule as
-- direct profile RLS because they intentionally bypass table policies.
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
    select lower(trim(p_query)) q,
           least(greatest(p_limit, 1), 50) page_size,
           (select auth.uid()) viewer
  ), ranked as (
    select searched_user.*,
      case
        when lower(trim(searched_user.username)) = input.q then 0
        when lower(trim(searched_user.username)) like input.q || '%' then 1
        when lower(trim(searched_user.display_name)) like input.q || '%' then 2
        else 3
      end rank_bucket,
      greatest(
        extensions.similarity(lower(trim(searched_user.username)), input.q),
        extensions.similarity(lower(trim(searched_user.display_name)), input.q)
      )::real match_score,
      case
        when private.confirmed_friends(input.viewer, searched_user.id) then 'friends'
        when exists (
          select 1 from public.friend_requests request
          where request.from_user_id = input.viewer
            and request.to_user_id = searched_user.id
            and request.status = 'pending'
        ) then 'outgoing'
        when exists (
          select 1 from public.friend_requests request
          where request.from_user_id = searched_user.id
            and request.to_user_id = input.viewer
            and request.status = 'pending'
        ) then 'incoming'
        else 'none'
      end friendship_state,
      (
        select count(*)
        from public.friends mine
        join public.friends theirs
          on theirs.user_id = searched_user.id
         and theirs.friend_user_id = mine.friend_user_id
        where mine.user_id = input.viewer
          and not private.blocked_between(input.viewer, mine.friend_user_id)
      ) mutual_friend_count
    from public.users searched_user
    cross join input
    where input.viewer is not null
      and searched_user.id <> input.viewer
      and private.can_view_user_as(searched_user.id, input.viewer)
      and input.q <> ''
      and (
        lower(trim(searched_user.username)) like input.q || '%'
        or lower(trim(searched_user.display_name)) like input.q || '%'
        or extensions.similarity(lower(trim(searched_user.username)), input.q) >= 0.2
        or extensions.similarity(lower(trim(searched_user.display_name)), input.q) >= 0.2
      )
  )
  select ranked.id, ranked.display_name, ranked.username, ranked.bio,
         ranked.location, ranked.favorite_drink, ranked.avatar_url,
         ranked.banner_url, ranked.friendship_state,
         ranked.mutual_friend_count, ranked.rank_bucket, ranked.match_score
  from ranked, input
  where p_after_rank is null
     or (
       ranked.rank_bucket,
       -ranked.match_score,
       lower(ranked.username),
       ranked.id
     ) > (
       p_after_rank,
       -coalesce(p_after_score, 0),
       lower(coalesce(p_after_username, '')),
       p_after_id
     )
  order by ranked.rank_bucket, ranked.match_score desc,
           lower(ranked.username), ranked.id
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
  with viewer as (
    select auth.uid() id
  ), rows as (
    select friendship.id relationship_id, friendship.friend_user_id user_id,
      connected_user.display_name, connected_user.username,
      connected_user.avatar_url, friendship.created_at, 'friends'::text kind
    from public.friends friendship
    join viewer on friendship.user_id = viewer.id
    join public.users connected_user on connected_user.id = friendship.friend_user_id
    where p_kind = 'friends'
      and private.can_view_user_as(connected_user.id, viewer.id)
    union all
    select request.id, request.from_user_id, connected_user.display_name,
      connected_user.username, connected_user.avatar_url,
      request.created_at, 'incoming'
    from public.friend_requests request
    join viewer on request.to_user_id = viewer.id
    join public.users connected_user on connected_user.id = request.from_user_id
    where p_kind = 'incoming'
      and request.status = 'pending'
      and private.can_view_user_as(connected_user.id, viewer.id)
    union all
    select request.id, request.to_user_id, connected_user.display_name,
      connected_user.username, connected_user.avatar_url,
      request.created_at, 'outgoing'
    from public.friend_requests request
    join viewer on request.from_user_id = viewer.id
    join public.users connected_user on connected_user.id = request.to_user_id
    where p_kind = 'outgoing'
      and request.status = 'pending'
      and private.can_view_user_as(connected_user.id, viewer.id)
    union all
    select blocked_user.id, block.blocked_id, blocked_user.display_name,
      blocked_user.username, blocked_user.avatar_url,
      block.created_at, 'blocked'
    from public.user_blocks block
    join viewer on block.blocker_id = viewer.id
    join public.users blocked_user on blocked_user.id = block.blocked_id
    where p_kind = 'blocked'
  )
  select * from rows
  where p_after_created_at is null
     or (created_at, relationship_id) < (p_after_created_at, p_after_id)
  order by created_at desc, relationship_id desc
  limit least(greatest(p_limit, 1), 50);
$$;

create or replace function public.get_public_profile(p_user_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  viewer uuid := auth.uid();
  result jsonb;
begin
  if viewer is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if not private.can_view_user_as(p_user_id, viewer) then
    raise exception 'profile unavailable' using errcode = '42501';
  end if;

  select jsonb_build_object(
    'profile', to_jsonb(profile),
    'friendship_state', case
      when viewer = p_user_id then 'self'
      when private.confirmed_friends(viewer, p_user_id) then 'friends'
      when exists (
        select 1 from public.friend_requests request
        where request.from_user_id = viewer
          and request.to_user_id = p_user_id
          and request.status = 'pending'
      ) then 'outgoing'
      when exists (
        select 1 from public.friend_requests request
        where request.from_user_id = p_user_id
          and request.to_user_id = viewer
          and request.status = 'pending'
      ) then 'incoming'
      else 'none'
    end,
    'stats', jsonb_build_object(
      'visible_visits', (
        select count(*) from public.visits visit
        where visit.user_id = p_user_id
          and private.can_view_visit_as(visit.id, viewer)
      ),
      'friends', (
        select count(*) from public.friends friend
        where friend.user_id = p_user_id
      ),
      'cafes', (
        select count(distinct visit.cafe_id) from public.visits visit
        where visit.user_id = p_user_id
          and visit.cafe_id is not null
          and lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
          and private.can_view_visit_as(visit.id, viewer)
      ),
      'home_sips', (
        select count(*) from public.visits visit
        where visit.user_id = p_user_id
          and lower(coalesce(visit.context_type, '')) = 'home'
          and private.can_view_visit_as(visit.id, viewer)
      ),
      'recipe_sips', (
        select count(*) from public.visits visit
        where visit.user_id = p_user_id
          and lower(coalesce(visit.context_type, '')) = 'recipe'
          and private.can_view_visit_as(visit.id, viewer)
      )
    ),
    'visits', coalesce((
      select jsonb_agg(
        to_jsonb(visible_visit)
        order by visible_visit.created_at desc, visible_visit.id desc
      )
      from (
        select
          visit.id, visit.user_id, visit.cafe_id, visit.caption,
          visit.drink_type, visit.drink_type_custom, visit.drink_subtype,
          visit.visibility, visit.ratings, visit.overall_score,
          visit.poster_photo_url, visit.context_type, visit.location_name,
          visit.created_at, cafe.name cafe_name, cafe.city cafe_city,
          cafe.latitude, cafe.longitude, cafe.identity_key
        from public.visits visit
        left join public.cafes cafe
          on cafe.id = visit.cafe_id
         and lower(coalesce(visit.context_type, 'cafe')) = 'cafe'
        where visit.user_id = p_user_id
          and private.can_view_visit_as(visit.id, viewer)
        order by visit.created_at desc, visit.id desc
        limit 50
      ) visible_visit
    ), '[]'::jsonb)
  )
  into result
  from public.users profile
  where profile.id = p_user_id;

  if result is null then
    raise exception 'profile unavailable' using errcode = 'P0002';
  end if;
  return result;
end;
$$;

-- A Cafe Session is one feed story. Counts exclude removed or moderated
-- comments so block/removal results are consistent between detail and feed.
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
  with input as (
    select auth.uid() viewer
  ), base as (
    select
      visit.*,
      author.display_name,
      author.username,
      author.avatar_url,
      cafe.name cafe_name,
      cafe.latitude,
      cafe.longitude,
      (
        select count(*)
        from public.likes likes
        where likes.visit_id = visit.id
          and not private.has_active_moderation_action(
            'user', likes.user_id, array['account_suspended']::text[]
          )
      ) likes,
      (
        select count(*)
        from public.comments comments
        where comments.visit_id = visit.id
          and comments.removed_at is null
          and not private.has_active_moderation_action(
            'comment', comments.id, array['content_hidden']::text[]
          )
          and not private.has_active_moderation_action(
            'user', comments.user_id, array['account_suspended']::text[]
          )
      ) comments,
      case
        when visit.user_id = input.viewer then .85
        when private.confirmed_friends(input.viewer, visit.user_id) then 1.0
        else .15
      end trust,
      exp(-extract(epoch from (now() - visit.created_at)) / 86400 / 12) recency,
      case
        when p_latitude between -90 and 90 and p_longitude between -180 and 180
             and cafe.latitude is not null and cafe.longitude is not null then
          greatest(0, 1 - (
            6371 * 2 * asin(sqrt(
              power(sin(radians(cafe.latitude - p_latitude) / 2), 2)
              + cos(radians(p_latitude)) * cos(radians(cafe.latitude))
              * power(sin(radians(cafe.longitude - p_longitude) / 2), 2)
            ))
          ) / 50)
      end geo,
      exists (
        select 1
        from public.user_cafe_states saved
        where saved.user_id = input.viewer
          and saved.cafe_id = visit.cafe_id
          and (saved.is_favorite or saved.want_to_try)
      ) saved_match,
      exists (
        select 1
        from public.visits mine
        where mine.user_id = input.viewer
          and mine.upload_state = 'complete'
          and coalesce(mine.drink_subtype, mine.drink_type_custom, mine.drink_type)
              = coalesce(visit.drink_subtype, visit.drink_type_custom, visit.drink_type)
      ) journal_affinity,
      visit.user_id <> input.viewer and exists (
        select 1
        from public.taste_signals mine
        join public.taste_signals theirs
          on theirs.signal_type = mine.signal_type
         and theirs.attribute = mine.attribute
        where mine.user_id = input.viewer
          and theirs.user_id = visit.user_id
          and mine.owner_state <> 'dismissed'
          and theirs.owner_state <> 'dismissed'
          and mine.support_count >= 3
          and theirs.support_count >= 3
      ) taste_match
    from public.visits visit
    cross join input
    join public.users author on author.id = visit.user_id
    left join public.cafes cafe on cafe.id = visit.cafe_id
    where input.viewer is not null
      and visit.upload_state = 'complete'
      and (
        visit.cafe_session_id is null
        or visit.cafe_session_role = 'primary'
      )
      and private.can_view_visit_as(visit.id, input.viewer)
      and case p_scope
        when 'friends' then visit.user_id = input.viewer
          or (
            visit.visibility in ('friends', 'everyone')
            and private.confirmed_friends(input.viewer, visit.user_id)
          )
        when 'everyone' then visit.visibility = 'everyone'
        when 'ranked' then true
        else false
      end
  ), diversified as (
    select base.*,
      row_number() over (
        partition by base.user_id order by base.created_at desc, base.id desc
      ) author_rank,
      row_number() over (
        partition by base.cafe_id order by base.created_at desc, base.id desc
      ) cafe_rank,
      row_number() over (
        partition by coalesce(base.drink_subtype, base.drink_type_custom, base.drink_type)
        order by base.created_at desc, base.id desc
      ) drink_rank
    from base
  ), scored as (
    select diversified.*,
      greatest(0,
        .35 * diversified.recency
        + .25 * diversified.trust
        + .15 * (case when diversified.taste_match then 1 else 0 end)
        + .10 * greatest(
          case when diversified.saved_match then 1 else 0 end,
          coalesce(diversified.geo, 0)
        )
        + .10 * (case when diversified.journal_affinity then 1 else 0 end)
        + .05 * least(
          (diversified.likes + diversified.comments * 2)::double precision / 10,
          1
        )
        - least(greatest(diversified.author_rank - 1, 0), 2) * .035
        - least(greatest(diversified.cafe_rank - 1, 0), 2) * .020
        - least(greatest(diversified.drink_rank - 1, 0), 2) * .015
      ) score
    from diversified
  )
  select
    scored.id, scored.user_id, scored.cafe_id, scored.caption,
    coalesce(scored.drink_subtype, scored.drink_type_custom, scored.drink_type),
    scored.overall_score, scored.poster_photo_url, scored.created_at,
    scored.display_name, scored.username, scored.avatar_url, scored.cafe_name,
    scored.likes, scored.comments,
    case when p_scope = 'ranked' then scored.score else 1::double precision end,
    case
      when p_scope <> 'ranked' then null
      when scored.user_id <> (select viewer from input) and scored.trust = 1
        then 'A recent sip from your friend'
      when scored.taste_match then 'Matches patterns in your tasting passport'
      when scored.saved_match then 'From a cafe you saved'
      when coalesce(scored.geo, 0) >= .65 then 'A sip from a cafe near you'
      when scored.journal_affinity then 'Inspired by drinks in your journal'
      else 'A recent sip from the Mugshot community'
    end,
    case
      when p_scope <> 'ranked' then null
      when scored.user_id <> (select viewer from input) and scored.trust = 1
        then 'friend_activity'
      when scored.taste_match then 'taste_match'
      when scored.saved_match then 'saved_cafe'
      when coalesce(scored.geo, 0) >= .65 then 'nearby_cafe'
      when scored.journal_affinity then 'journal_evidence'
      else 'recent_community'
    end
  from scored
  where case
    when p_scope = 'ranked' then
      p_after_score is null
      or (scored.score, scored.created_at, scored.id)
        < (p_after_score, p_after_created_at, p_after_id)
    else
      p_after_created_at is null
      or (scored.created_at, scored.id) < (p_after_created_at, p_after_id)
  end
  order by
    case when p_scope = 'ranked' then scored.score end desc,
    scored.created_at desc,
    scored.id desc
  limit least(greatest(coalesce(p_limit, 20), 1), 50);
$$;

-- Direct evidence and moderation writes are closed. Existing read and like
-- surfaces remain available under RLS; comments mutate only through RPCs.
revoke all on table public.reports from public, anon, authenticated;
grant select on table public.reports to authenticated;

revoke insert, update, delete, truncate, references, trigger
  on table public.comments from authenticated;
grant select on table public.comments to authenticated;

revoke all on function public.submit_report_v2(
  uuid,public.report_reason,text,uuid,text
) from public, anon, authenticated;
revoke all on function public.submit_report(
  public.report_reason,text,uuid,uuid,uuid
) from public, anon, authenticated;
revoke all on function public.get_report_receipt_v1(uuid)
  from public, anon, authenticated;
revoke all on function public.review_report_v1(
  uuid,public.report_status,text,text,text,text,uuid,timestamptz
) from public, anon, authenticated;
revoke all on function public.revoke_moderation_action_v1(uuid,text)
  from public, anon, authenticated;
revoke all on function public.create_comment(uuid,text,uuid,uuid[])
  from public, anon, authenticated;
revoke all on function public.update_comment_v1(uuid,text)
  from public, anon, authenticated;
revoke all on function public.remove_comment_v1(uuid,text)
  from public, anon, authenticated;
revoke all on function public.block_user_v2(uuid,boolean)
  from public, anon, authenticated;
revoke all on function public.block_user(uuid)
  from public, anon, authenticated;
revoke all on function public.toggle_visit_reaction(uuid,text)
  from public, anon, authenticated;
revoke all on function public.ranked_feed(
  text,double precision,double precision,integer,double precision,timestamptz,uuid
) from public, anon, authenticated;
revoke all on function public.search_users(text,integer,integer,real,text,uuid)
  from public, anon, authenticated;
revoke all on function public.list_social_connections(text,integer,timestamptz,uuid)
  from public, anon, authenticated;
revoke all on function public.get_public_profile(uuid)
  from public, anon, authenticated;

grant execute on function public.submit_report_v2(
  uuid,public.report_reason,text,uuid,text
) to authenticated;
grant execute on function public.submit_report(
  public.report_reason,text,uuid,uuid,uuid
) to authenticated;
grant execute on function public.get_report_receipt_v1(uuid)
  to authenticated;
grant execute on function public.review_report_v1(
  uuid,public.report_status,text,text,text,text,uuid,timestamptz
) to authenticated;
grant execute on function public.revoke_moderation_action_v1(uuid,text)
  to authenticated;
grant execute on function public.create_comment(uuid,text,uuid,uuid[])
  to authenticated;
grant execute on function public.update_comment_v1(uuid,text)
  to authenticated;
grant execute on function public.remove_comment_v1(uuid,text)
  to authenticated;
grant execute on function public.block_user_v2(uuid,boolean)
  to authenticated;
grant execute on function public.block_user(uuid)
  to authenticated;
grant execute on function public.toggle_visit_reaction(uuid,text)
  to authenticated;
grant execute on function public.ranked_feed(
  text,double precision,double precision,integer,double precision,timestamptz,uuid
) to authenticated;
grant execute on function public.search_users(text,integer,integer,real,text,uuid)
  to authenticated;
grant execute on function public.list_social_connections(text,integer,timestamptz,uuid)
  to authenticated;
grant execute on function public.get_public_profile(uuid)
  to authenticated;

drop policy if exists "Reporters create reports" on public.reports;
drop policy if exists "Reporters read own reports" on public.reports;
create policy "Reporters read own report receipts" on public.reports
  for select to authenticated
  using (reporter_subject_id = (select auth.uid()));

comment on function public.submit_report_v2(
  uuid,public.report_reason,text,uuid,text
) is 'Idempotent caller-bound report submission with an immutable evidence snapshot.';

comment on function public.block_user_v2(uuid,boolean) is
  'Idempotently blocks a user, severs pairwise social presentation, and optionally removes the blocker''s saved adaptations from that account.';

comment on function public.remove_comment_v1(uuid,text) is
  'Soft-removes a comment thread for its author or the owner of the containing sip.';

commit;
