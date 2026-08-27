---
document_type: living
status: current
last_verified: 2026-08-26
---

# Current product status

## Release baseline

Mugshot is a native SwiftUI social coffee journal distributed through
TestFlight. `main` includes the Home Workbench/documentation baseline from PR
#46, notification backend v3 from PR #47, and the safe schedule cutover from PR
#48, production release evidence from PR #49, the hardened iOS notification
lifecycle from PR #50, and physical registration evidence through PR #55.
PR #56 fixed immediate Feed/Activity unread propagation, and PR #57 contains
the Feed/Map feedback fixes described below. The completed remediation release
candidate is version 0.5.3 build 6. Organizer and the 44 cached Xcode feedback
packages provide direct evidence that testers used 0.5.3 (5), superseding the
earlier claim that 0.5.3 (4) was the latest distributed candidate. The owner
explicitly authorized the 0.5.3 (6) Simulator and connected-iPhone gates,
archive/upload, and Alpha Friends assignment on 2026-08-26. Processing and
testing-group state remain unclaimed until App Store Connect confirms them.

The Home Workbench and notification backend migrations are live through
`20260824171405`. Local, disposable-QA, live drift, and protected-data
fingerprint evidence closed on 2026-08-24.

## What works now

- Email/password, Apple, and Google authentication flows, session restore,
  profile completion, sign-out cleanup, and account deletion orchestration.
- Guest exploration and drafts, followed by account-scoped local adoption and
  signed-in Supabase authority.
- Guided Cafe, Home, and Elsewhere sip composition with durable drafts, pending
  submission recovery, photo handling, edit/delete, and visibility controls.
- Home Workbench recipe memory, brew templates, actual-versus-planned capture,
  coffee bag assets, reusable recipes, and owner journal projections.
- Remote Feed, Journal, profiles, likes, comments, mentions, reactions, tags,
  friend requests, blocking, reporting, moderation state, collaborative cafe
  lists, public share links, and privacy-aware projections.
- The shared owner/friend profile uses the approved Editorial Atlas layout: a
  compact 112-point photographic banner with a foam-white tappable
  Friends/Sips/Cafes dock, streamlined identity/actions, up to three compact
  owner-selected Favorite Spots, and Mugshots, cafes, exploration map, and
  tagged tabs. Sparse friend profiles collapse identity metadata and social
  links into a wrapping detail rail and do not render the former Taste overlap
  card. Favorite Spot creation presents all six reason categories at once and
  includes a visible custom descriptor path. The Cafes tab keeps one stable
  scroll owner around its lazy card grid. Friends Mugshots stay in Friends Feed
  and appear on the public profile by default; the owner can switch the public
  profile to Everyone-only, while Private Mugshots never appear. Favorite Spots
  may originate
  in private history or Apple Maps only through an explicit owner publication
  of cafe identity plus a short descriptor; private media and notes do not
  cross that boundary. Owners can hide a tagged Mugshot from their profile or
  remove their tag. The map reuses the production MapKit surface and controls,
  omits the redundant profile-named ratings legend below the map, and the
  obsolete Profile Highlight is not rendered by the new UI.
- Owner Profile sharing now uses a dedicated profile share hub. It renders
  fixed Story and Post snapshots from the canonical link's recipient-visible
  projection when available, explicitly orders profile-published Mugshots
  newest-first, and resolves both HTTPS and durable private-Storage media before
  artwork generation. It packages the chosen image with `Add me on
  Mugshot — @handle` copy and the active canonical profile URL, and supplies a
  branded link preview to the native share sheet. The export model contains
  public profile fields and profile-published media only; Private Mugshots and
  journal-only content are absent.
- The remediation branch adds expressive Like/Love/Laugh/Yummy post reactions
  without replacing historical coffee-specific reactions, one-level comment
  threading, identifier-based tab behavior, compact Journal/Profile/Feed
  surfaces, recoverable photo deletion, and address-order-invariant local cafe
  reconciliation. Reselecting Feed returns to its top, while the scope control
  stays fixed during pull-to-refresh and the first 60 points of upward travel,
  then moves continuously beneath the clipped compact header over its measured
  height. At rest it uses the same eight-point gap above and below the scope
  rail; its zero-height refresh reader is outside stack layout and contributes
  no blank space. The control is rendered independently of lazy feed-card
  recycling so it cannot pop away at the handoff. Scope subtitles keep a stable compact
  layout footprint, preventing Your Mix from shifting the control when its
  matching sentence wraps to two lines. Structured comment mentions open their
  own profile/friendship destination even when that account is not tagged on
  the post.
