-- The production worker existed before its durable schedule was restored, so
-- queued rows can be much older than a useful push notification. Preserve the
-- authoritative in-app Activity events while preventing a stale notification
-- burst at schedule cutover. Fresh deliveries remain eligible for the first
-- canonical worker run.

begin;

update private.activity_push_deliveries delivery
set
  status = 'cancelled',
  completed_at = now(),
  claimed_at = null,
  claim_token = null,
  last_error_code = 'pre_schedule_backlog_expired',
  updated_at = now()
where delivery.status = 'pending'
  and delivery.created_at < now() - interval '15 minutes';

commit;
