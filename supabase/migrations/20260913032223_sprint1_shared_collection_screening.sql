-- One allowlist governs both outward recipe projection and provider input.
create function private.recipe_shared_brew_details_v1(p_details jsonb)
returns jsonb language sql immutable set search_path='' as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'beans',case when jsonb_typeof(p_details->'beans') in ('string') then p_details->'beans' end,
    'beanOrigin',case when jsonb_typeof(p_details->'beanOrigin') in ('string') then p_details->'beanOrigin' end,
    'roastLevel',case when jsonb_typeof(p_details->'roastLevel') in ('string') then p_details->'roastLevel' end,
    'grindSetting',case when jsonb_typeof(p_details->'grindSetting') in ('string') then p_details->'grindSetting' end,
    'waterNotes',case when jsonb_typeof(p_details->'waterNotes') in ('string') then p_details->'waterNotes' end,
    'recipeName',case when jsonb_typeof(p_details->'recipeName') in ('string') then p_details->'recipeName' end,
    'recipeVersion',case when jsonb_typeof(p_details->'recipeVersion') in ('string') then p_details->'recipeVersion' end,
    'additions',case when jsonb_typeof(p_details->'additions') in ('string') then p_details->'additions' end,
    'doseGrams',case when jsonb_typeof(p_details->'doseGrams') in ('number') then p_details->'doseGrams' end,
    'yieldGrams',case when jsonb_typeof(p_details->'yieldGrams') in ('number') then p_details->'yieldGrams' end,
    'brewTimeSeconds',case when jsonb_typeof(p_details->'brewTimeSeconds') in ('number') then p_details->'brewTimeSeconds' end,
    'waterTemperatureCelsius',case when jsonb_typeof(p_details->'waterTemperatureCelsius') in ('number') then p_details->'waterTemperatureCelsius' end,
    'servingVolumeMilliliters',case when jsonb_typeof(p_details->'servingVolumeMilliliters') in ('number') then p_details->'servingVolumeMilliliters' end,
    'espressoShotCount',case when jsonb_typeof(p_details->'espressoShotCount') in ('number') then p_details->'espressoShotCount' end,
    'coffeeBag',jsonb_strip_nulls(jsonb_build_object('roaster',case when jsonb_typeof((p_details->'coffeeBag')->'roaster') in ('string') then (p_details->'coffeeBag')->'roaster' end,'name',case when jsonb_typeof((p_details->'coffeeBag')->'name') in ('string') then (p_details->'coffeeBag')->'name' end,'producer',case when jsonb_typeof((p_details->'coffeeBag')->'producer') in ('string') then (p_details->'coffeeBag')->'producer' end,'origin',case when jsonb_typeof((p_details->'coffeeBag')->'origin') in ('string') then (p_details->'coffeeBag')->'origin' end,'process',case when jsonb_typeof((p_details->'coffeeBag')->'process') in ('string') then (p_details->'coffeeBag')->'process' end,'variety',case when jsonb_typeof((p_details->'coffeeBag')->'variety') in ('string') then (p_details->'coffeeBag')->'variety' end,'roastLevel',case when jsonb_typeof((p_details->'coffeeBag')->'roastLevel') in ('string') then (p_details->'coffeeBag')->'roastLevel' end,'tastingNotes',case when jsonb_typeof((p_details->'coffeeBag')->'tastingNotes') in ('string') then (p_details->'coffeeBag')->'tastingNotes' end,'roastDate',case when jsonb_typeof((p_details->'coffeeBag')->'roastDate') in ('string','number') then (p_details->'coffeeBag')->'roastDate' end)),
    'homeMethodDetails',jsonb_strip_nulls(jsonb_build_object('waterGrams',case when jsonb_typeof((p_details->'homeMethodDetails')->'waterGrams') in ('number') then (p_details->'homeMethodDetails')->'waterGrams' end,'bloomGrams',case when jsonb_typeof((p_details->'homeMethodDetails')->'bloomGrams') in ('number') then (p_details->'homeMethodDetails')->'bloomGrams' end,'bloomSeconds',case when jsonb_typeof((p_details->'homeMethodDetails')->'bloomSeconds') in ('number') then (p_details->'homeMethodDetails')->'bloomSeconds' end,'preinfusionSeconds',case when jsonb_typeof((p_details->'homeMethodDetails')->'preinfusionSeconds') in ('number') then (p_details->'homeMethodDetails')->'preinfusionSeconds' end,'pressureBars',case when jsonb_typeof((p_details->'homeMethodDetails')->'pressureBars') in ('number') then (p_details->'homeMethodDetails')->'pressureBars' end,'steepSeconds',case when jsonb_typeof((p_details->'homeMethodDetails')->'steepSeconds') in ('number') then (p_details->'homeMethodDetails')->'steepSeconds' end,'coldBrewSteepHours',case when jsonb_typeof((p_details->'homeMethodDetails')->'coldBrewSteepHours') in ('number') then (p_details->'homeMethodDetails')->'coldBrewSteepHours' end,'pressSeconds',case when jsonb_typeof((p_details->'homeMethodDetails')->'pressSeconds') in ('number') then (p_details->'homeMethodDetails')->'pressSeconds' end,'pressureFlowNotes',case when jsonb_typeof((p_details->'homeMethodDetails')->'pressureFlowNotes') in ('string') then (p_details->'homeMethodDetails')->'pressureFlowNotes' end,'pourPattern',case when jsonb_typeof((p_details->'homeMethodDetails')->'pourPattern') in ('string') then (p_details->'homeMethodDetails')->'pourPattern' end,'agitationNotes',case when jsonb_typeof((p_details->'homeMethodDetails')->'agitationNotes') in ('string') then (p_details->'homeMethodDetails')->'agitationNotes' end,'heatNotes',case when jsonb_typeof((p_details->'homeMethodDetails')->'heatNotes') in ('string') then (p_details->'homeMethodDetails')->'heatNotes' end,'customNotes',case when jsonb_typeof((p_details->'homeMethodDetails')->'customNotes') in ('string') then (p_details->'homeMethodDetails')->'customNotes' end)),
    'equipmentSnapshots',(select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('role',case when jsonb_typeof(item->'role') in ('string') then item->'role' end,'displayName',case when jsonb_typeof(item->'displayName') in ('string') then item->'displayName' end,'brand',case when jsonb_typeof(item->'brand') in ('string') then item->'brand' end,'model',case when jsonb_typeof(item->'model') in ('string') then item->'model' end))),'[]'::jsonb) from jsonb_array_elements(case when jsonb_typeof(p_details->'equipmentSnapshots')='array' then p_details->'equipmentSnapshots' else '[]'::jsonb end) item),
    'steps',(select coalesce(jsonb_agg(jsonb_strip_nulls(jsonb_build_object('id',case when jsonb_typeof(item->'id') in ('string') then item->'id' end,'instruction',case when jsonb_typeof(item->'instruction') in ('string') then item->'instruction' end,'durationSeconds',case when jsonb_typeof(item->'durationSeconds') in ('number') then item->'durationSeconds' end))),'[]'::jsonb) from jsonb_array_elements(case when jsonb_typeof(p_details->'steps')='array' then p_details->'steps' else '[]'::jsonb end) item)
  ));
