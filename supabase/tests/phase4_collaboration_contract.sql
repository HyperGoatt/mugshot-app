begin;

create temp table phase4_users as
select id, row_number() over(order by id) n
from (select id from public.users order by id limit 3) users;
grant select on phase4_users to authenticated;

do $$ begin
  if (select count(*) from phase4_users) < 3 then
    raise exception 'phase 4 suite requires three existing users';
  end if;
  if (select count(*) from public.cafes) < 2 then
    raise exception 'phase 4 suite requires two existing cafes';
  end if;
end $$;

delete from public.user_blocks
where blocker_id in (select id from phase4_users) and blocked_id in (select id from phase4_users);
delete from public.friends
where user_id in (select id from phase4_users) and friend_user_id in (select id from phase4_users);
delete from public.friend_requests
where from_user_id in (select id from phase4_users) and to_user_id in (select id from phase4_users);

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from phase4_users where n=1), 'role', 'authenticated'
)::text, true);
select public.send_friend_request((select id from phase4_users where n=2));

select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from phase4_users where n=2), 'role', 'authenticated'
)::text, true);
select public.respond_friend_request((
  select id from public.friend_requests
  where from_user_id=(select id from phase4_users where n=1)
    and to_user_id=(select id from phase4_users where n=2)
    and status='pending'
), true);

reset role;
select set_config('request.jwt.claims', '{}'::jsonb::text, true);
create temp table phase4_targets(visit_id uuid, private_visit_id uuid, recipe_version_id uuid);
grant select on phase4_targets to authenticated;
do $$
declare shareable uuid; private_target uuid; identity_id uuid; version_id uuid; owner_id uuid;
begin
  owner_id := (select id from phase4_users where n=1);
  insert into public.visits(user_id,cafe_id,drink_type,drink_subtype,caption,visibility,overall_score,context_type)
  values(owner_id,(select id from public.cafes order by id limit 1),'Coffee','Phase 4 shareable','Only explicit social content','everyone',4,'Cafe')
  returning id into shareable;
  insert into public.visits(user_id,cafe_id,drink_type,drink_subtype,caption,visibility,overall_score,context_type)
  values(owner_id,(select id from public.cafes order by id limit 1),'Coffee','Phase 4 private','Private journal entry','private',4,'Cafe')
  returning id into private_target;
  insert into public.recipe_identities(user_id,name) values(owner_id,'Phase 4 recipe') returning id into identity_id;
  insert into public.recipe_versions(recipe_identity_id,version_number,brew_details)
  values(identity_id,1,'{"doseGrams":18,"privateNotes":"must never be copied"}'::jsonb)
  returning id into version_id;
  insert into phase4_targets values(shareable,private_target,version_id);
end $$;

set local role authenticated;
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from phase4_users where n=1), 'role', 'authenticated'
)::text, true);

create temp table phase4_list as
select (public.create_cafe_list('Phase 4 contract', 'transactional test', 'invited')).id;
grant select on phase4_list to authenticated;

select public.add_cafe_list_item_v2(
  (select id from phase4_list),
  (select id from public.cafes order by id limit 1),
  'First stop'
);
select public.invite_cafe_list_member(
  (select id from phase4_list),
  (select id from phase4_users where n=2),
  'editor'
);

select public.send_trusted_recommendation(
  (select id from phase4_users where n=2), 'visit', (select visit_id from phase4_targets), 'Try this sip'
);
select public.send_trusted_recommendation(
  (select id from phase4_users where n=2), 'recipe', (select recipe_version_id from phase4_targets), 'Brew this one'
);
do $$ begin
  begin
    perform public.send_trusted_recommendation(
      (select id from phase4_users where n=2), 'visit', (select private_visit_id from phase4_targets), null
    );
    raise exception 'private visit recommendation unexpectedly succeeded';
  exception when sqlstate '42501' then null;
  end;
end $$;

-- A stranger receives neither list metadata nor contents.
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from phase4_users where n=3), 'role', 'authenticated'
)::text, true);
do $$ begin
  if exists(select 1 from public.cafe_lists where id=(select id from phase4_list)) then
    raise exception 'stranger read invited list metadata';
  end if;
  if exists(select 1 from public.cafe_list_items where list_id=(select id from phase4_list)) then
    raise exception 'stranger read invited list contents';
  end if;
