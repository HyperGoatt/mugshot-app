begin;

create temp table recipe_owner_fixture as
select user_id from public.visits order by created_at desc limit 1;

do $$ begin
  if not exists (select 1 from recipe_owner_fixture) then
    raise exception 'recipe version contract requires one existing journal owner';
  end if;
end $$;

create temp table first_recipe_visit as
with inserted as (
  insert into public.visits (
    user_id, drink_type, drink_subtype, caption, visibility,
    ratings, overall_score, context_type, location_name, brew_method,
    brew_details, upload_state
  )
  select
    user_id, 'Coffee', 'Contract V60', '', 'private',
    '{"Overall":4}'::jsonb, 4, 'Recipe', 'Home', 'V60',
    '{"recipeName":"Contract V60","recipeVersion":"v1","steps":[{"id":"0f18ef86-94f4-4ea0-8c65-49bff1212c2d","instruction":"Bloom"}]}'::jsonb,
    'complete'
  from recipe_owner_fixture
  returning id
)
select id as visit_id from inserted;

do $$ begin
  if not exists (
    select 1
    from public.visits visit
    join public.recipe_versions version on version.id = visit.recipe_version_id
    join public.recipe_identities identity on identity.id = version.recipe_identity_id
    where visit.id = (select visit_id from first_recipe_visit)
      and version.version_number = 1
      and version.version_label = 'v1'
      and identity.name = 'Contract V60'
      and identity.user_id = visit.user_id
  ) then
    raise exception 'first recipe visit was not materialized';
  end if;
end $$;

create temp table second_recipe_visit as
with first_version as (
  select version.recipe_identity_id
  from public.visits visit
  join public.recipe_versions version on version.id = visit.recipe_version_id
  where visit.id = (select visit_id from first_recipe_visit)
), inserted as (
  insert into public.visits (
    user_id, drink_type, drink_subtype, caption, visibility,
    ratings, overall_score, context_type, location_name, brew_method,
    brew_details, upload_state
  )
  select
    owner.user_id, 'Coffee', 'Contract V60', '', 'private',
    '{"Overall":4.5}'::jsonb, 4.5, 'Recipe', 'Home', 'V60',
    jsonb_build_object(
      'recipeName', 'Contract V60',
      'recipeVersion', 'v2',
      'recipeIdentityID', first_version.recipe_identity_id::text,
      'steps', '[{"id":"b5028f58-a125-4d9d-88c9-e58d0930fd4e","instruction":"Longer bloom"}]'::jsonb
    ),
    'complete'
  from recipe_owner_fixture owner cross join first_version
  returning id
)
select id as visit_id from inserted;

do $$ begin
  if (
    select count(*)
    from public.recipe_versions version
    where version.recipe_identity_id = (
      select first_version.recipe_identity_id
      from public.visits visit
      join public.recipe_versions first_version on first_version.id = visit.recipe_version_id
      where visit.id = (select visit_id from first_recipe_visit)
    )
  ) <> 2 then
    raise exception 'recipe edit did not create an immutable second version';
  end if;

  if not exists (
    select 1
    from public.visits visit
    join public.recipe_versions version on version.id = visit.recipe_version_id
    where visit.id = (select visit_id from second_recipe_visit)
      and version.version_number = 2
      and version.version_label = 'v2'
      and version.brew_details ->> 'recipeVersion' = 'v2'
  ) then
    raise exception 'second recipe version did not preserve its own payload';
  end if;
end $$;

rollback;

select 'recipe_version_contract_passed' as result;
