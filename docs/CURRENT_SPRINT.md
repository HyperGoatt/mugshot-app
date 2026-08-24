---
document_type: living
status: current
last_verified: 2026-08-24
---

# Current sprint: real iOS notifications and TestFlight feedback

## Goal

Physically accept the existing Activity/APNs system, close device-lifecycle and
badge gaps, and process TestFlight feedback without regressing privacy, data
ownership, or the core sip journey.

## Delivery tracker

| Stage | Status | Evidence or gate |
| --- | --- | --- |
| Documentation baseline | Completed and merged | PR #46; living index, policy, current-state rewrite, automated freshness check |
| Home Workbench branch | Merged; production deployment separate | PR #46; `main` at merge `f91e2a4`; full-static gate passed 2026-08-24 |
| Supabase badge and scheduler contracts | Implemented and disposable-QA verified; live release pending | PR #47 on `codex/notification-backend-v3`; full-static 13/0/0, 183 SQL files parsed, disposable replay at migration head `20260824165630`, remote contracts 54/54, one canonical minute schedule, and authenticated fail-closed worker invocation on 2026-08-24 |
| Production schedule cutover | In progress | Live inventory found 69 pending delivery attempts older than 15 minutes and no Activity cron job; forward guard preserves Activity while expiring only stale push attempts before enabling the minute worker; full-static 13/0/0, 184 SQL files parsed, QA head `20260824171405`, remote contracts 54/54 |
| iOS sandbox and lifecycle hardening | Planned | Signed Debug entitlement, capability gate, reconciliation, refresh, badge tests |
| Physical sandbox acceptance | Pending | Connected iPhone, real event, lifecycle matrix |
| TestFlight production acceptance | Pending manual gate | Explicit upload authorization and processed build required |

## Feedback ledger

Do not store tester email addresses, account IDs, private content, or raw logs in
this file.

| ID | Received | Build | Severity | Summary | Reproduction | Verification tier | Branch/PR | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| — | — | — | — | No feedback logged yet | — | — | — | Open |

Severity definitions:

- P0: privacy, security, data loss, destructive behavior, or account isolation.
- P1: crash, blocked core journey, authentication, networking, or persistence.
- P2: functional degradation with a recovery path.
- P3: copy, layout, color, typography, icon, or isolated polish.

Independent root causes receive separate small pull requests. Each entry records
the exact affected build and the lowest verification tier that covers its real
risk.
