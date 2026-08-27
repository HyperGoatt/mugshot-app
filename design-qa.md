# Phase 2 Profile and Journal design QA

## Reference and implementation

- Approved reference: `/Users/joe.rosso/.codex/generated_images/019f5838-d3b5-7360-b744-1a754c877c71/exec-c37099a0-e3cb-4129-b6d8-1fd8cf0e052f.png`
- Implemented Profile, top state: `/Users/joe.rosso/.codex/visualizations/2026/07/12/019f5838-d3b5-7360-b744-1a754c877c71/phase-two/profile-top.jpg`
- Implemented Journal and Taste Identity state: `/Users/joe.rosso/.codex/visualizations/2026/07/12/019f5838-d3b5-7360-b744-1a754c877c71/phase-two/profile-taste.jpg`
- Side-by-side comparison: `/Users/joe.rosso/.codex/visualizations/2026/07/12/019f5838-d3b5-7360-b744-1a754c877c71/phase-two/profile-comparison.jpg`
- Simulator viewport: 368 × 800 points-equivalent pixels on iPhone 17 Pro.

## Fidelity review

| Surface | Result |
| --- | --- |
| Continuous Profile composition | Passed. Banner, avatar, identity, edit action, tags, and data summary read as one surface instead of stacked cards. |
| Journal hierarchy | Passed. Journal is the primary profile content, with All, Cafe, Home, and Recipes filters plus a searchable full archive. |
| Structured home entry | Passed. The feature card exposes real photo, method, equipment, notes, and visibility while preserving readable type sizes. |
| Supporting entries | Passed. A single secondary row keeps the overview concise; the archive carries the complete history. |
| Taste Identity | Passed. Identity and evidence appear inline after Journal without introducing another floating block. |
| Bottom navigation and safe areas | Passed. Interactive content remains clear of the app tab bar; scrolled content follows native iOS behavior. |

## Variance decisions

- The implementation uses the user's real Cardamom Bun Latte entry instead of the illustrative Peru Mocha content in the reference.
- Taste Identity follows Journal in the scroll rather than compressing both sections into one viewport. This preserves legibility, Dynamic Type resilience, and usable touch targets.
- Recipe actions live in the full Journal archive and Add flow instead of adding another control cluster to the profile overview.

## Issue history

- Reduced the All view from three supporting rows to one so Taste Identity remains close to the main Journal feature.
- Connected **See all** to a searchable, filterable archive and removed a nonfunctional empty-state action from the archive.
- Rebuilt and exercised the archive and Recipes empty state in Simulator after the final interaction change.

## Final result

Passed. No open P0, P1, or P2 visual or interaction issues remain for the approved Phase 2 scope.

---

# Sip-posting redesign design QA

## Reference and implementation

- Approved direction 3 reference: `/Users/joe.rosso/.codex/generated_images/019f5bda-9c1e-7a62-b883-3031550aa18e/exec-5f7b0bf3-d768-4260-b861-2f7d396dc547.png`
- Implemented Quick Sip: `/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/sip-posting-final/quick-sip.jpg`
- Implemented personal criteria: `/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/sip-posting-final/personal-criteria.jpg`
- Implemented Recipe privacy and steps: `/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/sip-posting-final/recipe-privacy.jpg`
- Cafe-preselected entry point: `/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/sip-posting-final/cafe-preselected.jpg`
- Full side-by-side comparison: `/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/sip-posting-final/reference-vs-quick-sip.jpg`
- Criteria side-by-side comparison: `/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/sip-posting-final/reference-vs-criteria.jpg`
- Simulator viewport: 368 × 800 points-equivalent pixels on iPhone 17 Pro.

## Fidelity review

| Surface | Result |
| --- | --- |
| Mugshot visual language | Passed. Cream canvas, sage accents, espresso type, editorial title treatment, native controls, soft elevation, and rounded cards remain consistent with the approved direction and existing system. |
| Progressive lanes | Passed. Quick Sip has the requested larger visual share, while Add Details is clearly secondary without looking hidden. |
| Quick Sip hierarchy | Passed. Context, drink, and independent half-step overall rating remain the only required decisions; photo and thought stay optional for private saves. |
| Personal criteria | Passed. The rating breakdown visually matches the reference density, supports half steps, and keeps the overall score independent. Customize remains visible at the point of use. |
| Context depth | Passed. Cafe, Home, and Recipe adapt their explanatory copy and structured fields without changing composers. |
| Privacy comprehension | Passed. Private notes have an explicit owner-only treatment, the current audience remains visible with the save action, and Everyone displays its text-only safeguard. |
| Navigation and safe areas | Passed. Content scrolls clear of the persistent save control and app tab bar; cancellation returns to the prior context. |
| Accessibility | Passed. Controls expose semantic labels, rating values, minimum usable targets, Dynamic Type-compatible text wrapping, and non-color state cues. |

## Variance decisions

- The implementation starts from the editable capture state instead of the reference's already-completed sip summary, because this branch replaces the composer rather than adding a post-save detail screen.
- The larger Quick Sip lane follows the approved 65/35 emphasis, reversing the reference's selected Add Details emphasis.
- Criteria use the user's live rating template and arbitrary names instead of fixed illustrative icons, preserving the personal tasting-lens model.
- Photo space appears only after the user adds media; an empty draft does not reserve a large decorative image slot.

## Issue history

- P1 fixed: the original drag-based half-star control intercepted vertical scrolling. It now uses spatial taps for half-step input, with accessible increment and decrement actions retained.
- P1 fixed: restoring a Home or Recipe draft could reapply default visibility and overwrite an intentional audience choice. Restoration now suppresses context-default mutation.
- P2 fixed: a cafe-preselected entry could resume an unrelated active draft. Draft storage now parks multiple drafts and resumes only a matching cafe draft for preselected launches.
- Rebuilt and repeated screenshot comparison after each interaction fix.

## Final result

passed

---

# Guided sip composer design QA

## Reference and implementation

- Selected direction: Tasting Ritual, grounded in the approved direction 3 visual language.
- Approved reference: `/Users/joe.rosso/.codex/generated_images/019f5bda-9c1e-7a62-b883-3031550aa18e/exec-5f7b0bf3-d768-4260-b861-2f7d396dc547.png`
- Guided Recipe memory: `/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/guided-recipe-memory-final-flattened.png`
- Guided Tasting Lens: `/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/guided-tasting-lens-settled-flattened.png`
- Final side-by-side comparison: `/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/tasting-lens-final-comparison.png`
- Simulator: iPhone 17 Pro.

## QA coverage

| Surface | Result |
| --- | --- |
| Guided progression | Passed. Context, drink, and rating are focused steps; optional memory modules do not block the quick route. |
| Feature-flag continuity | Passed. Switching between Long Form and Guided restored the same Recipe draft, fields, visibility, and guided step. |
| Contexts | Passed. Cafe, Home, and Recipe were exercised; their context-specific fields and visibility defaults remained intact. |
| Rating modes | Passed. Quick Rating and Tasting Lens were exercised. The lens replaces the overall control, supports half steps, exposes not-relevant handling, and shows the weighted result. |
| Visibility | Passed. Friends, Private, and Everyone states were exercised, including the text-only Everyone safeguard. |
| Visual fidelity | Passed. Cream, sage, espresso, editorial typography, native controls, and restrained motion match the approved Mugshot direction. |
| Accessibility implementation | Passed by code and build review. Controls include semantic labels, adjustable rating actions, minimum touch targets, Dynamic Type wrapping, and Reduce Motion fallbacks. |

## Issue history

- P1 fixed: both composer presentations originally remained in layout while one was transparent, allowing the hidden form to influence width and scrolling. Only the selected presentation now renders.
- P1 fixed: the persistent save bar collided visually with the app dock. Additional safe-area spacing now keeps the actions distinct.
- P2 fixed: wide optional-detail content could exceed the readable canvas. Composer stacks now conform to the available horizontal container.
- P2 fixed: Tasting Lens relevance was ambiguous. Each criterion now exposes a clear **Mark N/A** action.
- Rebuilt, reran, and repeated the reference comparison after the final layout fixes.

## Final result

Passed. No open P0, P1, or P2 visual or interaction issues remain in the guided composer scope.

---

# Sip detail Taste snapshot disclosure QA

## Evidence

- Source visual truth: `/Users/joe.rosso/.codex/visualizations/2026/07/15/019f6350-13a4-7c93-a7b5-82bf28410276/sip-taste-snapshot/reference.png`
- Collapsed implementation: `/Users/joe.rosso/.codex/visualizations/2026/07/15/019f6350-13a4-7c93-a7b5-82bf28410276/sip-taste-snapshot/collapsed.jpg`
- Expanded implementation: `/Users/joe.rosso/.codex/visualizations/2026/07/15/019f6350-13a4-7c93-a7b5-82bf28410276/sip-taste-snapshot/expanded.jpg`
- Full comparison: `/Users/joe.rosso/.codex/visualizations/2026/07/15/019f6350-13a4-7c93-a7b5-82bf28410276/sip-taste-snapshot/comparison.jpg`
- Viewport: iPhone 17 Pro, 368 x 800.
- States: collapsed and expanded Taste snapshot.

## Findings

- No open P0, P1, or P2 issues.
- Typography, spacing, cream and mint tokens, source imagery, and product copy remain consistent with the approved Immersive Pour system.
- The collapsed state intentionally improves on the supplied screenshot by following the user's explicit hierarchy: title, overall score, and disclosure control only.
- The expanded state reveals every available criterion with its score and bar, with a one-time animated fill and a Reduce Motion fallback.

## Comparison history

- P2 fixed: criterion names and scores previously appeared before the disclosure was opened. The complete criteria grid now enters only after `View breakdown` is activated.
- Focused UI coverage confirmed the collapsed labels are absent and the expanded labels and `Hide details` control appear after activation.

## Final result

final result: passed

---

# Feed header and Profile-share recency follow-up — implementation QA

## Comparison setup

- Owner references:
  - `docs/design-qa/profile-share-feed-followup/01-feed-reference.jpg`
  - `docs/design-qa/profile-share-feed-followup/02-public-profile-reference.png`
  - `docs/design-qa/profile-share-feed-followup/02-share-stale-reference.png`
  - `docs/design-qa/profile-share-feed-followup/05-feed-equalized-reference.png`
- Simulator implementation captures:
  - `docs/design-qa/profile-share-feed-followup/03-feed-implemented.jpg`
  - `docs/design-qa/profile-share-feed-followup/04-share-implemented.jpg`
  - `docs/design-qa/profile-share-feed-followup/06-feed-equalized-implemented.jpg`
