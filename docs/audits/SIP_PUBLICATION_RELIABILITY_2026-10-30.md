# Sip publication reliability evidence — 2026-10-30

> Subsequent checkpoint: the [completion and publishing ledger](PUBLISHING_COMPLETION_MOTION_2026-10-30.md)
> supersedes the provider-version/cause uncertainty and candidate verification
> state below. The multiline-address defect is confirmed and service version 17
> is live. This earlier investigation and original-attempt limitations remain
> historical evidence.

Historical investigation and implementation evidence for branch
`codex/sip-publication-reliability`. Current contracts live in
[REAL_DATA_FLOW_STATUS.md](../REAL_DATA_FLOW_STATUS.md) and the current
[verification workflow](../VERIFICATION_POLICY.md).

## Scope and safety

Journeys were derived from the owner's request: create/edit and audience choice;
visible validation/button handling; auth/account transitions; photo preparation;
private staging, finalization and truthful completion; cancellation, backgrounding,
retries and recovery. Documentation impact: product behavior, architecture/data
ownership, privacy/analytics/operations, and verification workflow. No database
schema, RLS, Storage or release-setting change is required.

Production diagnosis used read-only PostHog queries, Supabase rows/logs and a
read-only copy of the development app's preferences. No production attempt,
photo mutation, cleanup, migration, deployment or new test record was made.
Synthetic transport fixtures use `.invalid` hosts and isolated local stores.

## Corroborated incident evidence

- PostHog records repeated `sip_publish_failed` / `unknown` / `protected_retry`
  events on October 24 and 28, build 0.5.3 (8). Recorded events have no visit ID,
  so time/account correlation alone is not an exact per-visit join.
- The iPhone development-app outbox contains one five-photo submission at
  `prepared`, without finalization or remote-completion receipts. Its exact
  stable visit ID has no row in Supabase. This distinguishes a pre-creation
  dependency failure from a failed photo upload.
- At 2026-10-28 13:58:12.526Z the sharing-policy request succeeded. Account and
  verification-reservation checks also succeeded. `verify-cafe` then returned
  HTTP 503 at 13:58:13.349Z; `sip_publish_failed` followed at 13:58:13.615Z.
  Another account's 14:06:44Z attempt shows the same verification-stage failure.
- Deployed `verify-cafe` is ACTIVE version 10 with JWT verification enabled.
  Its catch-all 503 conceals whether configuration, provider or persistence
  failed. The underlying provider cause is not proven. Browser access is
  disabled and native computer access is locked; the connector cannot list
  provider secret configuration. No security guard is bypassed.
- Four retained visits from the preceding 14 days are complete, including the
  earlier October 23 incident's original post. This current state does not
  establish successful original UX or explain the prepared draft.
- `sip_publish_blocked` is implemented in source but absent from the live event
  taxonomy. Disabled-button/pre-submission failure prevalence is unmeasured.

## Confirmed source defects and guarantees

| Trigger | Defect | Intended guarantee |
| --- | --- | --- |
| Continue with the drink-name keyboard active on iOS 27 | Synchronous global keyboard dismissal strands the step transition | Defer scene-scoped dismissal until the button/step update returns |
| Retry after photos uploaded/local previews unavailable | Fresh form/photo validation can disable the protected retry | Validate identity and frozen payload; resume the same visit without local previews |
| Auth lost but cached local profile remains | Canonical publication falls back to local save | Require Auth for remote publication; local publishing only in DEBUG fixtures |
| Account changes during suspended publication | Untracked task and shared dynamic credentials can outlive the original account | Cancel, invalidate generation, and never borrow a later account's token |
| Composer and lifecycle recovery overlap | Stable ID alone does not serialize attachment/delete/finalize steps | One operation per account/visit in-process plus existing durable receipts |
| Empty media with nonempty plan / duplicate or foreign paths | Empty upload can return success before validation | Validate exact scoped media plan before mutation |
| Acknowledged upload loses local bytes | Retry unnecessarily reloads all files | Require bytes only for unacknowledged paths |
| Later edit photo/RPC failure | Successful uploads are deleted/repeated | Keep separate scoped edit receipts and stable paths until canonical commit |
| Repeated edit taps before async body starts | Loading guard is set inside Task | Lock synchronously and submit a frozen edit snapshot |
| Invalid edit field | Disabled button hides the only error path | Show the current validation reason before tapping |
| Late upload-failure write | Completed row can be downgraded | Server update excludes complete visits |

