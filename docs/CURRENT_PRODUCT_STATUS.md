---
document_type: living
status: current
last_verified: 2026-09-17
---

## Central Home entry enabled for owner QA — 2026-09-17

Current source removes the temporary Home placeholder gate. Central Add > Log a
Sip > Home now opens the unified Home quick log, and Journal > Home retains the
full My makes / Recipes workspace. The change does not migrate or rewrite Home
data and does not alter the production backend. TestFlight 0.5.3 (8) remains the
previous distributed artifact with the placeholder; a replacement has not been
uploaded or assigned. The signed `co.mugshot.app.dev` candidate compiled,
installed, and launched on Joe's iPhone; hands-on Home acceptance is in progress.

## TestFlight 0.5.3 (8) battery patch — 2026-09-16

Build 8 keeps marketing version 0.5.3 and packages both battery remediations for
replacement TestFlight distribution. It also restores regular-weight Feed and
detail captions, restores the personal Map legend title to **Your ratings**, and
temporarily routes central Add > Log a Sip > Home to a **Home is under
construction** placeholder with a return to cafe logging. Existing Home/Recipes
data and Journal collections are preserved.

The source changes and build-number increment are implemented. Focused Simulator
checks passed for the Home placeholder, its return-to-cafe action, the personal
Map legend, and caption presentation policy. The signed build-8 Debug candidate
also built, installed, and launched on Joe's connected iPhone. The Release
archive and local App Store Connect export passed. Xcode Organizer uploaded the
build at 4:32 PM EDT, App Store Connect completed processing, and build record
`db5a2bb5-697c-40e6-9617-d8ba48825167` is `Testing` for Mugshot Team and Alpha
Friends. The battery-focused testing notes were published with automatic tester
notifications enabled. Hands-on TestFlight acceptance remains pending. No
Supabase environment, schema, production data, or App Store release changed.

## Battery and thermal remediation release hold — 2026-09-16

The confirmed build-7 location lifecycle defect is remediated in current source.
Continuous best-accuracy updates now belong only to the visible Map while its
scene is active. Permission transitions and cafe search use one-shot requests,
manager teardown stops standard updates, and inactive scenes stop Map updates.
Opt-in nearby reminders retain region behavior while skipping empty and unchanged
configurations; significant-change monitoring requires Always authorization and
at least one eligible saved cafe. Visit and Home recovery tasks cancel on
inactivity and resume from durable state after activation.

Physical instrumentation also caught a new source-only regression introduced by
battery-remediation commit `038aad5`: successful Home recovery called itself
again with no pending work. On the signed development build, that produced 119
Home/Supabase synchronization starts in about 15 seconds, all with zero pending
operations and zero photo transfers. The recursive completion call is removed.
Home recovery now runs once for account/foreground/network eligibility and once
for each real non-nil pending operation. TestFlight 0.5.3 (7) predates this
recursive call; the loop is not evidence for the original build-7 incident.

Current source also contains a privacy-safe physical profiling layer. Debug builds
emit transition-only signposts and bounded counters for lifecycle, thermal and
power state, network availability, location ownership and delivery, nearby-reminder
wakes, recovery, Home synchronization, and visit-photo transfers. MetricKit stores
at most 20 protected payloads locally in the Debug app container. Coordinates,
content, identifiers, filenames, URLs, and error descriptions are excluded; Release
recorders are no-ops and no diagnostics are uploaded.
The physical Debug product and executable are named `MugshotDiagnostics` so
Instruments can distinguish them from the simultaneously installed production
app; bundle identities and Release packaging are unchanged.

Tier 4 evidence is green for the implemented foreground fix. Generic Debug
app/test compilation and hermetic backend contracts passed; 17 distinct focused
location/reminder/recovery/diagnostic tests and one permitted-location repeated-tab
UI test passed on an iOS 27 Simulator. The new regression test requires exactly
one Home recovery pass per trigger. The optimized Release build also passed and
its binary contains none of the diagnostic event or MetricKit storage strings.