- Same-input comparison boards:
  - `docs/design-qa/profile-share-feed-followup/feed-comparison.png`
  - `docs/design-qa/profile-share-feed-followup/share-comparison.png`
  - `docs/design-qa/profile-share-feed-followup/feed-gap-equalized-comparison.png`
- Viewport: Mugshot iPhone 17 Pro, iOS 27 Simulator, 368 × 800 pixels.
- Density normalization: each source was aspect-fit into a 368 × 800 cell
  beside the native 368 × 800 Simulator capture. Device framing and screenshot
  scaling were excluded from findings.
- Data state: Joe's authenticated live Feed, public owner Profile, and generated
  Story Profile-share preview. Production inspection was read-only.

## Findings and implementation

- **P2 — Feed scope rail had a duplicate resting gutter.** The independent
  overlay correctly protected the pills from refresh and lazy recycling, but
  its 16-point top inset sat below a header that already owned the intended
  spacing.
  - Fix: make the rail's resting inset zero while preserving its measured
    height, identical scope-control geometry, 60-point stationary threshold,
    and continuous upward translation.
- **P2 follow-up — the rail-to-card gap still exceeded the subtitle-to-rail
  gap.** A zero-height refresh reader was a separate child of the 12-point
  `LazyVStack`, so it contributed an invisible spacing interval.
  - Fix: attach the refresh reader behind the scope reservation and calculate
    that reservation so the visible upper and lower gaps both resolve to the
    eight-point design token.
- **P2 — current Profile media disappeared from generated shares.** The live
  Profile renderer supported durable `mugshot-storage://` values, while the
  Profile-share content filter admitted HTTPS only. Recent Friends-profile
  photos were therefore dropped and older public HTTPS images became the first
  visible grid items.
  - Fix: order profile-published sips newest-first, retain only validated HTTPS
    or private-Storage references, resolve viewer-authorized Storage media while
    preparing the artwork, and keep Private Mugshots excluded.

## Final comparison

- The Feed scope rail now nests directly beneath the subtitle in the approved
  visual rhythm; the first card begins after the same eight-point gap, and Your
  Mix, Friends, and Everyone share one unchanged baseline.
- The Profile-share preview now displays the same newest visible first row as
  the live public Profile: the interior iced coffee, blue-door drink, and Bad
  Bunnies storefront drink. The stale holiday imagery is absent.
- Banner, avatar, statistics dock, identity, Favorite Spots, tab rail, Story
  bounds, marketing footer, canonical link behavior, and native share structure
  remain unchanged.
- No actionable P0, P1, or P2 mismatch remains in the compared regions.

## Verification evidence

- Normal Debug Simulator build/install/launch: passed.
- Focused Profile/Feed-domain run: 29 passed and one exact floating-point
  assertion failed due to `-29.999999999999996` versus `-30`; the assertion was
  corrected to a bounded tolerance.
- Corrected focused Feed-motion rerun: 1 passed, 0 failed.
- Equal-gap Feed-motion rerun after the refresh-reader layout fix: 1 passed, 0
  failed.
- Live Feed and generated Profile-share render: passed.
- Same-input visual comparisons: passed.
- Full-static: 11 non-Xcode stages passed, optional `pglast` skipped, and the
  known Xcode 27 generic XCTest-framework Info.plist packaging stage failed;
  the normal Simulator build and focused XcodeBuildMCP tests passed.
- Latest physical-device and TestFlight acceptance: not run.

final result: passed

---

# Home Workbench brew-first flow — implementation QA

## Comparison setup

- Source visual truth: `docs/design/home-workbench-cafe-spine-2026-08-23/01-log-a-sip-home-workbench.png` through `08-published-mugshot.png`.
- Final implementation captures: `docs/design/home-workbench-cafe-spine-2026-08-23/production-evidence/final-ui-test/`.
- Same-input comparisons: `docs/design/home-workbench-cafe-spine-2026-08-23/production-evidence/comparisons/`.
- Viewport: iPhone 16 Pro Simulator, iOS 18.6, 402 x 874 points.
- Density normalization: source boards are 852/853 x 1844/1846 pixels; native implementation captures are 1206 x 2622 pixels at 3x. Each side was aspect-fit into an 853 x 1844 comparison cell without cropping.
- State: deterministic empty-library Home attempt using Espresso, 18.5 g in, 38 g planned yield, 42 g actual yield, a finished-cup placeholder, 4.0 sip score, make-again Yes, private Recipe v1, private Mugshot publication, and Brew Again with the 18.5 g setup restored.

## Final findings

No actionable P0, P1, or P2 visual or interaction mismatch remains.

- **Journey fidelity:** Home begins beneath the unchanged Cafe/Home/Elsewhere selector, then advances through Brew this version, What changed, finished-cup capture, the existing sip-rating spine, recipe disposition, Review Mugshot, the existing published/share hub, and Brew Again.
- **Progressive depth:** The planning screen keeps start source, bag, method, gear, and core brew values visible while method-specific fields remain behind Dial-in details. Every technical value stays optional.
- **Comparison safety:** Actuals preserve the selected source snapshot, calculate ratio, summarize only recorded deltas, and explicitly avoid causal claims. Private comparison notes do not enter the post projection.
- **Recipe lineage:** The tested blank attempt correctly creates Recipe v1. Domain tests separately prove that a v3 source stays immutable and produces v4 only when the user chooses a new version.
- **Cafe-flow continuity:** Capture, score, journal reflection, Review Mugshot, publication, and the post-publish share hub reuse the established Mugshot controls and language. Home adds method-aware suggestions and the make-again/recipe decisions without creating a second rating system.
- **Brand fidelity:** The native implementation retains Mugshot cream, foam, sage, mint, sand, espresso, serif headings, rounded quiet cards, Mugsy artwork, and restrained coaching.
- **Accessibility and fixed-footer behavior:** Controls expose identifiers and selected traits. The consolidated UI test scrolls the make-again choice fully above the fixed action bar before selecting it and confirms the action state changes.

## Comparison history

### Pass 1

- **P2 - The UI test typed actual values into prefilled fields instead of replacing them.**
  - Fix: added a selection-and-replacement interaction so the test exercises the real prefilled editing behavior.
- **P2 - The make-again choice could be queried while visually under the fixed action bar.**
  - Fix: positioned the control above the footer before tapping and waited for the selected accessibility state.
- **P2 - Brew Again asserted an off-screen lazy field before bringing it into the accessibility tree.**
  - Fix: scrolled the restored dose field into view, then verified the preserved 18.5 g value.

### Final pass

- All 15 focused Home Workbench domain tests passed.
- The complete seven-surface Simulator journey passed, including publish and Brew Again prefill.
- Side-by-side review confirmed the approved hierarchy, typography, tokens, privacy language, and action placement across brew, actuals, sip, recipe, review, and published states.
- The source boards use a richer saved-recipe/photo fixture; the production test intentionally uses the empty-library and missed-photo path. Those content differences exercise fallback behavior and are not visual regressions.

## Verification evidence

- Repository fast verification: 6 passed, 0 failed.
- Full static verification: 11 passed, 0 failed, 1 optional `pglast` check skipped because that dependency is unavailable.
- Hermetic Home Workbench migration, RLS, private storage, deletion, recipe projection, and export contract: passed; no linked Supabase project was touched.
- Focused Home Workbench domain suite: 15 passed, 0 failed.
- Consolidated iPhone 16 Pro Simulator journey: 1 passed, 0 failed.
- Source-and-implementation comparison: passed.

final result: passed

---

# First-launch marketing onboarding — implementation QA

## Comparison setup

- Source visual truth:
  - `testMugshot/Assets.xcassets/OnboardingMarketing01Capture.imageset/onboarding-marketing-01-capture.png`
  - `testMugshot/Assets.xcassets/OnboardingMarketing02Map.imageset/onboarding-marketing-02-map.png`
  - `testMugshot/Assets.xcassets/OnboardingMarketing03Feed.imageset/onboarding-marketing-03-feed.png`
  - `testMugshot/Assets.xcassets/OnboardingMarketing04Friends.imageset/onboarding-marketing-04-friends.png`
  - `testMugshot/Assets.xcassets/OnboardingMarketing05Saved.imageset/onboarding-marketing-05-saved.png`
  - `testMugshot/Assets.xcassets/OnboardingMarketing06Journal.imageset/onboarding-marketing-06-journal.png`
  - `testMugshot/Assets.xcassets/OnboardingMarketing07TastePassport.imageset/onboarding-marketing-07-taste-passport.png`
  - `testMugshot/Assets.xcassets/OnboardingMarketing08GoogleMaps.imageset/onboarding-marketing-08-google-maps.png`
  - `testMugshot/Assets.xcassets/OnboardingMarketing09Account.imageset/onboarding-marketing-09-account.png`
- Implementation captures: `docs/design/onboarding-marketing-2026-08-22/implementation/`
- Full same-input comparison: `docs/design/onboarding-marketing-2026-08-22/comparison/all-nine-contact-sheet.png`
- Focused same-input comparisons: `docs/design/onboarding-marketing-2026-08-22/comparison/01-source-left-implementation-right.png` through `09-source-left-implementation-right.png`.
- Simulator: iPhone 16 Pro.
- Captured viewport: 368 × 800 optimized pixels.
- Source pixels: 852–853 × 1844–1846. Each source was aspect-fit and normalized to 368 × 800 before comparison.
- Implementation pixels: 368 × 800.
- Appearance: forced light; Reduce Motion enabled.
- State: deterministic DEBUG first-launch route with no session restore, authentication, analytics, or remote mutation.

## Final findings

No actionable P0, P1, or P2 visual or interaction differences remain.

- Fonts and typography: the implementation displays the authored editorial serif and restrained sans hierarchy without a second native text layer, reflow, truncation, or fallback drift.
- Spacing and layout rhythm: all nine artworks preserve their authored aspect ratio and fill the modern iPhone viewport. The visible content order, margins, media proportions, card shapes, and CTA placement match the approved sources.
- Colors and tokens: cream, espresso, mint, sage, sand, map, and photography treatments are the exact approved raster artwork; no client-side recoloring or approximation is introduced.
- Image quality and asset fidelity: every approved screen is bundled at roughly 2× the captured point-equivalent width and rendered with high interpolation. The Feed retains its selected portrait media treatment. Friends has one Mugsy. Journal uses the selected no-placeholder variant. Google Maps uses the official Mugshot app icon. The final screen has no Start my reflection CTA.
- Copy and content: the opening says Capture Every Sip and names coffee, matcha, and tea. The Map headline is category-inclusive. Friendship and privacy meanings remain explicit. The final screen exposes only Create account and Sign in.
- Icons and affordances: the artwork contains the approved real Mugshot surfaces and official brand icon. Native invisible hit regions align with the visible Skip, Continue, Skip to account setup, Create account, and Sign in controls.
- Interaction states: Continue advanced through all nine screens in one Simulator session. Skip from the opening jumped directly to the final account-choice screen without selecting an authentication mode. Screen 9 exposed only Create account and Sign in; selecting Sign in completed first-launch education and retained Add as landing tab 2.
- Accessibility: every visible action is backed by a native SwiftUI Button with a stable accessibility label and identifier. Each artwork exposes its step number, headline, and supporting narrative. Device chrome may briefly appear after touch; that is runtime-owned and does not obscure a required action.

