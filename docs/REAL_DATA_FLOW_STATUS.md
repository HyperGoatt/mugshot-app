---
document_type: living
status: current
last_verified: 2026-09-25
---

## Cafe-backed publication recovery repair — 2026-09-24

A cafe-context publication first resolves or creates its canonical cafe, then
creates the stable visit row, uploads media, and finalizes the visit. Production
evidence exposed a break at the first boundary: the cafe INSERT policy allowed a
live account to submit, but PostgREST's requested representation also evaluated
the cafe SELECT policy before the original AFTER INSERT admission receipt was
observable. The transaction rolled back, leaving no cafe, visit, or Storage
object. The account-scoped frozen submission correctly remained local and
retryable, which drove the recovery banner.

Migration `20260924153000_repair_cafe_insert_returning.sql` moves the private
admission receipt to a BEFORE INSERT trigger, defers its cafe foreign key until
the row exists, and makes the existing authorization lookup observe that
same-statement receipt. It neither exposes an unverified cafe to another account
nor changes visit ownership, audience, upload, or cleanup rules. The exact
`INSERT ... RETURNING` and cross-account privacy cases pass hermetically and in
the complete hosted contract suite. Production is configured at migration 181.
A rolled-back production check using the affected account context passed without
leaving a row; protected content fingerprints, visit and Storage counts, and
bucket visibility remained unchanged.

## Home Sip V3 composer and publication data flow — 2026-09-18

The central Home composer now coordinates setup, optional preparation, capture,
shared reflection, local private save, and optional publication without handing
navigation to the Journal library. It continues to use the account-scoped Home
workspace as authority for recipes, immutable versions, attempts, sessions,
drafts, media names, conflicts, and pending synchronization.

Each attempt freezes the chosen recipe-version targets and stores actuals only
when entered or measured. New reflection and custom-actual properties are
optional additive fields in the existing versioned JSON document. Legacy Coffee
templates and unknown method identifiers decode without destructive rewriting.
Async media/private-save work verifies the originating account before committing.

Share creates or reuses a separate stable Sip publication draft only after the
attempt is local. Its projection includes publishable reflection and explicitly
selected preparation evidence. Recipe instructions can enter the post only via
an authorized exact-version Full details attachment; linked recipes do not
recurse. Private note, next-time note, inventory, local file paths, and
unselected content are excluded. Confirmed post success alone marks the Home
attempt published; retry retains the operation identity.

No schema, migration, bucket, RLS, Edge Function, schedule, or production data
changed for V3. Existing workspace/publication contracts remain the backend
transport and enforcement boundary.

The focused data-flow runtime gate passes on iOS 27.0: all 30 Home workspace
tests preserve targets/actuals, versions, conflicts, sessions, account isolation,
media recovery, and publication state; central setup-first routing and an
unrated/photo-free two-surface Quick Log private save also pass. This evidence
uses the installed Xcode 26.2 toolchain against the iOS 27 runtime and does not
substitute iOS 26.3 for a failing current-runtime path.


## Native Home workspace — 2026-09-16

The default-on Home/Recipes implementation owns atomic account-scoped recipes,
attempts, drafts, preparation sessions, batch progress, preferences, conflict
state, and immutable version references. The additive owner-bound workspace RPC
mirrors recipe identities and versions without fabricating visits. Targets and
actuals remain separate, and unknown values stay unknown.

Private attempt photos use generated owner-prefixed paths in the existing private
Home bucket with durable upload receipts and authenticated downloads. Versioned
linked-component progress and optional metric layouts persist in the workspace.
Conflicts pause remote synchronization without blocking local saves; explicit
reconciliation preserves historical versions, attempts, and in-progress sessions.
Shared recipe content uses nested per-type allowlists and never recursively
publishes linked instructions.

All 65 SQL contracts and real Auth/Data API/private Storage round-trips passed
against an isolated database containing all 177 migrations. Conflicts return HTTP
409 immediately. Home unrated posts use the existing zero-score wire sentinel
without creating a user rating or rated reflection; private feedback is excluded.
The native hosted journey and all 22 Home model/store tests pass. The disposable
branch was deleted after acceptance. Production now matches all 177 migrations;
pre/post content fingerprints, counts, Storage inventory, and bucket visibility
were unchanged. The native flag defaults on and preserves an explicit stored-off
rollback. See [data ownership and rollout state](HOME_RECIPES_IMPLEMENTATION.md).

