-- A single, anonymous-safe contract prevents the iOS client from inferring
-- backend readiness from a collection of 404 responses. Every capability is
-- derived from the deployed schema so a partial migration cannot advertise a
-- feature whose required objects are missing.

create or replace function public.get_backend_capabilities_v1()
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select jsonb_build_object(
    'contract_version', 1,
    'schema_release', '2026-07-22-alpha-social-foundations',
    'capabilities', jsonb_build_object(
      'taste_passport',
        to_regprocedure('public.get_taste_passport_v1(uuid)') is not null,
      'taste_passport_audience',
        to_regprocedure('public.get_taste_passport_visibility_v1()') is not null
        and to_regprocedure('public.set_taste_passport_visibility_v1(text,uuid)') is not null,
      'independent_recipe_visibility',
        to_regprocedure('public.get_recipe_projection_for_visit_v1(uuid)') is not null
        and to_regprocedure('public.get_recipe_identity_for_visit_v1(uuid)') is not null,
      'visit_tags',
        to_regprocedure('public.list_visible_visit_tags_v1(uuid)') is not null,
      'shared_mugshots',
        to_regprocedure('public.get_shared_memory_projection_v1(uuid)') is not null,
      'activity_center',
        to_regprocedure(
          'public.list_activity_events_v1(integer,timestamp with time zone,uuid)'
        ) is not null
        and to_regprocedure('public.activity_unread_count_v1()') is not null
        and to_regprocedure('public.mark_activity_read_v1(uuid)') is not null,
      'notification_preferences',
        to_regprocedure('public.get_notification_preferences_v1()') is not null
        and to_regprocedure(
          'public.set_notification_preferences_v1(boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean,boolean)'
        ) is not null,
      'push_registration',
        to_regprocedure('public.register_user_device_v2(uuid,text,text)') is not null
        and to_regprocedure(
          'public.claim_user_device_installation_v2(uuid,text,text)'
        ) is not null,
      'social_safety',
        to_regprocedure(
          'public.submit_report_v2(uuid,public.report_reason,text,uuid,text)'
        ) is not null
        and to_regprocedure('public.block_user_v2(uuid,boolean)') is not null,
      'moderation_transparency',
        to_regprocedure('public.get_my_enforcement_state_v1()') is not null
        and to_regprocedure('public.get_report_receipt_v1(uuid)') is not null,
      'collaborative_cafe_lists',
        to_regprocedure('public.list_cafe_lists_v2()') is not null
        and to_regprocedure('public.get_cafe_list_v2(uuid)') is not null
        and to_regprocedure('public.respond_cafe_list_invitation_v2(uuid,text)') is not null,
      'account_deletion_v3',
        to_regprocedure(
          'public.begin_account_deletion_step_up_v3(uuid,uuid,uuid,text,text)'
        ) is not null
        and to_regprocedure(
          'public.prepare_account_deletion_v3(uuid,uuid,uuid,text,text,uuid,text)'
        ) is not null
        and to_regprocedure(
          'public.acknowledge_account_deletion_completion_v3(uuid,text,text)'
        ) is not null
    )
  );
$$;

revoke all on function public.get_backend_capabilities_v1() from public;
grant execute on function public.get_backend_capabilities_v1() to anon, authenticated;

comment on function public.get_backend_capabilities_v1() is
  'Anonymous-safe Mugshot backend contract. Clients must gate optional features from this response instead of treating missing RPC errors as readiness.';
