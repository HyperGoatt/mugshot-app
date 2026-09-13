# Hermetic PostgreSQL contracts

These focused checks apply selected MugShot migration sections to disposable,
in-memory PostgreSQL databases provided by PGlite. They exercise high-risk
behavior that is expensive or unreliable to discover through iOS Simulator:

- account-deletion ownership transfer, recovery, and lifecycle fencing;
- collaborative cafe-list consent, enforcement, legacy expiry, lifecycle
  Activity, and retry-safe ownership transfer;
- notification-device churn and fanout limits;
- push-delivery lease fencing and retry classification.

They do not read Supabase configuration, open a network connection, invoke the
Supabase CLI, or use production-like data. Each process starts from an empty
database and exits after its assertions. The minimal bootstrap schemas are
deliberately limited to the dependencies of the contract under test.

Install the pinned PGlite and Deno runtimes once:

```bash
npm ci --prefix qa/pglite --ignore-scripts
```

Run the suite:

```bash
npm test --prefix qa/pglite
```

This suite supplements SQL parsing and the transaction-isolated SQL contracts
in `supabase/tests`; it is not a substitute for applying the full migration
chain to a disposable local Supabase stack before deployment. The standard
`scripts/verify-no-simulator.sh backend` command runs this suite and the
offline Edge Function checks automatically after the pinned dependencies are
present.

## Disposable Supabase branch contracts

For a backend release, run the complete migration/RLS/RPC suite against a
data-less Supabase branch after confirming its branch ID:

```bash
./scripts/verify-supabase-qa.sh <qa-branch-id>
```

The wrapper pins Supabase CLI `2.109.1`, requires zero local/remote migration
drift, refuses MugShot's production project reference, and seeds only synthetic
`.invalid` identities before executing every SQL file in `supabase/tests`.
Set `MUGSHOT_QA_SSL_CA_PATH` to a trusted CA bundle when strict certificate
verification is required. Delete the paid branch after recording the result.


### Hosted QA fixture admission and schedules

The remote runner sets the test-only `mugshot.qa_contract=isolated` setting and
refuses to seed when any scheduled job is active. Schedule contracts require
inactive jobs in this mode while continuing to require their exact schedules,
commands and secret references. Outside isolated mode, they require active jobs.
This setting is used only by tests and does not authorize application actions.

The four reserved `.invalid` profiles explicitly accept consent version 1. Their
base shared fixture revisions receive simulated unflagged screening completion
through the real finish RPC; the Private fixture stays outside the queue. This
makes downstream social contracts start from admitted content. Later test
inserts/edits are not automatically approved, and screening tests still exercise
pending/rejected/stale states explicitly. No fixture content is sent to OpenAI.


`fixture_screening_helpers.sql` installs a connection-local `pg_temp` helper
that simulates completion only for exact reserved `.invalid` owners. Tests call
it explicitly after creating or changing shared fixtures. It refuses missing
queue entries, other owners, unexpected review states, and non-isolated mode;
there is no persistent helper, auto-approval trigger, or provider call.
