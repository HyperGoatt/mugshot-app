---
document_type: historical
status: installed-physical-navigation-verified
---

# Home library and simpler Log a Sip — 2026-11-04

**Follow-up:** [Home source capture and full-flow QA](HOME_SOURCE_CAPTURE_2026-11-04.md)
adds automatic factual source capture and the isolated physical guidance/rating/
review journey. This report retains the original navigation-only chronology.

Current sources: [Home implementation](../HOME_RECIPES_IMPLEMENTATION.md) and
[optional Luna assistance](../AI_ASSISTANCE.md). This work changes product flow,
account-owned local defaults and AI permission/disclosure. It does not introduce
a backend schema or promote TestFlight or held parent PRs.

**Current acceptance:** the owner subsequently unlocked the phone. The installed
candidate launches and renders Journal with the existing account. Physical taps
through Device Hub verify Saved → Home library, all four library sections and
standalone manual-bag entry/cancel. See the physical-navigation addendum below;
the earlier locked-launch observation is retained as initial delivery history.

## Current-flow audit and priorities

Captured and inspected the actual current Simulator application using synthetic
guest data, a fixture backend and disabled analytics. These are new captures,
not old design boards. Native typography and cream, sage, mint and espresso
colors remain the visual target.

1. [Cafe capture](home-library-2026-11-04/before/01-cafe.jpg): clear photo/name
   pattern, context stays visible. Preserve this foundation.
2. [Elsewhere capture](home-library-2026-11-04/before/02-elsewhere.jpg): same
   pattern with only the relevant setting field. Good parity to preserve.
3. [Home entry](home-library-2026-11-04/before/03-home-entry.jpg): a horizontal
   starter strip hides tea/matcha and the tall bottom action area competes with
   the recipe choices. Simplify the primary action and expose all starter types.
4. [Selected method](home-library-2026-11-04/before/04-home-selected.jpg): useful
   setup summary, but Start making / Skip guidance / Quick log compete. Make
   logging the clear short route, with explicit optional guidance.
5. [Beans inside setup](home-library-2026-11-04/before/05-beans.jpg): functional
   add/scan controls are buried in an existing Home draft. Move management to a
   persistent Home library, and keep selection in the sip flow.

Screenshot evidence establishes visual hierarchy and reachable controls. It
cannot establish spoken VoiceOver quality, hardware camera fidelity, account
isolation, persistence, request cancellation or API behavior; those require the
separate checks below.

## Intended behavior

- Saved has a visible Home library entry; Journal and Home setup can open it too.
  Recipes, beans, gear and preferences can be managed without creating a sip.
- Existing recipe types, source attribution, link-only ideas, linked ingredients,
  method-aware preparation, timers and optional guidance remain available.
- Home offers a short logging route and explicit making guidance. Both finish
  through the existing shared sip reflection and review; targets remain planned
  until actuals are explicitly recorded.
- Luna reads a selected bag photo directly into editable fields after one-time,
  account-scoped enablement. It cannot overwrite typing made while the request
  runs. Failure uses on-device scanning/manual entry and never blocks saving.
- Other contextual Luna tools reuse the same remembered permission and avoid
  repeated consent checkboxes. Their source details remain inspectable, private
  notes remain separately controlled, and suggestions never publish or change
  ratings automatically.
- First use retains a short, explicit OpenAI permission control; it can be turned
  off in preferences. Apple App Review 5.1.2(i), verified November 4, requires
  disclosure and explicit permission before sharing personal data with
  third-party AI. This is not a claim that App Review has approved this design.
  [Primary requirement](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing).

## ECC checkpoints

- Runtime RED `c240b52`: two journeys fail at the absent standalone library and
  the primary Home action entering guidance rather than the short capture path.
  `/tmp/mugshot-home-library-red.xcresult`.
- `a12c66e`: intentional missing-API RED for account permission, compatible shelf
  preferences and protected autofill boundaries. `/tmp/mugshot-home-model-red.log`.
- `c88d36e`: the first sync implementation failed the stale-response regression:
  a newer edit was overwritten. Full-value acknowledgement checks, protection
  against edits during fetch and fractional-second cache dates correct it.
  The cache decoder continues accepting the previous whole-second format.
- The first broad batch had 52 passing cases and two failures. The sync failure
  above was real; the quick-flow test expected the old design's heading instead
  of the actual shared **How was the sip?** heading. That test lookup was corrected
  without changing the shared rating screen.

## Final verification

- **51 distinct native unit tests pass:** 17 Home library/permission/autofill/sync
  boundaries, 15 existing Home workbench boundaries and 19 assistance boundaries.
  `/tmp/mugshot-home-library-coverage.xcresult`.
- **16 distinct UI journeys pass** across the actual standalone library, recipe
  discovery-to-save, short Home reflection/review, automatic bag filling,
  on-device OCR fallback, shared helper permission/failure/review, Journal/bean
  regressions and existing guided latte/private-save/Cafe handoff.
- Passing runs are reused by test identifier, not summed as repeated executions:
  `/tmp/mugshot-home-library-green.xcresult`,
  `/tmp/mugshot-home-library-acceptance.xcresult` and
  `/tmp/mugshot-home-library-guidance.xcresult`. The later all-green runs supersede
  earlier failed versions of the same tests.
- The final accessibility batch passes all five Home-library/Journal UI cases.
  The final boundary batch passes all 17 new domain tests plus two Journal/bean
  UI cases, including the extended test that loads a legacy cache file through
  the store's custom decoder. An earlier exact-method selector selected zero
  tests and is excluded from evidence. [Sanitized run/test ledger](home-library-2026-11-04/verification.json).