end $$;

-- A pending invitee can inspect enough metadata to decide, but not contents.
select set_config('request.jwt.claims', jsonb_build_object(
  'sub', (select id from phase4_users where n=2), 'role', 'authenticated'
)::text, true);
do $$ begin
  if not exists(select 1 from public.cafe_lists where id=(select id from phase4_list)) then
    raise exception 'pending invitee could not read list metadata';
  end if;
  if exists(select 1 from public.cafe_list_items where list_id=(select id from phase4_list)) then
    raise exception 'pending invitee read invited-only contents';
  end if;
end $$;

select public.respond_cafe_list_invitation((select id from phase4_list), true);
do $$ begin
  if not exists(select 1 from public.cafe_list_items where list_id=(select id from phase4_list)) then
    raise exception 'accepted collaborator could not read list contents';
  end if;
end $$;

do $$ begin
  if (select count(*) from public.trusted_recommendations
      where recipient_id=(select id from phase4_users where n=2)) <> 2 then
    raise exception 'recipient did not receive exact trusted recommendations';
  end if;
  if not exists(
    select 1 from public.list_shared_recipes()
    where recipe_version_id=(select recipe_version_id from phase4_targets)
  ) then raise exception 'sanitized shared recipe was unavailable'; end if;
  if exists(
    select 1 from public.list_shared_recipes()
    where brew_details ?| array['privateNotes','private_notes','notes','caption','socialCaption']
  ) then raise exception 'shared recipe exposed an owner-only field'; end if;
end $$;

select public.toggle_visit_reaction((select visit_id from phase4_targets),'great_find');
do $$ begin
  if not exists(
    select 1 from public.visit_reactions
    where visit_id=(select visit_id from phase4_targets)
      and user_id=(select id from phase4_users where n=2)
      and reaction='great_find'
  ) then raise exception 'caller-bound reaction was not saved'; end if;
end $$;

-- Accepted editors can add, and contributor attribution remains caller-bound.
select public.add_cafe_list_item_v2(
  (select id from phase4_list),
  (select id from public.cafes order by id offset 1 limit 1),
  null
);
do $$ begin
  if not exists (
    select 1
    from jsonb_array_elements(
      public.get_cafe_list_v2((select id from phase4_list)) -> 'items'
    ) item
    where item #>> '{contributor,user_id}' =
      (select id::text from phase4_users where n=2)
  ) then raise exception 'editor contributor attribution was not caller-bound'; end if;
end $$;

select public.move_cafe_list_item_v2(
  (select id from public.cafe_list_items
   where list_id=(select id from phase4_list)
     and cafe_id=(select id from public.cafes order by id offset 1 limit 1)),
  0
);
do $$ begin
  if not exists(
    select 1 from public.cafe_list_items
    where list_id=(select id from phase4_list)
      and cafe_id=(select id from public.cafes order by id offset 1 limit 1)
      and position=0
  ) then raise exception 'editor could not reorder list items'; end if;
  if (select count(distinct position) from public.cafe_list_items
      where list_id=(select id from phase4_list)) <> 2 then
    raise exception 'reordering produced duplicate positions';
  end if;
end $$;

-- Direct mutation stays closed; all writes use caller-bound RPCs.
do $$ begin
  begin
    insert into public.visit_reactions(visit_id,user_id,reaction)
    values(gen_random_uuid(),(select id from phase4_users where n=2),'cozy');
    raise exception 'direct reaction insert unexpectedly succeeded';
  exception when insufficient_privilege or foreign_key_violation then null;
  end;
end $$;

-- Compatibility never ranks friends and executes only for a confirmed pair.
select * from public.friend_compatibility((select id from phase4_users where n=1));
do $$ begin
  begin
    perform * from public.friend_compatibility((select id from phase4_users where n=3));
    raise exception 'stranger compatibility unexpectedly succeeded';
  exception when sqlstate '42501' then null;
  end;
end $$;

reset role;
rollback;

select 'phase4_collaboration_contract_passed' as result;
