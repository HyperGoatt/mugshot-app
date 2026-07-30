-- Supabase public-schema defaults may grant table writes to authenticated.
-- Phase 4 mutations are RPC-only so caller identity and relationship checks
-- cannot be bypassed.
revoke insert, update, delete, truncate, references, trigger
on public.cafe_lists, public.cafe_list_members, public.cafe_list_items,
  public.trusted_recommendations, public.visit_reactions
from authenticated;

grant select
on public.cafe_lists, public.cafe_list_members, public.cafe_list_items,
  public.trusted_recommendations, public.visit_reactions
to authenticated;
;
