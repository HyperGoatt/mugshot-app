begin;

do $$
declare
  definition text;
  policy_qual text;
begin
  select pg_get_functiondef(
    'private.is_public_visit_discoverable_v3(uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%visibility = ''everyone''%'
     or definition not ilike '%upload_state = ''complete''%'
     or definition not ilike '%is_live_account_as%'
     or definition not ilike '%account_suspended%'
     or definition not ilike '%content_hidden%' then
    raise exception 'anon-safe public visit eligibility is incomplete';
  end if;

  select pg_get_functiondef(
    'public.discover_public_cafes(text,double precision,double precision,double precision,integer,double precision,uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%is_public_visit_discoverable_v3(visit.id)%'
     or definition ilike '%visit.visibility = ''everyone''%visit.upload_state = ''complete''%' then
    raise exception 'Map discovery bypasses the enforced public visit boundary';
  end if;

  select pg_get_functiondef(
    'public.visit_tag_suggestions_v1(integer)'::regprocedure
  ) into definition;
  if definition not ilike '%can_view_user_as(profile.id, input.actor)%' then
    raise exception 'visit tag suggestions expose unavailable accounts';
  end if;

  select pg_get_functiondef(
    'public.friend_compatibility(uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%can_view_taste_passport_as(p_friend_id, actor)%'
     or definition not ilike '%taste compatibility unavailable%' then
    raise exception 'friend compatibility bypasses Taste Passport visibility';
  end if;

  select pg_get_functiondef(
    'public.list_visible_visit_tags_v1(uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%can_view_user_as(profile.id, input.actor)%' then
    raise exception 'visible visit tags expose unavailable accounts';
  end if;

  select pg_get_functiondef(
    'public.get_recipe_identity_for_visit_v1(uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%can_view_visit_as(p_visit_id, input.actor)%'
     or definition not ilike '%can_view_user_as(owner.id, input.actor)%'
     or definition ilike '%brew_details%'
     or definition ilike '%brew_method%'
     or definition ilike '%equipment%'
     or definition ilike '%source_recipe_version_id%' then
    raise exception 'locked recipe identity projection exposes protected blueprint data';
  end if;

  select pg_get_functiondef(
    'private.can_view_cafe_list_as(uuid,uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%can_view_user_as(list.owner_id, p_viewer)%' then
    raise exception 'friend-visible cafe lists bypass owner enforcement';
  end if;

  select pg_get_functiondef(
    'private.cafe_list_summary_json_v2(uuid,uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%Unavailable cafe list invitation%'
     or definition not ilike '%invitation_status = ''pending''%'
     or definition not ilike '%can_view_user_as(list.owner_id, p_viewer)%' then
    raise exception 'unavailable cafe-list invitations expose owner metadata';
  end if;

  select pg_get_functiondef(
    'public.cancel_cafe_list_invitation_v2(uuid,uuid)'::regprocedure
  ) into definition;
  if definition ilike '%can_manage_cafe_list_as%'
     or definition not ilike '%list_owner is distinct from actor%'
     or definition not ilike '%invitation_status = ''cancelled''%' then
    raise exception 'cafe-list cancellation is not an independent safety exit';
  end if;

  select policy.qual into policy_qual
  from pg_policies policy
  where policy.schemaname = 'public'
    and policy.tablename = 'trusted_recommendations'
    and policy.policyname = 'Recommendation participants read';
  if policy_qual not ilike '%can_view_user(%'
     or policy_qual not ilike '%can_view_visit(%'
     or policy_qual not ilike '%can_project_recipe_version(%'
     or policy_qual ilike '%private.%' then
    raise exception 'recommendation notes bypass target or sender enforcement';
  end if;

  if has_function_privilege(
       'anon',
       'public.can_project_recipe_version(uuid,uuid)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.can_project_recipe_version(uuid,uuid)',
       'EXECUTE'
     ) then
    raise exception 'recipe projection RLS wrapper grants are incorrect';
  end if;
end;
$$;

rollback;

select 'alpha_projection_and_safety_hardening_passed' as result;
