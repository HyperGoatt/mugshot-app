---
document_type: historical
status: checkpoint
last_verified: 2026-09-16
---

# Physical battery diagnostics validation — 2026-09-16

Current release authority: [Current product status](../CURRENT_PRODUCT_STATUS.md).
This checkpoint follows the
[original battery, thermal, and runtime audit](BATTERY_THERMAL_RUNTIME_AUDIT_2026-09-16.md).

## Verdict

The instrumentation succeeded and found a **confirmed critical current-source
defect**. The development candidate based on `038aad5` unconditionally restarted
Home recovery after every successful pass. On an untouched foreground launch it
started 119 Home/Supabase synchronizations in about 15 seconds with no pending
operation and no photo transfer. The loop kept CPU and network work active after
launch had settled.

The targeted fix is physically verified. In matched seconds 6–20 of short Power
Profiler launch captures, sampled CPU fell from 1,250 ms to 3 ms, a reduction from
about 8.9% to 0.02% of one core. Continuing network traffic fell from roughly
115–125 KiB every five to six seconds to zero. Unified logging recorded one Home
synchronization in the fixed build. Both captures remained at nominal thermal
state.

This is not the cause of the original TestFlight 0.5.3 (7) incident. The recursive
call was introduced later by remediation commit `038aad5`; build 7 predates it.
The original audit's location finding remains the leading build-7 explanation.
The short captures also cannot establish a battery-discharge percentage or prove
background, locked, movement, or multi-hour behavior.

## Build identity and conditions

| Item | Evidence |
| --- | --- |
| Device | iPhone 16 Pro, iOS 27.0 (24A435) |
| Instrumented identity | `co.mugshot.app.dev`, signed Debug build |
| Process identity | Distinct `MugshotDiagnostics` product and executable |
| Pre-fix source | `038aad5` plus diagnostics; contains the recursive recovery completion call |
| Fixed source | `codex/add-battery-diagnostics` candidate; recursive call removed |
| Procedure | Instruments launched the app, then no user interaction occurred during each focused capture |
| Thermal state | Nominal throughout both Power Profiler captures |
| Backend effect | No schema or configuration change and no test content. Because every pass reported `pending_operation=0`, Home synchronization used the read-only `get_home_workspace_v1` RPC; the loop still created excessive authenticated request load. |
| Raw artifacts | Local `/tmp` traces only; device, account, and content identifiers are excluded from tracked documents |

The runs were sequential rather than randomized, and launch caches were warmer in
the fixed run. The CPU and network result after second 6 is still attributable:
the pre-fix signposts identify a continuing Home sync every 0.1–0.2 seconds, while
the fixed signposts show no second pass. The shorter post-fix location interval is
not attributed to this fix because location cache state was uncontrolled.

## Confirmed defect

| Field | Finding |
| --- | --- |
| Severity and likely impact | Critical for the affected source revision. Continuous authenticated synchronization can materially drain battery, heat the device, consume network data, and load Supabase while the foreground app is idle. |
| Location | Completion path in `testMugshot/Services/AutomaticSipRecoveryCoordinator.swift`; fixed scheduler at lines 138–166. Store synchronization remains bounded at `testMugshot/Services/HomeRecipeWorkspaceStore.swift:281`. |
| Reproduction | Sign in with Home enabled, foreground the app with network available, then stop interacting. No pending Home operation is required. |
| Evidence | 119 recovery and sync starts, 118 completions, zero pending operations, zero photo bytes, sustained CPU samples, and continuing bidirectional network traffic in the pre-fix traces. |
| Root cause | The recovery task cleared its single-flight token and immediately called `scheduleHomeRecovery()` again. Success therefore became its own trigger. |
| Fix | Remove completion-triggered scheduling. Subscribe only to non-nil pending-operation IDs; keep account, foreground, and network transitions as explicit triggers. Inject the Home recovery boundary so the scheduling contract can be tested without a backend. |
| Expected improvement | Remove continuous idle CPU and request traffic from this path while preserving one launch/reconnect pass and race-safe store retries for edits made during a sync. |
| Verification | Focused regression test requires one pass per trigger; physical Logging requires one launch pass; settled Power Profiler requires CPU and network to return to idle. |
| Build applicability | Present in `038aad5`; absent from TestFlight 0.5.3 (7); removed in the fixed candidate. |

