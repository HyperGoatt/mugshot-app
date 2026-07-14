-- Phase 2A.5 manual Supabase quarantine
--
-- Purpose:
--   Remove the unsafe public.visits insert trigger that calls the
--   notify-friends-on-new-visit Edge Function with an embedded bearer
--   credential in database metadata.
--
-- Scope:
--   Run manually only after rotating/revoking the embedded credential.
--   This does not delete data and does not change public.visits rows.
--   It removes push/social side effects from visit inserts so Phase 2B
--   can create no-photo visits safely.
--
-- Do not add secrets to this file.

begin;

-- 1. Preflight: confirm the exact trigger exists.
select
  trigger_schema,
  event_object_schema,
  event_object_table,
  trigger_name,
  action_timing,
  event_manipulation
from information_schema.triggers
where event_object_schema = 'public'
  and event_object_table = 'visits'
  and trigger_name = 'notify-friends-on-new-visit';

-- 2. Quarantine: remove the unsafe trigger definition from DB metadata.
drop trigger if exists "notify-friends-on-new-visit" on public.visits;

-- 3. Verification: this should return zero rows.
select
  trigger_schema,
  event_object_schema,
  event_object_table,
  trigger_name,
  action_timing,
  event_manipulation
from information_schema.triggers
where event_object_schema = 'public'
  and event_object_table = 'visits'
  and trigger_name = 'notify-friends-on-new-visit';

commit;

-- Post-run checklist:
-- 1. Confirm the rotated/revoked credential cannot be used.
-- 2. Confirm a public.visits insert no longer invokes notify-friends-on-new-visit.
-- 3. Keep notify-friends-on-new-visit deployed but unused until social/push work resumes.
-- 4. Before re-enabling notifications, rebuild this flow without plaintext
--    credentials in SQL metadata and update the Edge Function to use
--    friends.friend_user_id instead of friends.friend_id.

