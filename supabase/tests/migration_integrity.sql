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
    ('20260712214646')
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
end $$;

select 'migration_integrity_passed' as result;
