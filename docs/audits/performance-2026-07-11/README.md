# Mugshot performance sprint — 2026-07-11

## Scope and environment

- iPhone 17 Simulator, iOS 26.2, Xcode 26.2, Debug configuration.
- Live Supabase project in `us-east-2`, Postgres 17.6.
- Priority flows: signed-in launch, Friends/Everyone Feed, Map initial data, Visit Detail, remote images, scrolling memory.
- Production data was small during the audit (16 visits, 47 visit photos, 11 likes, 10 comments), so query-plan validation also used transaction-scoped 100,000-row synthetic tables. No synthetic rows persisted.

## Baseline and after

| Metric | Before | After | Change / evidence |
| --- | ---: | ---: | --- |
| App launch, 5 runs | 1.193 s avg | 1.129 s avg | 5.4% faster; `XCTApplicationLaunchMetric`, same simulator/build configuration |
| Public Feed relation hydration, 3 cards | 11 REST calls / 2,443 ms | 5 REST calls / 583 ms | 76.1% lower wall time in the same live REST harness; relation requests run concurrently after the visits response |
| Instrumented signed-in Friends Feed | not instrumented | 367–391 ms | `PerformanceMonitor`, live app and backend |
| Instrumented Everyone Feed | not instrumented | 221.5 ms | live app and backend after migration |
| Feed query, 100k synthetic rows | unindexed shape not retained | 0.068 ms | index scan, 12-row first page |
| Map query, 100k synthetic rows | 10.131 ms | 0.168 ms | 60.3x faster; sequential scan replaced by indexed bitmap scan |
| Memory after Feed/Map interaction | not captured | 138.7 MB footprint / 167.8 MB peak | Simulator memgraph; decoded image cache capped at 64 MB |
| Leaks | not captured | 0 leaks / 0 bytes | `leaks` analysis of captured memgraph |

The REST comparison is intentionally a topology benchmark, not a claim that every device will see the same absolute latency. At 150 ms RTT, the old 11-call serialized three-card path has a 1.65 s network-latency floor; the new visits request plus one concurrent relation wave has a 0.30 s floor.

## Confirmed bottlenecks and root causes

1. **Feed N+1 fan-out (P0, high impact, low risk).** Each visit performed two serialized social queries and each distinct author performed another query. Cafe hydration had also been N+1 in the base branch and was already being batch-fixed in the working tree. At the normal 25-card limit, the path could exceed 50 network requests.
2. **No Feed pagination or reuse (P0, high impact, medium risk).** Every Feed construction fetched a fixed 25 rows, reconstructed the entire dependency graph, and discarded it when switching tabs.
3. **Full-resolution remote image decode (P0, high impact, medium risk).** `AsyncImage` did not provide an app-controlled decoded-image bound or target-size downsampling. Large 2,000-pixel uploads could be decoded at full size while scrolling.
4. **Map over-fetching (P1, high impact at scale, low risk).** The Map requested up to 1,000 complete `SupabaseVisitRow` objects including captions, notes, ratings, and URLs, then only used cafe ID and overall score.
5. **Serialized Visit Detail dependencies (P1, medium impact, low risk).** Summary, photos, likes, and comments were fetched one after another; comment authors were then hydrated N+1.
6. **Repeated formatter construction during rendering (P1, scroll CPU, low risk).** ISO-8601 and relative-date formatters were created repeatedly from SwiftUI card bodies and computed date accessors.
7. **Repeated local persistence during remote state merge (P1, interaction latency, low risk).** Applying a list of cafe states encoded and wrote the complete local model for every item, then wrote it once more at the end.
8. **Hot RLS functions evaluated per row (P1 database CPU, low risk).** Feed/social/state policies called `auth.uid()` directly instead of through an initialization plan.

## Implemented improvements

- Batched cafes, profiles, likes, comments, and comment authors; independent relation requests execute concurrently.
- Parallelized Visit Detail summary/photos/likes/comments.
- Added stable `(created_at, id)` keyset pagination with a 12-card first page, duplicate protection, lazy next-page loading, and pull-to-refresh.
- Added a 30-second stale-while-revalidate in-memory Feed cache, so returning to a recent Feed is immediate and issues no duplicate request.
- Added an actor-backed remote image pipeline with request deduplication, a 64 MB decoded-image cache, a 256 MB disk HTTP cache, and ImageIO downsampling off the main actor.
- Replaced the Map's full visit model fetch with `cafe_id, overall_score` only and added the filter required to use the partial covering index.
- Reused date formatters safely instead of constructing them during every render.
- Reduced a remote cafe-state merge from N+1 full-model persistence writes to one.
- Removed the redundant session lookup after password sign-in by using the session returned from `signIn`.
- Added `OSSignposter`/unified-log timings for local data load, session restore, Feed pages, Map data, and image networking.

## Supabase migration

`20260711135027_optimize_feed_queries.sql` was applied to the live project and verified. It adds:

- `visits_visible_feed_cursor_idx`
- `visits_user_complete_cafe_idx` (partial covering index)
- `comments_user_id_idx`
- init-plan-safe `auth.uid()` evaluation in five hot read policies

All RLS predicates and visibility/ownership rules were preserved. Verification found all 3 indexes and all 5 policy rewrites.

## Regression evidence

- Full pre-change baseline suite: 33 passed, 0 failed.
- Full post-change suite: 33 passed, 0 failed.
- Final focused unit suite after the last query predicate change: 30 passed, 0 failed.
- Launch performance suite: 1 passed; five before and five after measurements.
- Cursor smoke test against live REST: page 1 = 2 rows, page 2 = 1 row, 0 duplicate IDs.
- Live Friends and Everyone Feed UI smoke tests succeeded after the migration.
- Final simulator build succeeded with no diff whitespace errors.

## Remaining opportunities and risks

1. Capture Release-build SwiftUI, Animation Hitches, and Time Profiler traces on a physical device with 100+ photo cards. ETTrace was not installed in this environment, and simulator timing does not prove device frame pacing.
2. Move Feed aggregation into a security-invoker database function or purpose-built read model when traffic justifies reducing the remaining five-request first page to one. Validate the function under RLS before rollout.
3. Generate server-side Storage image variants (thumbnail/card/detail) and store dimensions. Client downsampling controls memory but does not reduce original transfer bytes.
4. Add a persistent, account-scoped Feed cache for true cold-launch progressive rendering. Never share cached private rows across account IDs.
5. Consolidate the three permissive visit SELECT policies only after exhaustive multi-account RLS tests; the advisor still flags their evaluation overhead.
6. Address remaining advisor findings outside this sprint's hot paths: unindexed foreign keys, non-init-plan write policies, security-definer views/functions, mutable function search paths, and leaked-password protection. These require a separate security migration because their authorization contracts extend beyond Home/Feed.
7. Validate under an actual network conditioner (150–300 ms RTT, 1–3 Mbps, packet loss) and on the oldest supported device before App Store submission. This audit modeled slower-network RTT from measured request topology but did not have a system network conditioner available.
