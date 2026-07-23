-- Function to get aggregated cafe statistics for app-wide display
-- Returns total visits, average rating, and top 5 drinks ordered
CREATE OR REPLACE FUNCTION get_cafe_aggregate_stats(p_cafe_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    v_total_visits INT;
    v_average_rating DOUBLE PRECISION;
    v_top_drinks JSON;
BEGIN
    -- Get total visits and average rating
    SELECT
        COUNT(*)::INT,
        COALESCE(AVG(overall_score), 0)
    INTO v_total_visits, v_average_rating
    FROM visits
    WHERE cafe_id = p_cafe_id;

    -- Get top 5 drinks with proper name handling
    -- If drink_type is 'Other' and drink_type_custom is not empty, use custom name
    -- Otherwise use drink_type
    -- Normalize by lowercasing for grouping, but keep original casing for display
    WITH drink_stats AS (
        SELECT
            CASE
                WHEN drink_type = 'Other' AND drink_type_custom IS NOT NULL AND TRIM(drink_type_custom) != ''
                THEN TRIM(drink_type_custom)
                ELSE COALESCE(drink_type, 'Unknown')
            END AS drink_name,
            COUNT(*) AS order_count
        FROM visits
        WHERE cafe_id = p_cafe_id
        GROUP BY
            CASE
                WHEN drink_type = 'Other' AND drink_type_custom IS NOT NULL AND TRIM(drink_type_custom) != ''
                THEN LOWER(TRIM(drink_type_custom))
                ELSE LOWER(COALESCE(drink_type, 'unknown'))
            END,
            CASE
                WHEN drink_type = 'Other' AND drink_type_custom IS NOT NULL AND TRIM(drink_type_custom) != ''
                THEN TRIM(drink_type_custom)
                ELSE COALESCE(drink_type, 'Unknown')
            END
        ORDER BY order_count DESC
        LIMIT 5
    )
    SELECT COALESCE(
        json_agg(
            json_build_object(
                'drink_name', drink_name,
                'order_count', order_count,
                'percentage', CASE
                    WHEN v_total_visits > 0
                    THEN ROUND((order_count::NUMERIC / v_total_visits * 100)::NUMERIC, 1)
                    ELSE 0
                END
            )
        ),
        '[]'::json
    )
    INTO v_top_drinks
    FROM drink_stats;

    -- Build final result
    result := json_build_object(
        'total_visits', v_total_visits,
        'average_rating', ROUND(v_average_rating::NUMERIC, 2),
        'top_drinks', v_top_drinks
    );

    RETURN result;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_cafe_aggregate_stats(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION get_cafe_aggregate_stats(UUID) TO anon;;
