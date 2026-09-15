---
document_type: living
status: current
last_verified: 2026-09-14
---

## 2026-09-14 — Physical-device performance regression follow-up

Owner testing of `62991fa` reported text-input freezes, carousel loss after post
detail, page reset after scrolling, and image disappearance in the app switcher.
Two retrieved iPhone watchdog reports show synchronous UIKit image-pasteboard
probing while opening the keyboard, with negligible app CPU; this is distinct
from network latency. A Simulator stack capture reproduced the blocked system
pasteboard service. Plain-text UIKit configurations did not eliminate the wait
and were removed; standard SwiftUI fields remain. After disabling Simulator clipboard synchronization and restarting the Simulator,
the standard-input response-time test passed in 36.95 seconds for the full journey;
repeated Map focus-to-typing transitions took approximately 0.34 seconds. The
previous run stalled 33–58 seconds at one field. The physical-device freeze remains
unaccepted pending system-service recovery and retesting on that iPhone.

Feed social-state updates retain the complete photo collection, and Feed-owned
page selection survives recycled rows. Authorized images remain visible during
inactive app-switcher transitions until their existing expiry; background,
account changes, access revocation and expiry still hide protected pixels.
Profile header and post requests run concurrently and render before secondary
sections finish. No authorization lifetime has been extended.

The owner confirmed reminder preferences persist after tapping Save. A navigation
bar Save action and unsaved-change message clarify that explicit activation step.
This is a usability adjustment, not a backend persistence repair.

Verification: the Tier 3 full-static gate passed (12 passed, zero failed, optional
pglast skipped); focused photo-selection, photo-metadata and protected-image tests
passed. The bounded keyboard journey passed after Simulator clipboard isolation.
No crash-free physical acceptance or overall loading-speed benchmark is claimed.
No backend migration, TestFlight upload or marketing-version change is involved.

## 2026-09-14 — TestFlight feedback repair and reflection reminders

- Replaced the custom capture screen with Apple's standard still-photo camera,
  while retaining the existing photo-library path, draft ordering and media limits.
- Personal Map pins now average the owner's completed Mugshot scores per canonical
  cafe. Profile maps use individual mint cafe pins without regional aggregation.
- Publication recovery now reconciles each stable visit before resuming, continues
  past isolated failures, pauses on account-wide failures and exposes typed Retry
  and Review states without deleting unrecovered submissions.
- Normalized Instagram handles across setup, editing and link rendering; refreshed
  the owner projection after save. Cafe labels now route by canonical ID, Feed
  supports ordered photo paging, and published captions and structured journal
  headings use the approved emphasis and copy.
- Added explicit On this day and Weekly reflection preferences, account-bound
  destinations, a private scheduled queue, per-installation receipts and generic
  privacy-safe APNs payloads. Production migrations `20260914191634` and
  `20260914204700` plus the `deliver-reflections` worker are deployed. The
  follow-up migration bounds every APNs collapse identifier to the 47-byte
  `reflection:<occurrence UUID>` form. The rollback switch migrated off and
  was enabled only after health checks; zero preferences were delivery-active and
  the queue was empty at activation. The first post-redeploy five-minute dispatch
  returned HTTP 200 with zero enqueued, claimed, sent or failed work.
- Added focused Swift, Edge worker and isolated PGlite contracts plus a consolidated
  Simulator pass for Feed paging/routes, Map semantics, Profile pins, recovery,
  journal presentation and dock stability. Hardware camera, actual APNs receipt
  and replacement-TestFlight acceptance remain separate gates.

## 2026-09-14 — Reaction row polish

Move the full-post reaction breakdown into the action row before Save, retaining
its people-sheet action and adaptive layout. Yummy now uses a coffee mug symbol
in the picker, selected reaction, breakdown and people list. Presentation-only;
reaction values and backend behavior are unchanged. Verification: Tier 1 compile
and documentation check; device installation recorded in the delivery checklist.


## Regression repair candidate — 2026-09-14

Implemented on `codex/regression-repair-reactions`; production migration 171 and
`deliver-activity` are deployed. The dev build is installed and launched on Joe’s
iPhone; owner acceptance remains pending. This candidate retains visited tabs by account,
reuses fresh lists for 60 seconds, caches protected image pixels only in bounded
memory with renewed authorization, restores actor/action Activity and push copy,
adds comment-author navigation and reaction people, removes routine sharing-status
banners from post detail, and makes detail captions larger than journal notes.
No posts, photos, audiences, reaction rows or notification history are rewritten.
See [regression delivery checklist](REGRESSION_REPAIR_STATUS.md) for exact gates.


## 2026-09-14 — Keep restricted-content previews current

Retain the restriction and audit history while updating the review revision when
shared content changes. Private withdrawal retains the original owner for account
deletion cleanup. Focused SQL checks cover current preview and stale revision
invalidation. Production migration count is 170. Both public privacy pages are
updated; the dev build is installed and launched, awaiting owner interaction checks.

## 2026-09-14 — Local text filtering and report-driven moderation

- Replaced external provider execution with transactional blocked-term validation
  on existing shared-content write paths; photos use reports and human review.
- Retired worker scheduling and provider secrets; retained all human decisions,
  appeals, audit evidence, audiences, and existing content. Technical waits receive
  an explicit policy-transition reason. Production is at 169 migrations.
- Added long-press profile hiding and Undo for authored and tagged Mugshots; removed
  the tagged grid ellipsis. Normal taps still open the post.
- Updated native and web privacy/terms disclosures. Local SQL contracts, four
  review-media tests and Debug iPhone compilation passed. No distribution upload.


# Mugshot change log

## 2026-09-14 — Prepare TestFlight 0.5.3 (7)

- Advanced the app, share extension, and widget build number from 6 to 7 while
  keeping the approved 0.5.3 marketing version.
- The exact build-7 candidate compiled, installed, and launched on the booted
  iPhone 16 Pro Simulator and on Joe's connected iPhone. Exact `main` source
  `bead2de` then passed the Release archive gate, uploaded successfully,
  completed App Store Connect processing, and entered `Testing` for Mugshot Team
  and Alpha Friends, including 12 external testers. No App Store release was
  submitted.
- Per owner direction, TestFlight **What to Test** for this and future beta
  builds is `Welcome to Mugshot`.

## 2026-09-14 — Require an explicitly chosen public username

- Added a separate username-confirmation receipt to profile setup. Existing
  accounts that still match the exact collision-safe signup placeholder return
  to setup without any automatic rename; intentional handles remain complete.
