# Canonical Mugsy Design System

Status: approved model, motion, and product-placement implementation

This document defines Mugsy's canonical construction, articulation, contextual props, occasional outfits, motion language, and product-placement rules. The system faithfully normalizes the existing character; it does not reinterpret or modernize him.

## Source of truth

`MugsyNoWishlist` is the primary front-facing master because it exposes Mugsy's complete silhouette and was explicitly selected as the active design. The mark at his center is a Wishlist bookmark held beneath crossed arms. It is a prop, not clothing or anatomy.

These immutable assets remain supporting expression, pose, and personality evidence:

- `MugsyNoWishlist`
- `MugsyNoFavorites`
- `MugsyNoCafes`
- `MugsyNoFriends`
- `MugsyComingSoon`

The code-native model is an optical normalization of the approved artwork. It does not replace or mutate the source PNGs.

## Permanent identity rules

1. Mugsy is a softly hand-drawn white ceramic mug with controlled asymmetry.
2. Glasses are permanent and remain the strongest facial identity mark.
3. The handle remains on Mugsy's right in the canonical front view.
4. The ceramic body, elliptical rim, double-contour handle, small limbs, and compact feet retain the approved proportions.
5. Expressions come from brows, eyelids, pupils, gaze, cheeks, and mouth. Expressions never change anatomy.
6. Props and outfits are optional context layers. Removing them leaves a complete, recognizable Mugsy.
7. Mugsy keeps the same white ceramic palette on light and dark surfaces.
8. Coffee appears only inside the open rim. Liquid never recolors the ceramic body.

## Coordinate and proportion system

Mugsy is authored on a normalized 500 by 500 unit canvas. The primary asset's alpha bounds are `x: 145, y: 154, width: 271, height: 274`. The canonical model occupies `x: 67, y: 65, width: 366, height: 370` after reference normalization.

The rim, body, handle, glasses, cheeks, and feet are acceptance anchors. Each normalized model anchor remains within 2% of the corresponding master anchor. Left and right hand attachment anchors remain stable so props can change without changing Mugsy's base anatomy.

Minor optical correction may remove accidental raster drift or inconsistent line weight. It must not alter the silhouette, personality, handle side, face placement, or limb proportions.

## Locked palette

| Token | Value | Use |
| --- | --- | --- |
| Ink | `#0C0C0C` | Primary contour, glasses, pupils, hands, feet, and prop detail |
| Ceramic base | `#F3F3F3` | Body, rim, handle, and eye whites |
| Highlight | `#F7F7F7` | Ceramic and lens highlights |
| Ceramic shadow | `#D7D6D6` | Rim depth, right-side shade, handle depth, and steam |
| Blush | `#E8B8B0` | Cheeks, tender props, and delighted mouth detail |
| Mugshot mint | `#B8E0C0` | Approved contextual accent; never a ceramic recolor |

No expression, prop, outfit, background, or product context may redefine these character colors.

## Contour hierarchy

Mugsy uses three contour tiers:

- Primary: body, rim, handle, glasses, arms, and legs.
- Detail: brows, mouth, inner rim, lens reflections, props, and outfit detail.
- Micro: the smallest supported inspection detail.

| Tier | Scale ratio | Minimum |
| --- | --- | --- |
| Primary | 0.009 of rendered size | 1.35 pt |
| Detail | 0.0065 of rendered size | 1.00 pt |
| Micro | 0.0045 of rendered size | 0.80 pt |

All contours use rounded caps and joins. Small imperfections should feel authored, never noisy or mechanically wobbled.

## Layer hierarchy

1. Double-contour handle and handle shade
2. Legs and feet
3. Asymmetric ceramic body, highlights, shade, rim, inner rim, coffee surface, and steam
4. Context outfit
5. Context prop
6. Arms and hands
7. Cheeks, eyes, pupils, brows, mouth, glasses, bridge, temples, and lens highlights

The body and handle use curved Bezier construction. A generic rounded rectangle is never an acceptable body substitute.

## Value-state interfaces

- `MugsyModelConfiguration` owns static value state.
- `MugsyExpression` defines neutral, curious, delighted, focused, tender, and concerned faces.
- `MugsyProp` defines stable context objects.
- `MugsyOutfit` defines rare wardrobe contexts.
- `MugsyArmPose` defines articulation without changing shoulder anatomy.
- `MugsyLegArticulation` defines planted-foot knee bend, body lowering, and weight shift without changing canonical leg or foot anchors.
- `MugsyLiquidState` defines visible drink surface and steam.
- `MugsyActionState` defines event and progress-driven product motion.
- `MugsyPlacement` is the registry for approved app contexts.

## Props

Approved prop states are:

- None
- Wishlist badge
- Favorite heart
- Guidebook and pen
- Friends phone
- Camera
- Journal notebook
- Builder tools

The Wishlist state always pairs the bookmark prop with `crossedOverProp`. Props use stable hand anchors, remain separate layers, do not erase permanent identity features, and are never required for recognition.