## Measurement table

| Metric | Pre-fix instrumented candidate | Fixed instrumented candidate | Interpretation |
| --- | ---: | ---: | --- |
| Logging duration | 16.68 s | 21.67 s | Both valid physical captures |
| Home sync starts | 119 | 1 | Runaway loop removed |
| Home sync completions | 118 | 1 | Last pre-fix request was active when capture ended |
| Pending operations reported | 0 for every pass | 0 | Loop did no useful local recovery work |
| Photo bytes reported | 0 for every pass | 0 | Media upload/download did not drive the loop |
| Power Profiler duration | 32.49 s | 22.04 s | Both valid physical captures |
| CPU running samples, seconds 6–20 | 1,250 ms | 3 ms | About 8.9% versus 0.02% of one core |
| Network after initial six seconds | About 115–125 KiB per 5–6 s | 0 B | Continuing sync traffic stopped |
| Initial launch network | 2.63 MiB received / 136.94 KiB sent | 2.61 MiB received / 94.14 KiB sent | Similar expected launch/feed work; not assigned to the loop |
| Thermal state | Nominal | Nominal | Short runs show no thermal escalation |
| Location energy | High for 10.01 s | High for 6.10 ms | Uncontrolled warm-location difference; no causal claim |

Time Profiler and Power Profiler count one-millisecond running samples. The CPU
percentages are sample time divided by wall time for one core; they are not battery
percentages or Instruments energy scores.

## Scenario and coverage ledger

| Scenario | State | Evidence | Remaining work |
| --- | --- | --- | --- |
| Instrumented launch | Completed on device | Correct dev process, lifecycle, thermal, Low Power Mode, location, nearby-reminder, network, recovery, and sync events emitted | None for event availability |
| Foreground idle after launch | Completed, short | Pre-fix loop reproduced and fixed run returned CPU/network to idle | Repeat 10-minute screen-specific captures for release acceptance |
| Home/Supabase recovery | Completed for no-pending launch path | 119-to-1 before/after result; zero media bytes | Exercise real pending edit, conflict, offline, reconnect, and background cancellation with isolated content |
| Location | Partially completed | One-shot and nearby ownership events emitted; all standard managers released | Movement and reminder-enabled/disabled physical comparison |
| Thermal | Partially completed | Both short captures stayed nominal | Longer unplugged and locked intervals from matched starting conditions |
| Background and lock | Not completed in this checkpoint | Lifecycle instrumentation is installed | 30-minute ordinary, Map, camera, and upload arms |
| Media/upload/memory | Not completed in this checkpoint | Upload byte/outcome instrumentation is installed | Ten-cycle media retention and interrupted upload matrix |
| Extended discharge | Not completed | No battery percentage is inferred from traces | Counterbalanced repeated three-hour control and Mugshot arms |

## Trace index

| Artifact | Scope | Result | Local storage |
| --- | --- | --- | --- |
| Pre-fix Logging | Physical, signed dev build | Valid; 119 Home sync starts | `/tmp/mugshot-battery-instrumented-logging-unique-20260916.trace` |
| Pre-fix Power Profiler | Physical, signed dev build | Valid; sustained CPU/network and nominal thermal | `/tmp/mugshot-battery-instrumented-power-unique-20260916.trace` |
| Pre-fix Time Profiler | Physical, signed dev build | Valid and symbolicated; no potential hangs | `/tmp/mugshot-battery-instrumented-time-unique-20260916.trace` |
| Fixed Logging | Physical, signed dev build | Valid; one Home sync | `/tmp/mugshot-battery-fixed-logging-20260916.trace` |
| Fixed Power Profiler | Physical, signed dev build | Valid; settled CPU/network idle and nominal thermal | `/tmp/mugshot-battery-fixed-power-final-20260916.trace` |
| Focused regression tests | iOS 27 Simulator | 17 distinct battery and recovery tests passed | `/tmp/mugshot-battery-loop-tests-2.xcresult` |

## Release decision

The Home synchronization defect is fixed and its foreground idle effect is
physically verified. Keep the release hold because build 7 still contains the
original location defect and the fixed candidate has not completed the physical
background/lock, movement, media, upload, or extended-discharge matrix. The next
highest-value experiment is a 30-minute locked comparison after ordinary use and
after Map/reminder use, followed by a repeated three-hour matched discharge test.
