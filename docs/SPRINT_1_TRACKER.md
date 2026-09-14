---
document_type: living
status: current
last_verified: 2026-09-14
---

# Sprint 1 delivery: trust, moderation, and working sharing

> Current repair: [Repair and sharing status](REPAIR_SHARING_STATUS.md) supersedes
> the earlier delivery and acceptance statements below for moderation, Friends
> publication, profile sharing and the reported native bugs. Those earlier
> checkpoints remain evidence of the previous candidate, not this repair's acceptance.

## Current repair deployment — 2026-09-14

The repair is now production-configured at 167 migrations with all five matching
functions deployed. Original-table fingerprints and bucket visibility passed
preservation checks. The dev candidate is installed on the owner's iPhone and
the recorded phone checks passed. Technical-backlog recovery completed with 69
approvals and one explained missing-photo service item; see [the current repair status](REPAIR_SHARING_STATUS.md) for exact outcomes.
All disposable QA branches are deleted. TestFlight distribution remains held.

The older checkpoints below are historical evidence and do not describe the
current production head or active QA resources.



## Current preservation hold and compatibility work

The owner required preservation of all posts, photos, ownership and audiences.
Production remains at its original head and storage settings; the attempted
release preflight performed dry runs and read-only inventory only. The current
TestFlight reader cannot load older public URLs after bucket privatization.
A minimal `codex/media-compatibility-bridge` candidate based on `b498d92` now
compiles, with no backend or data changes. Hardware/both-backend acceptance and
TestFlight distribution remain separate gates. The full transition, including
existing-content screening/access preservation, is specified in
[the preservation-first release sequence](SUPABASE_RELEASE_WORKFLOW.md).

A read-only 72-table production fingerprint baseline is saved locally. The new
preservation guard passes QA unchanged-data and mismatch-rejection checks.
The full hosted SQL gate passes 63/63; the reflection fixture now uses reserved
IDs rather than whichever users happened to exist first. No production posts
were used as QA fixtures. The walkthrough QA remains active with schedules
paused for deterministic verification; no automatic continuation loop runs.

## Owner dev-build walkthrough — active

The owner requested a full phone walkthrough before TestFlight. A new isolated
QA branch (`foemiqrvwxavjchokjce`) is active specifically for this session; the
earlier completed QA branches remain deleted. Cleanup responsibility is tracked
in `.codex/owner-walkthrough-session.json`. Do not restart the deleted heartbeat.
Delete this QA branch and verify absence when the owner finishes testing.

Signed development build 0.5.3 (6), bundle `co.mugshot.app.dev`, is installed
on the owner's iPhone. It uses all 163 migrations and deployed screening,
review, cafe verification, deletion, sharing, drink-analysis and activity
functions. Scheduled screening approved both synthetic profiles in one attempt.
The owner fixture has founder review access. Scheduled email-account deletion
and in-app activity workers use QA-only destinations and dedicated secrets.
Analytics is disabled; OpenAI's three training-sharing choices were verified
Disabled before screening. Private content remains excluded.

The marketing/PWA preview deployments use QA. Authenticated preview verification
returned the correct synthetic profile through `/profile/final_qa_owner`. Vercel
protects preview pages, so the owner may need a Vercel login when testing links.
Cafe-list sharing now uses the configured public base URL, matching profiles
and posts; it no longer sends QA list links to the live marketing domain.
The focused signed device compile and built configuration assertions passed.
This is a dev-build handoff, not whole-app owner acceptance or TestFlight.

### Walkthrough checklist

- Use the provided disposable email account, not a production Apple/Google login.
- Feed/Journal: create, edit, reopen and delete test sips; try Cafe, Home and
  Elsewhere; exercise Private, Friends and Everyone audiences.
- Maps/Saved: search a cafe, add it, save/unsave and reopen Favorites.
- Profile: edit details and username, copy the readable share link, toggle
  Friends-on-profile consent, and check the preview recipient page.
- Shared content: submit harmless public content, observe screening status,
  and explore founder review, reports and appeals when items are available.
- Lists/Home: create a cafe list, test its share link, and try coffee bags,
  equipment, recipes and brew capture.
- Account/settings: sign out/in and confirm session restoration. If testing
  account deletion, do it last and only on the disposable account.
- Collect unexpected behavior and screenshots in one batch before another build.

Isolated-environment limits: Apple/Google OAuth, APNs push and PostHog erasure
are not configured here. Native email login and in-app activity are available.
There is no copied production content or social graph. A second disposable
viewer account is available for audience checks. Production rollout and
TestFlight upload remain on hold for the owner's walkthrough.

## Current scope — TestFlight preparation only

The owner explicitly directed TestFlight-only preparation, with no App Store
review submission. On September 13 the owner confirmed no disposable Apple
Account is available and authorized proceeding. Actual Apple token revocation
remains unverified and is a documented TestFlight limitation, not a prerequisite
for continuing the other work. Do not request that account again or revoke the
owner's real Apple authorization for testing.

The remaining bounded work is coordinated backend/client rollout verification
and the separate TestFlight upload approval after candidate validation. The
focused physical-iPhone photo acceptance below now passes. Retain marketing
version 0.5.3 unless the owner approves a change;
choose an unused build number at upload preparation. Do not submit App Store
review. PostHog's existing pending synthetic erasure request must be monitored
without blocking unrelated preparation or creating additional test identities.

The Mac became available for the final native session. The repaired deletion
flow passed against isolated QA: the progress sheet stayed visible, fresh sign-in
completed, Auth and profile rows were removed, the durable deletion job reached
`completed` with no error, and relaunch stayed signed out. The app disclosed
pending analytics cleanup. This test used a synthetic email identity; actual
Apple revocation remains unverified as approved above.

The owner completed the physical photo-picker handoff on an iPhone 16 Pro
running iOS 27.0. Signed development build 0.5.3 (6), source `6886a19`, used
isolated QA with analytics disabled. Native email sign-in, Private photo-post
save, and photo display after process termination/relaunch passed. The stored
post has `upload_state=complete`; the owner downloaded nonempty photo bytes,
while a separate account and anonymous access were denied. Both nonowners
also received no visit row. The Private visit has zero screening jobs. This
is physical development-build acceptance, not TestFlight acceptance.

The paid phone-photo QA branch was deleted and a fresh listing verified only
main remains. Local receipts are `.codex/phone-photo-privacy-receipt.json` and
`.codex/sprint1-phone-photo-session.json`. Production was not modified, and
no archive, upload, or App Store review submission occurred.

The owner requested removal of the continuation loop; the
`finish-mugshot-sprint-1` automation was deleted. Earlier checkpoints' active
heartbeat and photo/device-block statements are historical and superseded by
this checkpoint. Do not recreate the loop or repeat passing acceptance checks
without a concrete change or failure.

## Earlier checkpoint — September 13, journey acceptance and repairs

The provider gate above supersedes the Apple test-account requirement below.

The second native walkthrough verified persisted Love reactions, the native
profile share sheet, Friends-profile consent cancellation/confirmation/off,
and the shared-content status and founder review queue screens. The system
Photos picker displayed the synthetic checkerboard but did not accept automated
selection; photo upload/save/reopen remains unaccepted.

Saved returned Data API 403 because its historical table migration relied on
project default grants. Migration `20260913212833` explicitly grants only the
required authenticated CRUD operations and preserves owner-only RLS. The new
Saved access contract and adjacent cafe-admission contract both pass on isolated
QA. The same native app then saved a fixture cafe and displayed it in Favorites
without the previous loading error.

Native deletion failed closed before creating any deletion job. The client
required the legacy service-role worker contract while the new backend advertises
its dedicated worker secret. The source now accepts these two known contracts
and still rejects unknown authentication. Deletion also retains the signed-in
root while its sheet manages progress, so recoverable failures stay visible.
All 30 focused account-lifecycle tests pass, including the worker-authentication
regression. The full-static gate passes 12 checks with the optional SQL parser
skipped; documentation checks pass. Exact native deletion acceptance must still
be repeated after this repair. The synthetic Auth/profile remained intact.

The journey QA branch replayed 163 migrations after the Saved fix. Its paid
branch was deleted and a fresh listing verified only main; its app process and
temporary keep-awake assertion were stopped. The earlier 62-contract full pass
is preserved below; this follow-up ran two focused SQL contracts, not a new
63-contract full suite.

PostHog's existing synthetic erasure receipt is still pending. Apple disposable
provider revocation, remaining native acceptance, and coordinated production
rollout remain open. Production has not received these new migrations or clients.
No training-sharing settings were enabled. TestFlight remains a separate gate.

## Earlier checkpoint — September 13, native acceptance

Superseded by the journey acceptance and repairs checkpoint above.

A fresh disposable native QA branch replayed all 162 migrations and passed all
62 database contracts together. The native candidate at `e0d1eb0` was rebuilt
with Simulator signing and QA-only configuration. Authentication, session
restoration after relaunch, and profile onboarding passed.

The native-created profile was screened in one scheduled attempt. Its anonymous
profile response returns HTTP 200 with no-store caching, and its readable route
redirects to the matching companion profile with HTTP 302. Friends-on-profile
consent is false by default. All three OpenAI training-sharing settings were
freshly verified Disabled before synthetic screening.

The Mac locked again before the remaining consent, sharing, review, reaction,
capture and deletion screens could be accepted. The native QA branch was
deleted and absence verified; only main remains. PostHog erasure confirmation,
remaining native/provider acceptance and coordinated production rollout are
still open. The 15-minute continuation remains active.

## Earlier checkpoint — September 13, catalog QA closure

Superseded by the native acceptance checkpoint above.

Sprint 1 is implemented on the feature branches, with release acceptance and
production rollout still open. All 162 migrations replayed on isolated QA.
The final 62-contract run passed 61; its older reflection test needed explicit
new-revision admission after a shared-note edit. That focused contract now
passes without weakening its audience assertions. Backend checks pass 11/11
with optional pglast skipped; native compile and companion verification remain
green as detailed below.

Paid QA is deleted and absence verified. Production OpenAI and Maps credentials
are staged with both screening activation gates false; no production content
processing or new migration rollout is claimed. Native acceptance needs the Mac
unlocked, and the existing synthetic PostHog erasure receipt remains pending.
The active 15-minute heartbeat continues this task when those states change.
TestFlight remains a separate explicit authorization gate.

## Confirmed requirements

OpenAI moderation plus Joe's review queue; no Mugshot data shared for model
training or improvement. Private content is excluded from screening. Explicit
consent is required to publish existing and future Friends posts on public
profiles. Public profile links use `/profile/username`, preserve legitimate
legacy links, and never transfer old handles to another account. Complete
deletion, sip-link routing, existing expressive reactions, and removal of
unavailable Passport promises. Broad redesign and new growth features are out.

## Verification correction — 2026-09-13

