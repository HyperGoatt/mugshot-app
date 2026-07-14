-- RLS policy expressions execute with the caller's privileges. Use the
-- caller-bound public wrappers while keeping private visibility helpers sealed.

drop policy if exists "Visible sip companions" on public.visit_companions;
create policy "Visible sip companions" on public.visit_companions
  for select to authenticated
  using (
    public.can_view_visit(visit_id, (select auth.uid()))
    and not public.is_blocked_between((select auth.uid()), companion_user_id)
  );