$$;
revoke all on function private.recipe_shared_brew_details_v1(jsonb) from public,anon,authenticated;

create function private.recipe_screening_details_v1(p_details jsonb)
returns jsonb language sql immutable set search_path='' as $$
  with shared as(select private.recipe_shared_brew_details_v1(p_details) as details)
  select details || jsonb_build_object('steps',(
    select coalesce(jsonb_agg(step-'id'),'[]'::jsonb) from jsonb_array_elements(details->'steps') step
  )) from shared;
$$;
revoke all on function private.recipe_screening_details_v1(jsonb) from public,anon,authenticated;

-- Shared collections use the same revision and lease contract. Private
-- collections and private recipe versions do not enter provider snapshots.
create function private.refresh_collection_screening_v1(p_kind text,p_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare payload jsonb; actor uuid;
begin
  if p_kind='list' then
    select owner_id,case when visibility<>'private' and owner_id is not null then
      jsonb_build_object('text',concat_ws(E'\n',title,description),'images','[]'::jsonb) else null end
      into actor,payload from public.cafe_lists where id=p_id;
  elsif p_kind='list_item' then
    select coalesce(item.contributor_id,list.owner_id),case when list.visibility<>'private' and coalesce(item.contributor_id,list.owner_id) is not null then
      jsonb_build_object('text',coalesce(item.note,''),'images','[]'::jsonb) else null end
      into actor,payload from public.cafe_list_items item join public.cafe_lists list on list.id=item.list_id where item.id=p_id;
  elsif p_kind='list_comment' then
    select comment.user_id,case when list.visibility<>'private' and comment.deleted_at is null then
      jsonb_build_object('text',comment.body,'images','[]'::jsonb) else null end
      into actor,payload from public.cafe_list_comments comment join public.cafe_lists list on list.id=comment.list_id where comment.id=p_id;
  elsif p_kind='recommendation' then
    select sender_id,case when status<>'dismissed' then
      jsonb_build_object('text',coalesce(note,''),'images','[]'::jsonb) else null end
      into actor,payload from public.trusted_recommendations where id=p_id;
  elsif p_kind='recipe' then
    select identity.user_id,case when version.visibility in ('friends','everyone') then
      jsonb_build_object('text',concat_ws(E'\n',identity.name,version.version_label,
        coalesce(to_jsonb(version)->>'brew_method',to_jsonb(source)->>'brew_method'),
        coalesce(to_jsonb(version)->>'equipment',to_jsonb(source)->>'equipment'),
        private.recipe_screening_details_v1(version.brew_details)::text),'images','[]'::jsonb) else null end into actor,payload
      from public.recipe_versions version join public.recipe_identities identity on identity.id=version.recipe_identity_id
      left join public.visits source on source.id=(to_jsonb(version)->>'source_visit_id')::uuid where version.id=p_id;
  else raise exception 'invalid collection kind' using errcode='22023';
  end if;
  perform private.enqueue_screening_v1(p_kind,p_id,actor,payload);
end;
$$;

create function private.refresh_collection_screening_trigger_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare value jsonb:=case when tg_op='DELETE' then to_jsonb(old) else to_jsonb(new) end;
  target_id uuid:=(value->>'id')::uuid; child_id uuid;
begin
  if tg_table_name='cafe_lists' then
    perform private.refresh_collection_screening_v1('list',target_id);
    for child_id in select id from public.cafe_list_items where list_id=target_id loop perform private.refresh_collection_screening_v1('list_item',child_id);end loop;
    for child_id in select id from public.cafe_list_comments where list_id=target_id loop perform private.refresh_collection_screening_v1('list_comment',child_id);end loop;
  elsif tg_table_name='cafe_list_items' then perform private.refresh_collection_screening_v1('list_item',target_id);
  elsif tg_table_name='cafe_list_comments' then perform private.refresh_collection_screening_v1('list_comment',target_id);
  elsif tg_table_name='trusted_recommendations' then perform private.refresh_collection_screening_v1('recommendation',target_id);
  elsif tg_table_name='recipe_versions' then perform private.refresh_collection_screening_v1('recipe',target_id);
  elsif tg_table_name='recipe_identities' then
    for child_id in select id from public.recipe_versions where recipe_identity_id=target_id loop perform private.refresh_collection_screening_v1('recipe',child_id);end loop;
  end if;
  return null;
end;
$$;
create trigger screening_list after insert or update or delete on public.cafe_lists for each row execute function private.refresh_collection_screening_trigger_v1();
create trigger screening_list_item after insert or update or delete on public.cafe_list_items for each row execute function private.refresh_collection_screening_trigger_v1();
create trigger screening_list_comment after insert or update or delete on public.cafe_list_comments for each row execute function private.refresh_collection_screening_trigger_v1();
create trigger screening_recommendation after insert or update or delete on public.trusted_recommendations for each row execute function private.refresh_collection_screening_trigger_v1();
create trigger screening_recipe_version after insert or update or delete on public.recipe_versions for each row execute function private.refresh_collection_screening_trigger_v1();
create trigger screening_recipe_identity after insert or update or delete on public.recipe_identities for each row execute function private.refresh_collection_screening_trigger_v1();
revoke all on function private.refresh_collection_screening_v1(text,uuid),private.refresh_collection_screening_trigger_v1() from public,anon,authenticated;

select private.refresh_collection_screening_v1('list',id) from public.cafe_lists;
select private.refresh_collection_screening_v1('list_item',id) from public.cafe_list_items;
select private.refresh_collection_screening_v1('list_comment',id) from public.cafe_list_comments;
select private.refresh_collection_screening_v1('recipe',id) from public.recipe_versions;
select private.refresh_collection_screening_v1('recommendation',id) from public.trusted_recommendations;

create policy screening_lists_read on public.cafe_lists as restrictive for select to anon,authenticated
  using(owner_id=(select auth.uid()) or public.content_screening_approved_v1('list',id));
create policy screening_list_items_read on public.cafe_list_items as restrictive for select to anon,authenticated
  using(contributor_id=(select auth.uid()) or public.content_screening_approved_v1('list_item',id));
create policy screening_list_comments_read on public.cafe_list_comments as restrictive for select to anon,authenticated
  using(user_id=(select auth.uid()) or public.content_screening_approved_v1('list_comment',id));
create policy screening_recommendations_read on public.trusted_recommendations as restrictive for select to authenticated
  using(sender_id=(select auth.uid()) or public.content_screening_approved_v1('recommendation',id));

create or replace function private.can_view_cafe_list_as(p_list_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (exists(select 1 from public.cafe_lists where id=p_list_id and owner_id=p_viewer) or private.screening_approved_v1('list',p_list_id))
    and (private.is_public_cafe_list_as(p_list_id, p_viewer)
    or (
      p_viewer is not null
      and exists (
        select 1
        from public.cafe_lists list
        where list.id = p_list_id
          and (list.owner_id is null or not private.blocked_between(p_viewer, list.owner_id))
          and (
            list.owner_id = p_viewer
            or exists (
              select 1 from public.cafe_list_members member
              where member.list_id = list.id
                and member.user_id = p_viewer
                and member.invitation_status in ('pending', 'accepted')
            )
            or (
              list.visibility = 'friends'
              and list.owner_id is not null
              and private.can_view_user_as(list.owner_id, p_viewer)
              and private.confirmed_friends(p_viewer, list.owner_id)
            )
          )
      )
    ));
$$;

create or replace function private.can_view_cafe_list_items_as(p_list_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select (exists(select 1 from public.cafe_lists where id=p_list_id and owner_id=p_viewer) or private.screening_approved_v1('list',p_list_id))
    and (private.is_public_cafe_list_as(p_list_id, p_viewer)
    or (
      p_viewer is not null
      and exists (
        select 1
        from public.cafe_lists list
        where list.id = p_list_id
          and (list.owner_id is null or not private.blocked_between(p_viewer, list.owner_id))
          and (
            list.owner_id = p_viewer
            or exists (
              select 1 from public.cafe_list_members member
              where member.list_id = list.id
                and member.user_id = p_viewer
                and member.invitation_status = 'accepted'
            )
            or (
              list.visibility = 'friends'
              and list.owner_id is not null
              and private.can_view_user_as(list.owner_id, p_viewer)
              and private.confirmed_friends(p_viewer, list.owner_id)
            )
          )
      )
    ));
$$;

create or replace function private.is_public_cafe_list_as(p_list_id uuid, p_viewer uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.cafe_lists list
    where list.id = p_list_id
      and private.screening_approved_v1('list',list.id)
      and private.screening_approved_v1('user',list.owner_id)
      and list.visibility = 'public'
      and list.published_at is not null
      and list.system_kind is null
      and private.is_live_account_as(list.owner_id)
      and not private.has_active_moderation_action(
        'user', list.owner_id, array['account_suspended']::text[]
      )
      and (
        p_viewer is null
        or (
          private.is_live_account_as(p_viewer)
          and not private.blocked_between(p_viewer, list.owner_id)
        )
      )
  );
$$;

create or replace function private.public_cafe_list_profile_json_v1(
  p_subject uuid,
  p_viewer uuid
)
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  select case
    when not private.screening_approved_v1('user',p_subject)
      or not private.is_live_account_as(p_subject)
      or private.has_active_moderation_action(
        'user', p_subject, array['account_suspended']::text[]
      )
      or (p_viewer is not null and private.blocked_between(p_viewer, p_subject))
      then jsonb_build_object('identity_state', 'hidden')
    else coalesce((
      select jsonb_build_object(
        'identity_state', 'visible',
        'user_id', profile.id,
        'display_name', profile.display_name,
        'username', profile.username,
        'avatar_url', profile.avatar_url
      )
      from public.users profile where profile.id = p_subject
    ), jsonb_build_object('identity_state', 'departed'))
  end;
$$;

create or replace function private.public_cafe_list_json_v1(
  p_list_id uuid,
  p_viewer uuid,
  p_include_items boolean default false,
  p_include_comments boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  result jsonb;
begin
  if not private.is_public_cafe_list_as(p_list_id, p_viewer) then return null; end if;

  select jsonb_build_object(
    'id', list.id,
    'title', list.title,
    'description', list.description,
    'visibility', list.visibility,
    'published_at', list.published_at,
    'updated_at', list.updated_at,
    'comments_enabled', list.comments_enabled,
    'creator', private.public_cafe_list_profile_json_v1(list.owner_id, p_viewer),
    'contributors', coalesce((
      select jsonb_agg(profile order by profile->>'display_name', profile->>'username')
      from (
        select distinct private.public_cafe_list_profile_json_v1(item.contributor_id, p_viewer) profile
        from public.cafe_list_items item
        where item.list_id = list.id and private.screening_approved_v1('list_item',item.id) and item.contributor_id <> list.owner_id
      ) contributor_rows
      where profile->>'identity_state' = 'visible'
    ), '[]'::jsonb),
    'cafe_count', (select count(*) from public.cafe_list_items item where item.list_id = list.id and private.screening_approved_v1('list_item',item.id)),
    'follower_count', (select count(*) from public.cafe_list_follows follow where follow.list_id = list.id),
    'is_following', coalesce((
      select true from public.cafe_list_follows follow
      where follow.list_id = list.id and follow.user_id = p_viewer
    ), false),
    'can_comment', p_viewer is not null and list.comments_enabled
      and private.can_socially_mutate_as(p_viewer),
    'slug', (
      select link.slug from public.cafe_list_share_links link
      where link.list_id = list.id and link.revoked_at is null
      order by link.created_at desc limit 1
    ),
    'inspired_by', case when list.source_list_id is null then null else (
      select jsonb_build_object(
        'list_id', source.id,
        'title', source.title,
        'creator', private.public_cafe_list_profile_json_v1(source.owner_id, p_viewer)
      )
      from public.cafe_lists source
      where source.id = list.source_list_id
        and private.is_public_cafe_list_as(source.id, p_viewer)
    ) end,
    'items', case when p_include_items then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', item.id,
        'cafe_id', cafe.id,
        'position', item.position,
        'caption', item.note,
        'cafe_name', cafe.name,
        'cafe_address', cafe.address,
        'cafe_city', cafe.city,
        'latitude', cafe.latitude,
        'longitude', cafe.longitude,
        'apple_maps_place_id', cafe.apple_maps_place_id,
        'apple_place_id', cafe.apple_place_id,
        'website_url', cafe.website_url,
        'photo_url', photo.poster_photo_url,
        'contributor', private.public_cafe_list_profile_json_v1(item.contributor_id, p_viewer)
      ) order by item.position, item.created_at, item.id)
      from public.cafe_list_items item
      join public.cafes cafe on cafe.id = item.cafe_id
      left join lateral (
        select visit.poster_photo_url
        from public.visits visit
        where visit.cafe_id = item.cafe_id
          and private.is_public_visit_discoverable_v3(visit.id)
          and visit.visibility = 'everyone'
          and visit.upload_state = 'complete'
          and nullif(btrim(visit.poster_photo_url), '') is not null
          and not private.has_active_moderation_action(
            'visit', visit.id, array['content_hidden']::text[]
          )
          and private.is_live_account_as(visit.user_id)
        order by visit.created_at desc, visit.id desc limit 1
      ) photo on true
      where item.list_id = list.id and private.screening_approved_v1('list_item',item.id)
    ), '[]'::jsonb) else null end,
    'comments', case when p_include_comments then coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', comment.id,
        'body', comment.body,
        'created_at', comment.created_at,
        'author', private.public_cafe_list_profile_json_v1(comment.user_id, p_viewer),
        'can_delete', p_viewer = comment.user_id or p_viewer = list.owner_id
      ) order by comment.created_at, comment.id)
      from public.cafe_list_comments comment
      where comment.list_id = list.id
        and private.screening_approved_v1('list_comment',comment.id)
        and comment.deleted_at is null
        and not private.has_active_moderation_action(
          'cafe_list_comment', comment.id, array['content_hidden']::text[]
        )
        and (p_viewer is null or not private.blocked_between(p_viewer, comment.user_id))
        and private.is_live_account_as(comment.user_id)
    ), '[]'::jsonb) else null end
  ) into result
  from public.cafe_lists list
  where list.id = p_list_id;

  return result;