- Generated handles no longer prefill the public username field. A setup-state
  failure now offers Retry or Sign out instead of bypassing setup. The server
  rejects an unchanged placeholder from older clients as well.
- Added an optional final setup step for up to three Favorite Spots using the
  existing cafe picker, publication boundary, and privacy copy.
- Production migrations 172–173 are configured. All 18 usernames remained
  unchanged; eight exact generated placeholders now require explicit choice.
- Full-static passed 12/0/1 (the one skip is optional `pglast`). The signed Debug
  build compiled, installed, and launched as `co.mugshot.app.dev` on Joe's
  connected iPhone. No TestFlight upload was performed.

## 2026-09-14 — Moderation and sharing repair (production deployed; recovery complete)

Repair album screening through individual image requests, bounded technical retries,
service diagnostics and distinct moderation queues. Add acknowledged Friends
publication, independent authored/tagged profile hides, pin persistence, broader
named cafe search, audience-labelled Publish, selected reaction icons and Mugsy
profile previews. Preservation and verification evidence: [repair status](REPAIR_SHARING_STATUS.md).


## 2026-09-14

- Staged Sprint 1 on production for the owner's real-account dev test. The
  guarded atomic rollout preserved all 72 original tables and all original
  bucket visibility; historical notification copy is preserved too.
- Restored the encrypted logical backup into isolated PostgreSQL and matched
  all 6,036 rows across 72 typed tables. Production photo inventory remains 331.
- Deployed server functions, enabled no-training-verified screening and founder
  review, published the companion web updates, and installed the production-
  connected dev build on iPhone. TestFlight and final legacy bucket privacy
  cutover remain held. All disposable QA branches are deleted.

- Owner completed physical dev-build testing and requested rollout. Deleted the
  remaining paid QA branch and verified only production remains. Final bucket-privacy
  activation still requires the compatible-reader distribution gate.

- Fixed old-backend profile-photo compatibility with a narrowly scoped missing-API
  fallback; protected-server denials continue to fail closed.
- Added one-time visibility preservation for existing shared revisions while
  screening remains pending. Edits/new content require screening; rejection
  removes preserved visibility. All 64 hosted SQL contracts pass.
- Verified bytes for all 331 production Storage objects in encrypted backup/isolated restore,
  unchanged production fingerprints, and current/protected/atomic-transition
  audience matrices. Cutover changes notification copy in one historical migration;
  the preservation guard detected it and production remains held.

## 2026-09-13

- Added a read-only content-preservation fingerprint guard and a client-first
  compatibility release sequence. Captured production's original-column
  baseline without changing production. The isolated media bridge compiles;
  hardware/distribution and byte/access-preservation gates remain.
- Restricted the reflection SQL fixture to reserved synthetic accounts, fixing
  a failure caused by selecting unrelated QA users. All 63 hosted contracts pass.

- Prepared the owner's full Sprint 1 phone walkthrough on isolated QA with
  preview sharing sites, screening/review and scheduled email cleanup.
  Cafe-list share links now honor the configured public domain, as profiles
  and posts already do. Signed device compile and QA configuration checks
  passed; owner acceptance is pending. No TestFlight upload occurred.

- Physically accepted Private photo posting on iPhone 16 Pro using signed QA
  development build 0.5.3 (6): save and relaunched photo display passed, owner
  bytes were readable, nonowner/anonymous reads were denied, and no Private
  visit screening job was created. Deleted paid QA and verified only main.
  Removed the Sprint 1 heartbeat at the owner's request. No TestFlight upload
  or production rollout occurred.

- The repaired native deletion flow passed on isolated QA: fresh verification,
  preserved progress UI, Auth/profile deletion, completed durable job, clear
  completion message and signed-out relaunch. Apple revocation remains the
  explicitly accepted unverified TestFlight boundary.

- Owner narrowed delivery to TestFlight preparation, explicitly excluding App
  Store review submission. Real Apple revocation remains unverified; the owner
  authorized proceeding without a disposable Apple Account. Recorded that
  limitation and the bounded remaining release checks.

- Fixed Saved Data API permissions on clean replays while preserving owner-only
  access. Two focused SQL contracts and native Save-to-Favorites passed.
- Repaired native deletion capability matching for dedicated worker secrets and
  preserved the deletion sheet during verification/failure. Added focused
  capability regression coverage; all 30 account-lifecycle tests and full-static
  checks pass. Revised deletion runtime acceptance is pending.
- Accepted native Love persistence, profile share-sheet presentation, explicit
  Friends-profile consent controls, and review/status screen loading. Closed
  the paid journey QA branch and verified only main remains.

- Fresh native QA passed all 62 database contracts, signed Simulator sign-in,
  session restoration and profile onboarding. Verified the newly created
  profile's screening, readable route and default Friends-profile exclusion.
  Deleted QA after the Mac locked again. Documented why unsigned compile-only
  artifacts cannot prove Keychain-dependent runtime behavior.

- Closed paid catalog QA and verified that only the main branch remains.
  Staged approved production OpenAI/Maps credentials with screening disabled;
  verified secret digests. Native/provider acceptance and rollout remain open.

- Legacy reflection and comment projections now enforce current screening
  admission, including reply counts. Recipe identity lookup respects the linked
  recipe visibility and screening state. Owner-only criterion extras remain
  available to the owner and are excluded from outward reflection projection.

- Canonical post screening now includes explicitly shared raw notes, visible
  brew/equipment fields and visible criterion names. Reflection edits refresh
  revisions; Private posts and private raw notes remain excluded. Canonical
  criteria omit arbitrary extra keys, and discovery enrichment respects cafe
  admission and screened public evidence. Focused hosted acceptance passes.

- Added a dedicated deletion-worker secret override after live scheduled QA
  exposed a legacy credential mismatch. User authorization is unchanged;
  production activation requires a verified scheduled HTTP response.

- Fixed initial deletion manifest counts for accounts with stored photos. The
  regression contract and live synthetic fresh-login/deletion/recovery flow
  pass, including actual Auth and Storage cleanup and stale-session denial.
  Production rollout remains pending.

- Live QA exposed and fixed missing service-role execution of the existing
  PostgREST session hook. Authenticated cafe verification and synthetic
  screening/reviewer flows now pass through deployed endpoints. User-session
  enforcement is unchanged; production is not yet updated.
- Restored the missing profile website column to reproducible migration history
  and included website text in shared-profile screening. A non-empty hosted
  profile contract passes; actual readable web profiles render on QA.


