begin;

create temp table taste_graph_rls_fixture as
select signal.id as signal_id, signal.user_id
from public.taste_signals signal
order by signal.support_count desc
limit 1;
grant select on taste_graph_rls_fixture to authenticated;

do $$ begin
  if not exists (select 1 from taste_graph_rls_fixture) then
    raise exception 'taste graph RLS contract requires one signal';
  end if;
end $$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select user_id from taste_graph_rls_fixture),
    'role', 'authenticated'
  )::text,
  true
);

do $$ begin
  if not exists (
    select 1 from public.taste_signals
    where id = (select signal_id from taste_graph_rls_fixture)
  ) then
    raise exception 'owner cannot read their taste signal';
  end if;
end $$;

select set_config(
  'request.jwt.claims',
  jsonb_build_object('sub', gen_random_uuid(), 'role', 'authenticated')::text,
  true
);

do $$ begin
  if exists (
    select 1 from public.taste_signals
    where id = (select signal_id from taste_graph_rls_fixture)
  ) then
    raise exception 'another user can read private taste evidence';
  end if;

  begin
    perform public.set_taste_signal_owner_state(
      (select signal_id from taste_graph_rls_fixture),
      'dismissed',
      null
    );
    raise exception 'another user changed an owner taste signal';
  exception when insufficient_privilege then
    null;
  end;
end $$;

rollback;

select 'taste_graph_rls_passed' as result;
