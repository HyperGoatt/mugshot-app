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

Phase 2A status: native Supabase client setup, auth/session restore, and current-user `public.users` profile bootstrap are now implemented and simulator-smoke-tested. Map, Add, Saved, and stats remain local/demo after sign-in.

Phase 2A.5 status: Phase 2A was checkpointed at commit `ff98451`. Read-only Supabase inspection identified a risky `public.visits` insert trigger that would fire during real visit creation. After manual signing-key rotation, the quarantine SQL was applied and verification showed no visit insert trigger path calling `supabase_functions.http_request`. See `docs/VISIT_WRITE_BLOCKER.md`.

Phase 2B continuation status on 2026-07-01: the trigger path was quarantined, repo/branch reconciliation kept `/Users/joe.rosso/Desktop/Projects/testMugshot` as the source of truth, and real no-photo Add Visit is now implemented on `codex/phase-2b-real-add-visit`. The simulator created a real private visit, opened remote Visit Detail, showed it in Profile Recent, and showed it again after app relaunch. See `docs/PHASE_2B_REAL_VISITS.md` and `docs/REAL_DATA_FLOW_STATUS.md`.

Phase 2B UI pass status on 2026-07-01: current mockups were reviewed and only the pieces that strengthen the real Add Visit loop were adopted. Add Visit now has required-progress framing and signed-in photo-readiness copy; remote Visit Detail has owner saved confirmation plus a no-photo upload-next state; Profile Recent has cleaner no-photo/empty states. Saved, Friends, Notifications, map/cafe redesigns, full Taste Identity, and social/share ideas remain deferred.

Phase 2D photo upload slice status on 2026-07-01: Storage policy preflight passed and the native Add Visit picker is wired for signed-in uploads. The app creates the visit first, uploads selected JPEG-compressed photos to `visit-photos` under the authenticated user's folder, inserts `visit_photos`, and sets `poster_photo_url`. A simulator smoke created a real photo-backed visit after fixing uppercase UUID path handling. The next pass added focused tests for lowercase Storage paths and photo attach payloads, plus a small recovery card to retry failed photo uploads or open the saved no-photo visit without creating a duplicate. No-photo saves still work. See `supabase/manual/phase_2d_visit_photo_storage_policy.sql`.

Personal loop state update on 2026-07-01: `user_cafe_states` is now wired through a native `CafeStateService`. Signed-in Saved and Map sync Favorite/Want-to-Try state from Supabase, Map and full Cafe Detail write those toggles back to Supabase after resolving the remote cafe, successful remote Add Visit mirrors the cafe into the local shell so Map/Saved can reflect it, and full Cafe Detail loads the signed-in user's remote recent visits for cafes with a remote id. This preserves the existing UI while making cafe state durable.

Core loop validation update on 2026-07-02: profile text edit was live-smoked with a relaunch and restored to its original value. Saved/Want-to-Try persistence was live-smoked by toggling Ritual Coffee Roasters into Want-to-Try, relaunching, and verifying it in Saved > Want to Try. A display fallback was added so state-only cafe sync does not make Saved/Cafe Detail show `0 visits` when local visit rows are visible. Add Visit photo selection was tightened with a direct native `PhotosPicker`, top-of-form photo placement, and photo-library usage copy. The manual Photos picker pass is now complete: a seeded simulator image was selected, uploaded to Supabase Storage, attached to a real private visit, shown in Profile Recent after relaunch, and rendered in remote Visit Detail. Final audit also verified Feed, Saved, Map, and Cafe Detail state after relaunch. The personal-loop gate is complete enough to begin the mockup-led UI/UX revamp.

Add Visit polish update on 2026-07-02: the mockup-led revamp has started with Add Visit only. `log1`, `log2`, and `log3` influenced the new "Log a Sip" hierarchy, photo-first card, live progress/summary cues, drink chips, rating score panel, clearer copy, visibility controls, and keyboard/tab-bar spacing. Backend contracts were preserved: no-photo save still creates a Supabase visit and opens remote Visit Detail; the existing photo upload path was not changed. Build/run passed, tests passed 20/0, and a no-photo smoke created `Codex Add Visit polish no-photo smoke 2026-07-02`, which appeared at the top of Profile Recent after relaunch.

Visit Detail/Profile Recent polish update on 2026-07-02: the next mockup-led slice tightened the post-save loop without changing Supabase contracts. `log4` influenced the remote Visit Detail "Sip saved" confirmation and post-save hierarchy, while `profile1` and `feed1` influenced richer Profile Recent cards with photo-led posters, compact no-photo thumbnails, score pills, caption, visibility, and recency metadata. Remote detail remains read-only for social/edit actions, and no Supabase services or payloads changed. Build/run passed, tests passed 20/0, and simulator validation opened both the no-photo polish smoke and the photo-backed upload smoke from Profile Recent into remote Visit Detail.

Feed card polish update on 2026-07-02: `feed1` guided a focused signed-in Feed polish using the existing remote summary/detail contracts. Feed now has scope-aware subtitle copy, icon-backed Friends/Everyone controls, richer remote cards, a photo/no-photo poster area, location overlay, score pill, drink/caption hierarchy, metadata pills, and a compact detail footer. Remote cards still open the existing read-only Visit Detail; no feed search, social mutations, friend graph, notifications, or Supabase contract changes were added. Build/run passed, tests passed 20/0, and simulator validation opened both no-photo and photo-backed Feed cards into remote detail.

