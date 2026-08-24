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
were configured on 2026-08-09. Source on
`codex/notification-backend-v3` adds the badge-aware v3 contracts and a
canonical one-minute schedule. Those changes are locally and disposable-QA
verified but are not production-configured until the live release workflow
closes.
The archived 0.5.3 (4) app is signed with `aps-environment=production`; source
is currently 0.5.3 (5).

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
| Physical Debug | `co.mugshot.app.dev` | sandbox | Apple App ID/backend topic configured; client entitlement work is in this sprint |
| Release/TestFlight | `co.mugshot.app` | production | Signed and production configured; physical delivery acceptance pending |

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
replaced by the canonical definition. Production continues using the schedule
configured on 2026-08-09 until this forward migration is released.

`supabase/config.toml` sets `deliver-activity.verify_jwt=false` because this is
a service-only endpoint, not a user-JWT endpoint. The function independently
performs a constant-time comparison of the `apikey` header with
`ACTIVITY_DELIVERY_WORKER_SECRET` when configured, falling back to the
branch/project admin key for compatibility. The caller credential and the
admin key used for service-role RPCs are resolved separately, so a dedicated
cron credential does not become a database credential.

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

No signed-device or TestFlight v3 acceptance evidence has been recorded yet.
Evidence on 2026-08-24 is full-static verification 13/0/0, including parsing all
183 SQL files, plus a data-less disposable branch replayed to
`20260824165630` with all 54 remote SQL contracts passing. QA held exactly one
minute worker job; its authenticated calls reached the expected fail-closed
`push_configuration_required` response because APNs credentials were
deliberately absent.