- Added authenticated server cafe verification for Apple/Google selections,
  service-only admission and rate limits, contextual catalog reads, and guarded
  cafe references. Manual saves remain supported without private-content
  screening. All 156 migrations replayed and all 58 hosted contracts passed;
  four provider/handler tests, native app/test compilation and PWA build pass.
  Production deployment remains pending.
- Updated the isolated lifecycle and Home test harnesses to inspect the current
  superseding security definitions, and fixed the discovery cursor contract to
  use the actual last visible row when fewer than five cafes are available.


- Completed approved Apple Maps identifier and Maps-only key provisioning.
  Stored the private key outside Git with owner-only permissions. Local ES256
  verification and Apple's server-scoped token exchange passed (HTTP 200).
  Cafe verification implementation and production deployment remain pending;
  no user content was sent during the check.

- Replayed all 155 migrations and passed all 57 contracts in one isolated hosted
  run, including analytics recovery. Deleted the paid branch, verified absence,
  and removed its local credential. Production remains unchanged. Reverified
  all three OpenAI model-improvement sharing controls remain Disabled.

- Companion PWA cafe-search functions now omit raw queries, coordinates and
  arbitrary provider/network errors from logs and error responses. Two focused
  handler tests and Deno checks pass. Deployment is pending. Prepared Apple Maps
  identifier/key setup for catalog verification; new access awaits approval.

- Added audited service-only recovery for exhausted analytics cleanup. Stale
  snapshots, reused operation IDs, active work, and verified rows cannot reset
  the queue; original targets and provider evidence remain intact. Focused
  hermetic checks pass. Hosted rehearsal and production deployment are pending.

- Verified PostHog recording is disabled and an authenticated recording query
  from before project creation returns no results, without duration or test-user
  exclusions. This closes the dated recording-inventory gate; provider deletion
  and runtime acceptance remain separate. No recordings were deleted.

- Fixed cafe-list ownership transfers that rolled back when their new screening
  revision hid the response from the former owner. A content-free confirmation
  preserves existing client decoding and exact-epoch retries without approving
  the content. The focused hosted contract passes; production is unchanged.

- Fixed screening's suppression of the existing content-free Private tag notice.
  A completed Private sip can retain its canonical tag notice without entering
  screening or granting sip access. Shared pending content, blocked actors and
  removed tags stay withheld. Focused hermetic and hosted activity checks pass;
  the migration is not production deployed.

- Aligned hosted QA setup with explicit consent, admitted base shared fixtures,
  and inactive scheduler isolation. Later test mutations remain subject to
  screening. Updated legacy media assertions to require private buckets.
  All 56 hosted contracts now have passing evidence across the 55-pass full
  run and the final focused security-assertion correction. The paid QA branch
  was deleted and absence verified. Production behavior is unchanged.

- Replayed all 152 migrations in the second data-less hosted QA branch. The
  refreshed suite reports 32 passes and 24 failures across 56 contracts,
  including a pass for the corrected owner-edit rollback check. Deleted the
  branch and verified its absence after evidence capture; remaining failures
  are still release gates.

- Repaired 84 incorrect production migration statement records after guarded
  forward/rollback rehearsal in disposable QA. One of the initially counted
  85 records was legitimate and remains untouched. Schema and application row
  fingerprints are unchanged; production migration head is unchanged. Recorded
  the exact old/new hash ledger. Fresh automatic replay passed the repaired
  history and reached 113 migrations before scheduler configuration was needed;
  the check branch was deleted. Sprint 1 features remain undeployed.
- Corrected the owner-edit rollback test to inspect canonical tag storage.
  Screened public tag projections cannot establish whether a pending profile's
  stored tag was rolled back; the mutation and cross-owner checks remain under
  the authenticated role.

- Completed approved Apple and PostHog credential provisioning into restricted,
  Git-ignored local files. Apple client-secret signature verification and a
  synthetic PostHog lookup pass; neither credential is deployed. Recorded the
  Apple renewal deadline. Disabled PostHog project session recording and
  verified the saved setting; complete retained-recording evidence remains open.

- Recovered native test results hidden by Xcode diagnostic finalization: both
  attempts ran 446 tests, with six assertion failures in one stale Home
  Workbench expectation. Updated that existing test for the August criterion
  catalog; the focused suite passes 15/15 with a successful xcresult. Corrected
  the prior no-tests-ran interpretation in the sprint tracker.

- Ran the first approved hosted Sprint 1 QA branch and deleted it after
  evidence capture; branch absence is verified. Source replay passed with
  isolated scheduler prerequisites. The full remote suite reported 30 passes
  and 25 failures; production history also contains 85 damaged statement
  records requiring repair. Neither finding is waived.
- Added explicit least-privilege cafe catalog grants for fresh Supabase
  environments. The new grant contract and screening queue contract pass on
  hosted QA. Production remains unchanged; full-suite triage is still open.

- Corrected the compile verification scheme to `MugshotTests` and added a
  generated-manifest check for both test targets. The previous auto-generated
  scheme could pass with no tests configured. Both test bundles now compile;
  earlier app-and-test claims are qualified in the Sprint 1 tracker. The
  isolated unit execution attempt stalled without test results while the Mac
  was locked and was interrupted; runtime acceptance remains open.

- Prepared protected recipient media: legacy own-project profile/visit URLs
  now use one-minute signatures in shared-profile/shared-mugshot responses,
  with no permanent-URL fallback when signing is unavailable. Native profile
  and visit media resolution is implemented and compile-verified; the protected
  bucket migration is implemented and locally RLS-tested, not deployed.
- Added exact author/visit/bucket checks before privileged shared-link media
  signing. Five focused Edge tests pass. Migration `20260913061308` closes
  public user-media buckets and gates reads on current screened references;
  actual hermetic RLS tests pass for anonymous, friend, blocked, Private, and
  owner-recovery paths. Remaining web consumers and isolated remote QA are
  still deployment gates.

- Verified repaired marketing CI and preview deployment. Read-only Storage
  inventory confirmed public profile/legacy photo buckets; protected delivery
  and cache acceptance remain required before screening activation.

- Published the reviewed Sprint 1 implementation and website disclosures to
  their existing draft PRs. Repaired the marketing dependency audit failure;
  local website verification and npm audit pass. Production release remains
  gated on remote QA, configuration and runtime acceptance.

- Preserved owner-level moderation actions after reported content deletion by
  resolving the owner from server-captured report evidence. Deleted content
  cannot receive a hide action, and self-review remains prohibited.

- Aligned raw recipe recipient reads with projection authorization: suspended,
  blocked or unavailable owners/senders no longer retain a raw-table access
  path. Private recipes remain outside provider screening.

