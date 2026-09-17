---
document_type: living
status: current
last_verified: 2026-09-17
---

## Native Home and Recipes — production-configured; central Add enabled in source

Independent recipes, private attempts, quick logging, flexible preparation,
linked components, discovery/adaptation, improvement history, and optional
sharing are implemented through the complete planned loop. All 65 hosted SQL
contracts, real isolated Auth/API/Storage transport, the connected Simulator
journeys, and the largest Dynamic Type route pass.

The disposable 177-migration branch was deleted after acceptance. The Home
contract remains deployed through migration 177 with preservation evidence
unchanged; the shared production head is now repository-aligned at migration 179.
The native flag defaults on with an explicit stored-off rollback, all 22 focused
Home tests pass, and the signed candidate is installed and launched on the
owner's iPhone. Owner hands-on and TestFlight acceptance remain separate gates.
[Exact implementation status](HOME_RECIPES_IMPLEMENTATION.md).

Current source routes central Add > Log a Sip > Home into the unified quick log.
Existing Home data and Journal collections remain intact. TestFlight 0.5.3 (8)
still contains its historical placeholder; replacement distribution is not
implied by the enabled development candidate.

## Explicit profile identity setup — 2026-09-14

The next candidate distinguishes temporary collision-safe signup usernames from
explicitly chosen public handles. Accounts that still match the exact legacy
placeholder formula return to required setup without being renamed. The handle
field starts empty, failed setup-state checks cannot silently bypass the gate,
and a final optional step offers the existing up-to-three Favorite Spots editor.
Intentional handles, profile content, and permanent link aliases are preserved.
Production migrations 172–173 are configured: all 18 usernames retain the same
fingerprint and eight exact placeholders require a choice. Full-static and the
focused profile contract pass. The signed Debug build compiled, installed, and
launched on Joe's connected iPhone; interaction with the reopened setup path
remains owner acceptance.

## Current moderation amendment — 2026-09-14

Production now uses synchronous server-side blocked-term validation for shared text
and report-driven human moderation for photos and other shared content. OpenAI
provider execution is removed, its worker endpoint returns 410, its schedule is
retired, and its five server configuration secrets are removed. Migration history
is 170. Existing reporting, retry deduplication, block enforcement, operator alerts,
review decisions and appeals remain. The five initial English rules target explicit
threats, exploitation and slurs; they are a narrow blocklist, not semantic analysis
or a guarantee of App Review approval. Private journal text remains excluded.

The transition preserves prior provider evidence in sealed receipts, retains actual
flags and human restrictions, and labels technical waits `reactive_policy_transition`,
not a successful photo screening. Original posts, photos, audience selections,
profile hides, blocks and all 72 checked data tables were unchanged by the cutover.
Amanda's historical Friends Matcha post remains public under the separately approved
restoration policy. Two missing photo references are preserved; this change does
not recreate missing files.

The native profile grid now offers long-press **Hide from my profile** on authored
and tagged posts, with Undo after a successful save. Tagged posts also retain
Remove my tag in that menu. The inline tagged-card ellipsis is removed. Hiding is
profile-specific and does not delete a post or alter another person's profile.
The existing detail control remains an additional route to show a hidden post.

Verification: isolated local/reactive SQL contract passed (validation rollback,
Private withdrawal, real-decision preservation, no dispatch, protected rules);
historical profile visibility contract passed; four human-review media tests passed;
Debug iPhone compilation passed. Production verification reports 143 sharing-allowed records, zero pending/service
issues and zero Private-post jobs; the original human review event is preserved.
The dev build was installed and launched on Joe’s iPhone (0.5.3 build 6); long-press
interaction awaits owner acceptance. Public disclosure builds passed. No TestFlight or App Store submission.

## Earlier implementation evidence (superseded for moderation)

