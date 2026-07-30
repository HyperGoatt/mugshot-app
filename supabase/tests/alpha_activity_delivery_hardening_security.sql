\set ON_ERROR_STOP on

begin;

do $$
begin
  if not exists (
    select 1
    from information_schema.parameters parameter
    where parameter.specific_schema = 'public'
      and parameter.specific_name like 'claim_activity_push_batch_v2_%'
      and parameter.parameter_mode = 'OUT'
      and parameter.parameter_name = 'recipient_id'
      and parameter.data_type = 'uuid'
  ) then
    raise exception 'push claims are not bound to their recipient account';
  end if;
end;
$$;

do $$
declare
  registration_body text := pg_get_functiondef(
    'public.register_user_device_v2(uuid,text,text)'::regprocedure
  );
  installation_claim_body text := pg_get_functiondef(
    'public.claim_user_device_installation_v2(uuid,text,text)'::regprocedure
  );
  completion_body text := pg_get_functiondef(
    'public.complete_activity_push_delivery_v2(uuid,uuid,bigint,text,text,integer)'::regprocedure
  );
  revalidation_body text := pg_get_functiondef(
    'public.revalidate_activity_push_delivery_v2(uuid,uuid,bigint)'::regprocedure
  );
begin
  if to_regprocedure('private.activity_recipient_is_eligible_v2(uuid)') is null
     or to_regprocedure(
       'public.claim_user_device_installation_v2(uuid,text,text)'
     ) is null
     or to_regprocedure('public.claim_activity_push_batch_v2(integer)') is null
     or to_regprocedure(
       'public.revalidate_activity_push_delivery_v2(uuid,uuid,bigint)'
     ) is null
     or to_regprocedure(
       'public.complete_activity_push_delivery_v2(uuid,uuid,bigint,text,text,integer)'
     ) is null then
    raise exception 'activity delivery hardening functions are incomplete';
  end if;

  if not exists (
    select 1
    from pg_indexes index_definition
    where index_definition.schemaname = 'public'
      and index_definition.indexname = 'user_devices_apns_token_namespace_idx'
      and index_definition.indexdef ilike '%unique%'
      and index_definition.indexdef ilike '%environment%push_token%'
  ) then
    raise exception 'normalized APNs namespace is not unique';
  end if;

  if registration_body not ilike '%lower(btrim%'
     or registration_body not ilike '%pg_advisory_xact_lock%'
     or registration_body not ilike '%hashtextextended%apns-token%'
     or registration_body not ilike '%mugshot-device-installation%'
     or registration_body not ilike '%device.device_id = p_device_id%'
     or registration_body not ilike '%offset 5%'
     or registration_body not ilike '%user_device_registration_windows%'
     or registration_body not ilike '%material_change_count >= 20%' then
    raise exception 'device registration lacks normalization, token lock, cap, or churn bound';
  end if;

  if installation_claim_body not ilike '%device.user_id <> actor%'
     or installation_claim_body not ilike '%device.device_id = p_device_id%'
     or installation_claim_body not ilike '%device.push_token = normalized_token%'
     or has_function_privilege(
       'anon',
       'public.claim_user_device_installation_v2(uuid,text,text)',
       'EXECUTE'
     ) then
    raise exception 'device installation ownership claim is incomplete or exposed';
  end if;

  if to_regclass('private.user_device_registration_windows') is null
     or has_table_privilege(
       'authenticated', 'private.user_device_registration_windows', 'SELECT'
     )
     or has_table_privilege(
       'authenticated', 'private.user_device_registration_windows', 'INSERT'
     ) then
    raise exception 'device-registration throttle state is exposed to clients';
  end if;

  if completion_body not ilike '%claim_token = p_claim_token%'
     or completion_body not ilike '%lease_version = p_lease_version%'
     or completion_body not ilike '%attempt_count >= 12%'
     or completion_body not ilike '%p_outcome = ''unregistered''%'
     or completion_body not ilike '%power(2::numeric%'
     or completion_body not ilike '%hashtextextended%lease_version%' then
    raise exception 'completion fencing or durable retry policy is incomplete';
  end if;

  if revalidation_body not ilike '%claim_token = p_claim_token%'
     or revalidation_body not ilike '%lease_version = p_lease_version%'
     or revalidation_body not ilike '%activity_recipient_is_eligible_v2%'
     or revalidation_body not ilike '%activity_event_is_visible%'
     or revalidation_body not ilike '%interval ''30 seconds''%'
     or revalidation_body not ilike '%recipient_suspension_imminent%'
     or revalidation_body not ilike '%recipient_became_ineligible%'
     or revalidation_body not ilike '%status = ''cancelled''%' then
    raise exception 'the final pre-APNs eligibility fence is incomplete';
  end if;

  if has_function_privilege(
       'service_role', 'public.claim_activity_push_batch_v1(integer)', 'EXECUTE'
     )
     or has_function_privilege(
       'service_role',
       'public.complete_activity_push_delivery_v1(uuid,boolean,text,boolean)',
       'EXECUTE'
     ) then
    raise exception 'unfenced delivery protocol remains executable';
  end if;

  if has_function_privilege(
       'authenticated', 'public.claim_activity_push_batch_v2(integer)', 'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.revalidate_activity_push_delivery_v2(uuid,uuid,bigint)',
       'EXECUTE'
     )
     or has_function_privilege(
       'authenticated',
       'public.complete_activity_push_delivery_v2(uuid,uuid,bigint,text,text,integer)',
       'EXECUTE'
     ) then
    raise exception 'client role can execute the push worker protocol';
  end if;

  if not exists (
    select 1 from pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.activity_events'::regclass
      and trigger_row.tgname = 'guard_suspended_activity_recipient'
      and not trigger_row.tgisinternal
  ) or not exists (
    select 1 from pg_trigger trigger_row
    where trigger_row.tgrelid = 'private.moderation_actions'::regclass
      and trigger_row.tgname = 'suppress_suspended_recipient_activity'
      and not trigger_row.tgisinternal
  ) then
    raise exception 'suspended-recipient activity guards are incomplete';
  end if;

  if (
    select pg_get_triggerdef(trigger_row.oid)
    from pg_trigger trigger_row
    where trigger_row.tgrelid = 'public.visit_reactions'::regclass
      and trigger_row.tgname = 'activity_from_reaction'
      and not trigger_row.tgisinternal
  ) not ilike '%INSERT OR UPDATE OF reaction%' then
    raise exception 'reaction changes do not maintain current activity';
  end if;
end;
$$;

rollback;

select 'alpha_activity_delivery_hardening_security_passed' as result;
