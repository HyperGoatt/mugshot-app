---
document_type: living
status: current
last_verified: 2026-09-13
---

# Mugshot feature status matrix

> Current repair: [Repair and sharing status](REPAIR_SHARING_STATUS.md) supersedes
> the earlier delivery and acceptance statements below for moderation, Friends
> publication, profile sharing and the reported native bugs. Those earlier
> checkpoints remain evidence of the previous candidate, not this repair's acceptance.


Sprint 1 source adds readable `/profile/username` links, permanently reserved
handle aliases, and anonymous recipient pages in the companion PWA. The
unavailable Journal Passport entry and onboarding promotion are removed; the
companion marketing site removes current-feature promises. Local
handle contracts and synthetic browser checks pass; these changes are not yet
production deployed or accepted on an installed app. Current delivery evidence
is tracked in [Sprint 1 delivery](SPRINT_1_TRACKER.md).

Status vocabulary follows [the documentation policy](DOCUMENTATION_POLICY.md).

Sprint 1 implementation is tracked in [Sprint 1 delivery](SPRINT_1_TRACKER.md).
Its source changes supersede the legacy default-on profile behavior below;
production and TestFlight retain their separately recorded deployment states.

| Area | Status | Current evidence | Remaining gate |
| --- | --- | --- | --- |
| Auth and session restore | Implemented, locally verified | Supabase Auth, callback queue, account-checked session restoration | Signed-build provider regression pass when auth configuration changes |
| Profile and public identity | Latest share-media follow-up locally verified; prior source physically launched; profile contract production-configured | Compact 112-point banner, foam-white tappable stats dock, compact sparse-profile metadata with no Taste overlap card, fully visible reason-first Favorite Spot categories plus custom descriptor entry, stable Cafes scrolling, Mugshots/cafes/existing-map/tagged tabs, no redundant profile-map ratings legend, tagged hide/remove controls, default-on Friends plus Everyone profile publication, owner opt-out to Everyone-only, strict Private exclusion, sealed mutations, owner export, and fixed Story/Post profile snapshots carrying marketing copy plus the canonical active link. Snapshot media is newest-first and resolves durable private-Storage references before rendering; focused tests, live Simulator parity, and comparison evidence pass. The earlier source completed connected-iPhone build/install/launch | Promote the latest source only on owner request; replacement TestFlight acceptance remains separate |
| Guided sip composer | QA follow-up locally verified | Cafe, Home, Elsewhere, fresh central Add, explicit one/multi-draft recovery, all-step close, photos, publish recovery, edit/delete; focused domain tests and full-static pass | Manual Simulator persistence acceptance; preserve zero-loss and privacy contracts |
| Home Workbench | Implemented, production-configured | Recipe templates, planned/actual brews, bag media, reuse, journal projection; live migrations and protected-data fingerprints verified | Feedback-driven product acceptance |
| Feed and visit detail | Seventh QA follow-up locally verified | Compact cards, profile routing, one-level comments, reactions, tags, reselect-to-top, and a scope bar isolated from refresh/lazy content with matching eight-point upper/lower resting gaps that holds for 60 upward points and slides continuously beneath the header. Stable scope geometry and structured comment mentions remain; the Debug Simulator build/launch, focused motion/gap test, live capture, and same-input spacing comparison pass | Owner feel acceptance, production reaction migration, replacement TestFlight |
| Journal and reflection | Second QA follow-up locally verified | Compact Journal hub and draft routes; unavailable Passport entry and holding screen removed locally; 12–18 preparation-specific criteria, stationary suggestion rail, persistent importance, and compact Publish controls; full focused matrix and full-static pass | Manual composer retest, connected-iPhone runtime, replacement-build acceptance |
| Map and cafe discovery | QA follow-up locally verified | MapKit search, saved state, cafe detail/discovery, conservative read-time stitching across equivalent provider IDs, combined visit/media projection, viewer-visible Mugshots, and remote resolution for HTTP plus private-Storage references; focused identity/snapshot/classifier tests and replacement build/install/launch pass | Tiny Nook and Cafe Details runtime acceptance; no production row mutation |
| Saved and cafe lists | Implemented, locally verified | Favorite/want-to-try, private lists, collaboration lifecycle | Multi-account TestFlight feedback |
| Friends and profiles | Editorial Atlas follow-up locally verified and production-configured | Discovery, request lifecycle, compatibility, blocking, tappable friend count/list, and the owner-controlled public profile shell; Friends stay in Friends Feed while production profile publication defaults on and can be disabled; Sprint 1 source replaces this with explicit versioned consent and disables legacy opt-ins. Private remains excluded, and the existing live caller-bound setting RPCs resolve | Representative live-network and replacement-TestFlight acceptance; physical interaction only after owner promotion |
| Safety and moderation | Existing reports/blocks locally verified; Sprint 1 screening backend implemented locally | Revision-bound queue, worker, shared-content projection checks and native status/review screens; see [Sprint 1 delivery](SPRINT_1_TRACKER.md) | Reviewer/report runtime acceptance, scheduler activation, full-surface audit, isolated replay and production acceptance remain |
| In-app Activity | Implemented, locally verified, partially physically accepted | Events, unread count, pagination, read state, durable deep links with source attribution, account-bound push refresh, authoritative badge updates; real sandbox likes appeared unread, marked authoritatively read, and routed correctly. The direct-store fix cleared Activity and Feed immediately on signed hardware without relaunch | Complete the remaining signed notification lifecycle matrix |
| Remote push | V3 production-configured; one sandbox background delivery physically accepted | APNs worker v3, credentials, topics, queue, compatible v2/v3 backend, typed client environments, canonical minute job; a normal like completed one sandbox send on the first attempt and appeared in signed-device Activity | Visually accept foreground/background alerts and app-icon badge, terminated notification tap, category suppression, sign-out, and the production device matrix |
| Notification preferences | Implemented and physically verified for the master switch | Activity education and iOS authorization passed; master off removed the sandbox registration, restore recreated it, and in-app Activity remained available | Category opt-out plus delivery suppression evidence |
| Widgets and share extension | Implemented, locally verified | App-group data, widgets, pending place import and share routes | Release regression gate when extension contracts change |
| Public links | Implemented and production evidence recorded | Public Mugshot/profile/list routes and associated domains; Profile sharing packages a recipient-visible newest-first snapshot, resolves viewer-authorized Storage media for artwork, and includes a branded link preview plus canonical active URL; Simulator native handoff and latest-grid parity passed | Preserve audience/revocation guarantees through replacement TestFlight |
| Nearby cafe reminders | Implemented, device-sensitive | Local notifications, region monitoring, and shared notification authorization reconciliation | Physical regression pass |
| Account export/deletion | Existing production backend gates; Sprint 1 Apple cleanup integration in source | Export manifest, step-up deletion and scheduled cleanup; native Apple code capture, encrypted provider queue and lease-fenced worker with synthetic contracts | Configure Apple credentials, full QA replay and destructive-flow acceptance |
| Analytics | Implemented for core journeys and notification lifecycle | Pinned PostHog SDK; coarse education, permission, registration, preference, Activity-open and route events with no token/content identifiers | Monitor opt-outs, failures, and tester noise after distribution |
| Documentation | Living baseline merged | PR #46; canonical index, change log, policy and automated checks | Keep current in every PR |
| TestFlight | 0.5.3 (6) uploaded, processed, and `Testing` | Exact `b498d92` Simulator and Release archive gates passed; the owner reported completed device QA and waived a redundant rerun. App Store Connect published `Welcome to Mugshot!` and assigned Mugshot Team plus Alpha Friends | Keep reports open until hands-on replacement-build acceptance; complete the remaining production notification matrix |

