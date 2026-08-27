---
document_type: living
status: current
last_verified: 2026-08-26
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
| TestFlight production acceptance | 0.5.3 (6) uploaded, processed, and testing | Exact `b498d92` Simulator and Release archive gates passed; the owner reported completed device QA and waived a redundant rerun. Xcode uploaded build 6 at 9:37 PM EDT, App Store Connect completed processing, published `Welcome to Mugshot!`, and assigned Mugshot Team plus Alpha Friends. Hands-on replacement-build acceptance remains pending |
| Revised 44-report remediation | Implemented, merged, and distributed; feature acceptance pending | The five workstreams are on `main`; 425 unit tests, eight focused UI journeys, the 43-screenshot plus one-text review, later focused regressions, and consolidated Simulator acceptance passed. Build 0.5.3 (6) is now available to Alpha Friends. No report will be resolved until its behavior is manually accepted in this replacement build |
| Simulator-QA follow-up | Included in TestFlight 0.5.3 (6) | Feed reselect/top behavior plus scope pills with equal eight-point upper/lower resting gaps that ignore refresh pull, hold for 60 upward points, and slide continuously beneath the header over their measured height; Journal toolbar flag and Taste Passport holding screen; all-step composer close; explicit multi-draft recovery; 12–18 preparation-specific stationary criteria; persistent importance; compact Publish controls; private-Storage cafe photos; and non-destructive multi-ID cafe stitching are in the processed build. Local focused coverage and Simulator acceptance passed; replacement-build tester acceptance remains pending |
| Editorial Atlas profile | Included in TestFlight 0.5.3 (6); profile contract production-configured | The approved foam-white statistics dock and four tabs remain, the banner is back at 112 points, Favorite Spots is a compact text rail, and Add Favorite Spot chooses the reason before the cafe. The default-on Friends-on-profile setting publishes Friends plus Everyone profile content while keeping Private absent; turning it off restores Everyone-only profile content. Share Profile renders fixed Story/Post snapshots, sorts the current profile-published Mugshots newest-first, resolves durable private-Storage media before rendering, and hands iOS the artwork, `Add me on Mugshot` copy, and canonical active link. Focused Swift tests, live Simulator share render, and profile/share comparison pass. Migration `20260826143102` is live; replacement-build tester acceptance remains pending |

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
| IOS-004 | 2026-08-25 | 0.5.3 (5), Simulator and signed Debug | P3 | Reselecting Feed did not return to the top; scope pills moved during refresh and popped away after their hold | Pull to refresh, scroll upward past 60 points, then tap the selected Feed tab | Tier 2 | `codex/testflight-feedback-remediation` | Reselect-to-top passed. Source now isolates the pills from refresh/lazy content, holds them for 60 upward points, and translates them continuously beneath the header over their measured height; the focused motion test and fast static gate pass, replacement-device feel acceptance is pending |
| IOS-005 | 2026-08-25 | 0.5.3 (5), Simulator | P2 | Criteria suggestions crossed drink contexts, offered too few relevant choices, moved while selections grew, and importance did not persist between sips | Start an iced latte reflection, inspect and add suggestions, change importance, then start another matching sip | Tier 3 | `codex/testflight-feedback-remediation` | Source provides 12–18 unique choices per preparation/Home method and fixes the chooser above selected rows; the complete focused matrix and full-static pass, manual UI acceptance remains |
| IOS-006 | 2026-08-25 | 0.5.3 (5), Simulator | P2 | Cafe detail omitted viewer-visible Mugshot media and showed `Photo unavailable` for Sightsee | Open Sightsee, which has recent self-visible Mugshots with photos | Tier 3 | `codex/testflight-feedback-remediation` | Root cause fixed: durable private-Storage references were misclassified as local paths. Read-only production evidence found two complete visits, two poster-bearing visits, and ten photo rows; the focused classifier test and full-static pass, no production data was mutated, and runtime acceptance remains |
| IOS-007 | 2026-08-25 | 0.5.3 (5), Simulator | P2 | Add auto-restored work and required repeated Back taps to exit | Save one or more drafts, close, tap central Add, then choose Resume draft | Tier 3 | `codex/testflight-feedback-remediation` | Source starts central Add fresh, exposes X on every step, resumes one draft directly, and presents a picker for several; focused draft-domain coverage and full-static pass, persistence/UI acceptance remains |
| IOS-008 | 2026-08-25 | 0.5.3 (5), Simulator | P2 | Provider-split cafe rows showed duplicate Tiny Nook identities and divided its sips/media | Open Tiny Nook from Map or search and inspect its pin count, visit history, and poster media | Tier 3 | `codex/testflight-feedback-remediation` | Read-time identity stitching combines all equivalent cafe IDs while preserving RLS and production rows. Production read-only evidence found three matching cafe rows, three complete sips, and five photo rows; four focused Feed/cafe tests and replacement build/install/launch pass, manual Tiny Nook acceptance remains |
| IOS-009 | 2026-08-25 | Product-design QA | P2 | Existing profile lacked the approved visual hierarchy, user-controlled Favorite Spots, public cafes/map/tagged tabs, and tag presentation controls | Open an owner or friend profile and exercise every stat, tab, Favorite Spot, and tagged-post action | Tier 4 | `codex/testflight-feedback-remediation` | Initial design was Simulator-accepted. The physical-QA follow-up restores the 112-point banner, compacts Favorite Spots, makes its add flow reason-first, and adds owner-controlled Friends-on-profile publication with strict Private exclusion. The revised backend, five focused Swift tests, app build/launch, rendered profile, and reason-first Simulator journey pass; the migration is production-configured. Physical and TestFlight acceptance remain separate |
| IOS-010 | 2026-08-26 | Simulator and signed-Debug QA | P2 | Profile maps showed a redundant owner-named ratings legend, Your Mix shifted the Feed scope control, and comment mentions could not open accounts unless the same person was tagged on the post | Open any profile map; switch all Feed scopes; tap a structured mention for an otherwise-untagged account | Tier 2 | `codex/testflight-feedback-remediation` | Locally verified: the map legend is removed, Feed subtitle geometry is stable and compact, and comment mentions resolve through their own account metadata into the existing profile/friendship flow. Fast static, all 16 focused Sip Detail presentation tests, normal Simulator build/launch, Your Mix/Friends visual comparison, live Amanda map, and live structured-mention render pass. Owner mention-tap feel, physical, and TestFlight acceptance remain separate |
| IOS-011 | 2026-08-26 | Owner product QA | P2 | Share Profile handed iOS only a bare profile URL instead of a branded snapshot of the public-facing profile | Journal → Profile → More → Share profile; inspect Story/Post preview and open the native share sheet | Tier 3 | `codex/testflight-feedback-remediation` | Locally verified and physically launched: a dedicated hub renders the public profile at exact Story/Post bounds and packages artwork, `Add me on Mugshot — @handle` copy, and the canonical active profile link. Eight focused profile tests, normal Simulator build/install/launch, full Story hero/grid inspection, native share-sheet handoff, and connected-iPhone development build/install/launch pass. Hands-on physical share acceptance remains |
| IOS-012 | 2026-08-26 | Owner product QA | P2 | Feed had unequal blank space around its scope pills, while Profile share omitted newest Friends-profile photos and rendered much older public photos | Compare Feed header-to-pills and pills-to-first-card spacing, then compare the live owner Mugshots grid with Journal → Profile → More → Share profile | Tier 3 | `codex/testflight-feedback-remediation` | Locally verified: the scope rail now has matching eight-point upper/lower resting gaps without changing scope heights, refresh isolation, or motion; Profile share sorts newest-first and resolves durable private-Storage references before rendering. The Debug build/launch, focused equal-gap/motion test, live Feed/share captures, and same-input comparisons pass. Full-static passed 11 non-Xcode stages and reproduced the known generic Xcode 27 XCTest-framework packaging failure. The production projection was inspected read-only and already ordered correctly; no remote state changed. Physical and TestFlight acceptance remain separate |

