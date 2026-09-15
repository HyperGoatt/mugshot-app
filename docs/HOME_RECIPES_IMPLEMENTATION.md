---
document_type: living
status: current
last_verified: 2026-09-15
---

# Native Home and Recipes implementation

## Release state

Work in progress on `codex/home-recipes-production`. The feature flag
`MugshotRoadmap.homeRecipes.v1` defaults off. This is not a production-enabled,
Simulator-accepted, hardware-accepted, or TestFlight-accepted release.
The browser prototype remains a visual reference, not production navigation.
Limited native smoke checks passed; the complete release acceptance matrix has
not been run and the distinction below is intentional.

## Implemented foundation

- Independent, name-only-valid recipe records with immutable versions and
  coffee, component, drink, and custom starting templates.
- Ingredients, source URL and credit, tags, safe bean/equipment snapshots,
  preparation targets, ordered/timed steps, and typed custom fields.
- Built-in preparation fields can be renamed, reordered and hidden per recipe;
  stable metric identifiers retain calculation meaning and hidden values. The
  optional configuration decodes older workspaces without a backfill.
- Ratio/yield calculation, mixed incremental/cumulative pour steps, quantity
  scaling without changing temperature, pressure, grind, or time.
- Separate Home attempts with frozen targets, optional actuals, optional rating,
  reaction, private note, next-time note, make-again intent, and local photos.
- Two-surface quick logging, saved-entry detail, repeating with empty feedback,
  save-as-recipe, favorite results, next-time reminders, and version history.
- Attempt comparison presents recorded measurements, taste, beans and equipment
  without causal claims. Recipe filters persist per account.
- Remote conflicts pause synchronization without preventing local drafts or
  private saves. Attempt-driven recipe updates validate linked references and
  cycles atomically. Reminder authorization preserves newer session progress.
- Resumable preparation sessions and timestamp-based optional timers; cold-brew
  reminders and separately linked serving attempts.
- Atomic account-scoped JSON persistence, draft restoration, verified guest
  adoption, account cleanup, and a compare-and-swap synchronization contract.
- Explicit owner binding on the workspace RPC prevents an account/token race
  from writing one account's local document into another account's workspace.
- Recipe-link sheets preserve the parent editor. Linked content is not expanded
  into a parent publication projection. Cyclic references are rejected.
- Linked component preparation persists its timer, step and readiness inside
  the parent session, keyed by exact version, without creating child attempts.
- Sharing begins after the local attempt is saved and uses the existing Sip
  draft/outbox system, with empty private reflection fields and stable identity.
- Explicit version attachments require an online audience/rights check and
  confirmation. The existing publication worker holds a durable attachment
  receipt; failed attachment setup remains retryable without another post.
- Feed recipe actions, post attachments and recipes shared by friends have a
  unified native detail route. Reference saving is separate from an editable
  adaptation. Legacy values are retained without relabeling them as actuals or
  targets; adaptation preserves credit and does not copy linked instructions.
- Shared sources without copying rights retain only a reference in a new log;
  protected instructions remain in the re-authorized viewing surface rather
  than being persisted into an offline attempt snapshot.

## Data ownership

`HomeRecipeWorkspaceStore` owns the new local workspace under
`Application Support/MugshotHomeRecipes/<account scope>/workspace-v1.json`.
Photo files are account-scoped, use generated basenames, and remain local in
this first increment. They are passed to the existing publication media path
only when the owner chooses Share.

`home_recipe_workspaces` is an owner-readable, RPC-write-only synchronization
document. The RPC atomically mirrors owned recipe identities and immutable
versions into the existing recipe tables. Private full content is stored in
`private.home_recipe_contents`; the shared projection and moderation input use
the same recipe-field allowlist. No attempt reflection is included there.
Nested targets, ingredients, linked references, custom fields, metric layout,
beans and equipment are projected through explicit per-type allowlists rather
than accepting arbitrary nested payloads. Existing adaptation source references
cannot be erased by appending an unattributed version through the direct RPC.

