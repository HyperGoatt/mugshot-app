# iOS Simulator Testing

Date: 2026-06-30

Purpose: Phase 1.5 local loop setup for visually testing Mugshot in the iOS Simulator from Codex.

Phase 2A update: this same loop now also validates native Supabase auth/session/profile bootstrap.

## Current Status

Live Xcode/simulator testing is available through XcodeBuildMCP and was confirmed on a booted iPhone 17 Pro simulator.

Phase 2B/2D update on 2026-07-02:

- XcodeBuildMCP tests passed after the latest core-loop hardening pass: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on the iPhone 17 Pro simulator.
- Add Visit showed the signed-in photo target near the top of the form after moving Photos above cafe/drink fields.
- The app now includes `NSPhotoLibraryUsageDescription`.
- XcodeBuildMCP tap and lower-level touch events on the visible PhotosPicker target did not transition into an inspectable system Photos picker, and no app/runtime log error appeared. Treat this as an automation limitation.
- Computer Use coordinate-click validation on the visible Simulator did open the native Photos picker, selected a seeded simulator image, returned to Add Visit with a thumbnail, saved a real photo-backed Supabase visit, and verified the photo in remote Visit Detail after app relaunch.

Add Visit polish validation on 2026-07-02:

- XcodeBuildMCP build/run passed after the mockup-led Add Visit polish.
- XcodeBuildMCP tests passed: 20 passed, 0 failed.
- The polished Add Visit screen rendered the new "Log a Sip" header, photo-first library target, progress card, summary strip, drink chips, rating score panel, and bottom padding above the tab bar.
- A no-photo smoke through the polished form created a real Supabase visit and opened remote Visit Detail.
- During this run, XcodeBuildMCP still did not open the system Photos picker and Computer Use could not attach to the Simulator window, so photo-backed validation relies on the unchanged upload path and the earlier completed picker smoke.

Visit Detail/Profile Recent polish validation on 2026-07-02:

- XcodeBuildMCP tests passed: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Profile Recent loaded real signed-in Supabase visits and showed the richer remote cards for both `Codex Polish Cafe` and `Codex Photo Loop Cafe`.
- Tapping the no-photo Profile Recent card opened remote Visit Detail with the new "Sip saved" confirmation, no-photo placeholder, cafe/drink/caption summary, and metadata.
- Tapping the photo-backed Profile Recent card opened remote Visit Detail with the new "Sip saved" confirmation, large remote poster image, score badge, cafe/drink/caption summary, and private visibility.
- Screenshots were captured outside the repo:
  - No-photo detail: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_f3c179cc-2580-4dd5-b1df-a2e96da5f72c.jpg`
  - Photo-backed detail: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_d6c6e217-7953-4d22-b7dd-190e28729814.jpg`

Feed card polish validation on 2026-07-02:

- XcodeBuildMCP tests passed after the final Feed polish: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Feed Friends loaded real signed-in Supabase visits and showed the polished no-photo `Codex Polish Cafe` remote card.
- Tapping the Friends card opened the existing remote Visit Detail sheet.
- Feed Everyone updated the subtitle to "Fresh public sips" and showed public remote cards.
- Scrolling Everyone showed the photo-backed `Codex Photo Smoke Cafe` card with the large poster treatment; tapping it opened remote Visit Detail.
- Screenshots were captured outside the repo:
  - Friends no-photo card: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_abc33a26-d3f7-4cb3-8da8-5690ab6a30d5.jpg`
  - Everyone photo-backed card: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_15c69ade-91ff-4b42-8f5b-5382dd63c71d.jpg`

Saved/Cafe Detail polish validation on 2026-07-02:

