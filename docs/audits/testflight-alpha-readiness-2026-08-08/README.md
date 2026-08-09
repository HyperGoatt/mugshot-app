# Mugshot TestFlight Alpha Readiness Audit

Date: 2026-08-08; updated 2026-08-09
Release candidate: 0.5.1 (1)
Production app bundle: `co.mugshot.app`

## Verdict

The iOS source, production schema, live-session enforcement, durable deletion
worker, Apple Developer identifiers, production provisioning profiles, Apple
authentication configuration, APNs configuration, signed Release archive, and
App Store export pass their completed release gates. The six rehearsed
migrations and two account-deletion operations migrations are live, and
production migration history matches all 114 repository migrations.
Signed-client account-deletion acceptance and the unavailable canonical Codex
Security report remain open.

Do not invite external friends until the database branch rehearsal, signed
archive validation, upload processing, and first external-group Beta App Review
are complete.

## Release plan and state

| Gate | State | Evidence or stopping condition |
| --- | --- | --- |
| Repository, dependency, signing, and platform inventory | Complete | Xcode 26.2 / iOS 26.2 SDK; all app targets and production identifiers reviewed. |
| Codex Security Deep Security Scan | Blocked by host | Preflight passed, but discovery refused to start because this Codex task has no managed filesystem permission profile. No canonical report exists and no substitute report is claimed. |
| App Review, privacy, moderation, and account lifecycle audit | Complete | Privacy/terms/support/moderation surfaces exist. Privacy disclosures were reconciled with shipped behavior. |
| Scoped source and packaging fixes | Complete | Privacy manifests, export-compliance flag, iPad orientations, HTTPS Maps links, dependency pin, and shared XCTest scheme are present. |
| Deterministic and runtime verification | Local portion complete | Full static gate passed; 16 Deno tests passed; hermetic PostgreSQL contracts, including adversarial legacy-notification checks, passed; effective XCTest result 357/357; app built, installed, launched, and settled on iOS 18.6; unsigned Release archive passed Xcode store validation. |
| Production backend release | Complete | A fresh logical backup preceded deployment. All 114 migrations are live with zero drift; the approved legacy Shared Mugshot was converted to reciprocal tags and retired without losing either visit. |
| Account-deletion backend gates | Backend complete | Live/revoked/active-job/anonymous session checks passed. The Vault-backed five-minute worker produced a successful scheduled empty drain. Signed-client and destructive disposable-account acceptance remain. |
| Signed distribution archive | Complete | App Store archive and IPA export succeeded with the Candlewood Coffee LLC distribution identity and all three production profiles. Deep signature, entitlements, version, bundle ID, and embedded-profile checks passed. |
| App Store Connect record and upload | User-owned submission step | No upload will be performed by this task. The account holder will create/complete the record, upload the validated archive, and submit the first external build. |
| External TestFlight group | Pending | Requires processed upload, export-compliance answer, beta metadata, Beta App Review, and tester invitations. |

## Findings fixed in this branch

- Added target-level privacy manifests for the app, share extension, and widget.
- Declared no tracking and the linked data used for functionality/analytics,
  including precise location because saved cafe coordinates can identify a
  visit location.
- Declared that the app uses no non-exempt encryption so App Store Connect does
  not ask the export-compliance question for every build.
- Added all four iPad interface orientations required by the iPad app target.
- Replaced plain-HTTP Apple Maps URLs with HTTPS.
- Updated Supabase Swift from 2.48.0 to 2.54.1, including recent Auth and
  Realtime hardening/fixes; retained the current PostHog pin because the audit
  found no release-relevant fix requiring another dependency change.
- Added the shared `MugshotTests` scheme. The prior machine-local scheme had no
  enabled test bundles and could not run tests in CI or another checkout.
- Reconciled one stale Map scope expectation with the repository's newer,
  explicitly approved journal-first order.
- Replaced the deprecated application badge API with
  `UNUserNotificationCenter.setBadgeCount`.
- Constrained the legacy PWA notification INSERT path to authenticated social
  actions with verified actors, recipients, references, block state, and exact
  column grants. Added compatibility for the PWA's `friend_accept` event name.
- Published the associated-domain file at the production domain and verified
  its status, content type, redirect count, and repository-exact body.
- Replaced the old test bundle family and former Apple team with the production
  `co.mugshot.app` family under Candlewood Coffee LLC, while retaining the
  internal Xcode target names to avoid unrelated source and test churn.
