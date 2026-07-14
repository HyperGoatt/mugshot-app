-- Supabase Storage's remove endpoint reads object metadata before deleting it.
-- Keep owner-folder metadata readable after the visit row has been removed so
-- the app's durable post-delete media cleanup can finish without exposing an
-- orphan to another signed-in user.

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

commit;
