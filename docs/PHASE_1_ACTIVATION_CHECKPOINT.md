# Phase 1 — First-Session Activation Checkpoint

Status: Complete; advance to Phase 2 under the roadmap's risk-based transition policy.

## Shipped

- Signed-out Map and Saved access with contextual authentication gates for Feed, Add, Profile, cafe logging, and publishing.
- Map launch no longer requests location. Existing permission is honored; a new request begins only from the location control.
- Native Sign in with Apple appears first, with nonce hashing, Supabase ID-token exchange, session restoration, and email authentication as the secondary path.
- Guest Saved data is isolated from account-local data, previewed after authentication, merged idempotently, and retained on-device when a merge fails.
- Three optional capture preferences seed future Your Mix and journal defaults. Setup is skippable and editable later in Settings.
- Profile editing and Settings now use one explicit presentation route, preventing either sheet from suppressing the other.
- Existing first-sip save and Mugsy confirmation remain the activation moment; no profile fields or unrelated permissions are required.

## Data contract

- Repository migration: `20260714034500_add_capture_preferences.sql`
- Live migration: `20260714034718_add_capture_preferences`
- `user_capture_preferences` is owner-only with RLS, explicit authenticated grants, no anonymous grants, and account-deletion cascade behavior.
- Guest data remains an on-device store and is not uploaded until the signed-in owner explicitly confirms the merge.

## Verification

- Clean iOS 18.6 Simulator build succeeded.
- Clean iOS 26.2 Simulator build and run succeeded.
- 65 Swift unit tests passed, including guest/account storage isolation and merge-clearing safety.
- Signed-out UI journey passed on iOS 18.6: Map opens first, Saved remains available, Feed/Add are gated, and no permission alert appears at launch.
- Profile Settings gear UI journey passed on iOS 18.6 and iOS 26.2.
- Supabase activation contract passed.
- Supabase migration-integrity contract passed after the new migration.
- Screenshot QA: `phase-1-activation/01-guest-map.png` confirms the guest-first Map surface and selected Map navigation state.

## Carried risks and follow-ups

- Apple Developer Sign in with Apple capability/provisioning and the Supabase Apple provider still require dashboard configuration with production credentials. Email authentication remains available, so this is a release-configuration checkpoint rather than a Phase 2 blocker.
- Supabase automatically links identities that present the same verified email. Manual linking for a different Apple relay email is not exposed in this milestone and should be revisited with account-management work.
- Guest merge has unit and service-level safety coverage but has not been exercised with a destructive network interruption against a large production guest list. Its remote writes are idempotent and guest data is cleared only after complete success.
- The full permission matrix is not repeated here. The primary no-prompt launch path is automated; denied, restricted, and unavailable states remain part of ongoing accessibility and release QA.
- Existing project-wide Supabase advisor notices predate this migration. The new preference table introduced no missing-RLS or owner-policy defect.

## Advancement decision

The primary Phase 1 journey works end to end, and there is no known high-severity privacy, ownership, migration, or local data-loss defect. The remaining items are external configuration or bounded release QA, so Phase 2 may begin without waiting on them.
