---
document_type: living
status: current
last_verified: 2026-08-25
---

# Mugshot Development Verification Policy

This policy keeps verification proportional to risk while avoiding repeated Simulator loops. The default is the lightest local check that can credibly catch a regression. Static analysis, pure tests, hermetic backend tests, and compile-only builds are the discovery tools; Simulator or physical-device work is a batched acceptance gate after those checks are green.

The practical commands and final acceptance matrix live in [`IOS_QA_EFFICIENCY_FRAMEWORK.md`](IOS_QA_EFFICIENCY_FRAMEWORK.md).

## Operating rules

1. Classify the change before testing.
2. Run the minimum tier that covers its real blast radius.
3. Build or test once after the implementation is coherent, not after every small edit.
4. Prefer deterministic evidence in this order: inspection, static checks, pure tests, hermetic backend tests, compile-only build, then runtime acceptance.
5. Do not use Simulator as the normal bug-discovery loop. Collect and fix issues as a batch before the next acceptance round.
6. Stop when the required evidence passes. Escalate only when a failure, uncertainty, or wider dependency justifies it.
7. Do not duplicate the same evidence with both shell `xcodebuild` and XcodeBuildMCP.
8. Never infer that the linked Supabase project is disposable. Local verification must not deploy, reset, migrate, delete, or seed a production-like remote project.
9. User-requested validation always takes precedence.
10. Physical-device testing is owner-promoted, not a default completion gate.
    Finish Simulator-scoped implementation and acceptance without waiting for a
    connected iPhone. Run a physical-device pass only after the owner explicitly
    promotes that candidate for hardware testing. A later TestFlight handoff
    still follows its separate explicit authorization and device-gate policy.

## Tier 0 — inspection only

Use for:

- Documentation and comments
- Non-product metadata
- Test descriptions with no executable change

Required:

- Review the scoped diff.
- Run `./scripts/check-documentation.sh` for documentation changes.
- Run formatting or `git diff --check` when relevant.

Do not:

- Build the app.
- Launch Simulator.
- Run tests.

Expected time: under one minute.

## Tier 1 — fast static and compile check

This is the default for small, isolated UI polish and contained Swift changes.

Use for:

- Copy changes
- Spacing, padding, color, typography, corner radius, or icon changes
- A local visibility or disclosure tweak using existing state
- Small animation timing or transition changes
- Preview or fixture-only changes
- A contained SwiftUI refactor with unchanged data flow

Required:

- Review the scoped diff.
- Run `scripts/verify-no-simulator.sh fast`.
- Run one generic Debug compile check when Swift or app resources changed. `scripts/verify-no-simulator.sh full-static` provides the repository-standard compile-only check.
- If the compiler cannot exercise the changed path, use the smallest relevant static or pure check instead.

Do not routinely:

- Boot, build-and-run, or interact with Simulator.
- Create or mutate app data.
- Run UI tests or an end-to-end flow.
- Capture screenshots or produce a design-QA board.
- Run the complete unit-test suite.
- Build Release.

Expected time: three minutes or less when package dependencies are already local.

Example: changing Taste Snapshot so criteria appear only after `View breakdown` is Tier 1. A compile-only check is sufficient unless the state transition itself changed.

## Tier 2 — focused deterministic behavior check

Use for:

- New or changed local interaction logic
- Bindings, validation, capability mapping, or presentation adapters
- A component-level state machine
- A bug fix with a deterministic reproduction
- Local persistence behavior confined to one feature
- An Edge Function or isolated database contract

Required:

- Run Tier 1 evidence.
- Run the smallest directly relevant pure test, Edge Function test, SQL parser check, or hermetic database contract test.
- Add one focused test only when behavior changed and the test directly protects that behavior.
- If Swift logic can only run inside the current Simulator-hosted app test bundle, queue that test for the single consolidated acceptance checkpoint rather than starting a one-off Simulator loop.

Do not routinely:

- Run unrelated test targets.
- Recreate an entire user journey when deterministic evidence covers the behavior.
- Connect a SQL contract test to the linked Supabase project.
- Build Release.

