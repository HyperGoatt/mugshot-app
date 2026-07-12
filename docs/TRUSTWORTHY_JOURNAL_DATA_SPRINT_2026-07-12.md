# Trustworthy Journal Data Sprint — 2026-07-12

## Objective and baseline

Make cafe identity, saved state, visit publication, multi-photo recovery, deletion, relaunch, and cross-screen refresh trustworthy before adding more product surface area.

- Branch: `codex/app-store-polish`
- Existing unrelated work was dirty at sprint start and remains preserved.
- Baseline build: passed on signed-in iPhone 17, iOS 26.2.
- Baseline live data: 41 cafe rows, 16 complete visits, 47 photo rows, and 16 cafe-state rows.
- Baseline integrity: four exact cafe duplicate groups containing six redundant rows; no orphan photo rows; no stale incomplete visits at capture time.

## Confirmed defects

### DATA-001 — Concurrent cafe resolution creates duplicate cafe records

- Severity: High
- Reproduction: Resolve the same unresolved MapKit cafe through visit creation and saved-state mutation; repeat or allow the requests to overlap.
- Expected: Every real cafe resolves to one durable backend identity.
- Actual: Lookup and insert are separate operations with no unique Apple/geo/text identity constraint.
- Evidence: Live SQL found four duplicate groups: one group had four identical rows and three groups had two. Duplicate rows shared names, coordinates, and addresses; several were created as unreferenced shells beside the referenced row.
- Root cause: `CafeService.findOrCreateCafe` used check-then-insert against non-unique fields, while `cafes` only constrained `google_place_id`.
- Status: Fixed. Migration `20260712134347_enforce_cafe_identity` merged six rows, preserved all visit/state references, backfilled deterministic identity keys, and added a trigger plus unique constraint. Client resolution now uses the same identity and recovers a unique-key race by fetching the winner.

### DATA-002 — Upload recovery disappears after navigation or relaunch

- Severity: High
- Reproduction: Begin a signed-in photo-backed save, interrupt it after the visit draft is created, leave Add or terminate the app, then return.
- Expected: The same draft and photos can be retried or discarded without creating another visit.
- Actual: The pending visit and uploaded-object metadata live only in `@State`; `MainTabView` destroys Add when switching tabs.
- Evidence: Code path inspection of `pendingRemoteSubmission`; no disk/defaults persistence existed.
- Root cause: Recovery was scoped to a SwiftUI view lifetime and Storage object names were generated only during upload.
- Status: Fixed in code. Pending form data, local draft photos, client-generated visit ID, deterministic Storage paths, desired visibility, phase, and uploaded URLs are account-scoped and durable. Retry is idempotent across create/upload/attach/finalize boundaries.

### DATA-003 — Deleting a completed visit leaves Storage objects behind

- Severity: High
- Reproduction: Delete a remote visit with photos and inspect its `visit-photos` objects.
- Expected: The visit becomes invisible immediately and its media is removed, with cleanup retried if Storage is temporarily unavailable.
- Actual: `VisitService.deleteVisit` deleted only the database visit; photo rows cascaded but Storage objects were never addressed.
- Evidence: Direct service and remote-detail code inspection.
- Root cause: Database deletion and Storage cleanup had no orchestration or durable cleanup queue.
- Status: Fixed in code. Deletion captures object paths, deletes the journal record first, removes Storage media, and queues account-scoped cleanup for the next launch if removal fails.

### DATA-004 — Remote saved-state snapshots cannot clear stale local flags

- Severity: Medium
- Reproduction: Remove or clear a remote cafe state, then load a snapshot that omits it while the local cafe remains flagged.
- Expected: Map, Saved, and Cafe Details agree with the complete remote snapshot.
- Actual: `applyRemoteCafeStates` only upserted returned rows; absent remote state could remain true locally.
- Root cause: Merge semantics were used where authoritative snapshot reconciliation was required.
- Status: Fixed in code. Signed-in snapshot application resets local flags before applying remote rows, then persists once.

### DATA-005 — A completed visit can remain Want to Try

- Severity: Medium
- User impact: The same cafe can appear as both already visited and still awaiting a first try.
- Root cause: Visit finalization and cafe-state mutation were unrelated.
- Status: Fixed in code. Publication completes first, then a best-effort state cleanup runs so a transient state failure cannot misclassify a successfully published sip as failed. Launch reconciliation durably clears any completed-visit overlap and mirrors the corrected state locally.

### DATA-006 — Inactive cafe-state rows accumulate

- Severity: Low
- Reproduction: Toggle both Favorite and Want to Try off, then inspect `user_cafe_states`.
- Expected: A row exists only while at least one saved-state flag is active.
- Actual: Eight of 16 live rows had both flags false, increasing reconciliation work and making an omitted row ambiguous.
- Evidence: Baseline live SQL; eight inactive rows and eight active rows.
- Root cause: State updates persisted false/false rows instead of deleting them.
- Status: Fixed. `CafeStateService` deletes inactive rows and fetches only active state. Migration `20260712135105_remove_inactive_cafe_states` removed the eight historical inactive rows.

### DATA-007 — Five legacy Storage objects are unreferenced

