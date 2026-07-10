-- Approved release-data cleanup (DESTRUCTIVE; production-admin use only)
--
-- 1. Paste only visit IDs approved from report.sql into approved_visits.
-- 2. Verify the SELECT immediately below returns exactly the approved IDs.
-- 3. Run the transaction. It removes visit-photo storage objects using the
--    explicit (owner, visit) path contract, then deletes the visits.
--
-- This intentionally never infers eligibility from captions, cafe names, or
-- other customer-visible text. Profile media is not deleted by this script;
-- use delete-account for an explicitly approved whole-account removal.

begin;

create temporary table approved_visits (
  visit_id uuid primary key
) on commit drop;

-- insert into approved_visits (visit_id) values
--   ('00000000-0000-0000-0000-000000000000'::uuid);

select v.id, v.user_id, v.created_at, v.caption
from public.visits v
join approved_visits a on a.visit_id = v.id
order by v.created_at desc;

-- Exact visit-photo object paths are owner-id/visit-id/file.jpg.
delete from storage.objects object
using public.visits v, approved_visits a
where object.bucket_id = 'visit-photos'
  and v.id = a.visit_id
  and object.name like lower(v.user_id::text) || '/' || lower(v.id::text) || '/%';

delete from public.visits v
using approved_visits a
where v.id = a.visit_id;

commit;
