-- Fix the aggregate stats function to handle NULL drink_type with custom drink name
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
    -- Priority:
    --   1. If drink_type_custom is not empty, use it (regardless of drink_type value)
    --   2. Otherwise use drink_type
    --   3. Fall back to 'Unknown' if both are null/empty
    WITH drink_stats AS (
        SELECT
            CASE
                WHEN drink_type_custom IS NOT NULL AND TRIM(drink_type_custom) != ''
                THEN TRIM(drink_type_custom)
                WHEN drink_type IS NOT NULL AND TRIM(drink_type) != ''
                THEN drink_type
                ELSE 'Unknown'
            END AS drink_name,
            COUNT(*) AS order_count
        FROM visits
        WHERE cafe_id = p_cafe_id
        GROUP BY
            CASE
                WHEN drink_type_custom IS NOT NULL AND TRIM(drink_type_custom) != ''
                THEN LOWER(TRIM(drink_type_custom))
                WHEN drink_type IS NOT NULL AND TRIM(drink_type) != ''
                THEN LOWER(drink_type)
                ELSE 'unknown'
            END,
            CASE
                WHEN drink_type_custom IS NOT NULL AND TRIM(drink_type_custom) != ''
                THEN TRIM(drink_type_custom)
                WHEN drink_type IS NOT NULL AND TRIM(drink_type) != ''
                THEN drink_type
                ELSE 'Unknown'
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
$$;;
