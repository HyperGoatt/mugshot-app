# Dynamic Mugsy scene system

Date: August 5, 2026

This package records the production implementation and visual acceptance evidence for Mugshot's positive, context-aware Mugsy photo and true-empty states. The work uses the existing code-native Mugsy Studio model; it does not add generated character art or change Mugsy's identity.

## Product rules

- Production Mugsy scenes are always happy, joyful, curious, proud, cozy, playful, or welcoming. Tender, concerned, sad, angry, and depressed expressions are excluded from product placements.
- Mugsy appears only when a photo is genuinely absent or a product state is genuinely empty. Loading, failed media, removed media, privacy restrictions, offline content, and unavailable data retain truthful dedicated treatments.
- A stable cafe or sip identifier selects a variant deterministically. The same item therefore keeps the same Mugsy scene across relaunches instead of changing randomly.
- Small list and card placeholders are static. Only large hero placements may animate, and Reduce Motion makes those presentations static.
- Mugshot photos remain the cafe image as soon as an authorized Mugshot photo is available.

## Ten scene families

| Family | Primary use |
| --- | --- |
| Cheerful Cafe Scout | Cafe discovery, Map, and general cafe placeholders |
| Delighted Wishlist Holder | Want to Try cafes before the first completed sip |
| Happy Heart Keeper | Favorite cafes and keepsakes |
| Proud Camera Companion | Visited cafes and intentionally photo-free sips |
| Joyful Journal Keeper | Journal memories and personal history |
| Welcoming Friends Phone | Friends and attributed community activity |
| Cozy Coffee Ritual | Home coffee, quiet rituals, and taste memories |
| Excited First-Sip Celebration | First completed sip at a Want to Try cafe |
| Happy Builder | Shared cafe lists and experiences still taking shape |
| Playful Waving Mugsy | Welcome, generic true-empty states, and friendly handoffs |

Relationship semantics take precedence over decorative variety: visited cafes use the camera scene, Want to Try cafes use the wishlist scene, and Favorites use the heart scene. Generic contexts may select from a small compatible pool using the deterministic identifier.

## Integrated surfaces

- Saved cafe comfortable cards, rows, true-empty results, and cafe detail hero/identity placeholders
- Discovery rows and Map recent-visit/no-sip states
- Feed post, sip detail, remote visit detail, and Edit Sip photo-empty states
- Profile top cafes, journal rows, and remote visit thumbnails
- Shared cafe-list membership rows without changing established Lists behavior
- Tasting Lens photo-empty guidance
- DEBUG Mugsy Studio gallery for the complete ten-family product set

## Evidence manifest

All Simulator captures are from the iPhone 17 Pro at 402 x 874 points and 1206 x 2622 pixels at 3x, in the app's forced-light appearance. The fixture is deterministic, local, and contains no authenticated or production data.

1. [`01-studio-scenes-1-4-reduce-motion.png`](evidence/01-studio-scenes-1-4-reduce-motion.png) — Scout, Wishlist, Heart, and Camera families with Reduce Motion enabled.
2. [`02-studio-scenes-5-10-reduce-motion.png`](evidence/02-studio-scenes-5-10-reduce-motion.png) — Journal, Friends, Ritual, First-Sip, Builder, and Waving families with Reduce Motion enabled.
3. [`03-saved-want-to-try.png`](evidence/03-saved-want-to-try.png) — Production Saved cards resolve the Want to Try family for cafes without authorized photos.
4. [`04-cafe-detail-want-to-try-no-photo.png`](evidence/04-cafe-detail-want-to-try-no-photo.png) — Expanded cafe details uses the same relationship-aware scene, adds meaningful copy, and retains the approved action hierarchy.
5. [`05-saved-want-to-try-accessibility-xxxl.png`](evidence/05-saved-want-to-try-accessibility-xxxl.png) — Accessibility XXXL reflow with menus and vertical cards; Mugsy remains legible and non-essential motion is disabled.
6. [`06-source-and-implementation-comparison.png`](evidence/06-source-and-implementation-comparison.png) — Approved Mugshot V3 reference, Mugsy Studio gallery, and production implementations in one inspection board.

## Verification

- Full repository static verification: 11 passed, 0 failed, 1 optional dependency check skipped.
- Focused `MugsyDesignSystemTests`: 12 passed, 0 failed.
- Final Simulator build and launch: passed.
- Runtime semantic snapshots confirmed combined gallery labels, stateful Saved actions, and the accessibility XXXL category menus.
- Original-resolution visual inspection and combined brand comparison: passed.

The feature does not change networking, persistence schemas, backend behavior, production analytics, or established Lists workflows.
