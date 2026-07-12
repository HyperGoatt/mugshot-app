# Bug-Fix Sprint — 2026-07-11

## Scope and baseline

- Branch: `codex/app-store-polish`
- Existing work preserved: the sprint began with modified Supabase, Feed, Map, auth-root, performance, and test files plus untracked performance/migration files. These are treated as user-owned changes.
- Baseline build: passed on iPhone 17, iOS 26.2.
- Baseline tests: 33 passed, 0 failed, 0 skipped.
- Runtime coverage: signed-in iPhone 17 and clean signed-out iPhone 16e, iOS 18.6.

## Confirmed defects

### BUG-001 — Feed search control does nothing

- Severity: Medium
- User impact: A prominent header control advertises search but provides no response, making feed discovery appear broken.
- Reproduction:
  1. Launch while signed in.
  2. Open Feed.
  3. Tap the magnifying-glass button.
- Expected: A feed search field appears and entered text filters matching sips.
- Actual: The screen does not change.
- Evidence: Simulator tap succeeded but the before/after accessibility snapshots were identical. `FeedTabView` passes an empty closure to `MugshotIconButton`.
- Likely root cause: The search affordance was shipped before its action and query state were implemented.
- Status: Fixed and verified. The header button now reveals a focused inline search row; matching and no-results states were exercised in Simulator.

### BUG-002 — Feed actions are indistinguishable to assistive technology

- Severity: High
- User impact: VoiceOver users cannot reliably distinguish opening a sip, liking, commenting, or saving its cafe.
- Reproduction:
  1. Open Feed with remote visits.
  2. Inspect a visit card with the runtime accessibility hierarchy.
- Expected: Each interactive control has an action-specific label and hint.
- Actual: Five child buttons share the same label, such as `Peach Latte at Huriyali Gardens`.
- Evidence: iPhone 17 runtime snapshot exposed five targets with the identical visit label, including the bookmark target.
- Likely root cause: A single `.accessibilityLabel` and `.accessibilityHint` are applied to the entire `RemoteFeedVisitCard`, overriding descendant button semantics.
- Status: Fixed and verified. Runtime targets now distinguish Open, Like/Unlike, Comment, and Save cafe actions.

### BUG-003 — Add Visit rating stars are all announced as “Favorite”

- Severity: High
- User impact: VoiceOver users cannot tell which rating category or score a star changes.
- Reproduction:
  1. Open Add.
  2. Jump to Rating.
  3. Inspect the star buttons.
- Expected: Each star identifies its category and score, for example `Taste, 4 out of 5`.
- Actual: All 20 controls are labeled `Favorite`.
- Evidence: iPhone 17 runtime snapshot showed every Presentation, Value, Taste, and Ambiance star as `Favorite`.
- Likely root cause: Star buttons rely on the SF Symbol’s default accessibility name instead of explicit control semantics.
- Status: Fixed and verified. Runtime targets now identify category, selected score, and current rating.

### BUG-004 — Saved cafe detail is not reachable as an accessible control

- Severity: High
- User impact: VoiceOver and semantic automation users can trigger `Log a visit` but cannot open cafe details from Saved.
- Reproduction:
  1. Open Saved with at least one cafe.
  2. Inspect the card’s accessible controls.
- Expected: The cafe summary is exposed as a button that opens Cafe Detail.
- Actual: Only `Log a visit` is exposed; the visually tappable cafe summary is absent.
- Evidence: Runtime snapshot listed the segmented controls and `Log a visit` buttons but no cafe-detail targets.
- Likely root cause: The summary uses `.onTapGesture` on an `HStack` instead of a semantic `Button`.
- Status: Fixed and verified. Saved cafe summaries are exposed as named buttons and successfully open Cafe Detail.

### BUG-005 — Failed sign-in clears the entered credentials

- Severity: Medium
- User impact: A user who mistypes a password must re-enter both email and password after every failed attempt.
- Reproduction:
  1. Install on a clean simulator.
  2. Enter a valid-looking email and a password of six or more characters.
  3. Submit invalid credentials.
- Expected: The form remains in place, shows an error, and retains the entered values for correction.
- Actual: Both fields reset to their placeholders.
- Evidence: The pre-submit snapshot contained `invalid-sprint@example.com`; the post-failure snapshot contained `you@example.com` and `Password` placeholders.
- Likely root cause: `MugshotRootView` replaces `AuthEntryView` with `AuthLoadingView` for `.working`, destroying the form’s local `@State` before `.failed` recreates it.
- Status: Fixed and verified. A failed sign-in retained both entered fields on the clean iPhone 16e Simulator.

## Suspicions, limitations, and non-defects

