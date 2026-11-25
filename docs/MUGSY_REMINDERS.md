---
document_type: living
status: current
last_verified: 2026-11-25
---

# Mugsy reminders

## Purpose and release boundary

Help people keep a second drink memory and continue through weeks three and
four. The habit loop is a real memory, an easy next memory, a useful Weekly Pour,
and a kind invitation to return. Messages never ask people to consume more.
Mugsy is cheeky but kind; the current brand kit and immutable identity apply.

The owner authorized backend deployment and seven days of shadow observation
on November 25. Production schema `20261125193209_mugsy_attention_policy` is
installed; it starts OFF. The new worker is staged for shadow verification.
Existing production social/reflection delivery remains independent until
coordinated rollout. Seven real days of shadow observation, hardware acceptance,
a consenting pilot and an explicit launch decision remain separate gates.
Simulated clock tests do not satisfy elapsed observation. TestFlight is not
authorized by this task.

Read-only inventory on November 25 found 185 production migrations (latest
20261105183000), deliver-activity version 22, deliver-reflections version 9,
active one-minute Activity and five-minute reflection schedules, and the
reflection control enabled. The legacy notify-friends-on-new-visit version 22
is a deployed no-delivery HTTP 410 handler; earlier unretired-endpoint statements
in the notification history are superseded by this inventory. No Mugsy schema
was present during that initial inspection; the deployment record below
supersedes that inventory for Mugsy. This inventory does not prove worker health
or receipt on any device.

## Consent and native experience

- Existing social permission does not activate Mugsy engagement reminders.
- Offer one dismissible invitation after a real owner save and outside composing.
  Choosing reminders opens preferences before requesting iOS permission.
- Notifications groups People, My journal, Nearby, timing, pace and pause.
- Standard permits three optional interruptions in 168 hours; Light permits one;
  Off and pause prevent optional delivery. Limits are ceilings, never quotas.
- Default daytime is 09:00–19:00, normal reminder time 11:00, Weekly Pour Sunday
  18:00 and On This Day 10:00, all subject to the selected local window.
- Seven-day, thirty-day and indefinite pause take effect on server confirmation.
  Offline/failed writes show failure or pending state, never false success.
- In-app invitations and cards use approved Mugsy art and the existing palette.
  Respect dismissal and show at most one reminder card per foreground session.
  Cards appear inline in Journal and scroll with its content, keeping Feed clear.
- Backend absence leaves truthful previews/in-app journal use available and
  new push preference saving unavailable. It cannot silently enable sending.

Development builds support `--debug-open-mugsy-reminders` to open the real
owner settings after authentication restoration. This navigation-only shortcut
uses the normal service and changes no consent, permission or journal data;
it does not enable the isolated UI-test fixture or its reset behavior.

## Attention policy

Mugsy logging, Weekly Pour, On This Day, nearby and grouped casual friend updates
share the account budget. Use at least 48 hours between optional interruptions,
at most one per local day and two logging/nearby nudges per rolling 168 hours.
Recent completed memories suppress logging for 48 hours. Active/composing
sessions suppress optional interruptions; direct social activity suppresses them
for twelve hours. Missing consent, timezone, capability or verified relevance
fails closed. Select one eligible installation for optional pushes.

Priority is requested opportunity, Weekly Pour, On This Day, casual friend
summary, second-memory invitation, return invitation, then nearby. Every priority
must pass the same budget and consent checks. Group casual Activity without
removing its underlying rows. Requests, tags, comments and invitations keep their
own controls. Comment bursts on one thread are grouped over fifteen minutes.
Mugsy never creates an unread badge, sound or urgent interruption level.

A first-memory invitation needs explicit consent and 48 hours without a first
save. A second-memory opportunity needs 72 hours after the only completion.
Established users become eligible after five days without another completion.
A never-activated account gets at most one first-memory invitation. At most two
other logging invitations belong to one inactivity episode, at least seven
days apart; opening an app does not reset the episode. Successful completion or
explicit re-enrollment can resume it. Three accepted/uncertain optional sends
without an observed return/completion over 21 days start a thirty-day quiet period.

