---
document_type: living
status: current
last_verified: 2026-08-24
---

# Current product status

## Release baseline

Mugshot is a native SwiftUI social coffee journal distributed through
TestFlight. `main` includes the Home Workbench and documentation baseline from
merged PR #46. Active notification backend work is isolated on
`codex/notification-backend-v3`. Source remains version 0.5.3 build 5; the most
recent archived distributed candidate is 0.5.3 (4).

The Home Workbench branch is implemented and passed the repository full-static
no-Simulator gate on 2026-08-24. Its backend migrations are present in source;
living documentation does not assume a migration is live until deployment
evidence confirms it.

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
- Map, saved cafe state, discovery, cafe detail, Taste Passport, reflection,
  widgets, share extension, universal links, and nearby cafe reminders.
- In-app Activity with unread count, pagination, read actions, notification
  category preferences, and account-bound deep links.
- Caller-bound APNs registration and a durable Supabase delivery worker with
  production credentials; the missing durable schedule is being restored by
  the current release.

## Data authority

Supabase is authoritative for signed-in identity, public and social content,
visits, media references, cafe state, friends, safety, lists, Activity, device
registration, and Home library data. Account-scoped local stores remain
authoritative for guest data, unfinished drafts, pending submissions, cached
media, UI preferences, recovery commands, and offline presentation until a
remote write succeeds.

No local sample, cache, or fallback count may be presented as remote truth.

## Notification status

The notification system is implemented but not yet fully production-scheduled
or physically accepted. The Release/TestFlight app carries the production APNs
entitlement and the backend worker has both Apple topics. Physical Debug currently
lacks its sandbox entitlement and lifecycle hardening; those are active sprint
work. Badge-aware v3 registration, final unread-count revalidation, worker
payloads, and canonical scheduling are implemented and locally verified in
source but not yet production-configured. In-app Activity remains available
regardless of push state.

See [Notification system](NOTIFICATION_SYSTEM.md) for the precise contract and
remaining acceptance matrix.

## Current risks and gates

- Physical sandbox and production notification delivery, cold launch, deep
  links, and account lifecycle still require signed-device acceptance.
- TestFlight archive, upload, and group assignment remain explicit manual gates.
- Home Workbench and notification v3 migrations passed the data-less Supabase
  QA gate and must still complete the live snapshot, dry-run, deployment, and
  drift closure before the client relies on them in production.
- Local and remote state coexist intentionally; changes must preserve account
  isolation and zero-loss draft/publication behavior.

## Verification snapshot

`./scripts/verify-no-simulator.sh full-static` passed 11 checks with zero
failures for the documentation baseline. The notification backend branch later
passed full-static 13/0/0 on 2026-08-24, including local parsing of 184 SQL
files. A data-less disposable Supabase branch then replayed to repository head
and passed all 54 remote SQL contracts plus the canonical minute worker's
fail-closed invocation. This proves source and disposable-QA readiness, not
production configuration, physical notification delivery, or TestFlight
acceptance.
