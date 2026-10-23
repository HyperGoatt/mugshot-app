-- V4 posts expose only deliberate preparation facts. The owner workspace,
-- source text, notes, media paths, and linked recipe instructions stay private.
create function private.home_public_preparation_v4(p_details jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare raw jsonb := p_details -> 'homePreparation'; safe_rows jsonb;
begin
  if jsonb_typeof(raw) <> 'object' or jsonb_typeof(raw -> 'method') <> 'string' then
    return null;
  end if;

  select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object(
    'title', left(item ->> 'title', 80),
    'planned', case when jsonb_typeof(item -> 'planned') = 'number' then item -> 'planned' end,
    'actual', case when jsonb_typeof(item -> 'actual') = 'number' then item -> 'actual' end,
    'unit', left(coalesce(item ->> 'unit', ''), 16),
    'state', case when item ->> 'state' in ('unknown', 'asPlanned', 'measured')
      then item ->> 'state' else 'unknown' end
  )) order by ord), '[]'::jsonb) into safe_rows
  from jsonb_array_elements(case when jsonb_typeof(raw -> 'rows') = 'array'
    then raw -> 'rows' else '[]'::jsonb end) with ordinality as entry(item, ord)
  where ord <= 24 and jsonb_typeof(item) = 'object'
    and jsonb_typeof(item -> 'title') = 'string'
    and jsonb_typeof(item -> 'unit') = 'string';

  if jsonb_array_length(safe_rows) = 0 then return null; end if;
  return jsonb_strip_nulls(jsonb_build_object(
    'method', left(raw ->> 'method', 80),
    'recipeName', case when jsonb_typeof(raw -> 'recipeName') = 'string'
      then left(raw ->> 'recipeName', 120) end,
    'rows', safe_rows
  ));
end;
$$;
revoke all on function private.home_public_preparation_v4(jsonb) from public, anon, authenticated;

create function public.get_visit_home_preparation_v4(p_visit_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := auth.uid(); details jsonb;
begin
  if actor is null or not private.is_live_account_as(actor)
    or not private.can_view_visit_as(p_visit_id, actor) then
    return null;
  end if;
  select visit.brew_details into details from public.visits visit
  where visit.id = p_visit_id and visit.upload_state = 'complete';
  return private.home_public_preparation_v4(details);
end;
$$;
revoke all on function public.get_visit_home_preparation_v4(uuid) from public, anon, authenticated;
grant execute on function public.get_visit_home_preparation_v4(uuid) to authenticated;