Saved/Cafe Detail polish update on 2026-07-02: `saved1`, `saved2`, and `cafe1` guided a restrained personal-library polish. Saved now has scope-aware header copy, stronger cafe cards, score/state/visit chips, empty states, and compact action footers. Cafe Detail now has a padded identity card, stat cards, a stable action grid, and polished recent visit rows. Favorite/Want-to-Try sync, Cafe Detail remote visit loading, and local fallback behavior were preserved. Lists, search, notes, invites, friend recommendation/social proof, richer cafe aggregate backend work, and map/cafe redesigns remain deferred. Build/run passed, tests passed 20/0, and simulator validation covered Favorites, Want to Try, Cafe Detail, and visit-row drill-in.

Map bottom-sheet polish update on 2026-07-02: `map1` and `map2` guided a narrow bottom-sheet polish without changing MapKit behavior or backend contracts. The selected-cafe sheet now uses the same identity, state-chip, stat-card, action-grid, and recent-row language as Saved/Cafe Detail. Favorite/Want-to-Try writes still go through `CafeStateService`, Details still opens full Cafe Detail, and broader map filters/friend overlays/recommendation lists remain deferred. Build/run passed, tests passed 20/0, and simulator validation opened the sheet from a visible map pin plus opened full Cafe Detail from Details.

Beta-readiness audit update on 2026-07-02: the now-polished personal loop was audited with fresh iPhone 17 Pro simulator screenshots saved under `docs/audits/beta-readiness-2026-07-02/`. Map launch, Feed, remote Visit Detail, Add Visit, Saved, Cafe Detail, Profile, and Profile Recent are coherent enough for a narrow beta path. The audit found and fixed one Add Visit CTA issue: incomplete forms now show `Complete Required Details` and the primary save action is disabled until Cafe, Drink, Rating, and Caption are ready. Tests passed 20/0 and build/run passed after the fix. Remaining beta risks are Map search reliability, read-only/social icon clarity, state-only cafe copy, and accessibility/manual Photos picker checks.

Repo reconciliation status on 2026-07-01: continue Phase 2B from `/Users/joe.rosso/Desktop/Projects/testMugshot`. Older native work in `/Users/joe.rosso/Documents/mugshot-app` is useful as a selective-harvest reference, especially for Mugsy assets, empty states, Add Visit mapping, Friends/Notifications, Saved, and profile setup, but it should not be merged wholesale. See `docs/REPO_BRANCH_RECONCILIATION.md`.

Profile edit status: profile edit basics are implemented, simulator-validated, and live-smoked against the signed-in remote profile. See `docs/PHASE_2B_PROFILE_EDIT_BASICS.md` and `docs/PHASE_2B_REAL_VISITS.md`.

## 1. Secure The Supabase Trigger Secret - Done

Outcome: no bearer/service-role token is embedded in a database trigger action.

Why first: a sensitive bearer token was visible in the trigger definition for the visit insert Edge Function call. Do not copy it. Rotate/revoke it and replace the invocation pattern safely.

Current Phase 2A.5 decision: this no longer blocks no-photo Phase 2B visit writes. The `notify-friends-on-new-visit` trigger was removed from `public.visits`, and verification showed zero visits insert triggers using `supabase_functions.http_request`.

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

Status: started. `CafeService`, `VisitService`, `VisitPhotoUploadService`, and `CafeStateService` now support Profile Recent, Feed, remote detail, cafe create/reuse, signed-in photo-backed visit creation, first visit photo upload/attach, durable Favorite/Want-to-Try cafe state, like/unlike, comments, owner edit/delete, and cafe save from visit surfaces. A fuller repository split remains future work.

## 7. Wire One Visit Create Journey To Supabase - Done In Phase 2B

Outcome: Add Visit creates a real `visits` row for the signed-in user.

Start without complex social behavior. Use existing UI. Save cafe, drink type, drink subtype, caption, notes, visibility, ratings/category scores, and overall score.

Status: final trigger preflight passed, then the iOS simulator created a real no-photo visit with cafe, drink detail, ratings, caption, notes, private visibility, and context. The visit persisted after relaunch.

## 8. Wire Photo Upload For Visits - Started In Phase 2D

Outcome: selected visit photos upload to Supabase Storage and create `visit_photos` rows.

Keep the first version boring: upload, show progress/error, clean up the just-created visit row on upload failure when possible, then tighten partial-failure cleanup.

Status: first native upload path is wired after Storage policy preflight and simulator-smoked with uploaded photos, including completed native picker selection passes on 2026-07-01 and 2026-07-03. Lowercase Storage paths, upload caps, photo attach ordering, poster fallback, cafe insert payloads, and visit insert payloads now have focused tests. The 2026-07-03 readiness pass made photos required before any Add Visit save, removed the open-saved-no-photo recovery path, and then saved fresh smoke visit `587f8423-a56f-46fe-b15a-452b2f024ebf` with 1 uploaded photo. Remaining work is clearer per-photo progress/errors and orphaned Storage cleanup.

## 9. Replace Feed With Backend Data For Current User Plus Public Visits

Outcome: after relaunch, the Feed reads from Supabase and shows the visit just created.

Do not tackle full friend graph yet. First prove authenticated write, visibility, card counts, photo upload, and social mutation shape. Profile Recent, Feed, and remote detail now prove authenticated visit/cafe/profile/photo/comment/like reads from Supabase.

Cafe state note: Saved/Map now also prove authenticated `user_cafe_states` read/write for the personal loop; full friend graph and social actions remain separate.

## 10. Add Meaningful Tests For The First Journey

Outcome: tests cover onboarding/auth bootstrap, local model mapping, one visit creation, and feed reload behavior.

Use small tests around repository/model mapping first. Add UI tests only after the backend path is deterministic.

## First 3 Implementation Tasks I Would Do Next

1. Smoke like/unlike/comment/save cafe plus owner edit/delete on throwaway remote data.
2. Replace placeholder Settings legal copy with reviewed beta copy.
3. Do an accessibility pass on Add Visit, Feed cards, remote Visit Detail, Saved, Mugsy empty states, and Settings.

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
