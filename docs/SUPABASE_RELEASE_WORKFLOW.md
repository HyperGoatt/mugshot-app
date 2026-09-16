---
document_type: living
status: current
last_verified: 2026-09-15
---

Home/Recipes amendment (2026-09-15): additive migrations
`20260915212702_home_recipe_workspace.sql` through
`20260916020417_home_recipe_http_conflicts.sql` are implementation-complete but
not production-deployed. They introduce owner-bound workspace synchronization,
private version content, nested projection allowlists, attribution preservation,
owner export v4, private attempt-media paths, and immediate HTTP 409 conflicts.
They do not backfill ambiguous legacy measurements, make a bucket public, or widen
Storage access.

The owner-approved data-free `home-recipes-acceptance` branch aligned all 177
repository migrations with schedules disabled. All 65 SQL contracts, the real
Home Auth/API/Storage harness, and native hosted transport passed. The synthetic
branch was then deleted and its absence verified. Production was not modified and
the native flag was not enabled. Follow the normal preservation/deployment sequence
before production activation. See the
[current evidence and rollout boundary](HOME_RECIPES_IMPLEMENTATION.md).

Current amendment (2026-09-14): production is at 170 migrations with local shared-text
validation and reactive human moderation. OpenAI execution, schedule and server
secrets are retired. See [current repair status](REPAIR_SHARING_STATUS.md) for
preservation evidence and long-press profile controls. Earlier OpenAI rollout notes
below are historical and superseded by this amendment.


# Mugshot Supabase release workflow

> Current repair: [Repair and sharing status](REPAIR_SHARING_STATUS.md) supersedes
> the earlier delivery and acceptance statements below for moderation, Friends
> publication, profile sharing and the reported native bugs. Those earlier
> checkpoints remain evidence of the previous candidate, not this repair's acceptance.

## Current repair deployment — 2026-09-14

The repair is now production-configured at 168 migrations with all five matching
functions deployed. Original-table fingerprints and bucket visibility passed
preservation checks. The dev candidate is installed on the owner's iPhone and
the recorded phone checks passed. Technical-backlog recovery completed with 69
approvals and one explained missing-photo service item; see [the current repair status](REPAIR_SHARING_STATUS.md) for exact outcomes.
All disposable QA branches are deleted. TestFlight distribution remains held.
The owner-approved historical Friends restoration is deployed; Amanda's previously
excluded Matcha now appears in the anonymous profile response. Opt-outs, hides
and Private exclusion remain enforced.

The older checkpoints below are historical evidence and do not describe the
current production head or active QA resources.


Date established: 2026-07-22

## Outcome

The repository migration directory is the source of truth for MugShot's backend.
A live project is a deployed environment, not a place to make unrecorded schema
changes. Every backend release must prove the same migration history in a
disposable data-less branch, preserve live data with measured evidence, and end
with local/QA/live histories at the same head.

The repository migration head is
`20260913212833_sprint1_saved_cafe_data_api_access.sql`. Sprint 1 migrations
are not deployed to production; follow [Sprint 1 delivery](SPRINT_1_TRACKER.md) for activation
and acceptance gates. Read-only inventory on 2026-09-13 found 127 production
migrations, most recently `20260826143102_profile_editorial_atlas.sql`.
`20260825030917_post_reactions.sql` and the new Sprint 1 migrations are absent
from production. At the initial inventory only the default branch existed. The approved
`sprint1-catalog-qa-20260913` branch was deleted after its database and server
runtime checks; a fresh branch inventory confirms only main remains. The live project reference is recorded in the existing Supabase link,
and QA scripts refuse that production reference.