## Notification sprint priority

1. Complete foreground alert, background alert/icon badge, terminated-tap,
   category suppression, and sign-out checks.
2. Collect hands-on acceptance from TestFlight 0.5.3 (6) and keep unresolved
   reports open until their replacement-build behavior is accepted.


Sprint 1 recipe access correction (2026-09-13): raw recipe recipient reads now
apply owner/sender live-account, suspension, profile-screening and block checks
used by projection. Private recipe contents remain excluded from screening.
Implemented locally; production deployment and remote acceptance are pending.

Sprint 1 report review correction (2026-09-13): owner-level enforcement retains
a server-evidence lookup after reported content deletion. Hiding absent content
and reviewing one's own content remain rejected. Implemented locally; remote
acceptance and production deployment are pending.

## Sprint 1 protected-media follow-up (2026-09-13)

The current unshipped source resolves own-project legacy profile and visit media
through 60-second viewer-authorized Storage signatures. Native avatar, banner,
and visit-photo components discard images when account/foreground scope changes
and refresh protected media authorization every 55 seconds. Signed downloads use
an ephemeral uncached path; profile share artwork also avoids persistent caching.
This supersedes earlier media-loading implementation descriptions only. Bucket
policy migration and service-role author/visit/bucket provenance checks are now
implemented and locally tested. Remaining consumers, full remote integration,
and consolidated runtime acceptance are still open; production buckets have not
been changed. See [Sprint 1 tracker](SPRINT_1_TRACKER.md).

The protected-media compatibility follow-up now includes PWA user-image loading
and public cafe-list HTML. Local web media/account/visibility/postcard tests and
anonymous-signing denial tests pass. This is source/local evidence; live
Storage/CORS, remaining native direct-image consumers and rollout acceptance are
still open. Public cafe-list responses now use no-store caching.

Native direct-image consumer inventory is now closed in source: Log a Sip
companion avatars use the protected loader, and anonymous Mugshot projection
requests use an ephemeral uncached session. Generic Debug compilation passes.
Marketing share response headers now preserve JSON/image formats and prevent
shared caching; local marketing verification passes. These updates do not prove
live Storage/CORS, rendered acceptance, or production rollout.
