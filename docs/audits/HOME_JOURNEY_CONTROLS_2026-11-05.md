---
document_type: historical
status: audit-complete-implementation-pending
---

# Home journey, Journal parity and controls audit

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
