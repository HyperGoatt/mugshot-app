---
document_type: living
status: current
last_verified: 2026-11-24
---

# The Weekly Pour

## Goal and implementation plan

Deliver an on-brand, native Week in review in Journal, guided by the current
approved Mugsy catalog and the original October 31 design. Joe authorized
implementation on November 24. The historical approval-only prototype remains
preserved in [draft PR 107](https://github.com/HyperGoatt/mugshot-app/pull/107).
This independent implementation starts at main `f35f6cd`; it does not merge the
prototype's unfinished app dependencies.

Documentation impact: product behavior, account-bound data ownership, privacy,
and local verification. No schema, backend deployment, push schedule or
TestFlight change is required.

1. Recover the native mockup, inspect current brand/Mugsy authority, and record
   the exact source baseline. Complete.
2. Test completed-week boundaries, ownership, completed saves, duplicate
   suppression, deterministic highlights, repeats and privacy-safe sharing. Complete.
3. Implement the Journal invitation, real weekly loading, adaptive native
   chapters, archive, reversible caption, and explicit share preview. Complete.
4. Inspect real Simulator screens, large text and Reduce Motion; run focused
   domain/lifecycle tests, repository checks and a Debug build. Complete.
5. Install/launch the existing development app in place on the connected owner
   iPhone when available; report hardware and owner acceptance separately.
   Build 19 installed; launch is blocked by the locked iPhone.
6. Review the complete diff, publish a feature PR, pass required checks, merge
   with no unresolved reviews, and synchronize main.

## Product and data contract

The latest completed week ends at the most recent Sunday at 6 PM in the reader's
timezone. Its start is exactly 168 hours earlier, matching the original proposal.
Intervals include their start and exclude their end. Opening an archived week
keeps its explicit endpoint; a later date does not silently retarget it.

The story includes only this account's complete canonical sips and durably saved
private Home attempts. Drafts and failed/in-progress publications are never
counted as canonical sips. A saved Home attempt is not counted twice when its
publication is already present. Weekly remote reads are interval-bound and
paginated rather than derived from Journal's limited recent-history cache.

Chapters are cover, moments, standout, places, repeat order and keepsake. Only
chapters supported by actual data appear. Zero sips gets a quiet-week page;
one sip gets a shorter story. Unrated sips remain unrated. Highest rating uses
only valid recorded scores; ties and repeated drink names resolve deterministically.
No comparison, flavor inference, invented memory or consumption goal is added.

The recap is owner-only. Sharing opens a separate preview that excludes private
memories by default. An explicit toggle includes their aggregate counts.
Exports never contain captions, private notes, names, locations or photos.
The preview is exactly the locally rendered keepsake passed to system sharing.
No external message is sent by opening the preview or system sheet.

## Visual and accessibility contract

Use the [brand kit](brand/README.md): cream canvas, espresso regular-serif
headlines, mint context, sage-text actions and system body type. Use the approved
artwork through `MugsyCatalogView` for static journal, cozy and celebration poses.
Finite chapter/photo transitions settle at rest; Reduce Motion has direct state
changes. Previous, Next, Close and archive remain available without timed gates.
Chapter content scrolls independently of the reachable navigation controls.

Remote photos use the existing authorized image boundary; missing photography
and unavailable photography remain distinct. Account changes invalidate loaded
stories and sharing. Cancelled or superseded loads cannot replace a newer week.

## Verification and delivery

Implemented and locally verified. The [native screen review](design/weekly-pour-2026-11-24/index.html)
contains ten unaltered Simulator captures and [capture provenance](design/weekly-pour-2026-11-24/README.md).

| Evidence | Result |
| --- | --- |
| Production domain/store contracts | 34 assertions passed; 94.74% line coverage (171 lines) |
| Native data, visibility, paging, failure and rendered image | Six Simulator test methods passed, including six visibility cases |
| Full story, caption, archive, sharing, quiet/one-sip/photo-free/unrated, private default, largest text/Reduce Motion | Six Simulator UI journeys passed; zero skips |
| Final system chrome contrast | Full story/caption/share/archive UI journey passed again; native capture confirms white status text on espresso |
| System share handoff | Real iOS share sheet opened with Copy and Save Image; no destination selected or message sent |
| Repository static, documentation, brand, Mugsy | All 10 fast checks passed, including brand/identity authority |
| Native compilation | Generic Debug Simulator app build and signed Debug iPhone build passed |
| Physical install | Existing `co.mugshot.app.dev` updated in place to 0.5.3 (19); final source matches `71e5d84` |
| Local data preservation | Read-only backup retained; all 60 existing Application Support files were byte-identical after the first install |
| Physical launch/acceptance | Launch denied by iOS because the owner's phone is locked; physical unlock requested. No owner acceptance claimed |
| Production backend / TestFlight | No deployment, notification, archive, export, upload or group assignment performed |

Simulator reads use a synthetic `.invalid` backend, disabled analytics and local
fixtures. Network integration tests intercept the real client with URLProtocol.
The signed device uses the existing local client configuration, with analytics
disabled for the verification build. No diagnostic SQL or remote mutation is
part of this verification. Build logs, xcresult bundles, coverage profiles and
the owner-data backup are local-only under `/tmp` or ignored `.codex` paths.

The complete focused Simulator result is `/tmp/mugshot-weekly-final-tests.xcresult`
(12 passed, 0 failed, 0 skipped). The final contrast rerun is
`/tmp/mugshot-weekly-contrast-tests.xcresult` (1 passed). The earlier failed run
completed its assertions, then stalled collecting Xcode's verbose failure
diagnostics; the tool process was stopped and the final run disabled that
diagnostic collection. This tooling interruption is not reported as passing.

Reproduce the pure contracts without an app or backend:

```sh
xcrun swiftc -parse-as-library testMugshot/Models/WeeklyPourModels.swift \
  testMugshot/Services/WeeklyPourStore.swift scripts/test-weekly-pour.swift \
  -o /tmp/mugshot-weekly-contracts
/tmp/mugshot-weekly-contracts
```

The Simulator targets are `testMugshotTests/WeeklyPourDataSourceTests` and
`testMugshotUITests/WeeklyPourUITests` in scheme `MugshotTests`. Use the selected
supported Xcode and a disposable Simulator. No production credentials are needed.

### TDD evidence

- `92afe3f`: intended compile-time RED for the missing weekly domain/store,
  followed by passing production-domain contracts.
- `83b6e3b`: runtime RED reproduced cancellation leaving loading active.
  `ef51ff9` settles only the matching request using `defer`; all 34 focused
  domain/privacy/lifecycle assertions pass. Instrumented line coverage is
  94.74% across the production domain/store (171 lines, 9 missed).
- First Simulator run: six data-source/rendering test methods passed (including
  six visibility cases), and five of six UI journeys passed. The quiet-week
  exit returned to Journal, but the invitation's accessibility override hid its
  intended identifier/label. Native runtime inspection confirmed the working
  button and the missing semantics. `6318d7d` repairs it, and the focused rerun passes.
- Final focused rerun after `6318d7d`: all 12 Simulator tests pass (six native
  data-source/rendering methods and six UI journeys), with zero skips. Optical
  review then caught black system status text against the espresso standout
  background; the captured standout is the runtime RED for a scoped color-scheme
  repair. `71e5d84` applies the scoped preference; the full-story journey passes
  and optical review confirms readable system chrome.