The first Sprint 1 QA branch was created without data, used for repository
replay and remote contracts, then deleted on 2026-09-13. Automatic replay
exposed damaged stored statements in 85 historical production migration
records. Exact comparison found 84 incorrect records and one legitimate source
record. The 84 incorrect statement arrays have now been repaired in production
with verified schema/row invariants and a rehearsed rollback. See the
[exact repair evidence](SPRINT_1_MIGRATION_HISTORY_REPAIR_2026-09-13.md).
A fresh data-less branch automatically replayed 113 migrations through
`20260809144548`; the next migration requires operational scheduler Vault
configuration. The check branch was deleted and absence verified. The later catalog QA branch replayed all 162 migrations. All 61 contracts
at migration 160 passed together. Focused legacy reflection, comment and recipe
identity admission acceptance also passes at migration 162; the combined
62-contract run passed 61, with the older reflection test expecting edited text
to bypass screening. Its fixtures now explicitly approve those new revisions,
and the focused reflection contract passes with its audience assertions intact.
The complete suite was not repeated after that test-only correction. Native
runtime acceptance remains separate.
See [the dated QA checkpoint](SPRINT_1_QA_2026-09-13.md).

Current staging status: the owner requested real-account production testing
before any TestFlight distribution. The [September 14 staged rollout](#staged-production-owner-test--september-14)
supersedes earlier production-hold checkpoints below. Final bucket privatization
remains held for compatible-client adoption.

## Preservation-first compatibility transition — September 13

Production rollout is held at the owner's explicit preservation requirement.
The distributed `b498d92` client returns historical public photo URLs directly;
it cannot read those URLs after the two legacy buckets become private.
Production read-only inventory found 116 objects across `profile-media` and
`visit-photos`. Counts are objects, not a count of posts or lost records.

A separate branch, `codex/media-compatibility-bridge`, starts at that distributed
source and contains only media resolver/rendering/cache changes. It adds no
Supabase migration, moderation gate, audience change, content rewrite or data
copy. Its signed Simulator build renders legacy profile and visit photos against
the rehearsed cutover. It is not TestFlight accepted. Do not deploy the full
Sprint client first merely because
the media bridge compiles: the full client also expects new server contracts.

Required sequence:

1. Validate the bridge against the current backend contract and against the
   protected-media QA contract. Cover older profile/visit URLs, newer Private
   references, avatars/banners, photo sharing, account switches and relaunch.
2. Distribute compatible native readers only after the separate TestFlight
   authorization. Verify adoption/retirement of incompatible builds before
   the private-bucket cutover. An old anonymous public-object request cannot
   convey the identity needed to authorize Friends or Private media. There is
   no safe universal server redirect that retrofits that identity.
3. Capture a fresh physical database recovery point and a separate recoverable
   Storage-byte backup. A database backup does not back up stored image bytes.
   Prove restoration in isolation; inventory counts alone are insufficient.
4. Capture the read-only content baseline immediately before the change.
   `scripts/check-content-preservation.mjs snapshot receipt.json` requires
   `MUGSHOT_PRESERVATION_DATABASE_URL` explicitly; `verify receipt.json` compares
   original column values and counts, including ownership and audiences, across
   public tables, Auth users/identities and Storage object metadata. Use a
   restricted ignored receipt path. It runs in a read-only repeatable-read
   transaction, never exports rows and refuses to overwrite a baseline.
   It does not replace byte checks or audience/access tests. Concurrent genuine
   writes cause a mismatch requiring investigation, never automatic repair.
5. Rehearse a transition with representative synthetic historical Private,
   Friends and Everyone posts. In addition to row/byte preservation, compare
   actual owner, friend, blocked, stranger and anonymous access before/after.
   Migration `20260914023251` preserves only the exact already-shared revision
   captured at activation. Pending/needs-review remains the real job state;
   no provider approval is fabricated. Edits, rejection, approval and withdrawal
   expire the one-time visibility receipt. New posts receive no receipt.
   Audience, blocking and enforcement checks still apply; Private content is
   excluded. Apply all initial Sprint migrations and receipt capture in ONE
   database transaction so intermediate screening gates cannot hide old posts.
   The isolated replay rehearsed that transaction successfully. Do not use a
   sequence of separately committed migrations for initial activation.
6. Deploy reviewed backend and compatible web readers in the coordinated window
   only after the preceding gates. Verify unchanged original data, byte hashes
   and expected viewer access. Keep writes/activation held if any unexplained
   mismatch occurs. Never reset live, rewrite old URLs, move/delete originals
   or restore public access as an automatic fallback.

Evidence: the preservation guard passed unchanged-data and deliberately
incorrect-fingerprint checks on isolated QA (72 tables). A production baseline
was captured through the read-only MCP connection at
`.codex/production-content-preservation-baseline.json`; the CLI's direct main
branch password was not usable. All 63 hosted SQL contracts now pass after
the reflection contract was restricted to its reserved synthetic fixture IDs.
Production migration head, bucket settings and user content were not changed.

## Non-negotiable invariants

- Never reset, seed, or run behavioral SQL contracts against the linked live
  project.
- Never delete, rewrite, or manufacture existing Joe, Amanda, or other pre-alpha
  content to make a test pass.
- Never edit an applied migration. Repair behavior with a new forward migration.
  If historical metadata must be reconciled, record the exact old/new statement
  hashes and first prove that the metadata repair changes no schema or user row.
- Pin the Supabase CLI version. The current release harness uses `2.109.1`.
- Database migrations land before the client assumes a capability and before an
  Edge Function calls the new RPC.
- External integrations fail closed. Missing APNs, OAuth, scheduler, or signed
  client evidence must disable initiation, not silently emulate success.
- A clean migration replay proves schema reproducibility; it is not a substitute
  for a periodic physical-backup restore drill.

## Routine local verification

Use the no-Simulator-first pyramid:

```bash
./scripts/verify-no-simulator.sh fast
./scripts/verify-no-simulator.sh backend
./scripts/verify-no-simulator.sh full-static
```

These commands never connect to Supabase. `full-static` compiles against the
generic iOS Simulator SDK without booting, installing, or launching Simulator.

## Backend release sequence

1. **Freeze scope.** Review the changed migrations, RPC grants, RLS policies,
   storage policies, Edge Functions, client decoders, and capability gates as one
   contract.
2. **Inventory live read-only.** Record project identity, migration head, table
   counts, deterministic row fingerprints, Storage object count, active Edge
   versions, capability response, backup status, and advisors.
3. **Create a data-less QA branch.** Never copy pre-alpha rows into the destructive
   contract environment. Record the branch ID and hourly cost.
4. **Prove history alignment.** Local-only and remote-only migration counts must
   both be zero before tests. A reset of the disposable branch must be able to
   rebuild from the production history.
5. **Run the complete remote suite.** Install pinned QA dependencies once, then:

   ```bash
   ./scripts/verify-supabase-qa.sh <qa-branch-id>
   ```

   The runner refuses the production project, seeds only `.invalid` fixture
   identities, and executes every SQL file under `supabase/tests`. TLS is
   encrypted; set `MUGSHOT_QA_SSL_CA_PATH` to a trusted CA bundle when strict CA
   verification is required.
6. **Take the live safety snapshot.** Wait for a completed physical backup. Record
   counts and deterministic whole-row fingerprints immediately before deploy.
   For a destructive or high-volume migration, also complete a separate restore
   rehearsal before proceeding.
7. **Dry-run the exact live target.** Confirm the target project identity and that
   the dry run contains only the reviewed forward migrations:

   ```bash
   npx --yes supabase@2.109.1 db push --linked --dry-run
   ```

8. **Deploy database, then workers.** Apply the reviewed migrations once. Deploy
   pinned Edge Function sources only after their RPCs exist. Never place service
   credentials in migration SQL or source control.
9. **Verify live without test mutations.** Require zero migration drift; compare
   post-deploy counts/fingerprints; call the public capability RPC; inspect the
   scheduler, function versions, health logs, and security/performance advisors.
   Validate cleanup functions in a rolled-back transaction when possible.
10. **Close the environment.** Delete the paid QA branch and confirm it no longer
    appears. Record what is live, what remains gated, and the exact evidence.

## Capability and compatibility contract

The client calls `get_backend_capabilities_v1()` before enabling backend-dependent
surfaces. A missing or malformed response is a compatibility failure, not an
empty-data state. Additive capabilities may be introduced in a forward migration;
breaking payload changes require a new RPC/contract version and a client overlap
window.

Do not use capability flags to conceal an unsafe partially deployed feature. The
server must still enforce every permission and lifecycle rule independently of
the client UI.

## Current external gates

- **APNs:** worker version 6, the team-scoped key, both topics, badge-aware v3
  contracts, a dedicated cron credential, and exactly one Vault-backed minute
  schedule are live. Real sandbox and TestFlight delivery/tap acceptance
  remains.
- **Home Workbench:** the three repository migrations dated 2026-08-23/24 are
  live and were covered by the 2026-08-24 protected-data fingerprint closure.
- **Expressive post reactions:** the additive column/RPC/activity contract is
  implemented and hermetically verified. Disposable replay, complete remote
  contracts, live impact inventory, deployment, and read-only post-deploy
  verification remain. Historical `visit_reactions` rows are not a backfill
  source.
- **TestFlight:** client upload and tester assignment remain manual gates after
  Simulator and connected-device acceptance.
- **Auth and destructive flows:** provider, password-defense, and account-
  deletion state must be re-inventoried before a release that changes those
  surfaces; historical audits are evidence, not a substitute for current checks.

## Drift response

If local and live migration histories differ, stop. Do not run `db pull`, edit an
applied file, or mark an arbitrary version repaired until the live statements,
local file, and data impact are understood. Prefer fetching missing historical
migrations exactly, or add a forward compatibility migration. Resume deployment
only after a disposable clean reset and the complete contract suite pass.

If post-deploy counts or fingerprints differ unexpectedly, stop feature rollout,
preserve logs/backups, and identify the exact table and migration. Roll forward
with a reviewed repair; do not reset live or reseed user data.

## Protected-media rollout gate (Sprint 1)

Migration `20260913061308_sprint1_protected_media_reads.sql` changes
`profile-media` and `visit-photos` to private and preserves the private visit
bucket. Historical public URL strings remain stored identifiers, requiring
compatible resolvers in every supported native/web recipient path. Do not apply
this migration to production until that compatibility and the full migration
history pass isolated QA. Existing public downloads/cached copies cannot be
recalled. Read-time signatures last 60 seconds; do not imply instant revocation
of an already issued capability.

The migration adds a caller-bound Storage rule covering current screened
profile/visit references, blocks, Private exclusion, and owner recovery. A
restrictive policy overrides older permissive reads; other buckets retain their
existing policies. Local actual-RLS tests pass. Shared-link server signing also
checks projected author/visit/bucket provenance because privileged signing
bypasses Storage RLS. Full remote service integration remains an acceptance gate.

## Analytics erasure deployment gate

The current migration head adds the service-only account analytics queue.
Deploy it before the updated deletion worker. Keep PostHog erasure disabled
until the scoped credential and disposable-account acceptance are verified;
see [analytics plan](POSTHOG_ANALYTICS_PLAN.md). Pending/attention processor
records intentionally retain the minimum retry identifiers after account
removal. Do not purge them as ordinary completed deletion receipts.

## Shared cafe text deployment

The current head includes displayed cafe names, addresses, city/country and
website URLs in eligible shared-content snapshots. Applying it rebuilds affected
queue snapshots and holds changed revisions for screening without calling an
external provider. Server catalog text corrections invalidate affected visits,
profile favorites, list items and recommendations in the same transaction;
measure fanout on QA before production maintenance. Private-only visits/lists
remain excluded. Direct catalog admission/provenance and its raw read surfaces
remain an open gate; this migration does not certify those surfaces.

The subsequent displayed-visit-text migration includes shared `city_state` and
custom rating/category names in visit screening. It excludes numeric values and
unexpected nested properties and rebuilds only eligible shared visit snapshots.
No private brew fields are added. Existing changed payloads return to pending;
apply and measure this backfill in QA before activation.


## Cafe catalog admission deployment

Deploy `verify-cafe` with JWT verification enabled after migration
`20260913191001`. Configure `APPLE_MAPS_PRIVATE_KEY`, `APPLE_MAPS_KEY_ID`, and
`APPLE_MAPS_TEAM_ID` from restricted server secret storage, and retain the
existing `GOOGLE_PLACES_API_KEY`. Never place these values in client build
settings, logs, PR text or tracked files. Generate five-minute Maps authorization
JWTs with only `server_api` scope.

The endpoint validates the Auth user and live Mugshot account, enforces an
atomic 30-attempt/hour limit and admits only server-fetched fields through a
service-only RPC. Provider errors preserve the unsaved state and use a retry
message; do not fall back to marking caller fields verified. Coordinate native
and PWA activation with this endpoint. Existing unverified cafes are retained
and readable only through their authorized content contexts; there is no bulk
approval or private-content screening step.


The production dashboard showed an available physical backup dated
2026-09-13 12:35:29 UTC. This confirms a restore point exists, not a completed
restore drill, and does not cover Storage object bytes. The rollout must not
delete existing Storage objects.


## Deletion scheduler credential

Set a random server-only `ACCOUNT_DELETION_WORKER_SECRET` and store the same
value in the existing `mugshot_account_deletion_service_role` Vault slot used
by the scheduler. The historical slot name does not require a database service
key. The endpoint uses that dedicated bearer when configured; legacy deployments
retain their service-role fallback. Keep the value out of logs and client builds.
Confirm an actual scheduled HTTP 200 before setting the production scheduled
capability flag. QA scheduled execution initially returned 401 with the legacy
key despite successful interactive Auth deletion; a cron success status alone
only proves that the HTTP request was enqueued.


`delete-account` is explicitly deployed with gateway JWT verification disabled:
its user actions validate the token through Auth, while recovery capabilities
and the dedicated worker bearer must also function without a user JWT. This
matches the handler's existing authentication design. The live QA worker now
returns HTTP 200 with its configured secret and 401 with an unrelated bearer.


## Provider staging and paid QA closure — September 13

The production OpenAI key and three Apple Maps settings are stored in Supabase
secrets. Their digests match the approved local credentials. Both
`SCREENING_ENABLED` and `SCREENING_NO_TRAINING_VERIFIED` are explicitly false,
verified by digest, so this is credential staging only. Activation still requires
fresh no-training settings verification, disclosures and accepted runtime gates.
No production migration or new function was deployed at this checkpoint.

The catalog QA branch was deleted and absence verified; only main remains.
Provider deletion polling does not require a paid QA database. A new QA
environment may be created only for active acceptance, then must be removed.


## Native QA closure — September 13

A subsequent data-less native QA branch replayed all 162 migrations and passed
all 62 contracts together. This supersedes the earlier combined-run limitation.
Native sign-in, session restoration and profile setup passed against it. The
new profile was screened in one attempt; its readable route and default absent
Friends-profile consent were verified through live endpoints. The branch was
deleted after the Mac locked again; a fresh inventory contains only main.
Production remains at its original migration head with screening disabled.


### Journey QA permission contract — September 13

The native Saved request exposed a missing explicit grant on
`public.user_cafe_states` in a clean replay. The new migration grants authenticated
SELECT/INSERT/UPDATE/DELETE with owner-only RLS and explicit UPDATE WITH CHECK;
anonymous access remains revoked. Cafe-reference admission is unchanged. Both
the focused Saved owner/isolation test and cafe admission regression passed on
isolated QA, followed by native saving and Favorites display. All 163 migrations
were present on that branch before deletion; only main remains after cleanup.
No new production migration is claimed.

## September 14 preservation verification

The bridge allows historical public profile/visit URLs only when the server
returns the exact missing `can_read_protected_media_v1` API response
(`PGRST202`). Authorization denials, other server errors and network errors
never enable this fallback. Durable Private references always require signing.
The protected backend checks the viewer before issuing a 60-second URL.

Read-only production checks found all 72 original-table fingerprints unchanged.
The encrypted local Storage backup covers 331 objects / 439,219,602 bytes;
every object was read back, decrypted in isolation and compared byte-for-byte.
Keep both the ignored encrypted directory and its separate key. This proves
Storage-byte recoverability, not a physical database restore drill.

The current-contract QA replica included production's nullable `users.website_url`
column, which exists outside its recorded 127 migrations. Both current and
protected QA passed 30 photo/audience cases plus profile authorization checks.
The same access matrix passed after atomic cutover with all eight pre-existing
shared jobs still pending. No synthetic approval was used for that transition.
The fresh protected fixture matrix separately uses synthetic approvals only.

The cutover fingerprint guard intentionally stopped on `activity_events`:
migration `20260913042008` replaces notification copy and removes `list_title`
metadata. All other 71 original tables matched, including posts, owners,
audiences, Auth identities and Storage metadata. This is NOT an unexplained
post loss and NOT a full 72-table cutover pass. Production activation remains
held until that notification-copy transformation is explicitly reconciled with
the preservation requirement and the database recovery gate is satisfied.
No production migration or bucket change occurred during this verification.

## Staged production owner test — September 14

The owner clarified rollout scope: install the new dev build against real
production data for personal validation; keep TestFlight and App Store review
on hold. The production database now has all 164 migrations and ten updated
Sprint functions. Original bucket visibility is deliberately retained during
this stage; this is not completion of legacy public-photo protection.

`scripts/build-preserving-sprint1-rollout.mjs` generates the exact reviewed
37-migration SQL bundle from the 127-migration source head. It never connects to
a database itself. The artifact runs a single transaction, locks original tables
against concurrent writes, fingerprints every original column, captures existing
notification copy and bucket visibility, applies the migrations and their original
history statements, restores notification copy/visibility, and aborts the entire
transaction if any original table differs. Locks have a five-second timeout.
Never replay the generated artifact after the source head has advanced.

An isolated hosted rehearsal proved all 72 original tables unchanged and passed
30 photo/audience checks plus profile checks, with eight historical jobs honestly
pending. The identical production artifact committed with 72/72 preservation
checks passing. Original notification titles/bodies/list metadata were retained;
future notification generation follows the new generic-copy implementation.
Do not later replace historical notification copy without a separate decision.

Before deployment, encrypted database data was restored into isolated PostgreSQL:
72 tables, 6,036 rows, original column types and every row fingerprint matched.
This is a logical data-recovery proof, not a physical backup or a full schema/
RLS/index restoration. The previously verified provider physical backup remains
additional recovery evidence. Production Edge Function source was also downloaded
into the ignored backup folder. Keep these backups and their separate keys.

OpenAI feedback/evaluation/input-output sharing was freshly verified Disabled.
The deployed privacy disclosure explicitly describes screening and no training.
Screening and its schedule are enabled; live jobs have begun receiving approval.
Private visits are excluded. The creator account `joe` has founder-review access.
Dedicated production worker secrets are stored server-side and in Vault; the
actual scheduled deletion response returned HTTP 200 before its scheduled flag
was enabled. PostHog erasure stays disabled pending its prior verification;
Apple revocation remains an accepted unverified boundary.

Marketing PR 18 and PWA PR 13 passed checks, were merged, and local main branches
were synchronized. Live privacy, readable-profile and PWA routes return HTTP 200.
The production iPhone dev build installed and launched; Device Hub showed real
feed photos. Analytics is disabled for this dev build. No TestFlight action.
All disposable QA branches were deleted and only production remained in inventory.
