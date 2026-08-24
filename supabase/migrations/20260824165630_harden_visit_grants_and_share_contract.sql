-- Supabase's table-creation defaults can leave anonymous roles with ambient
-- table privileges even after the visit read surface is converted to column
-- grants. Remove those ambient privileges so the explicit safe read allowlist
-- remains the only anonymous path to raw visits. Existing column SELECT grants
-- are intentionally preserved.

begin;

revoke all privileges on table public.visits from anon;

grant select (
  id,
  user_id,
  cafe_id,
  drink_type,
  drink_type_custom,
  drink_subtype,
  caption,
  visibility,
  upload_state,
  ratings,
  category_scores,
  overall_score,
  poster_photo_url,
  context_type,
  location_name,
  city_state,
  recipe_version_id,
  cafe_session_id,
  cafe_session_order,
  cafe_session_role,
  created_at,
  home_coffee_bag_id
) on table public.visits to anon;

commit;
