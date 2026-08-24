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
| Home Workbench branch | Completed and production-configured | PR #46; migrations live through the aligned 126-migration head; protected-data fingerprints preserved 2026-08-24 |
| Supabase badge and scheduler contracts | Completed and production-configured | PR #47; worker version 6, `push_badge_sync`, compatible v2/v3 RPCs, and exactly one Vault-backed minute schedule are live |
| Production schedule cutover | Completed | PR #48; 69 stale attempts cancelled with Activity preserved, five existing devices defaulted badge support off, protected-data fingerprints unchanged, scheduled protocol-v3 HTTP 200 with zero claims |
| iOS sandbox and lifecycle hardening | Completed and merged | PR #50; full-static 12/0/1, 34 focused Simulator-hosted tests, and Simulator build/install/launch plus Activity-surface inspection passed |
| Physical sandbox acceptance | Blocked at local profile installation | `Mugshot Debug Push Development` is active through 2027-08-24 with App Groups, In-App Purchase, and Push Notifications; browser file handoff did not persist the download and Xcode has no configured Apple account for automatic retrieval |
| TestFlight production acceptance | Pending manual gate | Explicit upload authorization and processed build required |

## Feedback ledger

Do not store tester email addresses, account IDs, private content, or raw logs in
this file.

| ID | Received | Build | Severity | Summary | Reproduction | Verification tier | Branch/PR | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| — | — | — | — | No feedback logged yet | — | — | — | Open |

## Current iOS acceptance matrix

| Environment | Implemented source behavior | Remaining evidence |
| --- | --- | --- |
| Simulator | In-app Activity and nearby local authorization remain available; remote push reports signed-device unavailability | Build/install/launch and Activity surface passed; 34 focused lifecycle/Activity/analytics tests passed; authenticated live-session network acceptance remains part of later product regression testing |
| Signed physical Debug | `co.mugshot.app.dev`, development entitlement, sandbox environment, v3 badge registration | Download and install the active development profile, then run APNs registration, foreground/background/terminated delivery, routes, badges, preferences, and sign-out |
| TestFlight | `co.mugshot.app`, production entitlement/environment, v3 badge registration | Explicitly authorized upload of an accepted candidate, processing, production matrix |

Severity definitions:

- P0: privacy, security, data loss, destructive behavior, or account isolation.
- P1: crash, blocked core journey, authentication, networking, or persistence.
- P2: functional degradation with a recovery path.
- P3: copy, layout, color, typography, icon, or isolated polish.

Independent root causes receive separate small pull requests. Each entry records
the exact affected build and the lowest verification tier that covers its real
risk.
