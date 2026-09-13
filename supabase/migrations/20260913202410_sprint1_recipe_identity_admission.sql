-- A visible visit does not independently publish its linked recipe identity.
do $$
declare source text;
begin
 source:=pg_get_functiondef('public.get_recipe_identity_for_visit_v1(uuid)'::regprocedure);
 if strpos(source,'and private.can_view_user_as(owner.id, input.actor)')=0 then
   raise exception 'recipe identity projection source drift';
 end if;
 execute replace(source,'and private.can_view_user_as(owner.id, input.actor)',
   'and private.can_view_user_as(owner.id, input.actor) and private.can_project_recipe_version_as(version.id, input.actor)');
end;
$$;
