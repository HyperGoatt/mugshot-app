# Phase 2B Real Visits

Date: 2026-07-01

Purpose: record the attempt to begin real Supabase-backed Add Visit work, the web reference behavior, and the current backend blocker.

## Status

The durable personal coffee journal loop is implemented and simulator-validated on branch `codex/phase-2b-real-add-visit`.

Signed-in users can now create no-photo and photo-backed visits, see them persist in Profile Recent after relaunch, open remote Visit Detail with uploaded photos, persist basic profile text edits, and persist Favorite/Want-to-Try cafe state into Saved, Map, and Cafe Detail. The next product phase can move into the audited mockup-led UI/UX revamp while preserving these backend contracts.

Photo upload slice status: started on 2026-07-01 after Storage policy preflight. The first native path now uploads selected Add Visit images to Supabase Storage after the visit row exists, stores public URLs in `visit_photos`, and sets `visits.poster_photo_url`.

Private-beta readiness update on 2026-07-03:

- Add Visit now requires at least one selected photo before any save. The no-photo signed-in save path and no-photo upload recovery card were removed from the active UI path.
- If photo upload fails after the visit row is created, the app attempts to delete that just-created remote visit and returns the user to Add Visit with an error instead of opening a saved no-photo visit.
- Remote Feed/Visit Detail now have real Supabase-backed like/unlike, comment, count refresh, and cafe save/favorite controls. Cafe save preserves existing Want-to-Try state when present.
- Remote Visit Detail now supports owner edit of caption, private notes, and visibility, plus owner delete.
- Signed-in Profile stats and Top Cafes now derive from remote visit summaries instead of local/demo shell stats.
- A lean Settings surface now includes Sign Out, About, Privacy, Terms, and support/contact.
- A tiny Mugsy asset slice was imported from the older native asset catalog and is used through `MugsyEmptyStateView` in clear empty states only.
- XcodeBuildMCP build/run passed and `xcodebuild test` passed. A fresh photo-backed creation smoke completed on 2026-07-03 using Computer Use coordinate-click fallback for the native Photos picker after XcodeBuildMCP semantic tap/touch did not present it.
- Fresh smoke visit `587f8423-a56f-46fe-b15a-452b2f024ebf` saved caption `Codex photo-required beta smoke 2026-07-03 0844`, visibility `everyone`, one `visit_photos` row, and a `poster_photo_url`; after relaunch it appeared in Profile Recent, Feed, and remote Visit Detail with the uploaded photo visible.

Phase 2B write decision:

- Go: no `public.visits` insert trigger path calls `supabase_functions.http_request`.
- The removed `notify-friends-on-new-visit` trigger is not attached to `public.visits`.
- The only remaining non-internal visits trigger is `visits_set_updated_at`; it is enabled for updates only, not inserts, and calls `public.set_updated_at`.
- No service-role key or bearer text remains in the visits trigger path.

Completed read/write work:

- Added `SupabaseVisitRow`, `RemoteVisitSummary`, and `SupabaseCafeSummary` models.
- Added `CafeService.fetchCafe(id:)`.
- Added `CafeService.findOrCreateCafe(from:)` to reuse or create `public.cafes` rows from the selected native cafe.
- Added `VisitService.fetchRecentVisits(userId:limit:)`.
- Added `VisitService.fetchFeedVisits(scope:limit:)`.
- Added `VisitService.fetchVisitDetail(visitId:currentUserId:)`.
- Added `VisitService.createVisit(...)` to create the remote `public.visits` row that the signed-in photo upload path attaches photos to.
- Added `VisitPhotoUploadService` for the first signed-in visit photo upload path.
- Added `VisitService.attachPhotoURLs(visitId:photoURLs:posterPhotoIndex:)` to create `visit_photos` rows and update `poster_photo_url`.
- Added `CafeStateService` for signed-in Favorite/Want-to-Try persistence through `user_cafe_states`.
- Updated Profile Recent to load the signed-in user's real Supabase visits, including cafe names, drink names, captions, scores, dates, and visibility labels.
- Updated Feed to load signed-in Friends and Everyone scopes from real Supabase visits, including author, cafe/context, drink, caption, score, date, and visibility labels.
- Added a read-only remote visit detail sheet reachable from Feed and Profile Recent.
- Remote detail now reads visible `visit_photos`, `likes`, and `comments`, hydrates comment authors, renders existing remote photo URLs, and shows private notes only for the signed-in owner.
- Updated signed-in Add Visit to save the selected or typed cafe, drink type, drink details, ratings/category scores, caption, notes, visibility, context, required uploaded photos, and timestamp to Supabase.
- Added loading/error/success behavior and duplicate-submission protection for the remote save.
- Added a typed-cafe fallback when Apple Maps search is unavailable, then creates/reuses the cafe through the Supabase save path.
- Updated signed-in Saved, Map, and Cafe Detail to sync and write Favorite/Want-to-Try cafe state through Supabase while preserving the existing local UI shell.
- Successful remote Add Visit now mirrors the remote cafe identity into local state so Map/Saved can reflect newly logged cafes.
- Preserved local Add Visit as fallback only when there is no authenticated Supabase user.
- Left richer per-photo progress, orphaned Storage cleanup, full friend-graph semantics, and notification rebuilds for later slices.