Build 0.5.3 (8) historically adds a UI-only under-construction gate at central
Add > Log a Sip > Home. Current source removes that client gate and opens the
unified quick log without changing workspace ownership, issuing a Supabase
write merely for navigation, or changing stored recipes, attempts, drafts,
media, or conflict state.

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

## TestFlight feedback data contracts — 2026-09-14

Personal Map scores are read projections: each account-owned completed visit
contributes its V3 Mugshot score once at the canonical cafe, with legacy overall
score used only when V3 is absent. Incomplete, deleted, invalid and unrated
entries are excluded. The client paginates completed visits, deduplicates stable
visit IDs, batches an owner-only score projection and averages before one-decimal
display rounding. Cafe Pulse and Friends-map score semantics are unchanged; no
stored rating is rewritten.

Pending publication remains local frozen authority until the exact stable visit
is authoritatively complete. Recovery performs an owner-bound lookup before any
upload or creation. An authoritative absence may recreate only from a valid
frozen submission using the same IDs and object paths; lookup failure is unknown
state. Authentication and network failures pause the pass, while isolated
missing-media, invalid-payload, publication/setup and local-storage failures stay
reviewable and do not block later eligible records.

Reflection preferences and compatible-device state are caller-bound Supabase
contracts. Private occurrence and delivery rows are server-owned. The database
chooses eligible owner-bound targets from completed visits, while the client
stores only a pending route for the active matching account. Reminder delivery
is independent of social Activity history and badge state.

Production migrations `20260914191634` and `20260914204700` own these contracts.
The follow-up bounds each deterministic APNs collapse identifier to the
occurrence UUID. The rollback switch migrated disabled and was enabled after
deployment checks with zero activated preferences, occurrences and deliveries.
The five-minute cron and worker are live, but a device remains ineligible until
its owner explicitly saves the new preference contract and reports the supported
route capability.

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


# Real data flow status

> Current repair: [Repair and sharing status](REPAIR_SHARING_STATUS.md) supersedes
> the earlier delivery and acceptance statements below for moderation, Friends
> publication, profile sharing and the reported native bugs. Those earlier
> checkpoints remain evidence of the previous candidate, not this repair's acceptance.


Sprint 1 source adds readable `/profile/username` links, permanently reserved
handle aliases, and anonymous recipient pages in the companion PWA. Local
handle contracts and synthetic browser checks pass; these changes are not yet
production deployed or accepted on an installed app. Current delivery evidence
is tracked in [Sprint 1 delivery](SPRINT_1_TRACKER.md).

Revision-bound screening queues, workers and outward-read gates are implemented
and pass isolated hosted contracts. Private content and private notes remain
excluded; production screening is not active. See the current Sprint 1 tracker
for exact activation and runtime gates.

## Cafe catalog admission — source and isolated QA

The `verify-cafe` Edge Function accepts only an authenticated provider/ID pair.
Native Apple selections and PWA Google selections use this endpoint for new
provider records. It fetches canonical fields from the matching provider, uses
a service-only database admission function, preserves the existing provider
record ID on retries, and limits each live account to 30 attempts per hour.
Maps credentials remain server-only; errors omit raw provider details.

Manual cafe saves retain their private journal path. New manual identities are
scoped to their submitter. Raw catalog reads and the two legacy catalog-wide
RPCs require provider verification or an existing authorized content context.
Creating a reference to a guessed hidden cafe ID cannot create read access.
Provider verification is withdrawn when a catalog correction changes its fields;
shared text continues through the existing revision-bound screening workflow.
Private-only cafe fields are never submitted to OpenAI.

Migration `20260913191001` and its focused role/retry/rate contracts pass hosted
QA. This is not a production deployment claim. Google verification uses the
existing Places key; Apple uses the approved Maps-only key and `server_api` JWT
scope. Production activation still follows the release workflow.

## Authority model

Mugshot uses remote truth for durable signed-in product state and scoped local
truth for guest use, recovery, caching, and preferences. A remote success is the
commit point; local state may optimistically present or recover a command but
must not overrule an authoritative remote result.