## Comparison history

### Iteration 1 — blocked

- [P1] The first Simulator render respected the safe-area content frame, producing cream letterboxing around artwork intended to be full bleed.
  - Fix: extended the artwork geometry through the full screen while retaining aspect-fit mapping for the native tap regions.

### Final iteration — passed

- Rebuilt and relaunched the app on iPhone 16 Pro Simulator.
- Captured all nine implementation states after advancing through the real native Continue targets.
- Relaunched and confirmed Skip moves directly to the final Create account / Sign in choice.
- Normalized every source and implementation pair to the same 368 × 800 comparison viewport.
- Reviewed the full contact sheet plus focused comparisons for the opening, Feed, Friends/privacy, Google Maps logo, and final authentication states.
- No actionable P0/P1/P2 mismatch remained.

## Follow-up polish

- [P3] The iOS home indicator or Dynamic Island may briefly reappear after touch even when persistent system overlays are requested hidden. This is expected runtime-owned device chrome and does not affect the artwork or hit targets.

## Final result

final result: passed

---

# Supabase signup confirmation email — implementation QA

## Comparison setup

- Source visual truth: `docs/audits/auth-2026-07-30/confirm-signup-selected-concept.png` (1024 × 1536 pixels).
- Production template: `docs/audits/auth-2026-07-30/confirm-signup.html`.
- Browser-rendered implementation: `docs/audits/auth-2026-07-30/screenshots/confirm-signup-implementation.png` (1280 × 1063 pixels).
- Email-card crop: `docs/audits/auth-2026-07-30/screenshots/confirm-signup-implementation-card.png` (600 × 995 pixels).
- Same-input comparison: `docs/audits/auth-2026-07-30/screenshots/confirm-signup-design-comparison.png`.
- Browser viewport: 1280 × 720 CSS pixels at device scale factor 2; the email card renders at its production 600-pixel maximum width.
- Responsive check: an isolated 390-pixel email viewport rendered a 370-pixel card with `documentScrollWidth == documentClientWidth == 390`; the canonical Mugsy image resolved to 300 pixels and the headline to 43 pixels without overflow.
- State: signup confirmation with the Supabase `{{ .ConfirmationURL }}` placeholder intact.

## Findings

No actionable P0, P1, or P2 visual or interaction differences remain.

- Fonts and typography: Passed. Georgia provides the email-safe editorial serif headline; the system sans-serif stack preserves the product's functional copy hierarchy. The headline, body, CTA, backup link, and footer wrap cleanly at desktop and mobile widths.
- Spacing and layout rhythm: Passed. The compact masthead, large illustrated hero, editorial welcome, CTA, backup link, and quiet footer preserve the selected vertical sequence. The production card uses a 600-pixel email-safe frame and removes nonessential decoration rather than leaving blank space.
- Colors and visual tokens: Passed. Cream, foam, espresso, roast, sage, mint, latte, sand, and line values come from the canonical Mugshot palette. Text and CTA contrast remain accessible, and explicit light color-scheme hints reduce destructive client inversion.
- Image quality and asset fidelity: Passed. The email loads the unchanged 500 × 500 production `MugsyNoCafes.png` through the public `brand-assets` path. Local and hosted files share SHA-256 `0c47ebb14efe29f085b838aeba4f42c4681a72ba77bc4b9a88511986a1bbd435`; no generated Mugsy ships.
- Copy and content: Passed. The message uses one primary action, keeps `cafe` unaccented, hides the raw Supabase URL behind a readable backup link, and explains how to ignore an unrequested signup.
- Interaction and runtime: Passed. Both visible links retain `{{ .ConfirmationURL }}` exactly, the hosted Mugsy asset reports complete at its natural 500 × 500 size, and the browser console produced no warnings or errors.

## Comparison history

### Initial production render — blocked

- [P2] Canonical Mugsy appeared too small relative to the selected concept because the transparent source canvas was sized at 330 pixels.
  - Fix: increased the email image frame to 430 pixels on desktop and 360 pixels on mobile while retaining the exact source pixels and proportions.

### Final render — passed

- Reloaded the local production template after the asset-size correction.
- Captured the 600-pixel email card and placed it beside the selected source in one comparison board.
- Checked the 390-pixel responsive metrics, final copy, CTA template value, remote image completion, and console output.
- The omitted leaf, envelope, pin, and route ornaments are an intentional email-client compatibility tradeoff; the canonical Mugsy hero and Mugshot hierarchy remain intact.

## Focused-region evidence

Separate focused crops were unnecessary because the source and production card remain fully legible in the same-input comparison. The canonical Mugsy region was additionally verified by hosted-file checksum rather than visual approximation.

## Final result

final result: passed

---

# Mugshot 0.5.3 onboarding — canonical Mugsy product tour QA

## Comparison setup

