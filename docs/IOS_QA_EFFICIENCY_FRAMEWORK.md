# MugShot iOS QA Efficiency Framework

Date: 2026-07-22

## Outcome

MugShot uses a no-Simulator-first verification loop. Deterministic checks find most defects cheaply; one prepared Simulator or human-QA session validates the small set of behaviors that require a live iOS runtime. The intended cadence is:

```text
inspect -> static/pure/backend checks -> generic compile -> integration review
        -> one final runtime acceptance session -> batch any follow-up fixes
```

Simulator is an acceptance environment, not the default debugger.

## Repository commands

Run these from the repository root:

```bash
./scripts/verify-no-simulator.sh fast
./scripts/verify-no-simulator.sh backend
./scripts/verify-no-simulator.sh full-static
```

The modes are cumulative:

- `fast`: repository preflight, unstaged/staged/untracked text checks, migration filename integrity, and the required ASCII `cafe`/`cafes` spelling check.
- `backend`: `fast`, optional local PostgreSQL syntax parsing through Python `pglast`, offline Deno formatting/type/test checks when Deno is installed and dependencies are cached, and the committed in-memory PostgreSQL behavior suite when its pinned Node dependency is installed. It never invokes the Supabase CLI or a network database connection.
- `full-static`: `backend` plus a Debug `build-for-testing` compile against `generic/platform=iOS Simulator`. This compiles the app and test bundles with the Simulator SDK but does not boot, install, launch, or run tests on a Simulator.

The backend and full-static modes require the repository-pinned Deno/PGlite toolchain; missing required tools fail instead of producing a false-green result. Local `pglast` parsing remains optional and is reported as `SKIP`, never as a pass. Package versions are locked to the committed lockfiles and package updates are disabled. Xcode may still need to retrieve an exactly pinned dependency if it is not already present in the local package cache; that is package setup, not a Supabase connection.

The compile uses quiet output so routine success does not consume a large transcript. Failures still surface compiler diagnostics; rerun only the failed layer while fixing it.

## Testing pyramid

### 1. Inspection and repository invariants — every change

- Review the scoped diff, including generated project or entitlement changes.
- Run whitespace/conflict-marker checks.
- Confirm user-facing copy uses `cafe` and `cafes`.
- Confirm migration filenames are ordered and unique.
- Inspect all call sites when a shared model, projection, permission, or navigation route changes.

This layer catches accidental scope, merge debris, stale names, and inconsistent contracts without a build.

### 2. Static and compile-only checks — normal development loop

- Parse SQL locally when `pglast` is available.
- Format-check changed Edge Functions and type-check every function through Deno's cached-only, no-run test loader without downloading dependencies.
- Compile the app and test bundles once after a coherent batch using the generic Simulator destination.
- Treat compiler errors as compile problems; do not boot Simulator to diagnose them.

The generic destination uses the Simulator SDK only. It is not a runtime test and does not validate navigation, persistence, system permission prompts, or rendering.

### 3. Pure and hermetic behavior tests — logic and backend discovery

- Prefer pure Swift tests for reducers, formatters, policy decisions, state machines, payload decoding, idempotency, and account scoping.
- Prefer Deno tests for Edge Function decision logic and transport classification.
- Run SQL contract and RLS tests only in a disposable local PostgreSQL/Supabase environment or a transactionally isolated ephemeral harness.
- Cover the success path and the highest-risk denial, retry, duplicate, stale-state, and cleanup paths.

The current app unit target is Simulator-hosted because it imports the iOS app module. Queue that suite for the consolidated runtime checkpoint. As code is naturally refactored, moving pure domain logic into a host-testable Swift package would move more coverage below the runtime line; that is an optimization, not a prerequisite for using this framework now.

The focused repository-owned PGlite harness in `qa/pglite` exercises account deletion, collaborative-list consent and expiry, device-registration limits, and delivery leases against a new in-memory database per process. Install its exact pinned PGlite and Deno dependencies once with `npm ci --prefix qa/pglite --ignore-scripts`; the normal backend command then runs the database suite and offline Edge Function checks automatically. PGlite does not emulate every Supabase service or extension, so the broader SQL/RLS files in `supabase/tests` still require a disposable local Supabase stack before deployment. Never substitute the linked project.

### 4. Cross-feature integration review — before acceptance

- Trace write -> projection -> cache -> UI for changed data.
- Trace permission changes across Feed, post detail, Map, Saved, Journal, profile, notifications, search, and deep links.
- Verify that blocking, reporting, deletion, privacy, and invitation changes propagate to every relevant projection.
- Verify Codable payload compatibility and empty/error/failure states through fixtures or focused tests.
- Resolve all known compile, parser, contract, and integration-review findings before runtime work.

