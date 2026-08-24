---
document_type: living
status: current
last_verified: 2026-08-24
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
`20260824165630_harden_visit_grants_and_share_contract.sql`. Repository head and live
deployment state are separate facts; the live project reference is recorded in
the existing Supabase link and QA scripts refuse that production reference.

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

- **APNs:** the worker, team-scoped key, both topics, and production schedule are
  configured on the v2 production path. Badge-aware v3 contracts and the
  canonical Vault-backed schedule passed data-less disposable QA and still
  require live release. Real sandbox and TestFlight delivery/tap acceptance
  remains.
- **Home Workbench:** three repository migrations dated 2026-08-23/24 require
  the live snapshot, dry-run, deployment, and drift closure sequence before
  production reliance; the disposable-branch contract gate passed on
  2026-08-24.
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