The signed instrumented development candidate built and installed as
`co.mugshot.app.dev` on Joe's iPhone 16 Pro without replacing `co.mugshot.app`.
Physical Power Profiler, Time Profiler, and Logging captures launch the intended
development process and are symbolicated. Before the Home-loop fix, settled
seconds 6–20 contained 1,250 one-millisecond running samples, about 8.9% of one
core, and roughly 115–125 KiB of continuing network traffic every five to six
seconds. After the fix, the same interval contained 3 samples, about 0.02%, and
zero network bytes. Logging recorded one Home synchronization rather than 119.
Both short Power Profiler captures remained nominal thermally. The location-energy
interval was also shorter after the fix, but the warmed location cache makes that
difference uncontrolled and it is not attributed to the Home change.

Owner physical acceptance then passed the first charging and Map-to-lock battery
check on the fixed candidate. With Mugshot open, the displayed level rose from
37% to 53% during ten minutes plugged in. It remained at 53% across a 30-minute
unplugged interval consisting of two minutes on Map followed by a locked phone.
The original failure-to-charge symptom did not recur. This is one physical arm,
not a matched control; displayed percentages are coarse and device temperature
was not reported.

A matched force-quit control, movement, reminder-on/off, media retention,
interrupted upload, explicit thermal observation, and repeated extended-discharge
acceptance remain open. TestFlight 0.5.3 (7) still contains the original location
defect; build 8 is the distributed replacement. TestFlight distribution changed,
but no Supabase environment, production data, or App Store release changed. See the
[original audit](audits/BATTERY_THERMAL_RUNTIME_AUDIT_2026-09-16.md) and
[instrumented validation](audits/BATTERY_DIAGNOSTICS_VALIDATION_2026-09-16.md).

## Native Home and Recipes — 2026-09-16

The complete native Home/Recipes plan remains implemented and
production-configured. Its contract remains deployed through
`20260916020417_home_recipe_http_conflicts.sql`; the shared production database
is now aligned at all 179 repository migrations through
`20260917204208_people_discovery_foreign_key_indexes.sql`. The explicit
stored-off flag remains a rollback switch and does not remove saved recipe or
journal data.

Build 8 historically gates central Add > Log a Sip > Home with an
under-construction placeholder. Current source supersedes that client behavior
with the unified quick log. The Journal collections and stored Home/Recipes data
remain available; neither behavior deletes, migrates, or rewrites Home content.

The source includes template-first progressive recipe creation, two-surface quick
logging, espresso/pour-over/cold-brew guidance, flexible components and drinks,
exact-version linking, custom fields, immutable history, comparison and repeat,
discovery/adaptation, private-save-first posting, explicit attachments, durable
recovery, private media synchronization, owner export, and conflict review.

All 65 SQL contracts passed against an isolated 177-migration database. Real
Auth/API/Storage transport plus all 21 Home model/store tests passed on iOS 26.3.
The complete connected journeys and largest Dynamic Type route pass. The synthetic
branch was deleted after acceptance. The live cutover preserved every recorded
content fingerprint, row count, Storage object count, and bucket visibility value.
All 22 focused Home tests pass with the activation behavior, and the signed Debug
candidate is installed, launched, and running on Joe's iPhone. Hands-on and
TestFlight acceptance remain owner-promoted gates. See
[implementation and acceptance status](HOME_RECIPES_IMPLEMENTATION.md).

## Zoom-adaptive Map pins — 2026-09-14

The Map tab represents each located cafe as an individual travel pin at every
camera scale. Pins retain their rating-band color and geographic coordinate as
the camera moves. Their visible head scales continuously from 7 points at world
scale to 30 points at neighborhood scale, while the annotation keeps a 44-point
interactive target. Rating text appears only at close scale and uses separate
reveal and hide thresholds to avoid flicker during small zoom adjustments.

The Map updates the artwork of visible annotation views during camera movement;
it does not replace cafe annotations with clusters or regional cards. Canonical
cafe deduplication, score projections, the ratings legend, cafe-detail routing,
and accessible score descriptions keep their existing contracts. Profile maps
retain their separate Profile-only individual-pin presentation.

Local verification passed the Tier 3 full-static gate (12 passed, zero failed,
one optional skip), 14 focused Map tests, and a Simulator interaction test that
captured neighborhood, city, and world states and reopened cafe detail from a
pin. The same Debug candidate was installed and launched on Joe's connected
iPhone. Physical visual acceptance and TestFlight acceptance remain separate
pending gates.

## 2026-09-14 — Physical-device performance regression follow-up

