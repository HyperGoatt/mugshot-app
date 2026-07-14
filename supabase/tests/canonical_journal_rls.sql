begin;

create temp table canonical_journal_fixture as
select id as visit_id, user_id
from public.visits
order by created_at desc
limit 1;
grant select on canonical_journal_fixture to authenticated;

do $$ begin
  if not exists (select 1 from canonical_journal_fixture) then
    raise exception 'canonical journal RLS contract requires one existing visit';
  end if;
end $$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select user_id from canonical_journal_fixture),
    'role', 'authenticated'
  )::text,
  true
);

insert into public.visit_bookmarks (user_id, visit_id)
select user_id, visit_id from canonical_journal_fixture
on conflict (user_id, visit_id) do nothing;

do $$ begin
  if not exists (
    select 1 from public.visit_bookmarks
    where visit_id = (select visit_id from canonical_journal_fixture)
  ) then
    raise exception 'owner cannot read or create a journal bookmark';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text,
  true
);

do $$ begin
  if exists (
    select 1 from public.visit_bookmarks
    where visit_id = (select visit_id from canonical_journal_fixture)
  ) then
    raise exception 'another user can read an owner journal bookmark';
  end if;

  begin
    insert into public.visit_bookmarks (user_id, visit_id)
    values (
      auth.uid(),
      (select visit_id from canonical_journal_fixture)
    );
    raise exception 'another user created a bookmark for an unowned visit';
  exception when insufficient_privilege then
    null;
  end;
end $$;

rollback;

select 'canonical_journal_rls_passed' as result;
