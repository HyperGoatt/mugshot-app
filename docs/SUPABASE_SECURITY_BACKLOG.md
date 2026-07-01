# Supabase Security Backlog

Date: 2026-07-01

Purpose: track backend safety work discovered before and during Phase 2A. This file is a backlog only; Phase 2A did not change Supabase remotely.

Phase 2A.5 update: read-only Supabase inspection confirmed the visit trigger risk. No live backend changes were made.

Related docs:

- `docs/PHASE_2A5_SECURITY_CHECKPOINT.md`
- `docs/PHASE_2B_READINESS.md`

## Blocking Before Visit Writes

### 1. Rotate And Replace Visit Trigger Bearer Token

Severity: critical.

The `visits` insert trigger invokes an Edge Function through a database-side HTTP call and the trigger action currently contains an embedded bearer token. The token was not copied into docs.

Phase 2A.5 verification:

- Trigger: `public.visits` `AFTER INSERT FOR EACH ROW`.
- Trigger name: `notify-friends-on-new-visit`.
- Target: `notify-friends-on-new-visit` Edge Function.
- Function JWT setting: JWT verification is enabled.
- Phase 2B impact: every real `visits` insert would fire this trigger.
- Product dependency: not required for Add Visit, profile bootstrap, no-photo feed reads, or local shell navigation. It is notification/social infrastructure.

Classification: blocking Phase 2B until fixed or explicitly quarantined. The safest short-term quarantine for no-photo Add Visit is to remove or disable this visit insert trigger before any native visit writes. The safer long-term fix is to rebuild the invocation so database code does not store plaintext credentials.

Fix path:

1. Rotate/revoke the exposed token.
2. Short-term: drop or disable the `public.visits` trigger if push/social notifications are not part of Phase 2B.
3. Long-term: replace the trigger invocation with a safer secret-management pattern, such as a custom database function that reads a key from Vault at call time, or an Edge Function auth mode designed for server-to-server callers.
4. Re-test `notify-friends-on-new-visit`.
5. Do not enable native Add Visit Supabase inserts until this is resolved or intentionally quarantined.

### 2. Fix Push/Friends Function Drift

Severity: high.

The `notify-friends-on-new-visit` Edge Function appears to query a `friends.friend_id` column, but the current table uses `friend_user_id`.

Phase 2A.5 verification: the function source still selects and filters `friend_id`, while the `friends` table foreign keys are `user_id` and `friend_user_id`.

Fix path:

1. Update the Edge Function to use the actual friendship schema.
2. Add a narrow test fixture for a visit by one user and a friend recipient.
3. Confirm it fails closed if APNs/device tokens are unavailable.

Classification: must fix before social/notifications. It is not needed for no-photo Add Visit once the visit trigger is disabled or rebuilt safely.

## Phase 2A.5 Finding Classification

Must fix before Phase 2B visit writes:

- The `public.visits` insert trigger that calls `notify-friends-on-new-visit` with an embedded bearer credential.

Must fix before photos/storage:

- Public object listing behavior on `profile-media`.
- Re-check `visit-photos` upload/read policies before adding native upload.
- Replace old `auth.role()` storage policy patterns with role-targeted policies where practical.

Must fix before social/notifications:

- `notify-friends-on-new-visit` stale `friends.friend_id` reference.
- Broad/public execute access on security-definer functions that should be trigger-only or narrower RPCs.
- `notifications_with_actor` view should be reviewed for `security_invoker = true` or stricter exposure.
- `user_devices` policy labeled for service-role access appears broad; verify anon/authenticated users cannot list device tokens before device registration.
- `send_push_notification_trigger` search path and public execution posture.

Later hardening:

- Feedback-board security-definer views if the feedback board stays out of the first beta.
- `auth.role()` policy modernization on cafes and storage objects.
- Performance advisor items such as unindexed foreign keys, repeated `auth.uid()` evaluation, multiple permissive policies, and unused indexes.
- Moving `pg_net` out of `public` if feasible after trigger/webhook cleanup.
- Leaked password protection before external beta.

## Security Advisor Findings

### Security-Definer Views

Flagged views:

- `notifications_with_actor`
- `feedback_posts_with_counts`
- `feedback_comments_with_author`

Fix path:

- Review whether each view should use `security_invoker = true`.
- Confirm RLS still applies as intended to the underlying tables.

### Security-Definer Function Execution

Advisor flagged broad execution exposure for security-definer functions including:

- `create_friendship_on_request_accept`
- `get_cafe_aggregate_stats`
- `get_mutual_friends`
- `handle_new_user`
- `send_push_notification_trigger`

Fix path:

- Revoke unnecessary `anon`/`authenticated` execute privileges.
- Grant execute only where the client truly needs RPC access.
- Keep trigger-only functions non-callable from client roles where possible.

### Mutable Search Path Warnings

Flagged functions:

- `update_user_devices_updated_at`
- `send_push_notification_trigger`
- `set_updated_at`

Fix path:

- Set explicit `search_path` values on functions.
- Re-run advisors after migration.

### Public Extension Schema

`pg_net` is installed in `public`.

Fix path:

- Review whether the extension can be moved to a dedicated extension schema.
- Confirm existing database HTTP calls still work after migration.

### Public Bucket Listing

`profile-media` is public and advisor warns object listing may be broader than needed.

Fix path:

- Keep public URL delivery if needed.
- Restrict object listing where practical.
- Confirm profile image upload/update/delete policies are still user-folder scoped.

### Auth Hardening

Leaked password protection is disabled.

Fix path:

- Enable leaked password protection in Supabase Auth settings before beta.
- Confirm email/password UX handles the resulting auth errors cleanly.

### Older RLS Patterns

Some policies still use `auth.role() = 'authenticated'`.

Fix path:

- Prefer policy role targets like `TO authenticated`.
- Keep ownership checks with `(select auth.uid())` where performance advisors recommend it.

## Not Blocking Phase 2A

Phase 2A only initializes the native client, signs in/out, restores sessions, and fetches/bootstraps the current user's `public.users` row. It does not insert visits, upload photos, send notifications, or call push functions.

The backlog becomes blocking before:

- Phase 2C Add Visit Supabase insert.
- Visit photo upload.
- Push/device registration.
- Friends/notifications product work.
