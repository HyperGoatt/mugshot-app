---
document_type: historical
status: simulator-verified-phone-journal-verified
---

# Journal crash and Home bean access — 2026-11-04

Current sources: [product status](../CURRENT_PRODUCT_STATUS.md),
[Home behavior](../HOME_RECIPES_IMPLEMENTATION.md),
[optional assistance](../AI_ASSISTANCE.md).

## Confirmed failures and ECC RED

The owner reported Journal terminating the installed Mugshot Luna QA 0.5.3 (8).
Three physical crash reports were present. The latest, 11:37:26, identifies
`EXC_BAD_ACCESS / SIGSEGV`, `Thread stack size exceeded`, and
`___chkstk_darwin → JournalTabView.journalBody` while constructing navigation
presentations. This is native view construction before an AI request, rather
than provider failure. Raw crash reports and account screenshots remain private
under `/tmp`; only non-content diagnostic facts are recorded here.

The current V4 Home setup could select saved beans, but had no first-bag add or
scan control. Those controls existed only in the old workbench. The focused
Simulator RED stopped at the missing manual button. The initial Journal test
also failed because its accessibility selector expected an exact label instead
of the combined button label; that test error is not claimed as a Simulator
reproduction of the physical stack crash. Journal rendered on Simulator.

RED checkpoint: `915cda8`. Result bundle:
`/tmp/mugshot-journal-beans-red.xcresult` (two failed journeys, with the distinction
above). Physical crash report: `/tmp/mugshot-journal-113726.ips`.

## Minimal correction and boundaries

- Extract Journal's scroll content and introduce one stable `AnyView` boundary
  before navigation/presentation modifiers. Existing destinations, task lifetime,
  account clearing, archive, reflection and profile bindings remain intact.
- Reuse the existing bag editor and account-scoped shelf from current setup.
  Selection/clearing updates the draft's bag ID and safe coffee snapshot together;
  accepting a bag does not modify a saved recipe. Guest manual entry stays local.
- The picker checks the active account before loading/selecting and clears its
  presented editor on an account change. The editor disables save and dismisses
  for a changed account; late on-device scan proposals cannot be applied for that
  changed account. Safe snapshots exclude inventory, private photos and owner ID.
- No backend, model, key, consent, analytics or TestFlight behavior changes.

## Verification and phone state

**Final result: 15/15 focused native unit tests and 2/2 distinct UI journeys
pass, with physical Journal opening verified.** Unchanged passing evidence is
reused rather than repeating successful cases after test-selector corrections.
No app-wide coverage percentage is claimed for this presentation fix.

| Check | Result and evidence |
| --- | --- |
| HomeWorkbenchTests | 15/15 pass in `/tmp/mugshot-journal-beans-green.xcresult` |
| Journal open → Feed → Journal | 1/1 pass in `/tmp/mugshot-journal-beans-green3.xcresult` |
| Current Home beans | 1/1 pass in `/tmp/mugshot-journal-beans-green4.xcresult`: manual save, selected snapshot, scan cancel, None, saved-bag reselection |
| Compile/types | Simulator app/test bundles and signed physical Debug build pass |
| Repository static checks | `./scripts/verify-no-simulator.sh fast`: 7/7 pass |
| Documentation/format | `./scripts/check-documentation.sh` and `git diff --check` pass |
| Security/state review | Fixed draft scope, active-owner guards, safe snapshots, explicit save/consent, unchanged server contracts; actual key absent from changed files and installed package |
| Hardware | Authenticated Journal renders; all 55 prior app-support files unchanged; no new crash report |


The first corrected-source batch passed all **15 HomeWorkbenchTests** (bag
ownership/safe snapshots, local persistence, adoption/photo copying, scan parser,
merge and draft relationships). Both UI cases failed at later navigation checks.
The bean fixture contained a local sample account but no authenticated session;
the new owner guard correctly disabled its editor. The journey now explicitly
uses guest mode, with no production backend or analytics. The unrelated
Recipe Book return assertion was removed from this focused Journal tab check;
it is not claimed as passed. The final Journal journey checks initial rendering,
Feed return and reopening the tab. Physical installation and Journal opening
now pass (details below).

The follow-up UI run passed Journal opening/Feed return/reopening. Bean manual
save, selected label, scan cancellation and clearing passed before its final
menu-reselection lookup failed. The next focused capture confirms the menu's
actual label is **Morning Beans** (`CoffeeBag.displayName`), while the selected
snapshot label includes the roaster too. The test had incorrectly assumed these
two labels were identical. Its lookup is corrected to the observed menu label;
no product selection behavior was changed to satisfy that assertion.
Xcode's post-failure diagnostic collection then stalled after both cases had
finished. Its test stdout was preserved at
`/tmp/mugshot-journal-beans-green2-ui.log`; only diagnostic collection was stopped.
The final bounded rerun disables that broad collection and passes bean
reselection. The earlier tooling event is not classified as an app crash.

Existing provider/backend evidence is reused; this fix makes no backend change.
The correction remains on `codex/luna-assistance` / draft PR #108. Existing
parent acceptance holds prevent merging the stack; no TestFlight gate is promoted.

### Physical Journal acceptance

The signed replacement **Mugshot Luna QA 0.5.3 (8)** is installed on the owner's
iPhone 16 Pro / iOS 27.0.1 as the same `co.mugshot.app.dev`. Native compile,
strict/deep signatures, unchanged entitlements, disabled analytics and exclusion
of the actual OpenAI key pass. All **55** pre-install Application Support files
match byte-for-byte immediately after installation and before launch.

Initial launch was blocked by the locked screen. After the owner unlocked it,
the normal app restored its authenticated Feed. A warm `mugshot://journal` route
then selected the real Journal tab and rendered the owner's existing entries
and drafts; the private screenshot at
`/tmp/mugshot-journal-phone-warm-fixed.png` confirms the selected Journal tab.
The same tab selection constructs `JournalTabView` as a tab tap. This establishes
physical Journal opening, not physical touch-navigation or all destination
acceptance. A subsequent crash-log inventory contains only the same three older
reports, now under Retired; no new Mugshot crash appeared. No synthetic production
content, AI request, migration or TestFlight action was created.
[Sanitized package and preservation receipt](journal-beans-2026-11-04/phone-receipt.json).

## Human QA

1. Open Journal, return to Feed, then open Journal again. Open Recipe Book and
   return; open Archive and return. The app should remain responsive.
2. Add → Home → method → Adjust today’s setup → Beans, gear, and more.
   Add manually, enter a roaster or coffee name and Save. The bag should be
   selected immediately. Choose None, then select the saved bag again.
3. Open Scan bag and Cancel; the selected bag should stay unchanged. A real bag
   photo should populate editable printed details through on-device scanning.
   Check all fields, especially dates. Saving remains an explicit action.
4. Optional Luna: choose a photo, open Improve this scan, review the disclosed
   image/data and consent only if desired. Check and accept proposed fields;
   canceling or network failure must leave manual entry and Save available.
