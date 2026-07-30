begin;

-- Harden short-lived recipe staging and consented collaboration without
-- rewriting published visits, recipes, shared MugShots, or cafe-list content.

-- ---------------------------------------------------------------------------
-- Recipe payload staging: live owners, bounded queues, and durable expiry
-- ---------------------------------------------------------------------------

alter table private.visit_recipe_payload_staging
  drop constraint if exists visit_recipe_payload_staging_user_id_fkey;

alter table private.visit_recipe_payload_staging
  add constraint visit_recipe_payload_staging_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade not valid;

create or replace function private.guard_visit_recipe_payload_stage_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  active_stage_count integer;
begin
  if not private.is_live_account_as(new.user_id) then
    raise exception 'account unavailable' using errcode = '42501';
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('recipe-stage:' || new.user_id::text, 0)
  );

  delete from private.visit_recipe_payload_staging stage
  where stage.user_id = new.user_id
    and stage.expires_at <= now()
    and stage.visit_id <> new.visit_id;

  if tg_op = 'INSERT' and not exists (
    select 1
    from private.visit_recipe_payload_staging stage
    where stage.visit_id = new.visit_id
      and stage.user_id = new.user_id
  ) then
    select count(*) into active_stage_count
    from private.visit_recipe_payload_staging stage
    where stage.user_id = new.user_id
      and stage.expires_at > now();

    if active_stage_count >= 20 then
      raise exception 'too many pending recipe drafts' using errcode = '54000';
    end if;
  end if;

  new.expires_at := least(
    coalesce(new.expires_at, now() + interval '24 hours'),
    now() + interval '24 hours'
  );
  return new;
end;
$$;

revoke all on function private.guard_visit_recipe_payload_stage_v3()
  from public, anon, authenticated;

drop trigger if exists guard_visit_recipe_payload_stage_v3
  on private.visit_recipe_payload_staging;
create trigger guard_visit_recipe_payload_stage_v3
before insert or update of user_id, expires_at
on private.visit_recipe_payload_staging
for each row execute function private.guard_visit_recipe_payload_stage_v3();

create or replace function public.purge_expired_recipe_staging_v3(
  p_limit integer default 1000
)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
  removed_count integer;
begin
  with expired as (
    select stage.visit_id
    from private.visit_recipe_payload_staging stage
    where stage.expires_at <= now()
    order by stage.expires_at, stage.visit_id
    limit greatest(1, least(coalesce(p_limit, 1000), 5000))
    for update skip locked
  )
  delete from private.visit_recipe_payload_staging stage
  using expired
  where stage.visit_id = expired.visit_id;

  get diagnostics removed_count = row_count;
  return removed_count;
end;
$$;

revoke all on function public.purge_expired_recipe_staging_v3(integer)
  from public, anon, authenticated;
grant execute on function public.purge_expired_recipe_staging_v3(integer)
  to service_role;

-- ---------------------------------------------------------------------------
-- Consent invitations: bounded lifetime and durable inviter semantics
-- ---------------------------------------------------------------------------

alter table public.cafe_list_members
  add column if not exists expires_at timestamptz;

alter table public.cafe_list_members
  alter column invited_by drop not null,
  drop constraint if exists cafe_list_members_invited_by_fkey;

alter table public.cafe_list_members
  add constraint cafe_list_members_invited_by_fkey
  foreign key (invited_by) references public.users(id) on delete set null;

create index if not exists cafe_list_members_pending_expiry_idx
  on public.cafe_list_members (expires_at, list_id, user_id)
  where invitation_status = 'pending';

alter table public.shared_memory_members
  add column if not exists expires_at timestamptz;

create index if not exists shared_memory_members_pending_expiry_idx
  on public.shared_memory_members (expires_at, shared_memory_id, user_id)
  where status = 'pending';

-- Existing pending invitations predate the bounded-consent contract. Preserve
-- every still-actionable invitation with a deterministic original deadline,
-- and close only requests whose 14-day window had already elapsed.
update public.cafe_list_members
set invitation_status = 'cancelled',
    responded_at = coalesce(responded_at, created_at + interval '14 days'),
    updated_at = now(),
    expires_at = null
