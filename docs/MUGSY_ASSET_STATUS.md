---
document_type: living
status: current
last_verified: 2026-11-24
---

# Mugsy asset status

> Current repair: [Repair and sharing status](REPAIR_SHARING_STATUS.md) supersedes
> the earlier delivery and acceptance statements below for moderation, Friends
> publication, profile sharing and the reported native bugs. Those earlier
> checkpoints remain evidence of the previous candidate, not this repair's acceptance.


## Current identity and pose authority — 2026-11-24

The [brand kit](brand/README.md) is the entry point. The
[immutable identity contract](brand/identity/README.md) freezes the original
Mugsy master and seven native core shapes. The owner requested a pose/accessory
refresh while keeping Mugsy the same; 18 generated PNG poses and matching typed
SwiftUI configurations now expand the original rig. The five legacy asset names
remain compatible and hold updated positive poses. Original raster versions are
preserved under the identity archive.

Native geometry remains authoritative for code-rendered product motion. Generated
artwork is a separate static rendering with source prompts, exact output hashes,
true alpha, margins, and recorded optical review. It cannot redefine the body,
handle, glasses, proportions, palette, or master. Native reference renders use
production SwiftUI source offscreen on macOS and do not establish an iPhone or
TestFlight gate. [Current verification](brand/VERIFICATION.md) records the checks.

## Historical vector handoff — 2026-08-24

The following paragraph records the earlier vector handoff. Current pose and
asset authority is defined above; the PDF remains a review-only geometry reference.

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