## Personal Cafe State Slice

Implemented after the initial photo upload slice:

- Verified `public.user_cafe_states` has `user_id`, `cafe_id`, `is_favorite`, `want_to_try`, RLS enabled, and a unique `(user_id, cafe_id)` constraint for upsert.
- Added `Cafe.remoteCafeId` as the bridge between MapKit/local cafes and their resolved Supabase cafe identity.
- Signed-in Saved and Map load remote cafe state and merge it into `DataManager`.
- Map bottom sheet and full Cafe Detail optimistically toggle local Favorite/Want-to-Try, write through `CafeStateService`, and roll back with a small error if the remote write fails.
- Full Cafe Detail loads the signed-in user's remote recent visits for cafes with a resolved Supabase id, reflects remote count/average where available, and opens the existing remote Visit Detail.
- Added focused tests for `user_cafe_states` upsert encoding, remote cafe-to-local cafe mapping, and remote cafe visit stat calculation.
- Simulator validation after this slice opened Saved, presented Cafe Detail from a Saved cafe, showed the remote recent visit section for `Ritual Coffee Roasters`, and opened the remote Visit Detail from that cafe visit row.

Deferred from this slice:

- Richer remote cafe aggregate stats, popular drinks, broader cafe discovery, and social actions.

Validation follow-up on 2026-07-02:

- Profile text edit live-smoke passed with the signed-in account. Location was temporarily changed to `CHS Smoke`, the app was relaunched, the changed location reloaded from the restored Supabase session, and the field was restored to `CHS`.
- Saved/Want-to-Try persistence live-smoke passed. `Ritual Coffee Roasters` was toggled into Want-to-Try from Cafe Detail, the app was relaunched, and the cafe appeared in Saved > Want to Try.
- Map launch after relaunch still showed the Want-to-Try pin/legend state.
- Fixed a Cafe Detail/Saved display edge found during the smoke: state-only cafe sync can have no remote visit aggregate yet, so Saved cards and Cafe Detail now fall back to actual local visit rows instead of showing `0 visits` while rendering a visible visit row.
- XcodeBuildMCP tests passed after the fallback fix: 17 passed, 0 failed. The only warning was the existing `CLLocationCoordinate2D` imported-protocol conformance warning in `Models/Cafe.swift`.

## Phase 2D Photo Upload Slice

Storage preflight:

- Verified bucket `visit-photos` exists, is public, has a 10 MB file limit, and allows `image/jpeg`, `image/png`, `image/gif`, `image/webp`, and `image/heic`.
- Verified `storage.objects` has RLS enabled.
- Replaced the previous broad upload policy with an INSERT policy scoped to `TO authenticated`.
- The upload policy now requires `bucket_id = 'visit-photos'`, the lowercased first Storage folder to equal `auth.uid()`, and the object extension to be one of the allowed image extensions.
- Verified the policy in `pg_policies`; the app writes lowercased paths as `user-id/visit-id/generated-file-name.jpg`.
- Recorded the reviewable SQL in `supabase/manual/phase_2d_visit_photo_storage_policy.sql`.

Native upload behavior:

- Signed-in Add Visit now shows the existing native photo picker instead of only the no-photo readiness placeholder.
- Selected images are resized to a max 2000 px side, JPEG-compressed, and uploaded with `contentType: image/jpeg`.
- Uploads use standard Supabase Storage upload, not resumable TUS, because this first slice compresses images under the bucket's 10 MB limit.
- Storage object paths are lowercased before upload so Swift `UUID.uuidString` casing cannot fail the owner-folder policy.
- The visit row is created first, then photos are uploaded under the visit id, then `visit_photos` rows and `poster_photo_url` are saved.
- No-photo Add Visit no longer remains valid in signed-in or signed-out mode. Signed-out saves remain local/demo, but they still require a selected local photo.
- If photo upload fails after the visit row is created, the app now attempts to delete that just-created visit and shows an error instead of offering to open a no-photo remote visit.
- Added focused tests for lowercase Storage object paths, the 10-photo upload cap, `visit_photos` insert ordering/encoding, and poster photo fallback.

