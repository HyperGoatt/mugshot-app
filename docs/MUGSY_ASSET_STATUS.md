---
document_type: living
status: current
last_verified: 2026-08-24
---

# Mugsy asset status

## Current authority and vector handoff

The shipping PNG image sets and the production code-native
`MugsyModelView` remain authoritative. This remediation adds
`MugsyVectorReferenceExporter`, which renders the canonical 500-by-500 contour
geometry directly into a vector PDF with embedded provenance metadata. The
review artifact is [Mugsy code-native vector reference](assets/Mugsy-code-native-reference.pdf).

The PDF is review-only. It does not replace any asset catalog entry, does not
change shipping artwork, and is not an `.ai` file. A separately approved design
review is required before derived artwork can become production-authoritative.

## Historical imported-asset baseline

Date: 2026-07-03

## Current Active Repo

The active repo at `/Users/joe.rosso/Desktop/Projects/testMugshot` now includes a tiny Mugsy empty-state slice in `testMugshot/Assets.xcassets`.

Imported image sets:

- `MugsyNoFriends.imageset`
- `MugsyNoFavorites.imageset`
- `MugsyNoWishlist.imageset`
- `MugsyNoCafes.imageset`
- `MugsyComingSoon.imageset`

These were copied from `/Users/joe.rosso/Documents/mugshot-app/testMugshot/Assets.xcassets`.

## Assets Found Elsewhere

Useful project-owned Mugsy assets were found in:

- `/Users/joe.rosso/Documents/mugshot-app/fun time`
- `/Users/joe.rosso/Documents/mugshot-app-main/fun time`
- `/Users/joe.rosso/Downloads`

Named files found include:

- `Mugsy-no-friends.png`
- `Mugsy-no-favorites.png`
- `Mugsy-no-wishlist.png`
- `Mugsy-no-cafes.png`
- `Mugsy-coming-soon.png`
- `Mugsy-spin.png`
- `Mugsy-spin-celebrate.png`
- `Mugshot-launch-screen.png`
- `Mugsy-with-drink.png`
- `Mugsy-signup.png`
- `Mugsy-download-appstore.png`

Older native asset catalogs also include image sets such as:

- `MugsyNoFriends.imageset`
- `MugsyNoFavorites.imageset`
- `MugsyNoWishlist.imageset`
- `MugsyNoCafes.imageset`
- `MugsyComingSoon.imageset`
- `MugsySpin.imageset`
- `MugsySpinCelebrate.imageset`
- `Mugshot Launch Screen.imageset`

## Implemented Slice

1. Copied only the clear empty-state image sets from the older native repo into the active `Assets.xcassets`.
2. Added reusable `MugsyEmptyStateView`.
3. Used it in Saved empty states, Profile no-visit/top-cafe states, and empty remote Feed states.
4. Added focused enum/presence tests and passed build/tests.

Avoid copying old UI code wholesale just to get Mugsy. The active app's Supabase-safe core loop should remain the base.
