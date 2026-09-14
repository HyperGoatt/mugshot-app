-- Saved uses the Data API directly. Explicit privileges make clean replays
-- independent of the project's historical default privileges; RLS still owns
-- row authorization and the cafe-reference trigger still validates admission.
revoke all on public.user_cafe_states from anon;
grant select, insert, update, delete on public.user_cafe_states to authenticated;
alter table public.user_cafe_states enable row level security;
alter policy "Users can view their own cafe states" on public.user_cafe_states
  to authenticated using ((select auth.uid()) = user_id);
alter policy "Users can insert their own cafe states" on public.user_cafe_states
  to authenticated with check ((select auth.uid()) = user_id);
alter policy "Users can update their own cafe states" on public.user_cafe_states
  to authenticated using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
alter policy "Users can delete their own cafe states" on public.user_cafe_states
  to authenticated using ((select auth.uid()) = user_id);
