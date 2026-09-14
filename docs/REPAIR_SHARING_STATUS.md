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
remains bounded. Selected MapKit completions retain their location context;
keyboard-driven viewport updates cannot replace an active selection lookup. Pin
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
tests, both focused PGlite repair contracts, Debug compile, 148 unique focused Swift
tests, 16 unique sharing/link tests, and one isolated Auth identity test (165 distinct
tests total). Xcode printed
most results twice; the prior totals counted duplicate log lines.
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

Runtime gate remains incomplete. The current signed app passed sign-in through
its real UI against a local synthetic HTTP backend and reached Feed. An additional
focused AuthSessionIdentityTests regression passed with isolated Keychain storage
and a synthetic HTTP response. A direct synthetic Keychain write/read/delete probe
also passed. These rule out a general current-build Keychain or AuthService
identity failure. Follow-up hosted sign-in, profile setup, Feed reads and session restoration after relaunch now pass against the isolated repaired backend. No production-account
or authentication safety checks were weakened.

Live MapKit returned the Burlington result first for “Muddy Waters Vermont” from
the Charleston search context. Selection reproduced the reported failure. A
viewport refresh caused by keyboard dismissal can replace the selected lookup;
the follow-up isolates selection resolution from viewport searches and delays
keyboard dismissal until selection finishes. The same-path acceptance passed: one tap
opened Muddy Waters at 184 Main St, Burlington, and Log a Sip opened the composer with
that cafe selected. The final compiled follow-up was installed and launched
successfully. Presentation stayed pinned across reflection navigation and app
relaunch/resuming the draft; its synthetic account-scoped preference was also present on
disk. Keyboard Done dismissed editing without publishing. These checks used a local
synthetic app backend plus live MapKit, not production post writes.

Device signing update: the owner completed Xcode authentication. Xcode downloaded
the regenerated development profile through its supported account interface.
The production-connected Debug candidate (co.mugshot.app.dev, 0.5.3 build 6)
compiled and installed successfully on the connected iPhone. Its signed
entitlements contain both associated domains. Device launch was rejected with
Apple's Locked reason; installation is verified, hardware acceptance is not.

Remaining: finish the explicitly pending acceptance paths below, launch on the
unlocked connected phone, then run the guarded production rollout and measure
technical-backlog recovery.
Production migrations, screening thresholds, legacy bucket visibility and all
original data remain unchanged by this repair. Fresh preservation evidence must
be captured again at the eventual deployment time. Never infer hardware or
production success from compilation.

Disposable QA was deleted after verification; branch listing now contains only
production main. No QA branch is left accruing compute charges. Local encrypted
backups and sanitized rehearsal evidence are retained outside version control.

## Final acceptance and rollout checklist

These are remaining gates, not completed claims. Retain the existing passing
worker, SQL, preservation and unit evidence; repeat a check only for a changed
artifact or a demonstrated failure.

| Gate | Required evidence | Current state |
| --- | --- | --- |
| Hosted app session | Signed candidate signs in, restores the same account after relaunch and reads its real hosted projections | Passed signed app email sign-in, profile setup, Feed reads and relaunch against disposable hosted QA |
| Moderation UI | Harmless multi-photo post passes without a decision; real test flag/report appears with reason; technical retry appears only in Service status | Worker and hosted SQL contracts pass; hosted harmless text post passed automatically and owner details showed Screening passed; real synthetic provider flag confirmed; report submission/listing and one operator alert confirmed; multi-photo integrated UI and service/review actions pending |
| Sharing UI | Single notice, historical choice initially off, independent authored/tagged hides, Private removal everywhere and Friends excluded from Everyone Feed | Hosted visibility contracts pass; one notice with historical choice off passed in a focused publishing UI test; authored Hide/Show passed with persisted hide and explanatory feedback; remaining tagged/Private interactive paths pending |
| Composer and Feed | New applicable sip restores pins without scores; audience-labelled Publish preserves draft choice; post/edit/keyboard return retains dock position; reactions persist or visibly roll back | Pin navigation/relaunch and keyboard Done pass; all four reaction saves and forced-save rollback pass against hosted QA; Friends-labelled Publish and post-save detail passed; remaining edit/dock and fresh-sip pin paths pending |
| Installed links | Canonical profile link opens the signed app, browser fallback works, Mugsy invitation preview and marketing beta destination appear | Web endpoints and native unit checks pass; hardware routing/preview pending |
| Owner handoff | Signed dev build installed and launched on the connected iPhone with production configuration, followed by a concise owner walkthrough | Signed production-connected build installed; launch requires unlocked iPhone |
| Production repair | Refresh preservation evidence, apply guarded transaction, deploy matching functions, reprocess only eligible current technical failures and report actual outcomes | Held until acceptance gates pass |

The function deployment set includes screen-content and moderation-review, plus
all three consumers of the repaired capability-media helper: shared-profile,
shared-mugshot and public-cafe-list. Verify their deployed versions together;
deploying only the profile endpoint would leave the other readers unchanged.

For the owner walkthrough, use the existing account and first confirm old posts
and photos remain visible. Then inspect the audience notice, one new shared sip,
its screening detail, an authored profile hide, a reaction, and a copied profile
link. Keep genuine flagged-content and outage fixtures in isolated QA. Record
actual outcomes rather than interpreting absence of an error as acceptance.

Follow-up hosted acceptance used disposable branch repair-hosted-runtime-20260914.
The signed Simulator app completed email sign-in and profile setup, loaded hosted
Feed data, and restored its session after relaunch. Like, Love, Laugh and Yummy
were selected through the app and independently confirmed in public.likes. Laugh
remained visible after relaunch. An isolated forced RPC failure restored the prior
Yummy icon and preserved the database value; the original QA RPC was restored.
No production data was used or changed by these synthetic interactions.

The browser Simulator mirror rendered successfully but did not execute its
coordinate input, so it did not establish composer acceptance. At that checkpoint,
Mac native control was locked and Apple Developer required sign-in; the device
signing update above records the subsequent unlock and profile regeneration. The hosted branch was
deleted and the subsequent branch listing contained only production main.

Final hosted checkpoint used disposable repair-final-acceptance-20260914. One
focused publishing XCTest passed through caption entry, Publish · Friends, the
single acknowledgment notice (historical choice off), and save. The deployed
worker automatically approved the synthetic profile and photo-free post; native
details showed Screening passed. Hide from my profile persisted one hide record;
Show on my profile restored the control with explicit tagged-profile independence.
A deliberately unsafe synthetic profile revision produced needs_review with
provider_flag from the live provider, rather than a technical reason. A synthetic
report submitted through the public RPC appeared in the pending Reports API and
created one operator Activity alert. The dashboard visibly separated Flagged
content, Service status and Reports and appeals. Detailed review actions remain
unaccepted; these results do not establish every moderation UI path.

This checkpoint's branch was deleted and the subsequent listing showed only main.
The Simulator's QA session was terminated. No production data changed, no training
sharing setting changed, and no TestFlight operation occurred.