Deferred from this slice:

- Per-photo progress, deletion of orphaned Storage objects if a later database attach step fails, and private/signed URL bucket behavior.
- Broader photo-forward redesigns from the mockups; this slice only makes the existing Add Visit picker real for signed-in users.

Validation after upload slice:

- Supabase policy verification returned the expected `TO authenticated` owner-folder INSERT policy on `storage.objects`.
- Supabase security advisor did not report a new `visit-photos` Storage finding after the policy change; it still reports known backlog items for security-definer views/functions, `profile-media` object listing, `pg_net` in public, and leaked-password protection.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- XcodeBuildMCP test run passed after the retry/test slice: 14 test entries, 0 failures.
- Simulator UI snapshot showed signed-in Add Visit with the existing photo picker entry point and updated optional-photo copy.
- The system Photos picker opened with a seeded simulator image, but macOS Computer Use permissions were not granted, so the visible picker could not be completed through OS-level automation.
- A temporary debug-only launch injection was used for validation, then removed before finishing this slice.
- First upload smoke exposed a real bug: Swift uploaded uppercase UUID path segments, which failed the lowercase owner-folder Storage policy with a `POST /storage/v1/object/...` 400. Fixed by lowercasing iOS Storage paths and making the policy lowercase-safe.
- Final upload smoke created a real remote visit with one uploaded photo:
  - Caption: `Codex photo upload smoke 2026-07-01 1533`
  - Visit id: `4b37b6e8-62c3-4016-8163-28cdb804e792`
  - Storage object: `visit-photos` bucket, owner folder matched the authenticated user, visit folder matched the visit id, extension `jpg`, MIME type `image/jpeg`
  - `visits.poster_photo_url` is set and points to `visit-photos`
  - `visit_photos` has 1 row for the visit

Validation follow-up on 2026-07-02:

- Add Visit still shows the signed-in optional photo placeholder with `0/10` copy and the same no-photo save path.
- The photo target was converted from a separate boolean-driven presenter to a direct native `PhotosPicker` control.
- The Photos section now appears near the top of Add Visit, before cafe/drink fields, so the picker target is not pinned against the tab bar edge.
- Added `NSPhotoLibraryUsageDescription` to the app plist for the visit-photo selection path.
- Added focused tests for cafe insert payload encoding and no-photo visit insert payload encoding, including visibility, custom drink mapping, rating cleanup, category scores, and missing-rating rejection.
- XcodeBuildMCP tests passed after these changes: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed and showed the signed-in Add Visit photo target in the safer top-of-form position.
- XcodeBuildMCP taps and lower-level touch events still did not transition into an inspectable system Photos picker. No app/runtime log error appeared, so this remains a simulator automation limitation rather than an app failure.
- Computer Use coordinate-click validation on the visible Simulator opened the native Photos picker, selected a seeded simulator image, returned to Add Visit with a thumbnail, and showed `Ready to upload 1 photo`.
- A signed-in photo-backed visit was created through the real Add Visit form:
  - Cafe: `Codex Photo Loop Cafe`
  - Drink: `Photo Loop Cortado`
  - Caption: `Codex photo loop smoke 2026-07-02 1144`
  - Visibility: `private`
  - Overall score stored in Supabase: `5.0`
  - Visit id: `89e65d7c-f5f5-4e98-913e-ac72ab4a18d0`
  - Storage object: `visit-photos/71500ca8-a989-4416-b716-c160325c79ba/89e65d7c-f5f5-4e98-913e-ac72ab4a18d0/4cce55e4-1197-4294-977c-476545fe4b3a.jpg`
  - `visits.poster_photo_url` and `visit_photos.photo_url` point to the uploaded image.
- Remote Visit Detail rendered the uploaded photo, saved confirmation, cafe, drink, score, and private visibility.
- After app relaunch, Profile Recent still showed the photo-backed visit at the top, and opening it again rendered the remote photo in Visit Detail.
- Final personal-loop audit also verified Feed after relaunch showed the public photo-backed upload smoke, Saved > Want to Try still showed `Ritual Coffee Roasters`, Map launch still rendered the Want-to-Try state, and Cafe Detail opened from Saved with the expected count/rating/recent visit.

## Mockup-Informed UI Pass

