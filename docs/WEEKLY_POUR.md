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
   suppression, deterministic highlights, repeats and privacy-safe sharing.
3. Implement the Journal invitation, real weekly loading, adaptive native
   chapters, archive, reversible caption, and explicit share preview.
4. Inspect real Simulator screens, large text and Reduce Motion; run focused
   domain/lifecycle tests, repository checks and a Debug build.
5. Install/launch the existing development app in place on the connected owner
   iPhone when available; report hardware and owner acceptance separately.
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

Implementation and verification are in progress. Simulator, physical install,
owner acceptance and TestFlight acceptance are separate evidence states.

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
  button and the missing semantics; repair and focused rerun are in progress.
- Final focused rerun after `6318d7d`: all 12 Simulator tests pass (six native
  data-source/rendering methods and six UI journeys), with zero skips. Optical
  review then caught black system status text against the espresso standout
  background; the captured standout is the runtime RED for a scoped color-scheme
  repair before final delivery.
