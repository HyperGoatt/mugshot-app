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
| Physical sandbox acceptance | Delivery/read path partially accepted; matrix in progress | Two normal second-account likes each produced a first-attempt sandbox send. The signed iPhone showed the unread items and routed them correctly; after the direct-store fix, mark-one-read cleared the authoritative count, Activity marker, and Feed bell immediately without relaunch. Foreground presentation, a visually observed background alert/app-icon badge, terminated notification tap, category suppression, and sign-out remain. |
| TestFlight production acceptance | Pending manual gate | Explicit upload authorization and processed build required |
| Revised 44-report remediation | Implemented and locally verified; physical runtime pending | Five workstreams are represented on `codex/testflight-feedback-remediation`; 425 unit tests, eight focused UI journeys, the 43-screenshot plus one-text review, and full-static 12/0/1 passed. Signed Debug build/install passed, but launch was denied while the phone was locked. No report will be resolved until replacement TestFlight acceptance |

## Feedback ledger

Do not store tester email addresses, account IDs, private content, or raw logs in
this file.

The complete Organizer-backed 44-report ledger, including source build/device,
disposition, owner, and separate implementation/local/physical/TestFlight
states, is maintained in
[TestFlight feedback ledger](TESTFLIGHT_FEEDBACK_LEDGER.md). The three iOS
entries below are the earlier signed-Debug operational findings and remain
separate from those TestFlight packages.

| ID | Received | Build | Severity | Summary | Reproduction | Verification tier | Branch/PR | Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| IOS-001 | 2026-08-24 | 0.5.3 (5), signed Debug | P2 | Feed Activity bell stayed at `1` after marking the only unread item read inside the Activity sheet; relaunch reconciled it to zero | Receive one unread item, open Activity, open the item, return, and dismiss Activity | Tier 3 | `codex/activity-unread-badge-sync` | Resolved: full-static 12/0/1 and signed-device reproduction passed; Feed cleared immediately without relaunch |
| IOS-002 | 2026-08-24 | 0.5.3 (5), signed Debug | P3 | Feed left too much space below its scope control and wrapped the Your Mix subtitle across three lines | Open Feed with Your Mix selected and its education card dismissed | Tier 1 | `codex/feed-map-launch-polish` / PR #57 | Resolved in source: the control-to-post gap is reduced from 18 to 8 points and the subtitle is constrained to two lines; full-static passed 12/0/1 |
| IOS-003 | 2026-08-24 | 0.5.3 (5), signed Debug | P2 | Map opened on the broad zero-coordinate fallback instead of an already-authorized user's active location until the location button was tapped | Launch the app with location already authorized and Map selected | Tier 3 | `codex/feed-map-launch-polish` / PR #57 | Implemented and locally verified: the initial MapKit delegate transition can no longer overwrite the first current-location camera request; full-static passed 12/0/1 and focused arbitration tests compile, with signed-device launch acceptance remaining |

## Current iOS acceptance matrix

| Environment | Implemented source behavior | Remaining evidence |
| --- | --- | --- |
| Simulator | In-app Activity and nearby local authorization remain available; remote push reports signed-device unavailability | Build/install/launch and Activity surface passed; 34 focused lifecycle/Activity/analytics tests passed; authenticated live-session network acceptance remains part of later product regression testing |
| Signed physical Debug | `co.mugshot.app.dev`, development entitlement, sandbox environment; build/install/launch, permission, v3 badge registration, opt-out/re-register, terminated cold launch, two first-attempt sandbox sends, unread Activity presentation, in-app routing, mark-one-read authority, and immediate Activity/Feed badge clearing passed | Verify foreground alert, visually observed background alert/app-icon badge, terminated notification tap, category suppression, and sign-out |
| TestFlight | `co.mugshot.app`, production entitlement/environment, v3 badge registration | Explicitly authorized upload of an accepted candidate, processing, production matrix |

Severity definitions:

- P0: privacy, security, data loss, destructive behavior, or account isolation.
- P1: crash, blocked core journey, authentication, networking, or persistence.
- P2: functional degradation with a recovery path.
- P3: copy, layout, color, typography, icon, or isolated polish.

Independent root causes receive separate small pull requests. Each entry records
the exact affected build and the lowest verification tier that covers its real
risk.
