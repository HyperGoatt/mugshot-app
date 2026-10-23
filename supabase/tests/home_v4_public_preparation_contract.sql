do $$
declare projection jsonb; definition text;
begin
  projection := private.home_public_preparation_v4(jsonb_build_object(
    'homePreparation', jsonb_build_object(
      'method', 'Espresso', 'privateNote', 'NEVER-SHARE',
      'rows', jsonb_build_array(jsonb_build_object(
        'title', 'Pumpkin syrup', 'planned', 20, 'actual', 22,
        'unit', 'g', 'state', 'measured', 'linkedInstructions', 'NEVER-SHARE'
      ))
    ), 'privateNotes', 'NEVER-SHARE', 'localMediaPath', 'NEVER-SHARE'
  ));
  if projection ->> 'method' <> 'Espresso'
    or projection -> 'rows' -> 0 ->> 'actual' <> '22'
    or position('NEVER-SHARE' in projection::text) > 0 then
    raise exception 'Home V4 preparation projection leaked private content';
  end if;

  select pg_get_functiondef('public.get_visit_home_preparation_v4(uuid)'::regprocedure)
    into definition;
  if position('private.can_view_visit_as(p_visit_id, actor)' in definition) = 0
    or position('visit.upload_state = ''complete''' in definition) = 0
    or not has_function_privilege('authenticated',
      'public.get_visit_home_preparation_v4(uuid)', 'EXECUTE')
    or has_function_privilege('anon',
      'public.get_visit_home_preparation_v4(uuid)', 'EXECUTE') then
    raise exception 'Home V4 detail access is missing its visibility gate';
  end if;
end$$;
