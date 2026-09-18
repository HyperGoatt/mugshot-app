---
document_type: living
status: current
last_verified: 2026-09-18
---

# Native Home and Recipes implementation

## Release state

The approved Home and Recipes plan is implemented in native source and
production-configured. Production is aligned to migration
`20260916020417_home_recipe_http_conflicts.sql`, and
`MugshotRoadmap.homeRecipes.v1` now defaults on while retaining an explicit
stored `false` as a data-preserving rollback switch. The browser gallery remains
design evidence rather than production navigation.

Current source implements [Home Sip V3](HOME_SIP_V3_AMENDMENT_2026-09-18.md).
Central Add > Log a Sip > Home remains inside the production composer and opens
setup-first; **Already made it? Quick log** is a visible secondary route. Journal
> Home continues to provide the full My makes / Recipes workspace. Existing
account-scoped data, immutable versions, historical attempts, attribution, and
production schema remain intact. The already-distributed TestFlight 0.5.3 (8)
still contains its historical under-construction placeholder and is not evidence
for this source candidate.

The 2026-09-15 and 2026-09-17 acceptance records remain historical evidence for
their candidates. Home Sip V3 changes central navigation, preparation breadth,
reflection evidence, save/share sequencing, method identity, and publishing
privacy. It is implemented in source, generic app/test compilation passes, and
the focused Home runtime gate passes on iOS 27.0. The current Tier 4 acceptance
state is recorded below. No replacement TestFlight upload or App Store release
is claimed.

## 2026-09-18 V3 architecture

- `LogASipV3ProductionView` remains the visible coordinator for Cafe, Home, and
  Elsewhere. `HomeRecipeExperienceView` remains the Journal library/history
  destination and is no longer the default central Home handoff.
- A Home coordinator state in the durable Sip draft owns guided/quick path,
  setup, current phase, preparation session, private attempt, and the stable
  publication-draft link. The numbered path is Setup 1/4, Capture 2/4,
  Reflection 3/4, Saved 4/4; adaptive Make is unnumbered.
- `HomeBrewMethod` is an additive string-backed method registry with safe unknown
  decoding, preserved aliases, custom method names, method families, default
  values, criteria suggestions, and original Canvas-drawn vector identities.
- `HomeRecipeTemplate.preparation` serves coffee, matcha, hojicha, tea,
  components, complete drinks, and custom work. Legacy `.coffee` records remain
  readable and are not rewritten.
- Home attempts preserve frozen targets, independently optional actuals,
  custom-field values, manual/displayed score evidence, criteria, importance,
  sensory selections, private note, make-again intent, and next-time note.
- A private attempt and its media are account-scoped and durable before Saved or
  Review is shown. Async save work is fenced to the originating account.
- Sharing adapts that saved attempt into the standard production Review Mugshot
  flow with a stable publication draft. General brew details exclude recipe
  instructions; only an explicit exact-version Full details attachment can
  expose them after rights/audience confirmation.
- `MugshotRoadmap.homeSipV3Route.v1` is independent from the existing Home
  Recipes flag. An explicit stored false restores the previous central route
  without deleting V3 recipes, attempts, sessions, drafts, or media.

## 2026-09-17 repair architecture

- `HomeRecipeExperienceView` is the Home coordinator. It accepts explicit
  initial recipe, preparation, and attempt identities plus an explicit host exit
  callback. The generic Sip composer becomes an adapter only after a private
  Home attempt enters sharing.
- Attempt drafts support keep/discard behavior. Discard removes the selected
  unfinished make, its unfinished sessions, reminders, and only media that no
  remaining record references. Empty template and attempt envelopes are hidden
  or removed rather than presented as resumable work.
- Preparation sessions decode older records conservatively and add optional
  `phase` and `preparationCompletedAt` fields. Preparing, awaiting reflection,
  and saved are distinct; optional fields preserve wire compatibility with
  existing account workspaces.
- Attempts add optional publication status alongside the existing publication
  draft identifier. Publication state is private workspace metadata and does not
  widen the public post projection.
- Frequent editor changes are debounced while navigation/save boundaries flush
  synchronously. Image decoding and resizing move off the main actor. The
  account-scoped atomic workspace remains the durable source of truth.
- Missing referenced media is an explicit retryable synchronization/share error.
  Remote conflict recovery can refetch the canonical workspace when the first
  conflict fetch fails instead of trapping the account behind an unusable action.
- These additions live in the existing workspace JSON payload and require no
  Supabase migration. Production remains aligned through
  `20260916020417_home_recipe_http_conflicts.sql`.

## Product behavior

### Home and daily logging

- Journal > Home retains independent My makes and Recipes collection state,
  surfaces active batches and interrupted drafts first, and provides usuals,
  recent makes, Earlier entries, intentional empty states, and the full library.
