do $$
declare missing_migrations text[];
begin
  select array_agg(required.name) into missing_migrations
  from (values
    ('secure_social_foundation', array['20260712163405']),
    ('harden_legacy_views', array['20260712205140']),
    ('quarantine_legacy_definers', array['20260712205347']),
    ('optimize_social_pagination', array['20260712211408']),
    ('discovery_social_expansion', array['20260712214406']),
    ('complete_push_quarantine', array['20260712214646']),
    ('phase_two_journal_data', array['20260713035201']),
    ('separate_visit_private_notes', array['20260713205511']),
    ('add_visit_drink_analysis', array['20260713205518']),
    ('add_drink_analysis_retry_metadata_and_backfill', array['20260713231635']),
    ('harden_visit_photo_storage_contract', array['20260714013618']),
    ('optimize_visit_photo_storage_policies', array['20260714013836']),
    ('phase_2_canonical_journal', array['20260714042024']),
    ('harden_phase_2_journal_contracts', array['20260714043328']),
    ('phase_3_explainable_taste_graph', array['20260714044901']),
    ('refine_taste_graph_recommendation_reasons', array['20260714045207']),
    ('phase_4_lightweight_friends', array['20260714050516']),
    ('refine_cafe_list_invitation_visibility', array['20260714051041']),
    ('expose_caller_bound_phase_4_policies', array['20260714051404']),
    ('close_phase_4_direct_mutations', array['20260714051432']),
    ('sanitize_shared_recipe_payloads', array['20260714051603']),
    ('add_cafe_list_reordering', array['20260714052754']),
    ('phase_5_reflection_preferences', array['20260714053353']),
    ('phase_6_owner_data_export', array['20260714055538']),
    ('harden_owner_data_export_invoker', array['20260714061539']),
    ('followup_discovery_feed_companions', array['20260714151316']),
    ('fix_visit_companion_visibility_policy', array['20260714185446']),
    ('tasting_lens_2_core', array['20260717114908']),
    ('tasting_lens_2_security', array['20260717114953']),
    ('tasting_lens_2_export', array['20260717115015']),
    ('tasting_lens_2_indexes', array['20260717115054']),
    ('cafe_sessions_and_pulse', array['20260717142724']),
    ('private_visit_photo_storage', array['20260717150000']),
    ('session_balanced_map_pin_scores', array['20260717185855']),
    ('post_publish_share_hub', array['20260723154204'])
  ) required(name, versions)
  where not exists (
    select 1
    from supabase_migrations.schema_migrations migration
    where migration.version = any(required.versions)
  );
  if missing_migrations is not null then
    raise exception 'missing live migrations: %', missing_migrations;
  end if;

  if exists (
    select 1
    from pg_policies policy
    where concat_ws(' ', policy.qual, policy.with_check) ilike '%private.%'
  ) then
    raise exception 'an RLS policy calls a sealed private helper directly';
  end if;

  if has_function_privilege(
       'anon',
       'public.can_write_account_storage(uuid)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.can_write_account_storage(uuid)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'anon',
       'public.is_live_account(uuid)',
       'EXECUTE'
     ) then
    raise exception 'caller-bound Storage wrapper grants are incorrect';
  end if;

  if to_regclass('public.comment_mentions') is null then
    raise exception 'comment_mentions table is missing';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.comment_mentions'::regclass) then
    raise exception 'comment_mentions RLS is disabled';
  end if;
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='comment_mentions') then
    raise exception 'comment_mentions policy is missing';
  end if;

  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name='user_devices'
      and grantee in ('anon','authenticated')
  ) then raise exception 'legacy device table remains client accessible'; end if;

  if exists (
    select 1 from pg_trigger
    where tgrelid='public.notifications'::regclass
      and tgname='on_notification_insert'
      and not tgisinternal
  ) then raise exception 'legacy push trigger remains installed'; end if;

  if to_regprocedure('public.send_push_notification_trigger()') is not null then
    raise exception 'legacy push function remains installed';
  end if;

  if exists (
    select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relname in (
      'notifications_with_actor','feedback_posts_with_counts','feedback_comments_with_author'
    ) and not coalesce(c.reloptions @> array['security_invoker=true'],false)
  ) then raise exception 'legacy view is not security invoker'; end if;

  if not exists (
    select 1 from pg_indexes where schemaname='public' and indexname='visits_complete_created_id_idx'
  ) then raise exception 'social pagination index is missing'; end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='public' and table_name='visits' and column_name='brew_details'
      and data_type='jsonb'
  ) then raise exception 'structured brew_details column is missing'; end if;

  if to_regclass('public.visit_private_notes') is null then
    raise exception 'visit_private_notes table is missing';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.visit_private_notes'::regclass) then
    raise exception 'visit_private_notes RLS is disabled';
  end if;
  if (select count(*) from pg_policies
      where schemaname='public' and tablename='visit_private_notes') <> 4 then
    raise exception 'visit_private_notes owner policies are incomplete';
  end if;
  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name='visit_private_notes' and grantee='anon'
  ) then raise exception 'anonymous role can access private sip notes'; end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.visits'::regclass
      and conname='visits_legacy_notes_must_be_null'
  ) then raise exception 'legacy social notes column can be repopulated'; end if;
  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.visits'::regclass
      and tgname='route_legacy_visit_private_note' and tgenabled='O'
  ) then raise exception 'legacy private-note compatibility route is missing'; end if;
  if has_function_privilege('anon','public.route_legacy_visit_private_note()','EXECUTE')
     or has_function_privilege('authenticated','public.route_legacy_visit_private_note()','EXECUTE') then
    raise exception 'legacy private-note router is directly callable';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conrelid='public.visit_private_notes'::regclass
      and conname='visit_private_notes_visit_owner_fk'
      and condeferrable and condeferred
  ) then raise exception 'private-note owner constraint cannot route legacy inserts safely'; end if;

  if to_regclass('public.visit_drink_analyses') is null then
    raise exception 'visit_drink_analyses table is missing';
  end if;

  if to_regclass('public.taste_signals') is null then
    raise exception 'taste_signals table is missing';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.taste_signals'::regclass) then
    raise exception 'taste_signals RLS is disabled';
  end if;
  if has_table_privilege('anon','public.taste_signals','SELECT')
     or not has_table_privilege('authenticated','public.taste_signals','SELECT') then
    raise exception 'taste signal grants are incorrect';
  end if;
  if has_function_privilege('authenticated','public.refresh_taste_signals(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.set_taste_signal_owner_state(uuid,text,text)','EXECUTE') then
    raise exception 'taste graph function grants are incorrect';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.visit_drink_analyses'::regclass) then
    raise exception 'visit_drink_analyses RLS is disabled';
  end if;
  if (select count(*) from pg_policies
      where schemaname='public' and tablename='visit_drink_analyses') <> 1 then
    raise exception 'drink-analysis visibility policy is incorrect';
  end if;
  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name='visit_drink_analyses'
      and grantee='authenticated' and privilege_type <> 'SELECT'
  ) then raise exception 'authenticated clients can write parser output directly'; end if;
  if exists (
    select 1 from information_schema.role_table_grants
    where table_schema='public' and table_name='visit_drink_analyses' and grantee='anon'
  ) then raise exception 'anonymous role can access drink analyses'; end if;
  if has_function_privilege('anon','public.request_visit_drink_analysis_correction(uuid,jsonb)','EXECUTE')
     or not has_function_privilege('authenticated','public.request_visit_drink_analysis_correction(uuid,jsonb)','EXECUTE') then
    raise exception 'drink-analysis correction grants are incorrect';
  end if;
  if has_function_privilege('anon','public.seed_visit_drink_analysis()','EXECUTE')
     or has_function_privilege('authenticated','public.seed_visit_drink_analysis()','EXECUTE') then
    raise exception 'drink-analysis seed trigger is directly callable';
  end if;
  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.visits'::regclass
      and tgname='seed_visit_drink_analysis' and tgenabled='O'
  ) then raise exception 'drink-analysis seed trigger is missing'; end if;

  if not exists (
    select 1
    from storage.buckets
    where id='visit-photos'
      and public
      and file_size_limit=10485760
      and allowed_mime_types @> array['image/jpeg','image/png','image/gif','image/webp','image/heic']
  ) then raise exception 'visit-photo bucket contract is incomplete'; end if;
  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='Authenticated users can upload visit photos'
      and cmd='INSERT' and roles='{authenticated}'::name[]
      and with_check ilike '%auth.uid%'
      and with_check ilike '%storage.foldername%'
  ) then raise exception 'visit-photo insert policy is incomplete'; end if;
  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='Users can update their own visit photos'
      and cmd='UPDATE' and roles='{authenticated}'::name[]
      and qual ilike '%auth.uid%'
      and with_check ilike '%storage.extension%'
  ) then raise exception 'visit-photo update policy is incomplete'; end if;
  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='Users can delete their own visit photos'
      and cmd='DELETE' and roles='{authenticated}'::name[]
      and qual ilike '%auth.uid%'
  ) then raise exception 'visit-photo delete policy is incomplete'; end if;
  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='View photos based on completed visit visibility'
      and cmd='SELECT'
  ) then raise exception 'visit-photo visibility policy is missing'; end if;
  if not exists (
    select 1
    from storage.buckets
    where id='visit-photos-private'
      and not public
      and file_size_limit=10485760
      and allowed_mime_types @> array['image/jpeg','image/png','image/gif','image/webp','image/heic']
  ) then raise exception 'private visit-photo bucket contract is incomplete'; end if;
  if (
    select count(*)
    from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname in (
        'Owners upload private visit photos',
        'Owners update private visit photos',
        'Owners delete private visit photos',
        'Visit audiences read private visit photos',
        'Anonymous viewers read Everyone private visit photos'
      )
  ) <> 5 then raise exception 'private visit-photo policies are incomplete'; end if;
  if not exists (
    select 1 from pg_policies
    where schemaname='storage' and tablename='objects'
      and policyname='Visit audiences read private visit photos'
      and cmd='SELECT'
      and qual ilike '%can_view_visit_photo_object%'
  ) then raise exception 'private visit-photo audience policy is incomplete'; end if;
  if not has_function_privilege(
       'anon',
       'public.can_view_visit_photo_object(text)',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.can_view_visit_photo_object(text)',
       'EXECUTE'
     ) then raise exception 'visit-photo audience helper grants are incomplete'; end if;

  if has_function_privilege('anon','public.resolve_cafe_summary(text,double precision,double precision,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.resolve_cafe_summary(text,double precision,double precision,text)','EXECUTE') then
    raise exception 'canonical cafe resolver grants are incorrect';
  end if;

  if to_regclass('public.user_reflection_preferences') is null then
    raise exception 'reflection preferences table is missing';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.user_reflection_preferences'::regclass) then
    raise exception 'reflection preferences RLS is disabled';
  end if;
  if has_table_privilege('anon','public.user_reflection_preferences','SELECT')
     or has_table_privilege('authenticated','public.user_reflection_preferences','INSERT')
     or has_table_privilege('authenticated','public.user_reflection_preferences','UPDATE') then
    raise exception 'reflection preference grants are incorrect';
  end if;
  if has_function_privilege('anon','public.get_reflection_preferences()','EXECUTE')
     or not has_function_privilege('authenticated','public.get_reflection_preferences()','EXECUTE')
     or not has_function_privilege('authenticated','public.set_reflection_preferences(boolean,boolean,boolean,boolean)','EXECUTE') then
    raise exception 'reflection preference RPC grants are incorrect';
  end if;
  if has_function_privilege('anon','public.build_owner_data_export()','EXECUTE')
     or not has_function_privilege('authenticated','public.build_owner_data_export()','EXECUTE') then
    raise exception 'owner data export RPC grants are incorrect';
  end if;
  if exists (
    select 1 from pg_proc procedure
    join pg_namespace namespace on namespace.oid = procedure.pronamespace
    where namespace.nspname = 'public' and procedure.proname = 'build_owner_data_export'
      and procedure.prosecdef
  ) then raise exception 'owner data export bypasses caller RLS'; end if;

  if to_regclass('public.visit_sensory_snapshots') is null
     or to_regclass('public.visit_sensory_public_projections') is null
     or to_regclass('public.tasting_lens_preferences') is null
     or to_regclass('public.tasting_lens_corrections') is null then
    raise exception 'Tasting Lens storage contract is incomplete';
  end if;
  if not (select relrowsecurity and relforcerowsecurity
          from pg_class where oid='public.visit_sensory_snapshots'::regclass)
     or not (select relrowsecurity and relforcerowsecurity
             from pg_class where oid='public.visit_sensory_public_projections'::regclass)
     or not (select relrowsecurity and relforcerowsecurity
             from pg_class where oid='public.tasting_lens_preferences'::regclass)
     or not (select relrowsecurity and relforcerowsecurity
             from pg_class where oid='public.tasting_lens_corrections'::regclass) then
    raise exception 'Tasting Lens RLS is not enabled and forced';
  end if;
  if has_table_privilege('anon','public.visit_sensory_snapshots','SELECT')
     or has_table_privilege('authenticated','public.visit_sensory_snapshots','UPDATE')
     or has_table_privilege('authenticated','public.visit_sensory_snapshots','DELETE')
     or not has_table_privilege('authenticated','public.visit_sensory_snapshots','SELECT')
     or not has_table_privilege('authenticated','public.visit_sensory_snapshots','INSERT') then
    raise exception 'immutable sensory snapshot grants are incorrect';
  end if;
  if has_table_privilege('anon','public.tasting_lens_corrections','SELECT')
     or has_table_privilege('authenticated','public.tasting_lens_corrections','UPDATE')
     or has_table_privilege('authenticated','public.tasting_lens_corrections','DELETE')
     or not has_table_privilege('authenticated','public.tasting_lens_corrections','SELECT')
     or not has_table_privilege('authenticated','public.tasting_lens_corrections','INSERT') then
    raise exception 'append-only sensory correction grants are incorrect';
  end if;
  if (select count(*) from pg_policies
      where schemaname='public' and tablename='visit_sensory_snapshots') <> 2
     or (select count(*) from pg_policies
         where schemaname='public' and tablename='visit_sensory_public_projections') <> 4
     or (select count(*) from pg_policies
         where schemaname='public' and tablename='tasting_lens_preferences') <> 4
     or (select count(*) from pg_policies
         where schemaname='public' and tablename='tasting_lens_corrections') <> 2 then
    raise exception 'Tasting Lens policy set is incomplete';
  end if;

  if to_regclass('public.visit_tags') is null then
    raise exception 'visit_tags table is missing';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.visit_tags'::regclass) then
    raise exception 'visit_tags RLS is disabled';
  end if;
  if has_table_privilege('anon','public.visit_tags','SELECT')
     or has_table_privilege('authenticated','public.visit_tags','SELECT')
     or has_table_privilege('authenticated','public.visit_tags','INSERT')
     or has_table_privilege('authenticated','public.visit_tags','UPDATE')
     or has_table_privilege('authenticated','public.visit_tags','DELETE') then
    raise exception 'visit tag table grants are incorrect';
  end if;
  if not exists (
    select 1 from pg_policies
    where schemaname='public' and tablename='visit_tags'
      and policyname='Visible visit tags'
      and qual ilike '%can_view_visit%'
      and qual ilike '%can_view_user%'
      and qual not ilike '%private.%'
  ) then raise exception 'visit tag policy bypasses caller-bound visibility wrappers'; end if;
  if has_function_privilege('anon','public.set_visit_tags_v1(uuid,uuid[])','EXECUTE')
     or not has_function_privilege('authenticated','public.set_visit_tags_v1(uuid,uuid[])','EXECUTE')
     or has_function_privilege('anon','public.companion_suggestions(integer)','EXECUTE')
     or not has_function_privilege('authenticated','public.companion_suggestions(integer)','EXECUTE') then
    raise exception 'tag RPC grants are incorrect';
  end if;
  if not has_function_privilege(
       'anon',
       'public.discover_public_cafes(text,double precision,double precision,double precision,integer,double precision,uuid)',
       'EXECUTE'
     ) then
    raise exception 'signed-out discovery is unavailable to anon';
  end if;
  if has_function_privilege('anon','public.get_public_profile(uuid)','EXECUTE')
     or not has_function_privilege('authenticated','public.get_public_profile(uuid)','EXECUTE') then
    raise exception 'public profile RPC grants are incorrect';
  end if;
  if has_function_privilege(
       'anon',
       'public.get_friend_map_sip_summaries_v1(uuid[])',
       'EXECUTE'
     )
     or not has_function_privilege(
       'authenticated',
       'public.get_friend_map_sip_summaries_v1(uuid[])',
       'EXECUTE'
     ) then
    raise exception 'friend map Sip summary RPC grants are incorrect';
  end if;
end $$;

select 'migration_integrity_passed' as result;
