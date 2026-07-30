begin;

create temp table alpha_recipe_users as
select id, row_number() over (order by id) n
from (select id from public.users order by id limit 3) users;
grant select on alpha_recipe_users to authenticated;

do $$ begin
  if (select count(*) from alpha_recipe_users) < 3 then
    raise exception 'alpha recipe contract requires three existing users';
  end if;
end $$;

delete from public.user_blocks
where blocker_id in (select id from alpha_recipe_users)
  and blocked_id in (select id from alpha_recipe_users);
delete from public.friends
where user_id in (select id from alpha_recipe_users)
  and friend_user_id in (select id from alpha_recipe_users);
insert into public.friends (user_id, friend_user_id)
values
  ((select id from alpha_recipe_users where n = 1),
   (select id from alpha_recipe_users where n = 2)),
  ((select id from alpha_recipe_users where n = 2),
   (select id from alpha_recipe_users where n = 1))
on conflict do nothing;

create temp table alpha_legacy_recipe as
with legacy_visit as (
  insert into public.visits (
    user_id,
    drink_type,
    drink_subtype,
    caption,
    visibility,
    ratings,
    overall_score,
    context_type,
    location_name,
    brew_method,
    equipment,
    brew_details,
    upload_state
  )
  select
    id,
    'Coffee',
    'Legacy V60',
    'Legacy recipe read compatibility without mutation.',
    'everyone',
    '{"Overall":4.4}'::jsonb,
    4.4,
    'Home',
    'Home',
    'Legacy source-visit method',
    'Legacy source-visit dripper',
    '{"legacyVisitKey":"preserve exactly"}'::jsonb,
    'complete'
  from alpha_recipe_users where n = 1
  returning id, user_id
), legacy_identity as (
  insert into public.recipe_identities (user_id, name)
  select user_id, 'Legacy recipe identity' from legacy_visit
  returning id
), legacy_version as (
  insert into public.recipe_versions (
    recipe_identity_id,
    version_number,
    version_label,
    brew_details,
    source_visit_id,
    visibility,
    brew_method,
    equipment,
    source_kind,
    redistribution_allowed,
    public_reuse_acknowledged_at
  )
  select
    identity.id,
    1,
    'Legacy v1',
    '{"recipeName":"Legacy recipe identity","beans":"Legacy beans"}'::jsonb,
    visit.id,
    'everyone',
    null,
    null,
    'original',
    true,
    now()
  from legacy_identity identity cross join legacy_visit visit
  returning id, source_visit_id
)
select id recipe_version_id, source_visit_id visit_id from legacy_version;

update public.visits visit
set recipe_version_id = legacy.recipe_version_id
from alpha_legacy_recipe legacy
where visit.id = legacy.visit_id;
grant select on alpha_legacy_recipe to authenticated;

create temp table alpha_legacy_adaptation (recipe_version_id uuid not null);
grant select, insert on alpha_legacy_adaptation to authenticated;

do $$ begin
  if not exists (
    select 1
    from public.recipe_versions version
    join alpha_legacy_recipe legacy on legacy.recipe_version_id = version.id
    join public.visits visit on visit.id = legacy.visit_id
    where version.brew_method is null
      and version.equipment is null
      and visit.brew_method = 'Legacy source-visit method'
      and visit.equipment = 'Legacy source-visit dripper'
      and visit.brew_details = '{"legacyVisitKey":"preserve exactly"}'::jsonb
  ) then
    raise exception 'legacy recipe fixture did not begin byte-preserving fallback state';
  end if;
end $$;

