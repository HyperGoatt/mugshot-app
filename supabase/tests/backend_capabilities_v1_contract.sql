begin;

do $$
declare
  payload jsonb;
  capability_name text;
  expected_capabilities constant text[] := array[
    'taste_passport',
    'taste_passport_audience',
    'independent_recipe_visibility',
    'visit_tags',
    'shared_mugshots',
    'public_mugshot_sharing',
    'activity_center',
    'notification_preferences',
    'push_registration',
    'social_safety',
    'moderation_transparency',
    'collaborative_cafe_lists',
    'account_deletion_v3'
  ];
  is_security_definer boolean;
  function_config text[];
begin
  payload := public.get_backend_capabilities_v1();

  if payload ->> 'contract_version' <> '1' then
    raise exception 'Unexpected backend capability contract version: %',
      payload ->> 'contract_version';
  end if;

  if payload ->> 'schema_release'
      <> '2026-07-23-post-publish-share-hub' then
    raise exception 'Unexpected backend schema release: %',
      payload ->> 'schema_release';
  end if;

  if jsonb_typeof(payload -> 'capabilities') <> 'object' then
    raise exception 'Backend capabilities must be a JSON object';
  end if;

  if (
    select count(*)
    from jsonb_object_keys(payload -> 'capabilities')
  ) <> cardinality(expected_capabilities) then
    raise exception 'Backend capability response has unexpected keys: %',
      payload -> 'capabilities';
  end if;

  foreach capability_name in array expected_capabilities loop
    if jsonb_typeof(payload -> 'capabilities' -> capability_name)
        <> 'boolean' then
      raise exception 'Capability % is missing or not boolean', capability_name;
    end if;

    if not (payload -> 'capabilities' ->> capability_name)::boolean then
      raise exception 'Capability % is not deploy-ready', capability_name;
    end if;
  end loop;

  if not has_function_privilege(
    'anon',
    'public.get_backend_capabilities_v1()',
    'EXECUTE'
  ) then
    raise exception 'Anonymous clients cannot read the backend contract';
  end if;

  if not has_function_privilege(
    'authenticated',
    'public.get_backend_capabilities_v1()',
    'EXECUTE'
  ) then
    raise exception 'Authenticated clients cannot read the backend contract';
  end if;

  select procedure.prosecdef, procedure.proconfig
  into is_security_definer, function_config
  from pg_proc as procedure
  where procedure.oid = 'public.get_backend_capabilities_v1()'::regprocedure;

  if is_security_definer then
    raise exception 'Backend capability contract must remain security invoker';
  end if;

  if function_config is null
     or not ('search_path=""' = any(function_config)) then
    raise exception 'Backend capability contract lost its empty search_path';
  end if;
end;
$$;

rollback;

select 'backend_capabilities_v1_contract_passed' as result;