## TDD evidence

- RED checkpoint `a253557`: new focused tests intentionally reference missing
  shared validation, publication gate and strict upload-plan guarantees.
- Command: `xcodebuild -project testMugshot.xcodeproj -scheme MugshotTests
  -configuration Debug -destination 'generic/platform=iOS Simulator'
  -derivedDataPath /tmp/mugshot-publication-derived -quiet
  -disableAutomaticPackageResolution -skipPackageUpdates
  CODE_SIGNING_ALLOWED=NO COMPILER_INDEX_STORE_ENABLE=NO build-for-testing`.
- Result: compile-time RED reached the new tests; errors identify only the missing
  guarantees (and their dependent type-inference errors). A later extraction
  typo was corrected; it is not counted as RED evidence.
- Runtime RED: `existingProviderCafeDoesNotDependOnVerificationBeingOnline`
  failed with the injected HTTP 503; five other tests passed. A separate Auth
  fixture lacked `updated_at`; this was fixed and is not RED evidence.
- First GREEN: 49/49 focused tests passed on iOS 27, with synthetic backend
  configuration and production analytics disabled. Backend/static checks passed
  12/12, including offline Deno and hermetic PostgreSQL contracts.
- Extended GREEN: 51/51 focused tests passed in the first acceptance run.
- Runtime UI RED: the normal Cafe journey failed with "Failed to get matching
  snapshots: Timed out while evaluating UI query." A process sample taken at
  17:01:45 local time showed the main thread in `move(to:back:)` ->
  `dismissKeyboard()` -> `UIApplication.sendAction` -> `UITextField.resignFirstResponder`
  and keyboard layout. The fixture was stopped after capturing this evidence;
  the second UI journey was cancelled, not passed. The step change was still
  pending, so this is a pre-submission hang, not an upload failure.
- Keyboard repair defers scene-scoped `endEditing` until the gesture/step update
  returns. Final acceptance passed 53/53: 51 focused tests plus both UI journeys,
  zero failures or skips, on Mugshot iPhone 17 Pro / iOS 27.0 Simulator.
- Final command used `xcodebuild ... test` on destination
  `CC93D606-1300-44B5-AC69-1D4B21E63F96`, shared `MugshotTests` scheme,
  `-parallel-testing-enabled NO -collect-test-diagnostics never
  -enableCodeCoverage YES -test-timeouts-enabled YES
  -default-test-execution-time-allowance 120`, selecting
  `SipPublicationReliabilityTests`, `PendingVisitRecoveryTests`,
  `AutomaticSipRecoveryCoordinatorTests`, `PendingVisitOutboxTests`,
  `SipPostEditPolicyTests`, `MugshotAnalyticsTests`, and the two
  `testCafePublication...` UI methods. The checked-in tests are the executable
  specification; this report is the evidence index.
- Build overrides: `MUGSHOT_SUPABASE_URL=https://publication-fixture.invalid`,
  `MUGSHOT_SUPABASE_PUBLISHABLE_KEY=synthetic-key`, and an empty
  `MUGSHOT_POSTHOG_PROJECT_TOKEN`. Generated app Info.plist was checked for the
  synthetic host/key and disabled analytics before reporting acceptance.
- Final signed Debug candidate is 0.5.3 (8), `co.mugshot.app`; signature validation
  passed. It was built, installed and run in Simulator only.