- Minimized reviewer queue listings to status/reference metadata; raw content,
  evidence and history now load only through the protected detail path. Owned
  screening review/reconsideration records cascade on account deletion instead
  of retaining free-text reasons after the owner is removed.

- Fenced screening status, queue and preview loads with request identities.
  Old responses cannot replace newer results or strand a background-cleared
  screen; refreshed previews reload their images and restart expiration.

- Bound expressive reaction writes to the initiating account with a V2 RPC.
  Native service and Feed/detail response handling reject account switches;
  legacy Like-only fallback remains available when the RPC is absent. Focused
  PostgreSQL checks reject a mismatched actor and preserve Love behavior.

- Reconciled the Xcode feedback cache against the ledger: 45 packages, with
  one newly recorded build-6 copy suggestion. Preserved the original 44-report
  acceptance history and left the new suggestion Open, outside approved Sprint 1.

- Prepared the Apple provider-encryption key in ignored, mode-0600 local
  configuration without exposing its value. Server provisioning is pending;
  Apple Developer requires sign-in and native access reports a locked Mac.

- Added the new screening queue contract to the actual remote SQL suite.
  It checks sealed worker grants, lease/revision changes, stale approval
  rejection and withdrawal under a disposable fixture guard, then rolls back.
  The same SQL passes hermetic PostgreSQL; remote execution remains pending.

- Prepared retirement of the obsolete `notify-friends-on-new-visit` endpoint.
  Its replacement returns HTTP 410 without reading payloads, looking up devices
  or sending pushes. Read-only production inspection found legacy version 8
  still active; deploying the replacement remains a required release action.

- Removed unrestricted client updates to shared cafe catalog records. Native
  and PWA resolve/insert paths remain available, and trusted server corrections
  remain possible. A PostgreSQL role test verifies the permission boundary;
  no existing cafe rows are rewritten by this migration.

- Closed a shared-text screening gap: displayed drink type/subtype now join the
  existing caption/custom-name allowlist. Edits invalidate prior approval;
  Private notes remain excluded. The forward migration recomputes shared
  payloads without making provider requests.

- Fixed a screening-gate regression for explicitly shared Private recipes.
  Existing recipient access is preserved without sending Private recipe content
  to the provider; friendship alone and anonymous access remain insufficient,
  and dismissal/blocks revoke access. Focused PostgreSQL checks pass.

- Added an inactive-by-default screening scheduler definition with a dedicated
  Vault credential, strict worker URL validation, an idempotent ten-second
  schedule and empty-queue skip. Explicit operational activation remains gated
  by disclosures, no-training verification, isolated QA and server configuration.

- Added database-enforced screening dispatch limits: 60 claims per minute,
  ten per owner, six concurrent leases globally and two per owner. Throttled
  jobs stay pending without consuming attempts. Limits are serialized across
  worker calls, and owner budget records cascade with account deletion.

- Added capability-verified Apple cleanup status to normal and recovered
  deletion responses. Native completion copy distinguishes pending, revoked
  and unconfirmed Apple access from completed Mugshot data deletion. Status
  lookup is service-only and bound to the exact deletion request/job pair.

- Connected native Apple deletion authorization codes to verified server-side
  exchange and an encrypted, account-bound provider cleanup queue. Scheduled
  cleanup waits for confirmed Mugshot identity deletion, retries with leases,
  and erases credentials on success or bounded expiry. Provider failures do
  not block Mugshot data deletion. Synthetic checks cover encryption, staging,
  retry and failure paths; Apple configuration and live acceptance remain open.

- Added the Apple deletion-token exchange/revocation boundary with signed
  identity checks and sanitized errors. Five synthetic tests pass; durable
  storage and deletion-flow integration were pending at that checkpoint and are
  implemented in the later integration entry above. Removed raw error
  objects and job IDs from deletion endpoint logs.

- Made notification events durable while screening is pending, with approval-
  gated delivery, edit/reclaim fencing and 24-hour expiry for held pushes.
  Generated notification copy and lifecycle metadata no longer retain user-
  written names/list titles. Focused synthetic checks pass; production remains
  unchanged. Private-list invitation access is preserved without screening
  Private content; focused tests cover invitation, acceptance, blocks and removal.

- Added matching native, marketing and PWA disclosures for shared-content
  screening, Private exclusions, no model training opt-in, review and appeals.
  Privacy summaries no longer promise the unavailable Passport flow. Disclosure
  publication and processing activation remain coordinated release gates.

- Added report navigation to the current shared-content preview and four
  synthetic reviewer endpoint tests. Authentication, operator revocation,
  privacy withdrawal, bounded requests and media admission fail closed.
  Private/deleted revisions have no preview; live acceptance remains pending.

- Connected legacy and new cafe-list comment reports to durable review,
  enforcement and appeals. Original receipts/evidence survive retries; focused
  synthetic checks pass hide, reversal, ownership and deletion retention.
- Corrected post-save receipts to confirm journal storage without claiming the
  content is already live. Updated native acceptance assertions.

## 2026-09-12

- Added founder queues and native decisions for existing reports and enforcement
  appeals. Expected-account/status checks fence stale decisions; existing audit
  and ownership triggers remain in use. Focused synthetic PostgreSQL checks
  pass enforcement and reversal. List-comment report integration and runtime/
  production acceptance remain pending.

- Connected shared-content queue revisions, bounded worker leases and retries,
  primary/collection publication checks, protected review/status/reconsideration
  RPCs and reviewer media preview. Edits, Storage replacements and privacy
  withdrawal invalidate stale results. Nested recipe fields and public-list
  copies now filter data that must not be exposed. Synthetic queue/projection
  contracts pass. Added native status/reconsideration and operator review screens
  with expiring media and account-bound decisions; generic Debug compile passes.
  Complete surface audit, report enforcement, scheduling and runtime/production
  acceptance remain pending. No production configuration changed.

- Added the standalone moderation provider boundary with Private exclusion,
  metadata stripping, explicit input fields and fail-closed error handling.
  Seven synthetic Deno tests pass. Queue and publication integration progressed in the entry above; no user content has been sent and no worker is deployed.

- Removed the unavailable Journal Passport shortcut and upgrade holding screen,
  along with onboarding and marketing promises. Existing working profile
  summaries remain. The legacy marketing landing now explains unavailability.

- Implemented readable `/profile/username` links with permanent owner aliases
  and deleted-handle tombstones. Existing revoked tokens stay unavailable.
  Anonymous PWA sip/profile recipients and marketing rewrites are implemented
  in companion repositories; public API data is no longer service-worker cached.
  Local handle, Edge type and synthetic browser checks pass; production and
  installed-app acceptance remain pending. Share artwork now stops if the
  anonymous projection cannot load, instead of falling back to owner data.

