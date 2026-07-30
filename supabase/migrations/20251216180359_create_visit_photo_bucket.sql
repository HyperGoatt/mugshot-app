-- Create storage bucket for visit photos
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'visit-photos',
  'visit-photos',
  true,
  10485760, -- 10MB
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/heic']
)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for visit-photos bucket
CREATE POLICY "Anyone can view visit photos"
ON storage.objects FOR SELECT
USING (bucket_id = 'visit-photos');

CREATE POLICY "Authenticated users can upload visit photos"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'visit-photos'
  AND auth.role() = 'authenticated'
);

CREATE POLICY "Users can delete their own visit photos"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'visit-photos'
  AND auth.uid()::text = (storage.foldername(name))[1]
);;
