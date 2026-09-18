---
document_type: historical
status: checkpoint
last_verified: 2026-09-15
---

# Home and Recipes implementation audit and acceptance — 2026-09-15

> Historical checkpoint. The central composer and method breadth in this record
> are superseded by the [Home Sip V3 amendment](HOME_SIP_V3_AMENDMENT_2026-09-18.md).
> Preserve the acceptance results below as evidence for the 2026-09-15 candidate.

Current delivery source: [Home and Recipes implementation](HOME_RECIPES_IMPLEMENTATION.md).

## Scope and safety

This checkpoint audits the approved 38-screen prototype, product plan, living
product documentation, native implementation, backend contracts, and test
coverage. Runtime acceptance used synthetic local app data and the isolated
Supabase branch `home-recipes-acceptance` (`rfjbunvhidcyyzyzcyvh`). All schedules
were disabled and the branch was deleted after acceptance. Production, physical
hardware, and TestFlight were outside this checkpoint and remain unchanged.

## Audit conclusion

The feature model and connected journeys were substantially implemented before
this audit, including private attempts, immutable recipe versions, guided
preparation, batch continuity, linked components, discovery/adaptation, explicit
post attachments, account-scoped recovery, and hosted persistence. The material
remaining product gap was the native creation surface: it opened as one dense
generic form rather than the prototype's template-first progressive editor.

That gap is now implemented in source. New-recipe creation starts with Coffee,
Component, Complete drink, or Blank; coffee receives method-aware defaults;
optional sections are disclosed progressively; linked versions can be searched,
filtered, previewed, and attached without losing parent edits; and user tags are
usable library filters. The complete hosted SQL suite passes 65 of 65 contracts
after obsolete provider-queue expectations were reconciled with the current
local-text/reactive-moderation policy. Native hosted transport, three connected
Simulator journeys, and the largest Dynamic Type route also pass. No planned
source behavior remains open; production deployment and distribution remain
separate release gates.

The final consolidated iOS 26.3 result bundle passed 21 focused Home tests and
all three journey tests together with zero failures.

## Prototype-to-native coverage

| Prototype screen | Native production route | Source status |
| --- | --- | --- |
| 1. Home journal | Journal > Home > My makes | Implemented |
| 2. Unified recipe library | Journal > Home > Recipes | Implemented |
| 3. New-recipe template chooser | New recipe sheet | Implemented in this checkpoint |
| 4. Espresso recipe editor | Coffee template > Espresso | Implemented with 18 g, 1:2, 28 sec defaults |
| 5. Expanded espresso details | More details disclosure | Implemented |
| 6. Saved espresso recipe | Recipe detail/version | Implemented |
| 7. Espresso making view | Make this | Implemented |
| 8. Actuals and taste | Quick log preparation + reflection | Implemented |
| 9. Saved espresso attempt | Private attempt detail | Implemented |
| 10. Inspiration link | Inspiration & credit disclosure | Implemented |
| 11. Component recipe editor | Component template | Implemented |
| 12. Component preparation | Ingredient checklist/instructions | Implemented |
| 13. Component result | Attempt reflection/detail | Implemented |
| 14. Complete-drink editor | Complete drink template | Implemented |
| 15. Linked-recipe picker | Search/filter exact versions | Implemented in this checkpoint |
| 16. Linked-recipe detail | Non-destructive preview sheet | Implemented |
| 17. Completed latte recipe | Recipe detail | Implemented |
| 18. Latte preparation | Parent preparation with component readiness | Implemented |
| 19. Finished-drink capture | Quick-log first surface | Implemented |
| 20. Sip reflection | Quick-log second surface | Implemented |
| 21. Saved private latte | Attempt detail | Implemented |
| 22. Post composer | Share this make | Implemented |
| 23. Recipe-attachment privacy | Version-specific consent sheet | Implemented |
| 24. Published post | Existing post completion/feed | Implemented |
| 25. Make-again setup | Make again / use this setup | Implemented |
| 26. Changed attempt comparison | Attempt comparison | Implemented |
| 27. Recipe update and history | Just this time/update recipe + versions/attempts | Implemented |
| 28. Pour-over editor | Coffee template > Pour-over | Implemented |
| 29. Pour-step editor | Editable cumulative/incremental steps | Implemented |
| 30. Guided pour-over | Current/next step and cumulative water | Implemented |
| 31. Saved pour-over result | Attempt detail | Implemented |
| 32. Cold-brew editor | Coffee template > Cold brew | Implemented |
| 33. Batch in progress | Durable preparation session | Implemented |
| 34. Completion and dilution | Batch completion + serving log | Implemented |
| 35. Saved cold-brew result | Batch attempt detail | Implemented |
| 36. Blank/custom recipe | Blank template + custom fields | Implemented |
| 37. Quick Home log | Add/Home or Log a make | Implemented |
| 38. Quick unrated reflection | Rate later + Save to journal | Implemented |

The alternate prototype states are mapped as follows: empty Home and empty
Recipes use intentional empty guidance; source-only recipes offer Add preparation
details; unavailable links remain editable references; recipe/attempt drafts and
preparation sessions resume from Home; pending sync is non-blocking; failed posts
preserve the private entry and draft; component-only and photo-free posts use
real content and icons; linked recipe visibility remains independent; and native
controls support Dynamic Type, VoiceOver labels, Reduce Motion, and standard
touch targets.

## Consolidated acceptance matrix

| Area | Evidence required for this checkpoint | State |
| --- | --- | --- |
| Template-first creation | Create all four templates; verify method defaults and progressive sections | Passed: native UI journey plus method-default tests |
| Everyday logging | Recipe and no-recipe makes save through two surfaces without photo/rating | Passed: six-template UI journey and focused quick-log checks |
| Espresso math | 18 g x 1:2 = 36 g; yield-driven ratio; unknown actuals stay unknown | Passed: model/store tests and connected Simulator acceptance |
| Pour-over | Mixed cumulative/incremental steps and guided cumulative targets | Passed: model/store tests and guided UI journey |
| Cold brew | Relaunch resumes timestamped batch; serving does not duplicate production | Passed: model/store tests and relaunch UI journey |
| Linked recipes | Exact version, preview, readiness, no automatic component attempt | Passed: model/store tests and linked-component UI journey |
| Repeat/history | Cleared feedback, explicit historical setup, version choice, comparison | Passed: model/store tests and bounded native acceptance |
| Discovery/adaptation | Save reference, direct make/log, attributed adaptation, rights enforcement | Passed: native routes plus hermetic/hosted authorization contracts |
| Sharing/privacy | Private-save-first, explicit attachments, nested privacy, retry idempotence | Passed: hosted transport, HTTP, and full SQL regression |
| Continuity | Offline/local save, sync retry, conflict recovery, account isolation, private media | Passed: 21 focused tests and hosted two-store media/conflict journey |
| Backend regression | All repository SQL contracts on isolated branch | Passed: 65/65 |
| Accessibility | Large Dynamic Type layout and meaningful control labels | Passed at accessibility-extra-extra-extra-large; water rows expose label/value identifiers |
| Cafe/Elsewhere regression | Existing scoring and journal routes remain unchanged | Passed: full-static and hosted SQL regression; Home-only unrated sentinel remains context-gated |