- Primary visual direction: `/Users/joe.rosso/.codex/generated_images/01a020fa-6c79-7811-b31e-b6d1e6f480b0/exec-467cf2b2-c7cb-4f32-91e4-e72c8628dc29.png` (852 × 1846 pixels).
- Real product sources:
  - Map: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/codex-clipboard-460601e1-f23b-4f91-bdc9-463ab8fdddd1.png` (1206 × 2622 pixels).
  - Privacy-sanitized Map derivative: `/Users/joe.rosso/.codex/generated_images/01a020fa-6c79-7811-b31e-b6d1e6f480b0/exec-773d8cca-fafc-4ed1-9fa9-2049b3d5a88d.png` (853 × 1844 pixels); the precise blue location marker is removed from the bundled source itself.
  - Feed: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/codex-clipboard-cfcdd652-09cf-420e-aaba-7a25c464a33d.png` (1206 × 2488 pixels).
  - Saved: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/codex-clipboard-3369f80b-b102-48bb-8dce-a5b68cbcfd30.png` (1206 × 2504 pixels).
- Rendered implementation: `/Users/joe.rosso/.codex/visualizations/2026/08/20/01a020fa-6c79-7811-b31e-b6d1e6f480b0/onboarding-0.5.3-final/`.
- Full-view same-input comparisons:
  - `design-qa/map-target-vs-implementation.jpg`
  - `design-qa/feed-source-vs-implementation.jpg`
  - `design-qa/saved-source-vs-implementation.jpg`
- Focused coach comparison: `design-qa/map-coach-focused.jpg`.
- Simulator viewport: iPhone 17 Pro, 368 × 800 points-equivalent optimized screenshot pixels, light appearance.
- CSS viewport and device scale factor: not applicable to the native SwiftUI implementation. Source images were normalized to 368 × 800 by proportional scale plus crop or padding; implementation captures were already 368 × 800. No cross-density visual finding was filed.
- States: Capture Every Sip, map story, personalization celebration, Map, Feed, Saved, Journal, Google Maps share shortcut, and the real first Log a Sip setup screen.

## Findings

No actionable P0, P1, or P2 visual or interaction differences remain.

- Fonts and typography: Passed. Editorial serif titles and rounded/system sans-serif coach copy preserve the existing Mugshot hierarchy. Labels, messages, and actions remain readable at 368 × 800 without truncation.
- Spacing and layout rhythm: Passed. The coach occupies a compact lower corner rather than a centered takeover. Map, Feed, Saved, and Journal remain substantially visible; progress and dismissal moved inside the conversation bubble so product headers are unobstructed.
- Colors and visual tokens: Passed. Cream, foam, sage, mint, espresso, sand, border, and shadow treatments come from the existing app tokens and preserve adequate contrast.
- Image quality and asset fidelity: Passed. Feed and Saved use the supplied real product captures, while Map uses a surgical privacy-sanitized derivative with the location marker removed. The Google Maps lesson uses the privacy-sanitized real share-sheet treatment. Every floating Mugsy is the code-native `MugsyAnimatedView`/`MugsyModelView`; no generated Mugsy artwork ships.
- Copy and content: Passed. The tour names `cafe`, `cafes`, Friends, Want to Try, Lists, Journal, and Taste Passport consistently. Map includes the visible seven-cafe count and 3.6 average for the displayed pins.
- Icons and affordances: Passed. Back, next, dismiss, privacy, and primary actions use consistent SF Symbols and practical touch targets.
- Accessibility and resilience: Passed for the scoped Simulator acceptance. Coach actions expose stable identifiers and explicit labels, the Map source image has an accessibility description, the privacy cover explains that precise location is hidden, and canonical Mugsy remains decorative within the combined coach element. Reduce Motion continues to use the existing Mugsy motion environment.

## Comparison history

### Iteration 1 — blocked

- [P1] Mugsy and his speech bubble were clipped out of all three introduction heroes.
  - Fix: constrained the real product backdrop to the hero frame before applying the code-native Mugsy overlay.
- [P2] The separate progress and dismiss pills covered the real Saved and Journal titles and competed with the Feed header.
  - Fix: moved step count and dismiss into the compact speech bubble.
- [P2] Live empty Map, Feed, and Saved fixtures did not communicate the promised product value or the requested map wow moment.
  - Fix: used the supplied real product captures, retained live Journal, added the displayed cafe count and average, removed the Map location dot from the bundled image, and retained an explicit visible privacy treatment.
- [P2] The first-sip guide obscured the context selector and Photos heading it was explaining.
  - Fix: converted the guide from a layout inset to a compact floating coach, placed it in lower nonessential whitespace on setup/context, and alternated Mugsy’s side by composer step.

### Final iteration — passed

- Rebuilt and relaunched the complete onboarding route on the iPhone 17 Pro Simulator.
- Captured all eight onboarding states plus the first Log a Sip guide.
- Compared the selected visual direction and supplied product sources with the rendered implementation in the same comparison images.
- Inspected the focused coach region for canonical Mugsy identity, copy density, control placement, map visibility, and dock clearance.
- No actionable P0/P1/P2 issue remained.

## Follow-up polish

- [P3] The Map tour uses a solid cream status-area privacy mask above the real map capture. This is an intentional tradeoff that prevents a duplicated source status bar from appearing beneath the live iOS status bar.

## Final result

final result: passed

---

# Dynamic Mugsy scene system — implementation QA

## Comparison setup

- Approved brand source: `/Users/joe.rosso/.codex/state/plugins/product-design/assets/mugshot-v3-approved-five-screen-direction.png`.
- Character source of truth: the existing code-native canonical model in `testMugshot/Design/MugsyDesignSystem.swift` and `testMugshot/Views/Components/MugsyModelView.swift`.
- Semantic source of truth: the approved requirement for ten context-aware scene families with only happy, joyful, curious, proud, cozy, playful, or welcoming production expressions.
- Production evidence:
  - `docs/design/dynamic-mugsy-2026-08-05/evidence/01-studio-scenes-1-4-reduce-motion.png`
  - `docs/design/dynamic-mugsy-2026-08-05/evidence/02-studio-scenes-5-10-reduce-motion.png`
  - `docs/design/dynamic-mugsy-2026-08-05/evidence/03-saved-want-to-try.png`
  - `docs/design/dynamic-mugsy-2026-08-05/evidence/04-cafe-detail-want-to-try-no-photo.png`
  - `docs/design/dynamic-mugsy-2026-08-05/evidence/05-saved-want-to-try-accessibility-xxxl.png`
- Combined comparison input: `docs/design/dynamic-mugsy-2026-08-05/evidence/06-source-and-implementation-comparison.png`.
- Viewport: iPhone 17 Pro at 402 x 874 points and 1206 x 2622 pixels at 3x; forced-light appearance.
- Fixture: deterministic DEBUG/UI-test-only Saved data with no authentication, production data, analytics, or remote mutations.

No prior image contained these exact ten semantic scenes. The combined comparison therefore tests character identity, proportions, line treatment, palette, typography, and integration with the approved Mugshot V3 product language; the ten-family product behavior is verified by the Studio gallery, production screens, semantic snapshots, and focused tests.

## Required fidelity surfaces

- **Character identity:** White ceramic body, black hand-drawn outline, square glasses, handle, highlight/shadow behavior, bow tie, and face proportions remain those of the canonical Mugsy model.
- **Expression:** Every production family uses a positive expression. The tender and concerned expressions remain available only as internal model capabilities and are filtered from product placement controls.
- **Context:** Props, outfits, arm poses, leg poses, and coffee states communicate the difference between discovery, Want to Try, Favorite, visited, journal, friends, home ritual, first sip, shared lists, and welcome states without changing Mugsy's identity.
- **Brand integration:** Cream, sand, mint, sage, espresso, and white surfaces match the approved Mugshot V3 palette and density. No stock art, emoji, or disconnected illustration style was introduced.
- **Motion:** Small cards and rows are static. Hero motion remains optional, subtle, and disabled when Reduce Motion is active.
- **Truthfulness:** Mugsy is never substituted for a loading skeleton, failed photo, removed/private media, offline state, or unavailable data.
- **Accessibility:** Placeholder groups expose one concise accessibility label rather than announcing decorative Mugsy subparts. Accessibility XXXL reflows the surrounding Saved UI without shrinking text.

## Comparison history

### Pass 1

- **P2 — Studio gallery cards exposed duplicate child semantics.** The gallery had a combined description but still allowed decorative child labels to enter traversal.
  - Fix: the gallery card now ignores child semantics and exposes one combined family/context label.
- **P2 — The first-sip scene read too similarly to the neutral wishlist pose when static.** Reduce Motion removes celebratory animation, so the silhouette needed a stronger static distinction.
  - Fix: the family now uses a presenting arm and bent planted legs while retaining the approved joyful expression.

### Final pass

- Rebuilt and launched the final source on the iPhone 17 Pro Simulator.
- Captured all ten scene families with Reduce Motion enabled, then captured production Saved card, expanded detail, and accessibility XXXL states.
- Inspected every image at its original 1206 x 2622 resolution and judged the source and implementation together in the 2800 x 1840 comparison board.
- No actionable P0, P1, or P2 visual, semantic, or product-truth mismatch remains.

## Verification evidence

- Repository full static verification: 11 passed, 0 failed, 1 optional `pglast` check skipped because the dependency is not installed.
- Focused Mugsy design-system suite: 12 passed, 0 failed.
- Final Simulator build and launch: passed.
- Runtime semantic snapshots: passed for the Studio gallery, Saved Want to Try cards, expanded cafe detail, and accessibility XXXL category menu.
- Full source-and-implementation visual comparison: passed.

final result: passed

---

# Mugshot Post V2 — Editorial Pour QA

## Comparison target

- Source visual truth:
  - `docs/product-research/mugshot-post-v2/editorial-pour-full-post/01-canonical-full-post.png`
  - `docs/product-research/mugshot-post-v2/editorial-pour-full-post/02-score-evidence-expanded.png`
  - `docs/product-research/mugshot-post-v2/editorial-pour-full-post/03-journal-visit-expanded.png`
  - `docs/product-research/mugshot-post-v2/editorial-pour-full-post/05-photo-viewer.png`
  - `docs/product-research/mugshot-post-v2/editorial-pour-full-post/06-no-photo-fallback.png`
- Rendered implementation evidence:
  - `docs/product-research/mugshot-post-v2/design-qa-evidence/canonical-photo-comparison.png`
  - `docs/product-research/mugshot-post-v2/design-qa-evidence/no-photo-comparison.png`
  - `docs/product-research/mugshot-post-v2/design-qa-evidence/taste-evidence-comparison.png`
  - `docs/product-research/mugshot-post-v2/design-qa-evidence/journal-comparison.png`
  - `docs/product-research/mugshot-post-v2/design-qa-evidence/visit-context-comparison.png`
  - `docs/product-research/mugshot-post-v2/design-qa-evidence/photo-viewer-comparison.png`
- Viewport: iPhone 16 Pro Simulator on iOS 18.6, captured at 368 × 800 pixels in light mode.
- Normalization: the 853 × 1844 source state boards were scaled to 368 pixels wide, then cropped or padded to 368 × 800. Simulator captures were already 368 × 800. Device scale factor is not applicable to the optimized XcodeBuildMCP capture output.
- States: canonical three-photo post, Mugsy no-photo fallback, collapsed and expanded taste evidence, expanded shared journal, collapsed and expanded Visit Context, conversation content, and full-screen photo paging.

Every source and implementation state was placed into one side-by-side comparison image before the final assessment. Focused comparisons were required because the journal typography, Visit Context rows, taste evidence, and photo viewer are not readable enough in one full-post capture.

## Required fidelity surfaces

- **Fonts and typography:** Passed. The implementation uses the approved iOS system-serif for drink titles, editorial captions, evidence headings, journal copy, and private notes, with system sans-serif for controls and metadata. Scale, weight, wrapping, and hierarchy remain readable at the 368-point viewport.
- **Spacing and layout rhythm:** Passed. The post reads as one continuous cream editorial surface. Author, media, title, score, action rail, social proof, evidence, people, journal, Visit Context, private note, and conversation follow the selected order with 44-point-or-larger controls and no overlap.
- **Colors and visual tokens:** Passed. Cream, foam, sand, espresso, sage, mint, and line tokens come from the existing Mugshot design system. Selected, expanded, private, and score states do not rely on color alone.
- **Image quality and asset fidelity:** Passed. Production photos remain real user media. QA used existing Mugshot raster assets to exercise the multi-photo path. The no-photo state uses the established Mugsy model instead of a generic placeholder, and the viewer preserves the complete image with editorial letterboxing.
- **Copy and content:** Passed. Product strings use `cafe` consistently. The shared journal names its actual audience, explains that the note stays inside that audience, and keeps Visit Context separate. No precise address appears in the public presentation model.
- **Icons:** Passed. SF Symbols remain consistent in weight and alignment across actions, ratings, journal privacy, Visit Context facts, and the viewer.
- **States and interactions:** Passed. Taste, journal, and Visit Context disclosures were opened and closed independently. Visit Context starts collapsed. Photo paging and thumbnail selection work, and the conversation composer remains reachable.
- **Accessibility and resilience:** Passed for the scoped implementation. Runtime snapshots exposed semantic toggle values, descriptive photo controls, and stable identifiers. Dynamic Type branches, Reduce Motion fallbacks, multiline wrapping, and safe-area spacing were reviewed in code; no clipped state appeared at 368 × 800.

## Comparison history

### Pass 1

- **P2 — Mugsy fallback read as a compressed banner.**
  - Evidence: the first implementation placed Mugsy and copy in a shallow edge-to-edge region, while the source used a proper editorial media card.
  - Fix: increased the media region, constrained the author row, inset the fallback, added the approved rounded surface, and centered Mugsy above the copy.
- **P2 — Taste evidence was too compact and appeared in the wrong visual order.**
  - Evidence: small score chips followed the disclosure heading, while the selected direction established Sip and Cafe as primary evidence before the expandable explanation.
  - Fix: introduced the two-column Sip/Cafe score strip with large serif numerals and restrained star evidence, then placed `What shaped this Mugshot?` below it.
- **P2 — Tagged people consumed several rows.**
  - Evidence: the implementation repeated full account rows where the reference used one compact social attribution.
  - Fix: collapsed tags into one avatar stack and `With Jamie and Marco` row while keeping each avatar independently tappable.

### Pass 2

- **P2 — Full-screen photos were cropped instead of preserved.**
  - Evidence: the first viewer capture filled the viewport and cut off the drink, while the selected viewer showed the complete image on an espresso canvas.
  - Fix: added a viewer-specific fit renderer for local, remote, and QA asset sources; retained the count, thumbnail rail, selected outline, and drink/location caption.
- Recaptured the canonical post, no-photo fallback, taste evidence, journal, Visit Context, and viewer after the fixes.
- No actionable P0, P1, or P2 visual or interaction mismatch remains.

## Follow-up polish

- **P3:** The source viewer sketches an owner-only `Set as cover` action and a second share icon. The current viewer intentionally remains a browsing surface; cover mutation stays in editing behavior, and the working Share Hub remains in the post action rail.
- **P3:** QA fixtures use initial avatars when no profile image URL is available. The production avatar component still renders real remote profile images when supplied.
- **P3:** The app-owned content preserves native iOS status and navigation chrome, so less below-the-fold evidence appears in the first 368 × 800 capture than in the unframed concept board.

## Verification evidence

- Repository no-Simulator gate: 11 passed, 0 failed, 1 optional parser check skipped because local `pglast` is not installed.
- Focused `SipDetailPresentationTests`: 12 passed, 0 failed.
- Focused Editorial Pour disclosure UI test: 1 passed, 0 failed.
- Debug build and Simulator launch: passed for photo, no-photo, taste, journal/Visit Context, and viewer states.
- No Supabase environment was contacted or changed.

final result: passed

---

# Log a Sip V3 Production Criterion Parity QA

## Comparison target

- Reported production mismatch:
  - `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/codex-clipboard-2ca422f8-757e-4a91-9f56-84df11d1de8c.png`
- Approved UI Lab visual truth:
  - `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/codex-clipboard-b76244ac-4d7e-47ab-b0e2-5495596fd9bf.png`
  - `docs/product-research/mugshot-v3/production-parity/lab-sip.jpg`
  - `docs/product-research/mugshot-v3/production-parity/lab-cafe.jpg`
- Final production implementation:
  - `docs/product-research/mugshot-v3/production-parity/production-sip.jpg`
  - `docs/product-research/mugshot-v3/production-parity/production-cafe.jpg`
- Full-view comparison evidence:
  - `docs/product-research/mugshot-v3/production-parity/lab-vs-production-full.png`
- Focused criterion comparison evidence:
  - `docs/product-research/mugshot-v3/production-parity/lab-vs-production-criteria-focused.png`
- Viewport: two separate iPhone 17 Pro Simulators on iOS 27, each captured at 368 x 800 pixels in light mode.
- State: matching Iced Orange Creamsicle Cafe fixture. Sip uses Body 1.5/More/pinned, Presentation 4.0/Less, Orange balance 3.0/Normal, overall Sip 2.5, and advisory 2.4. Cafe uses Atmosphere 3.0/Most/pinned, Value 2.0/More/pinned, overall Cafe 3.5, and advisory 2.6.

The UI Lab and production app were kept open on separate booted Simulators. Both Sip and Cafe captures were placed together in the same full-view and focused comparison inputs before the final assessment.

## Required fidelity surfaces

- **Fonts and typography:** Production and the UI Lab now render the promoted shared criterion components, so title, helper, numeric score, importance, suggestion, and advisory typography use the same system font, weight, size, and wrapping. The approved system-serif treatment elsewhere in the flow is unchanged.
- **Spacing and layout rhythm:** Both surfaces use one grouped criterion card with zero row spacing, 12-point row padding, 48-point indented dividers, 36-point icon circles, 26-point star artwork on 44-point touch regions, stacked 27-point circular actions, and a 34-point importance capsule. The final captures preserve the same card width, row density, radii, dividers, suggestion rail, advisory card, and sticky action.
- **Colors and visual tokens:** Lab and production share Mugshot cream, foam, sage, mint, sand, espresso, and line tokens directly. Pinned, selected, advisory, disabled, and unselected states use the same opacities and borders.
- **Image quality and asset fidelity:** The compared region uses the same SF Symbols and code-native controls in both implementations; no emoji, placeholder drawing, handcrafted SVG, or substitute asset was introduced. Photo and Mugsy surfaces outside this focused change remain untouched.
- **Copy and content:** Helper language, `Use last setup`, human importance labels, idea counts, advisory-score copy, and Sip/Cafe action copy match. Production catalogs now preserve the UI Lab's 24 Sip and 21 Cafe criteria in the same order, including the first visible Cafe chips: Atmosphere, Service, and Comfort.

## Interaction and state evidence

- Verified the production Sip-to-Cafe handoff with the durable `SipDraft` bindings; the same promoted row component renders `ratingCriteria` and `contextRatingCriteria` without an adapter copy.
- Verified half-step criterion entry and fractional rendering, including an exact adopted decimal such as 2.4.
- Verified human-language importance selection, pin/unpin persistence, removal confirmation, suggestion addition, `Use last setup`, and the advisory score remaining optional.
- Verified the Mugsy prompt position is parent-owned when moving away and back.
- Expanded production Mugsy coaching to eight observation-first prompts for Sip and eight for Cafe; the 24/21 criteria catalogs remain separate and intact.
- Focused domain suite: 13 passed, 0 failed.
- Focused production UI journey: 1 passed, 0 failed after exercising importance, pin, removal, suggestion counts, and Sip-to-Cafe navigation.
- Final Debug Simulator build: passed.
- Final dual-Simulator manual Sip and Cafe journey: passed.
- Runtime log check found no app fatal error, assertion failure, uncaught exception, crash, or termination signal. The iOS 27 Simulator emitted its known duplicate WebKit accessibility-bundle runtime warning on both devices; it did not affect the app journey.

## Comparison history

### Pass 1

- **P1 - Production criteria were materially taller than the approved UI Lab.** Each criterion had its own large card, large full-width stars, and a full-width importance bar, causing large blank regions and turning optional reflection into a much longer scroll.
  - Fix: promoted the UI Lab fractional-star, compact criterion row, suggestion chip, and advisory card into shared production-safe components; production Sip and Cafe now bind their durable models directly into those components.
- **P2 - Production pin, remove, importance, and suggestion treatments drifted from the approved controls.** Bare 44-point glyphs, the system-like full-width importance row, and different chip states did not match the Lab.
  - Fix: wired the Lab's stacked 27-point circular actions, branded popover/capsule importance control, grouped dividers, icon resolution, chip states, and removal confirmation into both real surfaces.
- **P2 - Supporting reflection chrome still differed.** The overall stars used discrete SF half-star symbols, the advisory card was flat, the sticky subtitle sat outside its action, and Cafe suggestion order differed.
  - Fix: reused the Lab fractional-mask star rendering, advisory card, sticky action composition, and Sip/Cafe criterion catalogs.

### Pass 2

- Rebuilt and captured matching Sip and Cafe fixtures on two iPhone 17 Pro Simulators.
- Opened the full-view and focused Lab-versus-production boards together.
- No actionable P0, P1, or P2 visual mismatch remains in the shared reflection region.

## Follow-up polish

- **P3:** Production intentionally retains its real back button beside Close, while the DEBUG Lab uses review-only step navigation. This is host navigation, not criterion-component drift.
- **P3:** Status-bar time and the exact scroll offset differ by a few pixels between independently controlled Simulators; component geometry and density match.

final result: passed

---

# Mugshot V3 Production Composer Migration QA

## Comparison target

- Source visual truth:
  - `docs/product-research/mugshot-v3/references/approved-v3-five-screen-direction.png`
  - `docs/product-research/mugshot-v3/references/cafe-reflection-direction.png`
  - `docs/product-research/mugshot-v3/ui-lab/01-setup.jpg`
  - `docs/product-research/mugshot-v3/ui-lab/02-sip.jpg`
  - `docs/product-research/mugshot-v3/ui-lab/03-cafe.jpg`
  - `docs/product-research/mugshot-v3/ui-lab/04-publish.jpg`
  - `docs/product-research/mugshot-v3/ui-lab/05-passport.jpg`
- Rendered production implementation:
  - `docs/product-research/mugshot-v3/production-migration/01-setup.png`
  - `docs/product-research/mugshot-v3/production-migration/02-sip.png`
  - `docs/product-research/mugshot-v3/production-migration/03-home.png`
  - `docs/product-research/mugshot-v3/production-migration/04-publish.png`
  - `docs/product-research/mugshot-v3/production-migration/05-passport.png`
- Full-view comparison evidence: `docs/product-research/mugshot-v3/production-migration/full-comparison.png`
- Focused comparison evidence: `docs/product-research/mugshot-v3/production-migration/focused-comparison.png`
- Viewport: iPhone 17 Pro Simulator, 368 x 800 pixels.
- State: production Home memory using the deliberate Mugsy missed-photo fallback, an authored Sip score, Home reflection, required caption, local publication, and first-memory Taste Passport.

The approved UI Lab captures and production captures were combined into one same-viewport comparison image before review. The Sip and Publish surfaces were also combined into a focused comparison because those screens contain the densest typography, scoring, journal, and action hierarchy.

## Required fidelity surfaces

- **Fonts and typography:** Production uses the approved iOS system-serif display hierarchy and system sans-serif controls. Heading scale, weights, line lengths, supporting copy, and score hierarchy remain consistent with the approved UI Lab. The intentional Source Serif 4 design-to-system-serif code decision is preserved.
- **Spacing and layout rhythm:** The composer is a full-screen journey with stable safe areas, cream canvas, restrained cards, quiet borders, aligned section spacing, and a persistent action above the home indicator. No visible overlap, clipping, or unusable control was found at 368 x 800.
- **Colors and visual tokens:** Cream, foam, sage, mint, line, and espresso colors come from Mugshot's existing tokens. Selected context, progress, score, privacy, completion, and disabled-action states remain distinguishable without relying on color alone.
- **Image quality and asset fidelity:** Production photo states use real user images. The no-photo path uses the established code-native Mugsy component and branded fallback surface instead of a generic placeholder. Hero masks, crops, and Passport background treatment remain sharp and correctly bounded.
- **Copy and content:** Log a Sip, journal privacy, optional criteria, Home make-again reflection, required caption, Mugshot score, and Taste Passport language match the locked interview. The first-memory Passport intentionally says the identity is forming rather than inventing a pattern from one entry.
- **Icons and accessibility:** System icons retain a consistent weight and alignment. Star inputs, context pills, navigation, publishing, and recovery controls expose labels and practical touch targets. The five-screen progress treatment has a published-state accessibility label.

## Primary interactions tested

- Opened the production composer from the real Add tab as a full-screen flow.
- Selected Home, deliberately chose the Mugsy missed-photo fallback, and named the drink.
- Entered the Sip surface, selected an honest score, and advanced to Home reflection.
- Chose a make-again response, entered the required caption, and published the memory.
- Reached Taste Passport, verified the published entry and score, and confirmed the visible `5 of 5` completion state.
- Confirmed local draft/photo recovery primitives, V3 context serialization, feed projection batching, and non-cafe association behavior in focused tests.
- Checked captured runtime logs for fatal errors, crashes, assertions, duplicate publication, data-loss messages, and app faults. The only match was a Simulator-runtime WebKit accessibility-class warning outside Mugshot.

## Comparison history

### Pass 1

- **P2 - Production described the approved five-screen journey as four steps.** Setup through Publish displayed `1 of 4` through `4 of 4`, while the locked flow includes Taste Passport as screen five.
  - Fix: changed production progress to `1 of 5` through `4 of 5` and added the published Passport completion as `5 of 5`.

### Pass 2

- **P2 - iOS toolbar styling collapsed the Passport completion label to its icon.** The accessibility label was correct, but the visible `5 of 5` text was absent in the rendered capture.
  - Fix: replaced the toolbar `Label` with an explicit checkmark-and-text stack, rebuilt, completed the full journey, and recaptured all five production states.

### Pass 3

- The final same-viewport full and focused comparisons show the five-screen count on every production surface.
- Dynamic Home and first-memory Passport content differ intentionally from the populated Cafe fixture while preserving the approved structure, hierarchy, and Mugshot visual language.
- No actionable P0, P1, or P2 finding remains.

## Verification evidence

- Debug production build and launch: passed.
- Release Simulator build: passed.
- Focused V3 domain, recovery, detail, context, and projection tests: passed.
- Production Home -> Sip -> Context -> Publish -> Taste Passport UI journey: passed after the final visual fix.
- Live Supabase V3 contract: passed; no V3 performance advisor finding.
- Final source-and-production visual comparison: passed.

final result: passed

---

# Tasting Lens 2.0 Design QA

## Scope

Production implementation of the Tasting Lens 2.0 journey across brewed coffee, espresso, milk coffee, matcha, specialty matcha latte, hojicha, tea, milk tea, additions, and the universal fallback.

The journey keeps these concepts distinct:

- the drink identity and ingredient provenance;
- the user's own words;
- broad-to-specific flavor vocabulary;
- typed sensory observations, uncertainty, and confidence;
- personal preference and optional style impression;
- independent half-step enjoyment stars;
- immutable private snapshots and optional lossy social projections.

## Reference comparison

Accepted references:

- `/Users/joe.rosso/.codex/generated_images/019f6c5b-9d2c-7f73-95d1-b8fcde370cfe/exec-9de9fb82-48cb-4012-928e-05f478decb37.png`
- `/Users/joe.rosso/.codex/generated_images/019f6c5b-9d2c-7f73-95d1-b8fcde370cfe/exec-33aead15-9f24-4b7e-a3fd-d9494edc58f3.png`
- `/Users/joe.rosso/.codex/generated_images/019f6c5b-9d2c-7f73-95d1-b8fcde370cfe/exec-c4ed0abf-0561-488d-b7ce-c37532e951cb.png`

Combined reference-versus-build board:

- `/Users/joe.rosso/.codex/visualizations/2026/07/16/019f6c5b-9d2c-7f73-95d1-b8fcde370cfe/tasting-lens-qa/reference-vs-build.png`

Visible comparison findings:

- The cream, espresso, sage, mint, sand, serif-heading, and rounded-control language matches Mugshot's established brand.
- “Start with your words” preserves the reference hierarchy while deliberately hiding suggestions until the user has formed a first impression.
- The flavor explorer preserves the memorable web relationship while adding real broad-to-specific disclosure, custom language, ingredient provenance, and accessible list mode.
- Mugsy remains a brief contextual guide, with drink-specific first-sensation choices, optional closer distinctions, and a “why” explanation.
- Navigation, progress, primary actions, uncertainty states, and selection feedback are production controls rather than visual placeholders.
- Personal stars and the final Taste Snapshot extend the accepted direction without turning observations into a score formula.

## Product behavior QA

- Completed a clean Guided specialty matcha latte journey on iPhone 17 Pro at 368 x 800.
- Confirmed matcha-specific dispersion and texture questions appeared.
- Confirmed added orange remained ingredient provenance and did not become a claimed base-drink detection.
- Confirmed own words, Orange-like flavor, Mugsy guidance, observations, and a 2.5 personal rating remained distinct in the snapshot.
- Saved the sip privately and reached the completion state.
- Automated the complete Lens journey through Friends visibility, save, Journal reopen, and sensory-trail disclosure.
- Confirmed Quick, Guided, and Deep selection logic, universal fallback, old-draft migration, preference correction retry, offline draft restore, and repeated-evidence personalization thresholds in focused tests.

## Accessibility and motion QA

- Verified the largest accessibility content size.
- Corrected an initial header/footer crowding defect found during this check.
- Rechecked the corrected layout: compact header, reachable action, scrollable content, and no hidden required control.
- Confirmed the flavor web automatically becomes a disclosure list at accessibility text sizes.
- Confirmed Reduce Motion was `true` inside the running Mugshot process.
- Re-ran the complete save-and-reopen UI journey with Reduce Motion enabled; it passed.

## Data and privacy QA

- Full sensory snapshots are owner-private and insert-only.
- Corrections are append-only; preferences remain editable and account-scoped.
- Public projection storage cannot contain own words, full responses, or snapshot payloads.
- Canonical payload fields are cross-checked against indexed columns.
- Descriptor and dimension projections are bounded and identifier-only, including the `unexpected` dimension.
- Live read-only dependency preflight confirmed `set_updated_at()`, `can_view_visit(uuid, uuid)`, and the required visit-owner composite key exist.
- The production migration was deployed as four tracked, ordered migrations after live save diagnostics exposed the missing-schema release boundary.

## Verification evidence

- Debug Simulator build: passed.
- Release Simulator build: passed.
- Tasting Lens domain suite: 21 passed, 0 failed.
- Adjacent app unit suite: 91 passed, 0 failed.
- Sip detail presentation suite: 5 passed, 0 failed.
- Full Tasting Lens UI journey: passed normally and passed again with Reduce Motion enabled.
- Knowledge bundle JSON validation: passed.
- Swift/SQL diff whitespace checks: passed.

final result: passed

---

# Deep Tasting Lens posting recovery QA

## Reported state

- Source screenshot: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/codex-clipboard-34ae6fd0-7031-4992-bde8-0958659d387b.png`
- The UI reported a photo failure after a completed Deep Tasting Lens save.
- Production request logs showed the actual failure was a `404` while inserting the private sensory snapshot.
- Photo storage was never called, so the selected image was not the cause.
- The private visit shell remained server-side in a failed upload state with no attached photo, preserving the same-ID retry boundary.

