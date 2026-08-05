# Saved cafes: no-photo cafe-detail concepts

This isolated mockup package explores ten honest Mugshot-branded treatments for the 402 × 220 expanded cafe-detail hero when no authorized cafe photo exists.

## Locked behavior

- A treatment is selected deterministically from a stable cafe identifier. It does not change between launches or while scrolling.
- The first eligible public Mugshot photo replaces the treatment.
- Private and friends-only photos never become cafe cover media.
- The treatment never fabricates an interior, exterior, hours, popularity, activity, or photo provenance.
- VoiceOver announces `No cafe photo yet` once for the hero.
- The production app is unchanged by these concepts until a direction or family is approved.

## Outputs

- `outputs/NP-00-ten-direction-board.png`: 2400 × 1600 comparison board.
- `outputs/NP-01-hero.png` through `outputs/NP-10-hero.png`: exact 402 × 220 point treatments exported at 3× (1206 × 660 PNG).

All illustrations reuse authorized production Mugsy artwork from `testMugshot/Assets.xcassets`.

The HTML source is deterministic. After installing the local package dependencies, `npm run export` recreates the board and all ten 3× hero PNGs.