Weekly Pour uses the existing local Sunday 18:00 endpoint and exact 168-hour
inclusive-start/exclusive-end interval. It requires owned completed content and
an unviewed explicit endpoint. An anniversary needs an actual owned memory.
Expired opportunities are discarded instead of delivered in an outage backlog.

## Completion, privacy and routing

The local completion hook follows an atomic successful Home save. Drafts, failed
saves, guest data, repeated save calls and edits do not become extra memories.
Publication and protected recovery link the canonical visit to the original
Home attempt. A later publication preserves the original completion time.

Deleting a saved private Home attempt queues a durable withdrawal after the
workspace write. Persistent server tombstones prevent delayed device upserts
from restoring that fact; published canonical memories remain independently
owned. Tombstones retain only an ID and withdrawal time until account deletion.

The native owner-scoped outbox contains stable memory IDs, origins, completion
times and optional canonical linkage. It contains no captions, notes, photos,
measurements or coordinates. Seed existing private Home history without fresh
analytics or a new-user invitation. Logging stays ineligible until the baseline
and pending receipts synchronize. An offline save unknown to the server remains
a possible race, so notification copy makes no claim that a person forgot.

Versioned push intents bind recipient, occurrence, destination and expiry.
Every native RPC pins its expected owner in a request header; SQL rejects a
header/auth mismatch during SDK account changes. Completion analytics similarly
checks the identified owner under its lifecycle lock without emitting IDs.
Resolve the occurrence through the authenticated owner service, retain temporary
auth-restoration routes, reject other-account and forged destinations, and check
content access again when opening. Taps open a composer without publishing, a
fresh repeat with old ratings/companions cleared, the owned memory, Activity,
or the originally promised Weekly Pour. Missing content has a useful safe state.

Nearby matching stays on-device. An upgraded client needs a shared attention
permit before adding a local notification; no location coordinates are sent.
Cached permit retries recheck the current installation, preference revision,
pause, master switch and attention policy while retaining their original charge.
No permit/connectivity means in-app discovery. Unattributed old Nearby opt-in is
reset on upgrade rather than assigned to another account; users can explicitly
re-enable it with existing location access. Cancel obsolete local requests
on upgrade/account switch. Known active legacy installations block new Mugsy
coordination; unknown offline legacy schedulers cannot be remotely recalled.
The global cap applies to coordinated installations and server senders.

Detailed decisions are retained for 90 days; persistent minimal consent,
completion/episode and assignment state remain while needed. Account deletion
purges native reminder state, exact owner Nearby keys/OS requests and server-owned
rows through existing cleanup. Existing data export includes the owner-only Mugsy
preference, completion and withdrawal projection when the new backend is present.

## Delivery and creative contracts

Use the existing caller-bound registration, secret-authenticated worker, leased
claim and final revalidation boundaries. Account reservations charge the budget
transactionally. Retries retain the same opportunity and charge. Ambiguous APNs
outcomes and expired processing leases consume a slot and are not blindly retried.
Stable collapse/APNs IDs do not promise exactly-once display.

The new control starts off. Shadow can record decisions without engagement
sends; pilot/live require a completed shadow window and appropriate allowlisting.
Global/category kill switches and a circuit breaker stop unhealthy sending.
Revalidate consent, revision, pause, ownership, device, quiet hours, completion,
visibility and expiry immediately before transport. Only confirmed unregistered
APNs tokens disable an installation; provider configuration failures do not.

The canonical copy file is
[supabase/functions/_shared/mugsy-copy-v1.json](../supabase/functions/_shared/mugsy-copy-v1.json).
The app bundles the same file. It contains 32 reviewed English messages across
eight families; deterministic rotation avoids repeating a variant for 28 days. Factual grouped Activity status
copy is exempt, while its actual underlying Activity records remain deduplicated.
Exhausted or invalid eligible copy means no send. Factual constraints protect
repeat-order, Home, photo, recap and anniversary claims.

Explicit Home preference selects Home-specific return copy and a private Home
composer destination. Photo/repeat families are reviewed and tested in the catalog
but are not automatically selected until reliable eligibility facts exist.

