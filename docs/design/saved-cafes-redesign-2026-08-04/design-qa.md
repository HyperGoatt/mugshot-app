# Saved Cafes Checkpoint Design QA

Final result: passed

## Evidence

- Source visual truth: `concepts/00-locked-combined-direction.png`
- Browser-rendered implementation: `screens/CF-12-map-tab-saved-cafe-detail.png`
- Additional checkpoint implementations:
  - `screens/CF-01-favorites-populated.png`
  - `screens/CF-03-all-cafes-union.png`
  - `screens/CD-03-detail-expanded-top.png`
- Full-view comparison: `checkpoints/QA-map-source-and-implementation.png`
- Focused sheet comparison: `checkpoints/QA-detail-sheet-focus.png`
- Source pixels: 851 × 1848.
- Implementation pixels: 1206 × 2622, representing a 402 × 874 point app frame at 3×.
- CSS viewport for logical masters: 402 × 874.
- Interactive mobile-runtime verification: 393 × 852 CSS pixels at scale 1 inside the iPhone device screen.
- Density normalization: the source was normalized to 402 × 874 for side-by-side comparison. Final screen exports were rendered in three native-density 1206 × 874 strips and losslessly stacked to 1206 × 2622; they were not enlarged from 1× masters.
- State: light appearance, Harborlight selected from the existing Map tab, initial compact detail detent.

## Findings

No actionable P0, P1, or P2 findings remain.

- Typography: Source Serif 4 carries screen and cafe identity; system SF-style text carries controls and metadata. The implementation preserves the reference hierarchy while using deterministic text. Wrapping is intentional and no essential checkpoint copy clips.
- Spacing and layout: the Saved screens use 16-point margins, comfortable cards, 44-point-or-larger interactive targets, restrained elevation, and the approved dock. The Map keeps the compact horizontal query bar and gives the initial compact sheet more map context than the medium reference state.
- Colors and tokens: cream, foam, espresso, roast, sage, mint, sand, and divider tokens match the locked Mugshot direction. Primary actions use the accessible sage variant with white at 5.60:1; selected sage text on mint measures 4.55:1. Favorite and Want to Try use icon, fill, border, label, and accessibility value rather than color alone.
- Image quality and assets: final checkpoints are native 3× exports. Authorized Mugshot media is used for populated cafe imagery. The branded Mugsy treatment is used for cafes without authorized media; no external cafe imagery or fabricated stock content is present.
- Copy and content: `cafe` and `cafes` are used consistently. Personal signals are labeled as personal. Photo provenance is visible on the expanded detail hero.
- Icons: Lucide supplies a single consistent stroke family; stateful icons receive the approved fills without custom SVG or CSS-drawn replacements.
- Accessibility: measured checkpoint controls are at least 44 × 44 points. Semantic tabs, pressed states, action labels, image alternatives, and the Map/detail close control are exposed in the DOM. VoiceOver and motion remain specification targets for later device verification, not claims made by these static checkpoints.

## Intentional Differences From the Anchor

- The anchor shows a medium sheet; the Map checkpoint shows the approved initial compact detent. The same action hierarchy appears in the medium and expanded components.
- The anchor shows a Favorites scope example; the checkpoint uses the approved default `All` scope.
- The checkpoint retains the iOS status area and the existing Map-tab boundary. These are product constraints, not visual drift.

## Comparison History

1. Initial pass found a P2 stale Map legend and old source chrome visible behind the new compact sheet. Fixed by using the clean locked Map source and an explicit safe-area treatment. Post-fix evidence: `screens/CF-12-map-tab-saved-cafe-detail.png`.
2. Initial pass found a P2 oversized compact sheet with unused blank space. Fixed by tightening the compact detent to the content hierarchy. Post-fix evidence: `checkpoints/QA-detail-sheet-focus.png`.
3. Initial pass found a P2 filled Log a Sip symbol that read as a dot. Fixed by removing the inappropriate fill from CirclePlus. Post-fix evidence: all four final checkpoint screens.
4. Runtime QA found a P2 1345-point app surface inside an 852-point device screen. Fixed by constraining the app-specific mobile-scroll content and mock screen to the runtime viewport. Post-fix measurement: device screen 393 × 852; mock screen 393 × 852.
5. Accessibility QA found P2 segmented and toolbar controls below 44 points. Fixed by making segment targets and toolbar actions at least 44 points. Post-fix browser measurement found no visible checkpoint button below 44 × 44.
6. Export QA found a P2 image-density loss in mechanically enlarged 1× drafts. Fixed with native-density strip rendering and lossless stacking. Post-fix exports are sharp 1206 × 2622 PNGs.

## Primary Interactions Tested

- Favorites to All Cafes section change.
- Saved cafe card to shared medium cafe detail.
- Detail close returns to the originating All Cafes context.
- Saved dock to existing Map tab and back to the preserved Saved section.
- Runtime device screen and mock screen remain 393 × 852 at scale 1.
- Browser console warnings/errors checked: none.

## Follow-up Polish

- P3: after checkpoint approval, tune the exact Map compact-to-medium transition and motion curve in the specification board; static PNGs cannot verify motion or VoiceOver focus behavior.

## Verification

- `npm run check:runtime` passed for all 28 protected runtime files.
- `npm run build` passed.
- Four final PNGs inspected at 1206 × 2622.
