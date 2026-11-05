---
document_type: historical
status: simulator-and-physical-verified
---

# Recipe capture and drink composition — November 4, 2026

Current implementation and acceptance: [Home recipes](../../HOME_RECIPES_IMPLEMENTATION.md).
**November 5 update:** the same candidate is installed and passes the 27 selected
hardware checks plus the owner read-only component check. See the
[physical ledger](../../audits/HOME_RECIPE_COMPOSER_PHONE_2026-11-05.md) and
[phone captures](gallery.html#phone). The November 4 blocked-delivery checkpoint
below retains its original chronology.
[Open the native screen gallery](gallery.html).
This native review package changes product presentation and draft composition,
reusing existing account ownership, immutable recipe links, persistence and
publication contracts. No Supabase or model/quota change is planned.

## Sources and observed problem

- [Original interview, Round 4](../../MUGSHOT_V3_PRODUCT_INTERVIEW.md#round-4-of-8-cafe-home-and-everywhere-else):
  a syrup can be a reusable recipe, casual depth stays optional, gear is entered
  once, versions stay behind the scenes, and Home finishes with the common sip
  reflection.
- [Accepted September Home V4 interview/read-back](../../product-research/home-sip-v4/README.md):
  save syrup and foam separately, combine with a preferred base and milk, keep
  usage amounts in the parent drink, preserve the parent when inspecting a part,
  and never turn the parts into automatic journal entries.
- Owner-requested read-only phone inspection: the blueberry syrup has five
  ingredients, ten steps, source and creator credit, but remains a generic
  Preparation / Other. The Add screen exposes a plain multi-field Form. Linking
  a recipe requires the full editor and an implementation-oriented version picker.
  The private phone backup stays outside the repository.

## Native direction

1. A source-first capture page uses the Mugshot cream, espresso and accessible
   sage palette, large serif identity, readable source input and compact media
   choices. Import feeds an editable recipe preview; credit and advanced fields
   are secondary. A simple Brew / Component / Drink choice describes its use.
2. A syrup or brew offers **Use in a drink**. It opens an editable mix with a
   coffee/tea/matcha base, milk and the exact saved component. Amounts are optional
   and belong to this drink. The syrup batch and source never change.
3. **Build a drink** is directly available from the recipe book. Add saved parts
   by name, inspect one and return, or add a plain ingredient. Version IDs remain
   internal; no repeated template wizard or new inventory setup is required.
4. Save a reusable recipe explicitly, then use the existing optional guidance →
   capture → shared reflection → review journey. AI is optional throughout.

The current task authorizes implementing this extension of the accepted Home V4
direction. Native captures and focused fixture journeys will make the result
reviewable before delivery to the owner app. Existing owner recipes are not
reclassified, edited or used for synthetic saves.

## ECC checkpoints

- `dad56de`: intended missing-API RED for recipe use/composition.
- `71d967b`: 9/9 native composition tests pass.
- `e436e03`: native UI RED at the absent source-first capture heading.
- The imported-drink boundary then runs as a full 10-case native suite: 9 pass,
  one fails because replacing a guessed first-part base deletes the leading milk
  ingredient. Base replacement must identify the base, preserving unrelated parts.
- The first UI iteration passes 17/18 checks; its remaining preview assertion
  expects unnumbered text while the existing detail renders a numbered step.
  Screenshot review also exposes a real 15 → 1 input issue. The corrected
  assertion and focused RED run confirm truncated syrup entry and a needless
  version when reselecting an unchanged base. A separate 150.5 entry case passes.
- `fdf6f25`: RED checkpoint for those two confirmed failures. The fix retains
  focused numeric text while editing and leaves an unchanged base intact.
  `/tmp/mugshot-recipe-composer-green2.xcresult` passes 16/16: 12 native cases
  and 4 UI cases, including the complete component → latte → linked preview →
  guidance → shared review journey. Broader delivery checks follow below.
- The broader 75-case run passes 74, but the lower syrup field again retains 1
  after typing 15. The earlier focused pass is not sufficient input acceptance.
  The next fix commits numeric text synchronously and avoids reformatting during
  editing; repeated journey checks are required for this timing-dependent case.
- Repeated runs still reproduce the lower-field truncation before keyboard Done.
  A diagnostic trace shows repeated `1` updates during live editing. Source
  inspection also finds that the existing UI reset does not reset Home recipes,
  leaving earlier synthetic recipes/drafts in the fixture. Debug UI tests now use
  a dedicated resettable Home workspace, separate from ordinary owner storage.
- The numeric control now retains its native editing buffer while parent drafts
  autosave, formats outside editing, and owns its keyboard Done action. Parent
  focus bookkeeping does not force the native control to resign during an update.
  Save moves out of the active editing area. The final compact layout places the
  name, base and additions together; large accessibility text stacks the rows.
- The compact-layout batch passes 20/22. Quantities, linked inspection and the
  duplicate-selection value checks pass, but tapping the empty center of a
  plain-style picker row does not select it. Gear also saves a truncated nickname.
  A focused 17-case RED records those two failures plus two cases where reselecting
  the same base overwrites adjusted drink targets. Full-row hit shapes, explicit
  picker dismissal, identity-field editing cleanup and unchanged-base handling
  address those boundaries.
- The next batch passes 23/24; all ten UI journeys pass. The remaining saved-base
  unit case lacks an explicit resolver and exposes replacement of an already
  linked reference. Recognizing that exact reference fixes the no-op boundary.
- `/tmp/mugshot-recipe-composer-final-green.xcresult` passes all 20 selected cases
  twice: **40 executions, zero failures/skips**. This includes 14 native cases,
  five composer journeys and standalone bag/gear management. Four unchanged Home
  quick-log/discovery/caption journeys also passed in the preceding batch.
- Visual review catches a nested sheet that drops the accessibility environment,
  then a cramped largest-text base row. The environment is carried explicitly;
  the base/actions stack and the footer uses concise labels at accessibility sizes.
- Reviewing method guidance also finds an existing fallback that treats any
  measured drink as espresso and repeats an unlinked drink's assembly steps.
  Three intended missing-API RED cases define correct matcha guidance, linked-base
  instructions with parent target overrides, and the generic legacy fallback.
  The guide now respects explicit methods and includes assembly once. Named
  Simulator checks verify the actual guidance label and method-tip surface.

## Scope and review

- Documentation impact: product behavior, local draft/data ownership,
  development packaging, privacy/analytics and verification. Supabase contracts,
  deployed functions, Luna model/quota, marketing version and TestFlight do not change.
- SwiftUI review: the builder owns one editable draft; exact saved-version links
  retain their identity; delayed autosaves cancel and check the originating
  account; source inspection and picker dismissal preserve the parent. Opening
  and closing an untouched builder does not intentionally create a draft.
- Security review: existing reference, cycle, attribution and numeric validation
  still govern explicit Save. Account changes invalidate presentations and
  persistence. No source instructions are recursively copied or shared by adding
  a component. No private owner recipe, caption, source URL, photo or phone backup
  is included in this package.
- Runtime fixtures use an invalid backend and disabled analytics. Mutable phone
  journeys use the separate signed app with an isolated keychain and no owner app
  groups, registered URL schemes or app extensions. Hosted XCTest bundles are
  test instrumentation, not owner-facing extensions.
- These changes do not improve or guarantee access to every social caption/video.
  Source extraction, screenshots, video limits and fallback behavior retain the
  [prior source-capture contract](../../audits/HOME_SOURCE_CAPTURE_2026-11-04.md).
  VoiceOver speech, the broader device/appearance matrix and real-owner media
  fidelity remain separate acceptance checks.

## Behavior guarantees

| Guarantee | Focused evidence |
| --- | --- |
| Older generic syrups are discoverable without rewriting them | `HomeRecipeCompositionTests.legacySyrupIsDiscoverableAsAComponentWithoutRewritingIt` |
| A drink pins the exact saved component and keeps its own optional usage amount | Composition reference, persistence, duplicate and immutable-history cases |
| Replacing a base retains unrelated ingredients; choosing the same base retains parent adjustments | Imported-first-ingredient and unchanged/adjusted-base cases |
| Failed or cross-account saves preserve the original records and editable content | Composition failure/ownership cases; existing workspace validation |
| Preset matcha keeps matcha guidance; linked-base steps and assembly occur once | Guidance domain cases and the actual matcha Make-screen assertion |
| Capture → syrup → drink → source preview → saved-part picker → guidance → shared review is usable without AI | `HomeRecipeComposerUITests.testSyrupCanBeSavedThenCombinedAndPreviewedWithoutLosingTheLatte` |
| Multi-digit/decimal entry and removal during editing retain correct state | `HomeRecipeComposerUITests.testIngredientAmountTypingRetainsAllDigits` |
| Largest text reaches an actual accessibility-layout builder and explicit Save | `HomeRecipeComposerUITests.testLargestTextCanSaveAnIdeaAndBuildADrink`; inspected native captures |
| Standalone bag/gear management retains the full typed nickname | `HomeLibraryFlowUITests.testSavedHasStandaloneBeansAndGear` |

The sources are the owner interview/read-back above, not a separate generated
plan. Checkpoint commits preserve the earlier RED → GREEN sequence. Later
iteration results are kept here so a final feature commit does not hide failed
attempts or turn an intermittent pass into an acceptance claim.

## Final local acceptance and delivery

- Final guidance/composer batch: **22/22**, comprising 17 native domain cases and
  five native UI journeys. The matcha journey checks the actual Make-screen
  method, the method-tip surface, and two assembly steps rather than four.
- Final accessibility spacing/input follow-up: **1/1**, entering and retaining
  **125 ml** at the largest accessibility text size, then saving the drink.
- Legacy caption → guidance → selected four-star rating → private review:
  **1/1** after the shared guidance correction. Earlier unrelated quick/discovery
  passes are reused; no full Release or backend rerun is justified by this change.
- Earlier repeat reliability gate: **20 distinct cases, 40 successful executions**,
  including complete component composition, multi-digit/decimal input, safe
  ingredient removal while editing and full gear-name persistence.
- Focused coverage from the passing 22-case batch: **98.44%** for the composition
  model (126/128 executable lines), **95.49%** for the new builder (1206/1263).
  Final accessibility quantity-spacing polish has separate compiled runtime
  evidence. This is not app-wide coverage. Whole existing capture, library,
  detail and shared composer files contain unrelated/media/permission branches;
  their raw scoped figures and limitations are in [coverage.json](coverage.json).
- Source hashes, exact raw result-bundle paths, failure chronology and sanitized
  signed-package receipts: [verification.json](verification.json). Six inspected
  fictional native captures are in [the gallery](gallery.html).

Both development packages build and pass deep/strict signature and actual-key
exclusion checks. Owner entitlements remain unchanged; analytics are disabled.
The owner candidate is **Mugshot Luna QA 0.5.3 (8)**, debug-library SHA-256
`9cc76f80d52401cf59254360cbc2abd39cf28f945d1dc09525549293cced1ae2`.
The isolated fixture package matches the current Swift sources and retains its
data/keychain/backend isolation.

**November 4 delivery checkpoint: not installed / not physically accepted.** Repeated safe
owner-container backup attempts stop at CoreDevice error 4016: trusted device
services are unavailable, with no assertable device states. No install is attempted
without the fresh preservation backup. A physical connect/unlock request is
pending; prior same-version phone receipts describe earlier binaries. No owner
recipe is edited or synthetic content saved to the owner app during this task.
No backend deployment, TestFlight archive/export/upload/assignment or parent-stack
merge occurs. PR #109 remains a held draft on `codex/home-library-flow`.

To resume hardware acceptance, use the signed owner package under
`/tmp/mugshot-home-phone-tests/Build/Products/Debug-iphoneos/` and the separate
fixture package under `/tmp/mugshot-home-flow-physical-derived/Build/Products/`.
First obtain a fresh owner backup. Run the 17 composition-domain cases plus the
five composer and five Home-library UI cases only in `co.mugshot.app.homeqa`
(27 checks), with its invalid backend and blank analytics token. Then install the
verified owner candidate, compare the pre-launch files and original records, and
run `OwnerHomePhoneUITests` with the explicit owner/component-flow environment
flags. Never send `--ui-testing` or reset arguments to the owner app. Remove only
the separate synthetic app/runner after hardware verification.

The final Simulator commands use `MugshotTests`, the named test classes/cases,
`-enableCodeCoverage YES`, `-parallel-testing-enabled NO`, the fixture backend,
`CODE_SIGNING_ALLOWED=NO` and the existing QA Simulator. Native-only/API RED
checkpoints and exact bundle outcomes remain above and in the JSON ledger.

## Interaction references

Apple's [Entering data](https://developer.apple.com/design/human-interface-guidelines/entering-data)
and [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
inform paste support, reuse of existing choices, scoped part selection and
preservation of the parent task. These references guide the design; the native
runtime and accessibility checks establish this implementation's behavior.
