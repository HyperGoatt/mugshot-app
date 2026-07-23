# Alpha Account Deletion V3 Deployment Gate

Status: database foundation and `delete-account` v4 deployed on 2026-07-22;
new deletion initiation remains intentionally disabled.

The migrations and recovery worker are live so the contract cannot drift behind
the client. The three activation prerequisites remain false because production
does not yet have a reviewed PostgREST live-session hook, a durable deletion
drain schedule, or signed-client fresh-session acceptance evidence. This is the
required fail-closed state: the app cannot begin a new deletion, while the
worker remains available to recover a prepared job if one ever exists.

This gate exists because the current Supabase project contains valuable pre-alpha posts and social data. Do not exercise deletion against an existing owner. Use a newly created disposable account only after every gate below passes.

## What V3 guarantees

- One active deletion job per Auth subject.
- A live initiating session can create a five-minute deletion challenge, but cannot authorize it.
- Authorization requires a different, newly created Auth session for the same subject with eligible fresh AMR evidence after the challenge. The resulting authorization expires within two minutes and is single-use.
- Preparation freezes an immutable collaboration plan without changing user-visible content.
- Storage cleanup contains only exact object IDs and paths whose owner metadata matches the subject. Prefix listing or recursive prefix deletion is not part of V3.
- A 256-bit client capability can resume the same request after Auth deletion or a lost HTTP response. Supabase stores only SHA-256 hashes of that capability.
- Completed jobs discard subject UUIDs, session identifiers, Storage paths, and collaboration manifests. A fresh minimized receipt is retained for 400 days, then becomes a capability-bound `expired_completed` tombstone. It remains recoverable until the device uses that capability to acknowledge successful local cleanup; a 30-day lost-response grace period then begins before the tombstone is purged.
- Auth sessions are revoked before identity deletion. The Data API hook rejects deleted, deleting, or revoked-session JWTs.
- A scheduled service-role drain retries incomplete jobs one at a time with renewable, mutation-fenced leases and bounded backoff.

## Required migration order

Apply and validate the alpha migrations in timestamp order. Account deletion V3 specifically depends on:

1. `20260722024654_account_data_lifecycle_v2.sql`
2. `20260722100000_alpha_moderation_integrity_hardening.sql`
3. `20260722102000_alpha_recipe_collaboration_hardening.sql`
4. `20260722103000_alpha_account_deletion_hardening.sql`
5. `20260722105000_alpha_account_deletion_completion_ack.sql`

Before applying V3, take a project backup and inspect `private.account_deletion_jobs`. The migration intentionally fails if more than one non-completed job exists for the same subject; an operator must review that ambiguity rather than auto-merge or delete receipts.

Deployment record: all five migrations above are live, the isolated QA replay
and account lifecycle contracts passed, and the preserved pre-alpha row counts
were unchanged. No account deletion was exercised against a real owner.

## PostgREST live-session gate

The migration creates `public.enforce_mugshot_live_session_v3()` but deliberately does not overwrite `pgrst.db_pre_request`.

1. Inspect the database and role settings for an existing pre-request function.
2. If one exists, create a wrapper that calls the existing function and `public.enforce_mugshot_live_session_v3()`; do not replace the existing control.
3. Configure `pgrst.db_pre_request` for the `authenticator` role to the reviewed single function or wrapper.
4. reload PostgREST configuration.
5. Prove that a live session succeeds, a revoked `session_id` receives 401, a deleted subject receives 401, and an active deletion job receives 401.

This hook covers the Data API only. V3 separately enforces Storage writes and deletes with `guard_account_storage_write_v3`; social projections and mutations use `private.is_live_account_as` from the moderation hardening migration.

Set the Edge Function secret `ACCOUNT_DELETION_LIVE_SESSION_GATE=true` only after those checks pass.

Current production state: `pgrst.db_pre_request` is not configured for `anon`,
`authenticated`, or `authenticator`; `ACCOUNT_DELETION_LIVE_SESSION_GATE` must
therefore remain false.

## Fresh-session client gate

The backend and iOS client must be deployed in a fail-closed order:

