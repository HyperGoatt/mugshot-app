---
document_type: historical
status: local-qa-complete-hardware-pending
observed_at: 2026-10-23
---

# Signature Polish Sprint acceptance ledger

Current implementation/release authority: [Current product status](../../CURRENT_PRODUCT_STATUS.md).
Baseline: [October 23 audit](../polish-2026-10-23/README.md).

## Authorized scope and safety

Seven approved priorities plus Feed coffee-fill refresh, expressive key moments,
Simulator acceptance, signed connected-iPhone development acceptance, and a scoped
PR into Home V4. This changes product presentation and local feedback state;
it does not change backend contracts, audience policy, recipe ownership, or
release configuration. No TestFlight, production writes, or marketing-version
changes. Preserve existing user data on the connected development iPhone.

## Required evidence

| Gate | State | Evidence |
| --- | --- | --- |
| Shared controls, accessible text/contrast | Implemented; locally verified | Debug compile, readable disabled footer, largest-text Saved/detail UI pass |
| Truthful unrated/planned/private/photo/required states | Implemented; locally verified | Home quick/guided journeys, presentation tests, canonical receipt captures |
| Ratings, criterion/intent, cafe relationship feedback | Implemented; locally verified | Criterion handoff, optimistic Undo/persistence and failure rollback UI tests |
| Directional navigation | Implemented; locally verified | Short 14-point transition; back/Resume paths retained |
| Transaction-scoped receipts | Implemented; locally verified | Durable Home saves, owner/transaction replay tests; 720 ms guided cradle/nod |
| Feed lifecycle and geometry | Implemented; locally verified | Native pull/short-drag, delayed scope/background cancellation, failure/retry, empty/repeat, accessible refresh and Reduce Motion |
| Focused regression tests | 59 focused tests and 7 distinct UI journeys passed across coherent batches | Results below; earlier failures retained in chronology |
| Repository static and Debug compile | 13 full-static checks passed; final motion batch compiled/tested | Local logs; no remote backend environment touched |
| Signed development build | Signed Debug build and strict signature verification passed | Final source, same approved 0.5.3 (8), co.mugshot.app.dev |
| Signed iPhone installation/launch | Blocked by unavailable device | Install attempted: CoreDevice 4016, trusted connectivity unavailable; no installation or launch occurred |
| Physical motion/tactile and spoken VoiceOver acceptance | Open | Cannot be inferred from compilation, Simulator, installation or launch |
| Before/after representative evidence | Captured; local HTML/video package assembled | Four before/after pairs plus concise quick-save receipt; baseline 521f532 and sprint candidate |
| Review, CI, scoped merge to V4 | Scoped self-review complete; draft PR #104 open | GitHub reports no conflicts, checks, reviews or comments; merge held for hardware and review |
| Documentation gate | Passed; final rerun before publishing | check-documentation.sh and git diff --check |

## Consolidated runtime matrix

Use the isolated Simulator with existing UI-test fixtures. Never seed a remote
Supabase project. Exercise actual production screens; injected refresh outcomes
are DEBUG/UI-testing-only and do not prove a live server transaction.

- Home quick/guided: unrated, optional photo, unknown versus As planned actuals,
  With a tweak, back/edit/resume, private Review, durable local receipt and reopen.
- Cafe: separate sip/place half-star ratings, required-caption hint, audience
  visibility, review/back; no real post or sharing required for visual acceptance.
- Saved: Favorite/Want to Try, removal/Undo, injected failure/rollback, count and
  empty/loading/cached-offline/no-cache failure, note confirmation.
- Feed: partial/reversed/cancelled pull, repeat pulls, delayed/immediate/failed/
  empty/skipped outcome, stale scope/account completion, background/tab departure,
  no animation or false success at rest.
- Default and accessibility text sizes, Reduce Motion, VoiceOver values/focus,
  footer reachability, unchanged touch targets, no duplicate feedback.
- After deterministic checks, capture representative production-renderer motion,
  then install the signed development candidate in place on Joe's iPhone when
  available. Do not reset, replace the account, or create production test content.

The goal remains open until every required gate is supported by its own evidence.

## First candidate observations and repair batch

- The production half-star control changed Not rated to 3.5 immediately, and
  exposes “3.5 out of 5” through its adjustable accessibility value. Adding a
  criterion checked its chip and revealed a row without opening a keyboard.
