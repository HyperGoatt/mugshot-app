
-- Fix security warnings by setting explicit search_path for all functions
-- This prevents search path injection attacks

-- Fix update_updated_at_column function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

-- Fix create_friendship_on_request_accept function
CREATE OR REPLACE FUNCTION create_friendship_on_request_accept()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
    -- Only proceed if status changed to 'accepted'
    IF NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted') THEN
        -- Insert bidirectional friendship entries
        -- Entry 1: from_user_id -> to_user_id
        INSERT INTO public.friends (user_id, friend_user_id, created_at)
        VALUES (NEW.from_user_id, NEW.to_user_id, now())
        ON CONFLICT (user_id, friend_user_id) DO NOTHING;

        -- Entry 2: to_user_id -> from_user_id (bidirectional)
        INSERT INTO public.friends (user_id, friend_user_id, created_at)
        VALUES (NEW.to_user_id, NEW.from_user_id, now())
        ON CONFLICT (user_id, friend_user_id) DO NOTHING;
    END IF;

    RETURN NEW;
END;
$$;

-- Fix get_mutual_friends function
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
SET search_path = public
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
;