The Notification Service Extension attaches five allowlisted approved PNG assets
from the native catalog. It performs no network fetch, accesses no personal
photos and completes its handler once across expiry races. Plain text remains
meaningful when enrichment fails. The development extension signs successfully with its own provisioning. The
production extension profile remains a separate TestFlight release gate.

## Measurement and pre-registered evaluation

Primary metrics are second completion within seven days, new-user completion on
days 15–28 after first completion, and existing-user completion on days 8–28
after assignment. Also report distinct active memory weeks and recap-to-later-save.
Deduplicate private Home and publication in private operational state. App opens
and notification taps are diagnostics.

Assign a stable account-level 20% holdout from new Mugsy logging/comeback pushes.
Requested reminders, safety policy and in-app experiences stay consistent.
Exclude internal/test users and immature cohorts; separate new and established
users. Count qualifying completions with or without a push tap. At this early
cohort size, report raw counts and uncertainty, not a proven retention lift.
Calculate a future sample size for five-percentage-point absolute improvement,
80% power and a two-sided 5% significance level using the observed baseline.

Typed analytics include memory_completed (origin only), mugsy_invitation_viewed,
mugsy_invitation_dismissed, mugsy_card_viewed, mugsy_card_dismissed,
mugsy_route_resolved, mugsy_preferences_saved, mugsy_reminders_paused and
mugsy_synchronization_failed. Mugsy properties allowlist family/outcome/pace and
bound template_version. No user/content/occurrence IDs or raw copy enter custom
properties. Existing analytics authorization and identity/reset rules apply.

Stop the affected sender immediately for a consent, ownership, budget, pause or
reproducible duplicate/route defect. Pause expansion after two matching pilot
complaints, route failures above 1% after 100 taps, or opt-outs two percentage
points above control after each arm reaches 100 observed accounts. Small samples
remain count-based feedback, not fabricated rate precision.

## Verification and acceptance record

| Boundary | Evidence |
| --- | --- |
| Backend risk checks | 14 passed, zero failed; optional SQL parser skipped. New migration also executes in disposable PostgreSQL. |
| Policy/privacy SQL | 115 assertions, including account header mismatch, completion deduplication, withdrawal tombstones, cached Nearby permit revocation, shadow/live budgets, cooldowns, grants, and retention cohorts. |
| Real concurrency | 17 checks across separate PostgreSQL connections, including simultaneous claims, pause versus final authorization, withdrawal versus stale upsert, preserved charges and account erasure. |
| APNs/worker | 17 focused Deno checks (new and shared sender), plus cached-only repository worker type checking/tests. |
| Copy/identity | 76 standalone assertions, four native registry/embedded-resource tests, brand and 18-pose immutable-identity validation. |
| Native lifecycle/data | Final focused run: 88 tests in five suites passed; earlier Activity/device-registration and embedded-extension tests also passed. |
| Native UI | Five journeys passed: actual Feed/Journal header, inline card and scrolling regression; consent/Light/pause, failure/retry, unavailable service, accessibility XXXL/Reduce Motion. |
| App build | Generic Debug Simulator compile and signed iPhone 0.5.3 (21), including all three extensions, passed. |
| Native visual evidence | [Nine unaltered captures](design/mugsy-reminders-2026-11-25/index.html), hashes and fictional-service provenance. |
| Phone | Development app 0.5.3 (21) installed in place and launched; real Mugsy settings visually verified through iPhone Mirroring. Feed overlap corrected. Notification receipt/tap and owner acceptance remain pending. |
| Production/TestFlight | Owner-authorized schema deployment is recorded below. New engagement sending remains disabled; no archive, upload or testing-group assignment. |

The initial Swift beta compiler assertion in a test macro was corrected by
binding optional callbacks before invoking them. The initial large-text test
incorrectly expected a lazy offscreen Form switch to already exist; its corrected
journey scrolls to the control and verifies that it and Save remain reachable.
The original test results remain local evidence rather than being rewritten.

Local artifacts are under `/tmp/mugshot-mugsy-*`; owner backup data and credentials
are excluded from Git. The source branch is `codex/mugsy-reminders`. Production
rollout still requires source-matched schema/worker release, seven real shadow
days, hardware notification acceptance, a consenting pilot, and the explicit
launch decision. The named App Store notification-extension profile is not
created or verified by development signing.

