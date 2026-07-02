# Mugshot Restart Audit

Date: 2026-06-30

Phase: Phase 1 only. This audit documents what exists, what is real, what is demo-only, and what should happen next. No app implementation changes were made.

Phase 2A update: native Supabase auth/session/profile bootstrap has now been implemented after this audit. Historical Phase 1 notes below that say "no Supabase client" or "auth missing" should be read as pre-Phase-2A findings. Current status is documented in `docs/PHASE_2A_AUTH_PROFILE_BOOTSTRAP.md`.

Phase 2B read update: Profile Recent, Feed, and remote visit detail now read real Supabase data without writing rows. Historical notes below that say content surfaces do not use Supabase should be read as pre-read-slice findings for Map, Add, Saved, write paths, social actions, and stats. Current status is documented in `docs/PHASE_2B_REAL_VISITS.md` and `docs/REAL_DATA_FLOW_STATUS.md`.

## Founder Summary

Mugshot currently has a polished native iOS SwiftUI prototype with real local-device behavior for onboarding, map search, logging visits, photos, ratings, favorites, want-to-try, feed cards, visit detail, cafe detail, comments, likes, edit/delete, and profile stats.

The iOS app is now connected to Supabase for auth/session/profile bootstrap plus read-only Profile Recent, Feed, and remote visit detail. Most write-heavy content data is still stored in one local `UserDefaults` blob through `DataManager`, with newly selected photos saved as JPEG files in the app documents folder through `PhotoCache`. The social/content surfaces still look more complete than they are because visit creation, friendships, visibility writes, like/comment mutations, map state, photo upload, and stats are still local/demo data.

The connected Supabase project is real and significantly more advanced than the app code. It has auth-backed users, cafes, visits, visit photos, likes, comments, friends, friend requests, notifications, device tokens, storage buckets, Edge Functions, analytics, rating templates, and many migrations. The biggest restart task is not inventing a backend. It is safely reconnecting the existing iOS experience to the backend that already exists, while cleaning up security and schema drift first.

## Tools And Plugins Used

- GitHub connector: confirmed the repository is `HyperGoatt/mugshot-app`, public, on default branch `main`, with local checkout tracking `origin/main`.
- Supabase connector: inspected the active `Mugshot-App` project read-only: tables, RLS, storage buckets, functions, migrations, row counts, triggers, and advisors.
- Build iOS Apps plugin / XcodeBuildMCP: discovered the Xcode project and scheme, then ran simulator build and tests.
- Product Design plugin: reviewed its audit workflow. Full screenshot/Figma audit was not used because this Phase 1 request is a repo/Supabase reality audit, not a visual flow critique.
- Build Web Apps plugin: inspected briefly but not used. This is not a React/Next/Vite web app.

## Repository Reality

Stack:

- Native iOS app.
- SwiftUI plus UIKit bridges where needed.
- Xcode project: `testMugshot.xcodeproj`.
- App scheme: `testMugshot`.
- Bundle id: `co.mugshot.app.testMugshot`.
- Minimum deployment target currently set to iOS `18.5`.
- Swift Package dependency: Supabase Swift.
- No CocoaPods or Firebase.
- No repo-local README, AGENTS instructions, CONTRIBUTING file, Supabase config, migrations, or `.mcp.json`.

Current local git state:

- Branch: `main`, tracking `origin/main`.
- One pre-existing modified file before this audit: `testMugshot.xcodeproj/project.pbxproj`.
- That project change adds display name/category/orientation settings and currently sets display name to `Mugshott`, which appears to be a typo.

## What Is Actually Real Today

- A native SwiftUI app shell with Map, Feed, Add, Saved, and Profile tabs.
- Local onboarding that creates a local `User`.
- Apple Maps search through `MKLocalSearch`.
- Local cafe creation from Apple Maps results.
- Local visit logging with drink type, custom drink, caption, notes, visibility, ratings, and photos.
- Local photo persistence to the app documents directory.
- Local favorites and want-to-try cafe state.
- Local feed list with likes and comments.
- Local visit detail with edit/delete.
- Local cafe detail and recent visit history.
- Local profile stats.
- A connected Supabase backend exists, with real tables and policies. The iOS app now uses it for auth/profile plus read-only Profile Recent, Feed, and remote visit detail.

## What Looks Real But Is Not Wired Yet

- Auth: sign in, sign up, sign out, session restore, and Supabase auth client now exist from Phase 2A.
- Friends feed: signed-in Feed now reads remote visible visits, but full friend-graph semantics still need multi-account validation.
- Community feed: Everyone now reads remote public visits and opens read-only remote detail, but social mutations and card-level counts are not wired.
- User profiles: no public profile view exists yet; Feed author data is currently card-summary only.
- Notifications: backend tables/functions exist, but no iOS notification surface or device registration is wired.
- Push updates: Supabase has a push Edge Function, but the app has no device token registration and the function appears to reference stale friendship column names.
- Privacy controls: visibility is local only, not enforced by RLS from the app.
- Media storage: photos are local files, not Supabase Storage objects.
- Analytics: Supabase has `analytics_events`, but the iOS app does not send events.
- Feed search button: visible in `FeedTabView`, but action is empty.

## Product Surface Status