- Home quick save preserved the drink name and optional photo path, then showed
  a check receipt with Saved privately and Saved on this device · Sync pending.
  Guided Latte kept unmeasured actuals Unknown, accepted one explicit As planned
  dose, expanded With a tweak without keyboard focus, and reached canonical
  private detail with a guided receipt. Before/after clips are local QA artifacts.
- Saved failure did not claim no favorites; largest-text controls and recovery
  action were reachable by scrolling. Retry resolved to known-empty. Loading
  showed Loading cafes, and offline-with-cache retained cafes. Injected mutation
  failure restored the confirmed favorite and displayed row-associated feedback.
- Feed's first clip exposed native refresh spinner overlap and a presentation
  reset/reappearance around release, followed by fade over the returning card.
  The repair batch uses scroll-phase release to commit the existing normalized
  threshold, reserves a finite refresh gap, fades before collapsing that gap,
  and masks partial pulls to their available space. Native refresh rendering is
  removed; the request still uses the existing service and cache paths.
- The same batch removes duplicate row/global error copy, respects known cached
  library data while filtering, standardizes canonical media to Not rated, and
  updates existing UI-test review expectations. A focused armed-release test
  protects the custom release boundary. Final runtime evidence is still required.

Initial focused test result: 56 passed, zero failed/skipped, iOS 27 Simulator;
result bundle `test_sim_2026-10-23T18-57-02-218Z_pid75362_d520e54e.xcresult`
in the local XcodeBuildMCP workspace. Full-static log is local
`.codex/signature-polish-full-static.log`. Joe's iPhone was unavailable at the
latest device inventory; no hardware acceptance is claimed.

## Repair acceptance progress

The second source candidate passed all 13 full-static gates. The expanded run
passed 57 focused tests and three UI journeys (Home quick save, guided Latte,
and largest-text Saved/detail). Two UI checks failed and remain recorded as
failures until rerun: criterion parity assumed automatic draft resumption, and
Saved Undo's hit point was obscured by the search keyboard. The test now opens
the seeded draft through Resume draft; changing Saved categories or taking a
relationship action dismisses the search keyboard. Feedback ownership review
also restored one cue to local canonical like/favorite handlers and remote cafe
state actions after removing the shared child cue.

A native gesture recording of the repaired Feed shows progressive pour, held
request state, one pleased settle, fade, then gap collapse without a competing
spinner or overlap. Named Refresh sips accessibility actions are available on
Feed elements. Largest-text Feed inspection exposed a vertical spacer gap in
the shared stacked header and oversized photo captions clipping in a fixed
image. The final layout batch removes the vertical spacer and fixed subtitle
height/line cap at accessibility sizes, and places fully wrapping media captions
below the photo at those sizes. Default photo composition stays unchanged.

The latest batch passed all 13 full-static gates before these final layout
adjustments; a focused compile/test run for the affected journeys is underway.
No physical or production acceptance is inferred from these observations.

## Local QA checkpoint — 2026-10-23

The local source candidate implements the approved seven priorities and Feed
signature refresh without new rewards, destinations, backend contracts or
release changes. All 59 selected pure/hosted-app tests passed across the latest
coherent batches (12 SignaturePolishTests, 8 SavedCafeLibraryTests and 39
HomeRecipeWorkspaceTests). Seven distinct UI journeys passed: Home quick save,
guided Latte/actuals/private detail, criterion importance/pin/remove and cafe
handoff, Saved search/Undo/relaunch, largest-text Saved/detail, short/full pull
and tab departure, and failed cafe action rollback without a stale success notice.
These are local checks, not a production backend certification.

Key passing result bundles in the local XcodeBuildMCP workspace:

- `test_sim_2026-10-23T19-08-37-801Z_pid75362_052ffec8.xcresult`: Home quick/guided and largest-text journeys passed; two earlier failures retained.
- `test_sim_2026-10-23T19-22-55-065Z_pid75362_2d1bc007.xcresult`: Saved Undo/relaunch and largest-text journeys passed; earlier criterion entry failure retained.
- `test_sim_2026-10-23T19-29-21-866Z_pid75362_5a4036c8.xcresult`: repaired criterion journey passed.
- `test_sim_2026-10-23T19-57-45-531Z_pid75362_2c7e8107.xcresult`: 47 Home/Saved focused tests passed; initial droplet and indicator-visibility assertion failures retained.
- `test_sim_2026-10-23T20-05-07-210Z_pid75362_1df0900c.xcresult`: 11 polish tests and native short/full pull + tab cancellation passed.
- `test_sim_2026-10-23T20-15-33-734Z_pid75362_02443319.xcresult`: explicit largest-text relationship labels passed.
- `test_sim_2026-10-23T20-19-58-805Z_pid75362_cd2d9446.xcresult`: failure rollback and Undo/relaunch passed.
- `test_sim_2026-10-23T20-29-09-181Z_pid75362_ae7c3240.xcresult`: latest motion/visibility guards passed all 15 selected checks, including both Home saves and both new native UI regressions.

