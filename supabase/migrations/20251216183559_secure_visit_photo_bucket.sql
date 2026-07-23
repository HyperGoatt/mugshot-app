-- Fix visit-photos bucket security: Make bucket private and add visibility-aware RLS

-- Step 1: Update bucket to private
UPDATE storage.buckets SET public = false WHERE id = 'visit-photos';

-- Step 2: Drop the overly permissive policy if it exists
DROP POLICY IF EXISTS "Anyone can view visit photos" ON storage.objects;

-- Step 3: Create visibility-aware select policy for visit photos
CREATE POLICY "View photos based on visit visibility"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'visit-photos' AND
  (
    -- Check if photo belongs to a visit the user can see
    EXISTS (
      SELECT 1 FROM public.visits v
      LEFT JOIN public.visit_photos vp ON vp.visit_id = v.id
      WHERE (
        -- Match by poster_photo_url or visit_photos
        v.poster_photo_url LIKE '%' || storage.objects.name || '%'
        OR vp.photo_url LIKE '%' || storage.objects.name || '%'
      )
      AND (
        -- Visibility check: everyone, owner, or friends
        v.visibility = 'everyone'
        OR v.user_id = auth.uid()
        OR (
          v.visibility = 'friends'
          AND auth.uid() IS NOT NULL
          AND EXISTS (
            SELECT 1 FROM public.friends f
            WHERE f.user_id = auth.uid() AND f.friend_user_id = v.user_id
          )
        )
      )
    )
  )
);;
