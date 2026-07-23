-- Keep historical visit-photos URLs working while routing every new upload to
-- a private bucket. The app stores a durable mugshot-storage reference and
-- asks Storage for a short-lived signed URL under the current viewer's JWT.
--
-- The legacy bucket intentionally remains public during this compatibility
-- release. Older installed clients still render its public-form URLs directly,
-- so making it private here would blank historical media until those clients
-- update. A later adoption-gated migration can close that bucket after all
-- supported clients resolve signed URLs.

begin;
-- Storage policies cannot depend on the caller being able to select the
-- underlying visits row. This caller-bound helper performs the same canonical
-- audience check without accepting a spoofable viewer id. Its only anon-true
-- result is a complete Everyone visit.
create or replace function public.can_view_visit_photo_object(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.visits visit
    where lower(visit.user_id::text) =
          lower((pg_catalog.string_to_array(p_object_name, '/'))[1])
      and lower(visit.id::text) =
          lower((pg_catalog.string_to_array(p_object_name, '/'))[2])
      and (
        (
          (select auth.uid()) is null
          and visit.upload_state = 'complete'
          and visit.visibility = 'everyone'
        )
        or (
          (select auth.uid()) is not null
          and private.can_view_visit_as(visit.id, (select auth.uid()))
        )
      )
  );
$$;
revoke all on function public.can_view_visit_photo_object(text) from public;
grant execute on function public.can_view_visit_photo_object(text) to anon, authenticated;
drop policy if exists "View photos based on completed visit visibility" on storage.objects;
create policy "View photos based on completed visit visibility"
  on storage.objects
  for select
  to public
  using (
    bucket_id = 'visit-photos'
    and (
      lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
      or public.can_view_visit_photo_object(name)
    )
  );
insert into storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
values (
  'visit-photos-private',
  'visit-photos-private',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'image/heic']
)
on conflict (id) do update
set
  name = excluded.name,
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists "Owners upload private visit photos" on storage.objects;
create policy "Owners upload private visit photos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'visit-photos-private'
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
    and exists (
      select 1
      from public.visits visit
      where lower(visit.id::text) = lower((storage.foldername(name))[2])
        and visit.user_id = (select auth.uid())
    )
  );
drop policy if exists "Owners update private visit photos" on storage.objects;
create policy "Owners update private visit photos"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'visit-photos-private'
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  )
  with check (
    bucket_id = 'visit-photos-private'
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name)) in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
    and exists (
      select 1
      from public.visits visit
      where lower(visit.id::text) = lower((storage.foldername(name))[2])
        and visit.user_id = (select auth.uid())
    )
  );
drop policy if exists "Owners delete private visit photos" on storage.objects;
create policy "Owners delete private visit photos"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'visit-photos-private'
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  );
-- The owner-folder branch also keeps orphan metadata readable after a visit is
-- deleted, allowing the durable media cleanup queue to finish. Everyone else
-- must pass the exact same visit-level audience and block checks as the feed.
drop policy if exists "Visit audiences read private visit photos" on storage.objects;
create policy "Visit audiences read private visit photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'visit-photos-private'
    and (
      lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
      or public.can_view_visit_photo_object(name)
    )
  );
-- Signed-out discovery may sign media only for complete Everyone visits.
-- Keeping this separate avoids invoking authenticated-only helper functions
-- while the request is running as anon.
drop policy if exists "Anonymous viewers read Everyone private visit photos" on storage.objects;
create policy "Anonymous viewers read Everyone private visit photos"
  on storage.objects
  for select
  to anon
  using (
    bucket_id = 'visit-photos-private'
    and public.can_view_visit_photo_object(name)
  );
commit;
