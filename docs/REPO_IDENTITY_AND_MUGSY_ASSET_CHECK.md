# Repo Identity and Mugsy Asset Check

Checkpoint date: 2026-07-01

Update: the broader repo/branch source-of-truth pass is documented in `docs/REPO_BRANCH_RECONCILIATION.md`. That pass keeps `/Users/joe.rosso/Desktop/Projects/testMugshot` as the active implementation repo and treats `/Users/joe.rosso/Documents/mugshot-app` as the best selective-harvest reference for Mugsy assets and older native screens.

## Current Repo

- Path: `/Users/joe.rosso/Desktop/Projects/testMugshot`
- Remote: `https://github.com/HyperGoatt/mugshot-app.git`
- Branch: `main`
- Latest commit: `49350ed Add auth and profile foundation tests`
- Working tree: dirty from the current native/Supabase checkpoint work; branch is ahead of `origin/main` by 5 commits.

This is a native SwiftUI iOS repo with `testMugshot.xcodeproj`, app target `testMugshot`, Supabase Swift package integration, local tests, and the recent Supabase auth/profile/read-path work. For the current Phase 2B implementation thread, this appears to be the active intended iOS rebuild repo.

Important caveat: it is not the most complete local native Mugshot codebase. A separate local repo at `/Users/joe.rosso/Documents/mugshot-app` has the same Git remote, is on branch `Auth`, and contains substantially more native UI, widgets, and mascot assets.

## Current Repo Asset Findings

Searches in `/Users/joe.rosso/Desktop/Projects/testMugshot` for `Mugsy`, `mugsy`, `Fun Time`, image files, asset catalog references, and empty-state strings found:

- No `Mugsy` or `mugsy` references.
- No `Fun Time` or `fun time` folder.
- No PNG/JPG/WebP/SVG/PDF image assets in the current repo.
- `testMugshot/Assets.xcassets` exists, but currently contains only:
  - `AppIcon.appiconset`
  - `AccentColor.colorset`
  - root `Contents.json`
- Empty states are plain text/SF Symbols today, for example:
  - Profile recent visits: `No real visits yet` / `No visits yet`
  - Favorites: `No favorites yet`
  - Feed/photo placeholders: SF Symbols such as `photo`, `cup.and.saucer.fill`, `star.fill`
  - Onboarding welcome: text-only `Mugshot` / `Capture every sip.`

The Xcode project uses a file-system-synchronized root group for the `testMugshot` folder, so assets placed under `testMugshot/Assets.xcassets` should be included by the app target. However, Mugsy assets are not present there now.

## Mugsy Assets Found Elsewhere

Two local folders contain a `fun time` folder:

- `/Users/joe.rosso/Documents/mugshot-app/fun time`
- `/Users/joe.rosso/Documents/mugshot-app-main/fun time`

Both contain Mugsy PNGs:

- `Mugsy-no-friends.png`
- `Mugsy-no-favorites.png`
- `Mugsy-no-wishlist.png`
- `Mugsy-no-cafes.png`
- `Mugsy-spin.png`
- `Mugsy-spin-celebrate.png`
- `Mugsy-coming-soon.png`
- `Mugshot-launch-screen.png`

The more useful source is `/Users/joe.rosso/Documents/mugshot-app`, because it is a Git repo:

- Path: `/Users/joe.rosso/Documents/mugshot-app`
- Remote: `https://github.com/HyperGoatt/mugshot-app.git`
- Branch: `Auth`
- Latest commit: `bbf99ca craft sip`

That repo has the Mugsy files already imported into `testMugshot/Assets.xcassets` as image sets:

- `MugsyNoFriends.imageset`
- `MugsyNoFavorites.imageset`
- `MugsyNoWishlist.imageset`
- `MugsyNoCafes.imageset`
- `MugsySpin.imageset`
- `MugsySpinCelebrate.imageset`
- `MugsyComingSoon.imageset`

