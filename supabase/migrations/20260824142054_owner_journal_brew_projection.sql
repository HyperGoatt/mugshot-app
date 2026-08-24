-- Owner-only projection for private brew details used by Journal and Brew
-- Again. Direct SELECT remains revoked on the protected visit columns so a
-- social visit query can never read another person's recipe instructions.

begin;

create function public.get_owner_visit_brew_details_v1(
  p_visit_ids uuid[] default null,
  p_limit integer default 500
)
returns table (
  id uuid,
  brew_method text,
  equipment text,
  brew_details jsonb
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;
  if p_limit is null or p_limit < 1 or p_limit > 500 then
    raise exception 'limit must be between 1 and 500' using errcode = '22023';
  end if;
  if p_visit_ids is not null and cardinality(p_visit_ids) > 500 then
    raise exception 'at most 500 visit ids may be requested' using errcode = '22023';
  end if;

  return query
  select
    visit.id,
    visit.brew_method,
    visit.equipment,
    visit.brew_details
  from public.visits visit
  where visit.user_id = actor
    and visit.upload_state = 'complete'
    and (p_visit_ids is null or visit.id = any(p_visit_ids))
  order by visit.created_at desc, visit.id
  limit p_limit;
end;
$$;

revoke all on function public.get_owner_visit_brew_details_v1(uuid[],integer)
  from public, anon, authenticated;
grant execute on function public.get_owner_visit_brew_details_v1(uuid[],integer)
  to authenticated;

comment on function public.get_owner_visit_brew_details_v1(uuid[],integer) is
  'Returns private brew fields only for completed visits owned by the authenticated caller.';

commit;
