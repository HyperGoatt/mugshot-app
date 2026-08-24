---
document_type: living
status: current
last_verified: 2026-08-24
---

# Mugshot change log

## 2026-08-24

- Added backward-compatible v3 APNs device registration and final delivery
  revalidation, including opt-in authoritative unread badges while retaining
  both v2 RPCs and the existing route envelope. Updated Notification system,
  Current sprint, Current product status, Feature status matrix, Real data flow
  status, Repository map, Product roadmap, and Supabase release workflow.
- Added the fail-closed canonical one-minute Activity delivery schedule using
  Vault, `pg_cron`, and `pg_net`; source is locally verified and awaits the
  disposable-QA/live deployment workflow.
- Verified the notification backend branch with the backend gate (12 passed,
  zero failed) and full-static gate (13 passed, zero failed), including local
  parsing of all 182 SQL files.
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