Owner testing of `62991fa` reported text-input freezes, carousel loss after post
detail, page reset after scrolling, and image disappearance in the app switcher.
Two retrieved iPhone watchdog reports show synchronous UIKit image-pasteboard
probing while opening the keyboard, with negligible app CPU; this is distinct
from network latency. A Simulator stack capture reproduced the blocked system
pasteboard service. Plain-text UIKit configurations did not eliminate the wait
and were removed; standard SwiftUI fields remain. After disabling Simulator clipboard synchronization and restarting the Simulator,
the standard-input response-time test passed in 36.95 seconds for the full journey;
repeated Map focus-to-typing transitions took approximately 0.34 seconds. The
previous run stalled 33–58 seconds at one field. The physical-device freeze remains
unaccepted pending system-service recovery and retesting on that iPhone.

Feed social-state updates retain the complete photo collection, and Feed-owned
page selection survives recycled rows. Authorized images remain visible during
inactive app-switcher transitions until their existing expiry; background,
account changes, access revocation and expiry still hide protected pixels.
Profile header and post requests run concurrently and render before secondary
sections finish. No authorization lifetime has been extended.

The owner confirmed reminder preferences persist after tapping Save. A navigation
bar Save action and unsaved-change message clarify that explicit activation step.
This is a usability adjustment, not a backend persistence repair.

Verification: the Tier 3 full-static gate passed (12 passed, zero failed, optional
pglast skipped); focused photo-selection, photo-metadata and protected-image tests
passed. The bounded keyboard journey passed after Simulator clipboard isolation.
No crash-free physical acceptance or overall loading-speed benchmark is claimed.
No backend migration, TestFlight upload or marketing-version change is involved.

## TestFlight feedback follow-up candidate — 2026-09-14

The 14-report follow-up is implemented on
`codex/testflight-feedback-followup` while keeping marketing version 0.5.3. It
uses Apple's standard still-photo camera, completed-Mugshot personal Map
averages, individual Profile cafe pins, bounded per-record publication recovery,
normalized Instagram destinations, canonical cafe actions, Feed photo paging,
published caption presentation, structured Sip/Cafe/Setting journal headings and the
approved Feed copy.

On this day and Weekly reflection reminders are opt-in and require a new explicit
save before delivery activation. The client reports its current IANA timezone and
destination capability. The backend stores a private occurrence queue and
per-installation receipts, evaluates local schedules every five minutes, and
revalidates preference, master push state, account, target ownership,
eligibility and installation immediately before sending. Push copy contains no
caption, journal text, cafe name or photo. Migrations `20260914191634` and
`20260914204700` plus the `deliver-reflections` worker are deployed. The latter
bounds the deterministic APNs collapse identifier to 47 bytes. The server
delivery switch migrated off, then was enabled after database, worker and
APNs-configuration health checks.
At activation there were zero delivery-active preferences, occurrences or
deliveries, so only a future explicit compatible save can enter the queue. The
20:40 UTC scheduled dispatch returned HTTP 200 with zero enqueued, claimed, sent,
failed or cancelled work, and the queue remained empty afterward.

Focused Swift, worker and isolated database contracts pass. The consolidated
Simulator session exercised Feed paging and cafe routing, Profile pins, personal
Map scores and explanation, structured journal headings, recovery Review and dock
stability. Physical camera capture, visually observed APNs delivery and
replacement-TestFlight acceptance are still pending and must not be inferred
from local checks.

## TestFlight 0.5.3 (7) — 2026-09-14

Build 7 keeps marketing version 0.5.3 and contains the current merged product,
moderation, sharing, regression-repair, reaction, and explicit-profile-identity
work. The exact candidate compiled, installed, and launched on the booted iPhone
16 Pro Simulator and on Joe's connected iPhone. The exact `main` source at
`bead2de` then passed the Release archive gate, uploaded successfully, completed
App Store Connect processing, and entered `Testing` for Mugshot Team and Alpha
Friends, including 12 external testers. The 90-day testing window is active. No
App Store release was submitted. The owner set the standing beta **What to
Test** copy to `Welcome to Mugshot`.

## Explicit profile identity setup — 2026-09-14