| Domain | Authoritative source | Local role | Failure behavior |
| --- | --- | --- | --- |
| Authentication | Supabase Auth | Callback queue and last-known presentation | Fail closed for account-bound operations |
| Profile and social identity | `public.users`, sealed `profile_favorite_spots` / `profile_tagged_post_hides` / `profile_visibility_preferences`, and v4 profile projection/list RPCs | Account-scoped rendering cache plus DEBUG-only design fixture | Default to Friends plus Everyone only when the owner preference permits it; preference-off is Everyone-only and Private always fails closed |
| Visits, drinks, ratings and captions | Supabase visit schema/RPCs | Guest records, drafts and pending publication | Preserve draft/outbox until remote completion is proven |
| Visit and profile media | Supabase Storage plus metadata rows | Preview/cache and upload recovery | Resolve HTTP and durable `mugshot-storage://` values through the viewer-authorized remote pipeline, including Profile-share artwork; clean partial uploads through bounded recovery paths |
| Home recipes and coffee library | Home Workbench tables/RPC projections | Draft/template cache | Remote owner projection wins after save |
| Feed, Journal and profiles | Viewer-specific Supabase projections | Rendering cache | Keep the last valid view and show an actionable error |
| Cafe identity and detail visit cards | `public.cafes` provider rows plus viewer-scoped Supabase visit queries and RLS | Conservative read-time stitch projection and local visit fallback only when no visible remote visit is returned | Query all equivalent cafe IDs, then render only self, friend, and Everyone visits the backend permits; never mutate cafe rows or synthesize remote visibility from local history |
| Likes, comments, mentions, reactions and tags | `likes.reaction_kind`, caller-bound reaction/comment/tag RPCs, and historical `visit_reactions` compatibility rows | Optimistic UI only | Reconcile to server result; a missing additive reaction RPC falls back only to binary Like; stale account responses are discarded |
| Friends, blocks, reports and enforcement | Supabase caller-bound RPCs | Presentation cache | Privacy and block checks fail closed |
| People discovery | Production-configured invite/suppression/attribution state, caller-bound RPCs, and `people_v2` suggestion ranking | One selected contact name/phone retained only while preparing the native Messages invitation | Never upload a contact phone number or address book; Messages owns final send; suggestion signals use only viewer-visible shared Mugshots, mutual edges, recent visible interactions, and shared cafe lists; explicit opt-outs, blocks, and visibility fail closed |
| Saved cafes and cafe lists | `user_cafe_states` and cafe-list RPCs | Guest saved state and merge queue | Preserve explicit user intent until merged or dismissed |
| Activity and unread count | `activity_events` through caller-bound RPCs | Current page, pending route and app-icon presentation | Push failure never removes Activity history; successful refresh/read actions apply the authoritative unread badge |
| Push preferences and device ownership | Versioned preference/device RPCs plus `get_backend_capabilities_v1`; v3 badge capability defaults false | Installation ID, last token hint, uncertainty flag | Register v3 only for the exact authenticated account and typed build environment; malformed capability data disables remote registration |
| Nearby reminders | Shared iOS notification authorization plus local location state | Region/cooldown store | Independent of APNs delivery while still triggering one safe registration reconciliation after permission changes |
| Criterion setup preferences | Account- and criterion-scope-bound `UserDefaults` stores (`sip` plus the applicable environmental context) | Authoritative for pinned criterion names and preferred importance only | Never carry a prior visit's criterion score into a new sip; clear account-owned preferences on account deletion |
| Sip drafts | Account-scoped `SipDraftStore` metadata and local photo bundles | Authoritative until publish completion is proven | Central Add creates a new draft ID; Resume draft or Journal explicitly selects saved work, and unreadable bytes are preserved rather than deleted |
| Analytics | PostHog project | SDK queue | No private content or product identifiers |

## Compatibility behavior

The client uses versioned RPCs and treats missing functions as compatibility
states, not empty data. Existing Activity code retains a hardened legacy read
fallback. The backend now advertises additive `push_badge_sync` support while
retaining v2 device registration and delivery revalidation. Source build 5 now
loads and validates that contract at account activation, registers badge support
only through v3, and reports missing layers without disabling Activity.

