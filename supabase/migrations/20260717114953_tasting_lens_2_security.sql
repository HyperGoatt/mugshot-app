create or replace function public.reject_tasting_lens_history_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Tasting Lens history is append-only' using errcode = '55000';
end;
$$;

revoke all on function public.reject_tasting_lens_history_mutation() from public, anon, authenticated;

create trigger keep_visit_sensory_snapshots_immutable
  before update on public.visit_sensory_snapshots
  for each row execute function public.reject_tasting_lens_history_mutation();

create trigger keep_tasting_lens_corrections_immutable
  before update on public.tasting_lens_corrections
  for each row execute function public.reject_tasting_lens_history_mutation();

create trigger set_visit_sensory_projection_updated_at
  before update on public.visit_sensory_public_projections
  for each row execute function public.set_updated_at();

create trigger set_tasting_lens_preferences_updated_at
  before update on public.tasting_lens_preferences
  for each row execute function public.set_updated_at();

alter table public.visit_sensory_snapshots enable row level security;
alter table public.visit_sensory_snapshots force row level security;
alter table public.visit_sensory_public_projections enable row level security;
alter table public.visit_sensory_public_projections force row level security;
alter table public.tasting_lens_preferences enable row level security;
alter table public.tasting_lens_preferences force row level security;
alter table public.tasting_lens_corrections enable row level security;
alter table public.tasting_lens_corrections force row level security;

revoke all on table public.visit_sensory_snapshots from anon, authenticated;
revoke all on table public.visit_sensory_public_projections from anon, authenticated;
revoke all on table public.tasting_lens_preferences from anon, authenticated;
revoke all on table public.tasting_lens_corrections from anon, authenticated;

grant select, insert on table public.visit_sensory_snapshots to authenticated;
grant select, insert, update, delete on table public.visit_sensory_public_projections to authenticated;
grant select, insert, update, delete on table public.tasting_lens_preferences to authenticated;
grant select, insert on table public.tasting_lens_corrections to authenticated;

grant select, insert, update, delete on table public.visit_sensory_snapshots to service_role;
grant select, insert, update, delete on table public.visit_sensory_public_projections to service_role;
grant select, insert, update, delete on table public.tasting_lens_preferences to service_role;
grant select, insert, update, delete on table public.tasting_lens_corrections to service_role;

create policy "Owners read full sensory snapshots"
  on public.visit_sensory_snapshots
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners create full sensory snapshots"
  on public.visit_sensory_snapshots
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Visible visits expose only sensory projections"
  on public.visit_sensory_public_projections
  for select to authenticated
  using (public.can_view_visit(visit_id, (select auth.uid())));

create policy "Owners create sensory projections"
  on public.visit_sensory_public_projections
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Owners update sensory projections"
  on public.visit_sensory_public_projections
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Owners delete sensory projections"
  on public.visit_sensory_public_projections
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners read Tasting Lens preferences"
  on public.tasting_lens_preferences
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners create Tasting Lens preferences"
  on public.tasting_lens_preferences
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "Owners update Tasting Lens preferences"
  on public.tasting_lens_preferences
  for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Owners delete Tasting Lens preferences"
  on public.tasting_lens_preferences
  for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners read Tasting Lens corrections"
  on public.tasting_lens_corrections
  for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "Owners append Tasting Lens corrections"
  on public.tasting_lens_corrections
  for insert to authenticated
  with check ((select auth.uid()) = user_id);;
