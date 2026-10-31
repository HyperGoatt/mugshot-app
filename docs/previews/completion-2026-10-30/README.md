# Implemented native completion previews

All captures use the production SwiftUI receipt/rig/reflection components with
explicit local fixtures, a synthetic `.invalid` backend and disabled production
analytics. Simulator videos and physical screenshots are distinguished below;
neither establishes TestFlight acceptance. No production account content is included.

October 31 connected-iPhone evidence uses the same native components on an
iPhone 16 Pro / iOS 27.0.1 in the separate signed **Mugshot Motion QA** app:

- [Social completion](assets/physical/social-completion.png),
  [private save](assets/physical/private-save.png) and
  [other-owner result hidden](assets/physical/wrong-owner-hidden.png).
- [Actual fixture week](assets/physical/week.png) and
  [quiet week](assets/physical/quiet-week.png).
- [Largest-text reduced-motion quiet week](assets/physical/quiet-week-accessible-reduced.png)
  and [concise receipt](assets/physical/receipt-accessible-reduced.png).
- Sanitized [default acceptance](assets/physical/acceptance.json),
  [accessible acceptance](assets/physical/accessible-acceptance.json), and
  [source/package provenance](assets/physical/provenance.json).
- [Background return](assets/physical/background-return.png) and
  [lifecycle acceptance](assets/physical/lifecycle-acceptance.json): same-process
  reopening leaves playback cancelled, with no later receipts after returning.

These are timed native screenshots, not a physical animation recording; this
device rejects CoreDevice screen recording. Only the top 170 status-bar pixels
are cropped to remove the originating-app breadcrumb; app content is unchanged.
The DEBUG state sequence completed, validated three fresh account-scoped
receipts, rejected another owner and exercised actual/quiet weeks. Simulator UI
journeys establish touch routing because current tools expose no physical taps.
VoiceOver was enabled and restored off; its first-use prompt prevented spoken
acceptance. The owner judged the original haptics too weak. The stronger medium/
heavy revision is installed and played; the owner accepted it as comfortable and good.
Reproduce physical capture with the [isolated hardware workflow](../../IOS_QA_EFFICIENCY_FRAMEWORK.md#isolated-connected-iphone-motion-fixture).

Review the implemented behavior:

- [Motion review MP4](review.mp4) and [still](review.png): actual native coffee-fill,
  blink/gaze, planted-foot bend, delighted wave and clean settle.
- [Native completion](assets/completion.mp4), [Reduce Motion](assets/reduced.mp4)
  and [largest accessible text receipt](assets/large.mp4).
- [Week in review](assets/week-in-review.png), using two canonical fixture entries
  and one completed private Home save; the unrated save does not lower the average.
- [Publishing after failure/background/retry](assets/publishing-retry.png), captured
  in the actual composer Share Hub after successful local-fixture completion.
- [Quiet week at default size](assets/quiet-week-default.png) and
  [actual accessibility5 with Reduce Motion](assets/quiet-week-large.png).
  The latter includes the corrected sheet environment and immediate Done control.
- [Reopened receipt](assets/reopened-receipt.png); durable consumption suppresses
  a second celebration for the same account/operation.

The interactive sources remain editable in
[MugshotCompletionPlan.swift](../../../testMugshot/Design/MugshotCompletionPlan.swift),
[MugshotSaveReceiptView.swift](../../../testMugshot/Views/Components/MugshotSaveReceiptView.swift),
and [MugsyModelView.swift](../../../testMugshot/Views/Components/MugsyModelView.swift).
The DEBUG inspection route includes replay, same-operation reopening, private
versus social, quick save, another account, quiet weeks, and a rig scrubber.
It is excluded from Release.

Reproduce a capture from the repository root:

```sh
./scripts/capture-completion-preview.sh expressive
./scripts/capture-completion-preview.sh reduced
./scripts/capture-completion-preview.sh large
```

The script compiles a signed Debug fixture app and uses a booted iPhone
Simulator. Codex can select/boot one with the installed Build iOS Apps plugin.
Set `MUGSHOT_PREVIEW_APP` to reuse an already verified fixture app; the script
checks its bundle/backend/analytics configuration before installation.
It never targets hardware or production. Raw captures remain in `/tmp`; the
small retained MP4/PNG files are review artifacts and never enter the app bundle.
Only the system launch is trimmed; the final native frame is held for reading.
The interactive completion itself remains 1.32 seconds.

This supplementary HyperFrames project presents the native capture without
recreating its interactive animation. From this directory:

```sh
npm ci --ignore-scripts
npm run check
npm run dev
npm run render
```

The scripts pin HyperFrames 0.8.185 and disable skill updates and telemetry.
Codex installed the locked free dependencies locally; node_modules is ignored.
Only local check, preview and render run. Retained local fonts and GSAP make the
composition independent of a CDN at render time. See [licenses and cost](LICENSES.md)
and [visual identity](DESIGN.md). Full acceptance and delivery evidence is in the
[implementation ledger](../../audits/PUBLISHING_COMPLETION_MOTION_2026-10-30.md).

The CLI local preview server ran, but opening its browser UI was blocked by Work
settings. Codex inspected the local rendered frames instead. The final review is
1920 x 1080, 30 fps, six seconds, silent, with no vendor splash or watermark.
Native recordings hold the final frame for reading; they do not slow the live UI.