end;
$$;

create or replace function public.get_cafe_list_v2(p_list_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  summary jsonb;
  item_rows jsonb := '[]'::jsonb;
  member_rows jsonb := '[]'::jsonb;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  summary := private.cafe_list_summary_json_v2(p_list_id, actor);
  if summary is null then
    raise exception 'cafe list unavailable' using errcode = '42501';
  end if;

  if private.can_view_cafe_list_items_as(p_list_id, actor) then
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', item.id,
      'list_id', item.list_id,
      'cafe_id', cafe.id,
      'position', item.position,
      'note', item.note,
      'created_at', item.created_at,
      'cafe_name', cafe.name,
      'cafe_address', cafe.address,
      'cafe_city', cafe.city,
      'latitude', cafe.latitude,
      'longitude', cafe.longitude,
      'apple_place_id', cafe.apple_place_id,
      'website_url', cafe.website_url,
      'photo_url', photo.poster_photo_url,
      'is_favorite', coalesce(saved.is_favorite, false),
      'want_to_try', coalesce(saved.want_to_try, false),
      'saved_state', case
        when coalesce(saved.is_favorite, false) and coalesce(saved.want_to_try, false) then 'favorite_and_want_to_try'
        when coalesce(saved.is_favorite, false) then 'favorite'
        when coalesce(saved.want_to_try, false) then 'want_to_try'
        else 'none'
      end,
      'contributor', private.cafe_list_profile_json_v2(item.contributor_id, actor)
    ) order by item.position, item.created_at, item.id), '[]'::jsonb)
    into item_rows
    from public.cafe_list_items item
    join public.cafes cafe on cafe.id = item.cafe_id
    left join public.user_cafe_states saved
      on saved.user_id = actor and saved.cafe_id = item.cafe_id
    left join lateral (
      select visit.poster_photo_url
      from public.visits visit
      where visit.cafe_id = item.cafe_id
        and nullif(btrim(visit.poster_photo_url), '') is not null
        and private.can_view_visit_as(visit.id, actor)
      order by
        (visit.user_id = actor) desc,
        visit.created_at desc,
        visit.id desc
      limit 1
    ) photo on true
    where item.list_id = p_list_id and (item.contributor_id=actor or private.screening_approved_v1('list_item',item.id));
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'role', member.role,
    'invitation_status', member.invitation_status,
    'created_at', member.created_at,
    'updated_at', member.updated_at,
    'accepted_at', member.accepted_at,
    'responded_at', member.responded_at,
    'person', private.cafe_list_profile_json_v2(member.user_id, actor),
    'inviter', private.cafe_list_profile_json_v2(member.invited_by, actor),
    'can_change_role', list.owner_id = actor
      and member.user_id <> actor
      and member.invitation_status in ('pending', 'accepted')
      and private.can_manage_cafe_list_as(list.id, actor),
    'can_remove', list.owner_id = actor
      and member.user_id <> actor
      and member.invitation_status in ('pending', 'accepted')
      and private.can_manage_cafe_list_as(list.id, actor)
  ) order by
    case member.invitation_status when 'accepted' then 0 when 'pending' then 1 else 2 end,
    coalesce(member.accepted_at, member.created_at),
    member.user_id), '[]'::jsonb)
  into member_rows
  from public.cafe_list_members member
  join public.cafe_lists list on list.id = member.list_id
  where member.list_id = p_list_id
    and (
      (list.owner_id = actor and member.invitation_status in ('pending', 'accepted'))
      or member.invitation_status = 'accepted'
      or (member.user_id = actor and member.invitation_status = 'pending')
    );

  return summary || jsonb_build_object(
    'items', item_rows,
    'members', member_rows
  );