- XcodeBuildMCP tests passed after the final Saved/Cafe Detail polish: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Saved Favorites loaded signed-in synced cafe state and showed the polished `Ritual Coffee Roasters` card.
- Cafe Detail opened from Saved, showed the padded identity card, stat cards, action grid, and recent visits section.
- Tapping the recent visit row opened the existing visit detail flow. For `Ritual Coffee Roasters` this was the preserved local fallback row, matching the existing state-only cafe behavior.
- Saved Want to Try showed the planning subtitle and synced Want-to-Try cards.
- Screenshots were captured outside the repo:
  - Saved Favorites: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_4a548b82-c9f6-4d7b-9929-72a54bd2ab80.jpg`
  - Cafe Detail: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_95b0d022-2874-41fe-8359-63ae000a7fc8.jpg`
  - Want to Try: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_096e7538-fc0c-40b3-9146-c3455583e863.jpg`

Map bottom-sheet polish validation on 2026-07-02:

- XcodeBuildMCP tests passed after the Map sheet polish: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Apple Maps search returned `Can't reach Apple Maps right now. Try again in a bit.` during this smoke, so the sheet was opened by tapping a visible map pin through Computer Use.
- The polished Map sheet opened for `Ritual Coffee Roasters` with synced Favorite/Want-to-Try chips, stat cards, action grid, and recent visit row.
- The Details action opened the existing full Cafe Detail sheet.
- Screenshot was captured outside the repo:
  - Map sheet: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_f68675bb-0c20-4f51-9e15-525a8eaceb30.jpg`

Beta-readiness audit validation on 2026-07-02:

- XcodeBuildMCP tests passed after the audit fix: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Fresh screenshots were saved in `docs/audits/beta-readiness-2026-07-02/screenshots/`.
- Captured Map launch, Feed Friends, remote Visit Detail, Add Visit top/middle/lower/save states, Saved Favorites, Cafe Detail from Saved, Profile top, and Profile Recent.
- The audit found one Add Visit issue: the incomplete save button looked available while the progress card still showed `0 of 4 ready`.
- The Add Visit CTA now says `Complete Required Details` and is disabled until Cafe, Drink, Rating, and Caption are complete.
- After the fix, XcodeBuildMCP's semantic snapshot no longer exposed the incomplete CTA as a tappable target.
- The fresh Map bottom sheet capture was limited: Computer Use could read the Simulator window and map pins, but coordinate clicks returned a window error in this session. The immediately preceding Map polish pass had already validated the sheet and Details drill-in.

Codex confirmed these simulator tools are available:

- list simulators
- set session defaults
- build for simulator
- build, install, and launch on simulator
- capture screenshots
- inspect semantic UI snapshots
- tap UI elements
- capture runtime log path during launch

Confirmed working:

- Build, install, and launch on the booted simulator.
- Capture screenshots.
- Capture semantic UI snapshots.
- Read launch/runtime log files.
- Tap through primary app surfaces, with occasional second taps needed on the bottom tab bar.
- Sign in through the native auth screen.
- Relaunch and confirm Supabase session restore.

Partially blocked:

- Bottom tab-bar automation can be intermittent at the simulator bottom edge. Some taps succeed on the second attempt; a few taps from Saved did not switch tabs even though the tool reported success.
- Computer Use coordinate-click fallback was available for the Phase 2D picker smoke and worked as a backup for system Photos picker interaction.

## Project To Open

Open this Xcode project:

```text
/Users/joe.rosso/Desktop/Projects/testMugshot/testMugshot.xcodeproj
```

This is an Xcode project, not an Xcode workspace.

## Scheme

Run this scheme:

```text
testMugshot
```

## Bundle Identifier

Current app bundle identifier:

```text
co.mugshot.app.testMugshot
```

## Minimum iOS Target

Current minimum iOS deployment target:

```text
iOS 18.5
```

## Recommended Simulator

Use this simulator first:

```text
iPhone 17 Pro (iOS 26.2)
Simulator ID: 520A057F-F189-4F5E-A5EF-230E8F4704B4
```

This was the simulator target used for the successful Phase 1.5 build/run validation.

Secondary simulator used in Phase 1 build-only validation:

```text
iPhone 17 (iOS 26.2)
Simulator ID: 3CF667C9-24C1-4935-BB28-2B3E0192F7B3
```

## How To Boot The Simulator

Option A: Simulator.app

1. Open `Simulator.app`.
2. In the macOS menu bar, choose `File` -> `Open Simulator`.
3. Choose `iOS 26.2` -> `iPhone 17 Pro`.
4. Wait until the simulated iPhone home screen is visible.
5. Tell Codex: "The iPhone 17 simulator is booted."

Option B: Xcode

1. Open `/Users/joe.rosso/Desktop/Projects/testMugshot/testMugshot.xcodeproj`.
2. Select the `testMugshot` scheme.
3. Select `iPhone 17 Pro` as the run destination.
4. Press Run once, or otherwise let Xcode boot the simulator.
5. Tell Codex: "The iPhone 17 simulator is booted."

## How Codex Can Run It After The Simulator Is Booted

Once a simulator is booted, Codex can:

1. Set XcodeBuildMCP defaults to:
   - project: `/Users/joe.rosso/Desktop/Projects/testMugshot/testMugshot.xcodeproj`
   - scheme: `testMugshot`
   - simulator: the booted simulator
   - configuration: `Debug`
   - bundle id: `co.mugshot.app.testMugshot`
2. Build, install, and launch the app.
3. Capture a screenshot.
4. Inspect the UI tree.
5. Tap through tabs and reachable screens.
6. Summarize runtime launch logs and meaningful warnings/errors.

## Phase 1 Build Command That Passed

Phase 1 validation used XcodeBuildMCP with:

```text
build_sim
project: testMugshot.xcodeproj
scheme: testMugshot
simulator: iPhone 17
configuration: Debug
```

The build passed. The app also passed the current skeleton simulator tests, but those tests do not validate real Mugshot product flows.

## Phase 1.5 Live Run Results

Run target:

```text
project: /Users/joe.rosso/Desktop/Projects/testMugshot/testMugshot.xcodeproj
scheme: testMugshot
configuration: Debug
simulator: iPhone 17 Pro (iOS 26.2)
bundle id: co.mugshot.app.testMugshot
```

Build and launch result:

```text
XcodeBuildMCP build_run_sim: succeeded
App path: /Users/joe.rosso/Library/Developer/XcodeBuildMCP/workspaces/testMugshot-8ff6cf9d4260/DerivedData/testMugshot-bdc2d76cd469/Build/Products/Debug-iphonesimulator/testMugshot.app
Process id: 45927
```

Screenshots captured:

```text
Map launch screenshot:
/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_9b2ce338-17e7-4901-a9d1-7c880f7e75d3.jpg

