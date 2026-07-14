# Discovery and Social Expansion — Bug and Security Log

Date: 2026-07-12
Branch: `codex/discovery-social-expansion`
Base: `1b91802b84e61f7d673a84d6031ddc61b0316689`

## DS-001 — Live pagination migration timestamp differed from brief

- Severity: Medium (migration integrity)
- Reproduction: Compare the brief's `20260712210213_optimize_social_pagination` with `supabase_migrations.schema_migrations`.
- Expected: The named live migration and local filename agree.
- Actual: Live history records `20260712211408_optimize_social_pagination`.
- Evidence: Live migration list and recorded statement history.
- Root cause: The discarded attempt applied a later regenerated migration version.
- Resolution: Reconstructed the local migration as `20260712211408_optimize_social_pagination.sql` directly from live statement history. No migration was replayed.
- Status: Fixed and verified by `migration_integrity.sql`.

## DS-002 — Legacy push trigger remained enabled

- Severity: High (deferred privileged/network path)
- Reproduction: Inspect `pg_trigger` for `public.notifications.on_notification_insert` after the original quarantine migration.
- Expected: A deferred push path cannot execute or be called by client roles.
- Actual: Function execute grants were revoked, but the table trigger remained enabled; the legacy function also had a mutable search path and old device policies.
- Evidence: Catalog audit and Supabase security/performance advisors.
- Root cause: The earlier quarantine addressed RPC reachability, not trigger execution and device-table access.
- Resolution: Disabled the trigger, revoked all client function/table privileges, removed device policies, and fixed the function search path. The extension remains installed because moving `pg_net` is an unrelated destructive platform operation.
- Status: Fixed. Integrity test confirms disabled trigger and no client grants.

## DS-003 — Initial RLS test counted unrelated production relationships

- Severity: Low (test defect; no product impact)
- Reproduction: Run the first transactional suite against accounts that already have unrelated requests.
- Expected: The idempotency assertion considers only Alice/Bob/Carol test rows.
- Actual: It counted all rows visible to the current test actor and raised `repeated request was not idempotent`.
- Evidence: The rolled-back Postgres error and revised scoped assertion.
- Root cause: Test predicates were not limited to the selected three-account set.
- Resolution: Scope request and friendship assertions to the transaction's three IDs.
- Status: Fixed; suite returns `phase1_social_rls_passed`.

## DS-004 — Direct comment insert could not guarantee durable validated mentions

- Severity: High (authorization/integrity)
- Reproduction: Insert comment text containing arbitrary `@username` values directly into `comments`.
- Expected: Mention targets are durable, unblocked, visible, and authorized to see the visit.
- Actual: Legacy comments stored text only and had no durable mention relationship.
- Evidence: Pre-migration schema lacked `comment_mentions` and a caller-bound comment RPC.
- Root cause: Mentions were previously presentation-only parsing.
- Resolution: Added `comment_mentions`, one-level reply trigger, caller-bound `create_comment`, visibility validation for every mention target, and removed direct authenticated comment inserts.
- Status: Fixed; covered by SQL and Swift tests.

## DS-005 — Simulator sessions contained stale refresh tokens

- Severity: Low (test-environment state)
- Reproduction: Install/launch the app with the reused ignored publishable configuration on iPhone 17 or iPhone 16e.
- Expected: A valid prior session opens the signed-in app, or no session opens sign-in.
- Actual: Supabase Auth returns `refresh_token_not_found`; the app safely clears the session and opens sign-in.
- Evidence: Auth/API logs show two HTTP 400 refresh attempts; Simulator snapshots show the sign-in/create-account surface.
- Root cause: The Simulator keychain contains expired/deleted session material.
- Resolution: App behavior is correct. Three temporary, confirmed test identities were created directly in the live Auth schema without sending email, used only for the regression matrix, and deleted with all cascaded data after verification.
- Status: Resolved. Signed-in launch, relaunch/session restoration, search, request/accept, block/unblock, feed, discovery, comments, mentions, report, share, saved-state, and add-visit validation were exercised on the requested Simulators.

## DS-006 — Friends feed selected all friend-visible community posts

- Severity: High (privacy/personalization boundary)
- Reproduction: Sign in as a new account with one friend who has no visits, then select Friends.
- Expected: The feed is empty because neither side of the confirmed friendship has a visible visit.
- Actual: The client queried every visit whose visibility was `friends` or `everyone`, regardless of author relationship.
- Evidence: iPhone 16e initially displayed established community posts; the same live account returned the empty state after the fix.
- Root cause: The new ranked RPC correctly implemented friendship filtering, but the client retained the legacy direct-table path for non-ranked scopes.
- Resolution: All three scopes now use `ranked_feed`, passing `friends`, `everyone`, or `ranked`; the caller-bound RPC applies `confirmed_friends` and mutual-block visibility before hydration.
- Status: Fixed and verified in Simulator. Friends showed `0 sips` and `No friend-visible visits yet`; Everyone still returned public visits.

## DS-007 — Blocked management row could not unblock

- Severity: Medium (safety-control usability)
- Reproduction: Block a friend, open People > Blocked, and select the blocked row.
- Expected: An Unblock action remains available even though the blocked profile itself is mutually invisible.
- Actual: The profile RPC correctly refused the profile, and the action button was rendered only when profile data loaded.
- Evidence: iPhone 16e showed `Profile unavailable` with no relationship action before the fix.
- Root cause: The management action was nested inside the successful-profile branch.
- Resolution: Render the caller-owned Unblock action alongside the intentional unavailable-profile state.
- Status: Fixed and verified in Simulator; Unblock restored the `Add Friend` state and removed the Blocked connection.

## Advisor disposition

- Caller-bound `SECURITY DEFINER` notices: accepted and intentional. Every exposed function binds the actor to `auth.uid()`, uses an empty search path, validates target visibility, and has no `anon` execute grant.
- `pg_net` in `public`: pre-existing and unused by this epic; the only associated trigger is disabled and its function/table client surfaces are revoked.
- Leaked-password protection: project-level Auth setting remains disabled and requires an owner decision in Supabase Dashboard.
- New-index “unused” notices: expected immediately after creation; query plans are recorded below and indexes should be re-evaluated after representative production volume.

## Performance evidence

Current live data, `EXPLAIN (ANALYZE, BUFFERS)`:

- People search: 6.8 ms
- Public profile: 13.2 ms
- Cafe discovery: 16.6 ms
- Ranked feed: 16.1 ms

No query persisted request coordinates.

## Verification summary

- iOS: 44 tests passed, 0 failed, 0 skipped on iPhone 17 after the final fixes.
- Builds: final app build/install/launch succeeded on iPhone 17 and iPhone 16e, both iOS 26.2.
- Signed-in UI: temporary Alice/Bob/Carol roles verified exact/fuzzy people search, request/accept, empty friend feed isolation, public and ranked feeds, optimistic like, one-level reply with autocomplete mention, report reasons/submission, native rich share sheet, block/unblock management, discovery Map/List, denied-location fallback, 25/100 km controls, cafe details/actions, Saved propagation, and add-visit gating. A DEBUG-only launch fault also verified the offline recovery card, Retry interaction, and successful normal-network recovery without altering host networking.
- SQL: migration integrity, three-account social/RLS, and discovery/social contract suites all passed transactionally against the live project.
- Logs/advisors: Auth, API, Postgres, and Storage logs reviewed; security and performance advisors rerun after push quarantine. Remaining notices are dispositioned above.