- Journal keeps its tappable owner identity, hides the duplicate toolbar
  profile action behind a disabled feature flag, and presents a Mugsy upgrade
  holding screen for Taste Passport. Publish keeps direct edits for photos,
  identity, scores, and caption while Audience, Raw note, and Tag people remain
  compact inline controls; private-note editing remains in the reflection
  flow.
- Share output adds only allowlisted `@handle` and coarse city/state fields plus
  safer export bounds. Publish preview geometry and the share hub/sheet actions,
  formats, templates, controls, privacy flow, defaults, and collage behavior
  remain unchanged.
- Map, saved cafe state, discovery, cafe detail, reflection, widgets, share
  extension, universal links, and nearby cafe reminders. Cafe detail renders
  all remote Mugshots visible to the current viewer and uses local history only
  when no visible remote visit is available. Both historical HTTP URLs and
  current `mugshot-storage://` references resolve through the remote media
  pipeline. Same-name provider records with equivalent normalized street
  addresses are presented as one cafe; Map pins and detail queries combine
  their RLS-visible visits and media without mutating the source cafe rows.
- Feed keeps the Your Mix header to two lines with a compact first-card gap,
  and Map prevents its broad launch fallback from overwriting an
  already-authorized user's first current-location camera request.
- Reflection offers 12–18 relevant suggestions for every parsed drink
  preparation and Home brew method. The suggestion rail remains above the
  selected rows so adding a criterion does not move the available choices.
  Criterion importance is an account- and criterion-scope-bound local
  preference that survives future sips; criterion scores remain visit-specific
  and start blank.
- Central Add starts a fresh blank draft. Existing work is recovered only by
  choosing Resume draft in step one, selecting from the picker when several
  drafts exist, or opening a draft from Journal. The composer exposes a native X
  on every step and keeps Back beside it when an earlier step exists.
- In-app Activity with unread count, pagination, read actions, notification
  category preferences, and account-bound deep links.
- Caller-bound APNs registration and a durable Supabase delivery worker with
  production credentials and one Vault-backed minute schedule.
- Source build 5 notification lifecycle with typed sandbox/production
  environments, capability-gated v3 registration, shared local/remote
  authorization, account-bound foreground/tap refresh, authoritative badges,
  and privacy-safe notification analytics.

## Data authority

Supabase is authoritative for signed-in identity, public and social content,
visits, media references, cafe state, friends, safety, lists, Activity, device
registration, and Home library data. Account-scoped local stores remain
authoritative for guest data, unfinished drafts, pending submissions, cached
media, UI preferences, recovery commands, and offline presentation until a
remote write succeeds.

No local sample, cache, or fallback count may be presented as remote truth.

## Notification status

The notification backend is implemented and production-configured, but remote
delivery is not yet fully physically accepted. The Release/TestFlight app
carries the production APNs entitlement and the backend worker has both Apple
topics.
The Physical Debug sandbox entitlement and lifecycle hardening are implemented
on `main` through PR #50. A connected-iPhone build confirmed the Debug bundle,
entitlement file, and sandbox compilation condition, then stopped because the
installed development profile did not include `aps-environment`. Push
Notifications is now enabled for the Debug App ID. A replacement development
profile using the existing certificate and registered iPhone is active in the
Apple Developer portal and includes Push Notifications. The profile is now
downloaded and installed locally. Physical Debug uses that named profile only
for `iphoneos`; Simulator signing remains automatic. A signed device build
succeeded with `aps-environment=development`, and the app installed on Joe's
iPhone. The unlocked app launched, restored the signed-in session, presented
the just-in-time Activity education, received iOS authorization, and registered
one active sandbox installation with badge sync. Push opt-out removed that
sealed device row; restoring the preference recreated it, and a terminated
cold launch refreshed it while preserving the session. A normal cross-account
like then produced one sandbox delivery that the minute worker completed on
its first attempt. The signed iPhone showed the unread Activity item, opening
it set the authoritative unread count to zero, and the in-app destination
opened. The Feed bell remained stale until activation; a direct shared-store
observation fix on `codex/activity-unread-badge-sync` passed full-static 12/0/1
and a signed-device reproduction. A second normal like produced another
first-attempt sandbox send; opening it reduced the authoritative unread count
to zero and cleared both Activity and the Feed bell immediately without
relaunch. Foreground alert presentation,
visually observed background alert/app-icon badge behavior, terminated
notification taps, category suppression, sign-out, and production acceptance
remain.
Badge-aware v3 registration, final unread-count revalidation, worker payloads,
canonical scheduling, capability gating, and badge convergence are implemented.
In-app Activity remains available regardless of push state.

