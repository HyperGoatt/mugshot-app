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
| Feed and visit detail | Implemented, locally verified | Remote cards, media, reactions, likes, comments, tags, sharing | TestFlight feedback and performance monitoring |
| Journal and reflection | Implemented, locally verified | Canonical remote journal, filters, Taste Passport and reflections | Continue data-truth and accessibility checks |
| Map and cafe discovery | Implemented with remote/local composition | MapKit, search, saved state, cafe detail and discovery | Feedback-driven search and place-identity tuning |
| Saved and cafe lists | Implemented, locally verified | Favorite/want-to-try, private lists, collaboration lifecycle | Multi-account TestFlight feedback |
| Friends and profiles | Implemented, locally verified | Discovery, request lifecycle, compatibility, profiles and blocking | Validate representative tester networks |
| Safety and moderation | Implemented, locally verified | Reports, blocks, enforcement state, visibility suppression | Operational response remains human-run in alpha |
| In-app Activity | Implemented, locally verified | Events, unread count, pagination, read state, durable deep links with source attribution, account-bound push refresh, authoritative badge updates; 15 focused tests and Simulator surface inspection passed | Signed-in physical lifecycle acceptance |
| Remote push | V3 production-configured; client locally verified; physical acceptance pending | APNs worker v3, credentials, topics, queue, compatible v2/v3 backend, typed client environments, capability-gated v3 registration, canonical minute job; push-enabled Debug profile installed; signed physical build/install passed; 12 coordinator tests passed | Launch the installed Debug app and complete the sandbox/production device matrix |
| Notification preferences | Implemented, locally verified | Master/category controls, shared iOS authorization reconciliation, truthful build/backend/device messaging; Activity always available | Physical permission acceptance |
| Widgets and share extension | Implemented, locally verified | App-group data, widgets, pending place import and share routes | Release regression gate when extension contracts change |
| Public links | Implemented and production evidence recorded | Public Mugshot/profile/list routes and associated domains | Preserve audience/revocation guarantees |
| Nearby cafe reminders | Implemented, device-sensitive | Local notifications, region monitoring, and shared notification authorization reconciliation | Physical regression pass |
| Account export/deletion | Implemented with production backend gates | Export manifest, step-up deletion and scheduled cleanup | Follow destructive-flow acceptance policy |
| Analytics | Implemented for core journeys and notification lifecycle | Pinned PostHog SDK; coarse education, permission, registration, preference, Activity-open and route events with no token/content identifiers | Monitor opt-outs, failures, and tester noise after distribution |
| Documentation | Living baseline merged | PR #46; canonical index, change log, policy and automated checks | Keep current in every PR |
| TestFlight | Active distribution | 0.5.3 distributed; source build 5 | Explicit upload request and candidate device gates |

## Notification sprint priority

1. Launch the installed signed Debug app on the unlocked iPhone.
2. Complete physical Debug sandbox notification acceptance.
3. Prepare the next TestFlight candidate; upload only with explicit approval.