create temp table alpha_recipe_target as
with inserted as (
  insert into public.visits (
    user_id,
    drink_type,
    drink_subtype,
    caption,
    visibility,
    ratings,
    overall_score,
    context_type,
    location_name,
    brew_method,
    equipment,
    brew_details,
    upload_state
  )
  select
    id,
    'Coffee',
    'Alpha V60',
    'The post is public but its recipe begins private.',
    'everyone',
    '{"Overall":4.5}'::jsonb,
    4.5,
    'Recipe',
    'Home',
    'V60',
    'Alpha dripper',
    '{"recipeName":"Alpha V60","doseGrams":18,"steps":[{"instruction":"Bloom"}],"privateNotes":"never project this"}'::jsonb,
    'complete'
  from alpha_recipe_users where n = 1
  returning id
)
select * from inserted;
alter table alpha_recipe_target add column recipe_version_id uuid;
update alpha_recipe_target target
set recipe_version_id = visit.recipe_version_id
from public.visits visit
where visit.id = target.id;
grant select on alpha_recipe_target to authenticated;

do $$ begin
  if (select recipe_version_id from alpha_recipe_target) is null then
    raise exception 'recipe visit did not materialize an immutable version';
  end if;
  if not exists (
    select 1
    from public.recipe_versions version
    where version.id = (select recipe_version_id from alpha_recipe_target)
      and version.visibility = 'private'
      and version.source_kind = 'unspecified'
      and version.brew_method = 'V60'
      and version.equipment = 'Alpha dripper'
  ) then
    raise exception 'new recipe metadata did not materialize safely';
  end if;
end $$;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 3),
  'role', 'authenticated'
)::text, true);

do $$
declare projection jsonb;
declare adapted_version uuid;
declare adapted_projection jsonb;
begin
  if public.get_recipe_projection_for_visit_v1(
    (select id from alpha_recipe_target)
  ) is not null then
    raise exception 'public post leaked its independently private recipe';
  end if;
  begin
    perform public.set_recipe_visibility_v1(
      (select recipe_version_id from alpha_recipe_target),
      'everyone',
      true
    );
    raise exception 'non-owner changed recipe visibility';
  exception when sqlstate '42501' then null;
  end;

  projection := public.get_recipe_projection_for_visit_v1(
    (select visit_id from alpha_legacy_recipe)
  );
  if projection is null
     or projection ->> 'brew_method' <> 'Legacy source-visit method'
     or projection ->> 'equipment' <> 'Legacy source-visit dripper' then
    raise exception 'authorized legacy projection did not resolve source-visit equipment';
  end if;

  adapted_version := public.save_recipe_adaptation_v1(
    (select recipe_version_id from alpha_legacy_recipe),
    'Legacy fallback adaptation',
    'Adapted v1'
  );
  insert into alpha_legacy_adaptation values (adapted_version);
  adapted_projection := public.get_recipe_projection_v1(adapted_version);
  if adapted_projection ->> 'brew_method' <> 'Legacy source-visit method'
     or adapted_projection ->> 'equipment' <> 'Legacy source-visit dripper' then
    raise exception 'legacy adaptation did not copy resolved source-visit equipment';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 1),
  'role', 'authenticated'
)::text, true);

select public.configure_recipe_source_rights_v1(
  (select recipe_version_id from alpha_recipe_target),
  'original',
  true,
  null
);

do $$ begin
  begin
    perform public.set_recipe_visibility_v1(
      (select recipe_version_id from alpha_recipe_target),
      'everyone',
      false
    );
    raise exception 'Everyone recipe unexpectedly skipped rights acknowledgment';
  exception when sqlstate '42501' then null;
  end;
  begin
    perform public.set_recipe_visibility_v1(
      (select recipe_version_id from alpha_recipe_target),
      'everyone',
      null
    );
    raise exception 'Everyone recipe unexpectedly accepted null rights acknowledgment';
  exception when sqlstate '42501' then null;
  end;
end $$;

select public.set_recipe_visibility_v1(
  (select recipe_version_id from alpha_recipe_target),
  'everyone',
  true
);

-- A social restriction may not expand public recipe reuse, even when the
-- recipe audience itself remains Everyone. Privacy/safety reductions continue
-- to work so a restricted owner is never trapped in a broader state.
reset role;
insert into private.moderation_actions (
  subject_kind,
  subject_id,
  action_kind,
  reason_code
) values (
  'user',
  (select id from alpha_recipe_users where n = 1),
  'social_restricted',
  'alpha_recipe_reuse_contract'
);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 1),
  'role', 'authenticated'
)::text, true);

