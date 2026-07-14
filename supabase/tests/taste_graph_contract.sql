begin;

create temp table taste_graph_fixture as
select id as user_id
from auth.users
order by created_at
limit 1;
grant select on taste_graph_fixture to authenticated;

do $$ begin
  if not exists (select 1 from taste_graph_fixture) then
    raise exception 'taste graph contract requires one auth user';
  end if;
end $$;

create temp table taste_graph_visits (visit_id uuid primary key);
grant select on taste_graph_visits to authenticated;

with inserted as (
  insert into public.visits (
    user_id, drink_type, drink_subtype, caption, visibility, ratings,
    category_scores, overall_score, context_type, location_name
  )
  select
    fixture.user_id,
    'coffee',
    'Phase 3 contract latte ' || series.number,
    '',
    'private',
    '{}'::jsonb,
    jsonb_build_array(
      jsonb_build_object('name', 'Phase 3 Contract Clarity', 'score', 3 + series.number * 0.5, 'weight', 1),
      case when series.number <= 2
        then jsonb_build_object('name', 'Phase 3 Contract Freshness', 'score', 4, 'weight', 1)
        else jsonb_build_object('name', 'Overall', 'score', 4, 'weight', 1)
      end
    ),
    4,
    'Home',
    'Home'
  from taste_graph_fixture fixture
  cross join (values (1), (2), (3)) series(number)
  returning id
)
insert into taste_graph_visits select id from inserted;

update public.visit_drink_analyses analysis
set processing_status = 'complete',
    preference_signals = '["phase_3_contract_fruit"]'::jsonb,
    parser_version = 'contract-test',
    confidence = 0.9
where analysis.visit_id in (select visit_id from taste_graph_visits);

do $$ begin
  if not exists (
    select 1 from public.taste_signals
    where user_id = (select user_id from taste_graph_fixture)
      and signal_type = 'sensory_evaluation'
      and attribute = 'phase_3_contract_clarity'
      and support_count = 3
      and cardinality(evidence_visit_ids) = 3
      and average_score = 4
  ) then
    raise exception 'three-entry sensory signal was not calculated correctly';
  end if;

  if not exists (
    select 1 from public.taste_signals
    where user_id = (select user_id from taste_graph_fixture)
      and signal_type = 'sensory_evaluation'
      and attribute = 'phase_3_contract_freshness'
      and support_count = 2
  ) then
    raise exception 'sub-threshold evidence was not retained for future growth';
  end if;

  if not exists (
    select 1 from public.taste_signals
    where user_id = (select user_id from taste_graph_fixture)
      and signal_type = 'order_preference'
      and attribute = 'phase_3_contract_fruit'
      and support_count = 3
      and average_score is null
  ) then
    raise exception 'order evidence was not kept separate from sensory evaluation';
  end if;

  if exists (
    select 1 from public.taste_signals
    where user_id = (select user_id from taste_graph_fixture)
      and signal_type = 'sensory_evaluation'
      and attribute = 'phase_3_contract_fruit'
  ) then
    raise exception 'order preference was incorrectly presented as a sensory claim';
  end if;
end $$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select user_id from taste_graph_fixture),
    'role', 'authenticated'
  )::text,
  true
);

select public.set_taste_signal_owner_state(
  (
    select id from public.taste_signals
    where attribute = 'phase_3_contract_clarity'
      and user_id = (select user_id from taste_graph_fixture)
  ),
  'corrected',
  'Clarity that matters to me'
);

do $$ begin
  if not exists (
    select 1 from public.taste_signals
    where attribute = 'phase_3_contract_clarity'
      and owner_state = 'corrected'
      and owner_label = 'Clarity that matters to me'
  ) then
    raise exception 'owner correction was not retained';
  end if;
end $$;

reset role;

delete from public.visits
where id = (select visit_id from taste_graph_visits order by visit_id limit 1);

do $$ begin
  if not exists (
    select 1 from public.taste_signals
    where user_id = (select user_id from taste_graph_fixture)
      and attribute = 'phase_3_contract_clarity'
      and support_count = 2
      and owner_state = 'corrected'
      and owner_label = 'Clarity that matters to me'
  ) then
    raise exception 'deleted visit did not recalculate evidence while preserving the owner correction';
  end if;
end $$;

rollback;

select 'taste_graph_contract_passed' as result;