end;
$$;

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
      and (identity.user_id=p_viewer or private.screening_approved_v1('recipe',version.id))
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
      and (identity.user_id=p_viewer or private.screening_approved_v1('recipe',version.id))
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
            and private.screening_approved_v1('recipe',version.id)
            and recommendation.target_kind = 'recipe'
            and recommendation.recipient_id = p_viewer
            and recommendation.status <> 'dismissed'
            and not private.blocked_between(recommendation.sender_id, recommendation.recipient_id)
        )
      )
  );
$$;

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
language sql
stable
security definer
set search_path = ''
as $$
  select
    recommendation.id,
    identity.id,
    version.id,
    identity.name,
    version.version_number,
    version.version_label,
    private.recipe_shared_brew_details_v1(version.brew_details),
    recommendation.sender_id,
    recommendation.note,
    recommendation.created_at
  from public.trusted_recommendations recommendation
  join public.recipe_versions version
    on version.id = recommendation.target_recipe_version_id
  join public.recipe_identities identity
    on identity.id = version.recipe_identity_id
  where recommendation.target_kind = 'recipe'
    and private.screening_approved_v1('recommendation',recommendation.id)
    and recommendation.recipient_id = (select auth.uid())
    and recommendation.status <> 'dismissed'
    and private.can_project_recipe_version_as(
      version.id,
      (select auth.uid())
    )
  order by recommendation.created_at desc, recommendation.id desc;
