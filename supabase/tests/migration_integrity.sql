do $$
declare missing_versions text[];
begin
  select array_agg(required.version) into missing_versions
  from (values
    ('20260712163405'),
    ('20260712205140'),
    ('20260712205347'),
    ('20260712211408'),
    ('20260712214406'),
    ('20260712214646'),
    ('20260713035201'),
    ('20260713152500'),
    ('20260713191000')
  ) required(version)
  where not exists (
    select 1 from supabase_migrations.schema_migrations m where m.version=required.version
  );
  if missing_versions is not null then
    raise exception 'missing live migrations: %',missing_versions;
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

  if has_function_privilege('anon','public.resolve_cafe_summary(text,double precision,double precision,text)','EXECUTE')
     or not has_function_privilege('authenticated','public.resolve_cafe_summary(text,double precision,double precision,text)','EXECUTE') then
    raise exception 'canonical cafe resolver grants are incorrect';
  end if;
end $$;

select 'migration_integrity_passed' as result;
