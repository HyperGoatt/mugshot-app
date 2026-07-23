-- PostgREST applies SELECT RLS to rows returned from INSERT ... RETURNING.
-- The visibility helper reads the visits table and cannot observe the row
-- until the insert statement finishes, so owner inserts that request a
-- representation were rejected even though the INSERT policy passed.
-- Keep the shared visibility helper for established rows and add a direct,
-- caller-bound owner path that can evaluate the new row safely.

drop policy if exists "Visible visits" on public.visits;

create policy "Visible visits"
  on public.visits
  for select
  to authenticated
  using (
    (select auth.uid()) = user_id
    or public.can_view_visit(id, (select auth.uid()))
  );
;
