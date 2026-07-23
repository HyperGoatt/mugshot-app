
-- Create trigger function to automatically create bidirectional friend entries
-- when a friend request is accepted
CREATE OR REPLACE FUNCTION create_friendship_on_request_accept()
RETURNS TRIGGER AS $$
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger that fires when friend_request status changes to accepted
CREATE TRIGGER friend_request_accepted_trigger
    AFTER UPDATE OF status ON public.friend_requests
    FOR EACH ROW
    WHEN (NEW.status = 'accepted' AND (OLD.status IS NULL OR OLD.status != 'accepted'))
    EXECUTE FUNCTION create_friendship_on_request_accept();
;
