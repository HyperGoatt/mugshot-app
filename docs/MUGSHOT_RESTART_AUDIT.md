# Mugshot Restart Audit

Date: 2026-06-30

Phase: Phase 1 only. This audit documents what exists, what is real, what is demo-only, and what should happen next. No app implementation changes were made.

Phase 2A update: native Supabase auth/session/profile bootstrap has now been implemented after this audit. Historical Phase 1 notes below that say "no Supabase client" or "auth missing" should be read as pre-Phase-2A findings. Current status is documented in `docs/PHASE_2A_AUTH_PROFILE_BOOTSTRAP.md`.

## Founder Summary

Mugshot currently has a polished native iOS SwiftUI prototype with real local-device behavior for onboarding, map search, logging visits, photos, ratings, favorites, want-to-try, feed cards, visit detail, cafe detail, comments, likes, edit/delete, and profile stats.

The iOS app is now connected to Supabase for auth/session/profile bootstrap only. App content data is still stored in one local `UserDefaults` blob through `DataManager`, with photos saved as JPEG files in the app documents folder through `PhotoCache`. The social/content surfaces look more real than they are because visits, friendships, visibility, likes, comments, map state, and stats are still local/demo data.

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
- A connected Supabase backend exists, with real tables and policies. The iOS app now uses it for auth/profile only; content surfaces do not use it yet.

## What Looks Real But Is Not Wired Yet

- Auth: sign in, sign up, sign out, session restore, and Supabase auth client now exist from Phase 2A.
- Friends feed: the app only filters local visits by visibility and treats "Friends" as non-private local content.
- Community feed: there are no fetched users or remote visits.
- User profiles: only the current local user exists in the app.
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
| Setup Profile | Partially built | `OnboardingView.swift`, `Models/User.swift`, `Views/Profile/ProfileTabView.swift`, `Services/Supabase/ProfileService.swift` | Current `public.users` row loads/bootstraps; no profile edit, avatar, display name edit flow, or handle validation UI yet. |
| Feed | Partially built | `Views/Feed/FeedTabView.swift`, `Services/DataManager.swift` | Local visits only; friends/community framing is not backed by users or friendship graph. |
| Map | Mostly working | `Views/Map/MapTabView.swift`, `Services/MapSearchService.swift`, `Services/LocationManager.swift` | Apple Maps search works locally, but backend cafe identity and cross-user discovery are not wired. |
| Add Visit / Compose | Mostly working | `Views/Add/AddTabView.swift`, `Services/PhotoCache.swift`, `Models/Visit.swift` | Local save only; no Supabase visit insert, Storage upload, retry/error state, or schema mapping. |
| Saved | Mostly working | `Views/Saved/SavedTabView.swift`, `Models/Cafe.swift` | Favorites/want-to-try are local cafe booleans, while Supabase uses `user_cafe_states`. |
| Profile | Partially built | `Views/Profile/ProfileTabView.swift`, `Services/DataManager.swift` | Current-user stats are local only; no edit profile, avatar/banner, remote identity, or settings entry. |
| User Profile | Missing | None | No public profile view for another user despite Supabase user/friend data. |
| Visit Detail | Mostly working | `Views/Feed/FeedTabView.swift` | Local edit/delete/like/comment work, but no remote permissions, remote comments, or storage photos. |
| Cafe Detail | Mostly working | `Views/Saved/SavedTabView.swift`, `Views/Map/MapTabView.swift` | Local aggregate stats only; Supabase aggregate function exists but app does not use it. |
| Friends | UI-only / fake data | `Models/FeedScope.swift`, `Models/Visit.swift`, `DataManager.swift` | "Friends" exists as a label/visibility value, not as a real friends surface. |
| Notifications | Missing | None | Backend notifications exist, but no screen, unread state, or APNs registration in iOS. |
| Settings | Missing | Only system Settings deep link in `MapTabView.swift` | No app settings surface for account, privacy, notifications, or logout. |
| Privacy / Terms / Company pages | Missing | None | No legal/company pages in app or repo. |

## Biggest Blockers To Private Beta

1. The app has Supabase auth/profile bootstrap, but no backend repository layer for visits, cafes, feed, or storage.
2. Local data model and Supabase schema have drifted. Example: app stores `Cafe.isFavorite` and `Cafe.wantToTry`, while Supabase stores per-user cafe state in `user_cafe_states`.
3. Photo handling is local-only. Supabase has `visit-photos` storage and `visit_photos`, but iOS does not upload or reference those URLs.
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
- Test caveat: tests are default/skeleton launch tests and do not prove Mugshot product flows.
