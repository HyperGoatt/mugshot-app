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
`20260913152645_sprint1_transfer_screening_receipt.sql`. Sprint 1 migrations
are not deployed to production; follow [Sprint 1 delivery](SPRINT_1_TRACKER.md) for activation
and acceptance gates. Read-only inventory on 2026-09-13 found 127 production
migrations, most recently `20260826143102_profile_editorial_atlas.sql`.
`20260825030917_post_reactions.sql` and the new Sprint 1 migrations are absent
from production. Only the default branch exists; no disposable QA branch was
present. The live project reference is recorded in the existing Supabase link,
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
configuration. The check branch was deleted and absence verified. Full replay
with those prerequisites and complete remote acceptance remain open.
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
