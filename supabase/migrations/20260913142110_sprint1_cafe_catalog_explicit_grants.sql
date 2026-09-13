-- New Supabase projects need explicit Data API grants. Preserve the catalog's
-- existing read/insert contract without inheriting legacy blanket privileges.
alter table public.cafes enable row level security;
revoke all on table public.cafes from public, anon, authenticated;
grant select on table public.cafes to anon, authenticated;
grant insert on table public.cafes to authenticated;
