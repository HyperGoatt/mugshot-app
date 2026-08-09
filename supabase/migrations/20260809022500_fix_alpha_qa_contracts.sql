begin;

-- Discovery V1 added signed-out public cafe lists after these caller-bound
-- wrappers were introduced. Keep the private eligibility helpers sealed and
-- let the public wrappers accept either the exact authenticated caller or the
-- signed-out NULL identity used by anon RLS evaluation.

create or replace function public.can_view_cafe_list(
  p_list_id uuid,
  p_viewer uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not distinct from (select auth.uid())
    and private.can_view_cafe_list_as(p_list_id, p_viewer);
$$;

create or replace function public.can_view_cafe_list_items(
  p_list_id uuid,
  p_viewer uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not distinct from (select auth.uid())
    and private.can_view_cafe_list_items_as(p_list_id, p_viewer);
$$;

revoke all on function public.can_view_cafe_list(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.can_view_cafe_list_items(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.can_view_cafe_list(uuid, uuid)
  to anon, authenticated;
grant execute on function public.can_view_cafe_list_items(uuid, uuid)
  to anon, authenticated;

drop policy if exists "Public cafe lists" on public.cafe_lists;
create policy "Public cafe lists"
on public.cafe_lists for select to anon, authenticated
using (public.can_view_cafe_list(id, (select auth.uid())));

drop policy if exists "Public cafe list items" on public.cafe_list_items;
create policy "Public cafe list items"
on public.cafe_list_items for select to anon, authenticated
using (public.can_view_cafe_list_items(list_id, (select auth.uid())));

commit;
