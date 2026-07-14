-- Release-data cleanup candidate report (READ ONLY)
--
-- Before running, replace the commented examples below with an explicitly
-- reviewed QA-account allowlist and known smoke-test visit IDs. Do not add
-- caption, cafe-name, username, or date-pattern heuristics: they can capture
-- legitimate customer journals.

with
qa_accounts(user_id) as (
  values
    -- ('00000000-0000-0000-0000-000000000000'::uuid)
    (null::uuid)
),
known_smoke_visits(id) as (
  values
    -- ('00000000-0000-0000-0000-000000000000'::uuid)
    (null::uuid)
),
candidate_visits as (
  select v.id, v.user_id, v.cafe_id, v.created_at, v.caption, v.upload_state
  from public.visits v
  where v.user_id in (select user_id from qa_accounts where user_id is not null)
     or v.id in (select id from known_smoke_visits where id is not null)
)
select
  cv.id as visit_id,
  cv.user_id,
  cv.cafe_id,
  cv.created_at,
  cv.upload_state,
  cv.caption,
  coalesce(array_agg(vp.photo_url order by vp.sort_order) filter (where vp.id is not null), '{}') as photo_urls,
  coalesce(count(vp.id), 0) as photo_count
from candidate_visits cv
left join public.visit_photos vp on vp.visit_id = cv.id
group by cv.id, cv.user_id, cv.cafe_id, cv.created_at, cv.upload_state, cv.caption
order by cv.created_at desc;
