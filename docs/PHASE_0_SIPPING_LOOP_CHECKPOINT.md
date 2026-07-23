# Phase 0 — Sipping Loop Checkpoint

Status: Complete
Branch: `codex/full-lifecycle-roadmap`
Baseline: `d049283`
Last updated: 2026-07-13

Phase 0 is complete under Mugshot's risk-based roadmap policy. Exit-gate rows are evidence prompts, not absolute blockers: the phase advances when its core journey is reliable, privacy and data-integrity invariants hold, and remaining gaps are low-risk, understood, and documented.

## Implemented

- Guided is the default composer. Long Form remains a DEBUG-only evaluation control.
- The rating step offers `Save privately now` after context, drink, and Quick Rating or Tasting Lens.
- Cafe and Home are the primary contexts. Recipe is nested inside Home as a reusable brew option.
- Private and Friends saves no longer inherit a legacy photo or caption requirement.
- Everyone without media requires shareable text and a separate text-only confirmation.
- The custom bottom dock is hidden during the composer so its footer uses the full safe area.
- Save diagnostics record only opaque draft or visit identifiers and pipeline stages.
- Draft recovery now has deterministic DEBUG coverage for photo upload failure, retry, relaunch, and authentication interruption without weakening the production submission path.
- No-photo sip detail uses one readable hero instead of overlapping legacy and current titles.
- The local Journal projection now renders and reopens private local sips, including after an authentication interruption.
- The `analyze-drink` Edge Function is deployed with JWT verification, visit ownership enforcement, idempotent writes, parser versioning, and retry metadata.
- All 18 analysis rows are in a terminal state: 12 estimated and 6 intentionally excluded. No pending or failed rows remain.
- The live `visit-photos` bucket and authenticated owner mutation policies are now represented by forward migrations rather than manual-only state.
- Photo, caption, and tags now live in the drink chapter, before rating; optional brew depth and private notes remain in the final chapter.
- Owner deletion now retains enough owner-only Storage metadata visibility for durable media cleanup after the visit row is removed.

## Database and Edge Function

- Supabase project: `quskamnfwglctqewwfln`
- Migrations:
  - `20260713231635_add_drink_analysis_retry_metadata_and_backfill`
  - `20260714013618_harden_visit_photo_storage_contract`
  - `20260714013836_optimize_visit_photo_storage_policies`
  - `20260714025602_allow_owner_visit_photo_cleanup`
- Edge Function: `analyze-drink`, deployed version 1
- JWT verification: enabled
- Live authenticated analysis check: `complete`, parser `edge-rules-2`, caffeine coverage `estimated`
- Unauthenticated request check: rejected with HTTP 401

## Automated Verification

- iOS build: passed on iPhone 17 Pro, iOS 26.2.
- Swift unit target: 63 passed, 0 failed, 0 skipped.
- Seven guided XCUITest journeys pass on the final build. They were split into deterministic groups to stay within the automation transport limit.
- Ten clean Quick Sip saves completed in 9.31–10.76 seconds; median 9.45 seconds. Each run required context, drink, and rating only.
- Everyone text-only safeguards and persisted draft restoration passed in UI automation.
- A photo-bearing draft survived a forced save failure, relaunch, retry, Feed projection, and reopened detail in deterministic UI automation.
- An interrupted authentication save preserved its private draft through relaunch and reopened from Journal after retry.
- Home Tasting Lens with Friends visibility saved, projected the immutable natural-language drink name, reopened, and retained its criterion breakdown.
- Saved cafe entry preselected the cafe, avoided redundant search, saved with Friends visibility, projected to Feed, and reopened with the correct cafe.
- The guided context, drink, and rating screens pass the iOS accessibility audit for hit regions, element descriptions, clipped text, and traits.
- Shared segmented controls now meet the 44-point target minimum, the chapter progress indicator is exposed as informational, and the drink field wraps through larger text sizes.
- Edge Function Deno type-check: passed.
- Supabase `social_rls.sql`: passed.
- Supabase `discovery_social_contract.sql`: passed.
- Supabase `drink_analysis_contract.sql`: passed.
- Supabase `migration_integrity.sql`: passed.
- Supabase `visit_photo_storage_contract.sql`: passed.
- The Storage contract now behaviorally verifies that an owner can recover orphan metadata for cleanup while another authenticated user cannot read it.
- Supabase security and performance advisors were rerun. The new drink-analysis contract has RLS, owner-bound correction checks, restricted grants, and retry indexing; remaining advisor findings are preexisting project-wide hardening work, not a new Phase 0 regression.
- Product-copy scan found no accented spelling of `cafe` or `cafes` in production code, tests, Supabase, or docs.

