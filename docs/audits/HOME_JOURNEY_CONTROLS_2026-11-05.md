---
document_type: historical
status: implemented-physically-accepted
---

# Home journey, Journal parity and controls audit

> Current behavior: [Home implementation](../HOME_RECIPES_IMPLEMENTATION.md#home-journal-and-flow-controls--november-5-candidate).
> Baseline findings below remain historical; the follow-up entries record implementation and acceptance.

Audit baseline: `7775365`, `codex/home-library-flow`, November 5, 2026.
This follows the owner's request to audit, plan, then implement. No owner record
is a deletion fixture. Existing PR #109/#108, Home V4 deployment and TestFlight
holds remain. This is separate from the earlier completed recipe-focus update.

Documentation impact: product behavior, local data ownership/reconciliation,
permissions/privacy and development-device delivery. Existing owner-only workspace,
post deletion and library contracts will be reused; no production migration,
Luna/model change, additional analytics or paid hosted QA is planned.

## Confirmed findings

1. **Journal parity:** published entries use `RemoteJournalRow` (92 × 96 image,
   context icon/date, place, drink and score). Private Home entries duplicate a
   different 56 × 56 card; archive uses another 50 × 54 card and a separate Home
   section. Private Home rows therefore cannot inherit normal Journal polish.
2. **Identity:** private detail hardcodes Home. A saved attempt has no location
   snapshot and no saved named Home-profile model exists. Published posts already
   support `locationName`. Historical records cannot reveal an unrecorded profile.
3. **Saved sip deletion:** canonical posts have an owner deletion service and
   confirmation sheet. `HomeAttemptCanonicalDetailView` has no Delete action;
   the workspace has draft discard but no saved-attempt delete operation.
4. **Deletion consistency:** workspace reconciliation unions attempts/drafts/
   sessions. Removing an item without durable deletion markers can restore it
   after an offline conflict. A deleted published Home sip also needs its linked
   private attempt removed so it cannot return as a separate Journal entry.
5. **Unfinished work:** sip drafts, recipe drafts, private attempt drafts and
   preparation sessions have different resume surfaces. Setup expands every active
   session under Continue. Recipe Book lists named drink drafts only. Some resume
   pickers have no deletion action; Journal deletes a sip draft immediately.
6. **Screen design:** four Home surfaces still use full-page `Form`: advanced
   recipe editing, legacy make/reflection, legacy sharing and gear editing.
   The newer capture/builder/guidance/actuals/rating/review screens already use
   Mugshot's native canvas; retain their useful controls and common finish.
7. **Progress:** quick and guided paths are distinct, but several primary buttons
   say Continue without explaining the destination. Actual measurements are
   optional yet their page lacks an explicit Skip action. Preserve meaningful
   preparation/photo/reflection/review stages; make optional depth expandable.

## Surface and control inventory

| Surface | Normal controls and ownership | Audit decision |
| --- | --- | --- |
| Journal recent and archive | Open, date/filter/search, place identity, thumbnail, score | One shared card for cafe/Home/Elsewhere; merge chronology |
| Journal calendar/map | Date selection, empty state, location privacy | Include Home date records; never create a private-home map coordinate |
| Saved Home detail | Photos, make again, share, history, delete, cancellation/errors | Add confirmed owner-only Delete; preserve recipes/other servings |
| Published Home detail | Existing owner edit/delete/share/report distinction | Keep server authorization; clean linked owner memory after confirmed deletion |
| Sip draft list | Resume latest state, discard confirmation, cancel | Show all drafts; recovery-locked submissions use existing recovery path |
| Home unfinished work | Session/attempt/recipe identity, resume, discard | One compact Drafts entry; complete categorized management and deduplication |
| Context/setup | Context switch, drink/method, optional recipe, Home profile, back/close | Retain canvas; name the next action and show chosen profile |
| Named Home profiles | Add/edit/default/remove, profile-specific gear, validation | Local account-scoped nicknames; no address/GPS; immutable sip-name snapshot |
| Recipe discovery | Search chosen site, source credit, return/add, cancel | Retain source-first design and access fallbacks |
| Recipe capture | Link/text/image/video, permission denial, retry, edit, Save | Retain current extractor and non-AI path |
| Recipe editor | Identity, source, ingredients/steps/order/delete, methods, Save/close | Replace generic Form with composed editable cards; retain every control |
| Drink builder | Base/components/amounts, inspect source, reorder/remove, save draft | Retain accepted canvas and immutable references |
| Guidance | Step/back, timer, optional notifications, resume/discard, finish | Keep finite user-driven guidance; no mandatory permission/measurement |
| Actuals | Optional values, unknown/as-planned, units, back/skip/next | Explicit Skip; no fabricated values; clearer destination copy |
| Photo capture | Camera/library/placeholder/remove/cover, denial, back/next | Preserve optional private capture and existing public-post validation |
| Sip reflection | Rating, criteria, notes, sensory helper, setup edit, review | Same common finish; keep private notes separate |
| Publish review | Photo/caption/audience/recipe permissions, retry, Save/Post | Preserve explicit audience and protected-source boundaries |
| Celebration/share | Done, Share/Back, Story/Post/Style, See post, errors | Reuse the newly accepted full-screen flow |
| Beans | Manual/scan, permission/error fallback, edit/archive/restore | Retain canvas and optional Luna; no provider change |
| Gear | Add/edit/role/archive, cancel/save, identity flush | Replace Form with visual role/identity cards |
| Preferences | Method/bag/gear defaults, Luna revoke, saved profiles | Add Home profiles; retain account fences and device-local scope |
| Legacy make/share routes | Existing fields, photos/reflection, explicit rights | Replace remaining Form shells; retain reachable functionality |

## Safety and acceptance requirements

- No automatic deletion/migration/cleanup of existing owner content. Test only
  isolated fixture stores/apps; owner phone inspection is read-only.
- Delete a draft only after confirmation. An active/recoverable publication is
  not an ordinary draft; route it to its protected recovery controls.
- Deletion is idempotent, survives relaunch/conflict and cannot erase another
  account, a saved source recipe, shared media or an independent batch serving.
- A failed server deletion leaves the private Home memory intact. Confirmed
  remote deletion records an account-bound cleanup receipt for later local sync.
- Home profile names are nicknames shown in review, not addresses. Keep private
  profile IDs/gear inventory out of public projections; no geolocation request.
- Named profiles are optional. Old records show Home; never invent history.
- Cancel/back, validation, error/retry and 44-point targets remain accessible.
  Large text, Reduce Motion, empty states and denied optional permissions work.
- Core creation, composition, saving, deletion and Journal remain independent
  of AI. Preserve immutable recipe versions and explicit post/recipe audiences.

## Implementation and verification

The ordered [code action plan](../plans/home-flow-controls-2026-11-05.plan.md)
maps each finding to implementation and focused ECC RED/GREEN evidence. Native
captures, final acceptance and remaining limits will be appended here after work.

### ECC RED checkpoint

Focused `HomeJourneyControlTests` intentionally targets missing private-sip delete,
scope-aware draft discard, conflict deletion markers, profile identity, complete
draft indexing and Journal projection behavior. The isolated Debug build reaches
the tests and fails on those missing APIs (`locationName`, `HomeJournalProjection`,
`deleteAttempt` and related controls); this is an intended behavior/API RED, not
the owner diagnostics-module limitation. Receipt:
`/tmp/mugshot-home-controls-red-2026-11-05.log`. No owner mutation was used.

The first GREEN batch passes 68 native cases across Home controls, workspace and
library suites (`/tmp/mugshot-home-controls-core-green1-2026-11-05.xcresult`).
The ordinary sip-draft discard API then has its own intended-API RED in
`/tmp/mugshot-sip-draft-controls-red-2026-11-05.log`; existing APIs do not yet
provide a throwing, protected-outbox-aware discard and durable stale-save guard.

### Additional audit finding: compatibility and cover identity

The private workspace JSON is opaque to the server. An older client can omit
new deletion fields on a later save; server-side retention is therefore required
to keep confirmed deletions from being reintroduced by those clients. The action
plan now includes an additive, owner-only deletion-normalization trigger and
hermetic/disposable contracts. This changes the initial no-migration assumption;
no live database change is authorized as routine verification.

Private Home saving also serializes photo order without honoring the selected
cover. The implementation will retain all photos in stable selected-cover-first
order, matching the existing published sip behavior. Legacy make/reflection also
keeps its current surface only in view state; an optional resume marker will make
relaunch return to the user's last surface.

The hermetic Postgres recipe suite reproduces the server gap: after a deletion
marker is submitted, the saved attempt remains present. The assertion fails on
the old schema (`/tmp/mugshot-home-workspace-deletion-red-2026-11-05.log`). The
new tests also require old-client saves to retain markers, remove associated
unfinished sessions, preserve recipes/servings and reject malformed markers
without advancing the revision.

### Additional audit finding: embedded library handoffs

A gear library opened inside the drink builder inherited all library tabs, but
had no route back to the main sip composer. Switching to Recipes and choosing
Make could therefore dismiss into an empty callback. Root libraries now retain
all sections and the shared draft manager; recipe-selection sheets retain recipe
selection without offering an unrelated draft manager; gear-only sheets stay on
their requested section. This is implemented in source and still requires the
consolidated native verification recorded by the delivery owner.

Named Home selection uses the recorded nickname. Generic `Home` is therefore a
reserved nickname, and same-account names must be unique ignoring case and outer
whitespace. Model/store validation now enforces those boundaries as well as the
editor, so a later write cannot make profile gear selection ambiguous. Focused
`HomePlaceProfileControlTests` cover the reserved name, duplicate rejection and
same-identity rename.

### Integration and failure checks — November 5 follow-up

The first combined native batch passes **100 cases** (99 named tests plus one
additional parameterized case) across controls, deletion boundaries, Journal
history, profiles/adoption, sip discard, editors, workspace and library suites.
Receipt: `/tmp/mugshot-home-controls-native-green2-2026-11-05.xcresult`. Later
review fixes still require their final native pass. Generic and integration
compile errors were corrected as tooling/integration findings, not behavior REDs.

The first screen walkthrough reproduces missing explicit cancel controls in
iOS 27 confirmation popovers for drafts and Home setups. Shared scrollable
confirmation sheets replace those popovers. It also identifies extended remote
thumbnail accessibility frames and editor-field/SwiftUI menu automation issues;
fixes and focused reruns are in progress. Receipt:
`/tmp/mugshot-home-controls-ui1-2026-11-05.xcresult`.

Security/state review adds valid-name-only local cleanup, consumed edit-ID markers,
dependent edit-ID retention, preserved batch links, safe guest nickname collision
handling, abandoned photo-write cleanup, and fresh photo identities when a retired
file gains a new reference. The server rejects newly referenced retired names,
while photos already shared by retained makes stay valid.

The owner approved a new temporary **data-less** Supabase branch at
$0.01344/hour. Branch `c27a4159-dafe-4709-b53b-314c58e11d4f` /
`cwathktlaqheiqpsdzos` replays all **186 local migrations**, including the held
Home V4 migration only inside QA. All **68 hosted SQL contracts** pass with
zero migration drift; real Auth/Data API and Storage probes verify owner save,
foreign denial, uppercase markers, dependent edit cleanup, stale-client retries,
failed writes and idempotent private-object deletion. Synthetic probe accounts
were removed. The live project remains at 184 migrations; the exact production
release must exclude held Home V4. The paid branch must be deleted after QA.

UI1 completed 16 cases: 7 passed and 9 failed. Two failures reproduce missing
cancel actions; one reproduces a mismatched thumbnail accessibility frame.
Menu-item duplicates, a text field under the fixed Save bar, covered-root filter
queries and a measurement-sheet action identifier require targeted native/harness
corrections; assertions remain. The regular quick-log path must be included by
its exact test name in the next run (the first command requested an absent name).

The follow-up native/UI batch confirms visible cancel controls, largest-text
delete cancellation, edit-save identity/date preservation, edit keep/resume/
discard, recipe amount125/reorder/remove/save, archive filtering, scope changes
and the quick private-save path. One large-text scroll helper overshoots targets,
and a Journal label assertion queries a separate static label instead of its
combined VoiceOver control. Both are being corrected without removing the
geometry/content checks. A media-race regression also exposes an unnecessary
extra acknowledgment caused by changing absent optional sets into empty sets;
union now preserves absence. Current receipt:
`/tmp/mugshot-home-controls-green3-2026-11-05.xcresult`.

All 68 hosted contracts and real Auth/Storage probes completed, and the approved
paid QA branch was deleted; branch inventory confirms only main remains. The
reviewed live dry run contains only
`20261105183000_home_workspace_deletion_controls.sql`, excluding held Home V4.
A fresh 40-file Application Support backup and Preferences backup are protected
locally before phone installation. No owner deletion was performed.

### Native GREEN checkpoint

The final focused batch passes **106 native tests** in eight suites plus both
corrected UI cases, with zero failures:
`/tmp/mugshot-home-controls-green4-2026-11-05.xcresult`. Combined with the 15
unchanged passing UI3 cases, all **17 selected Home/Journal UI paths** pass.
The largest-text helper now uses controlled short drags instead of overshooting
flicks; Journal assertions verify combined VoiceOver labels as well as identical
actual 92 × 96 thumbnail frames. Both regular input125/reorder/remove/save and
large-text instruction controls are verified.

Extra focused boundaries cover completed edit replay/late autosave, source
deletion with older-client field omission, batch linkage, hostile filenames,
abandoned writes after discard/account change, shared-media deletion races and
conflict recovery with fresh media identity. Sharing-draft resolution never
overwrites a draft converted to another context. These paths use no AI.

[Native review captures](../design/home-flow-controls-2026-11-05/README.md) are
fictional fixtures. Signed owner and isolated phone builds are separate; physical
acceptance and live deployment remain pending at this checkpoint.

### Production guard and owner installation

The completed November 5 physical backup preceded the exact 185-file live
release. Only `20261105183000_home_workspace_deletion_controls.sql` was applied;
live history is 185, held Home V4 remains absent, the trigger is enabled, and
neither client role can execute the private helpers. Fresh before/after counts
and whole-row fingerprints match across all 75 protected tables. The capability
RPC is readable and security-advisor counts are unchanged (no new deletion-helper
finding). The exact release log is
`/tmp/mugshot-home-controls-live-deploy-2026-11-05.log`.

The signed Mugshot Luna QA 0.5.3 (8), `co.mugshot.app.dev`, is installed on the
owner iPhone. All 40 pre-install Application Support files remain byte-identical.
A launch attempt times out while iOS reports passcode-required; a physical unlock
request is pending, and the isolated hardware runner is ready. The app signature,
entitlements and real-key exclusion pass; its analytics remains disabled. The
separate fixture package targets invalid backend, no owner groups/URL schemes/
embedded extensions, and has a verified development signature. No owner deletion
or TestFlight action was performed.

### Physical acceptance and preservation — final November 5 gate

Mugshot Luna QA **0.5.3 (8)** is installed and launched on iPhone 16 Pro /
iOS 27.0.1 with its existing development/sandbox signing and unchanged
entitlements. All **106 native tests** pass on hardware. The standard UI-target
launch configuration returned CoreDevice10004; the documented installed-artifact
configuration resolves the launch and retains every functional assertion. Optional
UI-target launch diagnostics are off in that test configuration only. No new app
crash report appears and direct launches succeed.

All **18 distinct fixture screen paths** pass: Journal geometry/metadata, calendar/
filters/scope, complete draft resume/delete/cancel, profile add/remove-cancel,
recipe ingredient125/reorder/remove/save, large-text instruction/confirmation
controls, gear, legacy capture/share, saved-sip edit/save/keep/resume/discard,
confirmed private deletion preserving its recipe, and guided/quick private saves.
A system notification covered the Home-profile Save control in the first combined
run; the isolated unchanged test then passes. No owner content is the delete fixture.

Receipts:

- 106 hardware native tests: `/tmp/mugshot-home-controls-phone-2026-11-05.xcresult`
  (its UI-launch failures are tooling evidence, not passing screen acceptance).
- Journal geometry/metadata: `/tmp/mugshot-home-controls-phone-installed-smoke-2026-11-05.xcresult`
  — 1/1 passes.
- Remaining hardware matrix: `/tmp/mugshot-home-controls-phone-ui-final-2026-11-05.xcresult`
  — 16/17 pass; the notification-interrupted profile case passes 1/1 in
  `/tmp/mugshot-home-controls-phone-profile-retry-2026-11-05.xcresult`.
- Separate owner read-only existing-recipe acceptance:
  `/tmp/mugshot-home-controls-owner-readonly-2026-11-05.xcresult` — 1/1 passes.
- Confirmed private-delete Simulator path:
  `/tmp/mugshot-home-controls-delete-ui-2026-11-05.xcresult` — 1/1 passes, bringing
  cumulative selected Simulator coverage to all 18 paths.

All 40 original Application Support files remain byte-identical through install
and normal launch. After owner read-only acceptance, all 40 remain present; the
complete recipe workspace and every owner content field are unchanged. One shelf
file changes only its updatedAt timestamp. The final preservation receipt is
`/tmp/mugshot-home-controls-owner-final-preservation-2026-11-05.json`. The paid
QA branch, isolated fixture app and both task-specific test runners are deleted;
normal Mugshot, Mugshot Luna QA and unrelated Motion QA remain. TestFlight, held
Home V4 and draft-stack merge holds remain.

Focused coverage is collected, not app-wide: Home controls94.7%, profiles95.2%,
editor canvas96.5% in the final focused batch; broader legacy workspace/store
coverage is reported separately in the xcresult archives. [Native captures](../design/home-flow-controls-2026-11-05/README.md).
