begin;

create temp table drink_analysis_test_visit as
select visit.id as visit_id, visit.user_id
from public.visits visit
order by visit.created_at desc
limit 1;
grant select on drink_analysis_test_visit to authenticated;

do $$ begin
  if not exists (select 1 from drink_analysis_test_visit) then
    raise exception 'drink-analysis contract requires one existing visit';
  end if;
end $$;

set local role authenticated;
select set_config(
  'request.jwt.claims',
  jsonb_build_object(
    'sub', (select user_id from drink_analysis_test_visit),
    'role', 'authenticated'
  )::text,
  true
);

do $$ begin
  if not exists (
    select 1 from public.visit_drink_analyses
    where visit_id = (select visit_id from drink_analysis_test_visit)
  ) then raise exception 'owner cannot read seeded drink analysis'; end if;
end $$;

select public.request_visit_drink_analysis_correction(
  (select visit_id from drink_analysis_test_visit),
  '{"serving_volume_ml":355,"espresso_shot_count":2}'::jsonb
);
select public.request_visit_drink_analysis_correction(
  (select visit_id from drink_analysis_test_visit),
  '{"serving_volume_ml":355,"espresso_shot_count":2}'::jsonb
);

do $$ begin
  if (select processing_status from public.visit_drink_analyses
      where visit_id=(select visit_id from drink_analysis_test_visit)) <> 'pending' then
    raise exception 'correction did not schedule deterministic recomputation';
  end if;
  if (select user_overrides from public.visit_drink_analyses
      where visit_id=(select visit_id from drink_analysis_test_visit))
      <> '{"serving_volume_ml":355,"espresso_shot_count":2}'::jsonb then
    raise exception 'repeated correction was not idempotent';
  end if;
  begin
    perform public.request_visit_drink_analysis_correction(
      (select visit_id from drink_analysis_test_visit),
      '{"estimated_caffeine_mg":999}'::jsonb
    );
    raise exception 'client supplied caffeine override unexpectedly succeeded';
  exception when sqlstate '22023' then null;
  end;
end $$;

reset role;
rollback;

select 'drink_analysis_contract_passed' as result;
