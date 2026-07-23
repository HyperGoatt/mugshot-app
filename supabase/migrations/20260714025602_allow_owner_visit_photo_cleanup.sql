begin;

drop policy if exists "Owners can read their visit photo objects" on storage.objects;
create policy "Owners can read their visit photo objects"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'visit-photos'
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  );

commit;;