Manual native observations also confirmed 3.5 half-star selection, criterion
reveal without keyboard focus, With a tweak without keyboard focus, private
Review, local receipts and optional photos. A delayed refresh disappeared
immediately on scope change and did not replay its old result. Background/resume
was verified on the same Simulator process (26316) using a non-terminating native
resume; a prior helper-driven relaunch was excluded from that evidence. Failure
feedback is visible above the tab bar, keeps cached content, and clears on a
successful retry. Successful empty/repeated requests return to rest. A native
20-point drag cancelled without starting the delayed request; its UI regression
asserts the rendered label/state rather than existence of a retained hidden
SwiftUI wrapper. Droplet geometry tests protect visibility inside the revealed
gap during anticipation. Coffee remains inside the canonical open rim.

Motion tasks now consume their event before checking visibility, cancel on tab,
scene or Reduce Motion changes, and remain silent when the same state returns.
The existing tab-activity environment and account-keyed tab root are reused.
The retained legacy celebration renderer also pauses on inactive tabs. This is
code review and local runtime evidence; physical frame pacing is still open.

Accessibility evidence covers native adjustable values, named Refresh sips
activation, wrapping text, separate control targets and reachability. Actual
spoken VoiceOver focus/speech and tactile feel require the remaining hardware
pass. No live account switch, authenticated production post, or production
write was performed. Account stale-result and receipt-owner boundaries have
deterministic coverage; broader existing Home V4 release gates remain separate.

The sprint goal remains active until signed hardware acceptance and the scoped
review/merge into Home V4 are complete. No TestFlight handoff is authorized.

## Accessibility refresh and delivery checkpoint

The final accessibility refresh refinement passed 14 selected tests (12 focused
presentation tests and both new native UI regressions) in
`test_sim_2026-10-23T20-52-49-064Z_pid75362_c7b66cd5.xcresult`.
Named Refresh sips uses a compact visible progress label and announcements while
keeping the current scroll position; it never inserts the pull gap or coffee.
A subsequent redundant run could not launch its runners after Simulator services
disconnected (Mach -308); it executed no product assertions and is recorded as
infrastructure failure, not an additional passing run.

A signed Debug 0.5.3 (8) build passed strict codesign verification. Installing on
Joe's iPhone was attempted and failed with CoreDevice 4016 because trusted device
connectivity was unavailable. No physical installation, launch, tactile judgment
or spoken VoiceOver acceptance is claimed for this sprint.

Final signed build completed successfully after the accessibility refinement;
strict `codesign --verify --deep --strict` passed. The final fast gate passed
7/7 checks and whitespace is clean. Quiet accessibility refresh was observed
natively with its progress label, unchanged reading layout and no coffee.
Representative review files are local-only in `.codex/polish-audit-2026-10-23/`
(`review.html`, `clips/`, and `Mugshot-Signature-Polish-Review.zip`); they are
excluded from the source commit. The package contains four before/after pairs
plus quick-save acknowledgment. Cafe action footage shows Want to Try selection;
Undo/rollback evidence comes from the passing native UI tests.

## Published candidate

[Draft PR #104](https://github.com/HyperGoatt/mugshot-app/pull/104) targets
`codex/home-sip-v4` from `codex/signature-polish-sprint`. Implementation commit
`d8e035b` is pushed. GitHub reported a clean, mergeable diff with no CI check
entries, review submissions, review threads or comments at publication. No CI
pass or independent review is inferred from an empty list. The PR is attached
to this Codex task and remains draft/unmerged for signed hardware acceptance
and review. The Home V4 base remains `521f532`; main is unchanged by this sprint.

The local review package was opened and inspected in the in-app browser. Its
videos have native playback controls and do not autoplay. Downloadable archive:
`.codex/polish-audit-2026-10-23/Mugshot-Signature-Polish-Review.zip`.

Remaining owner-dependent gate: connect and unlock Joe's iPhone so the signed
candidate can be installed in place, then exercise motion, responsiveness,
haptics and spoken VoiceOver together. This needs a brief physical judgment;
automation cannot feel vibration. Record findings, repair any affected batch,
finish review, and merge the scoped PR only after acceptance passes.