Editorial Atlas reads prefer v4 profile and profile-publication list RPCs. During an
additive rollout, missing v4 reads fall back to older projections and then
apply an Everyone-only client filter to visible Mugshots; missing tagged and
Favorite Spot mutations do not invent local remote truth. Existing v3 profile,
highlight, and binary social contracts remain available to older clients, but
the new UI neither reads nor renders Profile Highlight. The new profile contract
now requires version-1 affirmative consent for Friends-on-profile publication
in Sprint 1 source. V2 writes record consent, legacy V1 can only disable,
and tagged Friends content also requires author consent. This migration is not
production deployed. The contract exposes only caller-bound preference writes,
and excludes Private from authored, cafe, map, tagged, and anonymous-link
projections regardless of preference.
Profile-share content consumes that same profile-published sip set, sorts it by
`created_at` descending with an ID tie-breaker, retains validated durable
private-Storage references, and resolves them only for the authenticated viewer
while rendering artwork. The signed URLs are ephemeral rendering inputs and are
not persisted into the profile or share-link contract.

Cafe provider aliases remain separate remote source rows until an explicitly
reviewed data repair is authorized. The iOS read projection stitches only an
exact normalized cafe name plus equivalent street address, or a same-name
location within 50 meters when an address is missing; matching street numbers
are required when two differently formatted non-empty addresses use the
coordinate fallback. Visit reads use the resulting ID set and continue to rely
on RLS for visibility.

## Current migration boundary

The Sprint 1 repository migration head is
`20260913023233_sprint1_readable_profile_links.sql` (not deployed). The preceding
`20260826143102_profile_editorial_atlas.sql` is the last deployed profile migration. It follows the additive reaction
migration in repository order. The profile migration is production-configured
and its expected tables/RPCs resolve in the connected project; the additive
reaction migration remains implemented and hermetically verified but undeployed.
Live production now contains 127 recorded migrations through the profile
contract, with the reaction migration still absent; worker version 6, the
minute schedule, and `push_badge_sync` remain active.
The reaction migration still requires disposable replay, the complete remote
contract suite, impact review, and an explicitly authorized live release.
The profile migration has completed production configuration; live account
behavior and replacement-TestFlight acceptance remain separate product gates.
Client capability adoption follows the order in
[the Supabase release workflow](SUPABASE_RELEASE_WORKFLOW.md).

The expressive contract is detailed in
[Post reaction contract](POST_REACTION_CONTRACT.md). Historical coffee-specific
`visit_reactions` data remains read-only compatibility data and receives no
speculative backfill.

## Non-negotiable invariants

- Never mix guest or previous-account state into a signed-in remote write.
- Never treat demo content, cached counts, or local search results as Supabase
  truth.
- Never remove a protected draft or pending submission before remote success.
- Never trust a client-supplied account ID when Auth can supply the caller.
- Never make push availability a requirement for viewing in-app Activity.


The live QA endpoint also verifies provider authentication and persistence.
Migration `20260913192620` permits service-role workers to execute the existing
PostgREST session hook. Migration `20260913193804` restores the production
website field to replayable history and includes it in shared-profile screening.
Actual QA profile projection and synthetic worker/reviewer acceptance pass;
these changes remain pending production rollout.

The 2026-09-25 data-less QA deletion journey included uploaded bytes,
fresh-session authorization, direct worker invocation, identity/media removal,
recovery without authentication, and repeated final acknowledgement. Migration
`20260925200700` repairs the acknowledgement retention clock, and production
is aligned at 182 migrations after preservation checks. Apple provider
revocation and signed-client acceptance remain separate.


Canonical shared-post text includes visible brew/equipment fields, context
criterion names, and raw notes only when explicitly shared. Reflection changes
refresh the associated screening revision. Private posts and private raw notes
are excluded. The canonical criterion projection uses an explicit key allowlist.
Discovery enrichment cannot reveal hidden cafe IDs and only aggregates admitted
public visit evidence. Migration `20260913200859` is verified on isolated QA.

Legacy reflection reads now require current visit admission, comment lists and
reply counts exclude pending comment revisions, and recipe identity lookup
requires the same authorization as recipe projection. The focused hosted
regression passes at migration `20260913202410`.

Paid catalog QA is deleted and absence verified. OpenAI and Maps credentials
are staged in production with screening disabled; this does not establish
production feature activation. Native acceptance and the asynchronous
PostHog erasure confirmation remain open.

A subsequent signed native candidate passed email sign-in, session restoration
and profile onboarding on fresh isolated QA. All 62 contracts passed together.
The native-created profile was screened and its readable endpoint and default
Friends-profile exclusion verified. That QA branch is also deleted. Remaining
native screens and provider/production acceptance are not yet established.
