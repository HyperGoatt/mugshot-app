---
document_type: living
status: current
last_verified: 2026-08-24
---

# Mugshot change log

## 2026-08-24

- Installed the active `Mugshot Debug Push Development` profile and added
  device-only manual Debug signing so physical builds select it without
  changing Simulator or extension signing. The connected-iPhone build passed
  with the expected development identity, named profile,
  `co.mugshot.app.dev`, `MUGSHOT_PUSH_SANDBOX`, and
  `aps-environment=development`; the app installed successfully. The first
  remote launch was denied because the phone was locked, so runtime notification
  acceptance remains pending. Updated Current product status, Current sprint,
  Feature status matrix, Notification system, Repository map, Product roadmap,
  and TestFlight handoff.
- Generated `Mugshot Debug Push Development` for `co.mugshot.app.dev` with the
  existing development certificate and registered iPhone. Apple reports the
  profile active through 2027-08-24 with App Groups, In-App Purchase, and Push
  Notifications. Browser file handoff did not persist the download, and
  Xcode's command-line automatic retrieval failed because no Apple account is
  configured locally; download, installation, and physical acceptance remain
  pending. Updated Current product status, Current sprint, Feature status
  matrix, Notification system, Product roadmap, and TestFlight handoff.
- Implemented the source-build-5 iOS notification lifecycle: typed sandbox and
  production APNs environments, development/production entitlements,
  capability-gated v3 badge registration, shared authorization with nearby
  reminders, account-bound foreground/tap refresh, authoritative icon badges,
  injectable system/backend interfaces, truthful availability copy, and
  privacy-safe lifecycle analytics. Added focused coordinator, badge, signal,
  environment, and analytics tests. Full-static passed 12/0/1 with only the
  optional `pglast` parser skipped; 34 focused Simulator-hosted tests and a
  Simulator build/install/launch with Activity-surface inspection passed. A
  connected-iPhone build verified the Debug bundle/entitlement/environment
  selection and then failed closed because the installed development profile
  lacked `aps-environment`. Push Notifications was then enabled for the Debug
  App ID without creating redundant SSL certificates; generation and
  installation of the replacement development profile remain pending, so
  physical delivery is not accepted.
  Updated Notification system, Current sprint, Current product status, Feature
  status matrix, Real data flow status, Repository map, Product roadmap,
  PostHog analytics plan, and TestFlight handoff. Published and merged the
  implementation as PR #50 (`0d1cf21`).
- Added backward-compatible v3 APNs device registration and final delivery
  revalidation, including opt-in authoritative unread badges while retaining
  both v2 RPCs and the existing route envelope. Updated Notification system,
  Current sprint, Current product status, Feature status matrix, Real data flow
  status, Repository map, Product roadmap, and Supabase release workflow.
- Added the fail-closed canonical one-minute Activity delivery schedule using
  Vault, `pg_cron`, and `pg_net`; source and disposable QA are verified and the
  live deployment workflow remains in progress.
- Codified `deliver-activity` as a service-key-authenticated Edge Function with
  platform JWT verification disabled in `supabase/config.toml`; the worker
  still performs its own constant-time `apikey` check and supports a dedicated
  cron credential separate from its internal admin key.
- Disposable QA exposed and closed an inherited anonymous `visits` write
  grant. The share-link contract now enforces the current viewer rule: Everyone
  links are anonymous-readable, while Friends links require an eligible
  signed-in viewer.
- Replayed all 125 migrations through head `20260824165630` on a data-less
  Supabase branch, passed all 54 remote SQL contracts, and proved the single
  minute worker reaches its authenticated fail-closed state without APNs
  secrets. Updated Notification system, Current sprint, Current product status,
  Feature status matrix, Real data flow status, Product roadmap, and Supabase
  release workflow.
- Added a one-time production schedule cutover guard after live inventory found
  69 stale pending delivery attempts and no Activity cron job. Attempts older
  than 15 minutes become cancelled without deleting or suppressing in-app
  Activity; fresh and processing work is preserved. Full-static passed 13/0/0
  across 184 SQL files, and the disposable branch reached migration 126 with
  all 54 remote contracts green.
- Released migrations `20260824162710` through `20260824171405` and worker
  version 6 to production. Local/live history aligned at 126 migrations; the
  v3 capability and grants are live; protected users, visits, Activity events,
  preferences, Home data, and Storage fingerprints were unchanged. Exactly one
  Vault-backed minute job returned protocol-v3 HTTP 200 with zero claims after
  the 69 stale attempts were expired. The disposable QA branch was deleted.
- Verified the notification backend branch with the backend gate (12 passed,
  zero failed) and full-static gate (13 passed, zero failed), including local
  parsing of all 183 SQL files.
- Implemented and locally verified the Home Workbench, recipe memory, structured
  brew projection, and associated social/product checkpoint upgrades on
  `codex/home-workbench-sprint`.
- Established the living documentation index, current notification runbook,
  active sprint ledger, documentation policy, and freshness verification.
- Reconciled current product, architecture, data-flow, roadmap, analytics,
  Supabase, verification, and TestFlight documents with source build 0.5.3 (5).
- Published and merged the documentation/Home Workbench baseline as PR #46;
  synchronized local and remote `main` at merge `f91e2a4`.

## 2026-08-09

- Configured the production APNs key, sandbox and production topics, and durable
  Activity delivery schedule. Apple accepted both provider/topic probes; real
  device delivery and tapped cold launch remained pending.

## Earlier history

Use dated audits, checkpoints, deployment gates, and Git history for earlier
evidence. Those records remain historical rather than being rewritten here.
