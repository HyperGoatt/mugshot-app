do $$
declare candidate_table text; function_name text;
begin
  foreach candidate_table in array array[
    'discovery_preferences','discovery_identifiers','discovery_keys','discovery_capabilities',
    'discovery_suppressions','friend_invites','friend_discovery_state',
    'friend_request_attributions','contact_match_budgets','discovery_action_budgets'
  ] loop
    if to_regclass('private.' || candidate_table) is null then
      raise exception 'missing private People discovery table: %', candidate_table;
    end if;
    if exists (
      select 1 from information_schema.role_table_grants
      where table_schema = 'private'
        and information_schema.role_table_grants.table_name = candidate_table
        and grantee in ('anon','authenticated')
    ) then
      raise exception 'People discovery private table is client accessible: %', candidate_table;
    end if;
  end loop;

  foreach function_name in array array[
    'get_discovery_preferences_v1()','set_discovery_preferences_v1(boolean,boolean,boolean,integer,bigint)',
    'get_people_discovery_capabilities_v1()',
    'search_people_v2(text,integer,integer,real,text,uuid)','get_people_suggestions_v1(integer)',
    'get_people_hub_v1(integer)',
    'dismiss_people_suggestion_v1(uuid,boolean)','create_friend_invite_v1(uuid)',
    'revoke_friend_invite_v1(uuid)','resolve_friend_invite_v1(text)',
    'send_friend_request_v2(uuid,text,uuid,uuid)','respond_friend_request_v2(uuid,boolean)',
    'people_prompt_eligibility_v1()',
    'consume_people_prompt_v1(text)'
  ] loop
    if to_regprocedure('public.' || function_name) is null then
      raise exception 'missing People discovery client contract: %', function_name;
    end if;
    if has_function_privilege('anon','public.' || function_name,'EXECUTE')
       or not has_function_privilege('authenticated','public.' || function_name,'EXECUTE') then
      raise exception 'incorrect client contract grants: %', function_name;
    end if;
  end loop;

  if has_function_privilege(
       'authenticated','public.service_match_discovery_digests_v1(uuid,text[],integer)','EXECUTE'
     ) or not has_function_privilege(
       'service_role','public.service_match_discovery_digests_v1(uuid,text[],integer)','EXECUTE'
     ) then
    raise exception 'contact matching digest lookup grants are unsafe';
  end if;
  if has_function_privilege(
       'authenticated','public.service_set_discovery_email_v1(uuid,text,integer,timestamptz)','EXECUTE'
     ) then
    raise exception 'discovery email enrollment is client callable';
  end if;
  if not has_function_privilege('anon','public.get_friend_invite_landing_v1(text)','EXECUTE') then
    raise exception 'minimal public invite landing resolver is unavailable';
  end if;

  if pg_get_functiondef('public.service_match_discovery_digests_v1(uuid,text[],integer)'::regprocedure)
       ilike '%email%address%'
     or pg_get_functiondef('public.get_friend_invite_landing_v1(text)'::regprocedure)
       ilike '%friendship%' then
    raise exception 'People discovery projection exposes forbidden private detail';
  end if;
end;
$$;

select 'people_discovery_v1_contract_passed' as result;