### Initial signed phone handoff — build 20

Build 0.5.3 (20) was compiled from `f0e48659ceeb9ba5ef3a6c6aa234975305ce0660`
and installed over the existing `co.mugshot.app.dev` app. Deep signature validation
passed for the app and all three extensions. `devicectl` independently reports
installed build 20 and successful launch. No uninstall or account reset occurred.

The read-only pre/post inventory retained all 60 existing Application Support
files: 59 are byte-identical and the rewritten Home workspace decodes to exactly
the same JSON value. No legacy preference key was removed. Of 54 legacy keys,
53 are unchanged; the remaining app-data cache only reordered the same saved-cafe
IDs and refreshed two derived cafe statistics. New keys belong to Mugsy's minimized
local scheduling state. Owner backups remain local and excluded from Git.

The initial mirroring attempt reported “iPhone in Use.” After the owner locked
the phone, mirroring connected and revealed a reminder card overlapping the Feed
header. The subsequent Journal placement correction and verification supersede
that layout; this initial install remains data-preservation evidence only.
Hardware notification receipt and owner acceptance remain separate gates.

### Current signed phone handoff — build 21

Build 0.5.3 (21) was compiled from source `cded57f` and installed in place.
Deep signature validation passed. The real signed app opened Mugsy settings after
authentication restoration using the navigation-only development argument.
iPhone Mirroring visually confirmed the approved artwork, notification preview,
separate consent and pace controls. At this initial handoff the undeployed backend correctly left
Save and consent editing unavailable; no permission or reminder choice changed.
The app was left open on that screen at the initial handoff.

The build-21 pre/post read-only inventory retains all 60 Application Support
files: 59 byte-identical; the Home workspace differs only in serialization order
of its unordered completed-ingredient IDs. All seven sessions and all remaining
JSON values match. No pre-existing preference key was removed. The only changes
among 58 keys are Mugsy's local state and the ordering of the same 42 saved-cafe
IDs; all other app-cache values match. No uninstall or test-reset argument ran.

The confirmed Feed overlap is corrected by placing the card inside Journal's
scrolling content. A focused production-shell Simulator journey passes header
visibility/actions, card ordering, scrolling and switching back to Feed. Its
three unaltered captures supplement the six earlier settings-service captures.
The initial integration assertions were corrected to distinguish screen titles
from dock labels and static text from interactive header actions. Card
accessibility now contains its children, retaining the individual action IDs.

This is physical settings/layout evidence, not APNs receipt, pause enforcement
on a live backend, owner acceptance or TestFlight acceptance. Those release
gates remain outstanding.

## Backend rollout — November 25

The production migration was applied atomically in OFF mode. Its tracked version
was aligned with the platform-assigned history version `20261125193209`; its SQL
bytes remain identical to the original reviewed migration, SHA-256
`fbd8056361cd009351589647b71b6e5b75dee560313c92a054b2e39f484f7c95`.
Both disposable fixtures follow the deployed filename.

Pre/post verification confirmed the original device fields and both social and
reflection preference inventories unchanged. All eleven new private tables have
RLS and no direct client policies. Anonymous preference execution and ordinary
client access to operator configuration are denied. The existing Activity v22
and Reflection v9 workers retain their RPC signatures and schedules.

The initial worker accepted GET metadata but returned HTTP 503 before request
authorization because its resolver did not recognize a hosted named server key.
The corrected resolver preserves the explicit activity-delivery key preference,
then reuses the established default/named/legacy key helper. It never returns key
values in HTTP diagnostics or logs. The named-key regression was RED first; six
configuration, three shared-key and seven worker tests pass after the fix.

Shadow start and an authenticated HTTP execution must be verified before the
seven-day observation clock is reported as running. A successful cron SQL row
only proves HTTP enqueueing; require the matching worker response as well.

Never-managed legacy social alerts retain their existing behavior during shadow.
Their direct-alert receipts are not yet part of shadow collision accounting, so
that portion of the seven-day model requires coordinated pilot verification.
No full-audience cap or APNs display guarantee applies to legacy installations.
