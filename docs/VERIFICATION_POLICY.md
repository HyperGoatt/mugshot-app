# Mugshot Development Verification Policy

This policy keeps verification proportional to risk. The default is the lightest check that can credibly catch regressions from the change being made.

## Operating rules

1. Classify the change before testing.
2. Run the minimum tier that covers its real blast radius.
3. Build or test once after the implementation is coherent, not after every small edit.
4. Stop when the required evidence passes.
5. Escalate only when a failure, uncertainty, or wider dependency justifies it.
6. Do not duplicate the same evidence with both shell `xcodebuild` and XcodeBuildMCP.
7. User-requested validation always takes precedence.

## Tier 0 — inspection only

Use for:

- Documentation and comments
- Non-product metadata
- Test descriptions with no executable change

Required:

- Review the scoped diff.
- Run formatting or `git diff --check` only when relevant.

Do not:

- Build the app.
- Launch Simulator.
- Run tests.

Expected time: under one minute.

## Tier 1 — fast compile check

This is the default for small, isolated UI polish.

Use for:

- Copy changes
- Spacing, padding, color, typography, corner radius, or icon changes
- A local visibility or disclosure tweak using existing state
- Small animation timing or transition changes
- Preview or fixture-only changes
- A contained SwiftUI refactor with unchanged data flow

Required:

- Review the scoped diff.
- Run one Debug compile check for the affected app target.
- If the compiler cannot exercise the changed path, run the smallest relevant static or unit check instead.

Do not routinely:

- Build and launch Simulator.
- Create or mutate app data.
- Run UI tests or an end-to-end flow.
- Capture screenshots or produce a design-QA board.
- Run the complete unit-test suite.
- Build Release.

Expected time: three minutes or less.

Example: changing Taste snapshot so criteria appear only after `View breakdown` is Tier 1. A compile check is sufficient; a single focused interaction test is optional only if the state transition itself is uncertain.

## Tier 2 — focused behavior check

Use for:

- New or changed local interaction logic
- Bindings, validation, capability mapping, or presentation adapters
- A component-level state machine
- A bug fix with a deterministic reproduction
- Local persistence behavior confined to one feature

Required:

- Run one Debug compile check.
- Run the smallest directly relevant unit test or focused UI test.
- Launch Simulator only when the behavior cannot be credibly exercised by the focused test or static evidence.

Do not routinely:

- Run unrelated test targets.
- Recreate an entire user journey when a component or unit test covers the behavior.
- Build Release.

Expected time: roughly three to ten minutes.

## Tier 3 — feature integration check

Use for:

- Navigation or presentation changes spanning screens
- Feed, Saved, Journal, Map, profile, or composer entry-point migrations
- Persistence across relaunch
- Networking or Supabase read/write behavior
- Authentication and account lifecycle
- Camera, Photos picker, uploads, maps, notifications, or background work
- Sharing, edit/delete flows, destructive confirmation, or optimistic mutations
- Concurrency, recovery, loading, and error-state changes

Required:

- Build and run Debug on the current standard Simulator.
- Exercise the affected journey end to end once.
- Run focused automated tests for the changed logic.
- Inspect runtime output when the change touches async work, networking, or persistence.

Add accessibility, multiple device sizes, or visual comparison only when those surfaces changed.

Expected time: roughly ten to twenty-five minutes. Explain the scope before starting if it will be materially longer.

## Tier 4 — release gate

Use for:

- Release candidates or distribution readiness
- Project settings, signing, entitlements, dependencies, build phases, or deployment-target changes
- Database migrations or security-sensitive changes
- App-wide architecture or design-system migrations
- Performance, memory, crash, or accessibility certification passes
- Explicit requests for exhaustive validation

Required as applicable:

- Debug and Release builds
- Relevant unit and UI suites
- Clean-install or clean-Simulator journeys
- Accessibility and Reduce Motion checks
- Compact and large-device checks
- Runtime logs, performance, memory, migration, or security evidence

Expected time: planned separately. State the validation matrix before running it.

## Escalation rules

Move up one tier only when at least one of these is true:

- The lower-tier check fails in a way that suggests broader impact.
- The changed API or state is consumed outside the edited feature.
- The behavior depends on lifecycle, navigation, persistence, network, system UI, or relaunch.
- The bug cannot be reproduced or verified at the current tier.
- The user explicitly requests broader validation.

Compiler errors do not automatically justify an end-to-end run. Fix the error, repeat the same compile check, and stop if it passes and no broader risk remains.

## Reporting

At handoff, state only:

- Which tier was used
- Which exact check ran
- Whether it passed
- Any relevant validation intentionally not run

Do not describe a narrow check as a full regression pass.