- Result bundle: `/tmp/mugshot-publication-derived/Logs/Test/Test-MugshotTests-2026.10.30_17-03-19--0400.xcresult`.
- Scoped line coverage: shared validation 68/79 (86.1%), publication gate 15/15
  (100%), edit media receipts 52/53 (98.1%). Across these new helpers: 135/147
  (91.8%). Existing upload service is 68.2% and client provider 77.8% in this
  focused run; these are not app-wide coverage claims. Live provider setup,
  physical lifecycle/expiration and production transport remain outside this
  local fixture coverage.
- `./scripts/verify-no-simulator.sh backend`: 12 passed, zero failed/skipped.
  This includes the repository static checks, Deno offline tests and hermetic
  PostgreSQL contracts. Signed app/test compilation is covered by the final
  Simulator test build rather than repeated with a generic destination.
- `./scripts/check-documentation.sh`, `git diff --check`, focused ownership/
  credential/media/cleanup review and complete diff inspection passed.

## Passing guarantees

| Test group | Evidence |
| --- | --- |
| Shared validation | Valid half-star boundary, NaN, required caption, caption/note limits, cafe context score, Tasting Lens and wrong-account rejection |
| Frozen retry | Uploaded/finalized submissions remain resumable without local previews or revalidating mutable caption; missing acknowledged bytes remain optional |
| Upload interruption/recovery | Existing third-photo interruption, receipt reload, retry only unfinished paths, no successful-object deletion, poster/order and stale receipt checks pass |
| Session isolation | Original-account token works; after account replacement REST, Storage and Functions requests carry the fail-closed credential rather than the next account's token |
| Duplicate protection | Repeated gate acquisition is denied; wrong tokens cannot release work; existing outbox/finalization/reconciliation tests pass |
| Edit media | Acknowledgements survive store reload, stay owner/visit scoped, reject foreign paths and purge only the deleted account |
| Lifecycle coordinator | Existing inactive/background continuation, cancellation and account-change tests pass with the publication gate |
| Normal runtime | Cafe setup -> scoring -> publish -> completion passes with local fixtures |
| Failure runtime | First-save failure displays an error and retains the draft; background/return -> retry -> completion passes |

Runtime fixtures do not establish a successful production remote publish or
physical iOS background-expiration acceptance. The local first-save injection
runs before a remote submission; interrupted network/media paths are separately
covered by synthetic URLProtocol tests.

## Acceptance boundaries

- Simulator matrix: normal local-fixture save; visible invalid validation;
  injected first-save failure then retry; interrupted upload preservation;
  account switch/cancellation; repeated taps; frozen uploaded retry.
- Physical-device acceptance: not promoted for this candidate. Read-only outbox
  inspection is diagnosis, not an install or acceptance pass.
- Production fix verification: blocked on provider diagnosis/configuration and a
  separately authorized deployment/acceptance. The original draft is preserved.
- TestFlight: not requested; no archive, upload, assignment or version change.
- GitHub: the checkout is based on the held signature-polish candidate (PR #104),
  not current `main`. Do not merge unrelated prerelease work to deliver this fix.

## GitHub delivery

- Branch: `codex/sip-publication-reliability`, pushed and tracking origin.
- RED checkpoints: `a253557`, `1af4e40`, `a9be732`.
- Implemented/GREEN commit: `1f043ad`.
- [Draft PR #105](https://github.com/HyperGoatt/mugshot-app/pull/105) targets
  `codex/signature-polish-sprint`; GitHub reports it mergeable with no configured
  check runs and no submitted review decision at this checkpoint.
- Merge is held: the live cafe-verification provider cause remains blocked by
  dashboard access, and parent [PR #104](https://github.com/HyperGoatt/mugshot-app/pull/104)
  is draft/held for its independent acceptance. `main` was not changed.
- Final local tree and pushed head are checked separately from production,
  physical-device, and TestFlight acceptance. No release was performed.
