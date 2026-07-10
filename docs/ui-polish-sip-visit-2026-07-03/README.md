# Sip Posting And Visit Detail UI Polish

Date: 2026-07-03

## Scope

Focused UI/UX polish pass for Mugshot's core sip loop:

- Bottom Add/Post Sip entry point
- Add Visit / Post Sip surface
- Feed and Profile visit cards
- Supabase-backed remote visit detail
- Owner vs public/other-user detail states
- Direct loading/error states for this flow

No Supabase schema changes were made. No working Supabase-backed flows were replaced with local/demo data.

## Baseline Problems Found

- The bottom green Add button was offset upward inside a fixed-height tab item, which made it visually cut into the page and created awkward layering near card taps.
- Remote visit detail opened as a bottom sheet and led with "Sip saved," so the destination felt like a debug confirmation rather than a social post.
- Visit detail was section-heavy: "Visit Details," "Overall Score," and similar labels dominated the experience.
- Feed and Profile cards had the right data but felt more like records than social sip posts.
- Profile Recent cards were too compact to communicate photo, score, cafe, caption, and visibility gracefully.

## Plan Used

1. Keep all Supabase read/write paths intact.
2. Fix the Add button as an intentional native floating control inside the bottom nav.
3. Use restrained Liquid Glass on floating controls and hero overlays, with material fallbacks.
4. Make visit cards feel like social sip posts: author, hero/photo, cafe, drink, caption, score, visibility, and social state.
5. Replace remote detail sheet composition with a full-screen post detail.
6. Preserve owner edit/delete/private notes, but keep them secondary.
7. Ensure scores and rating breakdowns remain visible for posted sips regardless of owner state.

## Changes Made

- Added reusable glass surface helpers with iOS 26 `glassEffect` and pre-iOS 26 material fallbacks.
- Reworked the bottom nav into a floating glass island.
- Rebuilt the Add button as a stable circular glass control with no upward offset.
- Switched remote visit detail presentations from `.sheet` to `.fullScreenCover` in Add, Feed, Profile, and Saved.
- Redesigned remote Feed cards with stronger author/photo/location/drink/caption/social hierarchy.
- Redesigned local Visit cards to match the new post-card language.
- Redesigned Profile Recent remote cards as richer compact sip previews.
- Rebuilt `RemoteVisitDetailView` into a full-screen post detail with:
  - photo/no-photo hero
  - glass location/score overlay
  - author and owner state
  - drink and caption
  - metadata chips
  - visible score and rating breakdown
  - owner-only private notes
  - social controls and comments
  - polished loading/error states

## Owner Vs Other-User Behavior

Owner state:

- Shows "Your sip."
- Shows an "Editable" chip.
- Keeps edit/delete in the top menu.
- Shows private notes when present.
- Shows overall score and full rating breakdown.

Other-user/public state:

- Shows the author's display name instead of "Your sip."
- Shows a "Posted" chip.
- Does not show owner edit/delete controls.
- Does not show private notes.
- Still shows overall score and full posted rating breakdown.

Simulator data available during this pass contained public/community-looking visits, but the tested records were still authored by the signed-in `@joe` account. The non-owner branch was implemented in code and remains tied to `currentUserId == visit.userId`.

## Validation

- Build and launch succeeded on iPhone 17 Pro simulator, iOS 26.2.
- Verified signed-in Supabase Feed loads real remote visits.
- Verified Add/Post Sip screen still loads and remains photo-required.
- Verified Profile Recent loads real remote visits.
- Verified own remote visit detail opens as full-screen post detail.
- Verified older public/community sip opens and scores/rating breakdown remain visible.
- Verified no Supabase write/read flow was replaced with fake data.

Build warning still present and unrelated:

- `Cafe.swift` extends imported `CLLocationCoordinate2D` to `Codable`, which may conflict if Apple adds that conformance later.

## Screenshots

Before:

- `screenshots/before-feed-card.jpg`
- `screenshots/before-add-sip.jpg`
- `screenshots/before-profile-recent.jpg`
- `screenshots/before-own-detail.jpg`
- `screenshots/before-public-detail.jpg`

After:

- `screenshots/after-feed-card.jpg`
- `screenshots/after-add-sip.jpg`
- `screenshots/after-profile-recent.jpg`
- `screenshots/after-own-detail.jpg`
- `screenshots/after-public-detail.jpg`

## Recommended Next Polish Pass

- Verify a true different-author remote visit with beta data so the non-owner branch can be screenshot-tested.
- Add a dedicated public user/profile route before making author avatars tappable.
- Tune Feed card density after more real-world photo/caption variety.
- Add per-photo upload progress and clearer partial-failure recovery in Add Visit.
- Consider remote pagination/windowing for Feed and Profile Recent once beta data grows.