- Severity: Low (storage/cost hygiene; no current broken UI)
- Reproduction: Compare objects in the `visit-photos` bucket with both `visit_photos.photo_url` and `visits.poster_photo_url`.
- Expected: Every object is referenced by a durable visit record or queued for cleanup.
- Actual: Five objects uploaded in December 2025 have no visit or photo-row reference.
- Evidence: Final live SQL found 26 objects in `visit-photos`, 21 referenced and five unreferenced. All 47 current photo rows resolve to an existing object across their two historical buckets.
- Likely root cause: The pre-sprint create/delete flow uploaded random object paths without transaction recovery or Storage cleanup.
- Status: Future recurrence fixed by deterministic upload paths plus the durable deletion cleanup queue. Historical deletion is blocked in-app because the five objects span account-owned prefixes and no authenticated owner/session can delete another account's media. An administrator should remove the five paths listed in the final sprint handoff through Supabase Storage after taking a backup or confirming retention requirements.

### PERF-001 — Local photo cache eagerly decodes every historical image

- Severity: Medium
- Reproduction: Launch with a large local/demo journal.
- Expected: Images decode near display size and on demand.
- Actual: `DataManager` preloaded every visit image at launch into an unbounded dictionary; disk reads/decodes could block a view appearance.
- Root cause: Eager startup preloading and an unbounded custom cache.
- Status: Fixed in code. Startup preloading was removed, the cache is cost/count bounded, and local image reads decode off the main actor through task-driven views.

## Migration verification

- Transactional dry run: six rows merged; 16 visits and 16 states preserved; zero duplicate identity pairs.
- Applied migration: `20260712134347_enforce_cafe_identity`.
- Applied cleanup migration: `20260712135105_remove_inactive_cafe_states`.
- After: 35 cafes, zero missing identity keys, zero duplicate identity keys, 16 complete visits, 47 photo rows, eight active cafe states, zero inactive states, zero true orphan cafe references, zero orphan photo rows, and zero current photo rows missing Storage objects.
- Rolled-back concurrency probe: two formatted variants of the same geo identity produced one row through `ON CONFLICT`.

## Final implementation verification

- Automated tests: 38 unit tests and three UI tests passed; zero failed or skipped. Focused coverage includes cafe identity normalization and reconciliation, explicit visit IDs, cafe insert identity encoding, durable account-scoped pending submissions and photos, Storage-path parsing, and cleanup-queue behavior.
- Simulator devices: signed-in iPhone 17 on iOS 26.2 and iPhone 16e on iOS 26.2 both built and launched successfully.
- Signed-in flows exercised: Feed, Map, Saved, Profile, Cafe Details, Favorite removal and restoration, state propagation between views, and relaunch. Favorite removal immediately removed the cafe from Favorites; restoration immediately returned it, while the backend remained deduplicated.
- Multi-photo behavior: existing carousel/full-screen behavior was regression-tested in the preceding sprint; this sprint verified durable image/record recovery with focused automated tests. The live Photos picker opened with seeded media, but native picker selection was unavailable to both Xcode accessibility automation and the fallback Mac UI controller, so a newly interrupted live upload could not be safely automated end-to-end.
- Destructive deletion: no real user visit was deleted during Simulator QA. Deletion ordering, owner-path filtering, URL parsing, and persistent cleanup retry are covered by focused tests; final live SQL has zero orphan photo rows and every current photo reference has a Storage object.
- Runtime logs: final signed-in launch and Feed → Map → Saved → Profile navigation produced no fatal, crash, assertion, Supabase, or runtime-error matches.
- Measured signed-in load spans: Feed initial page 312.2 ms and Map initial data 223.5 ms. Feed improved from the previous instrumented 367–391 ms baseline; no new synchronous image preload remains.
- Final build: passed on iPhone 17 after all edits. `git diff --check` passed.

## Files and implementation areas

- Cafe identity: `Cafe.swift`, `SupabaseCafe.swift`, `CafeIdentityReconciler.swift`, `CafeService.swift`, `DataManager.swift`, and migration `20260712134347_enforce_cafe_identity.sql`.
- Saved-state reconciliation: `CafeStateService.swift`, `MainTabView.swift`, and Map/Saved/Profile/Feed task revision wiring.
- Durable publication: `PendingVisitSubmissionStore.swift`, `AddTabView.swift`, `SupabaseVisit.swift`, `VisitService.swift`, and `VisitPhotoUploadService.swift`.
- Deletion and cleanup: `VisitDeletionService.swift` and `RemoteVisitDetailView.swift`.
- Performance: `PhotoCache.swift`, `PhotoImageView.swift`, and removal of eager local-photo preload in `DataManager.swift`.
- Focused coverage: `testMugshotTests.swift`.

## Remaining risk and exact external action

- Remove the five confirmed unreferenced `visit-photos` objects through an administrator Storage session; they are the five paths under owner prefixes `f2421502-1e33-401c-92e5-c68a1a92369d` (three JPEGs created 2025-12-17) and `71500ca8-a989-4416-b716-c160325c79ba` (two PNGs created 2025-12-24). Do not delete by editing `storage.objects` directly; use the Supabase Storage API or Dashboard.
- Perform one manual release-device interruption check: start a two-photo post, force-quit during upload, relaunch, and tap Retry. Automation could not select assets in the system Photos picker, but the persistence and idempotency boundaries are covered in tests.
- Existing Supabase advisor notices predating this sprint remain outside scope (security-definer/mutable-search-path warnings and unrelated index/policy performance suggestions). Neither migration added a new advisor finding.
