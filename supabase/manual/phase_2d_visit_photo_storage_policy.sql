-- Phase 2D manual Supabase Storage policy preflight
--
-- Purpose:
--   Restrict native visit photo uploads to the signed-in user's own
--   visit-photos folder before iOS starts writing Storage objects.
--
-- Scope:
--   This updates only the INSERT policy on storage.objects for the
--   visit-photos bucket. Existing SELECT/delete policies are left intact.
--
-- Do not add secrets to this file.

begin;

-- 1. Preflight: confirm the visit-photos bucket settings.
select
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
from storage.buckets
where id = 'visit-photos';

-- 2. Replace the previous broad authenticated upload policy.
drop policy if exists "Authenticated users can upload visit photos" on storage.objects;

create policy "Authenticated users can upload visit photos"
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'visit-photos'
  and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
);

-- 3. Verification: this should show roles {authenticated} and lowercase-safe owner-folder checks.
select
  policyname,
  roles,
  cmd,
  with_check
from pg_policies
where schemaname = 'storage'
  and tablename = 'objects'
  and policyname = 'Authenticated users can upload visit photos';

commit;

-- Post-run checklist:
-- 1. Confirm storage.objects still has RLS enabled.
-- 2. Confirm visit_photos insert RLS still requires an owned public.visits row.
-- 3. Confirm iOS writes lowercased object paths as auth-user-id/visit-id/file-name.jpg.
-- 4. Avoid upsert for the first slice; upsert requires INSERT, SELECT, and UPDATE.