The next candidate no longer treats a collision-safe signup username as the
account owner's chosen public handle. Production evidence showed that affected
accounts reached the existing setup screen, but its prefilled generated value
could be accepted unchanged. The new profile contract records explicit username
confirmation separately, reopens setup only for accounts still matching the
exact legacy email/account-ID placeholder pattern, and changes no username or
other user-selected profile value during migration. New and affected accounts receive an empty
**Choose your username** field; setup-state failures show Retry and Sign out
instead of silently entering the app. The server also rejects an unchanged
generated placeholder submitted by an older client. After identity and optional profile media,
bio, location, favorite drink, Instagram, and website, an optional second step
reuses the existing protected Favorite Spots editor for up to three cafes.

Implemented on `codex/profile-setup-username-confirmation`; production migrations
172–173 are configured. The production username fingerprint remained unchanged
across all 18 profiles, while the eight exact generated-placeholder accounts now
require a choice. The additive confirmation backfill advanced the standard
`updated_at` bookkeeping field on already-confirmed rows; no user-selected profile
value changed. Full-static passed 12/0/1, with only optional `pglast` skipped, and
the focused profile contract passed. A signed Debug build then compiled, installed,
and launched as `co.mugshot.app.dev` on Joe's connected iPhone. Interaction with the
reopened setup path remains owner acceptance because Joe's confirmed account does
not trigger it.
Existing intentional usernames and permanent readable-link aliases remain unchanged.

## Reaction presentation follow-up — 2026-09-14

Full-post reaction totals now sit in the action row before Save. Yummy uses a
coffee mug icon throughout the native reaction controls and people viewer.
Presentation-only follow-up; reaction data and sharing behavior are unchanged.

## Regression repair candidate — 2026-09-14

Implemented on `codex/regression-repair-reactions`; production migration 171 and
`deliver-activity` are deployed. The dev build is installed and launched on Joe’s
iPhone; owner acceptance remains pending. This candidate retains visited tabs by account,
reuses fresh lists for 60 seconds, caches protected image pixels only in bounded
memory with renewed authorization, restores actor/action Activity and push copy,
adds comment-author navigation and reaction people, removes routine sharing-status
banners from post detail, and makes detail captions larger than journal notes.
No posts, photos, audiences, reaction rows or notification history are rewritten.
See [regression delivery checklist](REGRESSION_REPAIR_STATUS.md) for exact gates.


## Current moderation amendment — 2026-09-14

Production now uses synchronous server-side blocked-term validation for shared text
and report-driven human moderation for photos and other shared content. OpenAI
provider execution is removed, its worker endpoint returns 410, its schedule is
retired, and its five server configuration secrets are removed. Migration history
is 170. Existing reporting, retry deduplication, block enforcement, operator alerts,
review decisions and appeals remain. The five initial English rules target explicit
threats, exploitation and slurs; they are a narrow blocklist, not semantic analysis
or a guarantee of App Review approval. Private journal text remains excluded.

The transition preserves prior provider evidence in sealed receipts, retains actual
flags and human restrictions, and labels technical waits `reactive_policy_transition`,
not a successful photo screening. Original posts, photos, audience selections,
profile hides, blocks and all 72 checked data tables were unchanged by the cutover.
Amanda's historical Friends Matcha post remains public under the separately approved
restoration policy. Two missing photo references are preserved; this change does
not recreate missing files.

The native profile grid now offers long-press **Hide from my profile** on authored
and tagged posts, with Undo after a successful save. Tagged posts also retain
Remove my tag in that menu. The inline tagged-card ellipsis is removed. Hiding is
profile-specific and does not delete a post or alter another person's profile.
The existing detail control remains an additional route to show a hidden post.

Verification: isolated local/reactive SQL contract passed (validation rollback,
Private withdrawal, real-decision preservation, no dispatch, protected rules);
historical profile visibility contract passed; four human-review media tests passed;
Debug iPhone compilation passed. Production verification reports 143 sharing-allowed records, zero pending/service
issues and zero Private-post jobs; the original human review event is preserved.
The dev build was installed and launched on Joe’s iPhone (0.5.3 build 6); long-press
interaction awaits owner acceptance. Public disclosure builds passed. No TestFlight or App Store submission.

## Earlier implementation evidence (superseded for moderation)

The sections below document earlier repair work. Their descriptions of active
OpenAI screening are historical; the amendment above is the current behavior.


