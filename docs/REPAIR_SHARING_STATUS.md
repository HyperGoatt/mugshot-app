---
document_type: living
status: current
last_verified: 2026-09-14
---

# Repair and sharing update

This is the current repair status and supersedes earlier Sprint 1 acceptance claims
for the changed features. Documentation impact: product behavior, data ownership,
Supabase contracts, signing, privacy/safety and operations.

## Scope and preservation

Deliver a production-connected dev build for owner acceptance. No recurring
automation, TestFlight distribution, archive or App Store submission. Legacy
photo-bucket privatization and Apple/PostHog deletion-provider verification are
outside this repair. All original posts, photos, owners, audiences and human
enforcement decisions must remain intact.

## Moderation

Confirmed starting backlog: 53 provider_configuration, 15 invalid_input and one
screening_unavailable. Recorded technical failures do not establish policy flags.
A live synthetic request established that omni-moderation-latest accepts one image
per request; the old worker sent entire albums. The repaired worker sends one
image at a time with shared text, checks the current lease before each request,
and approves only after every image succeeds. A live four-image synthetic album
passed automatically. Existing JPEG/PNG photos remain unchanged; screening strips
metadata from temporary bytes. Owner-scoped historical paths are accepted, with
20 MB per image and sequential processing rather than a 16 MB aggregate cutoff.

Current thresholds remain unchanged. Private posts and private notes remain
excluded. OpenAI training-sharing choices remain disabled; this repair does not
change provider data controls. Technical failures retry at most five attempts,
then appear in Service status. Flagged content and Reports are separate operator
views. Sanitized diagnostics contain only stage, HTTP status, provider code and
request ID. Human approval requires no typed reason; rejection requires an
owner-facing reason. Existing human decisions and revision history are preserved;
the repair requeues only technical failures and does not fabricate approvals.
Historical transition receipts continue to authorize eligible revisions during
processing; new unapproved shared revisions remain owner-visible.

Operator notifications use existing Activity delivery with deduplication. The
wire kind stays reaction for installed-client compatibility; new clients route
moderation metadata to the moderation screen. Existing push preferences apply.
Revoked operators cannot read the alerts. Service alerts deduplicate by reason
and day; reports and actionable flags deduplicate by report or revision identity.

## Public profile behavior

Friends: Appears in Friends Feed and on your public profile and tagged friends'
public profiles. Does not appear in Everyone Feed.

One acknowledged version-2 notice precedes an existing account's first new post.
Historical Friends inclusion starts unselected. New publication receipts use
insertion time, so a backdated new sip follows the acknowledged policy. Prior
explicit profile opt-outs and hides remain. Public profile availability defaults
on; Private remains excluded. Author and tagged-user hides are independent and
affect only the requesting profile. Private changes or deletion remove public
profile access everywhere. Profile publication does not grant Everyone Feed or
unrelated public discovery eligibility.

## Native and web repairs

Named cafe searches can return distant relevant results while nearby Discover
remains bounded. Full suggestion titles and locations resolve selection. Pin
changes persist immediately by account and criterion scope without copying prior
scores. Publish shows its selected audience; keyboard Done only dismisses input.
The tab dock ignores keyboard inset movement. Feed and detail show the selected
Like/Love/Laugh/Yummy icon and keep optimistic rollback behavior. Owner post menus
add Hide from my profile / Show on my profile.

Canonical copied links remain https://mugshotapp.co/profile/{username}. Public
pages show the app logo, a prominent native-open action and the marketing /beta
link. Native and web link previews use Mugsy and Add me on Mugshot · @username;
separately shared profile artwork is unchanged. Both domains are declared in
native associated domains and their AASA files. Provisioning must include the
capability before claiming installed-device universal-link acceptance.

## Evidence and remaining gates

Implemented and locally verified: 13 provider/worker tests, seven capability-media
tests, both focused PGlite repair contracts, Debug compile and 296 focused Swift tests plus 32 sharing/link tests.
Hosted QA: original 64 contracts passed after adapting the lifecycle assertion to
check the unchanged delegated implementation; an additional hosted publication,
reaction and operator-alert contract passed. Migration rehearsal preserved all
72 original tables. A fresh encrypted backup restored and compared all 335 photo
objects (443,012,737 bytes). No production migration or repaired-worker deployment
has yet been recorded for this repair.

Web deployed: marketing PR #19 merged as `63d28ad`, PWA PR #14 merged as
`d96bbcc`; both CI and deployment checks passed. The live preview PNG and app-domain
AASA endpoint return HTTP 200. The profile Edge Function metadata change remains
part of the held backend rollout.

Runtime gate remains incomplete: the app launches in Simulator, but synthetic QA
sign-in returns a session-identity mismatch after the Auth API succeeds. No
production-account or authentication safety checks were weakened to bypass it.
The original focused unit run passed; this is a separate live runtime failure.

Device gate is blocked: the existing dev provisioning profile lacks Associated
Domains, automatic provisioning reports no Xcode account, and the Apple Developer
browser session requires sign-in. Computer control also reported a locked Mac.
The owner was asked only to unlock and sign in; provisioning and installation
remain agent work afterward. No repaired dev candidate is installed on the phone.

Remaining: resolve the live Simulator session issue, finish the one consolidated
runtime matrix, regenerate dev provisioning, install on the connected phone,
then run the guarded production rollout and measure technical-backlog recovery.
Production migrations, screening thresholds, legacy bucket visibility and all
original data remain unchanged by this repair. Fresh preservation evidence must
be captured again at the eventual deployment time. Never infer hardware or
production success from compilation.

Disposable QA was deleted after verification; branch listing now contains only
production main. No QA branch is left accruing compute charges. Local encrypted
backups and sanitized rehearsal evidence are retained outside version control.