where invitation_status = 'pending'
  and created_at + interval '14 days' <= now();

update public.cafe_list_members
set expires_at = least(created_at + interval '14 days', now() + interval '14 days')
where invitation_status = 'pending'
  and expires_at is null;

update public.shared_memory_members
set status = 'cancelled',
    responded_at = coalesce(responded_at, created_at + interval '14 days'),
    expires_at = null
where status = 'pending'
  and created_at + interval '14 days' <= now();

update public.shared_memory_members
set expires_at = least(created_at + interval '14 days', now() + interval '14 days')
where status = 'pending'
  and expires_at is null;

create or replace function private.guard_cafe_list_invitation_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_owner uuid;
begin
  if tg_op = 'UPDATE' then
    if old.invited_by is not null
       and new.invited_by is null
       and new.invitation_status = 'pending' then
      new.invitation_status := 'cancelled';
      new.responded_at := now();
      new.updated_at := now();
      new.expires_at := null;
      return new;
    end if;
  end if;

  if new.invitation_status = 'pending' then
    select list.owner_id into current_owner
    from public.cafe_lists list
    where list.id = new.list_id
    for share;

    if current_owner is null
       or new.invited_by is distinct from current_owner
       or not private.can_socially_mutate_as(current_owner)
       or not private.is_live_account_as(new.user_id) then
      raise exception 'cafe list invitation is unavailable' using errcode = '42501';
    end if;
    new.expires_at := least(
      coalesce(new.expires_at, now() + interval '14 days'),
      now() + interval '14 days'
    );
  elsif new.invitation_status = 'accepted' then
    if tg_op = 'UPDATE' then
      if old.invitation_status = 'pending' and (
        old.expires_at is not null and old.expires_at <= now()
      ) then
        raise exception 'cafe list invitation expired' using errcode = '42501';
      end if;
      if old.invitation_status = 'pending' then
        select list.owner_id into current_owner
        from public.cafe_lists list
        where list.id = new.list_id
        for share;
        if current_owner is null
           or old.invited_by is distinct from current_owner
           or not private.can_socially_mutate_as(current_owner)
           or not private.can_socially_mutate_as(new.user_id) then
          raise exception 'cafe list invitation is unavailable' using errcode = '42501';
        end if;
      end if;
    end if;
    new.expires_at := null;
  elsif new.invitation_status in ('declined', 'cancelled') then
    new.expires_at := null;
  end if;

  return new;
end;
$$;

create or replace function private.guard_shared_memory_invitation_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  current_creator uuid;
begin
  if tg_op = 'UPDATE' then
    if old.invited_by is not null
       and new.invited_by is null
       and new.status = 'pending' then
      new.status := 'cancelled';
      new.responded_at := now();
      new.expires_at := null;
      return new;
    end if;
  end if;

  if new.status = 'pending' then
    select memory.created_by into current_creator
    from public.shared_memories memory
    where memory.id = new.shared_memory_id
    for share;

    if current_creator is null
       or new.invited_by is distinct from current_creator
       or not private.can_socially_mutate_as(current_creator)
       or not private.is_live_account_as(new.user_id) then
      raise exception 'shared MugShot invitation is unavailable' using errcode = '42501';
    end if;
    new.expires_at := least(
      coalesce(new.expires_at, now() + interval '14 days'),
      now() + interval '14 days'
    );
  elsif new.status = 'accepted' then
    if tg_op = 'UPDATE' then
      if old.status = 'pending' and (
        old.expires_at is not null and old.expires_at <= now()
      ) then
        raise exception 'shared MugShot invitation expired' using errcode = '42501';
      end if;
      if old.status = 'pending' then
        select memory.created_by into current_creator
        from public.shared_memories memory
        where memory.id = new.shared_memory_id
        for share;
        if current_creator is null
           or old.invited_by is distinct from current_creator
           or not private.can_socially_mutate_as(current_creator)
           or not private.can_socially_mutate_as(new.user_id) then
          raise exception 'shared MugShot invitation is unavailable' using errcode = '42501';
        end if;
      end if;
    end if;
    new.expires_at := null;
  elsif new.status in ('declined', 'cancelled', 'left') then
    new.expires_at := null;
  end if;

  return new;
