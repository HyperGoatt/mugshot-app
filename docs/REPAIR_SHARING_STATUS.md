---
document_type: living
status: current
last_verified: 2026-09-14
---

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
The owner subsequently approved restoring already-published historical Friends
posts by default. A sealed migration receipt records that existing set without
fabricating consent or editing posts. The obsolete historical opt-in checkbox
is removed from the notice. New publication receipts use
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

## Current deployment and preservation

On 2026-09-14 the guarded three-migration production transaction completed,
advancing the existing 164-migration head to 167. Its before/after fingerprints
matched every original column and row across 72 original tables, including
owners, audiences and photo references. Bucket visibility did not change.
The deployment-time inventory contained 82 posts, 18 users and 338 Storage objects.

Fresh encrypted backups verified 338 objects / 445,112,136 bytes by decrypting and
comparing each object. A separate encrypted database snapshot restored 6,230 rows
across 76 tables into isolated PostgreSQL with matching typed-row fingerprints.
The snapshot includes account, Storage and moderation records. These local backup
artifacts remain outside version control.

All five matching functions are deployed: screen-content, moderation-review,
shared-profile, shared-mugshot and public-cafe-list. Screening was paused during
the cutover and re-enabled afterward. Existing credentials, disabled training
sharing, thresholds and legacy bucket visibility were retained.

The migration preserved the existing human approval and audited/requeued 70
current technical failures: 54 provider_configuration, 15 invalid_input and one
screening_unavailable. Recovery completed: 69 revisions were approved by successful provider responses,
zero remain pending and zero entered policy review. One pre-existing missing-media
case reached service_error after five attempts. The existing human approval
remains intact.

## Verification evidence

- 21 distinct focused worker/provider/media tests, two PGlite repair contracts and 65
  hosted SQL contracts passed. These cover the visibility matrix, independent
  hides, historical choice, Private exclusion, blocks, unrelated feed exclusion,
  current revisions, reactions, owner/operator access and alert deduplication.
- 165 distinct focused Swift tests passed: 148 behavior, 16 sharing/link and one
  isolated Auth identity regression. Debug builds and seven fast static checks
  passed. Repeated Xcode log lines are not counted as additional tests.
- Hosted native acceptance passed sign-in, profile setup, Feed reads, session
  restoration, all four reaction saves and visible rollback on forced failure.
  One additional publishing XCTest passed caption entry, Publish · Friends,
  the single notice with historical inclusion off, and saving. Native details
  showed Screening passed; authored Hide/Show persisted with explanatory copy.
- The final hosted rollout gate uploaded four real synthetic image objects and
  processed their post through Storage, the deployed worker and OpenAI: approved
  automatically, with no human decision. Malformed media stopped at five attempts
  in Service status with media_format diagnostics. Private conversion removed
  the screening job. A real synthetic provider flag occupied the policy queue
  separately; rejection without a reason failed, and approval without a typed
  reason succeeded with its audit event. Report submission/listing and one
  operator alert passed in the earlier hosted checkpoint.
- The signed production-connected iPhone dev build is installed and launched:
  co.mugshot.app.dev, 0.5.3 build 6. The owner confirmed their account and older
  photos, Joe profile routing, automatic app opening from an external profile
  link, Muddy Waters selection from Charleston, draft pin persistence and the
  audience-labelled Publish action. Provisioning includes both associated domains.
- Live profile-crawler metadata now returns Add me on Mugshot · @joe, the canonical
  profile URL and the Mugsy invitation PNG. Native preview logic passed focused
  tests. A specific rendered iMessage card has not been supplied for visual review.

The full access matrix is covered by hosted contracts rather than manually tapping
every viewer combination. Physical owner acceptance covers the specific paths
listed above; it is not a claim of TestFlight acceptance or every phone interaction.

All disposable QA branches are deleted; the final listing contains only main.
No recurring automation, TestFlight operation or App Store submission occurred.

## Owner walkthrough after backend rollout