- Measured line coverage: HomeLibraryPreferences **82.9%** (29/35), permission
  store **100%** (19/19), synchronizer **94.8%** (163/172). Aggregate **93.4%**
  (211/226) across those three new files. Existing HomeLibraryStore is **77.7%**
  (282/363). These are focused file figures, not app-wide coverage.
- `./scripts/verify-no-simulator.sh fast`: **7/7 pass**. Native Simulator and
  signed physical Debug compilation pass. Documentation/diff checks pass.
- SwiftUI state/task and security review covers fixed originating scope, edits
  during requests, permission revocation, account-switch/erasure cancellation,
  serialized retry, safe snapshots and explicit persistence. Actual API-key
  exclusion is checked against changed files and the installed package.
- This native change makes no backend deployment. The existing provider/schema
  acceptance remains relevant; synthetic UI transports never call OpenAI or
  mutate production data.

## Final visual inspection

[Saved entry](home-library-2026-11-04/after/01-saved.jpg),
[Home library](home-library-2026-11-04/after/02-library.jpg),
[Home entry](home-library-2026-11-04/after/03-home-entry.jpg) and
[selected setup](home-library-2026-11-04/after/04-home-selected.jpg) show actual
rendered native screens, inspected at capture time. Library entry is visible,
all four library categories fit at normal text, and the short log/guidance actions
remain separate. The Home captures retain an unfinished fictional preparation
from the RED journey, demonstrating the existing Resume route.

The largest-text pass exposed a modal environment inheritance issue in the
DEBUG size override. Its normal-sized screenshot was rejected as large-text
proof. The library and nested presentations now receive the originating dynamic
text environment explicitly. The [accepted largest-text capture](home-library-2026-11-04/after/05-library-accessibility.jpg)
shows enlarged, wrapping text and horizontally scrollable category controls.
Content remains vertically scrollable. Spoken VoiceOver acceptance is pending.

The final state review also fixes Journal's library presentation to capture the
originating owner when tapped, matching Saved and Home setup. Account changes
dismiss that presentation instead of rebinding its in-progress fields.

## Initial delivery state

The owner-authorized development app **Mugshot Luna QA 0.5.3 (8)** is installed
on iPhone 16 Pro / iOS 27.0.1 as the same `co.mugshot.app.dev`. Strict/deep signing,
unchanged entitlements, disabled analytics and actual OpenAI-key exclusion pass.
All **40** immediately pre-install Application Support files match byte-for-byte
before launch. Raw backups and account screenshots remain private under `/tmp`.
The phone is locked, so launch/physical interaction acceptance remains pending;
an unlock request is pending. The final accessibility and owner-presentation
corrections are included in the installed package. [Sanitized delivery receipt](home-library-2026-11-04/phone-receipt.json).

This stays on `codex/home-library-flow`, stacked on draft #108 and its unresolved
parent acceptance holds. No merge, migration, server configuration or TestFlight
action occurred.

## Physical-navigation addendum after owner unlock

- The same signed package launches on the owner's iPhone 16 Pro / iOS 27.0.1.
  A warm `mugshot://journal` route renders the existing authenticated Journal,
  entries and draft, and the app stays running during the navigation checks.
- Device Hub's **View Screen** exposes working physical touch control through
  CUA even though its accessibility tree does not expose the iPhone's app rows.
  Coordinate actions were based on fresh live screenshots, with the real iPhone
  explicitly selected; this evidence is separate from the Simulator captures.
- Physical taps open Saved and its Home library. Recipes show existing saved
  recipes; Beans shows the existing bag; Gear shows existing tools; Preferences
  shows defaults and the unenabled Luna control. Opening Add manually then Cancel
  returns to the same bag shelf without creating a sip or saving a new bag.
- No AI permission, defaults, archive state or user content was changed. No real
  photo was sent to OpenAI. The phone is left on Home library → Beans.
- Launch, Journal rendering and the named library navigation are physically
  verified. Real camera/photo fidelity, scan/save, guided preparation through
  rating/review, spoken VoiceOver and owner satisfaction remain human QA.
- Raw device screenshots and process/launch receipts stay private under `/tmp`.
  The sanitized [phone receipt](home-library-2026-11-04/phone-receipt.json) records
  the checked scope. The 40-file byte comparison remains the pre-launch install
  preservation result, not a claim that runtime caches never change.

## Human QA

1. Saved → Home library → Beans: add, scan, edit and archive/restore a bag without
   opening Log a Sip. In Preferences, enable Luna once. Load a real bag photo:
   editable fields should fill without an Improve or acceptance step. Correct
   any printed detail and Save. Cancel should not create a bag.
2. Add gear and choose go-to beans/gear and a favorite method. A fresh coffee setup
   uses those choices; tea/matcha must not inherit the coffee bag. Existing recipe
   snapshots stay unchanged. Offline edits remain available; retry sync later.
3. Find a recipe → save a link/caption/screenshot, retain its creator/source,
   inspect extracted ingredients/steps, and edit before Save. Link-only ideas
   can be saved without AI or copying recipe instructions.
4. Add → Home: Log this sip reaches the shared rating/review. Make with guidance
   retains instructions/timers and explicit measured/As planned actuals before
   joining that same finish. Private saves stay private; sharing requires the
   ordinary explicit audience and publish action.
5. Turn Luna off, try poor/offline scans and switch accounts. Manual entry/save
   must remain usable, and another account must not inherit permission, shelf
   contents, defaults or late results. Physical photo fidelity, spoken VoiceOver
   and owner satisfaction remain human acceptance checks.
