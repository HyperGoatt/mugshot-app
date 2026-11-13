---
document_type: historical
status: complete
---

# Mugshot premium audit and polish — November 13, 2026

Current implementation: [Product status](../../CURRENT_PRODUCT_STATUS.md).

## Scope and evidence contract

Audit the current `0c08dcd` candidate before changing product code. Exercise
implemented production screens through normal navigation and existing isolated
DEBUG fixtures; distinguish fixture routes from connected end-to-end journeys.
Every inventoried flow gets a runtime outcome or an explicit blocker. Source
inspection and old passing tests are not new runtime evidence.

Work branch: `codex/premium-polish-audit`, based on
`codex/home-recipe-to-sip` (PR #111). Earlier dependency acceptance holds remain.
Unrelated `docs/design/weekly-pour-2026-10-31/` files are preserved and excluded.

Dedicated Simulator: Mugshot Premium Audit 2026-11-13, iPhone 17 Pro, iOS 27.
Backend build target: `https://premium-audit.invalid`; synthetic public key;
production analytics token empty. No real identity or production mutation.
Physical-device and TestFlight acceptance are separate and outside this sprint.

Documentation impact: product behavior, presentation/accessibility and client privacy/
account ownership; update Changelog, current product status, sprint, design system,
discovery specification and notification guide.
No intended schema, production configuration, signing, or release change.

## Tracked execution plan

1. **Complete — Audit:** inventory routes, inspect canonical components/artwork,
   exercise normal navigation and fixture edge states, capture baseline evidence.
2. **Complete — Prioritize:** record reproduction, impact, priority, proposed fix,
   and acceptance for each confirmed finding; present the coherent sprint batch.
3. **Complete — Implement:** behavior repairs first using RED/fix/GREEN; then
   shared visual consistency and purposeful, interruptible motion.
4. **Complete — Accept:** revisit every changed flow and relevant failure state;
   inspect smaller screens, largest text, accessibility semantics and Reduce Motion.
5. **Complete — Delivery preparation:** update living documentation, run required checks,
   review the full scoped diff, commit/push/PR, and honor dependency/review holds.

## Coverage

See the **42-flow [coverage matrix](FLOW_COVERAGE.md)**. Each row distinguishes observed interaction from fixture-only coverage, service blockers and remaining gaps.

## Baseline notes (recorded before product changes)

- Actual signed Debug app built with inert backend and empty analytics; signature
  verification passed. XcodeBuildMCP's combined call timed out at 300 seconds,
  but build/install/launch completed; screenshot and UI snapshot confirmed launch.
- First-launch preview navigation observed through account choice. Its final
  choice intentionally remains in the preview; normal launch separately opened
  account entry. There are eight implemented steps, using artwork numbered 1–6, 8–9; the baked-in nine-step counters are incorrect.
- Normal account entry: create/sign-in toggle, email editing, disabled incomplete
  submit, password reset unavailable-network feedback, guest exploration observed.
  Reset failure says “We couldn’t update your account. Please try again.”:
  **P2 candidate** for action-specific, actionable recovery copy (no credentials
  or real service used). Email survives failure.
- Guest introduction dismisses; Feed opens dismissible auth prompt; Saved and
  Home library remain available. Denied location shows truthful recovery and
  Settings action. Empty Home library creates the local tea starter and opens
  real guided making without network access.
- Baseline UI batch runs on a second disposable Simulator. MCP response timed
  out at 300 seconds while xcodebuild continued; its log and xcresult remain the
  authoritative evidence. Early draft-control failures are harness configuration:
  two preview hosts require the isolated `co.mugshot.app.homeqa` identity, whereas
  this candidate uses `co.mugshot.app` on a fresh Simulator. They are not product
  failures; rerun with the required fixture identity or exercise normal routes.

## Prioritized sprint plan (baseline locked before product edits)

| ID | Priority / affected flow | Reproduction and user impact | Improvement and acceptance |
| --- | --- | --- | --- |
| PP01 | P1 Account data health | Open Settings → Account and Sign In with no pending local work, then fail Export offline. Green “Cloud journal is up to date” remains although no server check ran. | Describe local queue evidence only; never imply verified cloud backup from empty queues. Preserve unreadable-data warnings. Unit + offline runtime checks. |
| PP02 | P1 Discovery recovery | Open Friends and Discoverability with unavailable service. False toggles remain without known preferences or Retry. Failed save optimistically replaces confirmed values before a second failing fetch. | Hide unknown controls, actionable retry, retain confirmed values, reject duplicate/stale/account-switched responses. Focused store tests and runtime unavailable state. |
| PP03 | P2 Reflection recovery | Open Reflections and Recaps with unavailable service. Empty sections, disabled Save and error without retry. | Clear recovery section and retry; keep unsaved edits on save failure; guard owner/lifecycle. Runtime failure/retry and local boundary tests. |
| PP04 | P2 Onboarding accessibility and accuracy | Continue through first launch: eight screens still show baked artwork counters “of 9”; largest text cannot resize raster copy. | Native accurate progress; accessible scrollable native text/actions at accessibility sizes or VoiceOver, using existing Mugsy. Preserve standard artwork and privacy wording; eight-step + skip + largest-text checks. |
| PP05 | P2 Map accessibility | Existing runtime accessibility audit flags a 10×10 decorative rating dot. | One static semantic legend with readable rating ranges; adaptive layout and no decorative hit targets. Rerun audit and inspect largest text. |
| PP06 | P2 Support finish | Open Support: cream content island on white background, fixed-size copy; Copy Email Address has no local acknowledgement. | Full cream scrollable layout, semantic type, clear copied state, immediate finite feedback that respects Reduce Motion. Runtime copy/large text, before/after video. |
| PP07 | P2 Authentication copy | Password reset with unavailable network says “couldn’t update your account.” Email remains intact. | Action-specific reset guidance without leaking account existence. Focused mapping test and real inert-network check. |
| QA01 | Verification maintenance | Baseline suites contain outdated page count/copy/entry points and scroll the underlying Saved screen under sheets on compact iPhone. | Correct selectors and reveal helpers to current visible flows; preserve assertions about resulting data, cancellation, and private scope. Record every initial failure and rerun outcome. |

No new feature, hosted contract, artwork identity, or release change is planned.
The onboarding accessibility presentation is a narrow alternate layout for readable
native content; approved artwork remains the standard-size presentation. Existing
Mugsy motion is already extensive, so added feedback will be brief and state-driven.

### Baseline automated evidence

- Main batch: 54 checks; 38 passed, 15 failed, 1 skipped. Twelve failures were the
  intentional Home fixture bundle-identity guard; all 12 passed after rebuilding
  the isolated `co.mugshot.app.homeqa` target with empty fixture entitlements.
  Remaining failures: obsolete onboarding count/tour copy and Map accessibility.
- Compact iPhone SE (3rd generation), iOS 18.6: 20 checks; 7 passed, 9 failed,
  4 native-share checks skipped because their explicit source fixture was absent.
  Failure diagnosis and corrected reruns are tracked in the final verification.
- Production authentication, collaborative writes, hosted profile updates, live
  providers, APNs, widget delivery, and spoken VoiceOver are not established by
  these isolated routes. They remain explicit coverage limits.


## Implemented result and acceptance

- **PP01:** Empty local queues now say “No pending uploads on this device.” The
  screen explicitly says this does not verify a cloud backup. Regression test and
  actual unavailable Export with preserved status passed.
- **PP02:** Unknown discovery values are hidden; loading and retry are visible.
  Failed writes show last confirmed values and require a reload because a lost
  acknowledgement may follow a successful server commit. Eight focused logic
  tests include account switch, dismissal, cancellation, duplicate rejection and
  no signed-out transport. The native load → retry → failed acknowledgement →
  reconciliation journey passed on compact iPhone.
- **PP03:** Reflection errors appear before the form; unavailable values do not
  leave empty sections. Retry restores the form; failed Save keeps edits, and
  retry succeeds. Generation/account checks prevent late screen updates and
  late permission prompts. Native fixture recovery passed.
- **PP04:** Eight actual first-launch steps now have accurate native counters.
  Largest text and VoiceOver use native scrollable content with the canonical
  Mugsy onboarding pose. Standard artwork, privacy wording and account actions
  remain. Eight-step, skip and largest-text journeys passed. The DEBUG signed-in
  tour now dismisses its introduction, completes all five pages and hands off to
  the first sip; its controls no longer inherit a giant combined accessibility label.
- **PP05:** The rating legend is one static accessible description; decorative
  dots are no longer tiny targets. Type scales and the full key reflows. A full-screen check then caught the enlarged key covering the recenter control; accessibility sizes now use an expandable key with a readable sheet. The focused
  component accessibility audit passes; a broad Map audit still reports an
  unassociated text-clipping warning, retained as an open diagnostic.
- **PP06:** Support fills the cream canvas, uses semantic type and a quiet envelope
  illustration, scrolls at largest text, and acknowledges copying immediately.
  Feedback is finite, can be repeated, and disables its animation for Reduce Motion.
  UI checks and real motion capture passed; physical haptics are not inferred.
- **PP07:** Password-reset errors have action-specific safe wording. The mapper
  regression confirms no internal error details are exposed; the real inert-network reset shows the new message and preserves the email.
- **QA01:** Stale copy/count expectations and offscreen navigation assumptions
  were repaired. Tests now confirm entered text before asserting later retention.
  Data-retention and privacy checks remain; obsolete copy and navigation assertions now describe the implemented journey.

The sprint uses existing serif/semantic typography, cream/sage/espresso colors,
shared buttons and canonical Mugsy. It adds no artwork identity, feature redesign,
backend contract or recurring decorative animation.

## Evidence gallery

All screenshots and recordings are real Simulator captures. Fixture photos,
people, cafes, recipes and stats are fictional. Images are resized for review;
raw captures and result bundles remain local.

| Flow | Before | After |
| --- | --- | --- |
| Support composition and copy feedback | [Screenshot](before/settings-support.png), [recording](before/support-copy.mp4) | [Screenshot](after/support-copy.png), [recording](after/support-copy.mp4) |
| Onboarding at largest text | [Raster content](before/onboarding-largest.png) | [Native content](after/onboarding-largest.png) |
| Standard onboarding progress | [Original artwork](before/onboarding-3.jpg) | [Accurate eight-step progress](after/onboarding-standard.png) |
| Data health with unavailable export | [Baseline](before/settings-account.png) | [Local evidence only](after/account-health.png) |
| Discovery recovery | [Baseline](before/settings-friend-discovery.png) | [Load failure](after/discovery-load-failure.png), [uncertain save](after/discovery-save-uncertain.png) |
| Reflection recovery | [Baseline](before/settings-recaps.png) | [Edits retained after failed Save](after/reflection-save-retry.png) |
| Map key | [Baseline Map](before/map-location-denied.png) | [Semantic key](after/map-legend.png), [enlarged sheet](after/map-legend-largest.png) |
| Map controls at largest text | [Intermediate overlap caught during verification](before/map-enlarged-key-overlap.png) | [Expandable key keeps recenter clear](after/map-largest-text-controls.png) |
| Password reset failure | [Generic account error](before/auth-error-keyboard.jpg) | [Specific reset guidance](after/password-reset.png) |

Additional after evidence: [compact copy/version actions](after/compact-copy-version.png),
[composed-drink private receipt](after/compact-private-receipt.png). The full before
folder preserves screen inventory evidence rather than claiming every screen changed.

## Review and safety

SwiftUI review covered task identity, cancellation, presentation lifetime, main-actor
state, keyboard focus, scroll ownership, Dynamic Type and Reduce Motion. Security
review covered authenticated account checks before and after service calls, stale
response invalidation, duplicate writes, unknown preference values and safe errors.
There are no schema/RLS/production configuration changes. DEBUG recovery transports
require the explicit UI-testing route and use no real authenticated identity.

## Remaining acceptance boundaries

- Real authentication providers, hosted social/list/profile writes, live place/AI
  services, export/deletion and canonical public links need a disposable authenticated
  environment. The linked production project was not mutated.
- Spoken VoiceOver navigation and physical haptic/camera/notification behavior are
  not established by semantic snapshots or XCTest accessibility audits.
- The broad Map text-clipping diagnostic has no associated element. The repaired
  legend passes its focused audit; the broader warning is not silently suppressed.
- Native share tests establish source handoff and local persistence on the stated
  OS versions, not external message delivery or every OS/host combination.
- Existing dependency acceptance holds, including the prior build-17 iPhone gate,
  remain open. No physical device install, archive, export, upload, marketing-version
  change or TestFlight assignment occurred.

## Final verification and publishing

All seven implementation findings meet their scoped local/Simulator acceptance.
The broad Map diagnostic and service/hardware gaps above remain explicit. This is
not a claim that every hosted or physical interaction passed.

| Evidence bundle | Result | Interpretation |
| --- | --- | --- |
| `premium-baseline` | 38 pass / 15 fail / 1 skip | Full initial main batch; failures retained in baseline notes. |
| `premium-homeqa-baseline` | 12 / 12 pass | Isolated Home draft/editor fixture identity; no production App Group inference. |
| `premium-compact-baseline` | 7 pass / 9 fail / 4 skip | Initial SE run, stale copy/scroll/input assumptions and absent native fixture. |
| `premium-red` | 4 fail | Two valid regressions (cloud claim/native large onboarding); two incorrect test menu labels, explicitly not product RED. Support lack of acknowledgement also recorded manually. |
| `premium-green1` | 11 / 11 pass | Eight logic checks + Support, unknown discovery and largest-text onboarding. |
| `premium-onboarding-map` | 2 pass / 2 fail | Eight-page and skip passed; exposed DEBUG tour labels and broad Map diagnostic. |
| `premium-green2` | 3 pass / 1 fail | Tour, Support XXXL and signed-out reflections passed; broad Map warning remains. |
| `premium-green3` | 1 pass / 1 fail | Focused Map audit passed; synthetic switch tap missed the thumb. |
| `premium-compact-rerun` | 7 pass / 4 fail | Bag naming/fallback and several Home journeys passed; scroll/input fixes followed. |
| `premium-green4` | 4 pass / 1 fail | Discovery reconciliation, empty shelf/unknown date, composed drink/private receipt, copy/version passed. Largest-text builder input needed keyboard readiness. |
| `premium-green5` | 9 / 9 pass | Eight logic checks after cancellation guard + reflection failed-load/save retry. |
| `premium-green6` | 3 / 3 pass | SE largest-text capture/build/save, reflection retained-edit retry after binding guard, enlarged key audit. |
| `premium-maprecents` / `premium-green7` | Map recent pass; composer initially incomplete input, then 1 / 1 pass | Confirming keyboard readiness before typing establishes name/photo retention independently from text entry. |
| `premium-green8` | 2 / 2 pass | Final expandable key opens/closes, passes AX audit, and leaves recenter reachable on the full compact Map. |
| `premium-library-final` | 2 / 2 pass | Final empty shelf/unknown roast date and archive/restore journeys after preserving the established sheet reveal helper. |
| `premium-native` | 1 pass / 3 fail | Safari source handoff on iOS 18.6; photo fixture/host navigation initially failed. |
| `premium-native-ios27` | 1 pass / 3 fail | Journal two-photo immediate/relaunch passed; cold Photos OCR/host selectors needed correction. |
| `premium-native3` | 2 / 2 pass | Native Photos recipe-source + Pocket Sip handoff; guest two-photo persistence across relaunch. |

These are overlapping targeted runs, not additive unique coverage totals.
All **17 newly added logic/UI tests** have a passing focused run. Existing passing
behavior was reused; no full Release or TestFlight build was performed. The aborted
`premium-native2` attempt targeted an unbooted media fixture and is not acceptance.
XcodeBuildMCP timeout/recording issues were handled through local xcodebuild logs,
xcresult bundles and simctl recording; no timeout was called a pass.

Required checks: Debug app/test builds passed as part of focused runs;
`./scripts/verify-no-simulator.sh fast` passed 7/7; `./scripts/check-documentation.sh`
and `git diff --check` passed (repeated on the final staged scope before publishing).
Raw result bundles are `/tmp/mugshot-premium-*.xcresult`; logs, exported attachments
and summaries are `.codex/premium-polish-2026-11-13/` (local-only, excluded from Git).

Manual evidence also includes normal guest brewing → background/terminate → elapsed
timer resume → private receipt, unavailable export, password reset with retained
email, widget placement/rendering/open-app, and all settings destinations. The first
widget tap was intercepted by the isolated Home QA bundle's duplicate URL scheme;
that disposable app was removed, the widget was added again, and its open-app route
then reached the intended `co.mugshot.app` Map. No personal Simulator data was removed.

Publication: feature branch `codex/premium-polish-audit`; stacked draft PR against
`codex/home-recipe-to-sip`. Parent PR #111 remains an open draft with unresolved
acceptance/dependency holds, so this sprint does not bypass them with a default-branch
merge. The final chat carries the commit, push and PR URL receipt.
