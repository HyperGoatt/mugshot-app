begin;

do $$
begin
  if not has_table_privilege('anon', 'public.cafes', 'SELECT')
     or not has_table_privilege('authenticated', 'public.cafes', 'SELECT')
     or not has_table_privilege('authenticated', 'public.cafes', 'INSERT') then
    raise exception 'catalog read/insert grants are missing';
  end if;
  if has_table_privilege('anon', 'public.cafes', 'INSERT')
     or has_table_privilege('anon', 'public.cafes', 'UPDATE')
     or has_table_privilege('anon', 'public.cafes', 'DELETE')
     or has_table_privilege('anon', 'public.cafes', 'TRUNCATE')
     or has_table_privilege('authenticated', 'public.cafes', 'UPDATE')
     or has_table_privilege('authenticated', 'public.cafes', 'DELETE')
     or has_table_privilege('authenticated', 'public.cafes', 'TRUNCATE') then
    raise exception 'catalog clients have unexpected mutation grants';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.cafes'::regclass) then
    raise exception 'catalog row security is disabled';
  end if;
end;
$$;

set local role anon;
select id from public.cafes limit 1;
reset role;
set local role authenticated;
select id from public.cafes limit 1;
reset role;

rollback;