- Native Photos picker: Xcode semantic taps do not present the picker. This matches existing repository documentation. Computer Use could not attach (`Sky Computer Use native pipe startup failed`). This is an automation limitation, not a confirmed app defect.
- Map screenshots briefly contained black tile gaps immediately after filter transitions; a settled screenshot rendered correctly. Classified as capture/render timing, not an app defect.
- Account creation was inspected and toggled but not submitted because creating a real account was unnecessary for this sprint.
- Sign-out and final account deletion were not committed. The delete confirmation and cancel path were verified without risking the existing test account.

## Low-regression implementation plan

1. Preserve `AuthEntryView` identity across `.working` and `.failed` signed-out states.
2. Wire the existing Feed search button to native programmatic SwiftUI search and filter only the already-loaded page; do not add network/API behavior.
3. Remove the card-wide Feed accessibility override and label each child action explicitly.
4. Add category/score labels, values, and hints to rating stars.
5. Replace the Saved cafe summary gesture with a plain semantic button while preserving its visual layout.
6. Add focused tests for feed search matching; verify the remaining fixes through Simulator accessibility snapshots and affected-flow smoke tests.

## Final verification

- Build/run: passed after fixes on iPhone 17, iOS 26.2.
- Compact/clean-device build/run: passed on iPhone 16e, iOS 18.6.
- Automated tests: 34 passed, 0 failed, 0 skipped.
- Feed: Friends/Everyone, remote detail, like/unlike with restoration, comment draft/clear, search match, search no-results, cancel, and relaunch/session restore passed.
- Map: filters, location action, place search, result selection, cafe detail, favorite/want-to-try toggles with restoration, and recent-search behavior passed.
- Add: requirement navigation, cafe search/selection, drink entry, all rating controls, caption/private note/visibility, photo-required state, cancel, and fresh-draft reset passed. Native Photos picker remained blocked only by the documented automation limitation.
- Saved: Favorites/Want to Try/All Cafes, sort controls, semantic cafe-detail opening, and Log Visit entry points passed.
- Profile/Settings: profile display, edit/cancel, About, Privacy, Terms, Support, delete confirmation/cancel, and relaunch passed.
- Runtime logs: no app errors, faults, crashes, assertions, or timeouts appeared in the final launch log.

---

## Reported-bug follow-up — 2026-07-11

### BUG-006 — Current location renders as an unexplained map pin

- Severity: Medium
- User impact: The sage current-location dot visually collides with journal pins and can be mistaken for an unrated cafe or Want to Try marker.
- Reproduction: Open Map with location permission granted and inspect the marker near the current coordinate.
- Expected: Only journal cafe pins appear; the existing Location button recenters the map when requested.
- Actual: MapKit adds a separate tinted user-location circle, while a previously selected unrated cafe can remain pinned after its detail is dismissed.
- Evidence: Supplied screenshot `codex-clipboard-a1c5c9e0-a55a-4e5e-a451-6e0321cc255b.png`; reproduced on the signed-in iPhone 17 Simulator. `MapViewRepresentable.makeUIView` explicitly sets `showsUserLocation = true`, and Map passed `selectedCafe` as highlighted even when no detail was visible.
- Likely root cause: The UIKit map enabled its native user annotation despite the dedicated recenter control, and highlighted selection state was not scoped to the detail presentation lifetime. Legacy zero-score visits could also produce an unlabeled default circle.
- Status: Fixed and verified. The duplicate location/selection markers no longer render; a genuine active Want to Try bookmark remains available under its matching filter.

### BUG-007 — Good map completions are replaced by unrelated place results

- Severity: High
- User impact: Users typing a specific nearby cafe can lose the correct suggestions and receive unrelated restaurants or a result thousands of kilometers away.
- Reproduction: On Map, enter `Baba`, wait for suggestions, then wait approximately half a second.
- Expected: Nearby `Babas` completions remain primary; concrete results are relevant and geographically plausible.
- Actual: Every keystroke starts a delayed broad `MKLocalSearch`; when it completes, the UI hides completions and shows results such as Poke Tea House or `Bab` 7,928 km away.
- Evidence: Supplied screenshots `codex-clipboard-203ff47c-5046-4918-aa0e-4eeeb4a7e642.png` and `codex-clipboard-53d3ad23-f481-4708-8193-31d515bc2b6b.png`; reproduced on iPhone 17 with the runtime hierarchy returning Poke Tea House, ViVi Bubble Tea, Maccaro, and Ding Tea for `Baba`.
- Likely root cause: The type-ahead and concrete-search pipelines compete, while the concrete results are only ranked and never rejected for textual or geographic irrelevance.
- Status: Fixed and verified. `Baba` remained on the four correct Charleston completions after settling; explicit completion selection returned the intended Babas place.

### BUG-008 — Multi-photo sips cannot be opened full screen

