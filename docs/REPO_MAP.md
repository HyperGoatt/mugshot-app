# Repository Map

Date: 2026-06-30

## App Type

This repository is a native iOS SwiftUI app.

There is no web frontend stack here: no React, Next.js, Vite, TypeScript, Tailwind, package.json, or npm scripts.

There is no complete local Supabase migration source in this repo. The repo does include manual Supabase SQL/runbook files under `supabase/manual/`.

Phase 2A added native Supabase client wiring for auth/session/profile bootstrap. Later Phase 2B/2D work added real signed-in visit creation, visit photo upload/attach, Feed/Profile/Cafe read paths, and Favorite/Want-to-Try cafe-state persistence.

Phase 2B real-visit preflight added documentation plus safe read-backed slices. The risky `public.visits` insert trigger was quarantined after signing-key rotation, and Profile Recent, Feed, and remote visit detail now read real Supabase data. See `docs/PHASE_2B_REAL_VISITS.md`, `docs/REAL_DATA_FLOW_STATUS.md`, and `docs/VISIT_WRITE_BLOCKER.md`.

Repo reconciliation checkpoint: multiple local native Mugshot repos/branches exist. The active source of truth remains this Desktop repo, while `/Users/joe.rosso/Documents/mugshot-app` is the best selective-harvest reference for older native screens and Mugsy assets. See `docs/REPO_BRANCH_RECONCILIATION.md`.

Phase 1.6 compared this native repo with the existing web reference app. The web app lives outside this repo and was inspected only as product/backend reference. See:

- `docs/WEB_APP_REFERENCE_AUDIT.md`
- `docs/FEATURE_PARITY_MATRIX.md`
- `docs/IOS_PARITY_ROADMAP.md`
- `docs/MUGSHOT_PRODUCT_SPEC.md`
- `docs/WEB_TO_IOS_TRANSLATION_NOTES.md`
- `docs/PHASE_2B_REAL_VISITS.md`
- `docs/REAL_DATA_FLOW_STATUS.md`
- `docs/VISIT_WRITE_BLOCKER.md`
- `docs/REPO_BRANCH_RECONCILIATION.md`

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
  - Conforms to `Equatable` so SwiftUI can reload remote Feed scopes deliberately.

- `Models/SupabaseUserProfile.swift`
  - DTO for `public.users`.
  - Maps remote profile fields back into the existing local `User` model.

- `Models/SupabaseCafe.swift`
  - DTO for lightweight `public.cafes` rows used by real visit summaries.

- `Models/SupabaseVisit.swift`
  - DTOs for lightweight `public.visits`, `visit_photos`, `likes`, and `comments` rows.
  - Provides `RemoteVisitSummary`, `RemoteVisitDetail`, and `RemoteVisitComment` view models.

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

- `Services/Supabase/CafeService.swift`
  - Fetches, resolves, and creates lightweight cafe rows for remote visit summaries and new visit/state writes.

- `Services/Supabase/VisitService.swift`
  - Creates real signed-in visits after resolving/creating the remote cafe.
  - Fetches the signed-in user's recent Supabase visits for Profile.
  - Fetches signed-in Feed visits for Friends and Everyone scopes.
  - Fetches read-only remote visit detail, photos, likes, and comments.
  - Attaches uploaded photo URLs through `visit_photos` and `poster_photo_url`.
  - Hydrates visit rows with related cafe and author summaries for display.

- `Services/Supabase/CafeStateService.swift`
  - Reads and writes `user_cafe_states` for Favorite and Want-to-Try behavior.

- `Services/Supabase/VisitPhotoUploadService.swift`
  - Compresses selected images and uploads signed-in visit photos to Supabase Storage.

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
  - Signed-in mode creates real Supabase visits and optionally uploads/attaches photos.
  - Signed-out/local fallback saves through `DataManager`.
  - Opens remote Visit Detail after successful signed-in save.

- `Views/Feed/FeedTabView.swift`
  - Feed header with Friends/Everyone toggle.
  - Signed-in users see read-only remote visit cards from Supabase for Friends and Everyone scopes.
  - Remote cards are tappable buttons that open the read-only Supabase detail sheet.
  - Signed-out users still see local/demo feed cards with photo, cafe, drink, caption, like count, and comment count.
  - Local visit detail full-screen view still supports likes, comments, edit, and delete locally.
  - Remote like/comment/edit/delete mutations are not wired yet.
  - Search icon is visible but not implemented.

- `Views/Feed/RemoteVisitDetailView.swift`
  - Read-only remote visit detail sheet for Supabase visits.
  - Displays existing remote photos, cafe/context, author, ratings, caption, owner-only notes, like count, and comments with authors.

- `Views/Saved/SavedTabView.swift`
  - Saved/Favorites/Want-to-Try/All Cafes lists.
  - Cafe cards with log visit, map, website, details.
  - Cafe detail view with hero photo, stats, actions, and recent visits.

- `Views/Profile/ProfileTabView.swift`
  - Current profile with avatar initial, username, location, stats, journey indicator, recent visits, top cafes, favorites, wishlist.
  - Profile identity and text edit are Supabase-backed.
  - Recent tab reads real Supabase visits for the signed-in user and opens read-only remote detail; stats/top cafes/favorites/wishlist remain local/demo.
  - No settings screen.

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
  - Swift Testing coverage for Supabase config hygiene, profile mapping/update encoding, visit/cafe/photo payload contracts, and remote summary/detail helpers.

- `testMugshotUITests/testMugshotUITests.swift`
  - Default app launch test and launch performance test.

- `testMugshotUITests/testMugshotUITestsLaunchTests.swift`
  - Default launch screenshot test.

Current tests include lightweight remote DTO and payload mapping checks, but they still do not fully validate signed-in end-to-end journeys.

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
- Simulator tests passed.
- Simulator Profile Recent and Feed Friends/Everyone showed real Supabase-backed visit cards and opened read-only remote detail sheets.

There are no npm/yarn/pnpm commands.

## Service Layer Reality

Today there are two service areas:

- Local prototype/content state: `DataManager` plus `PhotoCache`.
- Supabase auth/profile/read state: `AppAuthModel`, `AuthService`, `ProfileService`, `CafeService`, `VisitService`, and `SupabaseClientProvider`.

What now exists:

- Supabase client setup.
- Auth/session service.
- Current-user profile bootstrap.
- Profile edit basics.
- Read-only cafe service for remote visit summaries.
- Read-only visit service for Profile Recent, Feed, and remote detail.

What is still missing:

- Cafe write/upsert repository.
- Visit write repository.
- Storage upload service.
- Remote social mutation services.
- Friends service.
- Notifications/device token service.
- Analytics service.
- Offline/sync conflict strategy.

Recommended implementation approach:

Keep `DataManager` as the local/mock adapter for now. Add a small protocol-backed repository layer and migrate one journey to Supabase at a time instead of replacing the app wholesale.