Expected time: roughly three to ten minutes.

## Tier 3 — feature integration without Simulator discovery

Use for:

- Navigation or presentation changes spanning screens
- Feed, Saved, Journal, Map, profile, or composer entry-point migrations
- Persistence across account transitions or relaunch boundaries
- Networking or Supabase read/write behavior
- Authentication and account lifecycle
- Camera, Photos picker, uploads, maps, notifications, or background work
- Sharing, edit/delete flows, destructive confirmation, or optimistic mutations
- Concurrency, recovery, loading, and error-state changes

Required before runtime acceptance:

- Review the complete feature diff and all call sites of changed contracts.
- Run `scripts/verify-no-simulator.sh full-static`.
- Run focused pure tests and hermetic backend behavior/security tests for the changed contracts.
- Exercise failure, retry, authorization, idempotency, and data-projection states through deterministic tests where possible.
- Document any behavior that genuinely requires Apple system UI, lifecycle, or a live runtime.

Do not launch Simulator as each issue is fixed. Once implementation and deterministic checks are coherent, add the runtime-only items to the next consolidated acceptance matrix.

Expected time: roughly ten to twenty-five minutes for the no-Simulator gate. Explain the scope before starting if it will be materially longer.

## Tier 4 — consolidated acceptance or release gate

Use for:

- A completed cross-feature sprint
- Release candidates or distribution readiness
- Project settings, signing, entitlements, dependencies, build phases, or deployment-target changes
- Database migrations or security-sensitive changes
- App-wide architecture or design-system migrations
- Performance, memory, crash, or accessibility certification passes
- Explicit requests for exhaustive validation

Phase A — required before any runtime session:

- All required Tier 0–3 evidence is green.
- Backend tests used only a disposable local or isolated environment.
- The runtime matrix, accounts, data-safety limits, and expected states are written down.
- Known static failures are fixed or explicitly accepted. Simulator is not used to investigate a known compile or backend failure.

Phase B — one batched acceptance session, as applicable:

- Boot the standard Simulator once and reuse that boot for the session.
- Run the consolidated app unit suite once if the changed Swift logic requires it.
- Build, install, and launch once, then walk the prepared runtime matrix across all affected areas.
- Prefer one human-QA walkthrough when judgment, system UI, or accessibility behavior is the remaining uncertainty.
- Capture representative checkpoints and every failure, not a screenshot of every successful tap.
- For signing, push notifications, camera, performance, or distribution behavior that Simulator cannot prove, record the unverified hardware boundary and wait for the owner to explicitly promote the candidate before running one planned physical-device pass.
- Run Release only for a release gate, signing/packaging risk, optimizer/availability uncertainty, or an explicit request.

If runtime acceptance finds issues, record all observable failures before ending the session. Fix them as a batch, rerun the no-Simulator gate, and schedule another consolidated acceptance round only when coherent. Do not turn the acceptance gate into alternating one-fix/one-launch cycles.

Expected time: planned separately. State the validation matrix before starting.

## Escalation rules

Move up one tier only when at least one of these is true:

- The lower-tier check fails in a way that suggests broader impact.
- The changed API or state is consumed outside the edited feature.
- The behavior depends on lifecycle, navigation, persistence, network, system UI, or relaunch and cannot be isolated deterministically.
- The bug cannot be reproduced or verified at the current tier.
- The user explicitly requests broader validation.

Compiler errors do not justify an end-to-end run. Fix the error, repeat the same compile-only check, and stop if it passes and no broader risk remains.

A Simulator-only observation does not automatically require an immediate rerun. Unless it blocks all further inspection, log it, finish the matrix, and repair the batch afterward.

## Reporting

At handoff, state only:

- Which tier was used
- Which exact checks ran
- Whether they passed, failed, or were skipped
- Why an optional check was skipped
- Any runtime, device, or remote integration validation intentionally not run
- Which Supabase environment, if any, was touched

Do not describe a compile-only, parser-only, or local contract check as a full regression pass. Do not describe a Simulator pass as proof of production backend safety.
