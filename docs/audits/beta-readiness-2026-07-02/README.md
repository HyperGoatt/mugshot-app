# Mugshot Beta Readiness Audit

Date: 2026-07-02

Scope: polished personal loop on iPhone 17 Pro simulator: Map, Feed, remote Visit Detail, Add Visit, Saved, Cafe Detail, and Profile Recent.

Goal: confirm the current product loop is coherent enough for a narrow beta and identify the next highest-value work before broader mockup-led redesign.

## Evidence

Screenshots captured in `docs/audits/beta-readiness-2026-07-02/screenshots/`:

1. `01-map-launch.jpg` - Map launch state.
2. `02-feed-friends.jpg` - Feed Friends with real no-photo remote card.
3. `03-remote-visit-detail.jpg` - Remote Visit Detail from Feed.
4. `04-add-visit-top.jpg` - Add Visit top/photo-first state.
5. `05-add-visit-form.jpg` - Add Visit cafe/drink/rating middle state.
6. `06-add-visit-lower-form.jpg` - Add Visit caption/note/visibility area.
7. `07-add-visit-save-area.jpg` - Original incomplete save area before the audit fix.
8. `08-add-visit-disabled-save-after-fix.jpg` - Fixed incomplete save area.
9. `09-saved-favorites.jpg` - Saved Favorites.
10. `10-cafe-detail-from-saved.jpg` - Cafe Detail opened from Saved.
11. `11-profile-top.jpg` - Signed-in Profile top.
12. `12-profile-recent.jpg` - Profile Recent with no-photo and photo-backed visits.

## Step Health

1. Map launch - healthy enough for beta. The map opens with pins, a location-off banner, search, and a clear legend. Fresh Map sheet capture was limited because the Simulator window refused coordinate clicks during this audit, though the sheet was validated in the immediately preceding map polish pass.
2. Feed - healthy. Friends feed showed real remote visits, including no-photo states, with clear detail affordance.
3. Remote Visit Detail - healthy. The saved confirmation, no-photo placeholder, score, cafe, drink, caption, and metadata are easy to understand.
4. Add Visit top - healthy. The photo-first hierarchy, progress card, and Supabase/no-photo readiness copy make the creation path feel intentional.
5. Add Visit form - mostly healthy. Cafe, drink type, drink details, rating, caption, notes, and visibility are ordered sensibly.
6. Add Visit save area - fixed during audit. The primary CTA previously looked available while 0 of 4 required details were ready. It now says `Complete Required Details` and is disabled until the four required items are complete.
7. Saved - healthy with one caveat. Synced Favorite/Want-to-Try state is visible, actions are reachable, and cards match the current polish direction. State-only cafes can still show `0 visits`, which is valid but may need calmer copy before beta.
8. Cafe Detail - healthy. Details opened from Saved, displayed stats/actions/recent visits, and preserved the existing backend/local fallback behavior.
9. Profile - healthy. Signed-in profile data and stats loaded.
10. Profile Recent - healthy. The list showed both no-photo and photo-backed visits, preserving the key Supabase save/upload loop.

## Strengths

- The core beta promise is now visible across screens: log a sip, see it in Feed/Profile Recent, open detail, and keep cafe state in Saved/Map.
- Add Visit feels like the right first polished surface and still preserves the working save/upload contracts.
- No-photo and photo-backed states both have visible, understandable UI.
- The repeated card language across Feed, Profile Recent, Saved, Cafe Detail, and Map sheet is starting to feel like one app.
- Remote detail gives reassuring post-save confirmation without adding deferred social/share actions.

## UX Risks

- Map still depends on Apple Maps availability for search, and search has recently returned `Can't reach Apple Maps right now` in the simulator. Typed cafe fallback protects Add Visit, but map discovery is not yet beta-strong.
- State-only cafes with no visible remote aggregate can show `0 visits`, which may feel broken even when technically accurate.
- Feed includes Like, Comment, and Save icons that do not yet perform real social mutations. For beta, they should either become disabled/quietly local, be hidden, or get read-only treatment.
- Profile tabs beyond Recent remain mostly local/demo-style surfaces. Recent is the dependable beta surface.
- The current app still mixes remote truth with local shell data in Saved, Map, Cafe Detail, and stats. This is acceptable for a narrow beta, but should stay documented.

## Accessibility Risks

- Screenshots show generally large text and touch targets, but this audit did not prove VoiceOver labels, Dynamic Type reflow, contrast ratios, or keyboard/focus behavior.
- Map pins and some image placeholders rely on visual meaning; their accessible labels should be checked before TestFlight.
- The disabled Add Visit CTA is now semantically disabled, but contrast should be checked against accessibility thresholds.
- Bottom tab automation remains intermittent, so manual device testing should still confirm tab reachability and safe-area behavior.

## Implemented During Audit

- Add Visit now disables the primary Save action until the required Cafe, Drink, Rating, and Caption items are complete.
- The incomplete CTA now reads `Complete Required Details`.
- The existing validation, no-photo save, photo upload, remote detail, and Supabase payload paths were not changed.

## Deferred

- Full Map redesign, filters, friend overlays, and recommendation layers.
- Friends, Notifications, share/social surfaces, and social mutations.
- Full Taste Identity.
- Saved lists/search/notes/invite surfaces.
- Mugsy asset work and richer empty-state illustration.
- Backend schema changes, cafe aggregate expansion, and place identity strategy changes.

## Recommendation

Move next to a narrow beta-hardening pass, not another broad visual polish pass:

1. Run one fresh end-to-end no-photo Add Visit smoke after the disabled CTA fix.
2. Run one fresh photo-backed Add Visit smoke on device or simulator with reachable Photos picker.
3. Decide whether Feed social icons should be hidden or marked read-only until real mutations exist.
4. Do a focused accessibility pass on Add Visit, remote Visit Detail, Profile Recent, and Saved.
5. Then begin the larger mockup-led UI/UX revamp from the now-proven contracts.
