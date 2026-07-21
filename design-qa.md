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
