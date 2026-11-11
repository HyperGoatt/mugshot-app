# Mugshot Home from recipe to sip

Base candidate: `1bd91ee`, stacked on the cafe and Pocket Sip candidate.

## Goal

Make a Home sip start with the drink someone is making, use their existing
recipes and parts, and finish with a private Journal save. Preserve the guided
make, the separate sharing decision, and the recipe history that supports a
repeat brew.

## Acceptance

1. **Start with the drink.** Add → Home presents What are you making?, one
   search-or-name field, up to two recently made drinks, and Save a recipe.
   A named drink can proceed directly to rating. A selected saved drink carries
   its exact recipe reference, plan, and display name.
2. **Choose how to proceed once.** A selected drink previews base, milk, and
   add-ins with known amounts. Change for this brew edits the current plan.
   Follow steps and the saved recipe's Make this begin at instruction one.
   Log a make opens the prefilled rating screen.
3. **Finish a private sip at rating.** Stars, photos, and notes remain optional.
   Save privately commits one scoped Journal entry and reports success only
   after it is durable. Share sip opens the separate audience and recipe
   attachment review from the saved entry.
4. **Review imported evidence.** After import, collapse source controls,
   surface the extracted recipe and first missing input, and preserve typed
   corrections through retries. An incomplete idea can Save for later.
   A usable recipe can Save recipe or Save & make.
5. **Choose the destination in the Mugshot iOS share extension.** A link or
   text can become a recipe or a place. Images can become recipe evidence or
   Pocket Sip photos. Save a bounded, private handoff, show Continue recipe in
   Home, and verify ownership, retry, acknowledgement, and replay.
6. **Find recipes by use.** Saved → Home library has Whole drinks, Add-ins, and
   Brew recipes filters with search and archive recovery. Build a drink belongs
   with whole drinks, Use in a drink with add-ins, and method choices with brew
   recipes and the base selector.
7. **Make edit scope explicit.** Use for this brew affects the current sip.
   Save changes to recipe keeps version history. Save as new recipe creates a
   distinct copy. Remove from this drink and Archive add-in act on different
   objects. Used in shows the drinks and versions that use an add-in.
8. **Keep capture reachable at the largest text size.** Reserve real layout
   space for the Save footer. Verify every kind card and the footer at
   accessibility XXXL, including when dismissing the keyboard.

## Implementation order

- [x] Trace existing Home navigation, exact recipe snapshots, private saving,
      library editing, and the shared app container. Capture the RED evidence
      and pin the regression checks.
- [x] Build the Home entry, recipe parts preview, direct make/rating routes,
      and the private save action with the existing theme and controls.
- [x] Wire source review and Save & make. Put the footer in the scroll layout.
- [x] Add the scoped recipe share handoff and recovery. Verify place sharing
      and Pocket Sip through their normal routes.
- [x] Add library use filters, one-brew changes, explicit version and duplicate
      actions, and Used in.
- [x] Run focused Swift tests and native journeys on disposable Simulators.
      Inspect and retain screenshots at normal and largest text sizes.
- [x] Update living documents with actual evidence. Check the full diff and
      publish the branch for review against the cafe candidate.

## Verification and evidence

- Use the existing November 10 largest-text capture failure as runtime RED.
  Run focused regressions for the new normal routes and for private save,
  repeat recipe selection, archived and old linked versions, duplicate names,
  part removal, and source retries.
- Share tests cover both content classes, wrong account, stale session,
  rejected inputs, interrupted transfer, duplicate import, and the existing
  cafe and Pocket Sip routes. Use fictional inputs and disable analytics and
  the linked Supabase client in Simulator fixtures.
- Capture the named quick sip and saved-recipe path through the private Journal
  receipt, guided step one and finish, source intake and import review, native
  share destination and reopen, library filters, version/part edit scope, and
  the fully revealed largest-text kind controls and footer. Use real app
  screenshots and keep physical and TestFlight acceptance separate.
- Run `./scripts/check-documentation.sh`, `git diff --check`, applicable
  repository static checks, and the focused Simulator suites. Record what
  passed and what remains outside the observed environment.

## Documentation impact

Product behavior, SwiftUI state and navigation, account-scoped local data,
photo and text handoff, and recipe privacy all change. Update the changelog,
Home implementation, product status, feature status, sprint, data flow, and
sharing guidance. Review the submission data inventory against the final
behavior. The candidate uses the existing release version and backend
contracts.

## Verified candidate

- The old Home entry failed the new name-to-private-save regression. The
  revised candidate passed that journey and reopened an unrated private sip
  from Journal after a cold launch with an offline signed-in fixture.
- 89 focused Swift tests and 35 native journeys passed across the broad run
  and targeted reruns on iPhone 17 Pro Simulator with iOS 27.0. The journeys
  include Save & make, component and version scope, archived links, Map and
  Saved cafe regression checks, and accessibility XXXL with the keyboard open.
- Native Photos sharing saved and reopened a recipe screenshot and a Pocket
  Sip draft. Add saved and reopened two Pocket Sip photos. Safari opened the
  cafe lookup and preserved the exact shared website URL in Home.
- The generic Simulator build, documentation validation, and static checks
  passed. This source candidate is stacked on the cafe branch for review.
  Physical-device acceptance and TestFlight are separate release gates.
