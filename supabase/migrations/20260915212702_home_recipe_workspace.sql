-- Independent Home recipes and durable owner-only journaling. Additive: no
-- historical measurements, attribution, or recipe visibility are rewritten.
create table if not exists public.home_recipe_workspaces (
  user_id uuid primary key references auth.users(id) on delete cascade,
  revision bigint not null default 0,
  document jsonb not null default '{}'::jsonb,
  last_operation_id uuid,
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(document) = 'object')
);
alter table public.home_recipe_workspaces enable row level security;
revoke all on public.home_recipe_workspaces from public, anon, authenticated;
grant select on public.home_recipe_workspaces to authenticated;
create policy "Owners read Home workspace" on public.home_recipe_workspaces
  for select to authenticated using (user_id = (select auth.uid()));

create table if not exists private.home_recipe_contents (
  version_id uuid primary key references public.recipe_versions(id) on delete cascade,
  content jsonb not null check (jsonb_typeof(content) = 'object')
);
alter table private.home_recipe_contents enable row level security;
revoke all on private.home_recipe_contents from public, anon, authenticated;

-- One projection is used for both outward content and screening. Only recipe
-- fields may enter it; workspace attempts, drafts and media are never expanded.
create or replace function private.home_recipe_scalars_v1(p_value jsonb, p_keys text[])
returns jsonb language sql immutable set search_path = '' as $$
  select coalesce(jsonb_object_agg(key,value),'{}'::jsonb)
  from jsonb_each(case when jsonb_typeof(p_value)='object' then p_value else '{}'::jsonb end)
  where key=any(p_keys) and jsonb_typeof(value) in ('string','number','boolean','null');
$$;
revoke all on function private.home_recipe_scalars_v1(jsonb,text[]) from public,anon,authenticated;

