begin;

create temp table visit_insert_test_user as
select id as user_id
from public.users
order by created_at
limit 1;
grant select on visit_insert_test_user to authenticated;

do $$ begin
  if not exists (select 1 from visit_insert_test_user) then
    raise exception 'visit insert contract requires one existing user';
  end if;
end $$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select user_id from visit_insert_test_user),
    'role', 'authenticated'
  )::text,
  true
);

create temp table inserted_visit (
  id uuid,
  user_id uuid,
  notes text,
  visibility text,
  upload_state text
);

with created as (
  insert into public.visits (
  id,
  user_id,
  drink_type,
  drink_subtype,
  caption,
  notes,
  visibility,
  upload_state,
  ratings,
  overall_score,
  context_type,
  location_name,
  brew_details
)
values (
  gen_random_uuid(),
  (select user_id from visit_insert_test_user),
  'Coffee',
  'Insert returning contract sip',
  '',
  'Owner-only contract note',
  'private',
  'uploading',
  '{"Overall":4}'::jsonb,
  4,
  'home',
  'Home',
  '{}'::jsonb
  )
  returning id, user_id, notes, visibility, upload_state
)
insert into inserted_visit
select * from created;

do $$ begin
  if (select count(*) from inserted_visit) <> 1 then
    raise exception 'owner insert returning did not return exactly one visit';
  end if;
  if (select notes from inserted_visit) is not null then
    raise exception 'legacy private note leaked onto the social visit row';
  end if;
  if not exists (
    select 1
    from public.visit_private_notes private_note
    join inserted_visit visit on visit.id = private_note.visit_id
    where private_note.user_id = visit.user_id
      and private_note.note = 'Owner-only contract note'
  ) then raise exception 'legacy private note was not routed to owner-only storage'; end if;
end $$;

reset role;
rollback;

select 'visit_insert_contract_passed' as result;