### 5. One final runtime acceptance session — after the pyramid is green

Prepare the account states and checklist first. Boot one standard Simulator, run the consolidated unit suite once if needed, build/install/launch once, and walk the matrix below without stopping to repair each issue. A human may perform the taps while Codex records evidence and inspects logs. This is often faster and more reliable for system UI, gestures, scrolling, and visual judgment.

If the session finds a bug, capture the exact state, expected result, observed result, and logs if relevant. Continue through every unblocked row. Fix the findings together after the session, rerun the no-Simulator checks, then schedule another batched acceptance round only when the batch is coherent.

## Change-to-check matrix

| Change type | Primary discovery checks | Add before acceptance | Runtime-only gate |
| --- | --- | --- | --- |
| Documentation, copy, spacing, color, icon | Diff review; `fast`; generic compile if app resources changed | None unless shared UI code changed | None by default |
| Swift model, formatter, policy, or state machine | Focused pure test; `full-static`; decode/edge fixtures | Inspect all consumers and persistence compatibility | Consolidated app unit suite only if still app-target coupled |
| Navigation, sheet, deep link, or cross-tab state | `full-static`; route/state tests; call-site trace | Loading, cancellation, stale destination, and signed-out cases | One matrix walkthrough |
| Local persistence, drafts, caches, account scoping | Pure storage tests with isolated stores; `full-static` | Relaunch/account-switch reasoning and migration fixtures | One relaunch/account-switch walkthrough |
| Edge Function | Deno format, cached-only type check, focused Deno tests | Auth, timeout, retry, idempotency, and redacted-log cases | Physical device only if APNs/camera or another device service is involved |
| SQL migration, RPC, RLS, trigger | SQL parser; disposable database contract/security tests | Upgrade/backfill, rollback boundary, concurrency, and projection trace | App smoke only after deployment to a dedicated QA target |
| Feed, Map, search, Saved, Journal, profile projection | Backend contract tests; payload fixtures; `full-static` | Cross-surface privacy/block/deletion consistency review | One prepared read-only discovery pass |
| Upload, media, Photos picker, location, notifications | Pure coordinator/error tests; `full-static`; backend contract tests | Permission denied/revoked, retry, duplicate, cleanup, and offline cases | One planned Simulator pass; physical device where Simulator is not authoritative |
| Destructive account, post, report, block, invitation, or collaboration flow | State-machine tests; RLS/RPC tests in disposable DB; idempotency and recovery fixtures | Audit downstream projections and irreversible boundaries | Dedicated disposable QA identities only; never real production-like records |
| Signing, entitlements, build settings, deployment target | Diff review; generic Debug compile; targeted Release archive/build when justified | Provisioning and environment matrix | One signed physical-device/distribution gate |

## Final Simulator or human-QA acceptance matrix

The sprint owner should trim this to affected rows, but a completed alpha trust/social sprint should run the full matrix once. Use dedicated QA identities where a row mutates state. Preserve Log a Sip and Log a Cafe behavior; exercise only connection points unless a critical regression is suspected.

| Area | Prepared state | One-pass acceptance evidence |
| --- | --- | --- |
| Launch, auth, onboarding | Signed-out state plus an existing signed-in QA account | Correct onboarding/guest gate, sign-in, session restore, account switch or sign-out, no identity/data bleed |
| Global navigation | Account with content in every main area | Each tab opens once; back, sheet dismissal, deep link, scroll restoration, loading, empty, and error routing remain coherent |
| Map and cafe discovery | Location allowed and denied; known nearby cafes | Search, filters, pins, location banner, cafe detail, rating data, save state, and navigation agree |
| Feed and discovery | Own, friend, public, blocked, and unavailable-account fixtures | Your Mix/Friends/Everyone membership, counts, pagination/scrolling, search, hidden content, and detail navigation agree |
| MugShot post detail | Own, friend, public, carousel, sparse, and unavailable-related-user posts | Hierarchy, scoring, cafe/drink data, captions, likes/comments, Taste Snapshot, Visit Details, Conversation, tags, and permissions agree |
| Safety and management | Disposable posts and QA identities only | Edit/delete confirmation, report, block, failure/retry, and downstream removal/restoration behave coherently |
| Shared MugShot | Pending, accepted, declined, left, cancelled, unavailable inviter/member | Ordinary tags need no consent; shared participation does; every lifecycle action and identity fallback is understandable |
| Saved and collaborative lists | Favorites, Want to Try, custom list, pending collaborator, accepted collaborator | Filters, list detail, invitation consent, roles, leave/cancel, unavailable owner, empty states, and cafe navigation agree |
| Journal | Entries, drafts, reflections, recent sips, multiple cafes | Counts/averages, draft continuity, Passport/Footprint navigation, empty/error states, and source post consistency agree |
| Profile and Taste Passport | Own profile plus Everyone/Friends/Private visibility fixtures | Public-by-default Passport, visibility changes, personal content, public/private profile state, edit profile, and settings agree |
| Activity and notifications | Read/unread and deep-link fixtures | Activity count, read state, invitation/moderation destination, unavailable content fallback, and cold/warm deep-link routing agree |
| Permissions, network, and accessibility | Permission denied; offline or network-disabled state; larger text/VoiceOver/Reduce Motion | Recovery copy, no dead ends, focus/labels, contrast, dynamic layout, reduced motion, and retry behavior are usable |
| Account lifecycle | Separate disposable password and Apple QA identities only | Export/request/delete messaging, fresh-session verification, cancel/wrong-account/expiry handling, progress/failure state, sign-out boundary, recovery after a lost response, and preserved unrelated-account data agree |

