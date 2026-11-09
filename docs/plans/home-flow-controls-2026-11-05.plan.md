---
document_type: historical
status: implemented-physically-accepted
---

# Home journey control implementation plan

Source: [completed audit and screen inventory](../audits/HOME_JOURNEY_CONTROLS_2026-11-05.md).
The owner has requested audit → plan → implementation; proceed within that scope.
This plan is a task/evidence ledger, not permission to deploy or delete owner data.

## P1 — Data and action guarantees

- [x] Add owner-bound Home deletion/draft policies and persisted workspace deletion
  markers. Preserve recipes, referenced photos, other batch servings and legacy
  decoding. Reconciliation and stale autosave cannot resurrect deleted work.
- [x] Add private-sip deletion, draft/session/recipe discard and confirmed remote
  post cleanup through existing services, with scope, failure and retry guards.
- [x] RED/GREEN: `HomeJourneyControlTests` covers scope mismatch, protected work,
  failed writes/remote operations, idempotency, relaunch, conflict and media retention.
- [x] Preserve deletion markers on the server when an older client omits them;
  add a narrowly scoped workspace trigger with hermetic and disposable contracts.
  Keep existing auth/RLS/immutable recipe contracts. A live release requires its
  own approved data-less QA branch and the repository release gates.

## P2 — Journal parity and profile identity

- [x] Extract one Journal row layout with one photo size, context/date/place/drink/
  score hierarchy. Both remote and private Home adapters use it.
- [x] Merge Home entries into recent/archive chronology and date filtering while
  deduplicating published counterparts; Home locations stay off maps.
- [x] Add optional account-local named Home profiles and selected gear/defaults.
  Snapshot the displayed name into each make/publication; old records keep Home.
  Reserve generic Home and enforce unique account nicknames in the model/store.
- [x] RED/GREEN: projection/profile persistence and old decoding tests; native
  card geometry/metadata, archive date and owner/guest separation cases.

## P3 — Complete, quieter draft management

- [x] Replace expanded Continue piles with a single counted Drafts entry.
- [x] Provide categorized resume/discard for every meaningful sip, recipe,
  attempt and active session; deduplicate representations of the same make.
- [x] Reuse confirmations and existing protected publication recovery rather than
  deleting submitted/published work locally. Refresh counts after actions.
- [x] RED/GREEN: UI resume-last-surface, discard/cancel, empty state, locked work
  and linked session/draft removal with unrelated work retained.

## P4 — Designed screens and explicit progression

- [x] Build a reusable Mugshot editor canvas with visual section cards, readable
  hierarchy, field labels and accessible row actions.
- [x] Convert all four audited Home Form shells; keep ingredient/step/custom-field
  add/remove/reorder, recipe source/rights, photos, gear archive and save validation.
- [x] Name actual next actions and expose Skip for optional actuals. Retain the
  accepted quick/guided paths, common rating/review and full-screen completion.
- [x] Review camera/Photos/speech/notification/Luna denial/revocation and account
  switches. No new mandatory permission or hidden publish action.
- [x] Constrain embedded library controls to supported handoffs: root library
  keeps all sections/drafts, recipe-selection sheets select recipes, gear-only
  sheets stay in their requested section.
- [x] Native gallery before final integration review; regular and largest text,
  empty/error states and targeted existing Home journeys after implementation.

## P5 — Close the delivery

- [x] Scoped security/SwiftUI task/state review, meaningful focused coverage,
  static/compile/backend contracts appropriate to the changed boundaries.
- [x] Update living product/data/architecture/permission documents and CHANGELOG;
  run documentation and diff checks; exclude secrets/private/generated-local data.
- [x] Signed isolated iPhone fixtures, fresh owner backup, safe candidate install
  and read-only acceptance when available. No owner deletion fixture or TestFlight.
- [x] Preserve ECC RED/GREEN commits, push and update held draft PR #109; report
  exact local/Simulator/physical states, source limitations and human QA.

## Delivery closure

Implemented and locally/physically accepted; code checkpoint `2bae8ef` is pushed
on `codex/home-library-flow` and held draft PR #109 is updated. All 106 native
tests, 18 selected Simulator/phone UI paths and the separate owner read-only
check have passing evidence. All 68 hosted contracts and real Auth/Storage probes
pass. The deletion guard is live; held Home V4 and TestFlight remain unchanged.
The audit records source, install, live, hardware, retry and preservation evidence
separately. All plan items are complete; subjective owner design feedback remains
welcome without replacing these verified gates.
