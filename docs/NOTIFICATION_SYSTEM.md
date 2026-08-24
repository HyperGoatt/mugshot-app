---
document_type: living
status: current
last_verified: 2026-08-24
---

# Mugshot notification system

## Current state

In-app Activity, notification preferences, caller-bound device registration,
the durable delivery queue, and the `deliver-activity` Edge Function are
implemented. Production APNs credentials and the production worker schedule
were configured on 2026-08-09. The archived 0.5.3 (4) app is signed with
`aps-environment=production`; source is currently 0.5.3 (5).

No document may describe remote delivery as physically accepted yet. A real
notification and tapped cold launch on a signed sandbox build and a TestFlight
production build remain acceptance gates.

## Delivery flow

1. An authoritative social mutation creates `public.activity_events`.
2. Database visibility, moderation, blocking, suspension, and category
   preference checks decide whether a per-device delivery is queued in
   `private.activity_push_deliveries`.
3. A secret-authenticated Edge worker claims fenced leases and revalidates the
   recipient immediately before APNs.
4. APNs receives an alert plus an account-bound `mugshot` envelope containing
   the activity event ID, recipient ID, and deep link.
5. The app rejects an envelope for any account other than the active confirmed
   owner and routes valid taps to Activity, a visit, a profile, or cafe lists.

Activity history does not depend on push. Disabling push or denying iOS
permission never removes in-app Activity.

## Data and security boundaries

- `notification_preferences`, `activity_events`, and `user_devices` are raw
  client-sealed tables accessed through caller-bound RPCs.
- Delivery rows are private and worker RPCs are service-role-only.
- APNs keys and service credentials live outside source control and never enter
  the client, migration text, payload logs, or analytics.
- Only APNs `Unregistered` disables a device. Configuration and transport errors
  affect the delivery and remain retryable or terminal without destroying a
  valid account binding.
- A stale worker cannot finish a newer claim because completion requires the
  delivery ID, claim token, and lease version.

## Environments

| Build | Bundle/topic | APNs host | Current status |
| --- | --- | --- | --- |
| Simulator | none | none | In-app Activity only; push unavailable by design |
| Physical Debug | `co.mugshot.app.dev` | sandbox | Apple App ID/backend topic configured; client entitlement work is in this sprint |
| Release/TestFlight | `co.mugshot.app` | production | Signed and production configured; physical delivery acceptance pending |

## User controls

Push has a master toggle and category controls for friend posts, tags,
collaborative lists, likes, comments and mentions, reactions, and friend
requests. Friend-post delivery remains the alpha all-friends experiment.
Per-friend mute is deferred unless feedback demonstrates a concrete need.

## Failure behavior

- Missing backend capability, permission denial, registration failure, worker
  failure, or APNs failure leaves Activity available.
- Signed-out and cross-account pushes are rejected.
- Offline sign-out clears local presentation immediately and marks ownership
  uncertain until the server confirms cleanup or a later account reclaims the
  installation.
- Blocked, moderated, private, removed, or suspended content is suppressed
  before delivery and checked again before opening.

## Acceptance and operations

The complete gate covers foreground, background, terminated launch, deep links,
read state, badge convergence, preference-off, sign-out, token rotation,
blocking, and inaccessible content in sandbox and production. Use normal product
actions between disposable/test accounts; never insert synthetic production
activity rows.

Monitor delivery outcomes, retry volume, disabled devices, registration counts
by environment, category opt-outs, and tester reports. Never monitor message
content, push tokens, social identifiers, or deep-link identifiers.
