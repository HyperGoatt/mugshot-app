---
document_type: living
status: current
last_verified: 2026-08-24
---

# Mugshot notification system

## Current state

In-app Activity, notification preferences, caller-bound device registration,
the durable delivery queue, and the `deliver-activity` Edge Function are
implemented. Production APNs credentials, the badge-aware v3 contracts, worker
version 6, and the canonical one-minute schedule are live. The 2026-08-24
release restored the schedule after read-only inventory found the previously
recorded job absent.
The archived 0.5.3 (4) app is signed with `aps-environment=production`; source
is currently 0.5.3 (5). Source build 5 now includes the badge-aware iOS v3
lifecycle, signed sandbox Debug path, and production Release environment
selection. It has passed a generic Debug app/test compile, deterministic tests,
and a focused Simulator runtime gate. Physical acceptance remains a gate until
recorded below.

No document may describe remote delivery as physically accepted yet. A real
notification and tapped cold launch on a signed sandbox build and a TestFlight
production build remain acceptance gates.

## Delivery flow

1. An authoritative social mutation creates `public.activity_events`.
2. Database visibility, moderation, blocking, suspension, and category
   preference checks decide whether a per-device delivery is queued in
   `private.activity_push_deliveries`.
3. A secret-authenticated Edge worker claims fenced leases and revalidates the
   recipient immediately before APNs. V3 revalidation also returns the
   authoritative visible unread count and the installation's badge capability.
4. APNs receives an alert plus an account-bound `mugshot` envelope containing
   the activity event ID, recipient ID, and deep link. Only an installation
   registered as badge-capable receives `aps.badge`; the envelope is unchanged.
5. The app rejects an envelope for any account other than the active confirmed
   owner, requests an account-bound Activity refresh before tap routing, and
   routes valid taps to Activity, a visit, a profile, or cafe lists.
6. Successful Activity refreshes, read actions, tag removal, activation,
   sign-out, and deletion synchronize the app icon to the authoritative visible
   unread count. Cross-device changes converge on activation or the next push.

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

## Versioned backend contract

- `user_devices.supports_badge_sync` is non-null and defaults to `false`.
- `register_user_device_v2(uuid,text,text)` remains executable by authenticated
  clients. A device that has never used v3 therefore receives the original
  badge-free payload.
- `register_user_device_v3(uuid,text,text,boolean)` delegates token validation,
  account checks, churn control, token ownership, and device caps to v2, then
  records the caller installation's badge support without returning its token.
- `revalidate_activity_push_delivery_v2(uuid,uuid,bigint)` remains available to
  the service role during the compatibility window.
- `revalidate_activity_push_delivery_v3(uuid,uuid,bigint)` is service-role-only
  and returns final eligibility, authoritative visible unread count, and badge
  support after the v2 fence passes.
- `get_backend_capabilities_v1()` keeps contract version 1 and adds the Boolean
  `push_badge_sync` flag under schema release
  `2026-08-24-activity-push-badge-v3`.

## Environments

| Build | Bundle/topic | APNs host | Current status |
| --- | --- | --- | --- |
| Simulator | none | none | In-app Activity only; push unavailable by design |
| Physical Debug | `co.mugshot.app.dev` | sandbox | Development entitlement and `MUGSHOT_PUSH_SANDBOX` source path implemented; Push Notifications is enabled for the App ID; replacement development profile is staged but not generated/downloaded/installed |
| Release/TestFlight | `co.mugshot.app` | production | Production entitlement and `MUGSHOT_PUSH_CAPABLE` source path implemented; physical delivery acceptance pending |

The client models these values as `ActivityPushEnvironment.sandbox` and
`.production`; it never derives an APNs host or topic from server data.

## Worker scheduling

`20260824163143_activity_delivery_schedule_v3.sql` owns the canonical
`mugshot-activity-delivery-v3` `pg_cron` job. It runs every minute and invokes
`deliver_v3` through `pg_net`. The endpoint and `apikey` value are read at
execution time from the single Vault entries
`mugshot_activity_delivery_worker_url` and
`mugshot_activity_delivery_service_role`; no credential is stored in SQL or the
job command, and disposable QA can target its own worker.

Installation fails closed when either Vault entry, `pg_cron`, or `pg_net` is unavailable,
when more than one delivery job exists, or when the one existing job contains
an embedded credential. At most one safe existing delivery job is adopted and
replaced by the canonical definition. The 2026-08-24 live inventory found no
Activity delivery job or Activity Vault entries, despite the earlier deployment
record; this migration restored the missing durable schedule.

`20260824171405_expire_pre_schedule_activity_backlog.sql` is the one-time live
cutover guard. It cancels only pending delivery attempts older than 15 minutes
with `pre_schedule_backlog_expired`; it does not delete or suppress the
authoritative Activity event. Fresh queued work and any already processing
lease remain untouched.

Production has exactly one active `mugshot-activity-delivery-v3` job. Its first
post-activation evidence at 2026-08-24 17:21 UTC was HTTP 200, protocol version
3, with zero claims after 69 stale attempts were safely expired. All five
pre-v3 production device records defaulted to badge support off.