It also contains `DreamingMug.imageset`, `BookmarkMug.imageset`, and `Mugshot Launch Screen.imageset`.

Because `/Users/joe.rosso/Documents/mugshot-app` also uses a file-system-synchronized Xcode root group for `testMugshot`, those asset catalog image sets should be included in that app target.

## Native Usage Found In The More Complete Repo

`/Users/joe.rosso/Documents/mugshot-app` uses Mugsy in native SwiftUI:

- Friends empty state:
  - `Views/Friends/FriendsListView.swift`
  - `Image("MugsyNoFriends")`
- Feed friends empty state:
  - `Views/Feed/FeedTabView.swift`
  - `Image("MugsyNoFriends")`
- Saved empty states:
  - `Views/Saved/SavedTabView.swift`
  - `MugsyNoFavorites`
  - `MugsyNoWishlist`
  - `MugsyNoCafes`
- Discover / spin flow:
  - `Views/Discover/Components/SpinForASpotView.swift`
  - `Image("MugsySpin")`
  - `Image("MugsySpinCelebrate")`
- Widget design system:
  - `MugshotWidgets/Shared/WidgetDesignSystem.swift`
  - `WidgetMugsyIcon`, currently documented as an SF Symbol placeholder for Mugsy.

This confirms the remembered product direction: Mugsy belongs in friendly empty states and playful chooser/onboarding-adjacent moments.

## Web App Reference

Two likely web/PWA references were checked:

- `/Users/joe.rosso/mugshot-PWA`
  - Remote: `https://github.com/HyperGoatt/mugshot-520470e9.git`
  - Branch: `main`
  - Latest commit: `431b235 Refactor AddVisit component state management`
  - Has `src/assets/mugsy-download-appstore.png`.
  - Names Mugsy in `SpinForSpotSheet.tsx`: `Let Mugsy choose your next cafe` and `Mugsy chose...`.
  - Feed/friends empty states are plain text, not Mugsy illustrations.
- `/Users/joe.rosso/mugshot/mugshot`
  - Remote: `https://github.com/HyperGoatt/mugshot.git`
  - Branch: `main`
  - Latest commit: `7d81585 Optimize performance across the application...`
  - No Mugsy image assets found in the checked app files.
  - Empty states appear text/icon based.

Conclusion: the strongest Mugsy empty-state reference is the more complete native iOS repo, not the web app.

## Where Mugsy Should Appear In The Current iOS App

Based on the more complete native reference and product memory, Mugsy should eventually be used in:

- Friends: no friends / no friend activity.
- Saved:
  - no favorites
  - no want-to-try cafes
  - no saved/library cafes
- Profile:
  - no visits
  - profile with no activity
- Feed:
  - empty friends feed
  - possibly empty everyone feed, with different copy.
- Discover / Map:
  - spin/chooser flow, if/when brought back.
- Onboarding/welcome:
  - optional brand warmth, especially first-run or launch/welcome moments.

For Phase 2B specifically, the relevant near-term placement is the no-visits state after real Add Visit is wired, but implementation should focus on the Supabase write path first.

## Recommendation

Continue Phase 2B in `/Users/joe.rosso/Desktop/Projects/testMugshot`; it is the active native Supabase rebuild repo and already contains the recent auth/profile/read-path work.

Before implementing Mugsy UI polish, copy the project-owned Mugsy image sets from `/Users/joe.rosso/Documents/mugshot-app/testMugshot/Assets.xcassets` into the current repo's `testMugshot/Assets.xcassets`, then add a small reusable native empty-state component that can use those assets consistently. Do that as a tiny asset/design slice, not during the Add Visit write-path implementation.

Do not switch wholesale to `/Users/joe.rosso/Documents/mugshot-app` without a deliberate branch/repo reconciliation step. It appears more complete visually and functionally, but the current Desktop repo is the one already aligned with the active Supabase rebuild work.