select public.set_recipe_visibility_v1(
  (select recipe_version_id from alpha_recipe_target),
  'private',
  false
);
select public.configure_recipe_source_rights_v1(
  (select recipe_version_id from alpha_recipe_target),
  'original',
  false,
  null
);

do $$ begin
  begin
    perform public.set_recipe_visibility_v1(
      (select recipe_version_id from alpha_recipe_target),
      'everyone',
      true
    );
    raise exception 'restricted owner expanded public recipe reuse';
  exception when sqlstate '42501' then null;
  end;
end $$;

reset role;
delete from private.moderation_actions
where subject_kind = 'user'
  and subject_id = (select id from alpha_recipe_users where n = 1)
  and reason_code = 'alpha_recipe_reuse_contract';

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 1),
  'role', 'authenticated'
)::text, true);
select public.configure_recipe_source_rights_v1(
  (select recipe_version_id from alpha_recipe_target),
  'original',
  true,
  null
);
select public.set_recipe_visibility_v1(
  (select recipe_version_id from alpha_recipe_target),
  'everyone',
  true
);

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 3),
  'role', 'authenticated'
)::text, true);

do $$
declare projection jsonb;
declare adapted_version uuid;
begin
  projection := public.get_recipe_projection_v1(
    (select recipe_version_id from alpha_recipe_target)
  );
  if projection is null
     or projection ->> 'visibility' <> 'everyone'
     or projection ->> 'can_save_and_adapt' <> 'true' then
    raise exception 'Everyone recipe projection was unavailable or not reusable';
  end if;
  if (projection -> 'brew_details') ? 'privateNotes' then
    raise exception 'allowlisted recipe projection leaked a private JSON key';
  end if;

  adapted_version := public.save_recipe_adaptation_v1(
    (select recipe_version_id from alpha_recipe_target),
    'My Alpha adaptation',
    'v1'
  );
  if not exists (
    select 1
    from public.recipe_versions version
    join public.recipe_identities identity
      on identity.id = version.recipe_identity_id
    where version.id = adapted_version
      and identity.user_id = (select id from alpha_recipe_users where n = 3)
      and version.visibility = 'private'
      and version.source_kind = 'adapted'
      and version.source_recipe_version_id =
        (select recipe_version_id from alpha_recipe_target)
      and not (version.brew_details ? 'privateNotes')
  ) then
    raise exception 'saved adaptation was not private, attributed, and allowlisted';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 1),
  'role', 'authenticated'
)::text, true);
select public.set_recipe_visibility_v1(
  (select recipe_version_id from alpha_recipe_target),
  'friends',
  false
);

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 2),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if public.get_recipe_projection_v1(
    (select recipe_version_id from alpha_recipe_target)
  ) is null then
    raise exception 'confirmed friend could not see Friends recipe';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 1),
  'role', 'authenticated'
)::text, true);
select public.send_trusted_recommendation(
  (select id from alpha_recipe_users where n = 2),
  'recipe',
  (select recipe_version_id from alpha_recipe_target),
  'Projection enforcement contract'
);

reset role;
select set_config('request.jwt.claims', '{}'::jsonb::text, true);
update public.users
set taste_passport_visibility = 'friends'
where id = (select id from alpha_recipe_users where n = 1);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 2),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if not exists (
    select 1 from public.list_shared_recipes()
    where recipe_version_id = (select recipe_version_id from alpha_recipe_target)
  ) or not exists (
    select 1 from public.trusted_recommendations
    where target_recipe_version_id =
      (select recipe_version_id from alpha_recipe_target)
  ) then
    raise exception 'visible shared recipe recommendation was unavailable';
  end if;
  perform * from public.friend_compatibility(
    (select id from alpha_recipe_users where n = 1)
  );
end $$;

