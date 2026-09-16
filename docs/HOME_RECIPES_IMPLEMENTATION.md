---
document_type: living
status: current
last_verified: 2026-09-16
---

# Native Home and Recipes implementation

## Release state

The approved Home and Recipes plan is implemented in native source and
production-configured. Production is aligned to migration
`20260916020417_home_recipe_http_conflicts.sql`, and
`MugshotRoadmap.homeRecipes.v1` now defaults on while retaining an explicit
stored `false` as a data-preserving rollback switch. The browser gallery remains
design evidence rather than production navigation.

Implementation acceptance is complete for the repository candidate: deterministic
contracts, all hosted SQL contracts, real isolated Auth/API/Storage transport,
the focused native model/store suite, the connected Simulator journeys, and the
largest Dynamic Type journey pass. The disposable acceptance branch was deleted
after verification. The signed production-connected Debug candidate is installed
and launched on the owner's iPhone for hands-on acceptance. No TestFlight
acceptance is claimed.

## Product behavior

### Home and daily logging

- Journal > Home retains independent My makes and Recipes collection state,
  surfaces active batches and interrupted drafts first, and provides usuals,
  recent makes, Earlier entries, intentional empty states, and the full library.
- Add > Home and Recipe > Log a make attach a recipe without forcing guidance.
  The first surface captures the creation and optional preparation/photo data;
  the second captures optional rating, reaction, private note, make-again intent,
  and next-time note. A photo-free, unrated entry is valid.
- Saving always opens the real private attempt. Make again, Save as recipe, Share,
  favorite-result, batch-serving, history, comparison, and next-time-note actions
  operate on that saved attempt rather than a transient example.
- Repeating retains the selected recipe version and targets while clearing old
  actuals, photos, ratings, and reflections. A historical variation can be chosen
  explicitly. Unchanged makes create no recipe version; Update my recipe appends
  an immutable version and Just this time remains the default.

### One flexible recipe system

- Coffee preparation, Component, Complete drink, and Blank are starting templates,
  not separate data models. Only the name is required.
- New-recipe creation is template-first and progressively discloses inspiration,
  beans/equipment, ingredients, instructions, yield/tags/notes, and custom fields.
  Source-only and arbitrary custom recipes remain valid.
- Search covers names, tags, methods, beans, and equipment. All, Coffee,
  Components, Drinks, and user-tag filters coexist with pinned and recent recipes.
- Built-in and custom fields can be renamed, reordered, hidden, and restored per
  recipe. Stable metric identifiers preserve calculations independently of labels.
- Inspiration links store Instagram, TikTok, or website URLs and creator credit;
  unavailable links never block saving and no video extraction is promised.

### Preparation breadth

- Espresso starts at 18 g, 1:2, and 28 seconds. Ratio or yield can drive the
  calculated counterpart. Grind, temperature, preinfusion, pressure, and notes
  remain optional. Targets never become recorded actuals.
- Pour-over starts at 20 g and 300 g with three editable steps: bloom to 60 g and
  wait 40 seconds, pour to 180 g, then finish to 300 g at 1:20. Incremental and
  cumulative water modes can be mixed; guidance exposes the current cumulative
  target, next action, timer, and previous/next navigation.
- Cold brew separates brew ratio, steep duration, and serving dilution. A batch
  uses durable timestamps and optional reminders, resumes after relaunch, and can
  produce multiple serving logs without duplicating batch production.
- AeroPress, French press, immersion, moka pot, batch, pods, and unknown methods
  receive sensible editable starting fields. Quantities scale by multiplier,
  servings, or coffee dose without silently changing time, temperature, grind,
  pressure, or steep duration, and without mass/volume conversion.
- Components and drinks use ingredient checklists and ordered instructions. An
  ingredient may point to an exact immutable recipe version and amount. Its detail
  opens without losing parent edits. Preparation readiness is explicit and making
  a parent drink never creates a child attempt unless the user separately logs one.

### Discovery and sharing

- Existing Feed, Saved, and shared-recipe entry points open the unified recipe
  detail. An accessible recipe can be saved as a reference, made directly, or
  adapted into an editable personal copy with retained attribution and rights.
- Protected no-copy instructions are authorized for viewing/making without being
  persisted into an offline attempt or adaptation. Archived versions remain
  resolvable by historical attempts.
- A private attempt is saved before the post composer opens. The composer uses the
  attempt's real media, supports Friends or Everyone, previews the post payload,
  and preserves its draft on failure.
