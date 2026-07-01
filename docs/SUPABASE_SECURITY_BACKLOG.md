# Supabase Security Backlog

Date: 2026-07-01

Purpose: track backend safety work discovered before and during Phase 2A. This file is a backlog only; Phase 2A did not change Supabase remotely.

## Blocking Before Visit Writes

### 1. Rotate And Replace Visit Trigger Bearer Token

Severity: critical.

The `visits` insert trigger invokes an Edge Function through a database-side HTTP call and the trigger action currently contains an embedded bearer token. The token was not copied into docs.

Fix path:

1. Rotate/revoke the exposed token.
2. Replace the trigger invocation with a safer secret-management pattern.
3. Re-test `notify-friends-on-new-visit`.
4. Do not enable native Add Visit Supabase inserts until this is resolved or intentionally quarantined.

### 2. Fix Push/Friends Function Drift

Severity: high.

The `notify-friends-on-new-visit` Edge Function appears to query a `friends.friend_id` column, but the current table uses `friend_user_id`.

Fix path:

1. Update the Edge Function to use the actual friendship schema.
2. Add a narrow test fixture for a visit by one user and a friend recipient.
3. Confirm it fails closed if APNs/device tokens are unavailable.

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
