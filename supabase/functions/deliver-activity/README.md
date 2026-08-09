# Activity delivery worker

Deployment status: version 1 is active in the live Supabase project. In-app
activity is fully available. On 2026-08-09 the Candlewood Coffee LLC team-scoped
APNs key, both environment topics, and the durable schedule were installed in
production; the worker status endpoint reports `pushDelivery: configured`.
Physical-device delivery and tapped cold-launch routing still require the
planned first-build acceptance pass.

A provider-token probe against both Apple hosts returned `BadDeviceToken` for
an intentionally invalid token on 2026-08-09. That is the expected proof that
Apple accepted the key, team, and each topic without risking a real device
notification.

Deployment readiness requires:

- APNs-enabled App IDs for both physical Debug
  (`co.mugshot.app.dev`) and distribution
  (`co.mugshot.app`), with signed `aps-environment` and Sign in with
  Apple entitlements matching each provisioning profile;
- `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`,
  `APNS_SANDBOX_TOPIC=co.mugshot.app.dev`, and
  `APNS_PRODUCTION_TOPIC=co.mugshot.app` secrets;
- a service-to-service invocation with the Supabase secret key in the `apikey`
  header;
- platform JWT verification disabled for this service-only endpoint, because the
  caller authenticates with the secret-key header rather than a user JWT;
- a scheduler or database webhook that invokes `{"action":"deliver_v2"}`.

The worker never trusts a client-supplied user ID, never logs a push token, and
claims tokens only through the service-role-only `claim_activity_push_batch_v2`
RPC. Each claim includes the authoritative recipient ID, which is placed inside
the signed APNs payload so cold-launch deep links can be persisted before Auth
restoration and consumed only by that account. Each claim returns a token and
monotonically increasing lease version; both are required by
`complete_activity_push_delivery_v2`, so a stale worker cannot complete a newer
lease or disable its device.

The worker selects both APNs host and topic from the server-owned device
environment: sandbox deliveries use `APNS_SANDBOX_TOPIC`, while production
deliveries use `APNS_PRODUCTION_TOPIC`. A client never supplies a topic, and one
environment cannot silently route through the other App ID.

APNs requests have a ten-second bound. `Unregistered` disables that device,
payload and provider-configuration failures end only that delivery, and 429/5xx
responses use the durable database retry schedule (up to 12 attempts with
exponential backoff and jitter). A suspended recipient's pending deliveries are
cancelled without disabling registered devices. The worker dependency is pinned
to an exact `@supabase/supabase-js` version in `index.ts`.

Do not restore either legacy database trigger or embed a bearer credential in
SQL. The deployed function intentionally uses `verify_jwt=false` because it
performs constant-time service-key authentication through the `apikey` header;
public GET exposes status only and cannot claim a delivery.

Before alpha distribution, validate registration and a tapped cold-launch push
on a signed physical device for both sandbox and production provisioning. A
Simulator or unsigned build is not a substitute for that gate.
