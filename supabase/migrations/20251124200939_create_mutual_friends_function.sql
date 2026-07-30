
-- Create RPC function to get mutual friends between two users
-- This is more efficient than fetching both lists in the app and computing intersection
CREATE OR REPLACE FUNCTION get_mutual_friends(
    current_user_id UUID,
    other_user_id UUID
)
RETURNS TABLE (
    id UUID,
    display_name TEXT,
    username TEXT,
    bio TEXT,
    location TEXT,
    favorite_drink TEXT,
    instagram_handle TEXT,
    avatar_url TEXT,
    banner_url TEXT,
    website_url TEXT,
    created_at TIMESTAMPTZ,
    updated_at TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        u.id,
        u.display_name,
        u.username,
        u.bio,
        u.location,
        u.favorite_drink,
        u.instagram_handle,
        u.avatar_url,
        u.banner_url,
        u.website_url,
        u.created_at,
        u.updated_at
    FROM public.users u
    WHERE u.id IN (
        -- Get intersection of both users' friends
        SELECT f1.friend_user_id
        FROM public.friends f1
        WHERE f1.user_id = current_user_id
        INTERSECT
        SELECT f2.friend_user_id
        FROM public.friends f2
        WHERE f2.user_id = other_user_id
    )
    ORDER BY u.display_name, u.username;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION get_mutual_friends(UUID, UUID) TO authenticated;
;
