---
document_type: living
status: current
last_verified: 2026-09-13
---

# Mugshot Supabase release workflow

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