- Created the dedicated Mugshot OpenAI project; verified all three optional
  training-related data-sharing controls disabled. A synthetic-only moderation
  request returned HTTP 200. No user content was transmitted.
- Implemented versioned Friends-on-profile consent and author consent for
  tagged Friends posts. Legacy clients may withdraw but cannot grant consent.
  The isolated PostgreSQL consent test and iOS Debug compile pass;
  production deployment and runtime acceptance remain pending. See [Sprint 1 delivery](SPRINT_1_TRACKER.md).

## 2026-08-26

- Distributed the completed remediation sprint as TestFlight 0.5.3 (6) from
  exact `main` commit `b498d92`. The candidate passed Simulator and Release
  archive gates; the owner reported completed device QA and explicitly waived
  a redundant connected-iPhone rerun after the final sync. Xcode uploaded the
  archive at 9:37 PM EDT, App Store Connect completed processing, and the build
  is `Testing` for Mugshot Team and Alpha Friends with the published note
  `Welcome to Mugshot!`. Replacement-build product acceptance and feedback
  resolution remain separate.
- Implemented the latest owner-QA Feed and Profile-share follow-up on
  `codex/testflight-feedback-remediation`. The Feed scope rail now rests
  directly beneath the compact subtitle instead of reserving a second
  16-point gutter, and the space from the rail to the first Mugshot card now
  matches the same compact eight-point rhythm above it. The zero-height refresh
  reader moved behind the scope reservation so it no longer contributes hidden
  stack spacing; Your Mix, Friends, and Everyone retain identical control
  geometry, refresh isolation, the 60-point stationary threshold, and the
  continuous slide beneath the header. Profile-share content is explicitly
  sorted newest-first and now retains durable private-Storage photo references
  long enough for the authenticated media service to resolve them before
  rendering. This makes the snapshot grid match the current public Profile
  instead of dropping recent Friends-profile media and falling through to old
  public HTTPS photos. Private Mugshots remain excluded by the profile
  publication contract. The app Debug build/install/launch, 30 focused profile
  and Feed-domain tests after one floating-point assertion correction, the
  corrected single Feed test, the final equal-gap Feed test, live Feed capture,
  live current-profile share render, and same-input comparison boards pass on
  the standard Simulator. A
  read-only production query confirmed that the server projection was already
  newest-first and that the omitted recent rows used durable Storage
  references; no production data or policy was mutated. Full-static passed its
  11 non-Xcode stages, skipped optional `pglast`, and reproduced the known
  Xcode 27 generic XCTest-framework Info.plist packaging failure; the normal
  XcodeBuildMCP app build and focused tests passed. This latest source has not
  been promoted to a connected iPhone or TestFlight.
- Implemented public Profile sharing on
  `codex/testflight-feedback-remediation`. The owner Profile menu now opens a
  dedicated Mugshot share hub instead of handing iOS a bare URL. It renders
  exact 1080×1920 Story and 1080×1350 Post snapshots from the recipient-visible
  profile projection, preserving the 112-point banner, foam-white statistics
  dock, public identity details, compact Favorite Spots, four-tab rail, and
  portrait Mugshot grid. The activity payload includes the selected artwork,
  concise `Add me on Mugshot — @handle` copy, and the canonical active profile
  URL with a branded link preview. Private Mugshots and private journal data
  never enter the share content model. Eight focused Editorial Atlas tests, a
  normal Simulator build/install/launch, full Story export inspection, and the
  owner native-share handoff pass. The export was corrected during acceptance
  so oversized profile content anchors at the hero instead of cropping away
  the banner and statistics dock. The exact source then built with the named
  development profile, installed, and launched successfully as
  `co.mugshot.app.dev` on Joe's connected iPhone. This is physical
  build/install/launch evidence only; hands-on Profile share acceptance remains
  with the owner and TestFlight remains untouched.
- Implemented the next Simulator-QA polish batch on
  `codex/testflight-feedback-remediation`. Profile exploration maps keep the
  existing Mugshot MapKit surface, pins, clustering, cafe count, and location
  control but no longer render the redundant owner-named ratings legend below
  the map. Feed gives every scope subtitle the same compact layout footprint,
  so choosing Your Mix no longer shifts the scope control; its two-line
  matching sentence uses the existing space with tighter line spacing.
  Structured comment mentions now route by the mentioned account record rather
  than reusing the post-tag lookup, so a mentioned-only person opens the
  existing profile and friendship flow. The fast no-Simulator gate, app Debug
  compile, and all 16 focused Sip Detail presentation tests pass. A normal
  Simulator build/install/launch then verified that Your Mix and Friends keep
  the scope control at the same vertical position with the full subtitle
  visible, Amanda's live profile map has no ratings box beneath it, and the
  live structured Amanda mention retains its mint/bold treatment. End-to-end
  mention-tap feel remains in the owner's active QA rather than being promoted
  as physical or TestFlight acceptance.
- Implemented the second Editorial Atlas physical-QA follow-up on
  `codex/testflight-feedback-remediation`. Friend profiles no longer render or
  request the low-value Taste overlap card, and sparse identity metadata,
  favorite drink, Instagram, and website details now share a compact wrapping
  rail instead of leaving a tall single-column gap. The Favorite Spot reason
  picker replaces its undiscoverable horizontal category scroller with a fully
  visible two-column grid for Drink, Vibe, Food, Occasion, Service, and Make it
  yours; accessibility sizes use one column, and Make it yours exposes the
  existing validated 30-character custom descriptor field immediately. The
  profile shell is now eager around its still-lazy media grids, and cafe card
  title geometry is stable, removing the nested-lazy content-height feedback
  loop that made the Cafes tab jitter instead of scrolling. Five focused
  profile tests, the normal Debug build/launch, the live Amanda profile, custom
  descriptor entry, and repeated scrolling through all 11 visible cafe cards
  passed on the standard iOS 27 Simulator. The full-static non-Xcode stages
  passed; its generic no-Simulator test packaging remains blocked by the known
  Xcode 27 XCTest-framework Info.plist harness issue, while the equivalent
  XcodeBuildMCP app build and focused tests pass. This repaired source has not
  yet been promoted back to a connected iPhone or TestFlight.
