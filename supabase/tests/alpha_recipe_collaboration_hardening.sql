begin;

do $$
declare
  definition text;
  delete_rule "char";
begin
  select pg_get_constraintdef(constraint_record.oid)
  into definition
  from pg_constraint constraint_record
  join pg_class table_record on table_record.oid = constraint_record.conrelid
  join pg_namespace namespace on namespace.oid = table_record.relnamespace
  where namespace.nspname = 'private'
    and table_record.relname = 'visit_recipe_payload_staging'
    and constraint_record.conname = 'visit_recipe_payload_staging_user_id_fkey';

  if definition not ilike '%references auth.users(id) on delete cascade%'
     or definition not ilike '%not valid%' then
    raise exception 'recipe staging lost its forward-safe Auth lifecycle constraint';
  end if;

  select constraint_record.confdeltype into delete_rule
  from pg_constraint constraint_record
  join pg_class table_record on table_record.oid = constraint_record.conrelid
  join pg_namespace namespace on namespace.oid = table_record.relnamespace
  where namespace.nspname = 'public'
    and table_record.relname = 'cafe_list_members'
    and constraint_record.conname = 'cafe_list_members_invited_by_fkey';
  if delete_rule is distinct from 'n' then
    raise exception 'accepted cafe-list membership still cascades with inviter deletion';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'cafe_list_members'
      and column_name = 'expires_at'
  ) or not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name = 'shared_memory_members'
      and column_name = 'expires_at'
  ) then
    raise exception 'consent invitation expiry columns are missing';
  end if;

  if exists (
    select 1 from public.cafe_list_members
    where invitation_status = 'pending' and expires_at is null
  ) or exists (
    select 1 from public.shared_memory_members
    where status = 'pending' and expires_at is null
  ) then
    raise exception 'legacy pending consent invitations have no bounded expiry';
  end if;

  if exists (
    select 1 from information_schema.routine_privileges privilege
    where privilege.routine_schema = 'public'
      and privilege.routine_name in (
        'purge_expired_recipe_staging_v3',
        'purge_expired_collaboration_invites_v3'
      )
      and privilege.grantee in ('PUBLIC', 'anon', 'authenticated')
      and privilege.privilege_type = 'EXECUTE'
  ) then
    raise exception 'expiry cleanup is exposed to app roles';
  end if;

  if to_regclass('cron.job') is null
     or not exists (
       select 1
       from cron.job
       where jobname = 'mugshot-alpha-ephemera-v3'
         and schedule = '*/15 * * * *'
         and active
         and command ilike '%purge_expired_recipe_staging_v3(1000)%'
         and command ilike '%purge_expired_collaboration_invites_v3(1000)%'
     ) then
    raise exception 'alpha ephemera cleanup scheduler is missing or inactive';
  end if;

  if not has_function_privilege(
    'authenticated', 'public.remove_cafe_list_item_v2(uuid)', 'EXECUTE'
  ) or has_function_privilege(
    'authenticated', 'public.remove_cafe_list_item(uuid)', 'EXECUTE'
  ) then
    raise exception 'safe cafe-list removal RPC boundary is incomplete';
  end if;

  select pg_get_functiondef(
    'private.guard_visit_recipe_payload_stage_v3()'::regprocedure
  ) into definition;
  if definition not ilike '%active_stage_count >= 20%'
     or definition not ilike '%is_live_account_as%'
     or definition not ilike '%24 hours%' then
    raise exception 'recipe staging guard lost live-account, quota, or expiry controls';
  end if;

  select pg_get_functiondef(
    'private.enforce_shared_memory_participant_cap_v3()'::regprocedure
  ) into definition;
  if definition not ilike '%participant_count > 12%'
     or definition not ilike '%pending%accepted%' then
    raise exception 'shared MugShot aggregate participant cap is missing';
  end if;

  select pg_get_functiondef(
    'private.can_project_recipe_version_as(uuid,uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%can_view_user_as(identity.user_id, p_viewer)%' then
    raise exception 'recipe projection bypasses live-account or suspension enforcement';
  end if;

  select pg_get_functiondef(
    'public.list_shared_recipes()'::regprocedure
  ) into definition;
  if definition not ilike '%can_project_recipe_version_as%'
     or definition not ilike '%recipient_id =%auth.uid()%'
     or definition ilike '%privateNotes%' then
    raise exception 'legacy shared recipe inbox bypasses enforced recipe projection';
  end if;

  select pg_get_functiondef(
    'private.can_view_taste_passport_as(uuid,uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%can_view_user_as(p_owner, p_viewer)%' then
    raise exception 'Taste Passport projection bypasses account enforcement';
  end if;

  select pg_get_functiondef(
    'private.guard_recipe_visibility_expansion_v3()'::regprocedure
  ) into definition;
  if definition not ilike '%can_socially_mutate_as(owner_id)%'
     or definition not ilike '%alpha_audience_breadth_v3%'
     or definition not ilike '%expands_public_reuse%'
     or definition not ilike '%redistribution_allowed%' then
    raise exception 'recipe audience or public-reuse expansion is not enforcement-aware';
  end if;

  select pg_get_triggerdef(trigger_record.oid)
  into definition
  from pg_trigger trigger_record
  join pg_class table_record on table_record.oid = trigger_record.tgrelid
  join pg_namespace namespace on namespace.oid = table_record.relnamespace
  where namespace.nspname = 'public'
    and table_record.relname = 'recipe_versions'
    and trigger_record.tgname = 'guard_recipe_visibility_expansion_v3';
  if definition not ilike '%redistribution_allowed%'
     or definition not ilike '%source_kind%' then
    raise exception 'recipe sharing guard does not cover reuse-right mutations';
  end if;

  select pg_get_functiondef(
    'private.guard_recipe_source_reuse_v3()'::regprocedure
  ) into definition;
  if definition not ilike '%can_view_user_as(source_owner, target_owner)%'
     or definition not ilike '%can_socially_mutate_as(target_owner)%' then
    raise exception 'cross-owner recipe reuse bypasses enforcement';
  end if;

  select pg_get_functiondef(
    'private.guard_taste_passport_expansion_v3()'::regprocedure
  ) into definition;
  if definition not ilike '%can_socially_mutate_as(new.id)%'
     or definition not ilike '%alpha_audience_breadth_v3%' then
    raise exception 'Taste Passport expansion is not enforcement-aware';
  end if;

  select pg_get_functiondef(
    'private.guard_cafe_list_owner_transfer_v3()'::regprocedure
  ) into definition;
  if definition not ilike '%can_socially_mutate_as(new.owner_id)%'
     or definition not ilike '%new.owner_id is not null%' then
    raise exception 'cafe-list ownership can transfer to an unavailable account';
  end if;

  select pg_get_functiondef(
    'public.move_cafe_list_item(uuid,integer)'::regprocedure
  ) into definition;
  if definition not ilike '%for update%'
     or definition not ilike '%normalize_cafe_list_positions_v3%' then
    raise exception 'cafe-list move no longer serializes and normalizes ordering';
  end if;

  select pg_get_functiondef(
    'public.remove_cafe_list_item(uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%for update%'
     or definition not ilike '%normalize_cafe_list_positions_v3%' then
    raise exception 'cafe-list remove no longer serializes and normalizes ordering';
  end if;
end;
$$;

rollback;

select 'alpha_recipe_collaboration_hardening_passed' as result;