- Central Add > Log a Sip > Home opens setup-first inside the existing composer.
  A visible quick-log shortcut needs only Capture and Reflection. Neither route
  requires a recipe, rating, photo, measurement, or guided preparation, and
  selecting a recipe never forces guidance.
- Saving always opens the real private attempt. Make again, Save as recipe, Share,
  favorite-result, batch-serving, history, comparison, and next-time-note actions
  operate on that saved attempt rather than a transient example.
- Repeating retains the selected recipe version and targets while clearing old
  actuals, photos, ratings, and reflections. A historical variation can be chosen
  explicitly. Unchanged makes create no recipe version; Update my recipe appends
  an immutable version and Just this time remains the default.

### One flexible recipe system

- Preparation, Component, Complete drink, and Blank are starting templates,
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
- AeroPress, French press, immersion, moka pot, batch, siphon, Turkish/ibrik,
  Vietnamese phin, pods, flash brew, percolator, boiled coffee, instant, matcha,
  hojicha, western/gongfu/cold/iced tea, chai, milk/foam, syrup/sauce, tonic,
  blended/frozen, complete drinks, and unknown methods receive sensible editable
  starting fields. Quantities scale by multiplier,
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
- A private attempt is saved before Review Mugshot opens. Review uses the
  attempt's real media, supports Friends or Everyone, previews the post payload,
  and preserves its draft on failure.
- Recipe attachments are explicit, version-specific, audience-checked, retry-safe,
  and non-recursive. A parent never publishes linked component instructions.
  Private notes, next-time notes, inventory, and private media paths are excluded.
  Component-only and photo-free posts are supported. Unrated private results
  remain complete but must satisfy the standard score requirement before posting.

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

### 2026-09-18 Home Sip V3 evidence

- The generic Debug app, unit-test target, and UI-test target build for the iOS
  Simulator SDK. The focused Home workspace suite then passed 30 of 30 tests on
  a clean iPhone 17 Pro Simulator running iOS 27.0.
- Added focused coverage for the data-preserving V3 route flag, expanded method
  catalog, custom method/field identity, additive round trips, and unknown actuals.
- Added central-entry UI coverage that asserts Home opens setup-first inside the
  composer rather than the retired **What did you make?** route. That journey
  passed on iOS 27.0.
- The two-surface Quick Log journey passed Capture 1 of 2, shared Reflection 2
  of 2, and an unrated, photo-free private save on iOS 27.0. Direct Setup and
  Quick Log rendering was also inspected on that runtime.
- Xcode 26.2's XCTest keyboard bridge stalled while driving iOS 27 text input.
  The UI test uses a DEBUG-only deterministic launch value to exercise the
  production save journey without altering release behavior. This is recorded
  as a test-tooling limitation, not an application fallback to iOS 26.3.
- The repository full-static gate passed 13 required checks with zero failures,
  including generic app/test/UI compilation, cached Deno tests, and the complete
  hermetic Home authorization, conflict, privacy, and retry contract set.

### 2026-09-17 repair evidence

- `scripts/verify-no-simulator.sh full-static` passed all 12 required checks
  with zero failures. The optional local `pglast` parser was unavailable and
  skipped; repository migration timestamp validation still passed.
- The generic Debug app, app-unit target, and UI-test target compiled without
  booting or launching Simulator. The 28 focused Home workspace tests include
  new fixtures for calculation switching, method defaults, preparation phases,
  protected-source readiness, draft/media discard, and publication linkage.
- Cached Deno tests and every hermetic PostgreSQL behavior/security contract
  passed, including Home owner isolation, immutable versions, CAS conflicts,
  linked privacy/cycles, source rights, projection policy, and protected Storage.
- Documentation validation and diff integrity passed. No migration or remote
  deployment was required or performed.
- Per the owner’s no-Simulator instruction, executable iOS tests and connected
  journeys were compiled but not run. Navigation dismissal, camera/system UI,
  background timer recovery, Dynamic Type, VoiceOver, and publication retry
  remain queued for the consolidated runtime gate; no physical or TestFlight
  acceptance is claimed.

### Earlier implementation evidence

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

Home Sip V3 is present in source and defaults on behind its independent,
data-preserving route flag. The remaining gates are:

1. Complete the remaining broad iOS 27 journeys for guided preparation, relaunch,
   account switching, media, publication retry, Dynamic Type, VoiceOver, and
   Reduce Motion. Focused workspace, central setup, and quick private-save
   acceptance already pass on iOS 27.0.
2. Promote the same candidate to a connected iPhone only after the owner requests
   hardware acceptance. The current task does not claim physical acceptance.
3. Treat any later TestFlight archive/upload as a new explicit release gate with
   its own build number, candidate evidence, and What to Test handoff.
