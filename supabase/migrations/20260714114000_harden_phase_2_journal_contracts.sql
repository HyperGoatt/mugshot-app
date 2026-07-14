-- Lock internal trigger helpers away from PostgREST and use init-plan-safe
-- auth lookups in the new owner policies.

revoke all on function public.materialize_new_visit_recipe_version()
  from public, anon, authenticated;

drop policy if exists "Owners read journal bookmarks" on public.visit_bookmarks;
create policy "Owners read journal bookmarks"
on public.visit_bookmarks for select
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Owners add journal bookmarks" on public.visit_bookmarks;
create policy "Owners add journal bookmarks"
on public.visit_bookmarks for insert
to authenticated
with check (
  user_id = (select auth.uid())
  and exists (
    select 1 from public.visits visit
    where visit.id = visit_id and visit.user_id = (select auth.uid())
  )
);
drop policy if exists "Owners remove journal bookmarks" on public.visit_bookmarks;
create policy "Owners remove journal bookmarks"
on public.visit_bookmarks for delete
to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "Owners manage recipe identities" on public.recipe_identities;
create policy "Owners manage recipe identities"
on public.recipe_identities for all
to authenticated
using (user_id = (select auth.uid()))
with check (user_id = (select auth.uid()));

drop policy if exists "Owners read recipe versions" on public.recipe_versions;
create policy "Owners read recipe versions"
on public.recipe_versions for select
to authenticated
using (
  exists (
    select 1 from public.recipe_identities identity
    where identity.id = recipe_identity_id
      and identity.user_id = (select auth.uid())
  )
);