end;
$$;

revoke all on function private.guard_cafe_list_invitation_v3()
  from public, anon, authenticated;
revoke all on function private.guard_shared_memory_invitation_v3()
  from public, anon, authenticated;

drop trigger if exists guard_cafe_list_invitation_v3
  on public.cafe_list_members;
create trigger guard_cafe_list_invitation_v3
before insert or update of invitation_status, invited_by, expires_at
on public.cafe_list_members
for each row execute function private.guard_cafe_list_invitation_v3();

drop trigger if exists guard_shared_memory_invitation_v3
  on public.shared_memory_members;
create trigger guard_shared_memory_invitation_v3
before insert or update of status, invited_by, expires_at
on public.shared_memory_members
for each row execute function private.guard_shared_memory_invitation_v3();

create or replace function private.cancel_pending_cafe_list_invites_on_transfer_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.owner_id is distinct from old.owner_id then
    update public.cafe_list_members member
    set invitation_status = 'cancelled',
        responded_at = now(),
        updated_at = now(),
        expires_at = null
    where member.list_id = new.id
      and member.invitation_status = 'pending';
  end if;
  return new;
end;
$$;

revoke all on function private.cancel_pending_cafe_list_invites_on_transfer_v3()
  from public, anon, authenticated;

drop trigger if exists cancel_pending_cafe_list_invites_on_transfer_v3
  on public.cafe_lists;
create trigger cancel_pending_cafe_list_invites_on_transfer_v3
after update of owner_id on public.cafe_lists
for each row execute function private.cancel_pending_cafe_list_invites_on_transfer_v3();

create or replace function private.enforce_shared_memory_participant_cap_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  creator uuid;
  participant_count integer;
begin
  -- Decline, cancel, and leave are safety exits. They must remain available
  -- even if pre-hardening data already exceeds the new participant cap.
  if new.status not in ('pending', 'accepted') then
    return null;
  end if;
  if tg_op = 'UPDATE'
     and old.status in ('pending', 'accepted')
     and old.shared_memory_id = new.shared_memory_id then
    return null;
  end if;

  perform 1
  from public.shared_memories memory
  where memory.id = new.shared_memory_id
  for update;

  select memory.created_by into creator
  from public.shared_memories memory
  where memory.id = new.shared_memory_id;

  select count(*) into participant_count
  from public.shared_memory_members member
  where member.shared_memory_id = new.shared_memory_id
    and member.user_id is distinct from creator
    and member.status in ('pending', 'accepted');

  if participant_count > 12 then
    raise exception 'a shared MugShot can include at most 12 invited people'
      using errcode = '54000';
  end if;
  return null;
end;
$$;

revoke all on function private.enforce_shared_memory_participant_cap_v3()
  from public, anon, authenticated;

drop trigger if exists enforce_shared_memory_participant_cap_v3
  on public.shared_memory_members;
create constraint trigger enforce_shared_memory_participant_cap_v3
after insert or update of status, user_id, shared_memory_id
on public.shared_memory_members
deferrable initially immediate
for each row execute function private.enforce_shared_memory_participant_cap_v3();

