\set ON_ERROR_STOP on

begin;

do $$
declare
  definition text;
  policy_expression text;
begin
  select pg_get_functiondef(
    'public.can_view_cafe_list(uuid,uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%is not distinct from%auth.uid()%'
     or definition not ilike '%private.can_view_cafe_list_as%'
     or definition not ilike '%security definer%'
     or definition not ilike '%set search_path to ''''%'
     or not has_function_privilege(
       'anon', 'public.can_view_cafe_list(uuid,uuid)', 'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated', 'public.can_view_cafe_list(uuid,uuid)', 'EXECUTE'
     ) then
    raise exception 'caller-bound public cafe-list wrapper is incomplete';
  end if;

  select pg_get_functiondef(
    'public.can_view_cafe_list_items(uuid,uuid)'::regprocedure
  ) into definition;
  if definition not ilike '%is not distinct from%auth.uid()%'
     or definition not ilike '%private.can_view_cafe_list_items_as%'
     or not has_function_privilege(
       'anon', 'public.can_view_cafe_list_items(uuid,uuid)', 'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated', 'public.can_view_cafe_list_items(uuid,uuid)', 'EXECUTE'
     ) then
    raise exception 'caller-bound public cafe-list-item wrapper is incomplete';
  end if;

  select concat_ws(' ', policy.qual, policy.with_check)
  into policy_expression
  from pg_policies policy
  where policy.schemaname = 'public'
    and policy.tablename = 'cafe_lists'
    and policy.policyname = 'Public cafe lists';
  if policy_expression not ilike '%can_view_cafe_list(%'
     or policy_expression ilike '%private.%' then
    raise exception 'public cafe-list RLS bypasses its caller-bound wrapper';
  end if;

  select concat_ws(' ', policy.qual, policy.with_check)
  into policy_expression
  from pg_policies policy
  where policy.schemaname = 'public'
    and policy.tablename = 'cafe_list_items'
    and policy.policyname = 'Public cafe list items';
  if policy_expression not ilike '%can_view_cafe_list_items(%'
     or policy_expression ilike '%private.%' then
    raise exception 'public cafe-list-item RLS bypasses its caller-bound wrapper';
  end if;

  if to_regprocedure('public.companion_suggestions(integer)') is not null
     or to_regprocedure('public.visit_tag_suggestions_v1(integer)') is null
     or has_function_privilege(
       'anon', 'public.visit_tag_suggestions_v1(integer)', 'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated', 'public.visit_tag_suggestions_v1(integer)', 'EXECUTE'
     ) then
    raise exception 'tag-only suggestion compatibility is incorrect';
  end if;
end;
$$;

rollback;

select 'alpha_qa_compatibility_security_passed' as result;
