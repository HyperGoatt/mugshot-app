---
document_type: living
status: current
last_verified: 2026-08-24
---

# Mugshot feature status matrix

Status vocabulary follows [the documentation policy](DOCUMENTATION_POLICY.md).

| Area | Status | Current evidence | Remaining gate |
| --- | --- | --- | --- |
| Auth and session restore | Implemented, locally verified | Supabase Auth, callback queue, account-checked session restoration | Signed-build provider regression pass when auth configuration changes |
| Profile and public identity | Implemented, locally verified | Profile bootstrap/edit, avatar/banner, public projection and share route | Continue feedback-driven polish |
| Guided sip composer | Implemented, locally verified | Cafe, Home, Elsewhere, drafts, photos, publish recovery, edit/delete | Preserve zero-loss and privacy contracts in every change |
| Home Workbench | Implemented, production-configured | Recipe templates, planned/actual brews, bag media, reuse, journal projection; live migrations and protected-data fingerprints verified | Feedback-driven product acceptance |
| Feed and visit detail | Remediation implemented and locally verified | Compact cards, profile routing, one-level comments, expressive post-reaction client/contract, tags and sharing; unit, focused UI, visual-review, and full-static gates passed | Connected-iPhone runtime, production reaction migration, replacement TestFlight |
| Journal and reflection | Remediation implemented and locally verified | Compact Journal hub, Recent Sips, archive/reflection/Passport routes, direct Publish edits; the focused tab/profile and complete Home publish journeys passed | Connected-iPhone runtime and replacement-build acceptance |
| Map and cafe discovery | Implemented with remote/local composition | MapKit search, saved state, cafe detail/discovery, and address-order-invariant local identity fallback | Consolidated Map/canonical-result acceptance; no production row mutation |
| Saved and cafe lists | Implemented, locally verified | Favorite/want-to-try, private lists, collaboration lifecycle | Multi-account TestFlight feedback |
| Friends and profiles | Implemented, locally verified | Discovery, request lifecycle, compatibility, profiles and blocking | Validate representative tester networks |
| Safety and moderation | Implemented, locally verified | Reports, blocks, enforcement state, visibility suppression | Operational response remains human-run in alpha |
| In-app Activity | Implemented, locally verified, partially physically accepted | Events, unread count, pagination, read state, durable deep links with source attribution, account-bound push refresh, authoritative badge updates; real sandbox likes appeared unread, marked authoritatively read, and routed correctly. The direct-store fix cleared Activity and Feed immediately on signed hardware without relaunch | Complete the remaining signed notification lifecycle matrix |
| Remote push | V3 production-configured; one sandbox background delivery physically accepted | APNs worker v3, credentials, topics, queue, compatible v2/v3 backend, typed client environments, canonical minute job; a normal like completed one sandbox send on the first attempt and appeared in signed-device Activity | Visually accept foreground/background alerts and app-icon badge, terminated notification tap, category suppression, sign-out, and the production device matrix |
| Notification preferences | Implemented and physically verified for the master switch | Activity education and iOS authorization passed; master off removed the sandbox registration, restore recreated it, and in-app Activity remained available | Category opt-out plus delivery suppression evidence |
| Widgets and share extension | Implemented, locally verified | App-group data, widgets, pending place import and share routes | Release regression gate when extension contracts change |
| Public links | Implemented and production evidence recorded | Public Mugshot/profile/list routes and associated domains | Preserve audience/revocation guarantees |
| Nearby cafe reminders | Implemented, device-sensitive | Local notifications, region monitoring, and shared notification authorization reconciliation | Physical regression pass |
| Account export/deletion | Implemented with production backend gates | Export manifest, step-up deletion and scheduled cleanup | Follow destructive-flow acceptance policy |
| Analytics | Implemented for core journeys and notification lifecycle | Pinned PostHog SDK; coarse education, permission, registration, preference, Activity-open and route events with no token/content identifiers | Monitor opt-outs, failures, and tester noise after distribution |
| Documentation | Living baseline merged | PR #46; canonical index, change log, policy and automated checks | Keep current in every PR |
| TestFlight | Active distribution; remediation locally accepted | Organizer/Xcode feedback proves tester use of 0.5.3 (5); all 44 ledger entries are implemented and locally passed, with physical and TestFlight states separate | Keep reports open; unlock and complete connected-iPhone runtime acceptance, then require an explicit upload request for 0.5.3 (6) |

## Notification sprint priority

1. Complete foreground alert, background alert/icon badge, terminated-tap,
   category suppression, and sign-out checks.
2. Prepare the next TestFlight candidate; upload only with explicit approval.