See [Notification system](NOTIFICATION_SYSTEM.md) for the precise contract and
remaining acceptance matrix.

## Current risks and gates

- Physical sandbox and production notification delivery still require the full
  signed-device matrix. Sandbox build/install/launch, permission, registration,
  preference-off/restore, terminated relaunch, one background APNs acceptance,
  unread Activity presentation, authoritative mark-one-read, and in-app routing
  passed. Immediate Activity/Feed unread propagation also passed after the
  direct-store fix. Foreground alert, alert/icon-badge observation,
  notification-tapped cold launch, category suppression, sign-out, and
  production remain.
- TestFlight archive, upload, and Alpha Friends assignment are explicitly
  authorized for 0.5.3 (6); the exact candidate still must pass Simulator and
  connected-iPhone launch before upload.
- Migration `20260825030917_post_reactions.sql` is implemented and hermetically
  verified but is not production-configured. Expressive reactions cannot be
  described as live until the normal disposable-QA and production-release
  workflow completes.
- Migration `20260826143102_profile_editorial_atlas.sql` is implemented,
  hermetically verified, and production-configured. Favorite Spot saves, public
  tagged-profile hides, owner Friends-on-profile preferences, v4 profile
  projections, and v2 anonymous profile sip lists resolve in the connected
  Mugshot project. The client retains read-only legacy fallbacks for older
  environments.
- The 44 cached reports remain open pending replacement-TestFlight acceptance.
  Consolidated local and Simulator acceptance has passed. Physical-device
  testing is not a completion gate and will run only when the owner explicitly
  promotes a candidate; see the
  [feedback ledger](TESTFLIGHT_FEEDBACK_LEDGER.md).
- The Editorial Atlas profile has separately passed its hermetic v4 database
  contract check, eight focused Swift tests, deterministic Simulator interaction
  across all four tabs, and the final same-viewport design comparison. A signed
  `iphoneos` Debug package also builds and verifies locally. After owner
  promotion, the exact source installed and launched successfully as
  `co.mugshot.app.dev` on Joe's connected iPhone. The profile migration is
  production-configured. Physical profile interaction and TestFlight
  acceptance remain unclaimed.
- Local and remote state coexist intentionally; changes must preserve account
  isolation and zero-loss draft/publication behavior.

## Verification snapshot

`./scripts/verify-no-simulator.sh full-static` passed 11 checks with zero
failures for the documentation baseline. The notification backend branch later
passed full-static 13/0/0 on 2026-08-24, including local parsing of 184 SQL
files. A data-less disposable Supabase branch then replayed to repository head
and passed all 54 remote SQL contracts plus the canonical minute worker's
fail-closed invocation. Live release then aligned all 126 migrations, preserved
the counts and whole-row fingerprints of users, visits, Activity events,
notification preferences, Home data, and Storage objects, and recorded a
scheduled protocol-v3 200 response with zero claims. This proves production
configuration, not physical notification delivery or TestFlight acceptance.
The iOS lifecycle branch subsequently passed full-static 12/0/1 (optional
`pglast` skipped), 34 focused Simulator-hosted tests, and a Simulator
build/install/launch with Activity-surface inspection. The connected-iPhone
build reached provisioning and failed closed on its stale development profile;
the App ID capability is enabled and a replacement profile was generated on
2026-08-24. After local installation and an `iphoneos`-only named-profile
selection, the signed device build and app installation passed. The first
remote launch was denied only because the iPhone was locked. After unlocking,
the app launched and the physical sandbox authorization, badge-capable v3
registration, opt-out removal, restored registration, and cold-session restore
all passed. No synthetic Activity row was inserted. A normal second-account
like subsequently produced a first-attempt sandbox send and the expected
unread Activity item; mark-one-read and in-app routing passed. The stale Feed
bell issue described above was then fixed, compiled, installed, and physically
reproduced with a second first-attempt sandbox send.

