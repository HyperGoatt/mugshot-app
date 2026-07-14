-- App Store polish: public URLs remain available from public buckets, but
-- PostgREST Storage listing must not reveal all avatars or unfinished visits.

drop policy if exists "Public can view profile images" on storage.objects;

drop policy if exists "View photos based on visit visibility" on storage.objects;
create policy "View photos based on completed visit visibility"
  on storage.objects
  for select
  to public
  using (
    bucket_id = 'visit-photos'
    and exists (
      select 1
      from public.visits v
      left join public.visit_photos vp on vp.visit_id = v.id
      where (
        v.poster_photo_url like '%' || objects.name || '%'
        or vp.photo_url like '%' || objects.name || '%'
      )
      and (
        v.upload_state = 'complete'
        or v.user_id = auth.uid()
      )
      and (
        v.visibility = 'everyone'
        or v.user_id = auth.uid()
        or (
          v.visibility = 'friends'
          and auth.uid() is not null
          and exists (
            select 1
            from public.friends f
            where f.user_id = auth.uid()
              and f.friend_user_id = v.user_id
          )
        )
      )
    )
  );
