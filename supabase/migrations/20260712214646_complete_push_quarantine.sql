-- Push delivery is outside this epic. Remove its legacy client surface while
-- retaining tables and trigger definitions for a future audited rebuild.
alter function public.send_push_notification_trigger() set search_path = '';
revoke all on function public.send_push_notification_trigger() from public, anon, authenticated;
revoke all on table public.user_devices from public, anon, authenticated;

do $$ declare p record; begin
  for p in select policyname from pg_policies
    where schemaname='public' and tablename='user_devices'
  loop
    execute format('drop policy if exists %I on public.user_devices',p.policyname);
  end loop;
end $$;
;