The Feed/Map feedback change passed full-static 12/0/1 on 2026-08-24. Its two
focused camera-arbitration tests compile in the Simulator-hosted app test
bundle; runtime execution and a signed-device authorized-location launch remain
queued for the next consolidated acceptance pass.

The original revised 44-report remediation branch passed 425 unit tests, eight focused
UI journeys covering signed-in/guest shell behavior, Publish, photo removal,
profile routing, and detail privacy/layout, and visual review of all 43 cached
screenshots plus the text-only caption report. Full-static passed 12/0/1 with
only the optional local `pglast` parser skipped. The final signed Debug app
(`co.mugshot.app.dev`, version 0.5.3 build 5) built, verified its development
entitlements, and installed on Joe's iPhone. The initial automated launch was
denied while the device was locked; after the third QA source batch, the exact
current source built, installed, and launched successfully on the connected
iPhone. This completes only the physical build/install/launch gate, not manual
feature acceptance, production reaction configuration, report-level physical
acceptance, or TestFlight acceptance.

The 2026-08-25 Simulator-QA follow-up passed 17 focused composer/domain tests,
the Feed reselect and Taste Passport UI journeys, full-static 12/0/1, and a
normal Simulator build/install/launch with the restored signed-in Feed visible.
Manual Publish, criterion, close-control, and cafe-detail retesting remains in
the active walkthrough. These additions are not physically or TestFlight
accepted.

The second 2026-08-25 QA source batch passed 28 focused criteria,
Feed-motion, draft-domain, and cafe-media tests plus full-static 12/0/1; the
optional local `pglast` parser was the single skip. The third batch added the
shortened Feed hold and conservative multi-ID cafe stitching; five unique
focused Feed/cafe tests, offline verification 11/0/1, normal Simulator
build/install/launch, and connected-iPhone development build/install/launch
passed. Manual motion/composer/Tiny Nook acceptance remains, so no individual
feedback report or TestFlight state is promoted.

The initial Editorial Atlas profile source passed full-static 12/0/1, four
focused Swift tests, every deterministic Simulator tab, the final same-viewport
design comparison, and a signed `iphoneos` Debug package. The 2026-08-26
follow-up has additionally passed a focused PGlite contract covering default-on
Friends plus Everyone publication, opt-out restoration to Everyone-only,
strict Private exclusion, anonymous profile links, canonical cafe stitching,
private-history Favorite Spot publication without private media, tagged hides,
and sealed direct table access; five focused Swift tests; a normal app
build/launch; rendered profile inspection; and the reason-first Add Favorite
Spot Simulator journey. Migration `20260826143102` is live, its expected
tables/RPCs resolve, and the post-migration advisors introduced no error. The
intentional sealed-table/no-policy notices and caller-bound Security Definer
warning remain documented Supabase lint behavior. Physical interaction waits
for owner acceptance; the owner-promoted development build/install/launch on
Joe's connected iPhone passed. TestFlight acceptance remains pending.

The 2026-08-26 Feed/Profile-share QA follow-up passed a normal Debug
build/install/launch, 30 focused Profile/Feed-domain tests after correcting one
exact floating-point assertion, a green focused rerun, and live Simulator
inspection of both the compact Feed header and the regenerated Profile share
grid. The current share grid matches the live newest-first public Profile grid.
A read-only production query confirmed server ordering and identified durable
private-Storage references as the client-side omission cause; no remote rows,
objects, functions, or policies were changed. Full-static passed its 11
non-Xcode stages, skipped optional `pglast`, and reproduced the known Xcode 27
generic XCTest-framework Info.plist packaging failure; the normal Simulator app
build and focused tests passed. This latest source is locally verified only and
has not been promoted to physical or TestFlight acceptance.