## Outfits

Approved outfit states are:

- Canonical
- Builder
- Cafe scout
- Camera companion
- Cozy ritual

Outfits are exceptional rather than default. They may not cover the glasses, mirror the handle, recolor the ceramic, distort the rim, or change body proportions. The builder outfit is reserved for true coming-soon or maintenance contexts. Missing photography uses the camera treatment instead.

- Builder uses a mint apron, pocket, softly curved hard hat, and separate tools.
- Cafe scout uses a brimmed scouting hat and the existing guidebook; no strap crosses the face.
- Camera companion uses a camera and simple strap with a curious default expression.
- Cozy ritual uses a knitted lower-body wrap, warm drink, steam, and journal without obscuring the face.

## Motion language

`MugsyAnimatedView` wraps the static model. It uses interaction progress and one-shot state changes; it does not run an ambient timeline. `MugsyCelebrationLoopView` is the sole looping exception and exists only inside a visible accomplishment state.

- Pulling maps directly to coffee fill and gaze.
- Refreshing produces one restrained focused response with a full coffee surface and steam.
- Composer progress maps to drink fill; saving is focused; completion is delighted.
- Camera focus maps gaze to the focus point; capture and completion use short reactions.
- Recovery uses a concerned but calm expression.
- Approved interactive heroes and empty states may opt into wave-only or wave/hop/happy-dance tap cycles.
- A successful save may use one branded confetti burst and the scoped dance loop.
- The accomplishment dance must bend Mugsy's knees and lower the body over planted feet. Rigid whole-character wobble is not an approved substitute for leg articulation.
- Reactions pause when explicitly paused, when the scene is inactive, or under Reduce Motion.
- Haptics are owned by the interaction and fire once at meaningful thresholds.

### Feed refresh sequence

| Pull progress | Presentation |
| --- | --- |
| Rest | Nothing is rendered |
| 0–20% | First drop falls from beneath the selected feed pill; Mugsy looks toward the opening |
| 20–85% | Drop becomes a pour; coffee surface expands inside the rim |
| 85–100% | Pour reaches a full coffee surface and the threshold arms |
| Refreshing | Pour disappears; full coffee and restrained steam remain |
| Complete | Short delighted settle |

Under Reduce Motion, the same meaning is communicated through discrete states without spatial celebration.

## Product-placement registry

| Surface | Approved treatment |
| --- | --- |
| Onboarding | One delighted canonical hero |
| Authentication | One tender canonical hero; no loop while typing |
| Feed | Coffee-fill refresh plus first-feed, friends, and filtered empty states |
| Map and Discovery | Guidebook and cafe scout treatment in empty or recovery states; never a persistent loaded-map overlay |
| Saved Favorites | Favorite heart |
| Saved Wishlist | Wishlist badge beneath crossed arms |
| Saved cafes and shared lists | Guidebook and pen |
| Composer | Drink fill, focused save, delighted completion, concerned recovery |
| Camera | Camera prop and strap, focus gaze, capture reaction, permission recovery |
| Friends | Friends phone |
| Journal and Profile | Journal notebook, cozy ritual, and cafe ranking states |
| Missing photo | Camera treatment |
| True Coming Soon | Builder outfit and tools |
| Settings | Mugsy Studio and Motion Lab only; ordinary account controls remain quiet |

Mugsy does not appear persistently over a loaded map, inside every feed row, on destructive account confirmations, across privacy or legal screens, or as a looping distraction in scroll content.

## Forbidden deviations

- Replacing the body with a square, rounded rectangle, appliance, emoji, or generic cup icon
- Removing, minimizing, recoloring, or radically reshaping the glasses
- Changing white ceramic into a theme or dark-mode color
- Mirroring the canonical handle side
- Enlarging eyes or mouth into generic emoji anatomy
- Changing body, rim, handle, limb, or face proportions between expressions
- Treating a prop or outfit as permanent anatomy
- Adding random line wobble, inconsistent contour weights, blur, glow, or ornamental texture
- Generating a replacement character that merely resembles approved Mugsy
- Running character timelines in list cells or offscreen content

## Review and validation

The DEBUG-only Mugsy Studio includes:

- Canonical inspection with reference overlay, grid, anchors, and contours
- Six-expression sheet
- Correct Wishlist comparison
- Prop, outfit, and arm-pose libraries
- Tap-reaction and accomplishment-motion inspection
- Pull-to-refresh coffee sequence
- 44, 72, 120, and 200 point scale checks
- Light and dark background checks
- Side-by-side comparison against all five approved assets
- Locked palette inspection

Validation requires token and geometry tests, value-state invariants, deterministic refresh mapping, placement-registry coverage, Debug and Release builds, simulator inspection, VoiceOver review, Dynamic Type review, Reduce Motion review, and confirmation that the retired prototype rig has no remaining callsites.
