---
document_type: living
status: current
last_verified: 2026-11-25
---

# Mugsy delivery worker

Account-level optional attention orchestration. The migration starts in `off`.
No campaign is enabled by deploying this worker. Operator configuration requires
seven elapsed shadow days before `pilot` or `live`; pilot requires an allowlist.
No TestFlight upload or production activation is part of local verification.

The worker reuses the existing activity APNs credentials and its scoped request
secret. POST requires `apikey` and `{"action":"deliver_v1","limit":25}`. GET
exposes only protocol metadata. The five-minute scheduler derives the endpoint
from the existing validated worker URL; `off` returns before reading secrets.

Durable account reservations cover Mugsy, recaps, anniversaries, Activity
digests and nearby permits. One device receives each optional notification.
Final SQL revalidation checks consent revision, pause, fresh completion state,
ownership, visibility, capability, time, budget and selected copy before APNs. A
timeout, interrupted sender or abandoned processing lease becomes `unknown`,
retains its charge and is never automatically resent. Known APNs rejections may
retry under the same reservation within the original delivery expiry and
Retry-After.

The APNs delivery expiry is short; accepted owner-bound routes remain usable for
90 days. Weekly routes retain their exact original endpoint. Optional payloads
are passive, unbadged and silent; bundled Mugsy attachments are optional. The
reviewed copy registry is `../_shared/mugsy-copy-v1.json`. Its creative variants
have a 28-day cooldown; the factual Activity status summary is exempt, but its
underlying Activity records, daily frequency and shared budget are deduplicated.

Legacy Activity/reflection final-revalidation RPCs are wrapped in the database,
so older workers cannot bypass the shared policy for managed accounts. Managed
ownership is sticky through kill switches and capability loss: rollback does not
reactivate old optional senders. Never-managed legacy accounts preserve their
existing delivery behavior. Unknown old offline local schedulers remain outside
the coordinated-client guarantee.

Local verification:

```sh
node qa/pglite/check-mugsy-attention.mjs
qa/pglite/node_modules/.bin/deno test --cached-only supabase/functions/deliver-mugsy/worker_test.ts
MUGSY_TEST_SOCKET=/tmp/mugsy-reminder-pg-socket-20261125 node qa/pglite/check-mugsy-concurrency.mjs
```

The concurrency suite refuses TCP and uses only its explicitly named disposable
local PostgreSQL database. It checks overlapping worker claims, pause versus
final send authorization, historical charges after device removal, and account
erasure.
