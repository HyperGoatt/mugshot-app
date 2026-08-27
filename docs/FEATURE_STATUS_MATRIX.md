---
document_type: living
status: current
last_verified: 2026-08-26
---

# Mugshot feature status matrix

Status vocabulary follows [the documentation policy](DOCUMENTATION_POLICY.md).

| Area | Status | Current evidence | Remaining gate |
| --- | --- | --- | --- |
| Auth and session restore | Implemented, locally verified | Supabase Auth, callback queue, account-checked session restoration | Signed-build provider regression pass when auth configuration changes |
| Profile and public identity | Latest share-media follow-up locally verified; prior source physically launched; profile contract production-configured | Compact 112-point banner, foam-white tappable stats dock, compact sparse-profile metadata with no Taste overlap card, fully visible reason-first Favorite Spot categories plus custom descriptor entry, stable Cafes scrolling, Mugshots/cafes/existing-map/tagged tabs, no redundant profile-map ratings legend, tagged hide/remove controls, default-on Friends plus Everyone profile publication, owner opt-out to Everyone-only, strict Private exclusion, sealed mutations, owner export, and fixed Story/Post profile snapshots carrying marketing copy plus the canonical active link. Snapshot media is newest-first and resolves durable private-Storage references before rendering; focused tests, live Simulator parity, and comparison evidence pass. The earlier source completed connected-iPhone build/install/launch | Promote the latest source only on owner request; replacement TestFlight acceptance remains separate |
| Guided sip composer | QA follow-up locally verified | Cafe, Home, Elsewhere, fresh central Add, explicit one/multi-draft recovery, all-step close, photos, publish recovery, edit/delete; focused domain tests and full-static pass | Manual Simulator persistence acceptance; preserve zero-loss and privacy contracts |
| Home Workbench | Implemented, production-configured | Recipe templates, planned/actual brews, bag media, reuse, journal projection; live migrations and protected-data fingerprints verified | Feedback-driven product acceptance |
| Feed and visit detail | Seventh QA follow-up locally verified | Compact cards, profile routing, one-level comments, reactions, tags, reselect-to-top, and a scope bar isolated from refresh/lazy content with matching eight-point upper/lower resting gaps that holds for 60 upward points and slides continuously beneath the header. Stable scope geometry and structured comment mentions remain; the Debug Simulator build/launch, focused motion/gap test, live capture, and same-input spacing comparison pass | Owner feel acceptance, production reaction migration, replacement TestFlight |
| Journal and reflection | Second QA follow-up locally verified | Compact Journal hub, draft routes, Taste Passport holding screen, 12–18 preparation-specific criteria, stationary suggestion rail, persistent importance, and compact Publish controls; full focused matrix and full-static pass | Manual composer retest, connected-iPhone runtime, replacement-build acceptance |
| Map and cafe discovery | QA follow-up locally verified | MapKit search, saved state, cafe detail/discovery, conservative read-time stitching across equivalent provider IDs, combined visit/media projection, viewer-visible Mugshots, and remote resolution for HTTP plus private-Storage references; focused identity/snapshot/classifier tests and replacement build/install/launch pass | Tiny Nook and Cafe Details runtime acceptance; no production row mutation |
| Saved and cafe lists | Implemented, locally verified | Favorite/want-to-try, private lists, collaboration lifecycle | Multi-account TestFlight feedback |
| Friends and profiles | Editorial Atlas follow-up locally verified and production-configured | Discovery, request lifecycle, compatibility, blocking, tappable friend count/list, and the owner-controlled public profile shell; Friends stay in Friends Feed while profile publication defaults on and can be disabled, Private remains excluded, and the live caller-bound setting RPCs resolve | Representative live-network and replacement-TestFlight acceptance; physical interaction only after owner promotion |
| Safety and moderation | Implemented, locally verified | Reports, blocks, enforcement state, visibility suppression | Operational response remains human-run in alpha |
| In-app Activity | Implemented, locally verified, partially physically accepted | Events, unread count, pagination, read state, durable deep links with source attribution, account-bound push refresh, authoritative badge updates; real sandbox likes appeared unread, marked authoritatively read, and routed correctly. The direct-store fix cleared Activity and Feed immediately on signed hardware without relaunch | Complete the remaining signed notification lifecycle matrix |
| Remote push | V3 production-configured; one sandbox background delivery physically accepted | APNs worker v3, credentials, topics, queue, compatible v2/v3 backend, typed client environments, canonical minute job; a normal like completed one sandbox send on the first attempt and appeared in signed-device Activity | Visually accept foreground/background alerts and app-icon badge, terminated notification tap, category suppression, sign-out, and the production device matrix |
| Notification preferences | Implemented and physically verified for the master switch | Activity education and iOS authorization passed; master off removed the sandbox registration, restore recreated it, and in-app Activity remained available | Category opt-out plus delivery suppression evidence |
| Widgets and share extension | Implemented, locally verified | App-group data, widgets, pending place import and share routes | Release regression gate when extension contracts change |
| Public links | Implemented and production evidence recorded | Public Mugshot/profile/list routes and associated domains; Profile sharing packages a recipient-visible newest-first snapshot, resolves viewer-authorized Storage media for artwork, and includes a branded link preview plus canonical active URL; Simulator native handoff and latest-grid parity passed | Preserve audience/revocation guarantees through replacement TestFlight |
| Nearby cafe reminders | Implemented, device-sensitive | Local notifications, region monitoring, and shared notification authorization reconciliation | Physical regression pass |
| Account export/deletion | Implemented with production backend gates | Export manifest, step-up deletion and scheduled cleanup | Follow destructive-flow acceptance policy |
| Analytics | Implemented for core journeys and notification lifecycle | Pinned PostHog SDK; coarse education, permission, registration, preference, Activity-open and route events with no token/content identifiers | Monitor opt-outs, failures, and tester noise after distribution |
| Documentation | Living baseline merged | PR #46; canonical index, change log, policy and automated checks | Keep current in every PR |
| TestFlight | 0.5.3 (6) uploaded, processed, and `Testing` | Exact `b498d92` Simulator and Release archive gates passed; the owner reported completed device QA and waived a redundant rerun. App Store Connect published `Welcome to Mugshot!` and assigned Mugshot Team plus Alpha Friends | Keep reports open until hands-on replacement-build acceptance; complete the remaining production notification matrix |

## Notification sprint priority

1. Complete foreground alert, background alert/icon badge, terminated-tap,
   category suppression, and sign-out checks.
2. Collect hands-on acceptance from TestFlight 0.5.3 (6) and keep unresolved
   reports open until their replacement-build behavior is accepted.