Reviewed current mockups in `/mockups` on 2026-07-01.

Adopted now:

- `log1`, `log2`, and `log3` influenced a lightweight Add Visit progress card, but the app remains a single working form instead of becoming a multi-step wizard.
- `log1` influenced a signed-in photo-readiness section that now reflects optional Storage-backed photo upload without making photos required.
- `log4` influenced the remote Visit Detail owner confirmation: saved visits now show a "Visit saved" banner and a clearer reserved no-photo hero.
- `profile1` and `feed1` influenced cleaner Profile Recent no-photo thumbnails and empty-state language.

Deferred intentionally:

- Saved, Want to Try, Lists, Friends, Notifications, share cards, full Taste Identity analytics, cafe menu/detail expansion, map bottom-sheet redesigns, and broad tab/app redesign.
- Full photo upload UI polish remains deferred until the next UI/UX revamp; the smallest Storage write path has now been manually smoke-tested with a selected image.

Tradeoff:

- The mockups are photo-forward, but the first real backend loop was no-photo. The UI now allows optional signed-in photo upload while preserving no-photo saves as the reliable fallback.

## Add Visit Mockup-Led Polish

Implemented on 2026-07-02 after the durable personal loop was complete.

Mockups used:

- `log1` influenced the "Log a Sip" header, photo-first empty state, library-first photo action, and optional/no-photo reassurance.
- `log2` influenced the guided details flow, quick drink chips, selected-cafe summary, and large selected-photo poster treatment.
- `log3` influenced the prominent score panel, clearer rating section, caption/note labels, and visibility segmented controls.
- `log4` stayed deferred for the success surface because remote Visit Detail already owns the post-save confirmation and social/share actions are out of scope.

Implemented:

- Kept Add Visit as a single working form, but made it feel staged with a hero header, live progress count, status pills, and a horizontal summary strip.
- Rebuilt the Photos section into a larger photo-forward card using the existing direct native `PhotosPicker`, selected-image poster preview, thumbnail rail, add tile, and remove controls.
- Replaced the drink dropdown with native quick-pick chips while preserving the existing `DrinkType` values and custom "Other" field.
- Added clearer section labels, card padding, a larger rating score panel, updated caption/private-note copy, icon-backed visibility buttons, and keyboard-dismiss/bottom-scroll padding.
- Left `VisitService`, `VisitPhotoUploadService`, payload encoding, Storage paths, and the save/upload ordering unchanged.

Deferred:

- Camera capture, a multi-step wizard, share/friends prompts, success social cards, full Taste Identity, and any backend/schema changes.

Validation:

- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2. The only warning during one build was the existing `CLLocationCoordinate2D` imported-protocol conformance warning in `Models/Cafe.swift`.
- XcodeBuildMCP tests passed: 20 passed, 0 failed.
- No-photo simulator smoke through the polished form created a real Supabase visit:
  - Cafe: `Codex Polish Cafe`
  - Drink: `Polish Pass Cortado`
  - Caption: `Codex Add Visit polish no-photo smoke 2026-07-02`
  - Visibility: `Public`
  - Remote Visit Detail opened with saved confirmation.
- After relaunch, Profile Recent showed the polished no-photo smoke visit at the top.
- The polished photo picker target is visible and hittable, but in this run XcodeBuildMCP still did not transition into the system Photos picker, and Computer Use could not attach to the Simulator window. The already-proven photo-backed save/upload contract was not changed.

## Visit Detail And Profile Recent Polish

Implemented on 2026-07-02 as the next mockup-led continuation after Add Visit.

Mockups used:

- `log4` influenced the remote Visit Detail owner confirmation, centered saved state, and post-save hierarchy.
- `profile1` influenced richer Profile Recent cards with stronger image/no-photo treatment, cafe/drink hierarchy, and score pills.
- `feed1` influenced the compact metadata row and photo-led card direction that can carry into Feed later.

Implemented:

- Remote Visit Detail now presents owner visits with a larger "Sip saved" confirmation, then a photo-first hero or calmer no-photo placeholder.
- Photo-backed remote detail uses the first remote photo as a large poster with the score badge overlaid, while additional photos remain visible as thumbnails.
- Remote detail now groups cafe, drink, caption, author, visibility, context, and relative time into a clearer summary card before ratings and comments.
- Profile Recent remote cards now use a richer layout: image-led when a poster photo exists, compact no-photo thumbnail when it does not, with score, caption, visibility, and recency metadata.
- Profile Recent still opens the existing read-only remote detail sheet and still uses the existing signed-in Supabase fetch path.