create or replace function private.home_recipe_public_content_v1(p_content jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
declare result jsonb; key text; item jsonb; projected jsonb; entries jsonb;
begin
  result := private.home_recipe_scalars_v1(p_content,array[
    'name','template','method','servings','yieldDescription','sourceURL','creatorCredit','sourceVersionID','notes'
  ]);
  if jsonb_typeof(p_content->'targets')='object' then
    result := result || jsonb_build_object('targets',private.home_recipe_scalars_v1(p_content->'targets',array[
      'dose','ratio','output','calculation','seconds','temperature','grind','preinfusion','pressure','steepSeconds','dilution']));
  end if;
  if jsonb_typeof(p_content->'coffee')='object' then
    result := result || jsonb_build_object('coffee',private.home_recipe_scalars_v1(p_content->'coffee',array[
      'roaster','name','producer','origin','process','variety','roastLevel','roastDate','tastingNotes']));
  end if;
  if jsonb_typeof(p_content->'legacyDetails')='object' then
    result := result || jsonb_build_object('legacyDetails',private.recipe_shared_brew_details_v1(p_content->'legacyDetails'));
  end if;
  foreach key in array array['ingredients','steps','fields','metricConfiguration','equipment','tags','hiddenFields'] loop
    if jsonb_typeof(p_content->key) is distinct from 'array' then continue; end if;
    entries := '[]'::jsonb;
    for item in select value from jsonb_array_elements(p_content->key) loop
      if key in ('tags','hiddenFields') then
        if jsonb_typeof(item)='string' then entries := entries || jsonb_build_array(item); end if;
        continue;
      end if;
      if jsonb_typeof(item)<>'object' then continue; end if;
      projected := private.home_recipe_scalars_v1(item,case key
        when 'ingredients' then array['id','name','amount','unit']
        when 'steps' then array['id','instruction','startSeconds','waitSeconds','waterGrams','waterMode','isHidden']
        when 'fields' then array['id','label','kind','value','unit','isVisible']
        when 'metricConfiguration' then array['metric','label','isVisible']
        when 'equipment' then array['role','displayName','brand','model'] end);
      if key='ingredients' and jsonb_typeof(item->'recipe')='object' then
        projected := projected || jsonb_build_object('recipe',private.home_recipe_scalars_v1(item->'recipe',array['recipeID','versionID']));
      end if;
      if key='fields' and jsonb_typeof(item->'choices')='array' then
        projected := projected || jsonb_build_object('choices',(
          select coalesce(jsonb_agg(value),'[]'::jsonb) from jsonb_array_elements(item->'choices') where jsonb_typeof(value)='string'));
      end if;
      entries := entries || jsonb_build_array(projected);
    end loop;
    result := result || jsonb_build_object(key,entries);
  end loop;
  return result;
end;
$$;
revoke all on function private.home_recipe_public_content_v1(jsonb) from public,anon,authenticated;

create or replace function private.recipe_screening_details_v1(p_details jsonb)
returns jsonb language sql immutable set search_path = '' as $$
  with shared as (select private.recipe_shared_brew_details_v1(p_details) details)
  select details || jsonb_build_object('steps',(
    select coalesce(jsonb_agg(step-'id'),'[]'::jsonb) from jsonb_array_elements(details->'steps') step
  )) || case when jsonb_typeof(p_details->'homeRecipe')='object'
    then jsonb_build_object('homeRecipe',private.home_recipe_public_content_v1(p_details->'homeRecipe'))
    else '{}'::jsonb end from shared;
$$;
revoke all on function private.recipe_screening_details_v1(jsonb) from public,anon,authenticated;

create or replace function public.get_home_workspace_v1(p_owner_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result jsonb;
begin
  if actor is null or actor is distinct from p_owner_id then raise exception 'Account mismatch' using errcode = '42501'; end if;
  select jsonb_build_object('revision', revision, 'document', document) into result
    from public.home_recipe_workspaces where user_id = actor;
  return coalesce(result, jsonb_build_object('revision', 0, 'document', null));
end;
$$;

create or replace function public.save_home_workspace_v1(
  p_expected_revision bigint, p_operation_id uuid, p_document jsonb, p_owner_id uuid
) returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid(); state public.home_recipe_workspaces;
  recipe jsonb; version jsonb; content jsonb; ingredient jsonb;
  recipe_id uuid; new_version_id uuid; source_id uuid; existing_owner uuid;
  existing_content jsonb; existing_recipe uuid; existing_number integer;
begin
  if actor is null or actor is distinct from p_owner_id then raise exception 'Account mismatch' using errcode = '42501'; end if;
  if p_operation_id is null or p_expected_revision is null or p_expected_revision < 0
    or jsonb_typeof(p_document) <> 'object'
    or p_document->>'schemaVersion' is distinct from '1'
    or jsonb_typeof(p_document->'recipes') is distinct from 'array'
    or octet_length(p_document::text) > 8000000 then
    raise exception 'Invalid Home workspace';
  end if;
  insert into public.home_recipe_workspaces(user_id) values (actor) on conflict do nothing;
  select * into state from public.home_recipe_workspaces where user_id = actor for update;
  if state.last_operation_id = p_operation_id then
    return jsonb_build_object('revision', state.revision, 'document', state.document);
  end if;
  if state.revision <> p_expected_revision then raise exception 'HOME_WORKSPACE_CONFLICT' using errcode = '40001'; end if;

  for recipe in select value from jsonb_array_elements(p_document->'recipes') loop
    recipe_id := (recipe->>'id')::uuid;
    if jsonb_typeof(recipe->'versions') is distinct from 'array'
      or jsonb_array_length(recipe->'versions') = 0 then raise exception 'Recipe requires a version'; end if;
    select user_id into existing_owner from public.recipe_identities where id = recipe_id;
    if found and existing_owner <> actor then raise exception 'Recipe access denied' using errcode = '42501'; end if;
    insert into public.recipe_identities(id, user_id, name)
      values (recipe_id, actor, recipe->'versions'->-1->'content'->>'name')
      on conflict (id) do update set name = excluded.name, updated_at = now();
    for version in select value from jsonb_array_elements(recipe->'versions') loop
      new_version_id := (version->>'id')::uuid;
      content := version->'content';
      select rv.recipe_identity_id, rv.version_number, hc.content
        into existing_recipe, existing_number, existing_content
        from public.recipe_versions rv left join private.home_recipe_contents hc on hc.version_id = rv.id
        where rv.id = new_version_id;
      if found then
        if existing_recipe <> recipe_id or existing_number <> (version->>'number')::integer
          or existing_content is distinct from content then
          raise exception 'Immutable recipe version conflict' using errcode = '40001';
        end if;
        continue;
      end if;
      if length(trim(content->>'name')) not between 1 and 120 then raise exception 'Invalid recipe name'; end if;
      source_id := nullif(content->>'sourceVersionID', '')::uuid;
      -- Editing an adaptation cannot erase its provenance to regain original
      -- recipe publication rights. Existing immutable source rows remain the
      -- authority, even when a direct client omits local attribution fields.
      if exists (
        select 1 from public.recipe_versions prior
        where prior.recipe_identity_id=recipe_id and prior.source_recipe_version_id is not null
          and prior.source_recipe_version_id is distinct from source_id
      ) then raise exception 'Recipe source attribution must be preserved' using errcode='42501'; end if;
      if coalesce(trim(content->>'sourceURL'),'')='' and exists (
        select 1 from public.recipe_versions prior
        where prior.recipe_identity_id=recipe_id and prior.source_kind in ('external','purchased')
      ) then raise exception 'External recipe source must be preserved' using errcode='42501'; end if;
      if source_id is not null and not exists (
        select 1 from public.recipe_versions source join public.recipe_identities identity on identity.id = source.recipe_identity_id
        where source.id = source_id and private.can_project_recipe_version_as(source.id, actor)
          and (identity.user_id = actor or (
            source.visibility='everyone' and source.source_kind in ('original','adapted') and source.redistribution_allowed
          ))
      ) then raise exception 'Recipe reuse is not allowed' using errcode = '42501'; end if;
      insert into public.recipe_versions(id, recipe_identity_id, version_number, brew_details, visibility, source_kind, source_recipe_version_id)
        values (new_version_id, recipe_id, (version->>'number')::integer,
          jsonb_build_object('recipeName', content->>'name', 'homeRecipe', private.home_recipe_public_content_v1(content)), 'private',
          case when source_id is not null then 'adapted' when coalesce(content->>'sourceURL', '') <> '' then 'external' else 'original' end,
          source_id);
      insert into private.home_recipe_contents(version_id, content) values (new_version_id, content);
    end loop;
  end loop;

  -- Every link must name an owned immutable version. Linked content is never
  -- expanded into the parent payload, including when a parent is published.
  for recipe in select value from jsonb_array_elements(p_document->'recipes') loop
    for version in select value from jsonb_array_elements(recipe->'versions') loop
      for ingredient in select value from jsonb_array_elements(coalesce(version->'content'->'ingredients', '[]')) loop
        if ingredient->'recipe' is not null and ingredient->'recipe' <> 'null'::jsonb then
          if not exists (
            select 1 from public.recipe_versions rv join public.recipe_identities ri on ri.id = rv.recipe_identity_id
            where rv.id = (ingredient->'recipe'->>'versionID')::uuid
              and ri.id = (ingredient->'recipe'->>'recipeID')::uuid and ri.user_id = actor
          ) then raise exception 'Linked recipe access denied' using errcode = '42501'; end if;
        end if;
      end loop;
    end loop;
  end loop;
  if exists (
    with recursive edges as (
      select (r->>'id')::uuid parent, (i->'recipe'->>'recipeID')::uuid child
      from jsonb_array_elements(p_document->'recipes') r,
        jsonb_array_elements(coalesce(r->'versions'->-1->'content'->'ingredients', '[]')) i
      where i->'recipe' is not null and i->'recipe' <> 'null'::jsonb
    ), walk as (
      select parent, child, array[parent] path, parent = child cycle from edges
      union all
      select w.parent, e.child, w.path || w.child, e.child = any(w.path || w.child)
      from walk w join edges e on e.parent = w.child where not w.cycle
    ) select 1 from walk where cycle
  ) then raise exception 'Linked recipes cannot form a cycle'; end if;

  update public.home_recipe_workspaces set revision = state.revision + 1,
    document = p_document - 'pendingOperationID', last_operation_id = p_operation_id, updated_at = now()
    where user_id = actor returning * into state;
  return jsonb_build_object('revision', state.revision, 'document', state.document);
end;
$$;

create or replace function public.get_home_recipe_content_v1(p_version_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result jsonb;
begin
  if actor is null or not private.can_project_recipe_version_as(p_version_id, actor) then
    raise exception 'Recipe access denied' using errcode = '42501';
  end if;
  select private.home_recipe_public_content_v1(content) into result from private.home_recipe_contents where version_id = p_version_id;
  return result;
end;
$$;

revoke all on function public.get_home_workspace_v1(uuid) from public, anon;
revoke all on function public.save_home_workspace_v1(bigint, uuid, jsonb, uuid) from public, anon;
revoke all on function public.get_home_recipe_content_v1(uuid) from public, anon;
grant execute on function public.get_home_workspace_v1(uuid) to authenticated;
grant execute on function public.save_home_workspace_v1(bigint, uuid, jsonb, uuid) to authenticated;
grant execute on function public.get_home_recipe_content_v1(uuid) to authenticated;

create table private.home_post_recipe_attachments (
  visit_id uuid not null references public.visits(id) on delete cascade,
  version_id uuid not null references public.recipe_versions(id) on delete cascade,
  audience text not null check (audience in ('friends','everyone')),
  primary key (visit_id,version_id)
);
alter table private.home_post_recipe_attachments enable row level security;
revoke all on private.home_post_recipe_attachments from public,anon,authenticated;

create or replace function public.set_home_post_recipes_v1(p_visit_id uuid,p_owner_id uuid,p_attachments jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare actor uuid := auth.uid(); item jsonb; target record; requested_audience text;
begin
  if actor is null or actor is distinct from p_owner_id or not exists (
    select 1 from public.visits where id=p_visit_id and user_id=actor and upload_state='complete'
  ) then raise exception 'Post access denied' using errcode='42501'; end if;
  if jsonb_typeof(p_attachments) is distinct from 'array' or jsonb_array_length(p_attachments)>20 then
    raise exception 'Invalid recipe attachments';
  end if;
  for item in select value from jsonb_array_elements(p_attachments) loop
    requested_audience := item->>'audience';
    if requested_audience not in ('friends','everyone') or requested_audience is null
      or (item->>'acknowledgesSharing')::boolean is distinct from true then
      raise exception 'Confirm recipe sharing first' using errcode='42501';
    end if;
    select rv.* into target from public.recipe_versions rv join public.recipe_identities ri on ri.id=rv.recipe_identity_id
      where rv.id=(item->>'versionID')::uuid and ri.user_id=actor for update of rv;
    if not found then raise exception 'Recipe access denied' using errcode='42501'; end if;
    -- Never narrow an already broader recipe just because this post is Friends.
    -- The existing source-rights and visibility RPCs remain authoritative.
    if requested_audience='everyone' and target.visibility<>'everyone' then
      if target.source_kind not in ('original','adapted') then
        raise exception 'This source cannot share instructions with Everyone' using errcode='42501';
      end if;
      perform public.configure_recipe_source_rights_v1(target.id,target.source_kind,true,target.source_recipe_version_id);
      perform public.set_recipe_visibility_v1(target.id,'everyone',true);
    elsif requested_audience='friends' and target.visibility='private' then
      perform public.set_recipe_visibility_v1(target.id,'friends',false);
    end if;
  end loop;
  delete from private.home_post_recipe_attachments where visit_id=p_visit_id;
  insert into private.home_post_recipe_attachments(visit_id,version_id,audience)
    select p_visit_id,(entry.value->>'versionID')::uuid,entry.value->>'audience' from jsonb_array_elements(p_attachments) entry(value)
    on conflict do nothing;
end;
$$;

create or replace function public.get_home_post_recipes_v1(p_visit_id uuid)
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result jsonb;
begin
  if actor is null or not private.can_view_visit_as(p_visit_id,actor) then
    raise exception 'Post access denied' using errcode='42501';
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('versionID',a.version_id,'recipeID',v.recipe_identity_id,
    'name',coalesce(c.content->>'name',r.name),'versionNumber',v.version_number)),'[]'::jsonb) into result
    from private.home_post_recipe_attachments a join public.recipe_versions v on v.id=a.version_id
      join public.recipe_identities r on r.id=v.recipe_identity_id
      left join private.home_recipe_contents c on c.version_id=v.id
    where a.visit_id=p_visit_id and private.can_project_recipe_version_as(a.version_id,actor);
  return result;
end;
$$;
revoke all on function public.set_home_post_recipes_v1(uuid,uuid,jsonb),public.get_home_post_recipes_v1(uuid) from public,anon;
grant execute on function public.set_home_post_recipes_v1(uuid,uuid,jsonb),public.get_home_post_recipes_v1(uuid) to authenticated;

-- Preserve all prior export collections. The workspace includes private notes
-- only in this authenticated owner export, never in outward recipe projections.
create or replace function public.build_owner_data_export_v4()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare actor uuid := auth.uid(); result jsonb;
begin
  if actor is null then raise exception 'authentication required' using errcode='28000'; end if;
  result := public.build_owner_data_export_v3();
  return result || jsonb_build_object('home_recipes_and_attempts',
    coalesce((select document from public.home_recipe_workspaces where user_id=actor),'{}'::jsonb));
end;
$$;
revoke all on function public.build_owner_data_export_v4() from public,anon,authenticated;
grant execute on function public.build_owner_data_export_v4() to authenticated;
