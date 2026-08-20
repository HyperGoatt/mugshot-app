begin;

-- PostgREST delete filters depend on both row and column visibility. Keep the
-- destructive operation owner-bound in one transaction and return only the
-- media manifest the same owner may clean up after the row is gone.
create or replace function public.delete_owned_visit_v1(
  p_visit_id uuid
)
returns table (
  photo_url text
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target_owner uuid;
  deleted_photo_urls text[] := '{}'::text[];
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_visit_id is null then
    raise exception 'visit is required' using errcode = '22023';
  end if;

  select visit.user_id into target_owner
  from public.visits visit
  where visit.id = p_visit_id
  for update;

  if not found then
    raise exception 'visit not found' using errcode = 'P0002';
  end if;
  if target_owner <> actor then
    raise exception 'visit belongs to another account' using errcode = '42501';
  end if;

  select coalesce(array_agg(distinct reference.photo_url), '{}'::text[])
  into deleted_photo_urls
  from (
    select photo.photo_url
    from public.visit_photos photo
    where photo.visit_id = p_visit_id
    union all
    select visit.poster_photo_url
    from public.visits visit
    where visit.id = p_visit_id
  ) reference
  where nullif(btrim(reference.photo_url), '') is not null;

  delete from public.visits visit
  where visit.id = p_visit_id
    and visit.user_id = actor;

  return query
  select stored_reference
  from unnest(deleted_photo_urls) stored_reference;
end;
$$;

revoke all on function public.delete_owned_visit_v1(uuid)
  from public, anon, authenticated;
grant execute on function public.delete_owned_visit_v1(uuid)
  to authenticated;

comment on function public.delete_owned_visit_v1(uuid) is
  'Deletes one visit owned by the authenticated account and returns its former media references for durable Storage cleanup.';

commit;
