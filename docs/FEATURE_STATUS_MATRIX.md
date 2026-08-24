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
| Home Workbench | Implemented, disposable-QA verified | Recipe templates, planned/actual brews, bag media, reuse, journal projection; remote contracts passed | Complete live snapshot, dry-run, deployment, and drift closure |
| Feed and visit detail | Implemented, locally verified | Remote cards, media, reactions, likes, comments, tags, sharing | TestFlight feedback and performance monitoring |
| Journal and reflection | Implemented, locally verified | Canonical remote journal, filters, Taste Passport and reflections | Continue data-truth and accessibility checks |
| Map and cafe discovery | Implemented with remote/local composition | MapKit, search, saved state, cafe detail and discovery | Feedback-driven search and place-identity tuning |
| Saved and cafe lists | Implemented, locally verified | Favorite/want-to-try, private lists, collaboration lifecycle | Multi-account TestFlight feedback |
| Friends and profiles | Implemented, locally verified | Discovery, request lifecycle, compatibility, profiles and blocking | Validate representative tester networks |
| Safety and moderation | Implemented, locally verified | Reports, blocks, enforcement state, visibility suppression | Operational response remains human-run in alpha |
| In-app Activity | Implemented, locally verified | Events, unread count, pagination, read state and deep links | Foreground push refresh and badge convergence hardening |
| Remote push | V2 production configured; v3 disposable-QA verified; physical acceptance pending | APNs worker, credentials, topics, queue, compatible v2/v3 device and delivery RPCs, opt-in badge payload, canonical minute job | Live v3 release, then sandbox/production device lifecycle matrix |
| Notification preferences | Implemented, locally verified | Master and category controls; Activity always available | Correct stale capability copy and add analytics |
| Widgets and share extension | Implemented, locally verified | App-group data, widgets, pending place import and share routes | Release regression gate when extension contracts change |
| Public links | Implemented and production evidence recorded | Public Mugshot/profile/list routes and associated domains | Preserve audience/revocation guarantees |
| Nearby cafe reminders | Implemented, device-sensitive | Local notifications and region monitoring | Unify authorization reconciliation with push |
| Account export/deletion | Implemented with production backend gates | Export manifest, step-up deletion and scheduled cleanup | Follow destructive-flow acceptance policy |
| Analytics | Implemented for core journeys | Pinned PostHog SDK and privacy-safe event taxonomy | Add notification lifecycle events without identifiers/content |
| Documentation | Living baseline merged | PR #46; canonical index, change log, policy and automated checks | Keep current in every PR |
| TestFlight | Active distribution | 0.5.3 distributed; source build 5 | Explicit upload request and candidate device gates |

## Notification sprint priority

1. Release the QA-verified backward-compatible badge and scheduler contracts to live.
2. Enable physical Debug sandbox push and harden the coordinator.
3. Complete physical sandbox acceptance.
4. Prepare the next TestFlight candidate; upload only with explicit approval.