`supabase/config.toml` sets `deliver-activity.verify_jwt=false` because this is
a service-only endpoint, not a user-JWT endpoint. The function independently
performs a constant-time comparison of the `apikey` header with
`ACTIVITY_DELIVERY_WORKER_SECRET` when configured, falling back to the
branch/project admin key for compatibility. The caller credential and the
admin key used for service-role RPCs are resolved separately, so a dedicated
cron credential does not become a database credential.

Supabase's security advisor reports the authenticated `SECURITY DEFINER` v3
registration RPC. This is intentional: the sealed device table cannot be
written directly, and the function binds the device mutation to `auth.uid()`
through the already hardened v2 contract. The service-only v3 revalidation RPC
is not client-executable.

## User controls

Push has a master toggle and category controls for friend posts, tags,
collaborative lists, likes, comments and mentions, reactions, and friend
requests. Friend-post delivery remains the alpha all-friends experiment.
Per-friend mute is deferred unless feedback demonstrates a concrete need.

Notification authorization is shared with nearby cafe reminders. A permission
change performs one account-checked registration reconciliation; a nearby
reminder may request local notification permission on Simulator without
claiming that remote Activity push is supported there.

## iOS lifecycle boundary

- `BackendCapabilitiesV1` loads at account activation. Missing, malformed, or
  incomplete Activity, preference, registration, or badge capability disables
  remote registration and names the unavailable layer while Activity continues.
- `NotificationAuthorizationProviding`, `RemoteNotificationRegistering`,
  `ActivityDeviceServicing`, `ActivityNotificationClientCreating`, and
  `ActivityBadgeUpdating` isolate Apple and Supabase effects for deterministic
  coordinator tests. The shared coordinator remains the production owner.
- `AccountBoundActivityUpdateSignal` connects accepted foreground pushes and
  taps to the active Activity store. Cold-launch refresh intent remains queued
  until the matching session restores; another account cannot consume it.
- APNs token rotation reuses the installation ID, reclaims ownership through
  v2, and registers through v3 with `supports_badge_sync=true`. Tokens and
  account/content identifiers never enter analytics.

## Failure behavior

- Missing backend capability, permission denial, registration failure, worker
  failure, or APNs failure leaves Activity available.
- Signed-out and cross-account pushes are rejected.
- Offline sign-out clears local presentation immediately and marks ownership
  uncertain until the server confirms cleanup or a later account reclaims the
  installation.
- Blocked, moderated, private, removed, or suspended content is suppressed
  before delivery and checked again before opening.

The client records only coarse education source, permission result,
registration result/environment, preference category/value, Activity open
source, and route outcome. It never records push tokens, actor IDs, visit IDs,
notification content, or deep links.

## Troubleshooting

- Capability missing or malformed: do not register; keep Activity available and
  report backend capability as the unavailable layer.
- Registration rejected: confirm the active account, token format, build APNs
  environment, device cap, and churn bound without logging the token.
- Worker not draining: inspect the single cron job, recent `pg_net` responses,
  Edge Function health, lease/retry counts, and Vault-secret presence.
- `BadDeviceToken`: verify the build entitlement, bundle topic, APNs host, and
  registration environment. Only APNs `Unregistered` retires the device row.
- Badge mismatch: compare v3 capability on the installation with
  `activity_unread_count_v1()` after visibility filtering; never infer the
  count from locally cached Activity rows.

## Acceptance and operations

The complete gate covers foreground, background, terminated launch, deep links,
read state, badge convergence, preference-off, sign-out, token rotation,
blocking, and inaccessible content in sandbox and production. Use normal product
actions between disposable/test accounts; never insert synthetic production
activity rows.

Monitor delivery outcomes, retry volume, disabled devices, registration counts
by environment, category opt-outs, and tester reports. Never monitor message
content, push tokens, social identifiers, or deep-link identifiers.

No signed-device or TestFlight v3 delivery evidence has been recorded yet. On
2026-08-24, the iOS branch passed full-static verification 12/0/1; the only
skip was the optional local `pglast` parser. Thirty-four focused
Simulator-hosted tests passed: 12 coordinator lifecycle tests, 15 Activity and
badge/signal tests, and 7 privacy-safe analytics tests. A normal Simulator
build installed and launched, and the deterministic app fixture opened the
Activity surface; the fixture intentionally had no live signed-in session, so
it displayed the account-safe session-change state. Environment tests verify
that Simulator remote push reports signed-device unavailability while in-app
Activity remains available.

The connected iPhone build resolved `co.mugshot.app.dev`, the development
entitlement, and `MUGSHOT_PUSH_SANDBOX`, then failed closed because Apple's
current development profile lacks the Push Notifications capability and
`aps-environment`. No entitlement was removed or bypassed. Push Notifications
was subsequently enabled for the Debug App ID without creating legacy SSL
certificates because Mugshot uses token-based APNs authentication. The
replacement profile is staged with the existing development certificate and
registered iPhone but is not yet generated or installed. The earlier backend
release replayed all 126 migrations to `20260824171405`, passed all 54 remote
SQL contracts, preserved protected product/content fingerprints, activated
worker version 6, and recorded a scheduled protocol-v3 HTTP 200 with no pending
work. Physical delivery remains unaccepted.
