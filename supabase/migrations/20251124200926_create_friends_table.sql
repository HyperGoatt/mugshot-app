
-- Create friends table for bidirectional friendships
CREATE TABLE IF NOT EXISTS public.friends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    friend_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Ensure unique friendships (one row per direction)
    CONSTRAINT friends_unique_relationship UNIQUE (user_id, friend_user_id),

    -- Prevent self-friendship
    CONSTRAINT friends_no_self CHECK (user_id != friend_user_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_friends_user_id ON public.friends(user_id);
CREATE INDEX IF NOT EXISTS idx_friends_friend_user_id ON public.friends(friend_user_id);
CREATE INDEX IF NOT EXISTS idx_friends_bidirectional ON public.friends(user_id, friend_user_id);

-- Enable RLS
ALTER TABLE public.friends ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own friendships
CREATE POLICY "Users can view own friendships"
    ON public.friends
    FOR SELECT
    USING (auth.uid() = user_id);

-- RLS Policy: System can insert friendships (via service role or trigger)
-- Note: In production, this would typically be handled by a trigger after accepting a friend request
-- For now, we allow authenticated users to insert if they're one of the users
CREATE POLICY "Users can create friendships"
    ON public.friends
    FOR INSERT
    WITH CHECK (
        auth.uid() = user_id OR
        auth.uid() = friend_user_id
    );

-- RLS Policy: Users can delete their own friendships (removing friend)
CREATE POLICY "Users can delete own friendships"
    ON public.friends
    FOR DELETE
    USING (auth.uid() = user_id);
;