The installed dev build already contains the matching frontend; another compile
is unnecessary unless source changes. Refresh Shared Content Status to inspect
recovery, then create a normal multi-photo shared Mugshot, inspect its screening
status, return to Feed and try a reaction. Check authored Hide/Show and the sharing
notice on the first new post if it has not yet appeared. Historical Friends publication now follows the owner-approved restoration,
subject to profile opt-outs and individual hides. Private never appears publicly.

Final legacy-photo bucket privatization and unrelated Apple/PostHog verification
remain outside this repair. Existing TestFlight installations have not received
this dev candidate.

## Individually explained service failure

The remaining service item is visit 8f1ba284-4c13-472b-8651-a80f58cdab39,
`dairiequeen`'s Matcha from 2026-08-29. It references seven private-photo objects;
five exist and two were absent from Storage before this cutover. Missing filenames:
1a9cc452-afc4-4f33-82b1-a7be3483eebf.jpg and
84dde0bb-7307-40d7-b617-958241b51b88.jpg.

Neither missing file appears in any of the three retained photo-backup inventories
or the connected dev app's URL cache. The post, all photo-reference rows and the five existing files were preserved.
Its screening-transition access predicate passes after the service-error outcome;
it was not marked screened or rejected. This does not establish public-profile
publication: the separate Friends-publication policy still applies.
Resolving this one item requires recovery/re-upload of the original missing files,
then screening a current revision. Do not silently remove the references or
fabricate approval. No other recovered item requires a moderation decision.

A focused follow-up adds sanitized Storage HTTP status and the fixed
storage_object_missing diagnostic for future missing-object failures, distinguishing
them from transient provider/storage outages without retaining raw error bodies.
All seven worker tests passed after this change, including one new diagnostic
regression; the updated screen-content function is deployed.

Final production check: 82 posts, 18 users, 338 Storage objects, zero pending
screening jobs, zero policy-review jobs, one preserved human approval and the one
explained service item. The repaired frontend was already installed on the phone;
no new mobile build is needed for the server-only diagnostic follow-up.


## Correction: Amanda public-profile visibility — 2026-09-14

The owner reported the remaining service-error post absent from Amanda's public
profile. A direct production projection check confirms that absence. The post is
Friends, not individually hidden, and its owner profile is available. The screening
transition predicate is true, but profile_visit_published_v1 is false because
Amanda has no historical-Friends public-consent/publication preference record.

All 15 of Amanda's Friends posts are excluded from her anonymous public profile:
14 passed screening and one is the missing-photo service item. Her 11 Everyone
posts are published. Therefore automatic screening is not the exclusion cause.
Earlier claims that the post's visibility was preserved were too broad: only the
screening predicate was checked, not the actual final public-profile projection.

The historical opt-in rule was explicit in the approved repair plan. Changing it
to restore historical Friends publication by default is a product-policy amendment,
not an approval of flagged content. No audience, consent, hide or moderation state
was changed during this diagnosis. The owner approved restoring historical Friends visibility. The amendment below
preserves explicit opt-outs, individual hides, blocks and Private exclusion.


## Approved historical restoration — 2026-09-14

Migration 20260914144708 records the existing complete Friends-post set in the
sealed historical_profile_publications table and restores authored/tagged profile
publication subject to every existing availability, screening, enforcement,
opt-out and per-profile hide check. It does not change audience selections or
consent records. Future posts are not automatically added to this historical set.
The new-post notice remains; its obsolete historical inclusion checkbox is removed.

The guarded production transaction advanced history to 168 migrations and matched
all 72 original-table fingerprints. A focused PGlite regression covers authored
and tagged results, unchanged records, no fabricated consent, author/tagged
opt-outs, independent hides, Private changes, enforcement, profile availability,
future post boundaries and deletion. The signed device Debug compile passed.

Crucially, the actual anonymous shared-profile HTTP response now contains the
August 29 Matcha with visibility Friends. Amanda's current Friends posts pass the
public-profile projection. Production checks found zero publicly included Private
posts, zero violated explicit opt-outs and zero violated individual hides. The
Matcha remains excluded from unrelated public discovery. Its missing-photo
service issue is unchanged; no screening approval was fabricated.
