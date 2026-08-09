# Mugshot TestFlight Alpha Readiness Audit

Date: 2026-08-08; updated 2026-08-09
Release candidate: 0.5.1 (1)
Production app bundle: `co.mugshot.app.testMugshot`

## Verdict

The iOS source and unsigned Release package pass the local release gate after
the fixes recorded below. The build is not yet distributable to TestFlight.
Apple signing access, the App Store Connect app record, six missing production
database migrations, account-deletion activation, and the unavailable canonical
Codex Security report are open blockers. The associated-domain hosting blocker
is resolved.

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
| Production backend release | QA complete; production approval pending | All 112 migrations replayed with zero drift and an effective 49/49 remote contract result on a data-less branch. Production deployment pauses because the tag-only migration will convert and retire one live legacy Shared Mugshot container. |
| Signed distribution archive | Blocked by Apple account | Xcode has no valid signed-in account, Apple Distribution identity, or distribution profiles for the app and two extensions. |
| App Store Connect record and upload | Blocked by Apple account | No app record exists. App Store Connect and Xcode require account authentication and any prompted 2FA. |
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
- Routed signed-out public cafe-list policies through caller-bound public
  wrappers instead of sealed private helpers, and reconciled the remote
  contracts with the current tag-only suggestion API.

## Production backend blockers

Read-only production inspection used Supabase project `quskamnfwglctqewwfln`.
No production schema, data, secrets, functions, or settings were mutated.

The repository has 112 migrations and production reports 106. Production is
missing these migrations in order:

1. `20260723154204_post_publish_share_hub.sql`
2. `20260731143430_enforce_visit_caption_length.sql`
3. `20260803143000_edit_owned_visit_content_v2.sql`
4. `20260804204427_tag_only_social_edit_v2.sql`
5. `20260809022000_harden_legacy_notification_inserts.sql`
6. `20260809022500_fix_alpha_qa_contracts.sql`

The app already calls capabilities from this missing schema, so sharing and
editing behavior cannot be considered alpha-ready. The data-less Supabase
branch rehearsal is complete: all 112 migrations replayed in order, migration
history matched the repository with zero drift, and the remote contract result
was effectively 49/49 after the one corrected focused assertion. The temporary
branch was deleted immediately after verification, so there is no continuing
hourly branch charge.

The production `notifications` INSERT policy currently checks only that the
caller matches `actor_user_id`; an authenticated caller can still choose an
arbitrary recipient and references. Read-only production inspection confirmed
that the newer native `activity_events` pipeline is generated by authoritative
database triggers, while the hosted PWA has seven legacy client-side INSERT
sites. Migration `20260809022000` preserves those legitimate PWA actions while
rejecting spoofed actors, recipients, types, references, blocked pairs, and
content mutation. It passed both hermetic adversarial checks and the disposable
remote suite but remains unapplied in production.

The production impact check found zero captions over the new limit and no visit
deletions. The tag-only migration will rename eight existing tag rows, preserve
both contributed visits, convert the two Shared Mugshot contributions into
ordinary reciprocal tags, then delete one legacy Shared Mugshot container with
two membership rows and two contribution-link rows. That intentional retirement
is the only material destructive effect found and requires explicit approval
before production deployment.

Account deletion remains intentionally fail-closed. Production has no composed
PostgREST live-session hook, no durable deletion drain schedule, and no signed
fresh-session client acceptance evidence. Keep all three activation flags false
until the full gate in `docs/ALPHA_ACCOUNT_DELETION_DEPLOYMENT_GATE.md` passes.
Because Mugshot offers account creation, deletion must be working before the
build is presented for external Beta App Review.

## Apple blockers and hosting state

- App Store Connect currently contains no Mugshot app record.
- Xcode reports an invalid/missing account credential and no distribution
  profiles for `co.mugshot.app.testMugshot`, `.share`, and `.widgets`.
- `MUGSHOT_APP_STORE_URL` is intentionally blank until the app record supplies
  an Apple ID.
- `https://mugshotapp.co/.well-known/apple-app-site-association` now returns
  HTTP 200 directly with no redirects and `application/json`; its response is
  byte-for-byte identical to the repository copy and covers production and
  development bundle IDs for `/m/*` and `/l/*`.
- Publishing through the current Lovable plan restored its small
  "Edit with Lovable" site badge. This is not an iOS or TestFlight blocker.
- App Store Connect reported incomplete EU trader-status information and a
  pending age-rating questionnaire update. Resolve both before external review.

## App Store Connect privacy answers

Use `docs/app-store-submission-data-inventory.md` and the packaged
`PrivacyInfo.xcprivacy` as the source of truth. The release declares:

- No tracking and no tracking domains.
- Linked, app-functionality data: email address, name, user ID, device ID,
  precise location, photos/videos, and other user content.
- Linked analytics data: user ID, product interaction, and other usage data.
- Required-reason UserDefaults access: `CA92.1` and `1C8F.1` in the app, and
  `1C8F.1` in the share extension.

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
- Signed Release archive: stopped at signing before compile because no valid
  Xcode account or distribution profiles were available.
- Follow-up full-static gate after the notification hardening: 11 passed, 0
  failed, 1 optional parser check skipped; the focused legacy PWA compatibility
  test passed. Effective XCTest result: 357/357.
- Disposable Supabase branch: all 112 migrations replayed in order with zero
  local/remote drift. Initial suite result was 43 passed and 5 failed; the three
  underlying compatibility defects were fixed. The 48 unaffected contracts and
  corrected focused contract then passed, for an effective 49/49 result. The
  branch was deleted after verification.

## Upload completion checklist

- [ ] Start and complete the canonical Codex Security Deep Security Scan.
- [x] Rehearse the six migrations on a data-less Supabase branch, run the
      complete QA harness, replay in order, and prove zero drift without
      mutating tester data.
- [ ] Approve the one-container Shared Mugshot retirement, then deploy the six
      rehearsed migrations to production and verify zero drift.
- [ ] Finish the account-deletion activation matrix with disposable accounts.
- [x] Publish and validate the AASA file.
- [ ] Sign in to the Apple Developer account in Xcode and App Store Connect;
      confirm active program membership and agreements.
- [ ] Create the app record and set `MUGSHOT_APP_STORE_URL` to its final URL.
- [ ] Complete App Privacy, age rating, EU trader status, beta description,
      feedback contact, review notes, and review credentials.
- [ ] Create and validate a signed distribution archive, including final
      entitlements and embedded distribution profiles.
- [ ] Upload 0.5.1 (1), confirm TestFlight processing, answer export compliance,
      add it to the first external group, submit Beta App Review, and invite the
      friend testers after approval.
