# Repository Map

Date: 2026-06-30

## App Type

This repository is a native iOS SwiftUI app.

There is no web frontend stack here: no React, Next.js, Vite, TypeScript, Tailwind, package.json, or npm scripts.

There is no local Supabase folder or migration source in this repo.

Phase 2A added native Supabase client wiring for auth/session/profile bootstrap only. The rest of the app data surfaces are still local/demo.

Phase 1.6 compared this native repo with the existing web reference app. The web app lives outside this repo and was inspected only as product/backend reference. See:

- `docs/WEB_APP_REFERENCE_AUDIT.md`
- `docs/FEATURE_PARITY_MATRIX.md`
- `docs/IOS_PARITY_ROADMAP.md`
- `docs/MUGSHOT_PRODUCT_SPEC.md`
- `docs/WEB_TO_IOS_TRANSLATION_NOTES.md`

## Top-Level Structure

```text
testMugshot/
  Config/
    Info.plist
    SupabaseConfig.xcconfig
    SupabaseConfig.local.xcconfig.example
  testMugshot.xcodeproj/
  testMugshot/
    Assets.xcassets/
    Design/
    Models/
    Services/
    Utilities/
    Views/
    ContentView.swift
    testMugshotApp.swift
  testMugshotTests/
  testMugshotUITests/
```

## Main Entry Points

- `testMugshot/testMugshotApp.swift`
  - App entry point.
  - Owns `DataManager.shared` as `@StateObject`.
  - Shows `MugshotRootView`, which checks Supabase auth/session state before deciding signed-out vs signed-in shell.
  - Locks app to light mode.

- `testMugshot/Views/Auth/MugshotRootView.swift`
  - App-level auth gate.
  - Restores Supabase session on launch.
  - Shows auth/config/loading states or the existing `MainTabView`.
  - Seeds local sample data after successful auth so prototype tabs remain populated.

- `testMugshot/Views/MainTabView.swift`
  - Main tab shell.
  - Tabs: Map, Feed, Add, Saved, Profile.
  - Passes shared `DataManager` into all tab surfaces.
  - Uses `TabCoordinator` for switching to Feed after visit creation and jumping from Map/Saved into Add.

- `testMugshot/ContentView.swift`
  - Compatibility placeholder only.
  - Displays `Text("Mugshot")`.

## Models

- `Models/AppData.swift`
  - Single codable container for all local app state.
  - Holds `currentUser`, `cafes`, `visits`, `ratingTemplate`, and `hasCompletedOnboarding`.

- `Models/User.swift`
  - Local user profile: id, username, display name, location, avatar image path, bio.

- `Models/Cafe.swift`
  - Local cafe identity plus user state mixed together.
  - Fields include name, location, address, favorite flag, want-to-try flag, average rating, visit count, map URL, website URL, place category.
  - Extends `CLLocationCoordinate2D` to be `Codable`, which currently builds with a warning.

- `Models/Visit.swift`
  - Visit model with drink type, custom drink, caption, private notes, photo path strings, poster photo index, ratings dictionary, overall score, visibility, likes, comments, and mentions.
  - Custom Codable keeps backward compatibility with older field names.

- `Models/RatingTemplate.swift`
  - Local customizable rating categories and weights.
  - Defaults: Presentation, Value, Taste, Ambiance.

- `Models/FeedScope.swift`
  - Feed toggle enum: Friends and Everyone.

- `Models/SupabaseUserProfile.swift`
  - DTO for `public.users`.
  - Maps remote profile fields back into the existing local `User` model.

## Services

- `Services/DataManager.swift`
  - Core local data store.
  - Reads/writes a single encoded `AppData` blob in `UserDefaults` under `MugshotAppData`.
  - Handles cafes, visits, likes, comments, rating template, onboarding, and stats.
  - No direct network calls.
  - Accepts the authenticated Supabase profile as the current local user after sign-in.

- `Services/Supabase/SupabaseConfiguration.swift`
  - Loads client-safe Supabase URL/key values from environment or `Info.plist`.
  - Rejects missing placeholders and obvious secret/service-role keys.

- `Services/Supabase/SupabaseClientProvider.swift`
  - Creates and caches the official Supabase Swift client.

- `Services/Supabase/AuthService.swift`
  - Wraps Supabase Auth sign in, sign up, sign out, and session restore.

- `Services/Supabase/ProfileService.swift`
  - Fetches the signed-in user's `public.users` row.
  - Falls back to a safe upsert if the auth trigger did not create a profile row.

- `Services/Supabase/AppAuthModel.swift`
  - Main-actor app auth state model used by SwiftUI.
  - Bridges auth/profile state into `DataManager`.

- `Services/SampleDataSeeder.swift`
  - Seeds five San Francisco cafes and four sample visits after onboarding when local cafes and visits are empty.
  - This makes the app feel populated even without backend data.

- `Services/PhotoCache.swift`
  - Stores selected photos in memory and as JPEGs under the app documents folder `VisitPhotos`.
  - Used by visit feed/detail/cafe views.
  - Not backed by cloud storage.

- `Services/MapSearchService.swift`
  - Uses `MKLocalSearch` for cafe/address search.
  - Sorts results by distance to the search region center.