reset role;
select set_config('request.jwt.claims', '{}'::jsonb::text, true);
update public.users
set taste_passport_visibility = 'private'
where id = (select id from alpha_recipe_users where n = 1);
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 2),
  'role', 'authenticated'
)::text, true);
do $$ begin
  begin
    perform * from public.friend_compatibility(
      (select id from alpha_recipe_users where n = 1)
    );
    raise exception 'Private Taste Passport exposed compatibility traits';
  exception when sqlstate '42501' then null;
  end;
end $$;

reset role;
select set_config('request.jwt.claims', '{}'::jsonb::text, true);
update public.users
set taste_passport_visibility = 'friends'
where id = (select id from alpha_recipe_users where n = 1);
insert into private.moderation_actions(
  subject_kind, subject_id, action_kind, reason_code
) values (
  'user',
  (select id from alpha_recipe_users where n = 1),
  'account_suspended',
  'shared_recipe_projection_contract'
);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 2),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if exists (
    select 1 from public.list_shared_recipes()
    where recipe_version_id = (select recipe_version_id from alpha_recipe_target)
  ) or exists (
    select 1 from public.trusted_recommendations
    where target_recipe_version_id =
      (select recipe_version_id from alpha_recipe_target)
  ) then
    raise exception 'suspended recipe owner remained in recommendation surfaces';
  end if;
end $$;

reset role;
delete from private.moderation_actions
where subject_kind = 'user'
  and subject_id = (select id from alpha_recipe_users where n = 1)
  and reason_code = 'shared_recipe_projection_contract';
set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 2),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if not exists (
    select 1 from public.list_shared_recipes()
    where recipe_version_id = (select recipe_version_id from alpha_recipe_target)
  ) or not exists (
    select 1 from public.trusted_recommendations
    where target_recipe_version_id =
      (select recipe_version_id from alpha_recipe_target)
  ) then
    raise exception 'recommendation surfaces did not recover after revocation';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 3),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if public.get_recipe_projection_v1(
    (select recipe_version_id from alpha_recipe_target)
  ) is not null then
    raise exception 'stranger saw Friends recipe';
  end if;
end $$;

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 1),
  'role', 'authenticated'
)::text, true);
do $$ begin
  begin
    perform public.configure_recipe_source_rights_v1(
      (select recipe_version_id from alpha_recipe_target),
      'external',
      true,
      null
    );
    raise exception 'immutable recipe source provenance was replaced';
  exception when sqlstate '55000' then null;
  end;
end $$;

reset role;
do $$ begin
  if not exists (
    select 1
    from public.recipe_versions version
    join alpha_legacy_recipe legacy on legacy.recipe_version_id = version.id
    join public.visits visit on visit.id = legacy.visit_id
    where version.brew_method is null
      and version.equipment is null
      and visit.brew_method = 'Legacy source-visit method'
      and visit.equipment = 'Legacy source-visit dripper'
      and visit.brew_details = '{"legacyVisitKey":"preserve exactly"}'::jsonb
  ) then
    raise exception 'projection or adaptation mutated the legacy source rows';
  end if;
  if not exists (
    select 1
    from public.recipe_versions version
    where version.id = (select recipe_version_id from alpha_legacy_adaptation)
      and version.brew_method = 'Legacy source-visit method'
      and version.equipment = 'Legacy source-visit dripper'
  ) then
    raise exception 'legacy adaptation did not persist resolved equipment safely';
  end if;
end $$;

insert into public.user_blocks (blocker_id, blocked_id)
values (
  (select id from alpha_recipe_users where n = 1),
  (select id from alpha_recipe_users where n = 2)
);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from alpha_recipe_users where n = 2),
  'role', 'authenticated'
)::text, true);
do $$ begin
  if public.get_recipe_projection_v1(
    (select recipe_version_id from alpha_recipe_target)
  ) is not null then
    raise exception 'block did not sever recipe projection visibility';
  end if;
end $$;

rollback;

select 'alpha_recipe_visibility_contract_passed' as result;
