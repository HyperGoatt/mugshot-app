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
- Instructions can be hidden without deletion; guidance and cumulative pouring
  targets use only visible steps. Older steps default visible.
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
Photo files are account-scoped and use generated basenames. Private synchronization
uses the existing owner-only `home-coffee-bag-photos` bucket under
`<owner>/home-attempts/<generated basename>`, with durable per-account upload
receipts, idempotent uploads and authenticated downloads. Foreground/network
recovery coordinates workspace sync. Publishing still uses the separate existing
publication media path only after Share. Owner exports include the local workspace,
local attempt photos and, through additive export v4, the remote workspace. The
existing owner media export/deletion allowlist already includes this private bucket.

Explicit conflict reconciliation retains displaced immutable versions for historical
attempt lookup. New recipes depending on displaced versions become editable drafts
instead of an invalid canonical graph. Divergent drafts remain separate; conflicting
saved results and preparation progress require explicit choices in Home. Account and
operation fences prevent an old async task from applying results after switching.
Recovering the same conflicting attempt draft is idempotent, including when another
device already saved its attempt. Saved result targets reflect the preparation
chosen for that make; the original recipe snapshot and optional actuals stay separate.
Positive-amount validation also applies to changes saved Just this time.

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

1. Runtime acceptance of inline Journal Home navigation, account-scoped collection
   scroll restoration and Earlier Home entries. Legacy owner recipes open the unified
   detail and can be explicitly adapted without interpreting ambiguous measurements.
2. Full runtime acceptance of method-specific actuals, field customization and
   linked component preparation.
3. Full acceptance of Discovery/Feed/Saved routes, shared references, adaptations
   and version-specific attachment selection, including nested sheet dismissal
   and account changes while requests are in flight.
4. Full source-rights, audience, blocked-user and moderation integration tests
   against the complete migration stack. The new attachment harness uses
   controlled legacy helper fixtures, not live production authorization.
5. Runtime transport acceptance of private-photo continuity and recovery; the source
   paths and explicit historical conflict reconciliation are now implemented.
6. Runtime acceptance of method-relevant attempt comparisons, complete
   accessibility review. Structural funnel instrumentation is implemented; validate
   the event payload contract without collecting content.
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

The latest continuity increment passed full-static (12 passed, zero failed, one
optional parser skip), plus 71 focused tests covering Home, the publication outbox,
recovery, account lifecycle and analytics. The expanded Home-only suite subsequently
passed 16 tests, including hidden-step behavior. Mock transport coverage verifies
photo retry receipts, downloads on a second local store, and account switching;
this is not acceptance against live Storage.

A bounded iOS 26.3 check verified direct Journal Home navigation, independent
espresso recipe save (18 g, 1:2, 28 seconds), skipped guidance, a 37.5 g actual yield
with unrecorded dose/time, unrated photo-free private saving, repeat clearing,
private-note persistence, and a share preview excluding that note. It caught an
adjusted-target display issue, now covered by a focused regression test. Attachment
consent was cancelled without publishing; remote publication remains unaccepted.

The consolidated local template test then passed on iOS 26.3: espresso, pour-over,
cold brew, component, complete drink and custom recipes each saved to recipe detail
and completed the two-surface log without photos or ratings. The combined run passed
19 tests (18 Home model/store tests and one six-template UI journey), zero failures
or skips. Screenshots are retained in its xcresult bundle. This test covers the
common create/log loop, not detailed guidance, live discovery or remote posting.
After the final Just this time validation fix, the generic Debug app/test compile
and all 19 Home model/store tests passed again (zero failures or skips).
Documentation validation and whitespace checks passed. No hardware or TestFlight
acceptance is implied by these local results.

The complete backend migration/transport gate needs an isolated database. Read-only
inspection found only the production Supabase branch, no configured QA database,
and no local container/Postgres runtime. Permission to create a potentially billable,
data-free development branch was requested. Production remains untouched.