The test-launch interpretation in this earlier checkpoint is superseded by
[the recovered native test evidence](#native-unit-evidence--2026-09-13).
The scheme correction remains valid.

Earlier checkpoints described the generic `testMugshot` scheme compile as
app-and-test evidence. Its generated execution manifest had no test
configurations, so those runs prove the app compile only. The verification
script now uses the shared `MugshotTests` scheme and checks that both unit and
UI test targets appear in its execution manifest. A fresh build using that
scheme compiled both test targets successfully. This correction supersedes
only the earlier test-compilation claims; the separately executed hermetic
backend checks remain valid. The corrected compile gate and manifest check
passed, as did the fast gate and documentation validation.

A unit-only `test-without-building` attempt on the already booted iPhone 16 Pro
(iOS 18.6) used an intentionally invalid `MUGSHOT_SUPABASE_URL` in its local
execution manifest to prevent host-app session restoration and analytics
startup. It produced no test results before being interrupted after more than
two minutes. Computer access reported that the Mac was locked and automatic
unlock failed. This is an unverified runtime attempt, not a unit-test pass or
an assertion failure. Resume the consolidated unit suite in an unlocked
session. Live backend journeys still require disposable QA approval and
configuration; no production database was used for these tests.

## Hosted QA checkpoint — 2026-09-13

The first approved paid QA branch has been deleted and its absence verified.
Repository-source history replay passed after isolated scheduler prerequisites;
automatic replay exposed 85 damaged production migration statement records.
The full remote suite reported 30 passes and 25 failures. A missing cafe-table
grant was fixed in migration `20260913142110`, and both its focused contract and
the screening queue contract passed remotely. Full-suite triage, metadata
repair, provider configuration, and runtime acceptance remain open. See the
[dated QA evidence and exact failures](SPRINT_1_QA_2026-09-13.md).

## Native unit evidence — 2026-09-13

The staged test stdout and session logs from both Simulator attempts were
recovered. Both actually executed 446 tests in 30 suites, with six assertions
failing in the single Home Workbench criterion-suggestion test. The earlier
claim that no tests ran was based on the quiet outer command log and is
incorrect. Xcode stalled during diagnostic/result finalization; Mac lock state
alone did not explain it.

The test still expected the pre-August-26 criterion order, while production
source intentionally expanded that catalog in commit `10db1597`. Its six
expected lists now match that catalog, retaining the assertions that each brew
method selects the right suggestions and does not add ratings. No app behavior
changed. The corrected test bundle compiled; the focused Home Workbench suite
passed 15/15 on iPhone 16 Pro, iOS 18.6, with xcodebuild exit 0 and an xcresult
summary of Passed. Verbose failure diagnostics were disabled for this isolated
run. The intentionally invalid test-process backend URL prevented host-app
production session restoration. The full 446-test suite was not repeated after
the expectation-only fix; the previous run plus this focused correction is the
current unit evidence. Live backend and cross-screen acceptance remain open.

## Migration metadata repair — 2026-09-13

Exact comparison corrected the initial count: 84 stored migration statements
were wrong; one of the 85 repeated records legitimately owned that SQL.
Repaired those 84 statement arrays in production after exact forward/rollback
rehearsal on disposable QA. The guarded transaction verified unchanged schema
and application/Auth/Storage row fingerprints. Production still has 127
migration records at `20260826143102`; Sprint 1 features remain undeployed.
See the [repair evidence and exact hash ledger](SPRINT_1_MIGRATION_HISTORY_REPAIR_2026-09-13.md).
A fresh data-less branch automatically replayed 113 migrations through
`20260809144548`, past the repaired history. Its next migration requires the
operational scheduler Vault secret; complete replay still requires isolated
prerequisite provisioning. The fresh check branch was deleted and its absence
verified. Full application acceptance remains open.

## Second hosted QA checkpoint — 2026-09-13

The second data-less QA branch replayed all 152 repository migrations with
isolated scheduler prerequisites and inactive jobs. The refreshed full suite
reported **32 passed, 24 failed, 56 total**. Both the explicit cafe-grant contract
and screening queue contract pass. The owner-edit rollback test now verifies
canonical stored tags instead of a public projection that correctly withholds
unscreened profile names; it passes with authenticated mutation and cross-owner
rejection checks intact. The prior cafe permission failures progressed to
screening-related unavailable-profile/friend assertions. None of the remaining
24 failures is waived. This branch was deleted, absence verified, and its local
database credential file removed after testing.

## Provider configuration checkpoint — 2026-09-13

The approved Sign in with Apple key and project-scoped PostHog deletion key
have been created and saved in Git-ignored local files with mode 0600. Apple’s
key is restricted to Sign in with Apple for the primary production bundle.
The generated ES256 client secret passes local P-256 signature verification and
expires March 12, 2027 at 14:51:49 UTC; renew before February 10, 2027. Apple
token exchange and revocation still require disposable-account acceptance.

The PostHog key has only `person:write` access in the Mugshot project. A
synthetic random-UUID lookup returned HTTP 200 and zero people, confirming that
this write scope also permits the required lookup. No live deletion was run.
Neither credential has been deployed, and processing remains disabled.

The signed-in PostHog project had session recording enabled even though native
source disables it. Turned the project setting off and verified the persisted
Disabled state after reload. The recording list returned no matches for the
last 30 days with its default active-duration filter; that filtered observation
was not complete absence evidence. The subsequent authenticated recording
inventory from July 1 (before project creation), without duration/property or
internal-user exclusions, returned zero recordings. The project endpoint
confirms recording disabled and 30-day retention. This closes the current
recording-inventory gate; recheck before activation.

## Delivery states

| Workstream | Evidence | Remaining |
| --- | --- | --- |
| OpenAI setup | Dedicated Mugshot project created; feedback, evaluation/fine-tuning, and API input/output sharing all visibly Disabled organization-wide; project key saved locally outside Git; synthetic text-only moderation HTTP 200 | Server deployment and recurring release configuration checks |
| Profile consent | Versioned RPC, disable-only legacy setter, author plus tagged-profile consent; isolated PostgreSQL behavior test and iOS Debug app/test compile pass | Runtime acceptance and production deployment |
| Screening and review | Revision-bound queue and worker, primary/collection publication gates, sealed review/status/reconsideration RPCs, reviewer preview and native status/review screens implemented. Synthetic PostgreSQL queue/projection contracts and 11 provider/worker tests pass | Batched native and live reviewer-endpoint acceptance; complete outward-surface audit; scheduled activation and throughput acceptance; production acceptance; all 155 migrations replayed and all 57 hosted contracts pass |
| Existing shared content | Not screened | Updated disclosures, staged screening; unscreened content withheld from outward surfaces; owner access retained |
| Deletion | Existing V3 orchestration plus native Apple code capture, verified exchange, encrypted provider queue and scheduled cleanup integration; deterministic checks and generic compile pass; production initiation remains disabled | Server credential deployment/rotation; interrupted recovery, media/analytics cleanup, disposable-account and production acceptance |
| Readable profile and sip links | Implemented username RPC/routes, reserved aliases and tombstones, legacy token compatibility, public web recipient pages, and removal of service-worker API caching. Local handle contract and synthetic web render/revocation/retry checks pass | Native runtime acceptance, deployment and installed-app journey; exact backend replay passed |
| Reactions | Existing additive migration not production deployed at audit | Production deployment and candidate acceptance; isolated replay and capability fallback checks pass |
| Passport claims | Removed Journal upgrade-only entry and onboarding Passport promotion; marketing promotion, FAQ, feature schema and guide claims removed; legacy web page states unavailability | Source compile and marketing render checks pass; deployment and batched native acceptance remain |
| Release | Not accepted | Static/backend checks, batched Simulator and owner-promoted device acceptance, separately authorized TestFlight upload and exact-build acceptance |

## No-training operating contract

The organization sharing controls were inspected in the signed-in Platform on
2026-09-12 and reverified after a fresh reload on 2026-09-13 America/New_York.
All three were Disabled, including API inputs and
outputs; no free-token data-sharing program was enabled. Settings apply across
projects. This is dated configuration evidence, not a guarantee against future
administrator changes. Verify again before production content processing.

Use only `/v1/moderations` for this integration. Never send user content to
training, evaluations, Playground feedback, or debugging conversations. Strip
image metadata, minimize shared fields, exclude private journal content, and
redact logs. Human review decisions remain in Mugshot. Provider processing must
be disclosed; no-training is distinct from retention and external processing.

Sources: [OpenAI data controls](https://developers.openai.com/api/docs/guides/your-data)
and [moderation](https://developers.openai.com/api/docs/guides/moderation).

## Acceptance

Test visibility for Private/Friends/Everyone across author, friend, tagged
profile, stranger, anonymous visitor, blocked viewer, and old client. Exercise
moderation failures, stale revisions, edit/delete races, retries and removals;
deletion uses disposable accounts and preserves collaborators. Verify no raw
content in telemetry or unintended OpenAI payload fields. Check canonical,
legacy, revoked, renamed and deleted-account links, reaction persistence and
the core capture/save/reopen journey.

Follow the repository verification and documentation policies. Record exact
commit, migration, Edge Function configuration, and build for each acceptance
state. No TestFlight archive/upload/group assignment until explicitly requested
after local validation. Credentials and screenshots containing account details
must never enter the repository.

## Local verification checkpoint

`verify-no-simulator.sh full-static`: 12 passed, 0 failed, 1 skipped
(optional pglast unavailable; hermetic PostgreSQL execution passed). Final
consent-read adjustment passed the focused PostgreSQL test and a fresh generic
iOS Debug app/test compile. Documentation checker and diff checks passed.
No Simulator was booted, no Supabase project was mutated, and no TestFlight
build was created. Readable sharing implementation now follows the consent checkpoint. Its isolated
handle contract, Edge type checks, PWA build, marketing verification (14 tests),
and synthetic Playwright recipient checks pass. Native integration and full
backend replay remain pending. Browser plugin was unavailable; local Playwright
used 390x844 and 1280x900 viewports. Profile/sip rendering, unavailable-state
clearing, retry, native-link destinations and absence of runtime errors passed.
Screening, deletion completion and release remain outstanding. Passport removal
passed the updated generic iOS app/test compile, marketing build verification,
and local browser navigation check. Final sharing-source compile passed after
restoring old-backend collection fallbacks and making share artwork require a
successful anonymous projection. UI test expectations now match the retired
Passport entry; execution remains queued for consolidated acceptance.


## Screening implementation checkpoint

Three new local migrations connect explicit shared fields to a sealed queue and
hold pending/rejected content from primary and collection projections. Owner
access remains. Queue revisions cover text, photo references and same-path
Storage replacements. Worker results require an unexpired matching lease;
withdrawal, deletion, edits and human decisions fence stale responses. Repeated
failures transfer to human review. Only appointed active operators can read the
review queue or decide; self-review is rejected. Owners have minimal status and
idempotent reconsideration RPCs. Native status/review screens compile; batched runtime acceptance remains pending.

Recipe projections now allowlist nested shared brew details. Private notes,
order notes, companions and unknown nested fields are excluded; internal step
IDs are also omitted from provider input. At this early checkpoint private recipe versions were held owner-only,
including legacy recommendation paths; that regression is superseded by the
[private recipe correction](#private-recipe-recipient-access) below. The earlier
implementation required a shared
recipe audience and an approved revision. Public list copies filter held source
items so copying cannot expose an unscreened note through owner access.

The worker admits only validated owner-scoped media, rechecks the current lease
before transmission, strips metadata, and requires explicit release flags.
Reviewer media previews require live authentication and an active operator
appointment and expire after 60 seconds. No scheduler, production migration,
server secret or production processing has been enabled. The endpoint's live
integration, all outward surfaces (including notifications), and the full
historical migration replay still require acceptance. Local tests use synthetic
fixtures; no user content has been sent.

Native Settings now opens Shared Content Status with the latest 100 owner
records, review reasons and reconsideration. Active operators can page through
screening states, load the current revision and expiring media, inspect signals
and decision history, and record approval or rejection with a required reason.
The server rejects self-review and a mismatched expected account. Preview
images use an ephemeral session; approval waits for every image to load.
Backgrounding and account changes clear the displayed state. Authorized
parent navigation rows remain mounted while inspecting a child preview; clearing
them on disappearance could remove the active navigation destination.
This is screening review, not yet the complete report/enforcement dashboard.

Latest screening checkpoint: `verify-no-simulator.sh full-static` passed 12
checks with zero failures and one optional pglast skip. This includes the native
status/review app/test compile, cached Deno checks and synthetic PostgreSQL
contracts. Documentation validation and diff whitespace checks passed. No
Simulator, production project or TestFlight build was touched.

Next implementation priorities: operator report/appeal enforcement (including
list-comment reports), notification and remaining outward projection audit,
truthful post-save receipts while screening is pending, published provider
processing disclosures, worker schedule and rate controls, then the remaining
deletion and release-capability work. Reviewer endpoint authentication and
media-preview behavior now have synthetic handler coverage; live integration
acceptance remains required. The existing
shared-media public-bucket/cache boundary must be assessed during the outward
surface audit; synthetic projection tests alone do not prove object revocation.


## Report and appeal operations checkpoint

Added operator-only pending/reviewing/closed queues for existing account,
Mugshot and comment reports and enforcement appeals. Native operators can
inspect recorded text/context and history, resolve or dismiss reports, apply
warnings, hide reported content, restrict social access or suspend an account,
and uphold, shorten or reverse appealed actions. Existing durable audit and
ownership triggers remain authoritative. Decisions require the expected actor
and case status; stale submissions cannot create a second action. Reviewers
cannot handle their own reports, reported content or appeals, or revoke their
own enforcement. Queues recheck live operator appointments on every request.

The focused PostgreSQL contract passes projection minimization, queue cursors,
revoked access, self-review, account mismatch, stale status, enforcement and
appeal reversal using the existing subject ownership/report binding triggers.
Cafe-list comment reports are now bridged into this queue by the next migration; see the checkpoint below.
Current media inspection from a report is implemented in the later preview
checkpoint; complete integration/runtime acceptance remains open. No report evidence or human decision is sent to OpenAI.

Report-review checkpoint verification: the complete `full-static` gate passed
12 checks, zero failures and one optional pglast skip, including the native
app/test compile and all registered synthetic PostgreSQL contracts. Documentation
validation and diff checks passed. Implementation remains on the Sprint 1
feature branch; no production changes or TestFlight actions were performed.


## List-comment report integration and save receipts

Legacy list-comment receipts now enter the durable report queue with their
existing IDs. New reports use the same bridge; repeated submissions retain the
first evidence. The report and action subject contracts, ownership checks and
report binding now support cafe-list comments. Human hide decisions suppress
otherwise approved comments, and the existing appeal flow can reverse them.
Deleting a comment removes its legacy report pointer but retains the durable
case evidence and enforcement ownership. Backfilled text is the currently
available text captured during migration, not a reconstruction of original
report-time content; the UI calls it saved report text.

Focused synthetic checks pass backfill, new reports, duplicate evidence,
self-review denial, owner binding, hide/reversal and evidence retention after
deletion. Native report/enforcement labels and hide actions support these cases.
Post-save receipts say Mugshot saved and confirm journal storage without claiming
immediate publication. Existing UI assertions now use that truthful wording;
their execution remains part of the batched acceptance gate.


List-comment/save-receipt checkpoint: `full-static` passed 12 checks, zero
failures and one optional pglast skip, including native app/test compilation and
the extended synthetic report/appeal contract. Documentation and diff checks
passed. Read-only Supabase inventory found production healthy at 127 migrations,
with the August 26 profile migration present, reactions/Sprint 1 absent, and no
QA branch. No production mutation was performed. This inventory is not a
backup, fingerprint or full-history alignment proof; those release gates remain.


## Reviewer preview checkpoint

The reviewer endpoint now has four synthetic handler tests covering missing or
invalid authentication, absent operator permission, role revocation and privacy
withdrawal during signing, malformed/oversized input, owner-scoped media
admission and private/no-store responses. Request bodies are limited while
streaming, Supabase calls have deadlines, and the current revision is checked
again after signing. These tests do not contact a live backend or provider.

Reports link to the current shared revision through an operator-only locator.
It returns no raw payload or lease; the existing authenticated preview fetches
current text and expiring images. Private/deleted content with no queue entry
has no current preview. The synthetic PostgreSQL contract covers mapping
list-comment subjects, withdrawal and revoked access. Historical saved report
evidence stays distinct from current shared content. Native and deployed
endpoint acceptance remain pending.


Disclosure source now names OpenAI moderation and the exact classes of shared
content processed, excludes Private journal content/notes/recipes, states no
training opt-in and explains human review/appeals. Native Privacy and Visibility,
native policy summaries, and both websites have matching language. Websites
link to current OpenAI processing/retention documentation rather than claiming
that no training means no external processing. These policy changes are not yet
published; release configuration must remain disabled until they are available.


Preview/disclosure checkpoint verification: `full-static` passed 12 checks,
zero failures and one optional pglast skip, including all cached Deno tests,
synthetic PostgreSQL contracts and native app/test compilation. Marketing
`npm run verify` passed checks, formatting, tests, build and route verification.
PWA build and focused policy-page ESLint passed. Documentation and diff checks
passed. No live API content processing, production mutation or release upload
occurred. Remaining work includes the full outward/notification audit, rate
controls and scheduler, deletion completion, isolated full-history QA, deployment
and batched native acceptance before any separately authorized TestFlight gate.


## Activity screening checkpoint

Notification creation now uses sealed candidate checks that preserve the
existing audience, relationship and enforcement rules while allowing a durable
event to wait for screening. Public activity and actual push checks still
require screened actor/visit/comment content. Pending eligible deliveries wait
for approval for up to 24 hours; older held pushes expire to avoid a delayed
burst. An edit after claim releases the fenced lease without spending an APNs
attempt. Blocks, disabled devices, preferences and account restrictions retain
their cancellation behavior.

Generated notification titles/bodies now use app-owned generic copy, and list
titles are removed from lifecycle metadata, so edited or deleted user text is
not retained in notification snapshots. Existing notification identity, read
state, receipts and delivery history are preserved. Applying this migration
updates generated presentation fields and therefore requires the same live
fingerprint/backup checks as the other release migrations.

Synthetic tests pass pending creation, approval, edit/reclaim fencing, block
cancellation, 24-hour expiry, generic copy and metadata exclusion. The wider
outward audit remains incomplete. It also identified that new screening gates
must preserve explicitly invited collaborators' existing private-list access
without sending Private list content to OpenAI; the compatibility correction
is implemented and covered in the checkpoint below.


Private collaboration correction: Private lists continue to exclude all nested
content from the external screening queue. Existing explicit invitations still
control access: pending invitees can see the permitted summary, accepted
collaborators can read items, friendship alone grants nothing, and blocks or
membership removal revoke access. Anonymous/public projections remain closed.
The focused PostgreSQL contract verifies these distinctions and reads an owner's
private list note as an accepted collaborator without creating any screening job.
This preserves the existing private collaboration feature rather than treating
Private lists as public content or silently removing collaborator access.

Activity/private-collaboration checkpoint: backend verification passed 11 checks,
zero failures and one optional pglast skip. The shared lease fixture refactor
also passed the existing lease/retry/badge contracts. A separate generic Debug
app/test compile passed the review-navigation correction. Documentation and
diff checks passed. No Simulator, production migration or push dispatch was
performed. These are deterministic checks, not deployed notification acceptance.


## Apple deletion provider boundary

Added a server-only Apple authorization-code exchange and token revocation
module. It fetches verification keys before consuming the one-use code, verifies
the returned identity token's signature/issuer/audience/subject/expiry, bounds
requests and response sizes, and returns only sanitized failure categories.
Five synthetic Deno tests cover valid exchange, wrong identity/app/issuer,
expired/forged tokens, key-fetch failure, repeated revocation requests and
client-configuration versus spent-code errors. No live Apple request was made.
Deletion endpoint logs no longer print raw error objects or job identifiers.

At this boundary-only checkpoint, the module was not connected to deletion.
The later [durable integration](#durable-apple-cleanup-integration) supersedes
that implementation state. Native authorization-code capture,
encrypted durable provider-token storage, recovery orchestration, configured
Apple credentials and acceptance remain required. Apple guidance also requires
fulfilling deletion when no provider token/code can be recovered; provider
cleanup must not strand an otherwise valid account-deletion request. See
[Apple TN3194](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple).


Apple boundary checkpoint: backend verification passed 11 checks with zero
failures and one optional pglast skip, including five synthetic Apple tests and
the existing account-deletion PostgreSQL recovery contracts. Documentation and
diff checks passed. No native code, live Apple credentials, production settings
or real account were changed in this checkpoint.


## Durable Apple cleanup integration

The native deletion flow now passes Apple's authorization code only in the
fresh, account-bound authorization request. It is not added to the Keychain
recovery record. After server-side step-up verification, the endpoint derives
the Apple subject from `auth.getUser` identities, validates the exchanged token
and encrypts the refresh token with AES-GCM. The encryption context binds the
credential to its deletion request and Apple client ID. The sealed queue stores
ciphertext only, attaches to the prepared deletion job and clears its duplicate
subject ID. Missing or unrecoverable Apple credentials do not block deletion of
Mugshot data.

The existing authenticated scheduled cleanup action drains one provider item
per invocation after ordinary cleanup. A job is eligible only after confirmed
Mugshot identity deletion. Five-minute leases fence completion; failures have
bounded backoff and at most ten attempts. Unattached credentials expire after
15 minutes; attached credentials expire after seven days. Success or exhausted
retention erases ciphertext. Minimal outcome receipts expire after 30 days.
Missing provider configuration still runs expiration housekeeping with a
zero-size claim, without spending retry attempts. Provider errors and secrets
are excluded from logs and worker responses.

This affects Auth/Edge/schema contracts, privacy/data ownership and native
networking. Deterministic verification covers encryption/context tampering,
verified staging, identity-deletion eligibility, stale leases, retry, erasure,
configuration gaps and provider/persistence outages. Native lifecycle coverage
now also asserts forwarding the one-use code after fresh authentication.

Required server configuration is `APPLE_DELETION_CLIENT_ID`,
`APPLE_DELETION_CLIENT_SECRET` and `ACCOUNT_PROVIDER_ENCRYPTION_KEY` (a base64
32-byte AES key). No values are in source or these documents. Credential
provisioning/rotation and end-to-end acceptance
remain open. The migration and worker are not deployed; no real account or
Apple authorization was deleted/revoked by this work. Keep deletion activation
behind the existing release gates until the complete candidate is accepted.


Durable integration checkpoint: `verify-no-simulator.sh full-static` passed
12 checks with zero failures and one optional pglast skip. This includes the
new PostgreSQL provider queue contract, 13 synthetic Apple/encryption/staging/
worker tests, the existing backend suite and a generic Debug app/test compile.
The native forwarding assertion compiled; it has not yet executed in the
batched Simulator acceptance run. Documentation and diff checks passed. No
production migration, server secret, provider request or real deletion occurred.


Provider-status follow-up: the endpoint reads minimal Apple cleanup state only
for a verified deletion/recovery request and its exact job. The service-only RPC
returns pending, revoked or unavailable, without identifiers or credentials in
the value. Native completion messages preserve the proven Mugshot deletion
outcome and separately explain Apple cleanup status. Missing Apple client
configuration can now persist an unavailable receipt without holding up deletion.
A status absence does not assert that Apple access was revoked. Focused SQL
coverage checks request/job fencing, transitions and grants; the native ordered
flow assertion now includes pending provider status in the returned outcome.


Provider-status verification: full-static passed 12 checks, zero failures and
one optional pglast skip, including the updated request/job status contract and
generic Debug app/test compile. No Simulator was booted. Source inspection of
`DrinkAnalysisService.swift` and the complete `analyze-drink/index.ts` confirms
that this existing path performs deterministic backend parsing (`edge-rules-2`)
and writes Mugshot's own analysis projection; it makes no external model call.
Targeted provider/endpoint searches in the companion PWA source/functions and
marketing source found the new disclosures and unrelated typed response fields,
not another model integration. These source checks do not prove deployed Edge
source parity or replace the remaining outward-surface and telemetry audits.


## Screening dispatch controls

The source now enforces dispatch budgets in the claim RPC, across overlapping
worker invocations: 60 claims per calendar minute globally, ten per owner, six
concurrent leases globally and two per owner. The short global reservation lock
prevents concurrent budget overspending. Candidate scans are bounded and skip
currently saturated owners; excess jobs remain pending without consuming
attempts. Existing lease/revision fences and five-attempt human-review fallback
remain intact. Per-owner counters cascade on deletion and inactive counters are
purged by claim housekeeping. These limits affect backend operations and private
data ownership; they do not expand audiences or approve content.

The focused hermetic test covers owner fairness, global/owner concurrency,
minute budgets, retry preservation while throttled, window reset and deletion.
Scheduler installation, realistic backlog throughput and production activation
remain open. Supabase's current [Cron quickstart](https://supabase.com/docs/guides/cron/quickstart)
supports second-based intervals on supported Postgres versions; the exact
schedule still needs isolated QA and operational release evidence.


Dispatch checkpoint: backend verification passed 11 checks, zero failures and
one optional pglast skip. A focused rerun passed after moving the minute-window
clock read inside the reservation lock. Documentation and diff checks passed.
No native code changed, so no new compile or Simulator run was needed. All
screening migrations remain local-only and the external-processing activation
flags remain unset in production.


## Screening scheduler definition

The source now defines a service-only, idempotent ten-second screening schedule.
Migration application alone never starts it. Operational activation requires
separate Vault URL/worker-secret provisioning and the existing Edge disclosure,
no-training and enabled flags. Scheduler SQL contains no embedded credential;
Vault values are resolved only during dispatch. Empty/fully leased queues skip
HTTP dispatch, the URL must be the expected Supabase Edge route, and disabling
removes only the canonical screening job. This affects database operations and
secret ownership; no publication or training permission changes.

Synthetic Cron/Vault/HTTP fixtures verify default inactivity, missing/invalid
configuration, idempotency, secret isolation, empty-queue skip and disabling.
These mocks do not prove deployed extension behavior or realistic throughput.
Read-only branch inventory still shows only production. The Supabase tool
requires organization confirmation before quoting a paid disposable QA branch;
that question is pending for `joe's Org`. No branch was created or paid resource
activated while awaiting that response.


Scheduler checkpoint: backend verification passed 11 checks, zero failures and
one optional pglast skip, including the new scheduler fixture contract and all
existing hermetic contracts. Documentation and diff checks passed. No native
change or Simulator run was needed, and no production schedule or secrets were
installed. Isolated QA remains required before activation.


## Private recipe recipient access

Corrected the screening gate's incompatibility with existing explicitly shared
Private recipes. Friendship alone still grants no access, anonymous access stays
closed, and dismissal/block rules still revoke the recipient's access. An
explicit recipient can again read the permitted recipe identity/version and
projection without putting the Private recipe in the external screening queue.
The separately shared recommendation note keeps its existing screening behavior;
this exception does not approve shared Friends/Everyone recipe content.

The focused PostgreSQL contract passes recipient, no-invitation, anonymous,
block, dismissal and queue-exclusion checks, alongside the existing collection
contracts. This affects product behavior and Supabase read contracts. It is a
source correction, not a deployed change or installed-app acceptance result.


Private-recipe checkpoint: backend verification passed 11 checks, zero failures
and one optional pglast skip. Documentation and diff checks passed. No native
code changed, and no production migration or provider request was performed.


## Outward read audit: displayed drink fields

Found and corrected an allowlist gap: public projections display `drink_type`
and `drink_subtype`, while the initial visit payload included only the custom
name. Both displayed fields now participate in screening and revision changes.
The forward migration recomputes shared payloads without provider calls; Private
notes remain excluded. Focused PostgreSQL checks verify that displayed drink
edits hold the post, include the fields and preserve private-note exclusion.
This affects shared product behavior, payload ownership and Supabase contracts.

Additional source findings: `get_friend_map_sip_summaries_v1` is SECURITY INVOKER,
so its visit reads receive the restrictive screening RLS policy alongside
existing privacy policies. `discover_public_cafes` uses the screened
`is_public_visit_discoverable_v3` helper. Activity listing calls the current
screened event-visibility helper before joining actor presentation data. The
20260804204427 migration retired shared-memory public functions and removed
client grants; old definitions are historical, not current live APIs to revive.
These findings are based on the ordered local migration source. Full-history
QA, deployed source/grant parity and the remaining cafe/media/telemetry paths
still require evidence before the outward audit can close.


Shared-drink checkpoint: backend verification passed 11 checks, zero failures
and one optional pglast skip. Documentation and diff checks passed. This source
correction did not change native code, invoke a provider or mutate production.


## Cafe catalog write boundary

The outward audit found a legacy policy allowing any authenticated client to
update any shared cafe record. Source inspection of native `CafeService` and
PWA `useUpsertCafe` found resolve/insert flows, with no direct catalog-update
path. A forward migration removes the permissive update policy and client
UPDATE grants while preserving reads, inserts and trusted server corrections.
No existing catalog rows are rewritten. This closes an unchecked edit path into
names/links used across other users' already-screened posts and lists.

The focused PostgreSQL role test verifies authenticated/anonymous update denial,
normal insert/read behavior and service-role correction. This affects shared
product integrity and Supabase grants. The broader provenance/admission policy
for newly inserted cafe records remains an open outward-audit item; this fix
must not be presented as complete cafe-content moderation.


Cafe write-boundary checkpoint: backend verification passed 11 checks, zero
failures and one optional pglast skip. Documentation and diff checks passed.
No native code changed, and no production cafe row or grant was mutated.


## Live Edge inventory and stale notification endpoint

Read-only production inventory on 2026-09-13 found `delete-account` v8,
`deliver-activity` v6, `public-cafe-list` v6, `shared-mugshot` v6,
`shared-profile` v3 and `analyze-drink` v5. The new `screen-content` and
`moderation-review` endpoints are absent. These versions establish deployment
work remaining; local implementation is not production parity.

The still-deployed `notify-friends-on-new-visit` v8 contains a legacy push path
that trusts caller-supplied author/visibility fields and uses server credentials
to fetch friends/devices. Its old trigger was removed by migration
`20260722030904`, and current native/PWA source has no caller. Prepared a
replacement with no service dependencies or payload reads: every handled
request returns HTTP 410 with a no-store, content-free retirement response.
The source retains the existing JWT verification setting. Deploying this
replacement is required before closing notification delivery safety; it has
not been deployed or invoked against real data in this checkpoint.


Legacy endpoint checkpoint: backend verification passed 11 checks, zero
failures and one optional pglast skip, including the retirement response test.
Documentation and diff checks passed. The production inventory/source reads
were read-only; no push, endpoint deployment or server setting was changed.


## Remote screening contract coverage

Added `supabase/tests/sprint1_screening_queue_contract.sql` to the directory
executed automatically by the full remote QA runner. It requires the reserved
`.invalid` QA identity and uses a rolled-back transaction. It verifies sealed
worker grants, eligible claiming, edit revision changes, stale-result rejection,
current unflagged approval and complete payload withdrawal. The corresponding
local harness runs the same SQL against the real queue/rate migrations with
minimal PostgreSQL fixtures; it passes. No provider or production call occurs.

This closes a test-discovery gap, not the full remote acceptance gate. Existing
remote social/publication contracts may need explicit screening decisions where
they previously assumed immediate publication; their behavior must be reviewed
when the complete migration history is exercised. Do not disable screening in
QA to manufacture a passing suite.


Remote-contract checkpoint: backend verification passed 11 checks, zero failures
and one optional pglast skip, including execution of the new remote SQL file in
hermetic PostgreSQL. Documentation and diff checks passed. Remote QA has not
run; no production row or setting was changed.


## Apple configuration access checkpoint

Checked the repository's ignored configuration and conventional local signing
credential directories without printing credential values. No usable Apple
Sign in with Apple deletion credential was found there. Available tools did
not expose an Apple signing-key provisioning connector. Opening Apple Developer
Keys redirected to Apple sign-in; native app access separately reported that
the Mac is locked. The user has been asked to unlock/sign in so provisioning
can continue. No Apple key, account or capability was changed.

Generated the independent 32-byte provider-encryption key in the ignored local
`.codex/.env.apple-deletion` file with mode 0600. The file is not tracked and no
secret value was printed. It has not been uploaded to server configuration.
Preserve this key while any queued ciphertext depends on it; rotation requires
a deliberate drain or re-encryption procedure, not overwriting the secret.
Apple client configuration and live revocation acceptance remain incomplete.
The separate Supabase QA organization confirmation is still pending.


## Feedback ledger reconciliation

The local Xcode Organizer cache contains 45 feedback packages. Compared package
IDs with the living ledger and found exactly one unmapped report from
0.5.3 (6), submitted on 2026-09-03. Added it as report 45: a suggestion for
“Journal entry: Sip” terminology and explanatory sharing copy. No tester name,
account data, screenshot or raw log was copied into the repository. The report
remains Open and unimplemented; it is not an approved Sprint 1 requirement.
The historical 44-report remediation and its acceptance chronology are retained.
This resolves the count discrepancy without inventing acceptance or expanding
the confirmed sprint scope.

Local database runtime check found no Docker, psql or postgres executable on
PATH. The disposable Supabase QA branch remains the required full-history
validation route; its organization confirmation and Apple sign-in are pending.


## Account-bound reaction compatibility

Source inspection confirms that missing expressive-reaction RPCs preserve
Like/removal through the existing table path and reject Love/Laugh/Yummy with
an explicit unavailable error; missing reaction columns use legacy Like reads.
Added `set_visit_reaction_v2` to require the initiating account to match the
server-authenticated actor before calling the existing reaction implementation.
Native service checks the account before/after requests, and Feed/detail ignore
stale success or error updates after account changes. The V1 contract remains
for older clients. This affects networking, account isolation and Supabase RPCs.

Focused PostgreSQL coverage confirms a mismatched actor is rejected and the
current actor can still set Love, alongside existing replacement, removal,
visibility and block tests. Production still lacks the original reaction
migration and the V2 wrapper. Complete QA replay and installed-app persistence/
account-switch acceptance remain required before claiming reactions delivered.


Reaction account-switch UI review additionally clears Feed pending state when
the account changes, closes an old-account detail view, and checks the actual
SDK account before applying detail responses. Backend/full-static verification
passed 12 checks, zero failures and one optional pglast skip before this final
UI adjustment; the separate final generic Debug app/test compile also passed. No
production migration or live reaction was performed.


## Native review-screen concurrency review

Reviewed the complete new native screening service, status/review screens and
report/appeal views before publication. Found and corrected refresh/background
races in the status, queue and preview screens: request IDs now fence results,
errors and loading cleanup; background clearing invalidates in-flight work;
refreshed previews recreate image loaders and restart their expiration task.
The report/appeal views already use request IDs. This affects asynchronous UI
behavior and review-data lifetime. Fast verification passed 7/0/0, and the generic Debug app/test compile passed;
rapid-refresh/background and account-switch runtime acceptance remain pending
in the batched Simulator gate. The full accumulated patch review is not yet
complete, so no checkpoint commit or push is claimed.


## Screening boundary source review

Reviewed the complete worker/media resolver, reviewer Edge handler/dependencies
and sealed queue migration. Media admission uses the job's owner/visit path,
then rechecks the revision lease before provider submission. Reviewer previews
recheck appointment/revision after signing, use short-lived URLs and no-store
responses. Full-history QA and deployed Storage behavior remain required.

The review identified two corrections in the still-unapplied queue migration:
list responses no longer duplicate raw payloads, provider evidence, history or
owner IDs that the list UI does not use; and owner deletion now cascades their
screening history, including free-text reconsideration/review reasons. Reviewer
attribution on other owners' records remains nullable after reviewer deletion.
Focused contracts verify minimal list fields and erasure of the deleted owner's
screening history. This affects privacy/data ownership and Supabase responses;
no native decoder change is required because detail fields are optional.


Boundary-review checkpoint: backend verification passed 11 checks, zero failures
and one optional pglast skip. Documentation and diff checks passed. Reviewed
source hashes were recorded locally to detect changes before final staging;
the complete patch review, commit/push and release acceptance remain open.
No production data or configuration changed.


## Recipe recipient authorization review

Primary publication and shared-collection migrations were read in full. The
raw recipe-version/identity recipient predicates lacked the owner/sender account
checks already used by the safe projection. A focused regression reproduced
raw access surviving suspension. Migration
`20260913054056_sprint1_recipe_recipient_authorization.sql` aligns those raw reads
with live-account, suspension, profile-screening and block checks while preserving
owner access and explicit Private-recipe recipient access without provider input.
This changes Supabase access control and privacy behavior; deployment remains
pending the data-less QA branch and full remote contract suite.

Recipe-recipient checkpoint: the added regression failed before the fix and
passed afterward. Backend verification completed with 11 passed, zero failed
and one optional parser skip (`/tmp/mugshot-recipe-recipient-review.log`).
No Swift changed, so no additional app compile or Simulator run was needed.
No production configuration or data changed.


## Durable report owner review

Read the report operations, list-comment report bridge and current-content
preview migrations in full. The review found that V2 owner actions lost their
subject after content deletion even though sealed report evidence survived.
Migration `20260913054240_sprint1_deleted_report_owner_resolution.sql` falls back
to that server-captured owner. Existing V1 validation and enforcement triggers
still reject unavailable or unrelated subjects; self-review checks still use
the snapshot. A focused regression reproduced the missing owner warning path.
This affects moderation behavior and Supabase contracts; production is unchanged.

Durable-report checkpoint: the deleted-content regression failed before the
fix and passed afterward. Backend verification passed 11 checks, zero failures
and one optional parser skip (`/tmp/mugshot-deleted-report-review.log`). Also
completed source review of the screened-activity delivery migration, including
its candidate/visible separation, lease release after edits, and notification
copy backfill. This is source/local evidence only; live backup and QA/deployed
delivery acceptance remain required before migration rollout.


## Deletion and dispatch source review

Reviewed the account-deletion endpoint diff, Apple token exchange/revocation,
encryption, staging and worker modules, sealed provider queue migration, and
native credential/receipt integration. The source validates Apple identity from
server-owned account data, encrypts tokens with request/client context, waits for
Mugshot identity deletion before revocation, and bounds retries and credential
retention. Provider failures do not block Mugshot deletion. These are reviewed
source properties, not live Apple acceptance; credentials and runtime gates
remain open.

Also reviewed screening dispatch budgets and the scheduler definitions. Limits
are reserved under a database lock, and migration application alone creates no
active screening schedule. Reviewed the remaining small settings, report-label,
share-receipt and Edge JWT configuration diffs. Current source-review hashes are
recorded locally for 32 files; tests and remaining changes still require final
scoped review before publication. No implementation changed in this checkpoint,
so no equivalent backend or native build was repeated.


## Reaction and verification-source review

Reviewed the remaining reaction service/Feed/detail changes and native test
diffs, Private-list compatibility migration, displayed-drink and cafe-write
boundaries, retired notification handler/test, and the focused rate, schedule,
provider-queue, cafe-write and remote-screening SQL test sources. The local
remote-contract harness is explicitly a minimal schema check; it does not prove
full-history remote compatibility. The current reviewed-source ledger contains
54 file hashes. Remaining test/fixture and documentation diffs still require
review before staging and publishing.

A credential-pattern scan of changed and untracked publishable files found no
matching API keys or private-key blocks. Both local credential files remain
Git-ignored. This scan supplements, rather than replaces, the complete diff
and staged-file review. No implementation or production state changed here;
no already-passing build or backend suite was repeated.


## Final test-source and living-document review

Completed review of the remaining provider/reviewer/worker synthetic tests,
queue/publication/report contracts and lockfiles. Verified that the extracted
activity fixture exactly matches its prior SQL. Updated the release workflow
to the actual migration head, corrected the feedback table formatting, and
clarified the feature matrix's production-versus-source profile consent state.
The tracker diff remains the last native-repository review item before the
final staged-scope/secret check and checkpoint publication. Production and
runtime acceptance remain open; no new tests or builds were needed for these
documentation corrections.


## Reviewed implementation checkpoint

The accumulated native/backend source, test and documentation review is now
complete. The branch is ready for a draft PR checkpoint after an exact staged
file/hash check. Local backend verification remains 11 passed, zero failed and
one optional parser skip; the latest native review-screen app/test compile and
fast gate passed. Credential files remain ignored.

This checkpoint does not authorize activation or prove release completion.
Outstanding work includes the cafe-record admission and media/cache/telemetry
audit, full remote QA replay and endpoint acceptance, Apple configuration,
production fingerprints/backup/deployment, reviewer appointment, processing
disclosures and no-training re-verification, and batched native acceptance.
Keep the existing PR in draft while these release blockers remain.


## Published draft checkpoints and web CI repair

Native/backend commit `0b9b434` is pushed to draft PR 66; its worktree is clean
and GitHub reports no checks for that PR. The reviewed commit contains 79 files;
its full commit whitespace check passes and local credential files are excluded.
PWA disclosures are pushed as `8d08d58` in draft PR 13, with a successful Vercel
preview. Marketing disclosures are pushed as `96fe895` in draft PR 18.

Marketing CI passed verification and preview deployment but failed its npm
audit on Astro, Sharp, js-yaml and SVGO advisories. Commit `14f62d1` patches
Astro to 7.2.8 and Sharp to 0.35.4, with updated js-yaml/SVGO dependencies. Local
verification passes 14 tests, build and 20-route checks; npm audit reports zero
vulnerabilities. The replacement remote checks are pending. These are draft
branches and preview deployments, not production disclosure publication.


## Website CI acceptance and public-media inventory

Marketing commit `63ee3cc` repaired npm 10 clean-install compatibility after
npm 11 omitted optional runtime entries. GitHub run `34741493034` completed
successfully, including clean install, verification and dependency audit; its
Vercel preview also passed. PWA `8d08d58` preview checks passed. All companion
PRs remain draft for the coordinated backend release.

Read-only Storage inventory on 2026-09-13 confirms `profile-media` and
`visit-photos` are public; `visit-photos-private` is private. Aggregate counts
are 86, 29 and 204 objects respectively. No object paths or content were read.
Native profile uploads currently request a one-year cache lifetime and return
public URLs. The shared recipient resolver currently passes HTTPS URLs through
and signs only private visit references for five minutes. Therefore database
projection gates alone do not establish media revocation or screening safety.

Required next work: support authenticated/anonymous-authorized delivery for
profile and legacy visit media, keep existing object references compatible,
apply matching Storage read gates and private-bucket configuration only after
QA, and validate URL/cache lifetime on privacy changes. Existing cached or
downloaded copies cannot be treated as recalled. This remains an explicit
release blocker; no production bucket or object was changed.


## Protected recipient media preparation

Shared-profile and shared-mugshot endpoints now resolve historical own-project
Storage HTTPS references through one-minute signing, including profile media
and legacy visit photos. Private visit references use the same lifetime. Missing
signing credentials no longer fall back to a permanent own-Storage public URL;
foreign URLs never receive service-role signatures, and returned signatures must
remain on the configured project origin. Only fields already admitted by each
recipient projection reach this helper.

This changes Edge/media contracts and is only the first part of protected
delivery. Native profile/legacy image resolution, Storage policies, bucket
privacy and cache/runtime acceptance are still pending. No bucket or deployed
endpoint changed. Existing foreign HTTPS projection behavior is retained for
compatibility and remains part of the outward-media audit.

Protected-recipient checkpoint: backend verification passed 11 checks, zero
failures and one optional parser skip. The focused media contract verifies
legacy profile signing, one-minute expiry, missing-signer denial, and malformed/
foreign path rejection for signing. Source review and whitespace checks pass.
Native code, production buckets and deployed Edge functions are unchanged.

### Native protected-media preparation — September 13, 2026

Implemented in source: own-project legacy profile/visit public URLs now resolve
through viewer-authorized Storage signing for 60 seconds. Avatar, banner, and
visit-photo views discard displayed bytes on account/foreground changes and
reauthorize visible images every 55 seconds. Signed image downloads bypass the
shared image memory/disk caches; profile-share artwork uses an ephemeral session.
Foreign image compatibility remains under audit. Previously downloaded or cached
public copies cannot be recalled by this change.

This changes product media loading, Storage compatibility, and privacy behavior.
Production buckets are still public where inventoried; protected-bucket policies,
remaining media consumers, consolidated runtime acceptance, and deployment remain
open. Focused parser tests are added for own-origin, traversal, query, and bucket
boundaries. Compile/static evidence will be recorded after this source batch.

The protected-media source checkpoint passed `full-static`: 12 passed, 0 failed,
1 skipped (including hermetic PostgreSQL contracts and generic iOS app/test
compile). This is local evidence only. No Simulator, device, production data,
bucket configuration, or screening activation was touched. A final compile also
covers the monotonic refresh deadline, which includes signing/download time.

Next media gate: shared-link service-role signing must validate object provenance
against the projected author and visit, including avatars in Mugshot/profile-sip
responses. Current projection admission alone is not proof of Storage ownership.
Do not deploy this preparation before that boundary and bucket policies pass QA.

### Protected-media authorization follow-up — September 13, 2026

Supersedes the preceding next-media-gate implementation status: shared-link
signing now requires a server-derived author ID, exact visit ID for visit media,
and the correct bucket kind. The Mugshot endpoint resolves the admitted visit's
owner server-side without adding that private lookup to the response. Profile
and sip avatar fields now use protected signing too. Five focused Deno tests
pass, including cross-owner, sibling-visit, wrong-bucket and missing-owner
rejections before privileged calls. Both Edge entrypoints type-check with their
function configurations; an initial root-level check lacked the Mugshot JSX
configuration, corrected by checking from the function directory.

Migration `20260913061308_sprint1_protected_media_reads.sql` closes all three
user-media buckets and introduces exact current-reference, screening and
canonical audience checks. The previous anonymous raw Everyone read is removed.
An actual RLS test deliberately adds an old permissive allow-all policy and
proves the restrictive boundary still protects pending, unused, wrong-bucket,
Friends, Private and blocked media while preserving owner recovery. This test
uses only hermetic PostgreSQL with synthetic fixtures. It passes alongside the
existing primary/collection screening contract.

Remaining: public-cafe-list and other web/native consumers, cache/runtime
acceptance, full-history isolated Supabase QA, coordinated deployment, and live
verification. This source migration is not deployed. Do not close production
buckets until supported clients can resolve them. The existing no-training and
Private-content exclusion requirements remain unchanged.

Protected-media authorization verification: `./scripts/verify-no-simulator.sh
backend` completed with 11 passed, 0 failed, 1 skipped. Documentation checks and
whitespace checks pass. Native media source was compile-verified in the preceding
checkpoint and has not changed in this authorization follow-up. No remote
migration, live media fetch, user-content screening, Simulator, or release action
was performed.

### Protected web-media compatibility — September 13, 2026

Public cafe-list HTML now resolves user photos with the anonymous publishable
client and Storage RLS, with no privileged signing or permanent URL fallback.
Successful pages use private/no-store headers instead of shared caches. Six
focused Deno media tests pass, including anonymous Storage denials; the cafe-list
entrypoint type-checks.

The companion PWA now routes every user-image element through protected loading;
only bundled branding retains raw image elements. It clears signed blobs on
account/visibility/source changes, refreshes Storage authorization, and refreshes
shared-link projections every 45 seconds while visible. Postcard export waits
for image authorization/decoding and fences account changes. Seven focused web
tests, TypeScript, Vite build and targeted new-file ESLint pass. Existing upload
regression checks exposed stale header expectations; committed "Log a Sip" copy
was preserved and test expectations corrected.

This affects media loading, web sharing, Storage compatibility and privacy.
Production buckets and Edge Functions remain unchanged. Live signing/CORS,
remaining native direct-image consumers, cafe admission, telemetry/data export,
full isolated QA and consolidated runtime/deployment acceptance remain open.

The PWA compatibility checkpoint is committed and pushed as `6d0a5f0` on
`codex/sprint-1-sharing` (draft PR 13). Its seven new focused tests and six
existing AddVisit tests pass; final build and TypeScript checks pass. Production
publication and live-media acceptance are not claimed.

### Native media consumer closure — September 13, 2026

Source inspection found one remaining native `AsyncImage` consumer: companion
avatars in the Log a Sip form. It now uses the existing protected-image component
while preserving its initials fallback, size and appearance. The anonymous
Mugshot projection request now uses an ephemeral session without a URL cache and
checks cancellation before decoding. This changes media-loading/privacy behavior;
no Storage schema or production configuration is changed by this follow-up.

The native source inventory has no remaining direct `AsyncImage` calls or shared
URLSession data calls. Other `Data(contentsOf:)` calls found by the inventory read
local draft/library/photo-cache files, not remote Storage URLs. Focused generic
Debug compilation is the verification gate for this contained consumer change;
consolidated runtime and live Storage acceptance remain pending.

The native consumer follow-up passed generic Debug app/test compilation, plus
documentation and diff checks. Owner export was inspected: Storage references
are signed through the authenticated owner client, with owner/path allowlists
and account checks after download and before final package delivery. That
intentional owner export is distinct from public recipient media and is not
changed by this follow-up.

Marketing commit `0189162` makes HTML restoration conditional on share request
format, preserving upstream JSON and OG image response types. All four share
routes have private/no-store headers. The existing branded HTML fallback and
security headers remain. `npm run verify` passes with 14 tests, 20 generated
HTML routes and no Astro errors. Vercel query-based header conditions were
checked against official configuration documentation. Preview/live routing
acceptance and production rollout remain pending; draft PR 18 remains unmerged.

### Analytics erasure adapter — September 13, 2026

Historical adapter-only checkpoint; superseded by the queue integration below
and the current [analytics plan](POSTHOG_ANALYTICS_PLAN.md).

Audited native event snapshot construction: content-presence booleans and
controlled values are used instead of raw captions/notes. The PostHog identity
maps to the Supabase UUID, but the local deletion worker has no PostHog cleanup
integration. Read-only project metadata confirmed project `521217` matches the
native public token. No person/event records were read or deleted.

Added `delete-account/analytics.ts` for exact-account person lookup, scoped
cleanup submission, and asynchronous verification with submission-time fencing.
Four synthetic Deno tests pass, including stale receipts, partial cleanup,
owner mismatch and oversized response rejection. The adapter is not connected
to production or the deletion worker. Durable queue integration, scoped personal
API-key setup, SDK queue/reset handling and disposable-account acceptance remain
required. This is a privacy/analytics and backend-provider contract change; it is
not evidence of completed analytics erasure.

See [PostHog analytics plan](POSTHOG_ANALYTICS_PLAN.md) for the current contract
and authoritative provider references.

### September 13 analytics erasure queue integration

Added a durable account-bound PostHog erasure queue before identity deletion,
service-only lease/retry RPCs, scheduled worker integration, and a separate
native analytics cleanup receipt. The focused PGlite contract passes identity
ordering, surviving job removal, stale leases, other-account alias isolation,
and identifier clearing on verified completion. Provider acceptance remains
pending; event verification does not certify recordings. Production remains
unconfigured. See [analytics plan](POSTHOG_ANALYTICS_PLAN.md) for outstanding
SDK, support, credential, recording, and disposable-account gates.

Analytics queue checkpoint verification: seven synthetic Deno adapter/worker
tests passed; the backend gate passed 11 checks with no failures (optional
`pglast` parser unavailable; actual PGlite contracts passed). Generic Debug
Simulator build-for-testing compiled successfully. Documentation validation and
diff whitespace checks passed. No Simulator runtime or remote mutation ran.

### September 13 analytics accepted-submission retry fix

Persist provider acceptance separately from completion so pending erasure polls
its existing receipt instead of repeatedly enqueueing deletions. The focused
worker regression and actual queue contract verify this state survives retries.
SDK source inspection also confirmed reset/close do not dispose current disk
queues and app startup precedes deletion recovery; this remains an explicit
implementation gate in the [analytics plan](POSTHOG_ANALYTICS_PLAN.md).

Verification: eight synthetic Deno tests, the focused PGlite queue contract,
and documentation/whitespace checks passed. No native source changed, so no
additional compile or Simulator run was needed for this follow-up.

### September 13 native analytics deletion boundary

Moved SDK startup after account recovery. The real deletion POST now requires a
durable local analytics marker and closes telemetry for the rest of that process.
The next eligible launch purges only the configured PostHog namespace before
setup; failure keeps analytics off. Journal/media/Auth files are preserved.
Added isolated Swift disposal checks and a facade suppression/restart test.
The backend waits five minutes after identity removal; SDK requests use bounded
ephemeral sessions. Runtime and older-client/multi-device ingestion acceptance
remain open; see [analytics plan](POSTHOG_ANALYTICS_PLAN.md) for exact limits.

Verification: generic Debug Simulator build-for-testing compiled; fast gate
7 passed / 0 failed; standalone Swift quarantine and focused PGlite hold/queue
contracts passed. The native facade test compiled but awaits the consolidated
Simulator test run. No remote mutation or live provider upload was performed.

### September 13 shared cafe text screening

Native/PWA clients can supply cafe catalog text; provider IDs alone are not
verified provenance. The displayed cafe name/address/city/country/website now
joins the screening payload for shared visits, profile favorites, list items
and direct cafe recommendations. Empty notes no longer auto-approve unchecked
catalog text. Private-only visits/lists return before catalog lookup and still
produce no payload. Coordinates and provider place IDs are omitted.

Server catalog text corrections invalidate dependent revisions/leases in the
same transaction. Rebuilding snapshots is idempotent and does not append text
repeatedly. The migration rebuilds affected snapshots locally without provider
calls; it leaves direct catalog rows unchanged. Tests verify a pending public
list item is withheld, a correction invalidates approval, names/addresses enter
snapshots, and Private notes/selections stay excluded.

Direct catalog insert provenance and raw catalog read/projection admission
remain open. This is a shared-content screening fix, not a claim that all cafe
catalog surfaces are moderated or production configured.

Verification: backend gate 11 passed / 0 failed / 1 optional parser skipped;
focused actual-PostgreSQL tests passed after the final payload minimization,
including direct cafe recommendation invalidation. Documentation and whitespace
checks passed. No native source changed. No Simulator session or production
mutation ran.

### September 13 PWA sip-detail compatibility and account scoping

The raw-note concern resolves to an existing backend contract: legacy notes are
routed to the owner-only table and constrained null. Direct SELECT on both notes
and protected brew columns is revoked. PWA detail still requested them, so its
whole visit query could fail. The companion source now selects safe columns,
uses owner/shared recipe RPCs for brew method and drops the unused notes field.
Account/generation-scoped query keys, cancellation, cache removal and final
session checks prevent a late owner response from being reused after switching.

Three focused hook tests pass, along with TypeScript, focused ESLint and Vite
build checks. These are local synthetic checks; runtime/production acceptance
remain pending. The outward field inventory also identified shared `city_state`
and rating labels for screening-policy verification; do not infer full audit
completion from this compatibility fix.

PWA checkpoint `5f58528` is committed on `codex/sprint-1-sharing` for draft
PR 13. Native/backend source is unchanged in this follow-up.

### September 13 displayed visit location and rating labels

Verified native/PWA rendering uses `city_state` and custom names from `ratings`
and `category_scores`; these fields were missing from the visit screening text.
The new migration adds those displayed labels with a strict projection. Numeric
scores/weights, internal IDs, private notes and unexpected nested properties
are not serialized. Changing a displayed location/label invalidates approval;
changing only a numeric score or hidden metadata does not enqueue new text.
Private visits still return a null payload before any added text projection.

The focused PGlite screening/projection suite passes, including custom labels,
nested-field exclusion, revision changes and Private withdrawal. This is a
Supabase/privacy contract change with no native or web source changes. Remote
full-history QA and production activation remain pending; direct cafe catalog
admission is still open.

Checkpoint verification: focused PGlite behavior contracts passed and the fast
gate passed 7 checks with no failures. Documentation and diff checks passed.
No app build, Simulator session, provider request or production mutation ran
for this SQL-only change.


## Hosted contract fixture alignment — QA verified

Updated the remote harness to require inactive schedules and explicitly mark
its isolated test context. Scheduler assertions retain their command, cadence,
secret-reference and uniqueness checks, with inactive state required only in
that context. The reserved base QA profiles now give explicit consent and base
shared revisions finish simulated screening; Private content stays unqueued.
Later test mutations are not auto-approved. This is QA fixture behavior only;
production screening and permission rules are unchanged. The legacy media
contracts now require the protected buckets to be private, matching Sprint 1;
existing role/ownership and behavior assertions are retained. The consolidated
suite passed 55 of 56 contracts. The sole failure was a
source-inspection assertion expecting the transfer reader check in its old
function; it now verifies the guarded response helper and client privilege
revocations, and passes in a focused rerun. All 56 contracts therefore have
passing evidence across the full run and focused correction.


## Private tag notice regression — locally verified

Hosted QA exposed a real regression: the blanket visit-screening condition hid
an existing content-free notice for a Private sip, which correctly has no
screening job. Forward migration `20260913152000` allows that notice only for a
completed Private sip owned by the event actor with a current canonical tag.
Actor screening, live-account checks, blocks and recipient checks remain in
force. The existing projection grants no sip access, exposes no caption/photo,
and offers self-removal. Shared pending content still waits for screening.

The focused hermetic activity test passes for notice visibility, denied sip
access, no Private screening job, shared-content withholding, block enforcement
and tag removal. This is implemented and locally verified, not production
deployed. Hosted activity-delivery acceptance also passes.


## Ownership transfer during screening — implemented and QA verified

Migration `20260913152645` fixes a transfer rollback discovered in hosted QA.
Changing the owner intentionally queues a new screening revision. The mutation
now returns a content-free, existing-client-compatible confirmation while that
revision is pending; it does not return the list title, items, or previews.
An exact current-epoch receipt permits the former owner to retry safely, with
live-account, block and current-owner checks. The helper is private and denied
to client roles. Normal list reads remain subject to screening.

The focused hosted collaborative-list contract passes, including transfer,
former-owner editor membership, identical retry response, hidden pending
content, and new-owner leave/delete rules. This Supabase and privacy change is
not production deployed. The consolidated hosted run and focused security
correction cover all 56 contracts with passing evidence.


## Hosted QA closeout — 2026-09-13

The disposable `sprint1-fixture-qa-20260913` branch replayed all 154 migrations
through `20260913152645`. Provider credentials were not deployed, all scheduled
jobs stayed inactive, and only reserved synthetic fixtures were used. No
fixture payload was sent to OpenAI. The full run passed 55/56; after updating
the final source-inspection assertion to follow the new guarded transfer helper,
its focused rerun passed. This is 56 passing contracts across those runs, not a
claim that a single unchanged full run passed 56/56. The fast gate passed 7/7.

Security advisors reported 29 RLS-without-policy informational entries and
function-execution warnings for 28 anonymous and 186 authenticated RPCs.
The new private receipt helper is not client executable; the public transfer
RPC intentionally requires authentication and its existing ownership controls.
The broader RPC advisory inventory still requires release review; these counts
are not a clean security certification. See the [function advisory guidance](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable).

The paid QA branch was deleted after evidence capture. A fresh branch listing
contains only production `main`; its local database credential file was removed.
Production remains at its prior migration head. Cafe catalog admission,
provider/runtime acceptance, disclosure publication, and production rollout are
still open; no PR was merged and no TestFlight build was created in this batch.


## PostHog recording inventory — verified September 13

The connected PostHog tool resolves to the same Mugshot project as the signed-in
browser. Its project endpoint reports recording disabled, 30-day retention,
and project creation on July 20. `query-session-recordings-list` from July 1
with internal/test users included and no duration or property filters returns
an empty result. This supersedes the earlier duration-filtered browser result
and closes the current recording-inventory requirement. No recordings were
played, exported, or deleted, and no credential permissions were expanded.
Recheck configuration and inventory before activation. Provider event erasure,
SDK queue disposal, support recovery, and disposable-account acceptance remain
separate requirements.


## Analytics attention recovery — implemented and locally verified

Migration `20260913153904` adds an audited service-only retry for attention
items. Exact snapshot and operation IDs fence stale or duplicate recovery;
active, verified, or identity-incomplete work cannot be reset. The original
provider target, submission clock and accepted receipt remain intact. Normal
alias checks and lease fencing remain mandatory after recovery. The focused
PGlite test passes. This migration followed the 154-migration QA checkpoint;
the subsequent 155-migration hosted run below also passes. Production deployment
remains pending. Operating steps
are in the [analytics plan](POSTHOG_ANALYTICS_PLAN.md#recovering-an-analytics-cleanup-attention-item).


## Cafe verification and web search privacy — September 13

Catalog review confirms that native/PWA callers can submit cafe fields directly;
provider IDs do not attest those fields. The Apple account has only sign-in and
push keys, with no Maps identifier available for association. Prepared the
`Mugshot Cafe Verification` Maps identifier (`maps.co.mugshot.catalog`) for
registration. Registration/key creation await explicit new-credential approval;
no Maps access was created. Server place verification is not implemented or
production configured by this preparation.

The companion PWA's existing search functions logged raw queries and precise
coordinates and returned arbitrary provider/network error text. Removed those
logs and return fixed retry messages on failure. Both mocked-handler tests and
Deno type checks pass; provider requests and success results retain their
existing behavior. This privacy fix remains source-only pending coordinated
Edge deployment.


## Consolidated hosted acceptance — September 13, 155 migrations

The recovery QA branch replayed the exact repository migration history through
`20260913153904`. All **57 contracts passed in one full run**, including the new
analytics-recovery contract. That check covers stale snapshots, duplicate
operations, preserved provider target/evidence, active-work rejection, normal
lease completion and denied client execution. The prior 55-plus-focused result
is superseded by this full-run evidence. No provider request or production
mutation was part of the test.

The security advisor counts remain 28 anonymous and 186 authenticated definer
execution warnings. The private recovery audit table adds one expected
RLS-without-policy informational entry (30 total); clients have no access.
Existing RPC warnings still need release review. The QA branch was deleted,
its absence verified, and the local database credential removed. Only main
remains; no paid QA branch is left running.

OpenAI organization sharing controls were also reloaded from the server and
all three remain Disabled: feedback, evaluation/fine-tuning, and API inputs/
outputs. No data-sharing incentive was enabled. Maps credential approval,
catalog verification implementation, provider/runtime acceptance and coordinated
production rollout remain outstanding. No TestFlight build was created.


## Apple Maps credential — approved and authentication verified September 13

The owner approved the prepared Maps identifier and Maps-only credential after
reviewing their purpose. Registered `maps.co.mugshot.catalog` and created
`Mugshot Cafe Verification`, restricted to Maps and associated with that identifier.
This supersedes the pending-approval status above. Existing sign-in and push
credentials were not modified.

The downloaded private key is stored with owner-only permissions in the ignored
local credential directory, outside tracked source. A locally signed ES256 JWT
with only `server_api` scope successfully exchanged at Apple's `/v1/token`
endpoint: HTTP 200, with a 1,800-second access token. Neither the private key
nor either token was printed or committed. No user content or location was
submitted during this authentication check.

This verifies credential provisioning and authentication only. Cafe place
verification, catalog admission, production secret deployment, and runtime
acceptance remain open. OpenAI sharing settings and Private-content exclusion
remain unchanged; Maps authentication does not send anything to OpenAI. No paid
QA branch was created for this check.


## Cafe catalog implementation — September 13

Implemented `verify-cafe` for authenticated Apple/Google place-ID requests.
The server fetches the provider record, stores only canonical cafe fields, and
uses a service-only admission RPC with same-provider serialization and stable
IDs on retry. An atomic limit permits 30 attempts per account per hour. Native
and PWA provider-save paths call it; no caller labels are treated as verified.
A live Apple lookup of a public test cafe passes without any user content.

Raw cafe reads and legacy discovery/resolution now require provider admission
or an authorized content context. New manual cafes remain saveable with
submitter-scoped identities. Reference triggers reject guessed hidden IDs, so
creating a save/sip/list/favorite/recommendation cannot manufacture access.
Corrections withdraw provider admission and retain dependent screening refresh.
Private-only content is never queued to OpenAI.

The QA branch replayed all 156 migrations and passed all 58 contracts in one
full run. The new contract checks owner/other/anonymous access, hidden-reference
rejection, manual-name independence, retry identity, service-only grants, rate
limits and correction invalidation. Four Deno provider/handler tests pass.
The backend gate passes 11 checks with only optional pglast skipped. Native app
and both test targets compile; the PWA production build passes.

Advisors show 32 private RLS-without-policy informational entries and 29/187
anonymous/authenticated definer warnings. The one new public wrapper is
caller-bound through `auth.uid()` and returns only catalog readability; the
actual admission/rate functions deny clients. This is reviewed intentional
access, not a reason to grant more permissions. Existing RPC inventory review
and production/runtime release acceptance remain separate gates.


## Live server acceptance and profile replay repair — September 13

The deployed QA `verify-cafe` endpoint passed authenticated Apple verification,
anonymous denial, strict-field rejection and stable-ID retry. Live execution
found that the PostgREST pre-request hook denied service-role workers before
reaching their RPCs. Migration `20260913192620` grants that role permission to
execute the existing hook without changing user-session enforcement. The three
focused lifecycle/catalog contracts pass after the correction.

The QA screening worker successfully processed a synthetic profile with OpenAI.
A normal account was denied reviewer preview; a QA-only operator could preview
and approve another synthetic profile, with the decision persisted. All jobs
belong to reserved synthetic accounts; no production user content was sent.
All scheduled QA jobs remain inactive.

Real web profile acceptance then exposed the missing `users.website_url` column
in replayed history. Production already has that field. Migration
`20260913193804` adds it only when absent and includes website text in the shared
profile screening payload. A focused hosted contract requires an actual
non-empty admitted profile and sip projection and verifies that a website edit
is withheld until reviewed. The readable web profile now renders real QA data.

The native candidate launched against QA with analytics disabled and unchanged
compiled executable. Its sign-in screen renders, but the locked Mac prevents
input; automatic unlock failed. Simulator interaction is not accepted yet.
Backend and browser acceptance continue independently.


## Live media and deletion acceptance — September 13

All 158 migrations at the profile-website head passed all 59 hosted contracts
in one run. The public web profile consent test removed Friends posts while
retaining Everyone posts; an unknown handle showed the neutral unavailable
page. Actual Storage upload/owner recovery passed, while anonymous signing
and the historical public object URL were denied.

A disposable account with an uploaded photo exposed an initial deletion-job
count mismatch. Migration `20260913195241` records the initial manifest count
at insertion rather than waiting for V3's later sealing update. The count
constraint and authorization checks remain intact. Its focused non-empty
manifest regression passes against the 159-migration QA database.

The deployed deletion endpoint then passed the complete synthetic journey:
the original session cannot authorize deletion, a fresh password sign-in can,
Auth identity and actual Storage bytes are deleted, stale sessions are denied,
and capability recovery without a session returns completed. Apple token
revocation is a separate provider acceptance item; this account used email.
Only the deletion schedule was enabled in QA, with its destination explicitly
changed to the QA project and its credential held in Vault. Other schedules
remain inactive. The paid QA branch still requires cleanup after acceptance.

PostHog accepted erasure of one synthetic person with events and recordings
requested; the provider verification receipt is pending. No real account was
selected or deleted. Production session recording remains disabled.
The production physical backup dated 2026-09-13 12:35:29 UTC is visibly available.
Native interaction remains blocked by the locked Mac; server work continues.


The cleanup worker required explicit custom-auth deployment configuration.
Added `ACCOUNT_DELETION_WORKER_SECRET`, backed by the scheduler Vault slot, and
recorded `delete-account.verify_jwt=false` so the handler can authenticate the
worker bearer and recovery capability. User actions still require Auth checks.
Live direct worker acceptance now returns 200 for the configured secret and
401 for an unrelated bearer. The backend gate passes 11 checks, with only the
optional pglast parser skipped. Scheduled HTTP acceptance remains separate.


## Scheduled workers and companion integration — September 13

The actual QA deletion cron request returned HTTP 200 at 20:00 UTC with an
empty successful drain. The screening schedule processed the synthetic profile
in one attempt, approved its revision, and was then disabled. All scheduled jobs
are inactive again. The Private-visit screening queue count was zero.

The PWA branch now merges current main without conflicts. It retains canonical
post data and current companion screens while adding account-scoped query
cancellation/cache disposal and protected media to the new consumers. Owner
and viewed-profile Share actions now produce readable username links. The
actual TypeScript app check, all 45 tests, production build, and 45 PWA checks
pass; GitHub verification and Vercel preview checks pass. Marketing checks and
preview also pass. The integrated readable profile renders real QA data.

Projection review found that canonical posts exposed explicitly shared raw
notes and visible brew/equipment text outside the existing screening payload.
Migration `20260913200859` includes only those outward fields and criterion
names; private raw notes and Private posts remain excluded. Reflection edits
refresh revisions, pending canonical posts are withheld, and arbitrary extra
criterion keys are excluded from projection. Its hosted regression passes.
Discovery enrichment also now enforces cafe admission and screened public
visit evidence. These are forward fixes; production remains unchanged.


## Legacy projection acceptance — September 13

Read-path review followed the callable profile, post, recipe, reflection,
comment, discovery and activity projections into their admission helpers.
Migration `20260913202224` closes screening bypasses in legacy reflection and
comment RPCs, including reply counts. Migration `20260913202410` prevents a
visible visit from independently exposing a pending or private linked recipe
identity. The focused regression passes, including admitted content becoming
visible and edited comments returning to pending. Owner recovery remains.

The 61-contract combined run at migration 160 passed without failures. The
backend gate at the final source passes 11 checks with only optional pglast
skipped. No Swift change required another equivalent compile. Native runtime
acceptance is still blocked by the locked Mac. PostHog accepted the synthetic
erasure but has not yet returned a verified completion receipt.

A 15-minute heartbeat is active for this task so those external waits do not
require another request to continue. It remains quiet while the state is
unchanged, must not leave paid QA running while waiting, and may mark the goal
complete only after actual acceptance and production rollout. TestFlight is
still a separate explicit authorization gate.


The final legacy projection contract passes. The older reflection audience
contract now admits its edited synthetic revision before testing audience
visibility and passes separately. Paid QA was then deleted, and listing
branches verified only main. The exact local cleanup receipt records absence.
Production OpenAI/Maps credential digests match approved inputs; screening and
no-training activation flags remain false. These facts supersede earlier
statements that QA is active or that all provider credentials are local-only.


## Simulator packaging correction — September 13

The compile-only artifact had been built with code signing disabled. Reusing it
for runtime acceptance caused `AppAuthenticationOperationError.sessionMismatch`
after the Auth API returned a session. A read-only debugger Keychain probe
returned `-34018`; the artifact had no signature. This was a QA packaging
failure, not evidence that server authentication or profile projection failed.

A signed Debug Simulator build succeeded in 80 seconds using a restricted
QA xcconfig and an empty PostHog project token. Its signature and QA host were
verified before installation. The same sign-in then reached profile setup;
relaunch preserved the session, and profile completion reached Feed. A system
password-saving prompt was cleared by this planned relaunch without saving the
disposable credentials. The remaining native journey is unaccepted because the
Mac locked again. See the [runtime packaging rule](IOS_QA_EFFICIENCY_FRAMEWORK.md).


## Preservation and compatibility verification — September 14

Scope: product media behavior, Supabase read/screening contracts, privacy and
release operations (Tier 4). No production write or TestFlight action.

- Production read-only comparison: all 72 original-table fingerprints unchanged.
- Encrypted Storage backup: 331 objects, 439,219,602 bytes; every encrypted object
  decrypted and compared to its original download. Database restore not inferred.
- Current and protected synthetic media matrices: 30 audience/photo-byte checks
  each plus profile capability checks. Old raw public URLs retain their existing
  public exposure until the coordinated protected-bucket cutover.
- Exact old-server missing-API fallback resolves historical profile photos;
  protected denials and network failures never downgrade to public access.
- Atomic cutover: eight existing shared jobs remained honestly pending, with
  unchanged intended-viewer access in 30 cases. Private content stayed excluded.
  New SQL regression protects edit/rejection/appeal/withdrawal behavior and seals
  client access to one-time legacy eligibility. Full hosted suite: 64/64 passed.
- Preservation guard detected notification title/body/metadata sanitization in
  the earlier activity migration; all other 71 original tables matched.
  Production stays held; no claim of a completely unchanged 72-table cutover.
- Signed bridge Simulator displayed the legacy avatar and then all six Journal
  entries with protected photo rendering after the rehearsed cutover.
- Native Debug 0.5.3 (6), separate dev bundle, compiled for the owner's iPhone
  against the protected isolated QA host. Analytics token is empty. Installation
  and owner walkthrough are recorded at handoff, not inferred from compilation.

Local-only evidence is under ignored `.codex/`: production byte-backup manifest,
media-current/media-protected receipts, atomic-cutover-access receipt, production
preservation baseline and cutover baselines. Never publish keys, media or tokens.

Handoff confirmation: the signed dev build installed and launched on Joe's
connected iPhone. Device Hub visibly showed the retained QA owner session and
six synthetic checkerboard-photo Journal entries, including old-URL and durable
Private references. No real production posts were copied into QA. The owner
walkthrough screening schedule is active again after deterministic tests.
The extra current-contract branch was deleted and its absence confirmed; only
main and the owner-walkthrough QA branch remain. Keep the latter only until the
owner finishes this phone walkthrough, then delete it to stop QA compute charges.
Both documentation checks and backend static checks pass (11 passed, 1 optional
skip); the signed full Sprint Simulator build and device build also pass.


## Owner acceptance and production rollout request — September 14

The owner reports phone testing finished and requests production rollout.
The remaining owner-walkthrough QA branch was deleted; a fresh Supabase branch
inventory confirms only main. The six synthetic phone-test posts belonged to
that disposable environment and were not migrated to production. The encrypted
production photo backup and key remain preserved locally.

Fresh production read-only inventory: 127 migrations at 20260826143102, 80 posts,
331 Storage objects. The activity-copy transformation would affect 485 existing
notifications. No production schema, function, bucket or activation change has
been made at this checkpoint. TestFlight upload scope is being clarified because
existing distributed clients still require the compatibility update before
bucket protection can switch on. No App Store review submission is authorized.


## Real-account production dev handoff — September 14

The owner clarified that the next acceptance is the new dev build with their
actual production account/data, before TestFlight. A guarded staged rollout is
now applied: 164 migrations, ten updated functions, screening enabled after
fresh no-training/disclosure checks, and creator review access configured.
All 72 original tables matched inside the atomic production transaction, including
all 80 posts and existing notification text. All 331 Storage objects remain.
The added logical recovery drill restored 72 typed tables / 6,036 rows and matched
every fingerprint after decrypting the backup. No full physical restore is claimed.

Original bucket visibility is preserved for existing clients; final legacy-bucket
privatization still awaits compatible-client distribution. The isolated adjusted
rollout and 30 access checks passed before production application. The extra
rehearsal QA branch was deleted immediately afterward; only main remains.
Production scheduled deletion returned HTTP 200 with its dedicated secret.
PostHog erasure remains disabled and real Apple revocation remains unverified.

Signed dev 0.5.3 (6) built for production, installed and launched on the connected
iPhone; the real feed and its photos were visibly rendered. The Mac locked after
this observed checkpoint, so the owner's personal real-data walkthrough is still
pending. No request for TestFlight upload or App Store review is inferred.
Marketing PR 18 (f8795c6) and PWA PR 13 (44ea573) are merged, synchronized and live.
Native source remains on the Sprint branch for this owner acceptance phase.