Feed screenshot:
/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_90325feb-c2cf-4c09-a653-d2af1dd915e5.jpg
```

Launch/runtime logs:

```text
Runtime log:
/Users/joe.rosso/Library/Developer/XcodeBuildMCP/workspaces/testMugshot-8ff6cf9d4260/logs/co.mugshot.app.testMugshot_2026-06-30T22-03-27-251Z_helperpid45924_ownerpid8569_f3f12d24.log

OS log:
/Users/joe.rosso/Library/Developer/XcodeBuildMCP/workspaces/testMugshot-8ff6cf9d4260/logs/co.mugshot.app.testMugshot_oslog_2026-06-30T22-03-28-263Z_helperpid45961_ownerpid8569_a78d9171.log
```

Log summary:

- No crash was observed.
- No app-specific runtime errors were found.
- The runtime log was empty.
- The OS log only contained the log filtering/header line.

Visual state observed:

- The app launched into the Map tab, not onboarding. This simulator already had completed-onboarding local app data.
- The Map showed San Francisco, several local rating pins, a search field, a location-disabled banner, and a rating legend.
- Location access is off on this simulator; the app showed a clear banner and Settings action.
- Feed was reachable and showed seeded/local visit cards for user `joe`, with placeholder images, local scores, likes, and comments.
- The Feed UI looked polished, but the data is local/demo state.

## Phase 2A Auth/Profile Live Run Results

Run target:

```text
project: /Users/joe.rosso/Desktop/Projects/testMugshot/testMugshot.xcodeproj
scheme: testMugshot
configuration: Debug
simulator: iPhone 17 Pro (iOS 26.2)
bundle id: co.mugshot.app.testMugshot
```

Build and launch result:

```text
XcodeBuildMCP build_run_sim: succeeded
App path: /Users/joe.rosso/Library/Developer/XcodeBuildMCP/workspaces/testMugshot-8ff6cf9d4260/DerivedData/testMugshot-bdc2d76cd469/Build/Products/Debug-iphonesimulator/testMugshot.app
```

Validation performed:

- Auth screen appeared when signed out.
- Sign-in succeeded.
- Profile bootstrap succeeded against `public.users`.
- Profile tab showed the authenticated remote profile and "Supabase profile active".
- Relaunch restored the session directly into the signed-in Map tab.
- Simulator tests passed: 4 passed, 0 failed.

Screenshots captured:

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

Log summary:

- Final clean runtime logs showed no crashes or app-specific auth/profile errors.
- A previous launch crash was caused by plain `https://` syntax inside `.xcconfig`; fixed by using `https:/$()/...`.
- Latest build log had only an App Intents metadata extraction warning, which is harmless because the app does not use App Intents.

