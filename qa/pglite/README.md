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

### Home hosted integration

Use only an explicitly approved, data-free branch. These tools refuse the known
production reference and verify the branch identity. CLI credentials stay in
process memory; never redirect branch configuration to a committed file.

```bash
node qa/pglite/prepare-home-branch.mjs <branch-id> <project-ref>
node qa/pglite/check-home-remote.mjs <branch-id> <project-ref>
node qa/pglite/run-home-native.mjs <branch-id> <project-ref> <prepared-xctestrun> <simulator-id>
```

Preparation replays missing migrations in one transaction, seeds only random
operational placeholders for historical scheduler prerequisites, and disables
every schedule before commit. It is not a production deployment tool. Session
pooler port 5432 avoids the direct database endpoint's IPv6 dependency. The Home
helpers use encrypted TLS without certificate verification, like the default
legacy QA runner; use a trusted network and disposable credentials.

The HTTP and native runners create synthetic `.invalid` Auth identities and test
content in this disposable branch. They never email real users or copy production
secrets. The native runner passes only public client configuration and synthetic
user credentials through test-process environment; it never passes service-role
or database credentials into the app. It runs the hosted Swift transport test and
focused Home model/store tests. Default Swift runs skip hosted tests unless
explicit QA configuration is present. The unsigned hosted test uses isolated
in-memory Auth storage, not the app host's Keychain session. Keep the branch only while acceptance is
active, then delete it to remove synthetic data and stop branch charges.


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
