-- RLS expressions execute with caller privileges. Keep private projection
-- helpers sealed and expose one caller-bound recipe predicate for policy use.

create or replace function public.can_project_recipe_version(
  p_recipe_version_id uuid,
  p_viewer uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer = (select auth.uid())
    and private.can_project_recipe_version_as(p_recipe_version_id, p_viewer);
$$;

revoke all on function public.can_project_recipe_version(uuid,uuid)
  from public, anon;
grant execute on function public.can_project_recipe_version(uuid,uuid)
  to authenticated;

drop policy if exists "Recommendation participants read"
  on public.trusted_recommendations;
create policy "Recommendation participants read"
on public.trusted_recommendations for select to authenticated
using (
  (
    sender_id = (select auth.uid())
    and public.can_view_user(sender_id, (select auth.uid()))
  )
  or (
    recipient_id = (select auth.uid())
    and public.can_view_user(recipient_id, (select auth.uid()))
    and public.can_view_user(sender_id, (select auth.uid()))
    and case target_kind
      when 'cafe' then target_cafe_id is not null and exists (
        select 1 from public.cafes cafe where cafe.id = target_cafe_id
      )
      when 'visit' then target_visit_id is not null
        and public.can_view_visit(target_visit_id, (select auth.uid()))
      when 'recipe' then target_recipe_version_id is not null
        and public.can_project_recipe_version(
          target_recipe_version_id,
          (select auth.uid())
        )
      else false
    end
  )
);

comment on function public.can_project_recipe_version(uuid,uuid) is
  'Caller-bound RLS wrapper for recipe recommendation visibility.';