## Current iOS acceptance matrix

| Environment | Implemented source behavior | Remaining evidence |
| --- | --- | --- |
| Simulator | In-app Activity and nearby local authorization remain available; remote push reports signed-device unavailability | Build/install/launch and Activity surface passed; 34 focused lifecycle/Activity/analytics tests passed; authenticated live-session network acceptance remains part of later product regression testing |
| Signed physical Debug | `co.mugshot.app.dev`, development entitlement, sandbox environment; build/install/launch, permission, v3 badge registration, opt-out/re-register, terminated cold launch, two first-attempt sandbox sends, unread Activity presentation, in-app routing, mark-one-read authority, and immediate Activity/Feed badge clearing passed | Verify foreground alert, visually observed background alert/app-icon badge, terminated notification tap, category suppression, and sign-out |
| TestFlight | 0.5.3 (6), `co.mugshot.app`, production entitlement/environment, v3 badge registration; uploaded, processed, and `Testing` for Mugshot Team plus Alpha Friends | Replacement-build hands-on acceptance and remaining production notification matrix |

Severity definitions:

- P0: privacy, security, data loss, destructive behavior, or account isolation.
- P1: crash, blocked core journey, authentication, networking, or persistence.
- P2: functional degradation with a recovery path.
- P3: copy, layout, color, typography, icon, or isolated polish.

Independent root causes receive separate small pull requests. Each entry records
the exact affected build and the lowest verification tier that covers its real
risk.
