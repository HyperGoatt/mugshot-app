do $$
begin
  if not exists (
    select 1 from pg_tables
    where schemaname = 'public'
      and tablename = 'user_capture_preferences'
      and rowsecurity
  ) then
    raise exception 'capture preferences table or RLS is missing';
  end if;

  if (
    select count(*) from pg_policies
    where schemaname = 'public'
      and tablename = 'user_capture_preferences'
      and roles = '{authenticated}'::name[]
      and coalesce(qual, with_check, '') ilike '%auth.uid%'
  ) <> 4 then
    raise exception 'capture preferences owner policies are incomplete';
  end if;

  if has_table_privilege('anon', 'public.user_capture_preferences', 'select')
    or has_table_privilege('anon', 'public.user_capture_preferences', 'insert')
    or has_table_privilege('anon', 'public.user_capture_preferences', 'update')
    or has_table_privilege('anon', 'public.user_capture_preferences', 'delete') then
    raise exception 'anon has capture preference privileges';
  end if;
end $$;

select 'activation_contract_passed' as result;
