# Real Data Flow Status

Date: 2026-07-03

Overall status: the signed-in personal journal loop is real-data-backed enough for beta hardening. The app still mixes remote truth and local/demo shell data, so beta work should reduce confusion before adding major social features.

| Surface | Current data source | Status | Evidence | Next step |
| --- | --- | --- | --- | --- |
| App launch/auth gate | Supabase Auth | Real Supabase-backed | `MugshotRootView`, `AppAuthModel`, `AuthService` | Add richer tests for auth state transitions |
| Sign in/sign up/sign out | Supabase Auth | Real Supabase-backed | `AuthEntryView`, `AuthService` | Improve email-confirmation and error states |
| Session restore | Supabase Auth session | Real Supabase-backed | `AppAuthModel.restoreSession` | Keep in smoke checklist |
| Current user profile | `public.users` | Real Supabase-backed | `ProfileService.bootstrapProfile`, `SupabaseUserProfile.localUser` | Add username collision handling |
| Profile text edit | `public.users` | Real Supabase-backed | `ProfileService.updateProfile`, profile edit sheet | Add validation and better errors |
| Profile media | Local/avatar path only | Missing remote write | No Storage profile media service in active app | Defer until profile-media policies are reviewed |
| Add Visit | `public.visits`, `public.cafes`, required signed-in `visit_photos` | Real Supabase-backed for signed-in users | `AddTabView`, `VisitService`, `CafeService`, `VisitPhotoUploadService` | Complete manual/picker-capable fresh photo smoke before beta |
| Visit photos | Supabase Storage `visit-photos`, `public.visit_photos` | Real Supabase-backed for signed-in users | `VisitPhotoUploadService.uploadPhotos`, `VisitService.attachPhotoURLs` | Add cleanup for uploaded-but-unattached partial failures |
| Profile Recent/stats/top cafes | `public.visits`, `public.cafes` | Real Supabase-backed for signed-in users | `VisitService.fetchRecentVisits`, `RemoteProfileStats` | Add pagination/windowing beyond recent 100 visits |
| Feed | `public.visits`, `public.users`, `public.cafes`, `likes`, `comments`, `user_cafe_states` | Partially Supabase-backed | `VisitService.fetchFeedVisits`, quick like/save controls; friend graph semantics limited | Keep Friends scope narrow until graph exists |
| Remote Visit Detail | `public.visits`, `visit_photos`, `likes`, `comments`, `users`, `cafes`, `user_cafe_states` | Real Supabase-backed | `VisitService.fetchVisitDetail`, like/comment, owner edit/delete, save cafe | Smoke RLS with beta accounts |
| Map | MapKit plus local cafes plus `user_cafe_states` sync | Partially Supabase-backed | `MapTabView`, `CafeStateService` | Improve discovery/search and remote/local state clarity |
| Saved | `user_cafe_states` plus local cafe shell | Real Supabase-backed for state | `SavedTabView`, `CafeStateService.fetchCafeStates` | Add remote aggregates and better state-only copy |
| Cafe Detail | Local shell plus remote cafe visits/state | Partially Supabase-backed | `VisitService.fetchCafeVisits`, `CafeStateService` | Add aggregate stats/popular drinks/friend context |
| Likes/comments | `public.likes`, `public.comments` | Real Supabase-backed | `VisitService.toggleLike`, `VisitService.addComment`, remote detail/feed state helpers | Add moderation/reporting later; keep notifications deferred |
| Friends | None in active native app | Missing | No Friends view in active tab shell | Defer until social mutations and privacy are ready |
| Notifications | None in active native app | Blocked | Security docs flag old trigger/function path | Rebuild backend safely before UI |
| Settings/legal/about | Native Settings shell | Working | `SettingsView`, `SettingsDestination` | Replace placeholder legal text with reviewed beta copy |
| Demo/local data | `UserDefaults`, `SampleDataSeeder`, `PhotoCache` | Working but local/demo only | `DataManager`, `SampleDataSeeder` | Clearly separate demo data from remote truth |

## Fresh Validation

- Build/run: passed on iPhone 17 Pro simulator, iOS 26.2 through XcodeBuildMCP.
- Tests: passed, including 22 focused unit tests plus default UI launch/performance tests.
- Add Visit UI: signed-in form shows photo-required copy and a 5-step progress state including Photo.
- Remote read check: public Supabase read found 3 photo-backed visits and 6 `visit_photos` rows; top existing photo smoke was `Codex photo upload smoke 2026-07-01 1533`.
- Blocked smoke: XcodeBuildMCP tap automation did not present PhotosPicker after simulator media seeding, so the requested fresh photo-backed creation smoke still needs manual/picker-capable validation.

## Most Important Caveat

The core signed-in visit loop is real. The broader social/cafe/profile shell is not fully real yet. Product copy and UI affordances should reflect that during beta.
