# Mugshot Motion Identity

Date: 2026-07-15

## Creative direction

Mugshot motion follows **quiet ritual, lively response**.

- Stillness is the default.
- Direct actions receive immediate, weighted feedback.
- Mugsy uses brief anticipation, soft lift, tiny rotation, and a quick settle.
- Coffee and steam connect progress, refresh, ritual, and celebration.
- Mugsy observes and celebrates participation. He never judges a photo, drink, rating, or routine.

## Shared native system

The implementation is code-native and has no third-party animation runtime.

- `MugsyModelView.swift` is the sole canonical character renderer.
- `MugsyAnimatedView.swift` adds progress-driven and one-shot state articulation around that renderer.
- `MugsyDesignSystem.swift` owns expressions, props, outfits, arm poses, liquid, actions, placement defaults, palette, scale metrics, and identity invariants.
- `MugsySceneResolver` selects one of ten positive scene families from semantic context and a stable identifier.
- `MugsyPhotoPlaceholderView.swift` renders size-aware, truthful photo-empty states without taking ownership of loading or failure behavior.
- `MugshotMotionSystem.swift` owns shared timing, normalization, drink appearances, and intentional haptics.
- `MugshotSignatureMotion.swift` owns composer progress, pull refresh, Taste Bloom, and ritual presentation.
- Feature views own their local interaction state. There is no global animation manager.
- `MugsyStudioView.swift` and `MotionLabView.swift` compile only in DEBUG.

Mugsy has no ambient timeline in ordinary product content. Interaction progress comes from the owning gesture or form, and event reactions run once when the action changes. A dedicated dance timeline is allowed only while an accomplishment card is visible; it pauses with the scene and resolves to a still delighted pose under Reduce Motion.

## Product integrations

### Empty states

Empty states render the canonical layered model through `MugsyPlacement`. The approved PNGs remain immutable Studio references. Context comes from stable props and expressions:

- Favorites uses the heart.
- Wishlist uses the bookmark beneath crossed arms.
- Saved cafes and Discovery use the guidebook and pen.
- Friends uses the phone.
- Journal uses the notebook.
- True Coming Soon uses the builder outfit and tools.

Cafe and sip photo-empty surfaces use the same scene language with deterministic
variation. Visited cafes resolve to the camera companion, Want to Try cafes to
the Wishlist holder, Favorites to the heart keeper, friends to the friends
phone, shared lists to the builder, and general Discovery/Map/library cafes to a
stable scout, waving, or ritual scene. List and card instances are static; one
prominent detail hero may animate. All production scene faces are positive.

The renderer appears only when a photo is genuinely absent. Loading skeletons,
download failures, offline and stale data, hidden or removed media, permissions,
and unavailable content keep their distinct truthful treatments.

Selected welcoming and empty-state placements opt into direct touch. A first tap waves, a second hops, and a third performs a short happy dance. Camera, recovery, loading, list rows, and ordinary browsing placements do not intercept taps for play.

### Accomplishment

A successful sip save uses one branded celebration rather than a generic checkmark:

- The completion card enters with a short upward settle.
- Mint, sage, latte, blush, and coffee confetti fire once.
- Mugsy performs a small looping dance while the completed result remains visible. His body lowers over alternating curved knees while both feet stay planted; the character does not simply wobble as one rigid image.
- The dance stops when the view leaves the active scene.
- Reduce Motion shows the final delighted pose and completed information without spatial motion.

### Interactive composer Mugsy

The guided and long-form composer headers derive liquid level from real required state:

1. Context or cafe selected
2. Drink named
3. Rating completed
4. Audience step reached
5. Save in progress or complete

Optional photos, captions, serving details, and private notes do not count against completion. Drink names select only a broad liquid appearance and do not alter product logic.

### Camera companion

Mugsy responds to camera readiness, focus taps, camera switching, timer countdown, shutter, successful capture, permission state, and technical failure. Gaze follows the focus point. The camera performs no image analysis or subject judgment. Mugsy remains small, dismissible, and outside the primary capture region.

### Ritual

Journal dates produce a warm ritual snapshot. The system recognizes 3, 7, 14, 30, 50, and 100 day milestones. A day away is described as rest, and returning begins a new chapter without guilt.

### Taste Bloom

Taste Bloom is an organic radial portrait rather than a precision chart. Durable taste signals supply label, confidence, and support count. VoiceOver receives a plain-language summary.

### Pull to refresh

A zero-height geometry reader derives normalized progress from real scroll offset after subtracting the resting content inset. The refresh presentation has a fixed centered footprint, contains no changing status copy, and renders nothing at rest.

- 0–20%: Mugsy appears and a first drop descends from beneath the selected feed pill
- 20–85%: the drop becomes a pour and coffee expands inside the rim
- 85–100%: the pour reaches the full coffee surface and arms the refresh
- Refreshing: the pour disappears and restrained steam begins
- Completion: short delighted settle

Native `.refreshable` remains responsible for refresh behavior and cancellation.

## Accessibility

- Reduce Motion converts reactions to static state changes or a short fade.
- VoiceOver describes product meaning, not internal visual articulation.
- Decorative character reactions are never required to operate a flow.
- Camera controls retain explicit labels and 44-point targets.
- Dynamic Type, dark appearance, error states, and Reduce Motion are inspectable in Motion Lab.
- Color never carries completion, camera, ritual, or taste meaning by itself.

## Haptics

Haptics are limited to direct thresholds: selection, refresh armed, guided-step completion, shutter, successful capture, and explicit character taps. Passive Mugsy presentation never fires haptics.

## Testing and performance

- Palette, geometry, scale, identity, placement, prop, liquid, and refresh mapping have deterministic unit coverage.
- Visual components include deterministic SwiftUI previews.
- Motion Lab offers replay, pause, reset, Reduce Motion, appearance, Dynamic Type, error and success states, gaze, camera, ritual, taste, and pull controls.
- There are no live character timelines in feed rows, empty states, or refresh indicators. The only loop is scoped to the visible accomplishment card.
- Pull progress updates only the small indicator state rather than the feed or discovery data model.
- Camera configuration and session start and stop remain outside the Mugsy system.

## Integration boundaries

The visual system consumes existing product state but does not own or mutate persistence, navigation, networking, rating rules, cafe state, journal records, camera capture, or Supabase services. The later Mobbin-led UI and UX pass must treat the canonical Mugsy API and placement registry as fixed brand constraints.