1. Keep `ACCOUNT_DELETION_STEP_UP_CLIENT_READY=false` while deploying the migration and Edge Function.
2. Confirm the deployed iOS build performs `begin_delete_step_up_v3` with the initiating session.
3. Confirm password and Apple verification each create a different same-subject Auth session after the challenge.
4. Confirm that new session performs `authorize_delete_step_up_v3`, then sends the returned `challengeId` and `authorizationSecret` to `delete_v3` on the same session.
5. Prove wrong-subject, same-session refresh, stale AMR, expired challenge, expired authorization, and replay requests all fail before preparation.
6. Set `ACCOUNT_DELETION_STEP_UP_CLIENT_READY=true` only after that client build is available to the alpha cohort.

Supabase `reauthenticate()` for password-change nonces is not this protocol and must not be substituted for the fresh-session challenge.

## Scheduled drain

Deploy the pinned `delete-account` Edge Function, then configure a durable scheduler to POST at least once every five minutes with:

```json
{
  "action": "drain_deletions_v3",
  "protocolVersion": 3
}
```

The request must use the service-role key as its Bearer token. Keep that secret in the platform secret store; do not commit it or embed it in SQL text. Confirm scheduled invocation logs and one successful empty drain before setting `ACCOUNT_DELETION_WORKER_SCHEDULED=true`.

The iOS client refuses to initiate V3 deletion unless the live-session gate, fresh-session client gate, and scheduled-worker gate are all true. Recovery and worker actions remain available so an already-prepared job can finish if a flag is later removed.

Current production state: `delete-account` v4 is active, but no durable
`drain_deletions_v3` schedule is configured. Keep
`ACCOUNT_DELETION_WORKER_SCHEDULED=false` until an empty scheduled invocation is
visible in logs.

## Read-only Storage preflight

For each disposable test owner, review every object where either the first path segment or Storage owner metadata names that owner. V3 correctly blocks deletion if any object:

- is outside `visit-photos`, `visit-photos-private`, or `profile-media`;
- has a foreign or missing owner;
- is owned by the subject outside the subject’s first path segment; or
- contains an empty, dot, dot-dot, backslash, or control-character path segment.

Resolve unexpected metadata as a separate, backed-up data repair. Do not weaken validation and do not use a prefix sweep.

## Disposable-account verification

Run the flow only with a new account created for this check:

1. Add public and private posts, profile media, a collaborative cafe list, a pending invitation, an accepted collaborator, and a shared MugShot.
2. Begin the challenge with one live session. Confirm a refresh of that same session cannot authorize it and no job is created.
3. Create a fresh password session after the challenge. Confirm a wrong account is rejected and discarded, while the same subject can authorize exactly once.
4. Repeat with a separate disposable Sign in with Apple account.
5. Confirm an expired challenge, expired authorization, replayed authorization, and authorization used from another session all fail before preparation.
6. Interrupt the client after `delete_v3` reaches the Edge Function. Relaunch and prove the Keychain capability resumes the same request.
7. Advance the disposable environment beyond the detailed-receipt retention boundary and prove the capability receives an `expired_completed` proof instead of `not_found`.
8. Confirm Auth and public identity absence before local account-scoped data is purged.
9. Confirm the frozen successor receives ownership only if still accepted, live, and not suspended. Otherwise confirm the owner-only object is deleted without changing attribution.
10. Confirm only the exact manifest objects are removed. Add a deliberately foreign-prefix fixture and verify the flow blocks without deleting it.
11. Confirm the final receipt has empty manifests, a null subject and session ID, and a non-null redaction timestamp.
12. Confirm a reclaimed worker rejects the stale lease token and only the current lease can mutate the job.
13. Confirm the revoked access token cannot use the Data API or mutate/delete Storage.
14. After local account-scoped cleanup succeeds, confirm `acknowledge_delete_v3` accepts only the matching recovery capability, starts a 30-day final retention window, survives an ambiguous acknowledgement retry, and is purged only after that grace period.

## Activation and rollback

Keep all three capability flags false until migrations, the composed PostgREST hook, fresh-session iOS client, Edge deployment, scheduler, and disposable-account verification are green. Turning any initiation prerequisite false immediately stops new iOS deletion requests without disabling recovery of an existing job.

Do not roll back by deleting V3 job rows or restoring Auth identities. If the worker is unhealthy, leave jobs durable, turn off initiation flags, preserve receipts, and repair the worker or database function forward.