- Implemented the first Editorial Atlas physical-QA follow-up on
  `codex/testflight-feedback-remediation`. The shared profile returns to the
  112-point banner token while retaining its foam-white statistics dock,
  replaces image-heavy Favorite Spots with a compact descriptor/cafe text
  rail, and changes Add Favorite Spot to choose a Drink, Vibe, Food, Occasion,
  Service, or custom reason before choosing the cafe. Profile visibility is
  now explicit and owner-controlled: Friends Mugshots remain in Friends Feed
  but also appear on the public profile by default; an account setting can
  reduce the profile back to Everyone-only, and Private Mugshots remain absent
  from authored, cafe, map, and tagged profile projections in every state.
  Composer and Publish copy disclose that distinction. The sealed
  caller-bound Favorite Spots and profile-visibility contracts pass the focused
  PGlite ownership/privacy suite, including default/on/off behavior, anonymous
  profile links, canonical cafe stitching, tagged hides, and direct-table
  denial. The app build/launch, five focused Swift tests, rendered owner profile,
  and reason-first Add Favorite Spot journey pass on the standard iOS 27
  Simulator. Migration `20260826143102_profile_editorial_atlas.sql` is live in
  the connected Mugshot Supabase project; all expected tables/RPCs resolve, no
  advisor error was introduced, and existing cafe/sip/media rows were not
  rewritten. Physical acceptance of this follow-up and TestFlight acceptance
  remain separate owner-promoted gates.

## 2026-08-25

- Implemented the approved Editorial Atlas shared profile redesign on
  `codex/testflight-feedback-remediation`. Owner and friend profiles now share a
  photographic hero, foam-white tappable Friends/Sips/Cafes dock, streamlined
  identity and actions, up to three visual Favorite Spots, and four public tabs
  in the approved Mugshots, cafes, map, and tagged order. The map tab embeds the
  existing Mugshot MapKit surface, numeric pins, clustering, rating legend, and
  location control without dotted routes or a replacement map style. Mugshot
  and tagged grids retain 3:4 portrait crops; cafes use two-column visual cards.
  Owners can choose Favorite Spots from Mugshot/history or Apple Maps, assign a
  categorized or custom descriptor, reorder them, hide a tagged Mugshot from
  the profile, or remove their tag. The additive Supabase contract seals direct
  table access, exposes caller-bound mutations, groups cafes by canonical
  identity, restricts all public tabs/stats to Everyone content, keeps old v3
  profile/highlight clients compatible, and adds the new owner data to export.
  Profile Highlight is absent from the new UI. The profile-specific hermetic
  database contract, four focused Swift tests, full-static 12/0/1, all four
  deterministic Simulator tabs, and the final same-viewport visual comparison
  pass. The deterministic owner fixture also verifies profile actions, the
  Favorite Spots editor, tagged-grid controls, and the Hide from profile /
  Remove my tag sheet. A signed `iphoneos` Debug package builds and verifies locally.
  Per owner direction, physical-device testing is intentionally deferred until
  explicit promotion and is not a completion gate for this Simulator-scoped
  sprint. No migration was deployed.
- Implemented the second consolidated Simulator-QA follow-up on
  `codex/testflight-feedback-remediation`. The Feed scope pills now stay fixed
  during pull-to-refresh and the first 60 points of upward scrolling, then move
  continuously beneath the clipped Feed header over their measured height;
  this removes the abrupt lazy-stack disappearance while preserving Feed
  reselect-to-top. Log a Sip now offers 12–18 preparation-specific criteria
  across every parsed drink preparation and Home brew method, keeps the
  suggestion rail stationary above selected criteria, and preserves the
  existing score/importance contract. Central Add always creates a fresh blank
  draft, every composer step has a native X plus Back when applicable, and an
  explicit Resume draft action opens the only saved draft directly or presents
  a picker when several exist; Journal draft routes remain unchanged. Cafe
  detail now recognizes durable `mugshot-storage://` poster references as
  remote Storage media instead of sending them to the local cache. A read-only
  production aggregate confirmed Sightsee has two complete visits with poster
  references and ten photo rows; no records, Storage objects, or policies were
  mutated. Cafe identity now read-stitches same-name/same-address provider
  records across reversed address formats, optional ZIP codes, and guarded
  same-location fallbacks. Map pins, personal library projection, Cafe Details,
  and Map preview combine visits and poster media across every stitched remote
  cafe ID without rewriting production rows. A read-only production check
  confirmed the three Tiny Nook records at 267 Rutledge contain three complete
  sips and five photo rows together. All 28 earlier focused criteria,
  Feed-motion, draft-domain, and cafe-media tests passed; four additional Feed
  timing and cafe-stitch tests plus a normal Simulator build/install/launch
  passed. The preceding source also built with development signing, installed,
  and launched as `co.mugshot.app.dev` on Joe's connected iPhone. The latest
  Feed-motion source passed its focused test and fast static gate, then built
  installed, and launched on that iPhone after it was unlocked. This is
  physical app-launch evidence only; manual motion acceptance remains.
- Implemented the consolidated Simulator-QA follow-up on
  `codex/testflight-feedback-remediation`. Reselecting Feed now scrolls to the
  top; the Your Mix/Friends/Everyone control participates in feed scrolling so
  the fixed Feed header and actions remain compact after it leaves view.
  Journal hides its redundant toolbar profile action behind a disabled feature
  flag and routes Taste Passport to a Mugsy upgrade holding screen. Composer
  navigation now uses the single native toolbar control surface, drink-context
  suggestions exclude unrelated espresso or matcha criteria, and criterion
  importance persists by account and criterion scope without carrying visit
  scores forward. Publish preserves its accepted preview, caption position,
  and share flows while restoring the compact inline Audience, Raw note, and
  Tag people controls; private-note editing remains in the reflection flow.
  Cafe detail now renders every viewer-visible remote Mugshot returned by the
  existing RLS-scoped query before falling back to local history, and missing
  local media says `Photo unavailable` instead of `Legacy sip`. Seventeen
  focused composer/domain tests, the Feed reselect and Taste Passport UI
  journeys, full-static 12/0/1, and a normal Simulator build/install/launch
  passed. Manual Publish, criterion, close-control, and cafe-detail retesting
  remains part of the active Simulator walkthrough.

## 2026-08-24

