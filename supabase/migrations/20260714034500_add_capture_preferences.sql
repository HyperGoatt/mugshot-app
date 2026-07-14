begin;

create table if not exists public.user_capture_preferences (
  user_id uuid primary key references public.users(id) on delete cascade,
  usual_drink_families text[] not null default '{}'::text[],
  cafe_home_habit text check (cafe_home_habit is null or cafe_home_habit in ('cafe', 'home', 'both')),
  discovery_intents text[] not null default '{}'::text[],
  setup_completed_at timestamptz,
  updated_at timestamptz not null default now()
);

alter table public.user_capture_preferences enable row level security;

drop policy if exists "Owners read capture preferences" on public.user_capture_preferences;
create policy "Owners read capture preferences"
  on public.user_capture_preferences for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Owners insert capture preferences" on public.user_capture_preferences;
create policy "Owners insert capture preferences"
  on public.user_capture_preferences for insert to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Owners update capture preferences" on public.user_capture_preferences;
create policy "Owners update capture preferences"
  on public.user_capture_preferences for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

drop policy if exists "Owners delete capture preferences" on public.user_capture_preferences;
create policy "Owners delete capture preferences"
  on public.user_capture_preferences for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.user_capture_preferences from anon;
grant select, insert, update, delete on table public.user_capture_preferences to authenticated;

commit;
