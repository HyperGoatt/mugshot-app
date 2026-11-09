---
document_type: historical
status: checkpoint
date: 2026-11-09
---

# Home Library and brewing: novice and expert implementation

The owner approved all recommendations in the pasted [November 9 walkthrough](../audits/HOME_PERSONA_WALKTHROUGH_2026-11-09.md). This is a large change to existing Home behavior with new browse and comparison controls. Documentation impact: product behavior, local data ownership and privacy/AI presentation. Use the existing account-scoped shelf, recipe versions, preparation sessions, journal detail, and publication policy. No new backend contract, provider dependency, remote spend or release.

| Slice | Acceptance |
| --- | --- |
| Library and inventory | One library under Saved with Journal shortcut. Empty recipe shelf shows a local starter and Save a recipe you found; no zero-drafts card or useless filters. Populated shelves offer pins, Recently used / Newest / A–Z, method filters, no-match reset, and archived recipe restore. Beans and Gear have independent archive state. Beans offer status and roast-date/name sort with unknown dates explicit. Gear filters by role and named setup. Bag name suffices; all other fields optional. Detail returns directly to originating shelf. |
| Recipe capture and drink builder | One Save a recipe entrance with link, screenshot, video, caption and an explicit manual path; web search identified as external. Idea saves for later; usable instructions expose Make this. Suggest editable Whole drink / Add-in / Brew recipe with examples. Distinguish Base, Milk and Add-ins, show the linked version and source, and switch a linked part while preserving usage amount, source attribution and saved versions. Scale quantities locally where useful. |
| Start and make | Home offers Help me make it or I already made it. Starters work without network or inventory for coffee, tea and matcha. Quick goes directly to name/photos; optional nickname/gear explained. Show applied recipe/setup/default inputs and one Change for this brew action. Today edits never silently update defaults or recipe versions. Guidance shows a next step, useful timers and brief explanations, with optional measurements and shared rating/review. |
| Finish and repeat | Private home review clearly says Save to Journal · Private, optional rating/photo preserved, and sharing previews the selected audience. Saved sip shows comparable Plan / Actual / Last time in exact units, with missing values blank. Make again can carry one explicit planned change in a new draft. Luna remains optional and grounded in recorded evidence. |

Run ECC tests for changes and confirmed defects, reuse existing safe fixtures, then run beginner and expert paths in an isolated Simulator. Inspect SwiftUI state, account fences, immutable source reuse, protected publication, dynamic type and persistence. Record results and update the living docs before pushing to the held draft PR.
