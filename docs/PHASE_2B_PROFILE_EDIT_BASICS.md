# Phase 2B Profile Edit Basics

Date: 2026-07-01

Purpose: make the authenticated Supabase profile editable without starting Add Visit, photo upload, storage, Feed replacement, Map replacement, Friends, or Notifications.

## Status

Implemented, simulator-validated, and later live-smoked against the signed-in Supabase profile.

This is the roadmap's profile/edit slice. It does not unblock no-photo visit creation by itself; `docs/PHASE_2B_READINESS.md` still gates real `visits` inserts on the Supabase trigger quarantine.

## Completed

- Added a `public.users` update payload for editable profile fields.
- Added `ProfileService.updateProfile(...)`.
- Added `AppAuthModel.updateProfile(...)` with separate profile-update loading/error state so the signed-in shell does not collapse to the global auth loading screen while saving.
- Added an `Edit Profile` action on the existing Profile tab.
- Added a native edit sheet for:
  - display name
  - username
  - location
  - favorite drink
  - Instagram handle
  - website
  - bio
- Preserved the existing Profile layout and local/demo stats content.
- Kept avatar and banner upload out of scope because profile media storage still has a security backlog.

## Not Included

- Avatar upload.
- Banner upload.
- Profile media storage policy changes.
- Public profile browsing.
- Add Visit writes.
- Photo upload.
- Feed, Map, Saved, Friends, Notifications, Settings, or legal-page replacement.

## Validation

Target:

```text
project: /Users/joe.rosso/Desktop/Projects/testMugshot/testMugshot.xcodeproj
scheme: testMugshot
configuration: Debug
simulator: iPhone 17 Pro (iOS 26.2)
bundle id: co.mugshot.app.testMugshot
```

Results:

- Build: passed.
- Launch: passed.
- Session restore: passed; app opened into the signed-in shell.
- Profile: passed; Profile still showed Supabase profile active.
- Edit Profile sheet: passed; existing profile values rendered in editable fields.
- Cancel path: passed; sheet dismissed back to Profile.
- Tests: passed, 7 passed / 0 failed.
- Focused unit tests added for safe Supabase config loading, secret-key rejection, Supabase profile mapping, and profile update encoding.

Follow-up live validation on 2026-07-02:

- Save action was live-smoked against the signed-in Supabase profile.
- Location was temporarily changed to `CHS Smoke`, saved, and shown immediately on Profile.
- The app was relaunched, session restore loaded the changed value, and the field was restored to `CHS`.
- XcodeBuildMCP tests passed after the surrounding core-loop pass: 17 passed / 0 failed.

Screenshot:

```text
Edit Profile sheet:
/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_df0ca845-01fb-4529-8bc7-06efe4d20f41.jpg
```

Logs:

```text
Build:
/Users/joe.rosso/Library/Developer/XcodeBuildMCP/workspaces/testMugshot-8ff6cf9d4260/logs/build_sim_2026-07-01T03-44-30-175Z_pid79981_b876d51b.log

Build/run:
/Users/joe.rosso/Library/Developer/XcodeBuildMCP/workspaces/testMugshot-8ff6cf9d4260/logs/build_run_sim_2026-07-01T03-36-17-447Z_pid79981_5b34a6a9.log

Runtime:
/Users/joe.rosso/Library/Developer/XcodeBuildMCP/workspaces/testMugshot-8ff6cf9d4260/logs/co.mugshot.app.testMugshot_2026-07-01T03-36-42-943Z_helperpid26787_ownerpid79981_3e64539d.log

Tests:
/Users/joe.rosso/Library/Developer/XcodeBuildMCP/workspaces/testMugshot-8ff6cf9d4260/logs/test_sim_2026-07-01T03-50-00-898Z_pid79981_79f64e78.log
```

## Remaining Gate

Before real visit creation:

- Rotate/revoke the credential embedded in the `public.visits` trigger.
- Apply or otherwise perform the trigger quarantine in `supabase/manual/phase_2a5_quarantine_visit_notify_trigger.sql`.
- Verify the trigger no longer fires on `public.visits` inserts.
