-- Make the visit-photo Storage contract reproducible. The bucket remains
-- public for compatibility with the public URLs stored on existing visits;
-- object writes are still restricted to the signed-in owner's folder.

begin;

insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'visit-photos',
  'visit-photos',
  true,
  10485760,
  array['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/heic']
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Authenticated users can upload visit photos" on storage.objects;
create policy "Authenticated users can upload visit photos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'visit-photos'
    and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
  );

drop policy if exists "Users can update their own visit photos" on storage.objects;
create policy "Users can update their own visit photos"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'visit-photos'
    and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
  )
  with check (
    bucket_id = 'visit-photos'
    and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
  );

drop policy if exists "Users can delete their own visit photos" on storage.objects;
create policy "Users can delete their own visit photos"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'visit-photos'
    and lower((storage.foldername(name))[1]) = lower(auth.uid()::text)
  );

commit;
;
