-- Allow authenticated users to read basic profile info from all users
-- This is needed for friend search functionality
CREATE POLICY "users_public_read" ON public.users
FOR SELECT
TO authenticated
USING (true);

-- Drop the overly restrictive self-only select policy
DROP POLICY IF EXISTS "users_self_select" ON public.users;;