$$;

create or replace function public.copy_public_cafe_list_v1(p_list_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  source public.cafe_lists%rowtype;
  copied public.cafe_lists%rowtype;
begin
  if actor is null then raise exception 'authentication required' using errcode = '28000'; end if;
  if not private.can_socially_mutate_as(actor)
     or not private.is_public_cafe_list_as(p_list_id, actor) then
    raise exception 'public cafe list unavailable' using errcode = '42501';
  end if;
  select * into source from public.cafe_lists where id = p_list_id;
  insert into public.cafe_lists (
    owner_id, title, description, visibility, comments_enabled, source_list_id
  ) values (
    actor, left(source.title || ' — Copy', 80), source.description,
    'private', true, source.id
  ) returning * into copied;

  insert into public.cafe_list_items (
    list_id, cafe_id, position, contributor_id, note
  )
  select copied.id, item.cafe_id, item.position, actor, item.note
  from public.cafe_list_items item
  where item.list_id = source.id and private.screening_approved_v1('list_item',item.id)
  order by item.position, item.created_at, item.id;

  return public.get_cafe_list_v2(copied.id);
end;
$$;

create or replace function public.get_recipe_projection_v1(p_recipe_version_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  actor uuid := auth.uid();
  target record;
begin
  if actor is null then
    raise exception 'authentication required' using errcode = '28000';
  end if;

  select
    version.id,
    version.recipe_identity_id,
    version.version_number,
    version.version_label,
    version.brew_details,
    coalesce(version.brew_method, source_visit.brew_method) brew_method,
    coalesce(version.equipment, source_visit.equipment) equipment,
    version.source_visit_id,
    version.visibility,
    version.source_kind,
    version.redistribution_allowed,
    version.source_recipe_version_id,
    version.created_at,
    identity.user_id owner_id,
    identity.name recipe_name,
    profile.display_name,
    profile.username,
    profile.avatar_url
  into target
  from public.recipe_versions version
  join public.recipe_identities identity
    on identity.id = version.recipe_identity_id
  join public.users profile on profile.id = identity.user_id
  left join public.visits source_visit on source_visit.id = version.source_visit_id
  where version.id = p_recipe_version_id;

  if not found
     or not private.can_project_recipe_version_as(p_recipe_version_id, actor) then
    return null;
  end if;

  return jsonb_strip_nulls(jsonb_build_object(
    'recipe_identity_id', target.recipe_identity_id,
    'recipe_version_id', target.id,
    'recipe_name', target.recipe_name,
    'version_number', target.version_number,
    'version_label', target.version_label,
    'visibility', target.visibility,
    'source_kind', target.source_kind,
    'source_recipe_version_id', case
      when target.source_recipe_version_id is null
        or private.can_project_recipe_version_as(target.source_recipe_version_id, actor)
      then target.source_recipe_version_id
    end,
    'owner', jsonb_build_object(
      'id', target.owner_id,
      'display_name', target.display_name,
      'username', target.username,
      'avatar_url', target.avatar_url
    ),
    'brew_method', target.brew_method,
    'equipment', target.equipment,
    'brew_details', private.recipe_shared_brew_details_v1(target.brew_details),
    'can_save_and_adapt',
      target.visibility = 'everyone'
      and target.source_kind in ('original', 'adapted')
      and target.redistribution_allowed,
    'created_at', target.created_at
  ));
end;
$$;