The migration is additive. It does not backfill legacy measurements or fabricate
visits for independent recipes. Legacy Home and `.recipe` entries keep their
existing reading paths. Existing drafts with structured preparation, feedback,
or photos retain the old composer until a lossless migration adapter is ready.

## Remaining release requirements

The following are not complete and must not be inferred from the foundation:

1. Unified inline Journal Home navigation and per-tab scroll restoration,
   and legacy recipe adoption into the new collection.
2. Full runtime acceptance of method-specific actuals, field customization and
   linked component preparation.
3. Full acceptance of Discovery/Feed/Saved routes, shared references, adaptations
   and version-specific attachment selection, including nested sheet dismissal
   and account changes while requests are in flight.
4. Full source-rights, audience, blocked-user and moderation integration tests
   against the complete migration stack. The new attachment harness uses
   controlled legacy helper fixtures, not live production authorization.
5. Remote private-photo continuity, coordinated sync/recovery scheduling, and
   complete concurrent-edit reconciliation for historical version references.
6. Runtime acceptance of method-relevant attempt comparisons, complete
   accessibility review, and privacy-safe funnel instrumentation.
7. Representative legacy migration fixtures, full social authorization matrix,
   consolidated Simulator journeys, and backward-compatible deployment review.

These remain part of the user's requested release, not optional follow-up scope.
Keep the rollout flag off and do not deploy this migration or merge as a
release-ready feature until those requirements pass.

## Verification

The focused hermetic contract is `node qa/pglite/check-home-recipes.mjs`.
It covers owner isolation, expected-owner mismatch, immutable versions,
compare-and-swap conflicts, idempotent operation retries, linked-reference
ownership, cycle rejection, source-rights denial, explicit attachment consent,
attachment retry deduplication and non-recursive visibility. Its social-access helper
is a controlled fixture; it does not replace the full friendship/block/deletion
suite or production migration verification.

The initial foundation passed `scripts/verify-no-simulator.sh full-static`
(12 passed, zero failed, one optional skip). A subsequent generic Debug
app/test compile passed after adding the shared-recipe and attachment routes.
These checks do not establish runtime or production acceptance.

The final native increment compiled for generic iOS Simulator. The focused
`HomeRecipeWorkspaceTests` and `PendingVisitOutboxTests` run passed 13 tests,
zero failed or skipped. The attachment contract also passed after the
audience/source-rights hardening.

The bounded iOS 27 Simulator smoke check verified an unstructured photo-free,
unrated make through two input surfaces; independent Save as recipe; an espresso
target of 18 g × 1:2 = 36 g at 28 seconds; logging a 40.5 g actual without
populating dose or time; persistence after app relaunch; and private-save-first
sharing without a forced photo/rating. It caught and resolved a nested
navigation-stack issue that had kept the saved-entry screen visible after Share.
No remote post was submitted. Automated tap injection did not change screens;
native accessibility actions provided the bounded smoke evidence instead.

`HomeRecipeWorkspaceTests` covers calculation, missing actuals, scaling, mixed
pour targets, custom fields, persistence, repeat clearing, version conflicts,
cycle rejection, account isolation, and guest adoption. This does not substitute
for the remaining six-method end-to-end, migration and remote-media acceptance.

Required release gates remain repository Tier 3 deterministic checks followed
by Tier 4 consolidated Simulator acceptance. Hardware and TestFlight are
separate owner-promoted gates.

The continuation passed the full-static gate (12 passed, zero failed, optional
`pglast` parser skipped because it is not installed) and 16 focused native tests.
The local contract now additionally checks nested projection allowlists and
adaptation provenance. A bounded native check confirmed renaming a built-in dose
label, hiding Temperature and retaining the 18 g to 36 g calculation on returning
to the editor. This is not full journey acceptance. Synthetic launch mode was
found attempting workspace sync to the configured backend; its unavailable RPC
rejected the request, and an explicit UI-test guard now disables workspace sync
for synthetic runs. No remote mutation or migration was performed.