Backend contracts preserved:

- No Supabase services, payload shapes, Storage paths, or save/upload ordering were changed in this pass.
- No-photo and photo-backed visits continue to read from the same `visits`, `visit_photos`, `cafes`, likes, and comments contracts.

Deferred:

- Share cards, "Log Another", friend prompts, like/comment mutations, edit/delete visit actions, profile media grids, full Taste Identity, Saved redesigns, map/cafe redesigns, and Mugsy asset work.

Validation:

- XcodeBuildMCP tests passed: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Simulator Profile Recent showed real remote visits, including the `Codex Polish Cafe` no-photo smoke and `Codex Photo Loop Cafe` photo-backed smoke.
- Opening the no-photo Profile Recent card showed the new saved confirmation, no-photo placeholder, cafe/drink/caption summary, and metadata.
- Opening the photo-backed Profile Recent card showed the new saved confirmation, large remote poster image, score badge, cafe/drink/caption summary, and private visibility.
- Detail screenshots captured outside the repo:
  - No-photo detail: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_f3c179cc-2580-4dd5-b1df-a2e96da5f72c.jpg`
  - Photo-backed detail: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_d6c6e217-7953-4d22-b7dd-190e28729814.jpg`

## Feed Card Polish

Implemented on 2026-07-02 after the remote Visit Detail/Profile Recent polish.

Mockups used:

- `feed1` influenced the larger author row, icon-backed scope control, image-led remote cards, location overlay, score pill, drink/caption hierarchy, and compact footer affordances.
- `profile1` and `log4` reinforced the same card grammar now used across Profile Recent, remote detail, and Feed.

Implemented:

- Signed-in Feed now keeps the existing real Friends/Everyone Supabase fetch path, but presents the remote cards with a more polished mockup-led layout.
- Feed subtitle now responds to the selected scope: Friends uses "Sips from friends" and Everyone uses "Fresh public sips."
- The scope selector now includes native icons for Friends and Everyone.
- Remote Feed cards now use a stronger author header, score pill, large photo/no-photo poster, cafe/location overlay, drink/caption block, metadata pills, and a compact detail footer.
- No-photo Feed cards now read cleanly without the location overlay crowding the placeholder.

Backend contracts preserved:

- No Supabase services, query scopes, payload shapes, Storage paths, or remote detail presentation contracts changed.
- Feed cards still open the existing read-only `RemoteVisitDetailView`.

Deferred:

- Search behavior, remote like/comment/bookmark mutations, share surfaces, saved-by/social proof, friend graph expansion, notifications, and full feed algorithm work.

Validation:

- XcodeBuildMCP tests passed after the final Feed polish: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Simulator Feed Friends showed the polished no-photo `Codex Polish Cafe` card and opened remote Visit Detail.
- Simulator Feed Everyone showed the updated scope subtitle and the public no-photo card.
- Scrolling Feed Everyone showed the photo-backed `Codex Photo Smoke Cafe` card with the large poster treatment; tapping it opened remote Visit Detail.
- Feed screenshots captured outside the repo:
  - Friends no-photo card: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_abc33a26-d3f7-4cb3-8da8-5690ab6a30d5.jpg`
  - Everyone photo-backed card: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_15c69ade-91ff-4b42-8f5b-5382dd63c71d.jpg`

## Saved And Cafe Detail Polish

Implemented on 2026-07-02 after the Feed card polish.

Mockups used:

- `saved1` influenced the Saved library header, stronger cafe cards, score pills, state chips, and action footer.
- `saved2` influenced the Want to Try subtitle and planning-oriented copy.
- `cafe1` influenced the Cafe Detail identity card, stat cards, action controls, and recent-visit treatment.

Implemented:

- Saved now has a clear header/subtitle that changes by tab while preserving Favorites, Want to Try, and All Cafes.
- Saved empty states now explain how each tab fills without adding new Lists, filters, notes, or invites.
- Saved cafe cards now use a richer card layout with image/no-image treatment, score pill, address, Favorite/Want to Try chips, visit/category metadata, and compact action footer.
- Cafe Detail now wraps cafe identity in a padded summary card, uses stat cards for average score and visits, and replaces the cramped action row with a stable two-column action grid.
- Cafe Detail recent visit rows now use the same calmer card language and still open the existing visit detail flow.

Backend contracts preserved:

- `CafeStateService` syncing and Favorite/Want-to-Try writes were not changed.
- `VisitService.fetchCafeVisits` and the local fallback recent-visit behavior were preserved.
- No Supabase schema, query, payload, or Storage changes were made.