For APNs delivery and taps, camera capture, production signing, performance, or distribution, schedule one physical-device gate. A Simulator result is not authoritative for those capabilities.

## Failure triage rules

1. **Static/parser failure:** fix locally and rerun that same check. Do not escalate to Simulator.
2. **Compile failure:** fix the first actionable compiler error, rebuild once after the batch, and remain at compile-only scope.
3. **Pure/backend contract failure:** reduce to the smallest deterministic fixture, fix the contract or implementation, run the focused test, then run the containing backend batch. Do not validate against the linked Supabase project.
4. **Integration-review inconsistency:** enumerate every consumer and repair the projection/permission contract as one batch before compiling again.
5. **Runtime-only failure:** record the account, data state, steps, expected/actual result, screenshot, and relevant log; continue the remaining unblocked matrix; repair after the session.
6. **Automation/tool limitation:** switch once to human QA for that matrix row. Do not spend repeated rounds forcing brittle coordinate or system-UI automation.
7. **Environment or fixture failure:** do not call it a product bug. Repair or replace the disposable fixture, then resume the matrix.
8. **Potential production-like data impact:** stop the mutation immediately. No test result justifies risking preserved user data.

Severity does not change the loop. A blocker may stop dependent matrix rows, but unrelated rows should still be collected in the same acceptance session when safe.

## Production-like Supabase safety

The repository contains Supabase link metadata and the available backend is production-like pre-alpha data. Treat it as preserved user data.

The default verification contract is:

- Remote Supabase is read-only unless the user explicitly authorizes a narrowly scoped mutation against named disposable records.
- Never run `supabase db reset`, `supabase db push`, `supabase migration up`, `supabase functions deploy`, cleanup SQL, seed scripts, or account deletion as part of routine QA.
- Never infer a safe target from `supabase/.temp`, an environment variable, a local config file, or an authenticated CLI session.
- Never run SQL behavior/security tests through a connection string for the linked project.
- Use a disposable local/ephemeral database for migrations, RLS, RPC, triggers, backfills, concurrency, and destructive tests.
- Use dedicated QA identities and uniquely named disposable records for runtime mutation journeys. Do not report, block, edit, delete, invite, or transfer ownership involving real pre-alpha accounts or posts.
- If a dedicated QA backend is unavailable, use hermetic backend evidence plus a read-only human acceptance pass and explicitly defer the mutating remote row.
- Before any future deployment, review the migration set, backup/restore posture, target project identity, dry-run evidence, and rollback boundary as a separate operational gate.

`verify-no-simulator.sh` enforces the safest boundary by never invoking Supabase, `psql`, Simulator control, app launch, or UI-test commands. Deno checks use a frozen existing lockfile or disable lockfile discovery, so verification does not create or rewrite dependency locks.

## Evidence and handoff

Report concise, exact evidence:

- verification tier and mode;
- commands that passed;
- checks skipped and the missing tool or safe harness;
- whether Simulator or a physical device was intentionally not used;
- whether any Supabase environment was touched (normally: none);
- runtime matrix rows completed, deferred, or blocked;
- one grouped list of failures from the acceptance session.

Do not call static SQL parsing a migration test, a generic build a runtime test, or read-only app viewing proof that destructive flows are safe.
