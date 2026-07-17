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