## Repairs

- Deployed the missing Tasting Lens schema as four tracked production migrations:
  - `20260717114908_tasting_lens_2_core`
  - `20260717114953_tasting_lens_2_security`
  - `20260717115015_tasting_lens_2_export`
  - `20260717115054_tasting_lens_2_indexes`
- Split save diagnostics and recovery copy by visit creation, Tasting Lens snapshot, photo upload, and finalization.
- Removed the misleading instruction to remove the photo.
- Changed replacement photo uploads to storage upserts so an ambiguous interrupted request can retry without a duplicate-object loop.
- Kept the immutable sensory snapshot write ahead of publication and made retry verify or repair it before finalizing the visit.

## Live contract verification

- Confirmed all four production tables exist with forced RLS.
- Confirmed an owner could insert and read a sensory snapshot while a different authenticated user could not read it.
- Rolled the live probe transaction back and confirmed it left no probe row.
- Confirmed the new owner, projection, correction, and foreign-key support indexes exist.
- Confirmed the canonical Swift snapshot encoder writes `personalEnjoyment` as the numeric half-step expected by the SQL contract.

## Build and test evidence

- Debug Simulator build and launch: passed with no warnings or errors.
- Release Simulator compile: passed with no warnings or errors.
- Tasting Lens domain suite: 21 passed, 0 failed.
- Adjacent app unit suite: 91 passed, 0 failed, including stage-specific retry copy.
- Relaunch-and-retry photo UI test: 1 passed, 0 failed.
- Migration and knowledge-bundle integrity checks: passed.
- Diff whitespace and ASCII `cafe` checks: passed.

