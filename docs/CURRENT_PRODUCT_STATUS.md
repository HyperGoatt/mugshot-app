---
document_type: living
status: current
last_verified: 2026-08-24
---

# Current product status

## Release baseline

Mugshot is a native SwiftUI social coffee journal distributed through
TestFlight. `main` includes the Home Workbench/documentation baseline from PR
#46, notification backend v3 from PR #47, and the safe schedule cutover from PR
#48, production release evidence from PR #49, the hardened iOS notification
lifecycle from PR #50, and physical registration evidence through PR #55.
PR #56 fixed immediate Feed/Activity unread propagation, and PR #57 contains
the Feed/Map feedback fixes described below. Source remains version 0.5.3 build
5. Organizer and the 44 cached Xcode feedback packages provide direct evidence
that testers used 0.5.3 (5), superseding the earlier claim that 0.5.3 (4) was
the latest distributed candidate. The revised remediation source targets a
future 0.5.3 (6), but the project version/build is not changed and no archive or
upload is authorized by this implementation task.

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
- The remediation branch adds expressive Like/Love/Laugh/Yummy post reactions
  without replacing historical coffee-specific reactions, one-level comment
  threading, identifier-based tab behavior, compact Journal/Profile/Feed
  surfaces, direct Publish-summary editing, recoverable photo deletion, and
  address-order-invariant local cafe reconciliation.
- Share output adds only allowlisted `@handle` and coarse city/state fields plus
  safer export bounds. Publish preview geometry and the share hub/sheet actions,
  formats, templates, controls, privacy flow, defaults, and collage behavior
  remain unchanged.
- Map, saved cafe state, discovery, cafe detail, Taste Passport, reflection,
  widgets, share extension, universal links, and nearby cafe reminders.
- Feed keeps the Your Mix header to two lines with a compact first-card gap,
  and Map prevents its broad launch fallback from overwriting an
  already-authorized user's first current-location camera request.
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
- TestFlight archive, upload, and group assignment remain explicit manual gates.
- Migration `20260825030917_post_reactions.sql` is implemented and hermetically
  verified but is not production-configured. Expressive reactions cannot be
  described as live until the normal disposable-QA and production-release
  workflow completes.
- The 44 cached reports remain open pending consolidated Simulator, connected-
  iPhone runtime, and replacement-TestFlight acceptance. Consolidated local
  and Simulator acceptance has passed; see the
  [feedback ledger](TESTFLIGHT_FEEDBACK_LEDGER.md).
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

The revised 44-report remediation branch passed 425 unit tests, eight focused
UI journeys covering signed-in/guest shell behavior, Publish, photo removal,
profile routing, and detail privacy/layout, and visual review of all 43 cached
screenshots plus the text-only caption report. Full-static passed 12/0/1 with
only the optional local `pglast` parser skipped. The final signed Debug app
(`co.mugshot.app.dev`, version 0.5.3 build 5) built, verified its development
entitlements, and installed on Joe's iPhone; automated launch was denied only
because the device was locked. This is local acceptance and a partial physical
gate, not production reaction configuration, report-level physical acceptance,
or TestFlight acceptance.
