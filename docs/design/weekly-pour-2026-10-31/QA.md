# Design prototype verification — October 31, 2026

Status: **native prototype verified for design review; approval pending**.
This is not production recap integration, real-user activity, notification receipt,
physical prototype acceptance or TestFlight delivery.

## Evidence

- The isolated Debug Simulator app compiles with the retained SwiftUI proposal
  substituted only into the detached authoring host. The active production app
  source, project and backend remain unchanged. Bundle/backend/analytics guards
  pass before install or capture.
- Fourteen actual native Simulator states are captured at 1206 x 2622 pixels,
  with only the 62-point status area and 34-point home indicator cropped.
  Every retained screen is visually inspected. Changed scenes are recaptured;
  unchanged views reuse valid captures. The largest-text quiet week keeps
  navigation available while its content scrolls.
- The native walkthrough contains all thirteen normal-size scenes, including the
  real 3D caption turn and sparse/photo-free variants. `film-evidence.json`
  records native-frame matching. The exported file is also verified after
  encoding; this prevents a seek/timestamp error from silently dropping a scene.
- Native touch acceptance opens the saved caption, verifies its readable
  accessibility label, advances through Places/Repeat/Ending, opens the share
  preview, confirms the default three non-private moments and switches to five
  only after explicit private-Home inclusion. No image or message is shared.
- The review page opens in the in-app browser. Chapter selection, caption/back
  preview and next-chapter routing work. Its motion player uses the actual native
  recording; it is not a recreated web animation or shipping interaction.
- Supplementary HyperFrames check: zero errors/warnings; zero layout issues across
  nine samples; 31/31 HTML text contrast checks pass WCAG AA. The animation map
  covers eight tweens without flags. Its three-second still hold is intentional
  reading time. The six-second local render is inspected. These checks do not
  establish app-wide accessibility compliance.
- Shared typography/palette/rig are reviewed. Small labels on solid/half-mint
  surfaces use espresso ink after calculated sage contrast of 3.23/4.15 was
  rejected. Existing sage text remains on compatible light surfaces. Native
  notes use recorded facts; unrated does not become zero.
- Python/shell syntax, complete scoped diff, credential-pattern review, repository
  fast checks and documentation integrity pass before repository delivery.
  No backend, full app journey or Release test is repeated for this isolated
  presentation proposal; existing publishing evidence remains separate.

## Corrections made during authoring

1. Offscreen ImageRenderer omitted ScrollView content. Those blank exports were
   rejected and replaced with captures of the running native app.
2. Initial scene activation could leave entrance phase at zero. The authoring
   task now handles the first active page once, settles on inactivity and avoids
   replay on simple resume.
3. Mugsy overlapped remembered dates. His position was corrected and recaptured.
4. One-page alternatives initially inherited six progress segments. They now
   display one segment and an accurate accessible chapter count.
5. An input-seek export changed variable-frame timestamp behavior. Filter-based
   trim, timestamp reset and constant output cadence preserve the full native
   story. Both source and encoded scene presence are checked.
6. Wave-swing articulation overrode a prop-holding arm pose during entry. Props
   retain their normal hand pose; only prop-free Mugsy uses the wave controls.
7. The caption's accessible label now includes the caption itself.

## Reproduction and cost

`prepare.sh`, `capture.py`, `film.py` and `boards.py` retain the complete local
workflow. The CLI and renderer use the already installed HyperFrames 0.8.185.
Its animation-map helper needed the separate public Apache-2.0
`@hyperframes/producer@0.8.185`; Codex installed it into a temporary audit folder
with install scripts disabled and inspected its license. It is not added to the
iOS app or review runtime. Native source/art and all license records remain
editable locally. Additional subscription/export/generation cost: **$0**.

## Approval and remaining work

The owner approves the visual direction, chapter model and interactions before
production mapping. Real activity selection, archive occurrence endpoints,
ownership/media/privacy handling, notification rollout, final accessibility and
performance acceptance then receive focused integration tests. No mockup screenshot,
fixture install or rendered film proves those later gates.