## Remaining observation

- The original pending save lives on the user's physical device. Its server-side prerequisites and retry contract are repaired, but the final tap on that device cannot be observed from the Simulator.

final result: passed; original-device retry confirmation remains observational

---

# Mugshot V3 UI Lab Design QA

**Final result:** passed

## Comparison target

- Source visual truth:
  - docs/product-research/mugshot-v3/references/approved-v3-five-screen-direction.png
  - docs/product-research/mugshot-v3/references/cafe-reflection-direction.png
- Rendered implementation:
  - docs/product-research/mugshot-v3/ui-lab/01-setup.jpg
  - docs/product-research/mugshot-v3/ui-lab/02-sip.jpg
  - docs/product-research/mugshot-v3/ui-lab/03-cafe.jpg
  - docs/product-research/mugshot-v3/ui-lab/04-publish.jpg
  - docs/product-research/mugshot-v3/ui-lab/05-passport.jpg
- Viewport: iPhone 17 Pro Simulator; XcodeBuildMCP optimized captures at 368 x 800 pixels.
- State: populated Cafe fixture for an Iced Orange Creamsicle at The Daily, using 2.5 Sip, 3.5 Cafe, and 3.0 Mugshot scores.

The two complete reference boards and all five final Simulator captures were opened together in one comparison input. The setup, sip, cafe, publish, and passport captures are each focused phone-size comparisons; separate crops were not needed because typography, controls, photos, criteria, and supporting copy remained legible at the captured resolution.

## Required fidelity surfaces

- **Fonts and typography:** The implementation preserves the approved editorial serif hierarchy with Mugshot's iOS system-serif modifier. Small controls use the existing system sans-serif. The expected Source Serif 4-to-system-serif platform difference is intentional and does not change hierarchy or wrapping materially.
- **Spacing and layout rhythm:** Cream canvas, restrained card borders, rounded image masks, compact criteria, and bottom actions track the source. The extra back control and n-of-5 menu are intentional DEBUG-only review chrome; they will not define production navigation. All content remains scrollable above the sticky action.
- **Colors and visual tokens:** The implementation uses the existing Mugshot cream, foam, sage, mint, sand, line, and espresso tokens. Selection, score, and confidence treatments match the source's quiet sage emphasis.
- **Image quality and asset fidelity:** All drink and place imagery is raster source material in the asset catalog. The final hero is a project-bound ImageGen edit with natural orange peel, creamsicle marbling, and a wide-card crop that reads correctly at setup and publish sizes. No placeholder drawing or inline vector approximation is used.
- **Copy and content:** Titles, journal/private distinction, advisory criteria language, blended score, audience framing, evidence counts, confidence language, and non-radar Taste Passport identity all follow the locked interview record.

## Interaction evidence

- Opened the lab from Settings > Developer.
- Completed Setup -> Sip -> Cafe -> Publish -> Taste Passport once.
- Switched Cafe to Home and verified the surface changed to "Would you make it again?", then returned to Cafe.
- Opened Mugsy coaching, advanced from the first to the second prompt, and verified the prompt state advanced without changing the journal text.
- Exercised the publish action and verified it landed on Taste Passport.
- The final Debug build and launch passed. Four focused fixture tests passed, covering advisory scoring, Home scoring, raw-note visibility constraints, and human-language importance weights. Runtime logs contained no fatal error, assertion failure, crash, uncaught exception, or app-termination signal during the checked journey.

## Comparison history

### Pass 1

- **P2 - Hero did not communicate orange creamsicle clearly.** The first asset read as a generic iced latte, while the source used visible orange garnish and cream/orange movement.
  - Fix: generated a non-destructive V2 hero edit with thin orange-peel curls, a small orange segment, and subtle creamsicle marbling; updated the lab to use V3OrangeCreamsicleHeroV2.