- Registered the production app, share extension, widget, and shared App Group;
  installed all three App Store provisioning profiles; updated Supabase Apple
  client IDs; and configured the live APNs worker with a team-scoped
  sandbox-and-production key.
- Routed signed-out public cafe-list policies through caller-bound public
  wrappers instead of sealed private helpers, and reconciled the remote
  contracts with the current tag-only suggestion API.

## Production backend release

Production project `quskamnfwglctqewwfln` was backed up before mutation. The
logical archive is stored outside Git at
`~/Library/Application Support/Mugshot/Backups/2026-08-09-pre-release/public-private.dump`
(SHA-256 `e6ae8dc7afe838bbe5c3d026ad9cca8022e98a2626591af370ec876c7e4e86f8`).
The approved six migrations were then applied in order:

1. `20260723154204_post_publish_share_hub.sql`
2. `20260731143430_enforce_visit_caption_length.sql`
3. `20260803143000_edit_owned_visit_content_v2.sql`
4. `20260804204427_tag_only_social_edit_v2.sql`
5. `20260809022000_harden_legacy_notification_inserts.sql`
6. `20260809022500_fix_alpha_qa_contracts.sql`

Post-deployment verification found all eight tag rows intact, both former Shared
Mugshot contributions represented as reciprocal tags, zero rows in each retired
legacy container table, the caption constraint present, both new edit/share
RPCs present, and the authenticated-only legacy notification policy calling its
validation function. Production and repository now report the same 114
migrations.

Account deletion is still intentionally fail-closed for initiation. The
PostgREST hook and durable worker are now live and their two Edge Function flags
are true. Password step-up semantics passed directly against production, but
`ACCOUNT_DELETION_STEP_UP_CLIENT_READY` remains false until the signed client
and complete disposable-account flow pass. See
`docs/ALPHA_ACCOUNT_DELETION_DEPLOYMENT_GATE.md` for the evidence and final
matrix.

## Apple, authentication, push, and hosting state

- App Store Connect currently contains no Mugshot app record.
- Xcode recognizes `Candlewood Coffee LLC` (Team ID `R389G6U968`), its Apple
  Distribution identity, and installed App Store profiles for
  `co.mugshot.app`, `.share`, and `.widgets`.
- Apple Developer also contains the device-Debug identifiers
  `co.mugshot.app.dev`, `.dev.share`, and `.dev.widgets`. The main development
  App ID has App Groups, Associated Domains, Push Notifications, and Sign in
  with Apple enabled and is grouped with the production Mugshot App ID.
- Supabase Apple authentication now accepts `co.mugshot.app` and
  `co.mugshot.app.dev`; production still contains zero Apple identities from
  the retired test bundle family.
- The team-scoped `Mugshot APNs` key (key ID `RHY8PQRS76`) supports sandbox and
  production. Its one-time private key is stored outside Git with mode `0600`
  under `~/Library/Application Support/Mugshot/Secrets/APNs/`. The production
  worker reports `pushDelivery: configured`. Direct sandbox and production
  provider-token probes both reached Apple and returned the expected
  `BadDeviceToken` for an intentionally invalid token, proving the key, team,
  and topics are accepted. An actual notification and tapped cold launch remain
  part of the first physical-device pass.
- `MUGSHOT_APP_STORE_URL` is intentionally blank until the app record supplies
  an Apple ID. It is not used by the current share flow and does not block this
  TestFlight alpha; populate it for a later customer-facing release.
- `https://mugshotapp.co/.well-known/apple-app-site-association` now returns
  HTTP 200 directly with no redirects and `application/json`; its response is
  byte-for-byte identical to the repository copy and covers production and
  development bundle IDs for `/m/*` and `/l/*`.
- Apple's associated-domain CDN also returns HTTP 200 with the same 514-byte
  production document and reports the Mugshot origin as its source.
- Publishing through the current Lovable plan restored its small
  "Edit with Lovable" site badge. This is not an iOS or TestFlight blocker.
- App Store Connect accepted the complete new-app form for `Mugshot` and
  `co.mugshot.app`, but it was cancelled without creating the user-owned app
  record. The Free Apps Agreement is active through August 7, 2027; the Paid
  Apps Agreement is not needed for this free alpha. EU trader-status information
  and the new social-media age-rating questions remain for submission.

## App Store Connect privacy answers

Use `docs/app-store-submission-data-inventory.md` and the packaged
`PrivacyInfo.xcprivacy` as the source of truth. The release declares:

- No tracking and no tracking domains.
- Linked, app-functionality data: email address, name, user ID, device ID,
  precise location, photos/videos, and other user content.
- Linked analytics data: user ID, product interaction, and other usage data.
- Required-reason UserDefaults access: `CA92.1` and `1C8F.1` in the app, and
  `1C8F.1` in the share extension.

The complete app-record fields, ready-to-paste beta copy, privacy mapping,
age-rating evidence, review notes, external-group sequence, and human-only
placeholders are collected in
`docs/audits/testflight-alpha-readiness-2026-08-08/APP_STORE_CONNECT_SUBMISSION.md`.

## Verification record

Tier 4 release gate, using the repository's one-session acceptance policy:

- `./scripts/verify-no-simulator.sh full-static`: 11 passed, 0 failed, 1
  optional parser check skipped because `pglast` is not installed.
- Deno Edge Function unit tests: 16 passed.
- Hermetic PostgreSQL behavior and security contracts: passed.
- Generic Debug app/test compile: passed.
- XCTest unit target: 355 passed and one stale expectation failed; after the
  assertion repair, the focused failing test passed. Effective result: 356/356.
- iOS 18.6 Simulator: build, install, launch, and settled Map UI passed.
- Unsigned arm64 Release archive: passed Xcode store validation; all three
  target privacy manifests and dependency manifests were present and valid.
- Signed Release archive and App Store IPA: succeeded with the Candlewood
  distribution identity and all three correct profiles. Deep signature,
  package-integrity, production-entitlement, bundle ID, version/build, and
  embedded-profile checks passed. The owner-only release package is stored at
  `~/Library/Application Support/Mugshot/Releases/0.5.1-1/`; the IPA SHA-256 is
  `aac2a4802eb92a9ec80550181262d8ee88731a02ff44b2f0268fa68a864b237d`.
- Follow-up full-static gate after the notification hardening: 11 passed, 0
  failed, 1 optional parser check skipped; the focused legacy PWA compatibility
  test passed. Effective XCTest result: 357/357.
- Disposable Supabase branch: all 112 migrations replayed in order with zero
  local/remote drift. Initial suite result was 43 passed and 5 failed; the three
  underlying compatibility defects were fixed. The 48 unaffected contracts and
  corrected focused contract then passed, for an effective 49/49 result. The
  branch was deleted after verification.
- Production deployment: six rehearsed migrations applied after a fresh logical
  backup; all conversion counts and zero-drift checks passed.
- Account-deletion live-session gate: rollback test passed; authenticated 200,
  revoked 401, active deletion job 401, post-cleanup 200, and anonymous 200.
- Account-deletion worker: rollback test and backend suite passed; the first
  scheduled cron run and `pg_net` response succeeded with an empty drain.
- Password step-up: initiating session rejected, fresh same-subject session
  accepted once, replay rejected, and gated deletion created zero jobs.
- Final post-export `full-static` gate: 11 passed, 0 failed, with only the
  optional local `pglast` parser check skipped.

## Upload completion checklist

- [ ] Start and complete the canonical Codex Security Deep Security Scan.
- [x] Rehearse the six migrations on a data-less Supabase branch, run the
      complete QA harness, replay in order, and prove zero drift without
      mutating tester data.
- [x] Approve the one-container Shared Mugshot retirement, then deploy the six
      rehearsed migrations to production and verify zero drift.
- [ ] Finish signed-client and destructive disposable-account deletion
      acceptance; backend hook and worker gates are complete.
- [x] Publish and validate the AASA file.
- [x] Sign in to the Candlewood Coffee LLC Developer Team in Xcode.
- [x] Create the Apple Distribution certificate and three production profiles.
- [ ] Create the app record and record its Apple ID. Populate
      `MUGSHOT_APP_STORE_URL` for a later customer-facing release; it is not a
      TestFlight alpha blocker.
- [x] Prepare the App Privacy mapping, age-rating evidence, beta description,
      feedback address, What to Test copy, review notes, and group sequence.
- [ ] Enter those answers in App Store Connect and supply the account holder's
      EU trader decision, review contact, reviewer credentials, and tester
      emails.
- [x] Create and validate a signed distribution archive, including final
      entitlements and embedded distribution profiles.
- [ ] Upload 0.5.1 (1), confirm TestFlight processing, answer export compliance,
      add it to the first external group, submit Beta App Review, and invite the
      friend testers after approval.
