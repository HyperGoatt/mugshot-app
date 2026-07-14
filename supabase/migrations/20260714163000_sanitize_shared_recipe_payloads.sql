-- Explicit recipe sharing exposes an allowlisted snapshot, never the raw
-- version JSON. This protects historical or future owner-only keys even if a
-- client accidentally placed them inside brew_details.

drop policy if exists "Recipients read explicitly shared recipe identities" on public.recipe_identities;
drop policy if exists "Recipients read explicitly shared recipe versions" on public.recipe_versions;

drop policy if exists "Owners read recipe versions" on public.recipe_versions;
create policy "Owners read recipe versions" on public.recipe_versions for select to authenticated
  using (exists (
    select 1 from public.recipe_identities identity
    where identity.id = recipe_identity_id
      and identity.user_id = (select auth.uid())
  ));

create or replace function public.list_shared_recipes()
returns table(
  recommendation_id uuid,
  recipe_identity_id uuid,
  recipe_version_id uuid,
  recipe_name text,
  version_number integer,
  version_label text,
  brew_details jsonb,
  sender_id uuid,
  note text,
  shared_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  select
    recommendation.id,
    identity.id,
    version.id,
    identity.name,
    version.version_number,
    version.version_label,
    jsonb_strip_nulls(jsonb_build_object(
      'beans', version.brew_details -> 'beans',
      'doseGrams', version.brew_details -> 'doseGrams',
      'yieldGrams', version.brew_details -> 'yieldGrams',
      'brewTimeSeconds', version.brew_details -> 'brewTimeSeconds',
      'beanOrigin', version.brew_details -> 'beanOrigin',
      'roastLevel', version.brew_details -> 'roastLevel',
      'grindSetting', version.brew_details -> 'grindSetting',
      'waterTemperatureCelsius', version.brew_details -> 'waterTemperatureCelsius',
      'waterNotes', version.brew_details -> 'waterNotes',
      'recipeName', version.brew_details -> 'recipeName',
      'recipeVersion', version.brew_details -> 'recipeVersion',
      'steps', version.brew_details -> 'steps',
      'additions', version.brew_details -> 'additions',
      'servingVolumeMilliliters', version.brew_details -> 'servingVolumeMilliliters',
      'espressoShotCount', version.brew_details -> 'espressoShotCount'
    )),
    recommendation.sender_id,
    recommendation.note,
    recommendation.created_at
  from public.trusted_recommendations recommendation
  join public.recipe_versions version on version.id = recommendation.target_recipe_version_id
  join public.recipe_identities identity on identity.id = version.recipe_identity_id
  where recommendation.target_kind = 'recipe'
    and recommendation.recipient_id = (select auth.uid())
    and recommendation.status <> 'dismissed'
    and not private.blocked_between(recommendation.sender_id, recommendation.recipient_id)
  order by recommendation.created_at desc, recommendation.id desc;
$$;

revoke all on function public.list_shared_recipes() from public, anon;
grant execute on function public.list_shared_recipes() to authenticated;
