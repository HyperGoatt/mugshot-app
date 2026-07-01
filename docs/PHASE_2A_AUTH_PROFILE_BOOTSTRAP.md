# Phase 2A Auth And Profile Bootstrap

Date: 2026-07-01

Purpose: record the native iOS Supabase auth/profile bootstrap work without starting Add Visit, Feed, Map, Friends, Notifications, or Storage implementation.

## Status

Phase 2A is implemented and simulator-smoke-tested.

Completed:

- Added the official Supabase Swift package to the app target.
- Added safe local Supabase client configuration through ignored `.xcconfig` values.
- Added app-level auth state with sign in, sign up, sign out, and session restore.
- Added `public.users` profile fetch/bootstrap for the authenticated user.
- Mapped the remote `public.users` row back into the existing local `User` model so the current tab shell can stay intact.
- Preserved local/demo Map, Feed, Add, Saved, and Profile behavior after sign-in.

Not included:

- Add Visit Supabase writes.
- Photo upload.
- Backend Feed reads.
- Map/cafe persistence.
- Friends, Notifications, Settings, profile edit, avatar/banner upload, or legal surfaces.

## Files Added

- `Config/Info.plist`
- `Config/SupabaseConfig.xcconfig`
- `Config/SupabaseConfig.local.xcconfig.example`
- `testMugshot/Models/SupabaseUserProfile.swift`
- `testMugshot/Services/Supabase/SupabaseConfiguration.swift`
- `testMugshot/Services/Supabase/SupabaseClientProvider.swift`
- `testMugshot/Services/Supabase/AuthService.swift`
- `testMugshot/Services/Supabase/ProfileService.swift`
- `testMugshot/Services/Supabase/AppAuthModel.swift`
- `testMugshot/Views/Auth/AuthEntryView.swift`
- `testMugshot/Views/Auth/MugshotRootView.swift`

## Files Updated

- `.gitignore`
- `testMugshot.xcodeproj/project.pbxproj`
- `testMugshot/Services/DataManager.swift`
- `testMugshot/testMugshotApp.swift`
- `testMugshot/Views/Profile/ProfileTabView.swift`

## Supabase Shape Verified

The native app now targets the existing `public.users` table, not a new `profiles` table.

Required profile fields:

- `id`
- `display_name`
- `username`

Useful optional profile fields already mapped:

- `bio`
- `location`
- `favorite_drink`
- `instagram_handle`
- `avatar_url`
- `banner_url`
- `website_url`

The existing `auth.users` insert trigger creates a matching `public.users` row. The iOS bootstrap still includes a safe upsert fallback for missing rows.

## Simulator Validation

Target:

```text
project: /Users/joe.rosso/Desktop/Projects/testMugshot/testMugshot.xcodeproj
scheme: testMugshot
configuration: Debug
simulator: iPhone 17 Pro (iOS 26.2)
bundle id: co.mugshot.app.testMugshot
```

Results:

- Build/run: passed.
- Login: passed.
- Profile bootstrap: passed; Profile showed the authenticated `public.users` profile and "Supabase profile active".
- Session restore: passed; app relaunched directly into the signed-in Map tab.
- Tests: passed, 4 passed / 0 failed.
- Runtime logs after final clean launches: no crashes or app-specific auth/profile errors.

Screenshots captured outside the repo:

```text
Auth screen:
/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_7719f1d6-00ae-4bdb-96b2-5498ed14f84f.jpg

Signed-in Map:
/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_83db7813-28cd-4cdc-a109-c8c6620ae630.jpg

Feed:
/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_6180d92f-9828-4ad5-9576-af51453e8aee.jpg

Add Visit:
/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_10c964d7-6cdc-43bf-a6ab-1054a7af30e9.jpg

Saved:
/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_e8d05a5d-dae3-4336-b28e-0ff9cfc9d840.jpg

Profile:
/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_12098b36-1cb5-4c29-8103-48439a6e6284.jpg

Session restore Map:
/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_f708436c-1ebd-4a92-8b2a-9223e7bc233f.jpg
```

## Known Issues

- The tab surfaces still show local/demo content after sign-in. This is intentional for Phase 2A.
- iOS may show a system "Save Password?" prompt immediately after first login.
- Feed and Saved use placeholder image blocks where no local photo exists.
- Profile `Favorite` stat wraps `Coffee` awkwardly on iPhone 17 Pro width.
- Add Visit's lower rating rows can sit partly behind the tab bar at the captured scroll position.
- Saved `Details` buttons did not navigate during smoke testing.
- The Map settings button opens iOS Settings, not an in-app settings screen.
- XcodeBuildMCP bottom-tab automation can be intermittent at the simulator bottom edge; manual simulator taps remain a useful fallback for visual QA.
- The app display name is still `Mugshott`, a pre-existing project-file change intentionally left untouched.

## Next Phase

Before Phase 2B/2C writes real visits, address or explicitly quarantine the backend security backlog, especially the visit trigger bearer-token issue.