- Severity: Medium
- User impact: Although the detail hero can page through stored photos, users cannot tap into an unobstructed viewer to inspect the full set.
- Reproduction: Open a visit containing more than one uploaded photo, swipe the hero, then tap a photo.
- Expected: Hero swipes through all photos; tapping opens a full-screen, swipeable, aspect-fit viewer with position and dismiss controls.
- Actual: The hero is swipeable but taps do nothing and photos remain cropped under visit overlays.
- Evidence: `RemoteVisitDetail.photoURLs` and its existing paging test confirm the full ordered photo set; `remotePhotoPager` had no tap action or presentation state.
- Likely root cause: The data and inline pager were implemented without a full-screen media presentation.
- Status: Fixed and verified using a two-photo Cardamom Bun Latte visit. Inline paging reached 2/2, tapping opened full screen at 2 of 2, and dismiss returned to detail.

### BUG-009 — Profile average rating wraps at the decimal point

- Severity: Medium
- User impact: The compact stats strip displays values such as `3.7` as `3.` and `7` on separate lines, reducing readability and visual polish.
- Reproduction: Open Profile on a compact-width phone with a decimal average rating.
- Expected: The decimal rating remains on one line.
- Actual: SwiftUI compresses the value Text and wraps at the decimal separator.
- Evidence: Supplied screenshot `codex-clipboard-384fdad4-b6dc-456e-bfef-c289fdb28396.png`; `MugshotStatPill` had no single-line constraint.
- Likely root cause: Four pills compete for width and the numeric value allowed normal line wrapping.
- Status: Fixed and verified at 368-point compact width; `3.7` remains on one line.

### BUG-010 — Cafe hero photos are excessively zoomed

- Severity: Medium
- User impact: Visit photos used as cafe imagery can become unrecognizable because only a narrow crop is visible.
- Reproduction: Open Cafe details for a cafe whose latest visit photo is not already 16:9.
- Expected: The whole visit photo is visible within a stable hero area.
- Actual: The shared image view fills/crops, then Cafe details applies a second 16:9 fill/crop.
- Evidence: Supplied screenshot `codex-clipboard-8d7381ea-aa62-4808-8610-61567434cc34.png`; code inspection confirmed nested fill scaling.
- Likely root cause: Content mode was hard-coded to fill in both local/remote image components and again at the cafe call site.
- Status: Fixed and verified. Cafe hero call sites now use one aspect-fit pass in the stable 250-point hero frame; legacy/no-photo fallback also remains intact.

### BUG-011 — Text inputs show a tinted inner rectangle

- Severity: Medium
- User impact: Edit Profile, Map search, and other fields display a beige/gray bar inside the intended field container.
- Reproduction: Open Edit Profile or focus Map search.
- Expected: One normal input surface with no differently colored inner block.
- Actual: A UIKit appearance background is painted inside the SwiftUI field's own styled container.
- Evidence: Supplied screenshot `codex-clipboard-07b246a2-c0d9-471e-855b-3d7c6b0af6fd.png`; `testMugshotApp.configureTextInputAppearance` globally sets backgrounds on `UITextField` and `UITextView`.
- Likely root cause: Global UIKit appearance styling leaks through SwiftUI's platform-backed text controls.
- Status: Fixed and verified in signed-in Edit Profile and Map search, plus signed-out authentication fields on iPhone 16e.

### Follow-up implementation plan

1. Keep MapKit completions as the only automatic type-ahead result and run concrete place search only on Submit or completion selection.
2. Reject concrete results more than 100 km from the active map and reject unrelated names for specific queries; preserve nearby category discovery.
3. Remove the redundant MapKit user annotation while preserving the recenter button.
4. Add an item-driven full-screen photo viewer using the existing ordered photo URL set.
5. Make local and remote photo content modes configurable; use aspect-fit for cafe and full-screen media.
6. Force profile stat values and labels to remain single-line under compression.
7. Remove global text-input background appearance without changing field text colors.

### Follow-up final verification

- Builds: passed on iPhone 17 (iOS 26.2) and iPhone 16e (iOS 26.2).
- Automated tests: 37 passed, 0 failed, 0 skipped on the final compact-device run.
- Map: All/Favorites/Want to Try/Visited filters, recenter action, marker cleanup, `Baba` completion stability, completion selection, and relaunch passed. The remaining bookmark at the reported coordinate is confirmed user-owned Want to Try state, not a duplicate annotation.
- Visit media: one-photo and two-photo detail heroes, inline 1/2 → 2/2 swipe, selected-page full-screen opening, aspect-fit rendering, counter, and dismiss passed.
- Profile/input: compact average stat, Edit Profile field surfaces, cancel, and clean signed-out auth fields passed.
- Cafe detail: remote/local hero sizing and no-photo fallback built successfully; available Simulator cafe details rendered without the former nested fill crop.
- Runtime logs: final iPhone 17 and iPhone 16e launch logs contained no errors, faults, crashes, assertions, timeouts, or warnings.
- Worktree safety: unrelated pre-existing Supabase, feed, auth, performance, and migration changes remain unstaged and preserved; `git diff --check` passes.
