
-- Update notifications table to allow 'friend_request' type
-- First, drop the existing check constraint
ALTER TABLE public.notifications
    DROP CONSTRAINT IF EXISTS notifications_type_check;

-- Add new check constraint that includes friend_request
ALTER TABLE public.notifications
    ADD CONSTRAINT notifications_type_check
    CHECK (type = ANY (ARRAY[
        'like'::text,
        'comment'::text,
        'reply'::text,
        'mention'::text,
        'follow'::text,
        'friend_request'::text,
        'friend_request_accepted'::text,
        'new_visit_from_friend'::text
    ]));
;
