begin;

-- Deploy only with compatible native/web resolvers after the isolated QA gate.
-- Stored historical URLs remain durable identifiers; public GET is disabled.
update storage.buckets set public=false
where id in ('profile-media','visit-photos','visit-photos-private');

create function private.media_reference_matches_object_v1(
  p_reference text, p_bucket text, p_name text
) returns boolean language sql immutable security definer set search_path='' as $$
  select coalesce(
    p_reference !~ '[?#]'
    and (p_reference like 'mugshot-storage://%'
      or p_reference ~ '^https://[^/?#]+/storage/v1/object/public/')
    and private.screening_decode_path_v1(regexp_replace(p_reference,
      '^(mugshot-storage://|https://[^/?#]+/storage/v1/object/public/)',''))
        = p_bucket||'/'||p_name,
    false
  );
$$;
revoke all on function private.media_reference_matches_object_v1(text,text,text)
from public,anon,authenticated;

create function public.can_read_protected_media_v1(p_bucket text,p_name text)
returns boolean language sql stable security definer set search_path='' as $$
  select coalesce(
    p_bucket in ('profile-media','visit-photos','visit-photos-private')
    and not (string_to_array(p_name,'/') && array['','.','..'])
    and (
      -- Owners can recover pending uploads and delete old unreferenced objects.
      (private.is_live_account_as(auth.uid())
        and lower(split_part(p_name,'/',1))=lower(auth.uid()::text))
      or (p_bucket='profile-media' and exists (
        select 1 from public.users owner
        where lower(owner.id::text)=lower(split_part(p_name,'/',1))
          and private.profile_owner_visible_v2(owner.id,auth.uid())
          and (private.media_reference_matches_object_v1(owner.avatar_url,p_bucket,p_name)
            or private.media_reference_matches_object_v1(owner.banner_url,p_bucket,p_name))
      ))
      or (p_bucket in ('visit-photos','visit-photos-private') and exists (
        select 1 from public.visits visit
        where lower(visit.user_id::text)=lower(split_part(p_name,'/',1))
          and lower(visit.id::text)=lower(split_part(p_name,'/',2))
          and (case when auth.uid() is null
            then private.is_public_visit_discoverable_v3(visit.id)
            else private.can_view_visit_as(visit.id,auth.uid()) end)
          and (private.media_reference_matches_object_v1(visit.poster_photo_url,p_bucket,p_name)
            or exists(select 1 from public.visit_photos photo where photo.visit_id=visit.id
              and private.media_reference_matches_object_v1(photo.photo_url,p_bucket,p_name)))
      ))
    ),false
  );
$$;
revoke all on function public.can_read_protected_media_v1(text,text) from public;
grant execute on function public.can_read_protected_media_v1(text,text) to anon,authenticated;

-- Preserve the old function identity while removing its anonymous raw-visibility bypass.
create or replace function public.can_view_visit_photo_object(p_object_name text)
returns boolean language sql stable security definer set search_path='' as $$
  select public.can_read_protected_media_v1('visit-photos',p_object_name);
$$;
revoke all on function public.can_view_visit_photo_object(text) from public;
grant execute on function public.can_view_visit_photo_object(text) to anon,authenticated;

-- Restrictive policy prevents any older permissive read policy from bypassing
-- this boundary. Other buckets retain their existing access rules.
create policy sprint1_protected_media_read_boundary on storage.objects
as restrictive for select to anon,authenticated using (
  bucket_id not in ('profile-media','visit-photos','visit-photos-private')
  or public.can_read_protected_media_v1(bucket_id,name)
);
create policy sprint1_authorized_media_reads on storage.objects
for select to anon,authenticated using (
  public.can_read_protected_media_v1(bucket_id,name)
);

comment on function public.can_read_protected_media_v1(text,text) is
'Caller-bound current-media reads: live owner recovery, screened profile images, screened visit audiences and exact bucket/path membership.';
commit;