- Implemented the revised 44-report TestFlight remediation candidate on
  `codex/testflight-feedback-remediation`: identifier-based tabs preserve the
  Map, Feed, Add, Saved, Journal order while signed-in launch defaults to Feed;
  Journal and Feed are more compact; Publish supports direct summary edits and
  recoverable photo deletion; comments retain one-level reply structure; and
  post likes now support Like, Love, Laugh, and Yummy through an additive,
  caller-bound Supabase contract. Share-card output now includes a safe
  city/state and `@handle` with corrected export bounds, while the approved
  share hub/sheet and Publish-preview geometry remain unchanged. Added a
  review-only code-native Mugsy vector PDF exporter, cafe address-order
  reconciliation, focused Swift tests, a hermetic post-reaction contract, and
  the privacy-safe 44-report ledger. Caption entry now occurs only on Publish,
  and closing a successful Add flow returns to the last non-Add tab with Feed
  fallback while an explicit Passport action still routes to Journal. Local
  acceptance passed 425 unit tests, eight focused UI journeys, visual review of
  all 43 screenshots plus the text-only report, and full-static 12/0/1. A
  signed Debug build and install passed on Joe's iPhone; runtime launch was
  denied because the phone was locked. Physical runtime, production reaction
  configuration, replacement TestFlight acceptance, and report resolution
  remain separate pending gates.
- Implemented TestFlight-feedback polish for Feed and Map on
  `codex/feed-map-launch-polish`. Feed now keeps the Your Mix subtitle to two
  lines and reduces the scope-control-to-first-post gap from 18 to 8 points.
  Map camera reconciliation now preserves a current-location request that
  arrives while its broad launch fallback is still settling, so authorized
  launches center without requiring the location button. Added focused camera
  arbitration coverage. Full-static passed 12/0/1; the focused tests compiled
  in the Simulator-hosted app test bundle and remain queued with signed-device
  launch acceptance for the next consolidated runtime pass. Updated Current
  product status and Current sprint. Published as PR #57.
- Accepted the first real signed-device sandbox background delivery from a
  normal second-account like: the minute worker completed one send on its first
  attempt, Activity showed the unread item, the authoritative unread count
  reached zero after opening it, and its in-app destination routed correctly.
  The Feed bell stayed at `1` until activation, so
  `codex/activity-unread-badge-sync` now makes Feed observe the shared Activity
  store directly. Full-static passed 12/0/1, the signed build/install/launch
  passed, and a second first-attempt sandbox send physically proved the
  authoritative count, Activity marker, and Feed bell all clear immediately
  without relaunch. Updated Current product status, Current sprint, Feature
  status matrix, Notification system, Product roadmap, and TestFlight handoff.
- Physically launched the signed sandbox Debug app and accepted notification
  permission through its just-in-time Activity education. The settings surface
  reported the iPhone registered, and a privacy-safe aggregate backend check
  confirmed one active sandbox installation with badge sync. Saving master
  push off removed the sealed registration; restoring it recreated the row
  with every category true. A terminated cold launch restored the account and
  refreshed registration. No token, account ID, content, deep link, or synthetic
  production Activity was used; real cross-account APNs delivery remains.
  Updated Current product status, Current sprint, Feature status matrix,
  Notification system, Product roadmap, and TestFlight handoff.
- Installed the active `Mugshot Debug Push Development` profile and added
  device-only manual Debug signing so physical builds select it without
  changing Simulator or extension signing. The connected-iPhone build passed
  with the expected development identity, named profile,
  `co.mugshot.app.dev`, `MUGSHOT_PUSH_SANDBOX`, and
  `aps-environment=development`; the app installed successfully. The first
  remote launch was denied because the phone was locked, so runtime notification
  acceptance remains pending. Updated Current product status, Current sprint,
  Feature status matrix, Notification system, Repository map, Product roadmap,
  and TestFlight handoff.
- Generated `Mugshot Debug Push Development` for `co.mugshot.app.dev` with the
  existing development certificate and registered iPhone. Apple reports the
  profile active through 2027-08-24 with App Groups, In-App Purchase, and Push
  Notifications. Browser file handoff did not persist the download, and
  Xcode's command-line automatic retrieval failed because no Apple account is
  configured locally; download, installation, and physical acceptance remain
  pending. Updated Current product status, Current sprint, Feature status
  matrix, Notification system, Product roadmap, and TestFlight handoff.
- Implemented the source-build-5 iOS notification lifecycle: typed sandbox and
  production APNs environments, development/production entitlements,
  capability-gated v3 badge registration, shared authorization with nearby
  reminders, account-bound foreground/tap refresh, authoritative icon badges,
  injectable system/backend interfaces, truthful availability copy, and
  privacy-safe lifecycle analytics. Added focused coordinator, badge, signal,
  environment, and analytics tests. Full-static passed 12/0/1 with only the
  optional `pglast` parser skipped; 34 focused Simulator-hosted tests and a
  Simulator build/install/launch with Activity-surface inspection passed. A
  connected-iPhone build verified the Debug bundle/entitlement/environment
  selection and then failed closed because the installed development profile
  lacked `aps-environment`. Push Notifications was then enabled for the Debug
  App ID without creating redundant SSL certificates; generation and
  installation of the replacement development profile remain pending, so
  physical delivery is not accepted.
  Updated Notification system, Current sprint, Current product status, Feature
  status matrix, Real data flow status, Repository map, Product roadmap,
  PostHog analytics plan, and TestFlight handoff. Published and merged the
  implementation as PR #50 (`0d1cf21`).
- Added backward-compatible v3 APNs device registration and final delivery
  revalidation, including opt-in authoritative unread badges while retaining
  both v2 RPCs and the existing route envelope. Updated Notification system,
  Current sprint, Current product status, Feature status matrix, Real data flow
  status, Repository map, Product roadmap, and Supabase release workflow.
- Added the fail-closed canonical one-minute Activity delivery schedule using
  Vault, `pg_cron`, and `pg_net`; source and disposable QA are verified and the
  live deployment workflow remains in progress.
- Codified `deliver-activity` as a service-key-authenticated Edge Function with
  platform JWT verification disabled in `supabase/config.toml`; the worker
  still performs its own constant-time `apikey` check and supports a dedicated
  cron credential separate from its internal admin key.
- Disposable QA exposed and closed an inherited anonymous `visits` write
  grant. The share-link contract now enforces the current viewer rule: Everyone
  links are anonymous-readable, while Friends links require an eligible
  signed-in viewer.
- Replayed all 125 migrations through head `20260824165630` on a data-less
  Supabase branch, passed all 54 remote SQL contracts, and proved the single
  minute worker reaches its authenticated fail-closed state without APNs
  secrets. Updated Notification system, Current sprint, Current product status,
  Feature status matrix, Real data flow status, Product roadmap, and Supabase
  release workflow.
- Added a one-time production schedule cutover guard after live inventory found
  69 stale pending delivery attempts and no Activity cron job. Attempts older
  than 15 minutes become cancelled without deleting or suppressing in-app
  Activity; fresh and processing work is preserved. Full-static passed 13/0/0
  across 184 SQL files, and the disposable branch reached migration 126 with
  all 54 remote contracts green.