## Simulator Flow Evidence

Screenshot artifact folder:

`/Users/joe.rosso/.codex/visualizations/2026/07/13/019f5bda-9c1e-7a62-b883-3031550aa18e/phase-0-sipping-loop`

1. Cafe context — Healthy. Cafe and Home are the only primary choices; a real cafe remains attached.
2. Home/Recipe context — Healthy. Recipe is nested inside Home and explains its reusable role.
3. Natural-language drink — Healthy. The drink remains a single unrestricted source field.
4. Quick Rating — Healthy. A 4.5 rating maps correctly and exposes `Save privately now`.
5. Tasting Lens — Healthy. Personal criteria replace the overall rating; a long lens scrolls to the optional-memory route and the next chapter starts at its top.
6. Private save and social projection — Healthy. A private no-photo sip saves without entering the social Feed; Friends saves project immediately.
7. Sip detail — Healthy after repair. The saved no-photo sip reopened and its hero no longer overlaps.
8. Everyone guard — Healthy. Empty Everyone content is blocked; text-only content shows an explicit confirmation before any publish occurs.
9. Relaunch restoration — Healthy. The draft restored at guided step 4 with its caption and visibility intact, then was returned to Private without publishing.
10. Increased contrast and accessibility text-size check — The longest Home Tasting Lens path passed on an iPhone 16e at accessibility XXXL with increased contrast, including save and reopened detail. VoiceOver and hardware-keyboard review remain manual gates.
11. Local Feed projection — Healthy. The authored natural-language drink name is now preferred over the compatibility drink family in Feed, Map, Saved, and detail surfaces.
12. Local card opening — Healthy. The visible Open affordance is an accessible button, and item-driven presentation removes the prior state-order race.
13. Final worktree launch — Healthy. XcodeBuildMCP was redirected from the stale Desktop checkout to this worktree, then built and launched successfully with no runtime warning/error matches.
14. Final accessibility visual check — Healthy. The 44-point Cafe/Home control remains compact and balanced; a 71-character drink name wraps to two lines without clipping or displacing the persistent footer.
15. Live authenticated publishing — Healthy. Private photo failure/retry, Friends publishing, Everyone text-only confirmation, and sip-detail reopening all completed on the signed-in account.
16. Live cleanup — Healthy after repair. All three temporary visits, photo rows, analyses, and the uploaded Storage object were deleted; final residual counts are zero.

Accepted screenshots:

- `01-context-cafe-device.png`
- `01b-home-recipe-nested-device-stable.png`
- `02-natural-language-drink-device.png`
- `03-quick-rating-private-save-device.png`
- `03b-tasting-lens-device-stable.png`
- `04-private-sip-reopened-device.png`
- `05-accessibility-extra-large-increased-contrast.jpeg`
- `06-final-context-targets.jpeg`
- `07-final-wrapping-drink-field.jpeg`
- `08-photo-first-drink-chapter.jpeg`

## Residual Follow-up — Non-blocking

- A physical network-off toggle remains useful continuous QA. The same remote pipeline has passed a forced `networkConnectionLost`, retained its authenticated failed visit and local media, then retried to one completed remote visit.
- Manual VoiceOver listening order and hardware-keyboard focus remain recommended device QA. Automated semantics, hit regions, clipping, traits, Dynamic Type, contrast, and Reduce Motion behavior pass.
- Additional screenshot device sizes remain release-polish work; iPhone 17 Pro and small-phone accessibility coverage are complete.
- The live account exercised Home Quick Rating for all three audiences. Home Tasting Lens remains covered by deterministic end-to-end UI automation and domain tests.

## Scope Notes

- Phase 1 is the next active phase.
- Phase 7 merchant rewards, payments, loyalty, and partnerships remain unimplemented.
- No branch has been pushed and no pull request has been opened.
