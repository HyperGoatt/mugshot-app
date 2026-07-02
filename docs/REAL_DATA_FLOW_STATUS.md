# Real Data Flow Status

Date: 2026-07-02

Overall status: the signed-in personal journal loop is real-data-backed enough for beta hardening. The app still mixes remote truth and local/demo shell data, so beta work should reduce confusion before adding major social features.

| Surface | Current data source | Status | Evidence | Next step |
| --- | --- | --- | --- | --- |
| App launch/auth gate | Supabase Auth | Real Supabase-backed | `MugshotRootView`, `AppAuthModel`, `AuthService` | Add richer tests for auth state transitions |
| Sign in/sign up/sign out | Supabase Auth | Real Supabase-backed | `AuthEntryView`, `AuthService` | Improve email-confirmation and error states |
| Session restore | Supabase Auth session | Real Supabase-backed | `AppAuthModel.restoreSession` | Keep in smoke checklist |
| Current user profile | `public.users` | Real Supabase-backed | `ProfileService.bootstrapProfile`, `SupabaseUserProfile.localUser` | Add username collision handling |
| Profile text edit | `public.users` | Real Supabase-backed | `ProfileService.updateProfile`, profile edit sheet | Add validation and better errors |
| Profile media | Local/avatar path only | Missing remote write | No Storage profile media service in active app | Defer until profile-media policies are reviewed |
| Add Visit | `public.visits`, `public.cafes`, optional `visit_photos` | Real Supabase-backed for signed-in users | `AddTabView`, `VisitService`, `CafeService`, `VisitPhotoUploadService` | Continue no-photo/photo smoke validation |
| Visit photos | Supabase Storage `visit-photos`, `public.visit_photos` | Real Supabase-backed for signed-in users | `VisitPhotoUploadService.uploadPhotos`, `VisitService.attachPhotoURLs` | Add cleanup for uploaded-but-unattached partial failures |
| Profile Recent | `public.visits`, `public.cafes` | Real Supabase-backed | `VisitService.fetchRecentVisits` | Make profile stats/top cafes remote-backed too |
| Feed | `public.visits`, `public.users`, `public.cafes` | Partially Supabase-backed | `VisitService.fetchFeedVisits`; social mutations missing | Clarify read-only social actions and friend scope |
| Remote Visit Detail | `public.visits`, `visit_photos`, `likes`, `comments`, `users`, `cafes` | Partially Supabase-backed | `VisitService.fetchVisitDetail`, `RemoteVisitDetailView` | Add owner edit/delete, then like/comment mutations |
| Map | MapKit plus local cafes plus `user_cafe_states` sync | Partially Supabase-backed | `MapTabView`, `CafeStateService` | Improve discovery/search and remote/local state clarity |
| Saved | `user_cafe_states` plus local cafe shell | Real Supabase-backed for state | `SavedTabView`, `CafeStateService.fetchCafeStates` | Add remote aggregates and better state-only copy |
| Cafe Detail | Local shell plus remote cafe visits/state | Partially Supabase-backed | `VisitService.fetchCafeVisits`, `CafeStateService` | Add aggregate stats/popular drinks/friend context |
| Likes/comments | Reads from Supabase; local mutations only | Partially Supabase-backed | Remote detail reads counts/comments; local detail mutates local visits | Implement remote like/comment mutations later |
| Friends | None in active native app | Missing | No Friends view in active tab shell | Defer until social mutations and privacy are ready |
| Notifications | None in active native app | Blocked | Security docs flag old trigger/function path | Rebuild backend safely before UI |
| Settings/legal/about | None | Missing | No Settings root/legal screens | Add before external beta |
| Demo/local data | `UserDefaults`, `SampleDataSeeder`, `PhotoCache` | Working but local/demo only | `DataManager`, `SampleDataSeeder` | Clearly separate demo data from remote truth |

## Fresh Validation

- Build/run: passed on iPhone 17 Pro simulator, iOS 26.2.
- Tests: passed, 20 passed, 0 failed.
- Screenshot: Map launch state captured with tabs, search, pins, and location-off banner visible.

## Most Important Caveat

The core signed-in visit loop is real. The broader social/cafe/profile shell is not fully real yet. Product copy and UI affordances should reflect that during beta.