| Surface | Status | Files | Highest-priority issue |
| --- | --- | --- | --- |
| Welcome / onboarding | Mostly working | `testMugshot/Views/Onboarding/OnboardingView.swift`, `testMugshot/testMugshotApp.swift` | Local only; no auth, no username uniqueness, no profile sync. |
| Auth | Phase 2A implemented | `Views/Auth/AuthEntryView.swift`, `Services/Supabase/AuthService.swift`, `Services/Supabase/AppAuthModel.swift` | Email/password auth and session restore work; auth UI is intentionally minimal. |
| Setup Profile | Partially built | `OnboardingView.swift`, `Models/User.swift`, `Views/Profile/ProfileTabView.swift`, `Services/Supabase/ProfileService.swift` | Current `public.users` row loads/bootstraps and basic profile edit exists; avatar/banner upload and stronger handle validation remain. |
| Feed | Partially built | `Views/Feed/FeedTabView.swift`, `Views/Feed/RemoteVisitDetailView.swift`, `Services/DataManager.swift`, `Services/Supabase/VisitService.swift` | Signed-in cards read real Supabase visits/users/cafes and open read-only detail with photos/counts/comments; social mutations, card-level counts, and true friend-graph behavior remain unwired. |
| Map | Partially backend-backed | `Views/Map/MapTabView.swift`, `Services/MapSearchService.swift`, `Services/LocationManager.swift` | Apple Maps search remains native; signed-in Favorite/Want-to-Try state now syncs and writes through Supabase. Cross-user discovery is not wired. |
| Add Visit / Compose | Partially backend-backed | `Views/Add/AddTabView.swift`, `Services/PhotoCache.swift`, `Models/Visit.swift` | Signed-in Add Visit writes real visits and optional photos to Supabase; signed-out mode remains local. |
| Saved | Partially backend-backed | `Views/Saved/SavedTabView.swift`, `Models/Cafe.swift` | Signed-in Favorite/Want-to-Try state syncs through `user_cafe_states`; signed-out mode remains local. |
| Profile | Partially built | `Views/Profile/ProfileTabView.swift`, `Services/DataManager.swift` | Current-user stats are local only; no edit profile, avatar/banner, remote identity, or settings entry. |
| User Profile | Missing | None | No public profile view for another user despite Supabase user/friend data. |
| Visit Detail | Mostly working | `Views/Feed/FeedTabView.swift` | Local edit/delete/like/comment work, but no remote permissions, remote comments, or storage photos. |
| Cafe Detail | Mostly working | `Views/Saved/SavedTabView.swift`, `Views/Map/MapTabView.swift` | Local aggregate stats only; Supabase aggregate function exists but app does not use it. |
| Friends | UI-only / fake data | `Models/FeedScope.swift`, `Models/Visit.swift`, `DataManager.swift` | "Friends" exists as a label/visibility value, not as a real friends surface. |
| Notifications | Missing | None | Backend notifications exist, but no screen, unread state, or APNs registration in iOS. |
| Settings | Missing | Only system Settings deep link in `MapTabView.swift` | No app settings surface for account, privacy, notifications, or logout. |
| Privacy / Terms / Company pages | Missing | None | No legal/company pages in app or repo. |

## Biggest Blockers To Private Beta

1. The app has Supabase auth/profile bootstrap and read-only visit/feed/detail services, but no backend write layer for visits, cafes, storage, saved state, or social actions.
2. Local data model and Supabase schema still have some drift, but `Cafe.remoteCafeId` now bridges local cafes to Supabase cafes for saved state.
3. Photo handling has a first signed-in Storage path, but still needs manual picker validation and cleanup for partial failures.
4. RLS and function security need review before connecting real users. Supabase advisors show security-definer views/functions, public execution warnings, public bucket listing risk, and old `auth.role()` patterns.
5. A database trigger appears to embed a bearer token for an Edge Function call. Do not copy it. It should be rotated and replaced with a safer pattern before beta.
6. The silent push Edge Function appears to query `friends.friend_id`, but the actual table uses `friend_user_id`.
7. There are no meaningful app tests for the core journey.

## What Should Not Be Touched Yet

- Do not rewrite the SwiftUI app. The current local prototype contains useful interaction decisions.
- Do not delete Supabase tables or migrations. The backend appears to contain real prior work, and many concepts already map to the product vision.
- Do not remove local `DataManager` immediately. It can be useful as an offline/mock adapter while Supabase repositories are introduced.
- Do not launch broad redesign work before one backend-backed journey works.
- Do not change RLS policies casually. Treat Supabase as production-sensitive and create a separate reviewed security task.
- Do not delete the existing Edge Functions until their intended PWA/mobile history is understood.

## Shortest Path To One Clean End-To-End Journey

Build one narrow path:

1. User signs up or signs in with Supabase Auth.
2. App creates/loads the matching `public.users` profile.
3. User searches/selects a cafe.
4. User logs one visit with one optional photo.
5. App uploads the photo to `visit-photos`, inserts `visits`, inserts `visit_photos`, and updates/reads cafe state.
6. Feed shows that same saved visit from Supabase after app relaunch.

This should come before Friends, Notifications, public discovery, polished settings, or broad visual changes.

## Validation Run

- Build: passed using XcodeBuildMCP `build_sim` on iPhone 17 simulator target.
- Build warnings:
  - `Cafe.swift`: custom `CLLocationCoordinate2D` conformance to `Codable` may conflict if Apple adds conformance in the future.
  - `DataManager.swift`: `currentUserId` is assigned but unused in `toggleVisitLike`.
- Tests: passed using XcodeBuildMCP `test_sim`.
- Test caveat: tests now include lightweight remote DTO mapping checks, but they still do not prove full Mugshot product flows.