- `Services/LocationManager.swift`
  - Wraps CoreLocation permission and current location updates.
  - Location usage description is present in generated Info.plist settings.

- `Services/TabCoordinator.swift`
  - Tracks selected tab and exposes `switchToFeed()`.

## Views

- `Views/Onboarding/OnboardingView.swift`
  - Welcome step.
  - Local username/location step.
  - Rating preference display step.
  - Completes onboarding by writing local `User` and rating template.
  - Not currently used as the first-launch auth gate after Phase 2A.

- `Views/Auth/AuthEntryView.swift`
  - Minimal email/password sign-in and create-account UI.
  - Also shows safe local-config instructions if Supabase config is missing.

- `Views/Map/MapTabView.swift`
  - Full-screen `MKMapView` bridge.
  - Shows local cafe annotations for cafes with location and at least one visit.
  - Inline cafe search with Apple Maps results.
  - Bottom sheet cafe card with favorite, want-to-try, log visit, details, and recent visits.

- `Views/Add/AddTabView.swift`
  - Visit compose flow.
  - Cafe search, drink type, photos picker, ratings, caption, notes, visibility, validation, save.
  - Saves locally through `DataManager`.
  - Opens `VisitDetailView` after save.

- `Views/Feed/FeedTabView.swift`
  - Feed header with Friends/Everyone toggle.
  - Visit cards with photo, cafe, drink, caption, like count, comment count.
  - Visit detail full-screen view.
  - Visit detail supports likes, comments, edit, and delete locally.
  - Search icon is visible but not implemented.

- `Views/Saved/SavedTabView.swift`
  - Saved/Favorites/Want-to-Try/All Cafes lists.
  - Cafe cards with log visit, map, website, details.
  - Cafe detail view with hero photo, stats, actions, and recent visits.

- `Views/Profile/ProfileTabView.swift`
  - Current local profile with avatar initial, username, location, stats, journey indicator, recent visits, top cafes, favorites, wishlist.
  - No edit profile or settings.

- `Views/Components/PhotoImageView.swift`
  - Loads local cached/disk photos by photo path key.

- `Views/Components/MentionText.swift`
  - Highlights `@username` mentions in text.

## Design System

- `Design/BrandColors.swift`
  - Central color definitions.

- `Design/DesignSystem.swift`
  - Button styles, card style, spacing/radius/shadow constants.

## Utilities

- `Utilities/MentionParser.swift`
  - Regex parser for `@username` mentions.
  - Does not resolve mentions to real users.

## Tests

- `testMugshotTests/testMugshotTests.swift`
  - Default Swift Testing placeholder.

- `testMugshotUITests/testMugshotUITests.swift`
  - Default app launch test and launch performance test.

- `testMugshotUITests/testMugshotUITestsLaunchTests.swift`
  - Default launch screenshot test.

Current tests do not validate core Mugshot journeys.

## Dependencies And Risk

Third-party dependency:

- Supabase Swift package from `https://github.com/supabase/supabase-swift`.

Main platform dependencies:

- SwiftUI
- UIKit
- Combine
- MapKit
- CoreLocation
- PhotosUI

Risks:

- iOS deployment target is `18.5`, which excludes older iPhones. This may be intentional, but it is high for beta reach.
- Display name currently appears as `Mugshott` in the modified Xcode project file.
- Custom `CLLocationCoordinate2D: Codable` conformance compiles but warns that it may conflict with future Apple conformance.
- `PhotoCache` mutates an in-memory dictionary from a concurrent queue in at least one read path, which deserves cleanup before heavier media use.
- Supabase package resolution is now part of the Xcode/SwiftPM build.
- `Config/SupabaseConfig.local.xcconfig` is intentionally ignored and must not be committed.

## How To Run Locally

Known safe validation:

- Open `testMugshot.xcodeproj` in Xcode and run scheme `testMugshot`.
- Create `Config/SupabaseConfig.local.xcconfig` from the example file before running auth flows.
- XcodeBuildMCP build was configured with:
  - project: `testMugshot.xcodeproj`
  - scheme: `testMugshot`
  - simulator: iPhone 17 Pro
  - configuration: Debug

Validation performed:

- Simulator build/run passed.
- Simulator login and session restore passed.
- Simulator tests passed: 4 passed, 0 failed.

There are no npm/yarn/pnpm commands.

## Service Layer Reality

Today there are two service areas:

- Local prototype/content state: `DataManager` plus `PhotoCache`.
- Supabase auth/profile state: `AppAuthModel`, `AuthService`, `ProfileService`, and `SupabaseClientProvider`.

What now exists:

- Supabase client setup.
- Auth/session service.
- Current-user profile bootstrap.

What is still missing:

- Cafe repository.
- Visit repository.
- Storage upload service.
- Feed query service.
- Friends service.
- Notifications/device token service.
- Analytics service.
- Offline/sync conflict strategy.

Recommended implementation approach:

Keep `DataManager` as the local/mock adapter for now. Add a small protocol-backed repository layer and migrate one journey to Supabase at a time instead of replacing the app wholesale.