- **P2 - Criterion rows were materially taller than the source.** Only one criterion appeared above the action, making optional depth feel longer and more work-like.
  - Fix: changed the criterion component to a compact shared-card row with title, small half-star rating, human-language importance, pin, and remove controls on one line.

### Pass 2

- **P2 - Cafe journal height hid the suggestions that the approved source kept visible.**
  - Fix: tightened only the context journal to a 106-point minimum while preserving room for two lines of raw thought and the Mugsy prompt affordance.

### Pass 3

- Rebuilt and recaptured the revised Cafe state.
- No actionable P0, P1, or P2 mismatch remained.

## Follow-up polish

- **P3:** The DEBUG-only back button and step menu add review chrome above the source composition. Keep them in the lab for fast navigation; omit or redesign them when the flow is mapped into production navigation.
- **P3:** The Passport uses a restrained map-memory card instead of the source's decorative route and stamp illustration. The city-memory meaning is preserved; a bespoke illustration can be added later if alpha feedback shows it materially improves delight.

---

# Mugshot V3 UI Lab Simulator-Feedback Revision QA

## Comparison target

- Source visual truth:
  - `docs/product-research/mugshot-v3/references/approved-v3-five-screen-direction.png`
  - `docs/product-research/mugshot-v3/references/cafe-reflection-direction.png`
- Rendered implementation:
  - `docs/product-research/mugshot-v3/ui-lab-v2/01-setup.jpg`
  - `docs/product-research/mugshot-v3/ui-lab-v2/02-sip.jpg`
  - `docs/product-research/mugshot-v3/ui-lab-v2/02b-sip-criteria.jpg`
  - `docs/product-research/mugshot-v3/ui-lab-v2/03-cafe.jpg`
  - `docs/product-research/mugshot-v3/ui-lab-v2/04-publish.jpg`
  - `docs/product-research/mugshot-v3/ui-lab-v2/04b-publish-controls.jpg`
  - `docs/product-research/mugshot-v3/ui-lab-v2/05-passport.jpg`
  - `docs/product-research/mugshot-v3/ui-lab-v2/05b-passport-details.jpg`
- Combined full-view evidence: `docs/product-research/mugshot-v3/ui-lab-v2/design-qa-comparison.png`
- Viewport: iPhone 17 Pro Simulator; 368 x 800 pixel captures.
- State: populated Cafe memory for an Iced Orange Creamsicle at The Daily, with a 2.5 Sip score, 3.5 Cafe score, exact 2.4 Sip criteria suggestion, and 3.0 Mugshot score.

Both complete reference boards and all eight final Simulator captures were opened together in one comparison input. `02b-sip-criteria.jpg` and `04b-publish-controls.jpg` provide focused evidence for the two densest revised regions.

## Required fidelity surfaces

- **Typography:** Editorial system-serif headings preserve the Source Serif 4 design hierarchy intended for Figma while using the approved iOS system-serif implementation. Control copy remains compact system sans-serif.
- **Spacing and layout:** The five full-screen surfaces retain the cream canvas, quiet cards, sticky primary action, and optional-depth hierarchy. The Setup surface owns cover selection; Publish no longer repeats it.
- **Color and branding:** Mint cover state, sage score and action hierarchy, branded importance popovers, inline Mugsy coaching, and the generated archival city-map backdrop use existing Mugshot tokens consistently.
- **Image quality:** Four current-memory photos render cleanly in the setup picker and Publish carousel. The Passport backdrop remains legible under live content without competing with the evidence cards.
- **Copy and content:** Audience and raw-note visibility share one control language; raw-note visibility cannot exceed the post audience. Mugshot leads the score hierarchy, with Sip and Cafe nested as evidence.

## Interaction evidence

- Presented the DEBUG UI Lab with a full-screen cover from Settings and completed Setup -> Sip -> Cafe -> Publish -> Taste Passport.
- Selected the cover in Setup and verified the mint/star treatment remains the source of truth on Publish.
- Opened the inline Mugsy coach without presenting a bottom sheet.
- Opened the flavor explorer and completed Flavor -> Fruit -> Citrus -> Orange, preserving the visible internal-prototype attribution.
- Verified the criteria advisory remains exact at 2.4 while the user-owned Sip score stays 2.5 until explicitly adopted.
- Verified 24 Sip suggestions and 21 Cafe suggestions, larger criterion stars, stacked pin/remove controls, branded importance choices, and removal confirmation.
- Verified the Publish photo carousel, Mugshot-first score hierarchy, matched visibility selectors, and five recommended friend avatars plus the expanded picker affordance.
- Published into Taste Passport and verified the optional `Pour another one` action leaves the completed-memory state visually primary.

## Comparison history

### Pass 1

- **P1 - Taste Passport background overflowed its horizontal bounds.** The generated map backdrop expanded beyond the phone viewport and clipped content alignment.
  - Fix: constrained the backdrop with a `GeometryReader`, explicit viewport sizing, and clipping before applying the safe-area treatment.
- **P1 - Presenting a nested flavor sheet reset the UI Lab to Setup.** The full-screen host was attached to a transient Developer button subtree, so nested presentation rebuilt the lab state.
  - Fix: moved the full-screen presentation host to the stable Settings root. Re-ran the Flavor -> Fruit -> Citrus -> Orange journey without losing the Sip surface.

### Pass 2

- **P2 - Half-star hit regions still followed the 26-point artwork.** The criteria looked larger but retained overly precise touch targets.
  - Fix: expanded every rating star to a 44-point-high invisible gesture target while preserving the approved 26-point artwork and half-step selection.
- **P2 - Caption was visually required but not behaviorally required.** Clearing it left Publish enabled.
  - Fix: centralized the locked minimum validation, disabled Publish until the required fields are complete, and capped the caption at 80 characters.
- **P2 - Mugsy's coach wiggle ignored Reduce Motion.**
  - Fix: removed the spring, rotation, scaling, and prompt transition animations whenever Reduce Motion is enabled.
- Rebuilt the full flow and recaptured the visually affected Sip and Cafe surfaces; the unchanged Setup, Publish, and Passport captures remained valid.
- Confirmed the final Passport stays within the 368-point viewport and the nested flavor sheet preserves the active Sip state.
- No actionable P0, P1, or P2 visual or interaction mismatch remained.

## Verification evidence

- Final Debug Simulator build and launch: passed.
- Complete five-screen Simulator journey: passed.
- Focused V3 fixture suite: 9 passed, 0 failed.
- Full source-and-implementation visual comparison: passed.

final result: passed

---

# Feed and Full Post Refresh QA

## Comparison target

- Source visual truth:
  - `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/codex-clipboard-642d658d-92bf-4a6e-8df2-70df19d60e90.png` (current feed hierarchy)
  - `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/codex-clipboard-a715118b-8260-42d6-bf9f-c90e7b216fd9.png` (share-card overlay language)
- Combined reference-and-implementation input: `docs/design-qa/feed-full-post-refresh/comparison-board.png`
- Final Simulator captures:
  - `docs/design-qa/feed-full-post-refresh/feed-top.jpg`
  - `docs/design-qa/feed-full-post-refresh/feed-long-overlay.jpg`
  - `docs/design-qa/feed-full-post-refresh/feed-square.jpg`
  - `docs/design-qa/feed-full-post-refresh/feed-no-photo.jpg`
  - `docs/design-qa/feed-full-post-refresh/amanda-detail.jpg`
  - `docs/design-qa/feed-full-post-refresh/joe-detail.jpg`
- Viewport: iPhone 17 Pro Simulator; XcodeBuildMCP optimized captures at 368 x 800 pixels.
- Density normalization: the 1206 x 2622 reference captures were resized to the same 368 x 800 aspect and placed beside the native 368 x 800 implementation capture. The comparison evaluates the requested hierarchy and visual language; post content and the DEBUG-only feed header state intentionally differ.
- State: deterministic Friends feed with Amanda directly above Joe, a 1,000-scalar Amanda caption, landscape and square media, an extreme portrait source, Home and Elsewhere contexts, a two-photo carousel, and a 3:4 no-photo fallback.

The current-feed reference, share-card reference, and rendered feed were opened as one side-by-side comparison input. The focused captures cover long overlay text, square media, no-photo fallback, Amanda's carousel/full caption, and Joe's post detail.

## Required fidelity surfaces

- **Media geometry:** Supported photos preserve their intrinsic ratio. The extreme portrait source clamps to 3:4, the landscape and square sources retain their ratios, the no-photo surface uses 3:4, and Amanda's detail carousel keeps the first image's landscape frame.
- **Overlay hierarchy:** Drink and context stay lower-left; the one-decimal Mugshot score and `OUT OF 5` stay lower-right. A bottom contrast gradient keeps both readable on light, dark, and detailed imagery. Address, stamp, remembered-by copy, date, chevron, and the old score badge are absent.
- **Feed rhythm:** Caption immediately follows media, the author row follows the caption, and the social/Open dock remains independent. Two rendered lines end with inline `… more` only when measured overflow exists.
- **Full post hierarchy:** Display name plus `@username · timestamp` precedes the adaptive media, the full caption follows it, and the existing action/evidence sections continue below. Visit Context is absent.
- **Brand fidelity:** The implementation reuses Mugshot's cream, foam, sage, mint, line, espresso, system-serif, and system-sans tokens; it does not introduce a parallel card system.

## Interaction evidence

- Tapped Amanda's media and verified destination accessibility identity `feed.destination.AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA` with Amanda's name, drink, carousel, and full 1,000-scalar caption.
- Returned and tapped Amanda's `Open` action; it resolved to the same Amanda UUID.
- Returned and tapped Joe's media while Joe remained directly below Amanda; it resolved to `feed.destination.BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB` with Joe's name, Peach Cobbler Latte, and the correct photo.
- Expanded Amanda's two-line caption in place; expansion did not navigate.
- Confirmed the feed exposes separate like, comment, save, author, media, and `Open` controls.
- Confirmed `Visit Context` and `sip.detail.visitContext.toggle` are absent from the rendered detail hierarchy.
- Scrolled the consolidated matrix through landscape, square, extreme portrait, Home, Elsewhere, carousel-backed, and no-photo fixtures.

## Comparison history

### Pass 1

- **P2 - The first deterministic fixture looked like a no-photo placeholder, weakening overlay QA.** It used the archival map backdrop even though the presentation mechanics were correct.
  - Fix: moved the real landscape drink photo to Amanda and retained the archival portrait fixture lower in the matrix for boundary-clamp coverage.
