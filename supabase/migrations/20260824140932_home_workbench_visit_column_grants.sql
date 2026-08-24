-- Restore the hardened visit read/write contract after adding the optional
-- Home coffee relationship. The visits table intentionally uses column-level
-- privileges, so additive columns are not available to app roles until they
-- are explicitly allowlisted.

begin;

grant select (home_coffee_bag_id)
  on table public.visits to anon, authenticated;

grant insert (home_coffee_bag_id)
  on table public.visits to authenticated;

commit;