Visual state observed:

- Auth screen is simple and readable.
- Map, Feed, Add, Saved, and Profile were reachable.
- Feed now shows real Supabase-backed visit cards for signed-in Friends and Everyone scopes, and those cards open read-only remote detail sheets. Add Visit writes signed-in no-photo and photo-backed visits to Supabase, while signed-out mode remains local/demo. Saved now syncs signed-in Favorite/Want-to-Try cafe state.
- Map shows a location-disabled banner because the simulator has not granted location access.
- iOS showed a system "Save Password?" prompt immediately after first login.
- Feed and Saved showed placeholder image blocks where no local photo exists.
- Profile `Favorite` stat wrapped `Coffee` awkwardly on iPhone 17 Pro width.
- Add Visit's lower rating rows sat partly behind the tab bar at the captured scroll position.
- Saved `Details` buttons did not navigate during smoke testing.
- Map Settings opens iOS Settings, not an in-app settings screen.
- Profile shows the Supabase-backed identity plus local stats/sample data.

## Known Blockers

- 2026-07-03 private-beta readiness pass: XcodeBuildMCP build/run and `xcodebuild test` passed on iPhone 17 Pro iOS 26.2, and Add Visit showed the signed-in photo-required state. A seeded simulator image was added with `xcrun simctl addmedia`, but semantic taps on the native `PhotosPicker` control did not present the system picker, and subsequent tab/cancel taps also did not navigate despite reported tap success. Treat the fresh photo-backed Add Visit creation smoke as still requiring manual interaction or picker-capable automation.
- Bottom tab-bar automation is still intermittent from some screens. In Phase 2A testing, Map, Feed, Add, Saved, and Profile were reachable, but a few later tab taps from Saved did not switch screens even though XcodeBuildMCP reported success.
- Computer Use coordinate fallback may be needed for system Photos picker interaction because XcodeBuildMCP semantic taps do not currently open that picker reliably.
- The existing Xcode project file is already modified and sets the display name to `Mugshott`, which appears to be a typo. Do not fix this during Phase 1.5 unless launch depends on it.
- The app is now Supabase-backed for auth/profile, Add Visit, Profile Recent, Feed, remote visit detail, visit photos, and signed-in Favorite/Want-to-Try cafe state. Some Map/Saved/stat presentation still uses the existing local shell while syncing selected remote state.
- If onboarding has already been completed on the chosen simulator, the app may launch directly into the main tabs. If the simulator has no app data, it should launch into onboarding.

## What Codex Can See And Control

Codex can see:

- Available simulators and their boot/shutdown state.
- Xcode schemes and project settings.
- Build and launch results.
- Simulator screenshots.
- Semantic UI snapshots with tappable element references.
- Runtime log path from launch.

Codex cannot see:

- Manual touches you make unless the UI state is inspected after.
- Private Xcode UI state unless exposed through XcodeBuildMCP.
- Supabase-backed write behavior until the relevant app surface is wired to Supabase in a later phase.
- Mac-level coordinate clicks in Simulator unless Computer Use permissions are granted.

## Recommended Future Visual QA Loop

1. Boot `iPhone 17 Pro (iOS 26.2)`.
2. Ask Codex to build and launch through XcodeBuildMCP.
3. Codex captures the launch screenshot and UI snapshot.
4. If XcodeBuildMCP tab taps work, Codex taps through Map, Feed, Add, Saved, Profile, and reachable detail sheets.
5. If tab taps do not work, either grant Computer Use permission for Simulator coordinate clicks or manually tap the requested screen and ask Codex to inspect the resulting UI.
6. Codex saves screenshots outside the repo unless you ask for committed artifacts.
7. Codex summarizes visible issues without changing product code unless you explicitly move into an implementation phase.