The sections below document earlier repair work. Their descriptions of active
OpenAI screening are historical; the amendment above is the current behavior.


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
| Profile and public identity | Latest source physically launched; profile contract production-configured | Compact 112-point banner, foam-white tappable stats dock, compact sparse-profile metadata with no Taste overlap card, fully visible reason-first Favorite Spot categories plus custom descriptor entry, stable Cafes scrolling, Mugshots/cafes/existing-map/tagged tabs, no redundant profile-map ratings legend, tagged hide/remove controls, default-on Friends plus Everyone profile publication, owner opt-out to Everyone-only, strict Private exclusion, sealed mutations, owner export, and fixed Story/Post profile snapshots carrying marketing copy plus the canonical active link. Snapshot media is newest-first and resolves durable private-Storage references before rendering. Profile setup now requires an explicitly chosen username for exact generated-placeholder accounts, rejects unchanged placeholders from older clients, and offers an optional Favorite Spots step. Production migrations 172–173, focused contracts, full-static, and signed connected-iPhone build/install/launch pass | Owner interaction with the reopened setup path; replacement TestFlight acceptance remains separate |
| Guided sip composer | Enabled Home candidate launched on signed device; build 8 remains distributed | Cafe and Elsewhere retain the guided composer. Central Add > Home now opens the unified quick log, while Journal > Home exposes My makes / Recipes. The signed development candidate compiled, installed, and launched on Joe's iPhone; build 8 retains the historical placeholder | Owner hands-on acceptance of enabled Home; separately authorized replacement TestFlight |
| Home Workbench | Implemented, production-configured | Recipe templates, planned/actual brews, bag media, reuse, journal projection; live migrations and protected-data fingerprints verified | Feedback-driven product acceptance |
| Native Home and Recipes | Production-configured; enabled candidate launched on signed device | Unified Coffee/Component/Drink/Blank recipes, guided preparation, resumable batches, linked immutable versions, repeat/comparison, adaptation, private sync/media, and explicit sharing remain implemented. The Home contract is deployed through migration 177 and preservation evidence matched; the shared production head is 179. Central Add now enters the real quick log in current source; the signed development candidate compiled, installed, and launched on Joe's iPhone. Distributed TestFlight build 8 retains its historical placeholder | Owner hands-on acceptance; replacement TestFlight remains a separate explicit gate |
| Feed and visit detail | Seventh QA follow-up locally verified | Compact cards, profile routing, one-level comments, reactions, tags, reselect-to-top, and a scope bar isolated from refresh/lazy content with matching eight-point upper/lower resting gaps that holds for 60 upward points and slides continuously beneath the header. Stable scope geometry and structured comment mentions remain; the Debug Simulator build/launch, focused motion/gap test, live capture, and same-input spacing comparison pass | Owner feel acceptance, production reaction migration, replacement TestFlight |
| Journal and reflection | Second QA follow-up locally verified | Compact Journal hub and draft routes; unavailable Passport entry and holding screen removed locally; 12–18 preparation-specific criteria, stationary suggestion rail, persistent importance, and compact Publish controls; full focused matrix and full-static pass | Manual composer retest, connected-iPhone runtime, replacement-build acceptance |
| Map and cafe discovery | QA follow-up locally verified | MapKit search, saved state, cafe detail/discovery, conservative read-time stitching across equivalent provider IDs, combined visit/media projection, viewer-visible Mugshots, and remote resolution for HTTP plus private-Storage references; focused identity/snapshot/classifier tests and replacement build/install/launch pass | Tiny Nook and Cafe Details runtime acceptance; no production row mutation |
| Saved and cafe lists | Implemented, locally verified | Favorite/want-to-try, private lists, collaboration lifecycle | Multi-account TestFlight feedback |
| Friends and profiles | Option 1 People redesign physically launched; `people_v2` production-configured | Requests-first hierarchy, device-local one-person Messages invitation, share/QR, horizontal reasoned suggestions, friends/sent lists, search, durable invite links, and explicit suggestion opt-outs. `people_v2` adds mutual, shared-context, and recent visible interaction signals. Production verification preserved existing user/request/friend-edge counts and returned live v2 reasons. The exact source built, installed, and launched as `co.mugshot.app.dev`; no phone-number matching or SMS provider is used | Connected-iPhone hands-on interaction acceptance and separately authorized replacement TestFlight |
| Safety and moderation | Existing reports/blocks locally verified; Sprint 1 screening backend implemented locally | Revision-bound queue, worker, shared-content projection checks and native status/review screens; see [Sprint 1 delivery](SPRINT_1_TRACKER.md) | Reviewer/report runtime acceptance, scheduler activation, full-surface audit, isolated replay and production acceptance remain |
| In-app Activity | Implemented, locally verified, partially physically accepted | Events, unread count, pagination, read state, durable deep links with source attribution, account-bound push refresh, authoritative badge updates; real sandbox likes appeared unread, marked authoritatively read, and routed correctly. The direct-store fix cleared Activity and Feed immediately on signed hardware without relaunch | Complete the remaining signed notification lifecycle matrix |
| Remote push | V3 production-configured; one sandbox background delivery physically accepted | APNs worker v3, credentials, topics, queue, compatible v2/v3 backend, typed client environments, canonical minute job; a normal like completed one sandbox send on the first attempt and appeared in signed-device Activity | Visually accept foreground/background alerts and app-icon badge, terminated notification tap, category suppression, sign-out, and the production device matrix |
| Notification preferences | Implemented and physically verified for the master switch | Activity education and iOS authorization passed; master off removed the sandbox registration, restore recreated it, and in-app Activity remained available | Category opt-out plus delivery suppression evidence |
| Widgets and share extension | Implemented, locally verified | App-group data, widgets, pending place import and share routes | Release regression gate when extension contracts change |
| Public links | Implemented and production evidence recorded | Public Mugshot/profile/list routes and associated domains; Profile sharing packages a recipient-visible newest-first snapshot, resolves viewer-authorized Storage media for artwork, and includes a branded link preview plus canonical active URL; Simulator native handoff and latest-grid parity passed | Preserve audience/revocation guarantees through replacement TestFlight |
| Nearby cafe reminders | Implemented, device-sensitive | Local notifications, region monitoring, and shared notification authorization reconciliation | Physical regression pass |
| Account export/deletion | Existing production backend gates; Sprint 1 Apple cleanup integration in source | Export manifest, step-up deletion and scheduled cleanup; native Apple code capture, encrypted provider queue and lease-fenced worker with synthetic contracts | Configure Apple credentials, full QA replay and destructive-flow acceptance |
| Analytics | Implemented for core journeys, notification lifecycle, and People discovery | Pinned PostHog SDK; People events use typed sources/outcomes and count buckets only, with no queries, contact data, social IDs, or invitation secrets; first-friend attribution is stored server-side on authoritative acceptance. The People backend is production-configured | Verify delivery/cohort coverage during hands-on and replacement-build rollout; monitor opt-outs, failures, and tester noise |
| Documentation | Living baseline merged | PR #46; canonical index, change log, policy and automated checks | Keep current in every PR |
| TestFlight | 0.5.3 (8) uploaded, processed, and `Testing` | Exact `e07cb5f` source passed focused iOS 27 Simulator journeys, the signed connected-iPhone build/install/launch gate, Release archive, and export. App Store Connect published the battery-focused testing notes and assigned Mugshot Team plus Alpha Friends with automatic tester notifications enabled. No App Store release was submitted | Keep reports open until hands-on build-8 acceptance; complete the remaining production notification matrix |

## Notification sprint priority

1. Complete foreground alert, background alert/icon badge, terminated-tap,
   category suppression, and sign-out checks.
2. Collect hands-on acceptance from TestFlight 0.5.3 (8) and keep unresolved
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
