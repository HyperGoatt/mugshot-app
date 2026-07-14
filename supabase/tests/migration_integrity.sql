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
    ('separate_visit_private_notes', array['20260713152500','20260713205511']),
    ('add_visit_drink_analysis', array['20260713191000','20260713205518']),
    ('add_drink_analysis_retry_metadata_and_backfill', array['20260713231635']),
    ('harden_visit_photo_storage_contract', array['20260714013429','20260714013618']),
    ('optimize_visit_photo_storage_policies', array['20260714013809','20260714013836'])
  ) required(name, versions)
  where not exists (
    select 1
    from supabase_migrations.schema_migrations migration
    where migration.version = any(required.versions)
  );
  if missing_migrations is not null then
    raise exception 'missing live migrations: %', missing_migrations;
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

  if not exists (
    select 1 from pg_trigger
    where tgrelid='public.notifications'::regclass
      and tgname='on_notification_insert' and tgenabled='D'
  ) then raise exception 'legacy push trigger is not disabled'; end if;

  if has_function_privilege('anon','public.send_push_notification_trigger()','EXECUTE')
     or has_function_privilege('authenticated','public.send_push_notification_trigger()','EXECUTE') then
    raise exception 'legacy push function remains callable';
  end if;

  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='send_push_notification_trigger'
      and p.proconfig @> array['search_path=""']
  ) then raise exception 'legacy push function search path is not quarantined'; end if;

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

  if has_function_privilege('anon','public.resolve_cafe_summary(text,double precision,double precision,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.resolve_cafe_summary(text,double precision,double precision,text)','EXECUTE') then
    raise exception 'canonical cafe resolver grants are incorrect';
  end if;
end $$;

select 'migration_integrity_passed' as result;
