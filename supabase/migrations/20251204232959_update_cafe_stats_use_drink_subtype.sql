-- Update get_cafe_aggregate_stats function to use drink_subtype instead of drink_type
-- This shows specific drinks (e.g., "Iced Honey Cinnamon Latte") instead of generic types

CREATE OR REPLACE FUNCTION get_cafe_aggregate_stats(p_cafe_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_total_visits INTEGER;
  v_average_rating NUMERIC(3,2);
  v_top_drinks JSON;
  v_result JSON;
BEGIN
  -- Get total visits for this cafe
  SELECT COUNT(*)
  INTO v_total_visits
  FROM visits
  WHERE cafe_id = p_cafe_id;

  -- Get average rating for this cafe
  SELECT COALESCE(AVG(overall_score), 0)
  INTO v_average_rating
  FROM visits
  WHERE cafe_id = p_cafe_id AND overall_score > 0;

  -- Get top 5 drinks ordered at this cafe
  -- Use drink_subtype when available, fallback to drink_type for old data
  SELECT COALESCE(
    json_agg(
      json_build_object(
        'drink_name', drink_name,
        'order_count', order_count,
        'percentage', ROUND((order_count::NUMERIC / NULLIF(v_total_visits, 0) * 100), 1)
      )
      ORDER BY order_count DESC
    ) FILTER (WHERE drink_name IS NOT NULL),
    '[]'::json
  )
  INTO v_top_drinks
  FROM (
    SELECT
      COALESCE(drink_subtype, drink_type) AS drink_name,
      COUNT(*) AS order_count
    FROM visits
    WHERE cafe_id = p_cafe_id
      AND (drink_subtype IS NOT NULL OR drink_type IS NOT NULL)
    GROUP BY COALESCE(drink_subtype, drink_type)
    ORDER BY COUNT(*) DESC
    LIMIT 5
  ) subquery;

  -- Build the final JSON result
  v_result := json_build_object(
    'total_visits', v_total_visits,
    'average_rating', v_average_rating,
    'top_drinks', v_top_drinks
  );

  RETURN v_result;
END;
$$;;
