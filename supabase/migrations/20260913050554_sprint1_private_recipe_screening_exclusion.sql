-- Preserve explicit private-recipe recipient access without external screening.
-- Existing recipient, dismissal, audience and block predicates remain in force.
create or replace function private.can_project_recipe_version_as(
  p_version_id uuid,
  p_viewer uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select p_viewer is not null and exists (
    select 1
    from public.recipe_versions version
    join public.recipe_identities identity
      on identity.id = version.recipe_identity_id
    where version.id = p_version_id
      and (identity.user_id=p_viewer or version.visibility='private' or private.screening_approved_v1('recipe',version.id))
      and private.can_view_user_as(identity.user_id, p_viewer)
      and (
        identity.user_id = p_viewer
        or version.visibility = 'everyone'
        or (
          version.visibility = 'friends'
          and private.confirmed_friends(p_viewer, identity.user_id)
        )
        or exists (
          select 1
          from public.trusted_recommendations recommendation
          where recommendation.target_kind = 'recipe'
            and recommendation.target_recipe_version_id = version.id
            and recommendation.recipient_id = p_viewer
            and recommendation.status <> 'dismissed'
            and private.can_view_user_as(recommendation.sender_id, p_viewer)
        )
      )
  );
$$;

create or replace function private.can_view_recipe_version_as(p_version_id uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1
    from public.recipe_versions version
    join public.recipe_identities identity on identity.id = version.recipe_identity_id
    where version.id = p_version_id
      and (identity.user_id=p_viewer or version.visibility='private' or private.screening_approved_v1('recipe',version.id))
      and (
        identity.user_id = p_viewer
        or exists (
          select 1 from public.trusted_recommendations recommendation
          where recommendation.target_recipe_version_id = version.id
            and recommendation.target_kind = 'recipe'
            and recommendation.recipient_id = p_viewer
            and recommendation.status <> 'dismissed'
            and not private.blocked_between(recommendation.sender_id, recommendation.recipient_id)
        )
      )
  );
$$;

create or replace function private.can_view_recipe_identity_as(p_identity_id uuid, p_viewer uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.recipe_identities identity
    where identity.id = p_identity_id
      and (
        identity.user_id = p_viewer
        or exists (
          select 1
          from public.recipe_versions version
          join public.trusted_recommendations recommendation
            on recommendation.target_recipe_version_id = version.id
          where version.recipe_identity_id = identity.id
            and (version.visibility='private' or private.screening_approved_v1('recipe',version.id))
            and recommendation.target_kind = 'recipe'
            and recommendation.recipient_id = p_viewer
            and recommendation.status <> 'dismissed'
            and not private.blocked_between(recommendation.sender_id, recommendation.recipient_id)
        )
      )
  );
$$;