- Recipe attachments are explicit, version-specific, audience-checked, retry-safe,
  and non-recursive. A parent never publishes linked component instructions.
  Private notes, next-time notes, inventory, and private media paths are excluded.
  Component-only, photo-free, and unrated posts remain valid.

## Architecture and data ownership

`HomeRecipeWorkspaceStore` owns an atomic account-scoped document under
`Application Support/MugshotHomeRecipes/<account scope>/workspace-v1.json`.
Recipes, immutable versions, attempts, frozen target snapshots, optional actuals,
preparation sessions, batch references, drafts, preferences, and conflict state
have typed identifiers. Account and operation fences prevent an old asynchronous
task from applying after an account change. Guest adoption is verified and
idempotent.

Private attempt images use generated basenames in the existing owner-only
`home-coffee-bag-photos` bucket under
`<owner>/home-attempts/<generated basename>`. Durable receipts make uploads
idempotent and allow authenticated downloads on another device. Owner export v4
includes the workspace and private media; optional posting uses the separate
publication media path only after Share.

`home_recipe_workspaces` is owner-readable and RPC-write-only. The RPC binds the
expected owner, compares revisions, mirrors recipe identities and immutable
versions, and stores full private content in `private.home_recipe_contents`.
Shared projections use explicit nested allowlists and retain source attribution.
Linked-reference ownership and cycles are validated atomically. Conflicting edits
preserve both drafts and displaced immutable versions for explicit reconciliation.

The additive migrations do not fabricate journal visits, reinterpret ambiguous
legacy values, or remove legacy `.recipe` reading paths. Existing structured
legacy drafts remain in their lossless composer until a safe adapter exists.

## Verification record

Tier 4 acceptance used synthetic local data and a disposable, data-free Supabase
branch containing all 177 repository migrations through
`20260916020417_home_recipe_http_conflicts.sql`. Production was targeted only
after that acceptance and a fresh restorable physical backup.

- All 65 files in `supabase/tests` passed together. The seven formerly stale
  provider-queue/moderation expectations now follow the current local-text and
  reactive-human-moderation contract.
- `qa/pglite/check-home-recipes.mjs` and the remote-screening hermetic contract
  pass owner isolation, conflicts, cycles, projection allowlists, attribution,
  audience consent, retry idempotency, and non-recursive privacy.
- Hosted native acceptance on iOS 26.3 passed real Auth sign-in, workspace sync,
  typed projection decoding, private JPEG upload/download into a second store,
  immediate conflict recovery, account isolation, and unrated photo-free
  publication. The same run passed all 21 `HomeRecipeWorkspaceTests`.
- Simulator journeys pass independent creation and unrated logging for espresso,
  pour-over, cold brew, component, complete drink, and blank recipes; guided
  mixed-water pour-over; a cold-brew batch resumed after relaunch; exact-version
  linked component preparation without a child attempt; and private saving.
- The final consolidated iOS 26.3 bundle passed all 21 focused Home tests and all
  three end-to-end journeys together with zero failures.
- The linked component/drink journey also passes at
  `accessibility-extra-extra-extra-large`. Preparation water rows expose explicit
  accessibility labels, values, and stable identifiers.
- The repository full-static gate passes 12 required checks with zero failures;
  optional `pglast` parsing is skipped when that package is unavailable.
- Production dry-run named only the two reviewed Home migrations. Deployment
  advanced live history from 175 to 177 migrations. Auth-user, visit, recipe
  identity/version, and Storage-object counts; whole-row fingerprints for visits
  and recipe records; and every bucket visibility value matched before and after.
  The new tables began empty with RLS enabled, anonymous RPC execution denied,
  authenticated RPC execution granted, and business conflicts mapped to HTTP 409.
- The default-on/explicit-off rollback behavior and all focused Home tests pass
  together (22 tests). The signed Debug candidate built, installed, launched, and
  remained running on Joe's iPhone 16 Pro without changing the App Store marketing
  version or build number.

The acceptance branch `home-recipes-acceptance`
(`rfjbunvhidcyyzyzcyvh`) contained only synthetic `.invalid` users and disabled
schedules. It was deleted after the final hosted runs, stopping its hourly charge.

## Remaining rollout gates

No implementation item from the approved Home and Recipes plan remains open in
this source candidate. The following are release operations, not missing product
scope:

1. Complete owner hands-on acceptance on the launched production-connected
   Debug candidate. Source, production schema, and the default-on flag are ready.
2. Archive, upload, or assign a TestFlight build only after an explicit TestFlight
   request and the required Simulator and connected-iPhone gates.
