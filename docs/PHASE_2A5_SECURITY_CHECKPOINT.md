# Phase 2A.5 Security Checkpoint

Date: 2026-07-01

Purpose: checkpoint Phase 2A safely, quarantine the visit-trigger bearer-token risk, and decide whether Mugshot can proceed to real no-photo visit creation.

## Status

Phase 2A was committed locally.

```text
commit: ff98451
message: Phase 2A: add Supabase auth and profile bootstrap
branch: main
remote status at checkpoint: ahead of origin/main by 1 commit
```

No live Supabase changes were made in Phase 2A.5. Supabase was inspected read-only.

## Repo And Secret Validation

Confirmed:

- `Config/SupabaseConfig.local.xcconfig` is ignored by git.
- The ignored local config was not staged or committed.
- Tracked config files contain placeholders only.
- Staged files were scanned for token-shaped values before commit.
- No `sb_secret_` key, service-role assignment, JWT-shaped token, private key block, or OpenAI-style secret key was found in the staged diff.

Expected safe references remain in docs and code:

- Warnings about bearer tokens and service-role keys.
- Placeholder `sb_publishable_REPLACE_ME` text in the example config.
- Non-secret authorization API names in Apple/Supabase code.

## Supabase Trigger Finding

Read-only database metadata confirmed:

- Table/event: `public.visits` `AFTER INSERT FOR EACH ROW`.
- Trigger: `notify-friends-on-new-visit`.
- Target service: Supabase Edge Function `notify-friends-on-new-visit`.
- Function JWT setting: JWT verification enabled.
- Trigger action contains an embedded bearer credential. The credential value was not copied into docs.

Impact:

- A Phase 2B insert into `public.visits` would fire the trigger.
- The trigger is not required for Add Visit, profile bootstrap, no-photo feed reads, or current native shell navigation.
- The trigger belongs to push/social notification infrastructure.

Classification: blocking Phase 2B until fixed or explicitly quarantined.

## Edge Function Finding

The `notify-friends-on-new-visit` Edge Function:

- Uses environment variables for APNs configuration.
- Uses Supabase server-side credentials from environment variables.
- Sends silent APNs/background pushes when a visible visit is created.
- Still references `friends.friend_id`.

The current `friends` table uses:

- `friends.user_id`
- `friends.friend_user_id`

This means the push/friends lookup path is stale and should be fixed before notifications/social work resumes.

## Manual Supabase Remediation Checklist

Do these in Supabase before allowing native visit inserts:

1. Open the Supabase Dashboard for project `quskamnfwglctqewwfln`.
2. Rotate or revoke the credential currently embedded in the `public.visits` trigger. Treat it as exposed.
3. Decide the short-term quarantine:
   - Recommended for Phase 2B: drop or disable the `notify-friends-on-new-visit` trigger on `public.visits`.
   - Keep the Edge Function deployed but unused until notification work resumes.
4. Verify the trigger no longer fires on `public.visits` inserts.
5. For the long-term notification path, rebuild the database-to-Edge-Function invocation so SQL metadata does not store plaintext credentials.
6. Store server-side secrets in Supabase Edge Function secrets or Postgres Vault, depending on the final invocation design.
7. Update `notify-friends-on-new-visit` to use `friends.friend_user_id`.
8. Re-test visible visit creation, private visit creation, no-friends behavior, no-device-token behavior, and APNs-unconfigured behavior.
9. Verify no service-role, secret, APNs key, or bearer credential appears in trigger definitions, function source, logs, or committed files.

Warning: Phase 2B should not proceed if the current trigger can still fire on `public.visits` inserts.

## Other Security Findings

Must fix before Phase 2B:

- Visit insert trigger with embedded bearer credential.

Must fix before photos/storage:

- `profile-media` public listing exposure.
- `visit-photos` upload/read policy review.
- Storage policies that still use older `auth.role()` checks.

Must fix before social/notifications:

- Stale `friends.friend_id` reference in `notify-friends-on-new-visit`.
- Security-definer functions with broad executable privileges.
- `notifications_with_actor` view exposure/security-invoker posture.
- `user_devices` broad read posture before registering device tokens.
- Push trigger/function mutable search-path issues.

Later hardening:

- Feedback-board views if the feedback board remains deferred.
- Cafe/storage policy modernization from `auth.role()` to role-targeted policies.
- Performance advisor items.
- `pg_net` extension schema cleanup.
- Leaked password protection before external beta.

## Phase 2B Decision

Do not start Phase 2B real visit creation yet.

The schema and RLS model are close enough for no-photo visit creation, but the insert side effect is not safe. Once the visit trigger is disabled, dropped, or rebuilt without embedded credentials, Phase 2B can proceed with real `visits` inserts and no photo upload.

