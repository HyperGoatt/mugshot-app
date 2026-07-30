-- Make visit-photos bucket public so images can be accessed via getPublicUrl
UPDATE storage.buckets
SET public = true
WHERE id = 'visit-photos';;
