
-- Create friend_requests table
CREATE TABLE IF NOT EXISTS public.friend_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Prevent duplicate pending requests
    CONSTRAINT friend_requests_unique_pending UNIQUE (from_user_id, to_user_id, status)
        DEFERRABLE INITIALLY DEFERRED,

    -- Prevent self-requests
    CONSTRAINT friend_requests_no_self CHECK (from_user_id != to_user_id)
);

-- Create indexes for efficient queries
CREATE INDEX IF NOT EXISTS idx_friend_requests_from_user ON public.friend_requests(from_user_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_to_user ON public.friend_requests(to_user_id);
CREATE INDEX IF NOT EXISTS idx_friend_requests_status ON public.friend_requests(status);
CREATE INDEX IF NOT EXISTS idx_friend_requests_created_at ON public.friend_requests(created_at DESC);

-- Add updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_friend_requests_updated_at BEFORE UPDATE ON public.friend_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable RLS
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Users can view their own incoming and outgoing friend requests
CREATE POLICY "Users can view own friend requests"
    ON public.friend_requests
    FOR SELECT
    USING (
        auth.uid() = from_user_id OR
        auth.uid() = to_user_id
    );

-- RLS Policy: Users can create friend requests (from themselves to others)
CREATE POLICY "Users can create friend requests"
    ON public.friend_requests
    FOR INSERT
    WITH CHECK (
        auth.uid() = from_user_id AND
        auth.uid() != to_user_id
    );

-- RLS Policy: Recipients can update requests sent to them (accept/reject)
CREATE POLICY "Recipients can update friend requests"
    ON public.friend_requests
    FOR UPDATE
    USING (auth.uid() = to_user_id)
    WITH CHECK (auth.uid() = to_user_id);

-- RLS Policy: Request senders can delete their own pending requests
CREATE POLICY "Users can delete own sent requests"
    ON public.friend_requests
    FOR DELETE
    USING (
        auth.uid() = from_user_id AND
        status = 'pending'
    );
;