create or replace function public.purge_expired_collaboration_invites_v3(
  p_limit integer default 1000
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  cafe_count integer;
  shared_count integer;
  bounded_limit integer := greatest(1, least(coalesce(p_limit, 1000), 5000));
begin
  with expired as (
    select member.list_id, member.user_id
    from public.cafe_list_members member
    where member.invitation_status = 'pending'
      and member.expires_at <= now()
    order by member.expires_at, member.list_id, member.user_id
    limit bounded_limit
    for update skip locked
  )
  update public.cafe_list_members member
  set invitation_status = 'cancelled',
      responded_at = now(),
      updated_at = now(),
      expires_at = null
  from expired
  where member.list_id = expired.list_id
    and member.user_id = expired.user_id;
  get diagnostics cafe_count = row_count;

  with expired as (
    select member.id
    from public.shared_memory_members member
    where member.status = 'pending'
      and member.expires_at <= now()
    order by member.expires_at, member.id
    limit bounded_limit
    for update skip locked
  )
  update public.shared_memory_members member
  set status = 'cancelled',
      responded_at = now(),
      expires_at = null
  from expired
  where member.id = expired.id;
  get diagnostics shared_count = row_count;

  return jsonb_build_object(
    'cafe_list_invitations', cafe_count,
    'shared_mugshot_invitations', shared_count
  );
end;
$$;

revoke all on function public.purge_expired_collaboration_invites_v3(integer)
  from public, anon, authenticated;
grant execute on function public.purge_expired_collaboration_invites_v3(integer)
  to service_role;

-- Schedule expiry when pg_cron is already enabled. The deployment gate checks
-- that this job exists before alpha collaboration is enabled.
do $$
declare
  existing_job_id bigint;
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    execute $sql$
      select jobid
      from cron.job
      where jobname = 'mugshot-alpha-ephemera-v3'
      limit 1
    $sql$ into existing_job_id;

    if existing_job_id is null then
      perform cron.schedule(
        'mugshot-alpha-ephemera-v3',
        '*/15 * * * *',
        'select public.purge_expired_recipe_staging_v3(1000); select public.purge_expired_collaboration_invites_v3(1000);'
      );
    end if;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Enforcement-aware recipe, Taste Passport, and ownership projections
-- ---------------------------------------------------------------------------

create or replace function private.alpha_audience_breadth_v3(p_visibility text)
returns smallint
language sql
immutable
security definer
set search_path = ''
as $$
  select case lower(coalesce(p_visibility, ''))
    when 'everyone' then 2
    when 'friends' then 1
    else 0
  end::smallint;
$$;

revoke all on function private.alpha_audience_breadth_v3(text)
  from public, anon, authenticated;

create or replace function private.can_project_recipe_version_as(
  p_version_id uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not null and exists (
    select 1
    from public.recipe_versions version
    join public.recipe_identities identity
      on identity.id = version.recipe_identity_id
    where version.id = p_version_id
      and private.can_view_user_as(identity.user_id, p_viewer)
      and (
        identity.user_id = p_viewer
        or version.visibility = 'everyone'
        or (
          version.visibility = 'friends'
          and private.confirmed_friends(p_viewer, identity.user_id)
        )
        or exists (
          select 1
          from public.trusted_recommendations recommendation
          where recommendation.target_kind = 'recipe'
            and recommendation.target_recipe_version_id = version.id
            and recommendation.recipient_id = p_viewer
            and recommendation.status <> 'dismissed'
            and private.can_view_user_as(recommendation.sender_id, p_viewer)
        )
      )
  );
$$;

create or replace function private.can_view_taste_passport_as(
  p_owner uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select private.can_view_user_as(p_owner, p_viewer)
    and exists (
      select 1
      from public.users owner
      where owner.id = p_owner
        and (
          owner.id = p_viewer
          or owner.taste_passport_visibility = 'everyone'
          or (
            owner.taste_passport_visibility = 'friends'
            and private.confirmed_friends(p_viewer, owner.id)
          )
        )
    );
$$;

revoke all on function private.can_project_recipe_version_as(uuid,uuid)
  from public, anon, authenticated;
revoke all on function private.can_view_taste_passport_as(uuid,uuid)
  from public, anon, authenticated;

create or replace function private.guard_recipe_visibility_expansion_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  owner_id uuid;
  expands_audience boolean;
  expands_public_reuse boolean;
begin
  select identity.user_id into owner_id
  from public.recipe_identities identity
  where identity.id = new.recipe_identity_id;
  if owner_id is null then
    raise exception 'recipe owner unavailable' using errcode = '42501';
  end if;
  if actor is not null and actor <> owner_id then
    raise exception 'recipe ownership required' using errcode = '42501';
  end if;

  if tg_op = 'INSERT' then
    expands_audience := private.alpha_audience_breadth_v3(new.visibility) > 0;
    expands_public_reuse := new.visibility = 'everyone'
      and new.source_kind in ('original', 'adapted')
      and coalesce(new.redistribution_allowed, false);
  else
    expands_audience := private.alpha_audience_breadth_v3(new.visibility)
      > private.alpha_audience_breadth_v3(old.visibility);
    expands_public_reuse := (
      new.visibility = 'everyone'
      and new.source_kind in ('original', 'adapted')
      and coalesce(new.redistribution_allowed, false)
    ) and not (
      old.visibility = 'everyone'
      and old.source_kind in ('original', 'adapted')
      and coalesce(old.redistribution_allowed, false)
    );
  end if;
  if (expands_audience or expands_public_reuse)
     and not private.can_socially_mutate_as(owner_id) then
    raise exception 'recipe sharing expansion is unavailable' using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function private.guard_recipe_source_reuse_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_owner uuid;
  source_owner uuid;
  source_visibility text;
  source_kind text;
  source_redistribution boolean;
begin
  if new.source_recipe_version_id is null then return new; end if;

  select identity.user_id into target_owner
  from public.recipe_identities identity
  where identity.id = new.recipe_identity_id;
  select
    identity.user_id,
    version.visibility,
    version.source_kind,
    version.redistribution_allowed
  into source_owner, source_visibility, source_kind, source_redistribution
  from public.recipe_versions version
  join public.recipe_identities identity
    on identity.id = version.recipe_identity_id
  where version.id = new.source_recipe_version_id;

  if target_owner is null or source_owner is null then
    raise exception 'recipe source is unavailable' using errcode = '42501';
  end if;
  if actor is not null and actor <> target_owner then
    raise exception 'recipe ownership required' using errcode = '42501';
  end if;
  if source_owner = target_owner then
    if not private.is_live_account_as(target_owner) then
      raise exception 'recipe owner unavailable' using errcode = '42501';
    end if;
    return new;
  end if;

  if not private.can_socially_mutate_as(target_owner)
     or not private.can_view_user_as(source_owner, target_owner)
     or source_visibility <> 'everyone'
     or source_kind not in ('original', 'adapted')
     or not source_redistribution then
    raise exception 'recipe source is unavailable for adaptation' using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function private.guard_taste_passport_expansion_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is not null and actor <> new.id then
    raise exception 'account scope mismatch' using errcode = '42501';
  end if;
  if private.alpha_audience_breadth_v3(new.taste_passport_visibility)
       > private.alpha_audience_breadth_v3(old.taste_passport_visibility)
     and not private.can_socially_mutate_as(new.id) then
    raise exception 'Taste Passport audience expansion is unavailable'
      using errcode = '42501';
  end if;
  return new;
end;
$$;

create or replace function private.guard_cafe_list_owner_transfer_v3()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.owner_id is distinct from old.owner_id
     and new.owner_id is not null
     and not private.can_socially_mutate_as(new.owner_id) then
    raise exception 'new cafe list owner is unavailable' using errcode = '42501';
  end if;
  return new;
end;
$$;

revoke all on function private.guard_recipe_visibility_expansion_v3()
  from public, anon, authenticated;
revoke all on function private.guard_recipe_source_reuse_v3()
  from public, anon, authenticated;
revoke all on function private.guard_taste_passport_expansion_v3()
  from public, anon, authenticated;
revoke all on function private.guard_cafe_list_owner_transfer_v3()
  from public, anon, authenticated;

drop trigger if exists guard_recipe_visibility_expansion_v3
  on public.recipe_versions;
create trigger guard_recipe_visibility_expansion_v3
before insert or update of visibility, source_kind, redistribution_allowed,
  recipe_identity_id
on public.recipe_versions
for each row execute function private.guard_recipe_visibility_expansion_v3();

drop trigger if exists guard_recipe_source_reuse_v3
  on public.recipe_versions;
create trigger guard_recipe_source_reuse_v3
before insert or update of source_recipe_version_id, recipe_identity_id
on public.recipe_versions
for each row execute function private.guard_recipe_source_reuse_v3();

drop trigger if exists guard_taste_passport_expansion_v3
  on public.users;
create trigger guard_taste_passport_expansion_v3
before update of taste_passport_visibility on public.users
for each row execute function private.guard_taste_passport_expansion_v3();

drop trigger if exists guard_cafe_list_owner_transfer_v3
  on public.cafe_lists;
create trigger guard_cafe_list_owner_transfer_v3
before update of owner_id on public.cafe_lists
for each row execute function private.guard_cafe_list_owner_transfer_v3();

-- ---------------------------------------------------------------------------
-- Deterministic list ordering under concurrent collaborator edits
-- ---------------------------------------------------------------------------

create or replace function private.normalize_cafe_list_positions_v3(
  p_list_id uuid
)
returns void
language sql
security definer
set search_path = ''
as $$
  with ordered as (
    select item.id,
           (row_number() over (
             order by item.position, item.created_at, item.id
           ) - 1)::integer as normalized_position
    from public.cafe_list_items item
    where item.list_id = p_list_id
  )
  update public.cafe_list_items item
  set position = ordered.normalized_position
  from ordered
  where item.id = ordered.id
    and item.position is distinct from ordered.normalized_position;
$$;

revoke all on function private.normalize_cafe_list_positions_v3(uuid)
  from public, anon, authenticated;

create or replace function public.remove_cafe_list_item(p_item_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_list_id uuid;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select item.list_id into target_list_id
  from public.cafe_list_items item
  where item.id = p_item_id;
  if not found then return; end if;

  perform 1 from public.cafe_lists list
  where list.id = target_list_id
  for update;
  if not found or not private.can_edit_cafe_list_as(target_list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  delete from public.cafe_list_items item
  where item.id = p_item_id and item.list_id = target_list_id;
  perform private.normalize_cafe_list_positions_v3(target_list_id);
  update public.cafe_lists set updated_at = now() where id = target_list_id;
end;
$$;

create or replace function public.remove_cafe_list_item_v2(p_item_id uuid)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.remove_cafe_list_item(p_item_id);
  return true;
end;
$$;

create or replace function public.move_cafe_list_item(
  p_item_id uuid,
  p_position integer
)
returns public.cafe_list_items
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target public.cafe_list_items;
  target_list_id uuid;
  desired_position integer;
  last_position integer;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select item.list_id into target_list_id
  from public.cafe_list_items item
  where item.id = p_item_id;
  if not found then
    raise exception 'cafe list item unavailable' using errcode = '42501';
  end if;

  perform 1 from public.cafe_lists list
  where list.id = target_list_id
  for update;
  if not found or not private.can_edit_cafe_list_as(target_list_id, actor) then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  perform private.normalize_cafe_list_positions_v3(target_list_id);
  select * into target
  from public.cafe_list_items item
  where item.id = p_item_id and item.list_id = target_list_id
  for update;
  if not found then
    raise exception 'cafe list item unavailable' using errcode = '42501';
  end if;

  select greatest(count(*) - 1, 0) into last_position
  from public.cafe_list_items item
  where item.list_id = target_list_id;
  desired_position := greatest(
    0,
    least(coalesce(p_position, target.position), last_position)
  );

  if desired_position < target.position then
    update public.cafe_list_items item
    set position = item.position + 1
    where item.list_id = target_list_id
      and item.id <> target.id
      and item.position >= desired_position
      and item.position < target.position;
  elsif desired_position > target.position then
    update public.cafe_list_items item
    set position = item.position - 1
    where item.list_id = target_list_id
      and item.id <> target.id
      and item.position > target.position
      and item.position <= desired_position;
  end if;

  update public.cafe_list_items item
  set position = desired_position
  where item.id = target.id
  returning * into target;
  update public.cafe_lists set updated_at = now() where id = target_list_id;

  if target.contributor_id is not null
     and private.blocked_between(actor, target.contributor_id) then
    target.contributor_id := null;
  end if;
  return target;
end;
$$;

revoke all on function public.remove_cafe_list_item(uuid)
  from public, anon, authenticated;
revoke all on function public.remove_cafe_list_item_v2(uuid)
  from public, anon, authenticated;
revoke all on function public.move_cafe_list_item(uuid,integer)
  from public, anon, authenticated;
grant execute on function public.remove_cafe_list_item_v2(uuid)
  to authenticated;

comment on function public.purge_expired_recipe_staging_v3(integer) is
  'Service-only bounded cleanup for unpublished recipe payloads after their 24-hour recovery window.';
comment on function public.purge_expired_collaboration_invites_v3(integer) is
  'Service-only bounded expiry for unaccepted cafe-list and shared MugShot invitations.';

commit;
