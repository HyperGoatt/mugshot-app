-- Storage RLS executes with caller privileges. These narrow wrappers keep the
-- account-lifecycle helpers sealed while binding every decision to auth.uid().

create or replace function public.is_live_account(
  p_subject_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_subject_id is not null
    and p_subject_id = (select auth.uid())
    and private.is_live_account_as(p_subject_id);
$$;

create or replace function public.can_write_account_storage(
  p_subject_id uuid default auth.uid()
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_subject_id is not null
    and p_subject_id = (select auth.uid())
    and private.can_write_account_storage_as(p_subject_id);
$$;

revoke all on function public.is_live_account(uuid) from public;
revoke all on function public.can_write_account_storage(uuid) from public;
grant execute on function public.is_live_account(uuid) to anon, authenticated;
grant execute on function public.can_write_account_storage(uuid)
  to authenticated;

drop policy if exists "Authenticated users can upload visit photos"
  on storage.objects;
create policy "Authenticated users can upload visit photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'visit-photos'
    and public.can_write_account_storage((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name))
      in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
  );

drop policy if exists "Users can update their own visit photos"
  on storage.objects;
create policy "Users can update their own visit photos"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'visit-photos'
    and public.can_write_account_storage((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  )
  with check (
    bucket_id = 'visit-photos'
    and public.can_write_account_storage((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name))
      in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
  );

drop policy if exists "Users can delete their own visit photos"
  on storage.objects;
create policy "Users can delete their own visit photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'visit-photos'
    and public.can_write_account_storage((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  );

drop policy if exists "Owners can read their visit photo objects"
  on storage.objects;
create policy "Owners can read their visit photo objects"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'visit-photos'
    and public.is_live_account((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  );

drop policy if exists "View photos based on completed visit visibility"
  on storage.objects;
create policy "View photos based on completed visit visibility"
  on storage.objects for select to public
  using (
    bucket_id = 'visit-photos'
    and (
      (
        public.is_live_account((select auth.uid()))
        and lower((storage.foldername(name))[1])
          = (select lower(auth.uid()::text))
      )
      or public.can_view_visit_photo_object(name)
    )
  );

drop policy if exists "Owners upload private visit photos" on storage.objects;
create policy "Owners upload private visit photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'visit-photos-private'
    and public.can_write_account_storage((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name))
      in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
    and exists (
      select 1 from public.visits visit
      where lower(visit.id::text) = lower((storage.foldername(name))[2])
        and visit.user_id = (select auth.uid())
    )
  );

drop policy if exists "Owners update private visit photos" on storage.objects;
create policy "Owners update private visit photos"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'visit-photos-private'
    and public.can_write_account_storage((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  )
  with check (
    bucket_id = 'visit-photos-private'
    and public.can_write_account_storage((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
    and lower(storage.extension(name))
      in ('jpg', 'jpeg', 'png', 'gif', 'webp', 'heic')
    and exists (
      select 1 from public.visits visit
      where lower(visit.id::text) = lower((storage.foldername(name))[2])
        and visit.user_id = (select auth.uid())
    )
  );

drop policy if exists "Owners delete private visit photos" on storage.objects;
create policy "Owners delete private visit photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'visit-photos-private'
    and public.can_write_account_storage((select auth.uid()))
    and lower((storage.foldername(name))[1]) = (select lower(auth.uid()::text))
  );

drop policy if exists "Visit audiences read private visit photos"
  on storage.objects;
create policy "Visit audiences read private visit photos"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'visit-photos-private'
    and (
      (
        public.is_live_account((select auth.uid()))
        and lower((storage.foldername(name))[1])
          = (select lower(auth.uid()::text))
      )
      or public.can_view_visit_photo_object(name)
    )
  );

comment on function public.is_live_account(uuid) is
  'Caller-bound RLS wrapper for live-account checks.';
comment on function public.can_write_account_storage(uuid) is
  'Caller-bound RLS wrapper for account Storage writes.';
