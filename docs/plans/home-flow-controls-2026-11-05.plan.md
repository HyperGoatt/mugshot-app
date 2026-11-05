---
document_type: historical
status: planned
---

# Home journey control implementation plan

Source: [completed audit and screen inventory](../audits/HOME_JOURNEY_CONTROLS_2026-11-05.md).
The owner has requested audit → plan → implementation; proceed within that scope.
This plan is a task/evidence ledger, not permission to deploy or delete owner data.

## P1 — Data and action guarantees

- [ ] Add owner-bound Home deletion/draft policies and persisted workspace deletion
  markers. Preserve recipes, referenced photos, other batch servings and legacy
  decoding. Reconciliation and stale autosave cannot resurrect deleted work.
- [ ] Add private-sip deletion, draft/session/recipe discard and confirmed remote
  post cleanup through existing services, with scope, failure and retry guards.
- [ ] RED/GREEN: `HomeJourneyControlTests` covers scope mismatch, protected work,
  failed writes/remote operations, idempotency, relaunch, conflict and media retention.

## P2 — Journal parity and profile identity

- [ ] Extract one Journal row layout with one photo size, context/date/place/drink/
  score hierarchy. Both remote and private Home adapters use it.
- [ ] Merge Home entries into recent/archive chronology and date filtering while
  deduplicating published counterparts; Home locations stay off maps.
- [ ] Add optional account-local named Home profiles and selected gear/defaults.
  Snapshot the displayed name into each make/publication; old records keep Home.
- [ ] RED/GREEN: projection/profile persistence and old decoding tests; native
  card geometry/metadata, archive date and owner/guest separation cases.

## P3 — Complete, quieter draft management

- [ ] Replace expanded Continue piles with a single counted Drafts entry.
- [ ] Provide categorized resume/discard for every meaningful sip, recipe,
  attempt and active session; deduplicate representations of the same make.
- [ ] Reuse confirmations and existing protected publication recovery rather than
  deleting submitted/published work locally. Refresh counts after actions.
- [ ] RED/GREEN: UI resume-last-surface, discard/cancel, empty state, locked work
  and linked session/draft removal with unrelated work retained.

## P4 — Designed screens and explicit progression

- [ ] Build a reusable Mugshot editor canvas with visual section cards, readable
  hierarchy, field labels and accessible row actions.
- [ ] Convert all four audited Home Form shells; keep ingredient/step/custom-field
  add/remove/reorder, recipe source/rights, photos, gear archive and save validation.
- [ ] Name actual next actions and expose Skip for optional actuals. Retain the
  accepted quick/guided paths, common rating/review and full-screen completion.
- [ ] Review camera/Photos/speech/notification/Luna denial/revocation and account
  switches. No new mandatory permission or hidden publish action.
- [ ] Native gallery before final integration review; regular and largest text,
  empty/error states and targeted existing Home journeys after implementation.

## P5 — Close the delivery

- [ ] Scoped security/SwiftUI task/state review, meaningful focused coverage,
  static/compile/backend contracts appropriate to the changed boundaries.
- [ ] Update living product/data/architecture/permission documents and CHANGELOG;
  run documentation and diff checks; exclude secrets/private/generated-local data.
- [ ] Signed isolated iPhone fixtures, fresh owner backup, safe candidate install
  and read-only acceptance when available. No owner deletion fixture or TestFlight.
- [ ] Preserve ECC RED/GREEN commits, push and update held draft PR #109; report
  exact local/Simulator/physical states, source limitations and human QA.