- Rebuilt and recaptured the feed and both detail destinations.
- The title/context block stays clear of the score with long drink and context names, and the gradient remains legible across light and dark source regions.
- No actionable P0, P1, or P2 visual or interaction mismatch remains.

## Verification evidence

- Full static verification: passed (11 passed, 0 failed, 1 optional `pglast` check skipped because that dependency is not installed).
- Focused post-presentation and detail projection suite: 18 passed, 0 failed.
- Hermetic PGlite caption migration/contract check: passed; no linked Supabase project was touched.
- Consolidated Simulator routing and visual journey: passed.
- Full source-and-implementation visual comparison: passed.

final result: passed

---

# Feed Location and Social Action Rail Refinement QA

## Audit scope and user goal

- Surface: refreshed feed card and shared full-post detail.
- Goal: add a compact city-level location to cafe posts and make social actions feel like a lightweight Instagram-style action rail instead of a second content section.
- Source captures:
  - `docs/design-qa/feed-social-refresh/01-feed-source.png`
  - `docs/design-qa/feed-social-refresh/02-detail-source.png`
- Rendered implementation:
  - `docs/design-qa/feed-social-refresh/03-feed-implemented.jpg`
  - `docs/design-qa/feed-social-refresh/04-detail-implemented.jpg`
- Combined comparison input: `docs/design-qa/feed-social-refresh/comparison-board.png`
- Viewport: iPhone 17 Pro Simulator; implementation captures are 368 x 800 pixels.
- Density normalization: the 872 x 1800 feed source and 816 x 1754 detail source were aspect-fit into 368 x 800 comparison cells beside native 368 x 800 implementation captures. The source includes device framing while the implementation capture is screen-only; that framing difference was excluded from findings.
- State: Friends feed and friend full-post detail for an Uptown Coffee post with Pittsburgh locality, one like, and the like/comment/recommend/save actions available.

## Audit findings and decisions

- **Strength:** The drink, cafe, and score overlay already establishes the post identity without repeating metadata below the photo.
- **P2 - Cafe identity lacked geographic disambiguation.** The source left an empty visual slot after `Uptown Coffee`, and similarly named cafes would be hard to distinguish.
  - Fix: render `Cafe name · City` using the stored cafe city/city-state value and a compact locality formatter. Keep Home and Elsewhere labels unchanged unless they have an explicit cafe context.
- **P2 - The detail social module competed with the Mugshot evidence.** Four tall labeled actions plus a second like/comment summary consumed a full content section before the score evidence.
  - Fix: treat social controls as an action rail immediately after the caption: 22-point SF Symbols inside 44-point tap targets, counts inline only for like/comment, distribution actions on the left, save at the far right, and no duplicated like/comment summary row.
- **Accessibility:** Visible icons are smaller, but touch targets remain at least 44 x 44 points. Every icon retains a spoken action/count label; active like/save states use both fill and color rather than color alone. Screenshot review cannot prove VoiceOver reading order, so semantic snapshot labels and focused tests remain the implementation evidence.
- **Purpose in the flow:** The rail is the handoff from consuming the memory to acting on it. It should stay between caption and taste evidence, remain visually subordinate to the photo and caption, and never look like another evidence card.

## Required fidelity surfaces

- **Typography:** The overlay keeps the existing serif drink hierarchy and compact system-sans metadata. The new locality shares the cafe line's weight and baseline instead of introducing another row.
- **Spacing and layout rhythm:** The detail action region drops from roughly two labeled rows to one 52-point rail. Caption-to-actions spacing is 12 points; the taste evidence follows without duplicated engagement content.
- **Colors and tokens:** Existing cream, espresso, sage, mint, and line tokens remain unchanged. Sage marks active like/save states without adding Instagram-red branding to Mugshot.
- **Image quality:** Photo crops, adaptive ratios, gradients, and rounded masks are unchanged; no new raster or illustrative assets were required.
- **Copy and content:** The location reads `Uptown Coffee · Pittsburgh`. Visible action labels are removed, while accessibility labels preserve `Like`, `Comment`, `Recommend`, `Save cafe`, and their counts/states.

## Comparison history

### Pass 1

- Added the centered-dot locality and replaced the large labeled dock plus duplicated proof row with the compact action rail.
- Rebuilt the deterministic feed/detail fixture and compared both revised screens in the combined board.
- The locality remains legible without colliding with the score, all four actions fit without compression, save is clearly separated at the trailing edge, and Mugshot evidence moves materially higher on the detail screen.
- No actionable P0, P1, or P2 visual or interaction mismatch remains.

## Verification evidence

- Repository fast verification: 6 passed, 0 failed.
- iOS Simulator build and launch: passed.
- Focused post-presentation and detail tests: 19 passed, 0 failed.
- Runtime accessibility snapshot: distinct 44-point targets for like, comment, recommend, and save; destination identity remained Joe's exact UUID.
- Full source-and-implementation comparison: passed.

final result: passed

---

# Saved cafes redesign — implementation QA

## Comparison setup

- Source visual truth:
  - `docs/design/saved-cafes-redesign-2026-08-04/screens/CF-01-favorites-populated.png`
  - `docs/design/saved-cafes-redesign-2026-08-04/screens/CF-12-map-tab-saved-cafe-detail.png`
  - `docs/design/saved-cafes-redesign-2026-08-04/screens/CD-03-detail-expanded-top.png`
- Final implementation captures:
  - `docs/design/saved-cafes-redesign-2026-08-04/production-evidence/ui-test-final-matrix/B3C67E8A-701D-4E85-B2EC-25E6FC3ABC63.png`
  - `docs/design/saved-cafes-redesign-2026-08-04/production-evidence/ui-test-final-matrix/31B02138-B703-4512-AFD7-297AF8ACBDAF.png`
  - `docs/design/saved-cafes-redesign-2026-08-04/production-evidence/ui-test-final-matrix/E67711BB-1E7E-4634-8DC2-DB98BA406CB0.png`
  - `docs/design/saved-cafes-redesign-2026-08-04/production-evidence/ui-test-final-matrix/394624C2-BB68-436F-B7C8-657B87AFF17F.png`
  - `docs/design/saved-cafes-redesign-2026-08-04/production-evidence/ui-test-final-matrix/7F24C097-6BFB-44AC-A55F-4FAD4AEB5954.png`
- Same-input comparisons:
  - `docs/design/saved-cafes-redesign-2026-08-04/production-evidence/comparison-saved-final-pass.png`
  - `docs/design/saved-cafes-redesign-2026-08-04/production-evidence/comparison-map-final-pass.png`
  - `docs/design/saved-cafes-redesign-2026-08-04/production-evidence/comparison-detail-final-pass.png`
- Viewport: iPhone 17 Pro, iOS 26.3.1, 402 × 874 points.
- Pixels and density: every source and implementation capture is 1206 × 2622 pixels at 3×. No density normalization was required.
- Appearance: forced light.
- Fixture: deterministic local Saved audit data; no authentication, analytics, or remote mutations.
- States: Favorites populated, Saved medium detail, expanded detail, Saved-to-Map compact detail, and accessibility XXXL Saved/detail.

## Final findings

No actionable P0, P1, or P2 visual differences remain.

- Fonts and typography: the regular-size hierarchy retains the serif Saved/cafe identity and SF system UI treatment. Dynamic Type changes the Saved category controls to readable menu rows, makes cafe cards vertical, and makes detail actions full-width rows rather than compressing labels.
- Spacing and layout: the production screen uses the real iPhone 17 Pro safe area, so content begins lower than the bezel-free static board. The hierarchy, 16-point margins, 44-point minimum controls, card structure, native sheet detents, and dock clearance are preserved.
- Colors and tokens: cream, foam, espresso, roast, sage, mint, sand, and divider treatments map to Mugshot tokens. Selected state is differentiated with fill, border, icon, label, and accessibility value.
- Image quality: fixture images use authorized Mugshot assets at native density. Missing imagery uses Mugsy and a branded sand surface; there are no stock photos or fabricated cafe images.
- Copy and content: strings use `cafe` and `cafes`; personal ratings and history are labeled separately from cafe reflection and community data. No unavailable score, distance, hours, or report submission is fabricated.
- Icons and affordances: actions use SF Symbols with explicit labels. Map scope uses the approved layered-source icon; Lists continues to call the existing membership workflow.
- Accessibility: accessibility XXXL was rendered in Simulator. Controls reflow without horizontal compression; category switches become menus; cards and action rows become vertical. VoiceOver labels, values, selected traits, and minimum targets are implemented. Full VoiceOver traversal and Reduce Motion quality remain device-level acceptance checks rather than visual claims.

## Comparison history

### Iteration 1 — blocked

- [P1] The compact Map cafe sheet hid the approved search/scope/List control.
  - Fix: kept the floating Map control visible while the native compact detail sheet is presented.
- [P1] The deterministic signed-out capture omitted the Cafes/Lists boundary visible in the approved Saved board.
  - Fix: the DEBUG-only audit route now renders that boundary without authenticating or loading Lists; production Lists behavior is unchanged.
- [P2] Favorites selection and Your Mugshot used neutral white surfaces rather than the approved mint hierarchy.
  - Fix: applied the selected mint wash and the attributed Your Mugshot mint surface with white stat cards.

### Iteration 2 — blocked

- [P1] The first accessibility harness did not actually apply accessibility XXXL.
  - Fix: added a DEBUG/UI-test-only Dynamic Type override and proved the large-size layout in Simulator.
- [P1] Direct semantic scaling compressed category controls and regular library controls at accessibility XXXL.
  - Fix: replaced segmented categories with full-width menus, stacked sort/count/density controls, shortened the search placeholder, made cafe cards vertical, and made actions full-width labeled rows.

### Final iteration — passed

- Recompiled after the accessibility changes.
- Ran the three-test Saved Simulator matrix: Saved search/categories/Undo persistence, Saved-detail-Map handoff, and accessibility XXXL Saved/detail.
- Re-captured the implementation at the same viewport and rebuilt all same-input comparison boards.
- No actionable P0/P1/P2 mismatch remained.

## Focused-region evidence

Focused review was performed directly on the full-resolution Saved card action area, compact Map sheet identity/CTA area, expanded identity/action/Your Mugshot region, and accessibility category/card/action regions. Separate crops were unnecessary because each source and implementation pair shares the same 1206 × 2622 dimensions and the relevant controls remain legible in the full-resolution side-by-side boards.

## Follow-up polish

- [P3] The production Map sheet uses a native `Cafe details` title and Done control rather than the mockup's custom close button. This is an intentional navigation-clarity tradeoff.
- [P3] The synthetic fixture shows full street addresses on Saved cards because the current cafe model has no trustworthy neighborhood projection. The UI avoids inventing neighborhood or distance values.

## Final result

final result: passed
