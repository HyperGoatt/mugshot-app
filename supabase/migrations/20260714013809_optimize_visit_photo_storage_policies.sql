-- Evaluate auth.uid() once per Storage policy statement rather than once per
-- candidate row. This is a forward-only correction to the preceding contract.

begin;

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

drop policy if exists "Users can update their own visit photos" on storage.objects;
create policy "Users can update their own visit photos"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'visit-photos'
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  )
  with check (
    bucket_id = 'visit-photos'
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
  );

drop policy if exists "Users can delete their own visit photos" on storage.objects;
create policy "Users can delete their own visit photos"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'visit-photos'
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  );

commit;
