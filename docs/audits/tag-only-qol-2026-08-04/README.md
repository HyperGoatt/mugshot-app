# Tag-only quality sprint audit

Date: August 4, 2026

## Scope

This audit covered the posted-Mugshot editor, tag-only social data, private Journal people recaps, publishing and recovery, Map aggregation, cafe selection, and connected detail actions. Production data and the production Supabase project were not touched.

## Numbered evidence

Before:

1. [`before/01-launch.png`](before/01-launch.png) — baseline app shell.
2. [`before/02-sip-detail.png`](before/02-sip-detail.png) — baseline sip detail.

After:

1. [`after/01-full-posted-mugshot-editor.png`](after/01-full-posted-mugshot-editor.png) — recovered owner editor with photo, caption, and criteria controls.
2. [`after/02-editor-audiences-and-tags.png`](after/02-editor-audiences-and-tags.png) — constrained journal/post audiences, tags, and save action.
3. [`after/03-publishing-restored-draft.png`](after/03-publishing-restored-draft.png) — relaunched draft restored at publishing.
4. [`after/04-published-recovery.png`](after/04-published-recovery.png) — truthful already-published recovery state without a duplicate retry action.
5. [`after/05-private-people-recap.png`](after/05-private-people-recap.png) — owner-private monthly people counts.
6. [`after/06-map-aggregate.png`](after/06-map-aggregate.png), [`after/06b-map-individual-cafes.png`](after/06b-map-individual-cafes.png), and [`after/06c-map-named-places.png`](after/06c-map-named-places.png) — zoom-first Map progression.
7. [`after/07-connected-detail-actions.png`](after/07-connected-detail-actions.png) — explicit Journal-note audience and privacy-safe detail actions.
8. [`after/08-one-tap-composer-cafe-selection.png`](after/08-one-tap-composer-cafe-selection.png) — one-tap recent cafe selection without losing the draft.
9. [`after/09-one-tap-map-cafe-selection.png`](after/09-one-tap-map-cafe-selection.png) — one-tap recent cafe selection opening the correct Map card.

## Findings resolved

- Removed Shared Mugshot ownership, invitation, membership, contribution, grouped-presentation, activity, preference, export, cleanup, capability, draft, service, and UI paths. Historical contributions are converted to reciprocal tags without merging posts or changing audiences.
- Recovered the complete remote owner editor and made tags part of the same atomic edit contract as visit, reflection, audience, criteria, and ordered photo changes.
- Added owner-private monthly and yearly people recaps over current tags only.
- Consolidated composer and recovery post-publication work through `SipPostPublicationSetupWorker`, including durable tag projection retry.
- Fixed an iOS 26 Add control whose nested interactive glass surface could intercept the parent tab button.
- Removed the animated duplicate journal-note preview that briefly overlapped its explicit audience disclosure.
- Explicitly revoked anonymous execution of owner-only Mugshot share-link controls after the QA database exposed inherited default grants.
- Confirmed Map's existing zoom-first policy: individual pins open the correct cafe, multi-cafe markers zoom, coincident cafes eventually open a list, and search/recent rows select and dismiss in one tap.

## Acceptance matrix

- Backend/static: 11 repository checks passed; 159 SQL files parsed; Deno checks passed.
- Disposable Supabase QA branch: 47/47 SQL/RLS contracts passed, including atomic edits, cross-owner rejection, rollback, photo order/ownership, tag validation and self-removal, blocking, audience rules, historical conversion, recap bounds, and stable ordering.
- Swift: 331/331 unit tests passed. Focused coverage includes edit normalization, criteria, cover order, tag bounds, legacy decoding, publication receipts, account-scoped recovery, FIFO pending posts, Map scopes, stale cafe handling, and coincident-cafe selection policy.
- Simulator: 11/11 serial acceptance tests passed for editing evidence, publishing restoration, failed photo-save relaunch/retry, published recovery, private recap, Map aggregation, one-tap cafe selection, connected detail actions, and accessibility. The final detail polish was then rerun and passed independently.
- Visual review: numbered screenshots were inspected at the same 402-by-874-point Simulator viewport. The sip-detail before/after pair was reviewed together; new editor and recap surfaces had no prior production counterpart.

## Limits and follow-up

- The formal in-app Browser pass could not be completed because the Browser's URL policy rejected the local app surface. Simulator UI tests, accessibility audits, deterministic tests, and direct screenshot review were used instead.
- Camera hardware, signing, push notifications, and a production-network smoke test remain device/deployment gates. Production migration deployment still requires explicit approval.
- The Add-control hit-target correction and its audit evidence are delivered as a separate follow-up change so the tag/editor migration review stays focused.
