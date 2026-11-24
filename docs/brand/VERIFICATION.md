---
document_type: living
status: current
last_verified: 2026-11-24
---

# Brand-kit verification

Current contract: **1.1.0**. Change classification: visual app assets, the native
Mugsy pose/accessory subsystem, and brand documentation/reference artifacts.
There is no networking, persistence, authentication, user-data, Supabase,
signing, marketing-version, or distribution change. Verification uses Tier 1:
scoped inspection, deterministic guards, artifact review, and a Debug compile.

## Current evidence

Checks apply to the reviewed source and local artifacts on November 24, 2026.
Publication and merge state are reported with the pull request. Source
integration does not establish an installed or distributed build.

| Check | Evidence |
| --- | --- |
| New imagery | Five OpenAI-generated photographic-style scenes reviewed and integrated; both orange hero resource names use the same accepted output |
| Mugsy visual review | All 18 generated cutouts reviewed against the original master for silhouette family, glasses, right-side handle, palette, limbs, complete props, and clear margins |
| Immutable identity | Master SHA-256 and seven native shape definitions are locked in identity/mugsy-spec.json; generated poses never become the next identity reference |
| PNG transparency | Standard-library RGBA scanline validation checks real transparent and opaque pixels, clear edges, square canvases, and recorded alpha bounds |
| Recorded rejection and repair | Initial beans output failed the matte/margin gate; an image-engine background-only correction passed and retains both attempts in its receipt |
| Native catalog | 18 typed configurations generated from one specification; existing 10 scene families consume matching catalog entries |
| Native reference renders | All 18 production SwiftUI configurations rendered offscreen on macOS in separate processes; manifest fingerprints bind previews to production code and output bytes |
| iOS compile | XcodeBuildMCP Debug build of MugshotTests for an iPhone 17 Pro / iOS 27 Simulator destination passed in 88.7 seconds; compile only, no Simulator boot or app launch |
| Compile repair | The first compile identified the new apron missing from the developer wardrobe switch; fixed before the passing compile |
| Brand exports | 25 exact native resource copies; unchanged app icon and identity master, 18 current poses, five scenes, generated tokens, exact source copy, and retained prompts |
| Browser review | Desktop 1440 and mobile 390 layouts checked; 18 gallery items, artwork/native switching, foam/mint surfaces, loaded visible images, and no horizontal page overflow |
| PDF | 24 pages exported and rendered; text extracted with catalog/code present and no replacement glyphs or exporter overflow |
| ZIP | Packaging verifies archive integrity and every packaged file hash; PACKAGE.json records version, source commit, dirty-draft state, and native baseline |
| Repository verification | Fast suite: nine passed, zero failed, zero skipped; documentation integrity, JavaScript syntax, and diff formatting passed |

The deterministic checks cannot establish optical likeness. Generated artwork
and the native rig are distinct renderings of a shared semantic pose; exact
pixel parity is not claimed. Native construction is identical across code
poses because every pose uses the same protected geometry.

The brand book's previews are macOS reference renders, not screenshots from an
installed iPhone app. The exporter uses a fresh process per pose to avoid stale
offscreen rendering resources. App behavior was not changed to accommodate an
export-only artifact.

## Reproduction

```sh
python3 scripts/mugsy-catalog.py --check
python3 scripts/brand-kit.py --check
./scripts/verify-no-simulator.sh fast
./scripts/check-documentation.sh
git diff --check
```

The fast command includes both brand guards. `mugsy-catalog.py` rejects changed
masters/core shapes, unreviewed image bytes, mismatched receipts or registration,
and stale native previews. `brand-kit.py` rejects source/export, copy, contrast,
local-link, independent-color, and photographic-receipt drift. A new native
source change requires its own appropriate compile after the guards pass.

## Historical 1.0.0 evidence

The initial extraction was documentation/static artifacts only: 14 original
assets, 12 native copy lines, eight repository checks, and a 20-page PDF.
Desktop/mobile interactions and intentional contrast failure cases were checked.
Isolated stale-token, altered-asset, and independent-color fixtures were rejected.
That evidence belongs to 1.0.0 and does not replace the current imagery/native
checks. The earlier Impeccable scan was degraded because optional HTML parser
modules were unavailable; it was never a complete accessibility audit.

## Limits

- No physical-device, production-backend, live-user, or TestFlight action occurred.
- The marketing source audit remains local source evidence. Production website
  adoption and deployment remain open.
- The five scenes are synthetic brand illustrations, not evidence of a real
  named venue, customer's drink, or current app screen.
- OpenAI's built-in image tool was used; its model version is not exposed.
- System web fonts vary by platform. The PDF uses built-in Times/Helvetica role
  fallbacks and does not redistribute native font files.
- Missing vector logo, inverse/mono mark, and CMYK masters remain explicit gaps.
  The original icon and UI palette are unchanged.
