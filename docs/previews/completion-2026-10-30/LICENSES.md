# Sources, licenses and cost boundary

Interactive production sources are retained in `testMugshot/Design` and
`testMugshot/Views/Components`. The approved Mugsy artwork/rig and all captured
UI belong to Mugshot; no new third-party character art was generated or imported.
These captures contain synthetic local fixtures only.

| Component | Retained/reproducible source | Terms / cost |
| --- | --- | --- |
| iOS animation and haptics | SwiftUI numeric rig curves, UIKit feedback APIs | Existing Apple SDK; no added tool subscription/export/royalty |
| HyperFrames CLI 0.8.185 | Exact pin in `package.json`; installed local package inspected | Apache-2.0; local check/preview/render only |
| GSAP 3.14.2 | `assets/gsap.min.js`, copyright header retained | [Standard no-charge license](https://gsap.com/standard-license/); [official commercial-use confirmation](https://webflow.com/updates/gsap-becomes-free) |
| Inter 400 | `assets/fonts/Inter-400.woff2` | SIL OFL 1.1, retained in `licenses/Inter-OFL.txt` |
| EB Garamond 700 | `assets/fonts/EBGaramond-700.woff2` | SIL OFL 1.1, retained in `licenses/EBGaramond-OFL.txt` |
| FFmpeg | Local Homebrew executable, no binary redistributed | Open-source local encoding; no added credits/export fee |

No cloud render, generation service, paid credits, new subscription, royalty,
watermark or vendor splash is used. No HyperFrames/GSAP/fonts/video is added to
the iOS app bundle. The rendered review is supplementary; live behavior remains
native, state-driven and cancellable.