Deferred:

- Lists, Saved filters beyond the existing tabs/sort, search, notes, invites, friend recommendation/social proof, richer cafe aggregate backend data, and full map/cafe redesign.

Validation:

- XcodeBuildMCP tests passed after the final Saved/Cafe Detail polish: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Simulator Saved Favorites showed the polished card layout and synced remote cafe state for `Ritual Coffee Roasters`.
- Simulator Cafe Detail opened from Saved, showed the padded identity card, stat cards, action grid, and recent visit section.
- Simulator tapped the recent visit row and opened the existing visit detail flow.
- Simulator Want to Try showed the planning subtitle and synced Want-to-Try cards.
- Screenshots captured outside the repo:
  - Saved Favorites: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_4a548b82-c9f6-4d7b-9929-72a54bd2ab80.jpg`
  - Cafe Detail: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_95b0d022-2874-41fe-8359-63ae000a7fc8.jpg`
  - Want to Try: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_096e7538-fc0c-40b3-9146-c3455583e863.jpg`

## Map Bottom Sheet Polish

Implemented on 2026-07-02 after the Saved/Cafe Detail polish.

Mockups used:

- `map1` and `map2` influenced the sheet grabber, clearer place identity, selected-state chips, stat cards, and compact action grid.
- The broader map discovery concepts from those mockups were treated as future direction, not implementation scope.

Implemented:

- Map cafe bottom sheet now uses a compact grabber, stronger cafe identity block, address wrapping, Favorite/Want-to-Try/category chips, stat cards, and the same action-grid language as Cafe Detail.
- The sheet keeps Log Visit, Favorite, Want to Try, Details, and Directions actions, but presents them in a more stable layout.
- Recent local visit rows in the sheet now match the calmer card language used across Feed, Profile Recent, Saved, and Cafe Detail.
- Empty map-sheet recent state now explains that logging the cafe will add it to the taste journal.

Backend contracts preserved:

- MapKit map/search/pin behavior stayed intact.
- `CafeStateService` Favorite/Want-to-Try writes were not changed.
- The full Cafe Detail sheet still opens from the Map sheet's Details action.
- No Supabase schema, query, payload, Storage, or remote cafe aggregate work was added.

Deferred:

- Map filters, friend overlays, recommendation carousels/lists, nearby discovery backend, social proof, full map redesign, and remote aggregate cafe data.

Validation:

- XcodeBuildMCP tests passed after the Map sheet polish: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Apple Maps search returned a simulator/network error during smoke, so the sheet was opened by tapping a visible map pin via Computer Use.
- Simulator opened the polished Map sheet for `Ritual Coffee Roasters`, showing synced Favorite/Want-to-Try state, stat cards, action grid, and recent visit row.
- The Map sheet Details action opened the existing full Cafe Detail sheet.
- Screenshot captured outside the repo:
  - Map sheet: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_f68675bb-0c20-4f51-9e15-525a8eaceb30.jpg`

## Beta Readiness Audit

Completed on 2026-07-02 after the Add Visit, Visit Detail/Profile Recent, Feed, Saved/Cafe Detail, and Map sheet polish passes.

Evidence:

- Audit report: `docs/audits/beta-readiness-2026-07-02/README.md`
- Screenshots: `docs/audits/beta-readiness-2026-07-02/screenshots/`

Implemented during the audit:

- Add Visit now disables the primary save action until Cafe, Drink, Rating, and Caption are complete.
- The incomplete CTA now reads `Complete Required Details` instead of looking like a ready `Save Visit` action.
- Existing validation, no-photo save, photo upload, remote Visit Detail, and Supabase payload paths were not changed.

Audit outcome:

- The narrow personal beta loop is coherent enough to keep hardening: Map launch, Feed, remote Visit Detail, Add Visit, Saved, Cafe Detail, Profile, and Profile Recent all rendered successfully from the signed-in simulator state.
- Profile Recent showed both no-photo and photo-backed remote visits.
- Saved and Cafe Detail kept the current synced Favorite/Want-to-Try and recent-visit behavior.
- Remaining beta risks are Map search reliability, read-only/social icon clarity, state-only cafe copy, Photos picker manual/device validation, and accessibility verification.

Validation:

- XcodeBuildMCP tests passed after the audit fix: 20 passed, 0 failed.
- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Fresh Map sheet capture was limited by a Computer Use coordinate-click window error in this audit run; the immediately preceding Map polish validation still covers sheet behavior and Details drill-in.

Validation after UI pass:

- XcodeBuildMCP build/run passed on iPhone 17 Pro iOS 26.2.
- Add Visit smoke created a new private Supabase no-photo visit:
  - Cafe: `Codex UI Pass Cafe`
  - Drink: `UI Pass Latte`
  - Caption: `Codex UI pass smoke 2026-07-01`
  - Visibility: `private`
  - Overall score: `5.0`
- Save opened the revised remote Visit Detail, showing saved confirmation, no-photo upload-next messaging, cafe, drink, score, and private visibility.
- Dismissing remote Visit Detail returned to Profile Recent with the new visit at the top.
- Post-pass detail screenshot captured outside the repo: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_a475e73b-871b-4f8a-a303-9301b34714d1.jpg`
- Post-dismiss Profile Recent screenshot captured outside the repo: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_2ef6b120-0919-45a4-a45c-343b9eea0cfe.jpg`

Smoke-test row created from the iOS simulator:

- Cafe: `Codex Test Cafe`
- Caption: `Codex no-photo visit smoke 2026-07-01 1349`
- Visibility: `private`
- Notes: `Phase 2B simulator smoke test`
- Context: `Cafe`
- Overall score: `5.0`
- Supabase row id: `7961eda4-ca64-4e0e-9afd-0b71bb67382a`
- The visit appeared in Visit Detail immediately, then appeared at the top of Profile Recent.
- After app stop/relaunch, Profile Recent still showed the same visit with the same caption and visibility.

## Preflight Evidence

Repository:

- Path: `/Users/joe.rosso/Desktop/Projects/testMugshot`
- Branch: `codex/phase-2b-real-add-visit`
- Current Desktop repo remains the source of truth; `/Users/joe.rosso/Documents/mugshot-app` was used only as a reference.
- Phase 2A checkpoint already exists: `ff98451 Phase 2A: add Supabase auth and profile bootstrap`
- `Config/SupabaseConfig.local.xcconfig` is ignored by `.gitignore`
- Secret scan found only documented warnings and guard code, not committed credentials

iOS baseline:

- XcodeBuildMCP build/run on iPhone 17 Pro iOS 26.2 passed before any docs edits.
- Screenshot captured outside the repo: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_6dae27c7-32bd-4336-9b2c-4d6dbbe7b793.jpg`
- After the read-backed slice, build passed, tests passed, launch passed, and Profile Recent showed real Supabase visits in the simulator.
- Profile Recent screenshot: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_b36ba6a8-3fd9-434e-8187-d6df9c57b742.jpg`
- After the Feed read slice, build passed, tests passed, launch passed, and Feed Friends/Everyone showed real Supabase visit cards in the simulator.
- Feed Everyone screenshot: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_766d492e-0399-42bd-9c45-3420f9413d9c.jpg`
- After the remote detail slice, build passed, tests passed, launch passed, and Feed/Profile Recent opened real Supabase detail sheets in the simulator.
- Feed Friends remote detail screenshot: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_eb77daf9-69bc-4b63-9318-2ead11077bfc.jpg`
- Feed Everyone remote detail social/comment screenshot: `/var/folders/n7/700n6bmn1vv_j9x6yw1p7njh0000gp/T/screenshot_optimized_f4ddff9a-8d37-4e32-8cdc-84b666f396bc.jpg`

Supabase readiness:

- `users`, `cafes`, `visits`, `visit_photos`, `user_cafe_states`, `likes`, and `comments` have RLS enabled.
- Authenticated role has table grants for select/insert/update/delete on those tables.
- `visits` has owner insert/update/delete policies and select policies for owner, friends, and public/everyone visibility.
- `cafes` is readable by everyone and writable by authenticated users, but policies still use older `auth.role()` patterns.
- Final preflight showed no active visits insert trigger that calls HTTP or contains bearer text.

Trigger scope checked:

- Visit creation: unblocked. `notify-friends-on-new-visit` is no longer attached.
- Cafe creation: does not fire the risky trigger. Only `cafes_set_updated_at` exists for cafe updates.
- Photo row creation: no trigger found on `visit_photos`.
- Likes/comments: no insert trigger found on `likes` or `comments`.
- Friends/saved state: no insert trigger found on `friends` or `user_cafe_states`; `friend_requests` has update triggers only.
- Notifications: separate `on_notification_insert` push trigger exists, so native work should avoid notification inserts until social/push is reviewed.

## Web Add Visit Reference Flow

The inspected web reference is `/private/tmp/mugshot-web-reference` at commit `a036556`.

User flow:

1. Open `/add`.
2. If auth is loading, show a loading state.
3. If signed out, show a login CTA instead of the compose form.
4. Choose location type: Cafe, Home, Travel, or Other.
5. For Cafe, search nearby/recent/results through Google Places Edge Functions, then upsert or reuse a cafe row before selection.
6. For Home/Travel/Other, enter a setup/location name, optional brew method, optional equipment, and visibility toggles for brew/equipment.
7. Choose drink type: Coffee, Matcha, Hojicha, Tea, Chai, or Other.
8. For cafe Coffee, choose a brew method.
9. For Other, enter a custom drink type.
10. Enter the specific drink/subtype. This is required.
11. Add up to 10 optional photos, each image-only and at most 10 MB.
12. Rate the visit. Smart templates auto-select from system templates by drink/brew method, with user templates taking priority.
13. Category ratings calculate the overall score. Users can also quick-rate the overall score.
14. Enter an optional caption, max 200 characters.
15. Choose visibility: Private, Friends, or Public/Everyone.
16. Optionally expand More Options and enter private notes, max 200 characters.
17. Submit with `Post to Journal`.
18. The submit button is disabled until required fields are present and disabled again while posting.
19. Web upload order is photos first, then insert `visits`, then insert `visit_photos`.

Native beta contrast as of 2026-07-03: web allowed optional photos in the inspected reference, but native Add Visit now requires at least one photo before posting or saving.
20. On success, web invalidates visit queries, shows a success toast, and navigates to Feed.

Backend payload:

- Required for the web path: `user_id`, `drink_type`, `drink_subtype`, `ratings`, `overall_score`, `caption`, `visibility`
- Required for cafe visits in product flow: `cafe_id`
- Optional or context-specific: `notes`, `poster_photo_url`, `context_type`, `location_name`, `brew_method`, `brew_method_visible`, `city_state`, `equipment`, `equipment_visible`, `rating_template_id`, `rating_template_type`, `category_scores`
- Photos: uploaded to `visit-photos`, public URLs stored in `poster_photo_url` and `visit_photos`
- System rating templates exist for Coffee, Espresso, Latte, Cappuccino, Pour Over, Drip Coffee, French Press, Cold Brew, Aeropress, Matcha, Tea, Hojicha, Chai, and General/Other.

## iOS Comparison

Already close:

- Native Add Visit has cafe search/select, drink type, custom drink type, up to 10 photos, rating categories, caption, private notes, visibility, validation, and local success/detail flow.
- Drink taxonomy mostly matches web, with iOS adding Hot Chocolate.
- Native visibility labels map to the web/backend values: Private, Friends, Everyone/Public.
- Native photo UI already supports 10 images and poster selection locally.

Missing or different:

- iOS saves to `DataManager` only and does not write Supabase rows.
- iOS requires caption, while web only requires cafe/setup, drink subtype, rating, and custom drink when applicable.
- iOS has no separate required drink subtype field; it currently treats drink type/custom type as the main drink field.
- iOS has no location type selector for Home, Travel, or Other.
- iOS has no cafe upsert service against `public.cafes`.
- iOS has no Supabase rating template reads, smart template matching, or persisted user templates.
- iOS photo selection is local only and does not upload to Storage.
- iOS success opens a local Visit Detail cover, while web navigates to Feed after success.

Implemented first native write slice:

1. Kept the existing native structure.
2. Extended `CafeService` with a cafe reuse/create path.
3. Extended `VisitService` with a no-photo write method after the trigger quarantine.
4. Added a required drink details field mapped to `drink_subtype`.
5. Mapped iOS visibility to lowercase backend values: `private`, `friends`, `everyone`.
6. Reused or created the selected cafe before visit insert.
7. Inserted a no-photo `visits` row using the authenticated user's id.
8. On success, opened remote Visit Detail and returned the user to Profile Recent.
9. Persisted current simple rating categories into `ratings` and `category_scores`.
10. Left upload retry/progress polish, Craft Sip write support, and social mutations for the next safe slices.

## Completion Checklist

1. Rotate/revoke the credential embedded in the old visit trigger action. Done manually before this slice.
2. Apply the reviewed trigger quarantine in `supabase/manual/phase_2a5_quarantine_visit_notify_trigger.sql`. Done before this slice.
3. Verify `notify-friends-on-new-visit` no longer exists or no longer fires on `public.visits` inserts. Done.
4. Confirm no bearer credential remains in trigger metadata for the visits path. Done.
5. Implement and simulator-test no-photo Add Visit writes. Done.
6. Confirm the created visit persists after relaunch. Done.