- Released migrations `20260824162710` through `20260824171405` and worker
  version 6 to production. Local/live history aligned at 126 migrations; the
  v3 capability and grants are live; protected users, visits, Activity events,
  preferences, Home data, and Storage fingerprints were unchanged. Exactly one
  Vault-backed minute job returned protocol-v3 HTTP 200 with zero claims after
  the 69 stale attempts were expired. The disposable QA branch was deleted.
- Verified the notification backend branch with the backend gate (12 passed,
  zero failed) and full-static gate (13 passed, zero failed), including local
  parsing of all 183 SQL files.
- Implemented and locally verified the Home Workbench, recipe memory, structured
  brew projection, and associated social/product checkpoint upgrades on
  `codex/home-workbench-sprint`.
- Established the living documentation index, current notification runbook,
  active sprint ledger, documentation policy, and freshness verification.
- Reconciled current product, architecture, data-flow, roadmap, analytics,
  Supabase, verification, and TestFlight documents with source build 0.5.3 (5).
- Published and merged the documentation/Home Workbench baseline as PR #46;
  synchronized local and remote `main` at merge `f91e2a4`.

## 2026-08-09

- Configured the production APNs key, sandbox and production topics, and durable
  Activity delivery schedule. Apple accepted both provider/topic probes; real
  device delivery and tapped cold launch remained pending.

## Earlier history

Use dated audits, checkpoints, deployment gates, and Git history for earlier
evidence. Those records remain historical rather than being rewritten here.

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

### Repair follow-up verification

Added an isolated Auth session-identity regression and corrected duplicate Xcode
log counting. The signed app reaches Feed using a local synthetic Auth backend.
Live MapKit reproduced suggestion-selection cancellation during keyboard/viewport
changes; the follow-up protects the selected lookup from viewport refreshes.

The repaired Burlington suggestion opened its cafe card and Log a Sip in live
MapKit acceptance. Pins survived reflection navigation and relaunch/resume;
keyboard Done left the draft unpublished. The final Debug candidate compiles and
launches. These runtime checks used synthetic local app data; live hosted, physical
device and production rollout gates remain pending.

Recorded the remaining repair acceptance gates and the complete shared-media
function deployment set. This documentation checkpoint makes no additional
runtime or production acceptance claim.

Follow-up hosted runtime acceptance passed email sign-in, profile setup, session
restoration, all four reaction saves, and visible rollback on a forced save
failure. The disposable hosted branch was deleted and its removal verified.
Remaining interactive acceptance, signing and production rollout remain pending.

Apple Developer now has Associated Domains enabled for the dev app and a
regenerated development profile for the existing iPhone/certificate. Local profile
retrieval and signed installation remain pending: Chrome blocks the download by
organization policy, and Xcode authentication is required for managed retrieval.


Xcode authentication and managed profile retrieval subsequently succeeded. The
production-connected repair dev candidate (0.5.3 build 6) compiled and installed
on the iPhone; launch remains blocked by the phone lock. One focused hosted
publishing UI test passed the single notice with historical inclusion off.
Harmless content screened automatically, authored Hide/Show worked, a genuine
synthetic provider flag was recorded, and a synthetic report reached its queue
with one operator alert. The final hosted QA branch was deleted and only main
remains. See the repair status for the precise remaining acceptance gates;
production repair deployment remains held.

After the owner unlocked the iPhone, the installed repair dev app launched
successfully and its running process was confirmed. This resolves the physical
launch blocker; owner screen acceptance, installed links and production repair
rollout remain pending.

The owner confirmed that the repair dev build loads the real account and older
photos correctly. Remaining feature acceptance and the backend repair remain
held; this confirmation is limited to account and photo compatibility.

The owner also confirmed that the readable Joe profile URL delivered to the
installed dev app opens the correct profile. Cross-app universal-link selection
and preview acceptance remain distinct pending checks.

Owner physical acceptance now includes automatic app opening from the external
readable profile link, Muddy Waters selection from Charleston, draft pin
persistence and audience-labelled Publish. Production repair is still pending;
a fresh read found 70 technical failures (54 provider_configuration, 15
invalid_input, one screening_unavailable), with human approval preserved.


## 2026-09-14 — Repair production cutover

Applied the three repair migrations with all 72 original-table fingerprints and
bucket visibility unchanged. Deployed all five matching functions and re-enabled
screening. Audited and requeued 70 technical-failure revisions while preserving
the human approval. Recovery completed with 69 automatic approvals, zero pending/flagged items and
one explained missing-media service item.

Fresh backups restored 338 objects (445,112,136 bytes) byte-for-byte and 6,230 rows
across 76 typed tables. The final hosted checks passed real four-photo automatic
approval, bounded malformed-media retries, Private withdrawal, separate service
and flagged queues, and approval/rejection reason rules. All QA branches were
deleted. The repaired production-connected dev build is on the owner's phone;
no TestFlight distribution or App Store submission occurred.


Recovery finished with 69 automatic approvals and no content flags. One August 29
Matcha references two files absent from all retained backups and the phone cache;
it is a service issue, retains historical visibility and was not falsely approved.
A focused worker follow-up records sanitized missing-object HTTP/code diagnostics;
its seven tests passed and the updated function is deployed. Final production
counts remain 82 posts, 18 users and 338 objects. See the repair status for the
specific recovery action. No TestFlight build was distributed.


## 2026-09-14 — Correction to public-profile preservation claim

Directly verified that Amanda's 15 Friends posts are excluded by the separate
historical-publication opt-in rule, including 14 with successful screening. Her
11 Everyone posts appear. The prior screening-transition check did not prove
public-profile inclusion; the earlier visibility claim was too broad. This
read-only diagnosis makes no publication or moderation-policy changes. Current
evidence and the requested policy clarification are in REPAIR_SHARING_STATUS.md.


## 2026-09-14 — Restore historical Friends profile visibility

At the owner's explicit request, restored the existing complete Friends-post set
on authored/tagged public profiles, retaining explicit opt-outs, per-profile hides,
blocks, enforcement and Private exclusion. The additive migration preserved all
72 original-table fingerprints and changed no post audiences or consent records.
Amanda's August 29 Matcha now appears in the actual anonymous profile response.
A focused restoration regression and signed Debug compile passed. Removed the
now-obsolete historical opt-in checkbox from the single new-post notice. The
missing-photo service issue remains separate and no content was falsely approved.