# Current product status

> Current repair: [Repair and sharing status](REPAIR_SHARING_STATUS.md) supersedes
> the earlier delivery and acceptance statements below for moderation, Friends
> publication, profile sharing and the reported native bugs. Those earlier
> checkpoints remain evidence of the previous candidate, not this repair's acceptance.


Sprint 1 is staged on production for the owner's real-account dev-build test.
Readable profile links, screening/review and updated server contracts are deployed.
The signed dev build 0.5.3 (6) is installed on the owner's iPhone, configured for
production; the real feed and photos visibly loaded. No TestFlight upload or
App Store submission was performed. Owner acceptance with real data is pending.

The atomic update preserved all 72 original tables, including 80 posts and all
notification text. All 331 Storage objects remain. Encrypted photo-byte recovery
and an isolated typed database-data restore (72 tables / 6,036 rows) passed.
For compatibility with existing installs, original bucket visibility remains:
legacy profile/visit buckets are still public; the Private bucket stays private.
The final bucket-privacy cutover awaits compatible-client distribution/adoption.
New native/web readers use caller-authorized signing.

OpenAI sharing choices were reloaded and verified Disabled before activation.
Screening is enabled; existing shared revisions retain their audience visibility
while pending, and Private visits have zero screening jobs. Joe's creator account
has founder review access. Scheduled deletion worker HTTP 200 is verified.
PostHog erasure remains disabled pending its prior provider verification; real
Apple revocation remains unverified. Do not test account deletion on the owner's
real account as an acceptance shortcut. All disposable QA branches are deleted.

Current evidence: [Sprint 1 tracker](SPRINT_1_TRACKER.md) and
[staged rollout](SUPABASE_RELEASE_WORKFLOW.md#staged-production-owner-test--september-14).

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
explicitly authorized the 0.5.3 (6) release and reported that device QA was
already complete, waiving a redundant connected-iPhone rerun. The exact
`b498d92` candidate passed Simulator and Release archive gates, uploaded at
9:37 PM EDT on 2026-08-26, completed App Store Connect processing, and is now
`Testing` for Mugshot Team and Alpha Friends with the published note
`Welcome to Mugshot!`.

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
- Current source presents the Option 1 People hub: incoming requests first,
  private contact invite/share/QR actions, horizontal explainable suggestions,
  then friends and sent requests. Contacts now chooses one phone recipient for a
  native Messages invitation; the number remains device-local and is not used for
  account matching. `people_v2` adds mutual, shared-context, and recent visible
  interaction signals with default-on missing preferences and explicit opt-outs.
  The client is implemented and passed Simulator visual QA. The additive
  `people_v2` migration is production-configured and verified with unchanged
  protected row counts. The exact source is installed and launched as
  `co.mugshot.app.dev` on Joe's connected iPhone; hands-on interaction and
  TestFlight acceptance remain separate.
- The shared owner/friend profile uses the approved Editorial Atlas layout: a
  compact 112-point photographic banner with a foam-white tappable
  Friends/Sips/Cafes dock, streamlined identity/actions, up to three compact
  owner-selected Favorite Spots, and Mugshots, cafes, exploration map, and
  tagged tabs. Sparse friend profiles collapse identity metadata and social
  links into a wrapping detail rail and do not render the former Taste overlap
  card. Favorite Spot creation presents all six reason categories at once and
  includes a visible custom descriptor path. The Cafes tab keeps one stable
  scroll owner around its lazy card grid. Friends Mugshots stay in Friends Feed and
  require versioned, explicit consent before appearing on public profiles in
  Sprint 1 source. Legacy default-on preferences do not count as consent;
  Private Mugshots never appear. This migration is not production deployed.
  Favorite Spots may originate
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
- TestFlight 0.5.3 (6) is uploaded, processed, and `Testing` for Mugshot Team
  and Alpha Friends. The exact `b498d92` source passed Simulator and archive
  gates. The owner reported completed connected-iPhone QA and explicitly
  waived a redundant post-sync device rerun; Codex did not repeat that install.
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
build and focused tests passed. This source is included in processed TestFlight
build 0.5.3 (6). Distribution is verified; hands-on replacement-build
acceptance remains pending and no feedback reports have been closed from the
upload alone.
