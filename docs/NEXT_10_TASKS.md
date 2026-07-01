# Next 10 Tasks

Date: 2026-06-30

These are ordered for the shortest path to a real private beta. They intentionally avoid broad redesigns and preserve the current app.

Phase 1.6 added a web reference audit. Read these before starting implementation:

- `docs/WEB_APP_REFERENCE_AUDIT.md`
- `docs/FEATURE_PARITY_MATRIX.md`
- `docs/IOS_PARITY_ROADMAP.md`
- `docs/MUGSHOT_PRODUCT_SPEC.md`
- `docs/WEB_TO_IOS_TRANSLATION_NOTES.md`

The main conclusion did not change: connect the existing native shell to durable Supabase behavior before adding new product surfaces.

Phase 2A status: native Supabase client setup, auth/session restore, and current-user `public.users` profile bootstrap are now implemented and simulator-smoke-tested. Map, Feed, Add, Saved, and stats remain local/demo after sign-in.

Phase 2A.5 status: Phase 2A was checkpointed at commit `ff98451`. Read-only Supabase inspection confirmed the risky `public.visits` insert trigger still exists and would fire during real visit creation. Phase 2B visit inserts are blocked until the trigger is disabled, dropped, or rebuilt without embedded credentials.

Profile edit status: profile edit basics are implemented and simulator-validated. See `docs/PHASE_2B_PROFILE_EDIT_BASICS.md`. Live Save validation still needs an approved remote profile-write pass with a test user.

## 1. Secure The Supabase Trigger Secret

Outcome: no bearer/service-role token is embedded in a database trigger action.

Why first: a sensitive bearer token was visible in the trigger definition for the visit insert Edge Function call. Do not copy it. Rotate/revoke it and replace the invocation pattern safely.

Current Phase 2A.5 decision: this blocks real Add Visit writes. For a no-photo Phase 2B, the shortest safe quarantine is to remove or disable the `notify-friends-on-new-visit` trigger on `public.visits` before inserting visits from iOS.

Prepared helper: `supabase/manual/phase_2a5_quarantine_visit_notify_trigger.sql`. Prefer dropping the trigger after rotating the credential, because disabling it would still leave the embedded credential in database metadata.

## 2. Pull Supabase Schema And Migrations Into The Repo

Outcome: the repo contains the current Supabase migrations/functions or an agreed snapshot.

Why: the database has a substantial migration history, but the repo has no `supabase/` folder. Future schema work needs reviewable files.

## 3. Fix Push/Friends Backend Drift

Outcome: `notify-friends-on-new-visit` uses the actual `friends.friend_user_id` column or the agreed friendship model.

Why: the Edge Function appears to query `friend_id`, which does not exist on the current `friends` table.

## 4. Add Supabase Swift Client And Environment Configuration - Done In Phase 2A

Outcome: app can initialize a Supabase client without exposing secret keys.

Scope: add only the official client dependency and safe public config. No feature rewrites yet.

Status: implemented with the official Supabase Swift package, `Config/SupabaseConfig.xcconfig`, ignored local config, and `Config/Info.plist` placeholders.

## 5. Build Auth And Profile Bootstrap - Done In Phase 2A

Outcome: user can sign up/sign in, app can load/create `public.users`, and the current profile is available to the existing app shell.

Keep it simple: one auth method first, one profile row, one session restore path.

Status: sign in, sign up, sign out, session restore, profile fetch/bootstrap, and remote-profile-to-local-user mapping are implemented. Full profile setup/edit remains Phase 2B.

## 6. Add A Repository Layer Beside DataManager

Outcome: app screens can use a small service boundary instead of calling Supabase directly from SwiftUI views.

Suggested shape:

- `AuthService`
- `ProfileRepository`
- `CafeRepository`
- `VisitRepository`
- `PhotoStorageService`

Keep `DataManager` available for local/mock mode until the first remote journey is stable.

## 7. Wire One Visit Create Journey To Supabase

Outcome: Add Visit creates a real `visits` row for the signed-in user.

Start without complex social behavior. Use existing UI. Save cafe, drink, caption, notes, visibility, ratings, and overall score.

Gate: do not start until the visit insert trigger is confirmed safe or inactive.

## 8. Wire Photo Upload For Visits

Outcome: selected visit photos upload to Supabase Storage and create `visit_photos` rows.

Keep the first version boring: upload, show progress/error, retry or cancel, then save the visit after URLs exist.

## 9. Replace Feed With Backend Data For Current User Plus Public Visits

Outcome: after relaunch, the Feed reads from Supabase and shows the visit just created.

Do not tackle full friend graph yet. First prove authenticated read/write, visibility, photos, likes count, and comments shape.

## 10. Add Meaningful Tests For The First Journey

Outcome: tests cover onboarding/auth bootstrap, local model mapping, one visit creation, and feed reload behavior.

Use small tests around repository/model mapping first. Add UI tests only after the backend path is deterministic.

## First 3 Implementation Tasks I Would Do Next

1. Resolve or quarantine the Supabase trigger/security findings and decide where backend migrations/functions live.
2. Run an approved backend-write smoke test for profile edit basics with a non-production test user.
3. Wire Add Visit to create one real Supabase visit only after the visit trigger quarantine is applied and verified.

## Product Recommendations Separate From Implementation

- Keep the current mobile-first tab structure for now: Map, Feed, Add, Saved, Profile.
- Make the first beta promise narrow: "log every sip and see your own history across map, feed, and profile."
- Delay Friends, Notifications, and public User Profile until auth and one saved visit are solid.
- Decide whether place identity should be Apple Maps-first, Google Places-first, or dual-source before backend cafe matching expands.
- Treat rating templates as a signature Mugshot feature, but start by mapping the current simple ratings JSON to Supabase before over-designing templates.
- Use the web app as a product/data-contract reference, not as a screen-by-screen implementation checklist.

## Things To Avoid

- Do not redesign the app before connecting one journey.
- Do not delete backend tables just because the iOS app does not use most of them yet.
- Do not move every screen to Supabase at once.
- Do not launch public social discovery until RLS and visibility behavior are tested.
- Do not add push notifications before device registration and Edge Function security are clean.
