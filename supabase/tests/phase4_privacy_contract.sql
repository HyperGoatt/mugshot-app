begin;

do $$
declare leaked text;
begin
  select column_name into leaked
  from information_schema.columns
  where table_schema='public'
    and table_name in ('cafe_lists','cafe_list_members','cafe_list_items','trusted_recommendations','visit_reactions')
    and column_name in ('private_notes','private_note','caption','social_caption','photo_url')
  limit 1;
  if leaked is not null then
    raise exception 'phase 4 table contains private or parser-irrelevant field: %', leaked;
  end if;

  if exists(
    select 1 from information_schema.role_table_grants
    where grantee='authenticated'
      and table_schema='public'
      and table_name in ('cafe_lists','cafe_list_members','cafe_list_items','trusted_recommendations','visit_reactions')
      and privilege_type in ('INSERT','UPDATE','DELETE')
  ) then raise exception 'phase 4 direct mutation grant detected'; end if;

  if exists(
    select 1 from pg_class table_record
    join pg_namespace namespace on namespace.oid=table_record.relnamespace
    where namespace.nspname='public'
      and table_record.relname in ('cafe_lists','cafe_list_members','cafe_list_items','trusted_recommendations','visit_reactions')
      and not table_record.relrowsecurity
  ) then raise exception 'phase 4 table missing RLS'; end if;
end $$;

rollback;
select 'phase4_privacy_contract_passed' as result;
