-- RLS policy expressions run as the authenticated caller. Expose narrow,
-- caller-bound wrappers while keeping the underlying private helpers sealed.

create or replace function public.can_view_cafe_list(p_list_id uuid, p_viewer uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select p_viewer = (select auth.uid())
    and private.can_view_cafe_list_as(p_list_id, p_viewer);
$$;

create or replace function public.can_view_cafe_list_items(p_list_id uuid, p_viewer uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select p_viewer = (select auth.uid())
    and private.can_view_cafe_list_items_as(p_list_id, p_viewer);
$$;

create or replace function public.can_view_recipe_identity(p_identity_id uuid, p_viewer uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select p_viewer = (select auth.uid())
    and private.can_view_recipe_identity_as(p_identity_id, p_viewer);
$$;

create or replace function public.can_view_recipe_version(p_version_id uuid, p_viewer uuid default auth.uid())
returns boolean language sql stable security definer set search_path = '' as $$
  select p_viewer = (select auth.uid())
    and private.can_view_recipe_version_as(p_version_id, p_viewer);
$$;

revoke all on function public.can_view_cafe_list(uuid, uuid) from public, anon;
revoke all on function public.can_view_cafe_list_items(uuid, uuid) from public, anon;
revoke all on function public.can_view_recipe_identity(uuid, uuid) from public, anon;
revoke all on function public.can_view_recipe_version(uuid, uuid) from public, anon;
grant execute on function public.can_view_cafe_list(uuid, uuid) to authenticated;
grant execute on function public.can_view_cafe_list_items(uuid, uuid) to authenticated;
grant execute on function public.can_view_recipe_identity(uuid, uuid) to authenticated;
grant execute on function public.can_view_recipe_version(uuid, uuid) to authenticated;

drop policy if exists "Visible cafe lists" on public.cafe_lists;
create policy "Visible cafe lists" on public.cafe_lists for select to authenticated
  using (public.can_view_cafe_list(id, (select auth.uid())));

drop policy if exists "Visible cafe list memberships" on public.cafe_list_members;
create policy "Visible cafe list memberships" on public.cafe_list_members for select to authenticated
  using (
    user_id = (select auth.uid())
    or public.can_view_cafe_list(list_id, (select auth.uid()))
  );

drop policy if exists "Visible cafe list items" on public.cafe_list_items;
create policy "Visible cafe list items" on public.cafe_list_items for select to authenticated
  using (public.can_view_cafe_list_items(list_id, (select auth.uid())));

drop policy if exists "Recommendation participants read" on public.trusted_recommendations;
create policy "Recommendation participants read" on public.trusted_recommendations for select to authenticated
  using (
    (sender_id = (select auth.uid()) or recipient_id = (select auth.uid()))
    and not public.is_blocked_between(sender_id, recipient_id)
  );

drop policy if exists "Visible visit reactions" on public.visit_reactions;
create policy "Visible visit reactions" on public.visit_reactions for select to authenticated
  using (
    public.can_view_visit(visit_id, (select auth.uid()))
    and not public.is_blocked_between(user_id, (select auth.uid()))
  );

drop policy if exists "Recipients read explicitly shared recipe identities" on public.recipe_identities;
create policy "Recipients read explicitly shared recipe identities" on public.recipe_identities for select to authenticated
  using (public.can_view_recipe_identity(id, (select auth.uid())));

drop policy if exists "Owners read recipe versions" on public.recipe_versions;
create policy "Owners read recipe versions" on public.recipe_versions for select to authenticated
  using (public.can_view_recipe_version(id, (select auth.uid())));

drop policy if exists "Recipients read explicitly shared recipe versions" on public.recipe_versions;
create policy "Recipients read explicitly shared recipe versions" on public.recipe_versions for select to authenticated
  using (public.can_view_recipe_version(id, (select auth.uid())));
