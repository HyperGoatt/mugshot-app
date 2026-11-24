---
document_type: living
status: current
last_verified: 2026-11-24
---

# Mugshot brand kit

Version **1.1.0**. This directory is Mugshot's brand authority. The app's immutable identity and tokens remain fixed; user-authorized OpenAI imagery and controlled poses are versioned here and supplied to the app. Marketing consumes the same kit.

Open the [visual brand book](index.html), use the [machine-readable policy](brand.json),
or start with the [marketing-site handoff](WEBSITE_HANDOFF.md).
This file is generated from brand.json and the native sources; edit those inputs,
then run the build command. Do not maintain a competing guide elsewhere.

## Authority and status

Brand imagery refresh and native pose catalog, implemented in source. This is not an app distribution, a marketing-site deployment, or evidence of physical-device or TestFlight acceptance.

The kit is the canonical brand contract for app, web, email, social, and future
collateral. [brand.json](brand.json) owns identity, voice, source mappings, and web
application rules. [tokens.json](tokens.json) and [tokens.css](tokens.css) are
generated from the app's existing primitive values. [assets.json](assets.json)
records exact source paths, dimensions, allowed uses, and SHA-256 hashes.
[source-manifest.json](source-manifest.json) records the audited source files.

Native source base: `1ffba7b074da7b1230942e394a477dc8a5db2911` plus this reviewed kit change. Current per-file hashes are in source-manifest.json.
The original app icon and immutable Mugsy identity master remain byte-identical.
Five photographic-style scenes and 18 pose PNGs were created with OpenAI's built-in image engine at the owner's request, then integrated as native resources.
The engine version is not exposed by the tool; no more specific model is claimed.
Every kit export is a byte-identical copy of its named native resource. Prompts
and provenance are in generation/. No stock imports, external fonts, live accounts,
or backend data are used. App distribution retains its existing acceptance gates.

Web adaptations are labeled rules, not historical native measurements. New
identity artwork still needs the product owner's explicit review under the
[Mugsy artwork authority](../MUGSY_ASSET_STATUS.md).

## Brand foundation

**Positioning:** A personal sip journal for the drink, the place, and the little moment around it.

Source-derived synthesis of native onboarding, not a new product claim.

**Audience:** People who want to remember their drinks, return to favorite cafes, and choose what they share with friends.

**Promise:** Help people remember what they enjoyed and what they want to try next.

**Personality:** Warm, Observant, Personal, Calm, Quietly playful.

**The moment comes first.** Lead with the drink and its memory. Ratings and interface details support the story.

**A journal at your pace.** Use inviting, specific language. Keep social sharing a choice and preserve audience meaning.

**Warmth, with room to breathe.** Use cream surfaces, espresso typography, gentle green accents, and generous space.

**Mugsy is a companion.** Use the existing character to guide and acknowledge. Keep his permanent identity intact.

## Name, icon, and wordmark

Write **Mugshot** and **Mugsy**. New brand copy uses this casing even where legacy
code strings vary. The existing app-icon PNG is the canonical supplied mark.

Use live text in the native regular serif role. There is no separately approved vector wordmark in the app.

- Web application rule: leave at least one quarter of the displayed icon width around an icon/name lockup; retain all padding inside the source PNG.
- Web application rule: use the full icon at least 48 CSS px wide; use a text-only name if the embedded mug loses clarity.
- Web application rule: use the app's 12 px spacing step between the displayed icon and name.
- Prefer cream or white. The original icon includes its own white canvas; do not fake transparency on dark backgrounds.

Do not redraw, trace, recolor, mirror, stretch, crop source padding, or invent
inverse/monochrome versions. Typography and surrounding layout can adapt to the
channel; the original mark stays intact.

**Asset gap:** No approved standalone vector logo, inverse logo, monochrome master, CMYK master, or favicon-size redraw exists in the audited app. Keep these as explicit gaps rather than inventing replacements.

## Color

Use cream as the canvas, espresso for primary text, roast for supporting text,
and mint for quiet accents. Accessible actions use the existing sage-text token.
Map rating colors retain their semantic purpose; they are not campaign colors.
Character colors are a separate locked palette.

| Native token | sRGB hex | Application |
| --- | --- | --- |
| `mugshotMint` | `#A8CDB8` | Accent panels and selected context. Pair with espresso text. |
| `mugshotSage` | `#6E8F7C` | Decorative sage and large graphic elements. Do not use with white for small text. |
| `mugshotSageText` | `#4D6F5D` | Accessible action fill and green text on cream, foam, and sand. |
| `mugshotMatcha` | `#8FAF6A` | Supporting drink-context accent, not a replacement primary green. |
| `mugshotLatte` | `#DCC8A6` | Supporting warm accent for drink context. |
| `mapPinHigh` | `#4F8A68` | High-rating map meaning. Always accompany with a number or label. |
| `mapPinMiddle` | `#D4AD55` | Middle-rating map meaning. Always accompany with a number or label. |
| `mapPinLow` | `#C26355` | Low-rating map meaning. Always accompany with a number or label. |
| `creamWhite` | `#FAF6F0` | Primary page canvas. The warm surface that connects app and marketing. |
| `foamWhite` | `#FFFFFF` | Cards, fields, and text on the accessible dark sage action color. |
| `espressoBrown` | `#1F1712` | Primary type, editorial headings, and high-contrast marks. |
| `roastBrown` | `#5B4636` | Body copy, supporting text, and readable secondary information. |
| `darkRoast` | `#2B1F17` | Deep brown supporting ink. |
| `sandBeige` | `#EEE6D8` | Quiet panels, secondary surfaces, and grouped controls. |
| `mugshotLine` | `#E3DED4` | Quiet separators. Insufficient by itself to identify an essential input boundary. |
| `sageGray` | `#A8CDB8` | Legacy alias of mugshotMint; do not create a separate color. |

### Accessible combinations

Ratios below are calculated from the exact sRGB tokens using relative luminance.
Normal text requires 4.5:1; large text requires 3:1. A normal-text pass is not an
app-wide accessibility certification. Always inspect the final size and context.

| Foreground / background | Contrast | Normal text | Application |
| --- | --- | --- | --- |
| espressoBrown / creamWhite | 16.40:1 | Pass | Primary text |
| roastBrown / creamWhite | 8.22:1 | Pass | Supporting text |
| espressoBrown / mugshotMint | 10.16:1 | Pass | Mint panels |
| foamWhite / mugshotSageText | 5.60:1 | Pass | Primary actions |
| mugshotSageText / creamWhite | 5.21:1 | Pass | Green links |
| mugshotSageText / sandBeige | 4.52:1 | Pass | Green text on sand |
| foamWhite / mugshotSage | 3.57:1 | Fail | Avoid for normal text |
| mugshotMint / creamWhite | 1.61:1 | Fail | Avoid as body text |

Use espresso text on mint. Use white on sage-text. Do not use white on the softer
sage token for normal text, or use mint as a pale text color on cream. A quiet
line separator is not sufficient contrast for an essential input boundary; web
fields pair a visible label with a sage-text outline. Focus is visible and
keyboard reachable. Color never carries rating, privacy, or error meaning alone.

## Typography

Native display: `.system(size: size, weight: .regular, design: .serif), tracking -0.2 pt`.

Native body: System sans; semantic text styles where implemented. Respect Dynamic Type.

| Observed native role | Default source size | Weight |
| --- | --- | --- |
| Brand name | 42 pt | 400 |
| Welcome heading | 40 pt | 400 |
| Screen heading | 30 pt | 400 |
| Body / controls | 16 pt | 500 |

Web display stack: `ui-serif, Georgia, 'Times New Roman', serif`.

Web body stack: `-apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif`.

No font binaries are bundled with the native app. No external fonts are part of this kit.
System faces vary by platform. Georgia and Times are fallbacks, not an assertion of exact SF Serif parity. PDF reference exports use built-in Times and Helvetica.

The following responsive scale is a web translation of that hierarchy. Native
point sizes are evidence, not a mandate to freeze web text at the same number.

| Web role | Size / line height | Application |
| --- | --- | --- |
| Hero | `clamp(2.5rem, 5.5vw, 5rem)` | One main marketing statement; regular serif. |
| Section | `clamp(2rem, 3vw, 3rem)` | Serif section headings with natural wrapping. |
| Body | `1rem / 1.6` | System sans, 60-70 characters per line. |
| Label | `0.875rem / 1.4` | System sans; clear sentence case. |

Use regular serif headlines, sans body copy, light tracking, and comfortable
reading measures. Wrap headings naturally. Do not replace the hierarchy with
heavy campaign sans, condensed display lettering, or downloaded font files.
Keep labels legible when text grows and preserve browser zoom.

## Spacing, shape, depth, and motion

- Native spacing steps: 4, 8, 12, 16, 20, 24, 32 pt.
  The same values become CSS px tokens; responsive section spacing composes them.
- Native radii: small 8, control 12, card 16, heroCard 20, sheet 24, pill 999 pt.
  Pill radius is a capsule convention, not a 999 px-sized object.
- Cards use the existing white surface, quiet line, 16 px radius, and soft offset
  shadow. Hero cards may use 20 px; sheets use 24 px. Pills belong to controls.
- Native shadow vocabulary: card, subtle, and overlay; see tokens.json for exact
  offsets and opacity. Glass is a contextual native material, not the marketing canvas.
- Native base transitions are 150, 200, and 250 ms ease-out, with a 0.98 press
  scale. Web easing approximates the native curve; it is not a spring simulation.
- Quiet at rest, responsive to interaction, briefly expressive on completion. No ambient mascot loop in marketing. Honor reduced motion with a still pose.

## Component translation

Use the [interactive specimens](index.html#components) and tokens.css together.

| Component | Contract |
| --- | --- |
| Primary action | Sage-text fill, white semibold sans text, capsule, 24 px horizontal / 13 px vertical padding. Web minimum target 44 px. |
| Secondary action | White fill, espresso label, quiet line, capsule, 24 px horizontal / 12 px vertical padding. |
| Field | Persistent label, white fill, espresso value, 12 px radius, visible sage-text outline. Placeholder is supplementary. |
| Card | Photo or content first; white surface, 16 px corners, quiet border and native soft offset shadow. |
| Chip / filter | Capsule; selected state has readable text and a semantic selected attribute. The 44 px web hit area can exceed its visual height. |
| Rating | Keep the score with an explicit out-of-five label. A number or rating never replaces the drink photo as the main visual. |
| Navigation | Clear text labels and one active state. Web layouts use their own responsive composition while preserving hierarchy. |
| Empty / error | Use approved positive contextual Mugsy scenes for true emptiness. Do not represent failures, hidden content, or permission denial as missing photography. |

The accessible web action token and field outline are intentional translations.
Older native controls can still use softer sage or quiet borders. This kit does
not silently change native code or claim those instances have been migrated.
SF Symbols remain native implementation evidence; no symbol glyphs or font
binaries are exported into this web kit.

## Mugsy

- MugsyIdentityMaster freezes the original front-facing Mugsy artwork byte-for-byte. It is the reference for every new pose, not a pose to redraw.
- White ceramic, the same asymmetric body, rim, right-side handle, glasses, cheek placement, thin limbs, and compact feet stay fixed.
- Seven native identity shapes are locked by SHA-256. The renderer shares them across all 18 configurations.
- Only expression, gaze, articulated limbs, liquid, outfits, and named accessories vary. Props never replace anatomy or hide the glasses.
- Every generation references the immutable master. Full prompts and generation provenance are saved. No identity is recursively re-created from another generated pose.
- Each PNG must have true alpha, complete clear margins, a square canvas, an exact reviewed hash, and a recorded optical identity review.
- Alpha-derived display registration makes poses fit consistently without altering or cropping the PNG source.
- Generated artwork and code-native renders share semantic pose mappings. They are distinct renderings, not a claim of pixel-identical output.
- Use native geometry for dynamic product states and generated PNGs for static illustration. Native core construction stays authoritative.
- Use the builder only for coming-soon or maintenance. Keep accessories context-specific and expressions positive.
- Artwork colors remain separate from UI tokens. Never recolor the ceramic body.
- Original legacy rasters are archived under identity/legacy-originals; outdated baked onboarding panels are excluded from the current kit.

The original identity is frozen in [the identity contract](identity/README.md).
The 18 current positive poses include generated cutouts and separate native
render previews. Original supporting poses are archived as historical references.
Production scene details remain in the
[canonical Mugsy subsystem](../MUGSY_DESIGN_SYSTEM.md).

## Photography and product imagery

- Use the five current OpenAI-generated photographic-style brand scenes supplied in assets.json. They replace the old drink, latte, cafe, and orange-peel imagery.
- Photographic realism means plausible ice and condensation, fine milk texture, natural light, real material detail, and restrained color. Avoid glossy synthetic rendering and excessive garnish.
- These are fictional illustrative brand scenes, not captured customer drinks, named real cafes, testimonials, or release evidence.
- Keep source PNGs intact. Responsive display crops may preserve the drink focal point; do not distort images.
- Use solid cream behind text when image contrast would be uncertain.
- Use current named Mugsy poses with the immutable identity contract; do not generate a new Mugsy identity.
- Legacy baked onboarding composites remain historical native resources and are not the current brand imagery or screenshots of a new build.
- No personal journal, private note, live account, or production service data enters the imagery.

## Voice and writing

**Voice profile:** Warm, concrete, observant, and unhurried. Short serif-worthy headlines; plain explanatory body copy; verbs that describe what happens next.

Speak to the person as you. Use we only for a real Mugshot action or responsibility. Mugsy is a named companion, not the narrator of every sentence.
Favor short statements and natural fragments in headlines. Follow with one useful sentence. Keep UI labels literal.
Mugshot, Mugsy, Map, Feed, Saved, Journal, Friends, Favorites, Want to Try, Lists. Sentence case in new copy; preserve the sourced Capture Every Sip headline.
Always cafe and cafes, using ASCII e.

| Context | Tone rule |
| --- | --- |
| Invitation | Warm and specific. Lead with the memory and let the person choose. |
| Instruction | Literal action, useful object, clear outcome. |
| Success | Calm acknowledgement. Celebrate the completed action, not a promised future save. |
| Error | Say what is known, what remains safe, and the next available action. Use no blame. |
| Privacy | Use exact audience semantics. Separate private notes from a post's chosen audience. |

Avoid hype, rankings, invented numbers, pressure, jargon, and release claims
that lack current evidence. Do not imply social sharing is mandatory.

**Privacy language:** Private means owner-only. Friends means confirmed mutual friends. Everyone means public. Private notes stay private. Describe the selected audience rather than promising blanket privacy.

### Copy library

These lines exist in the native app and are checked against their exact source.
Use them as the starting point for marketing. They are identity language, not
proof that every pictured feature is available in a current distributed build.

| Role | App-source copy |
| --- | --- |
| Primary brand headline | Capture Every Sip |
| Short introduction | The drink. The place. The little moment around it. Mugshot helps you remember it all. |
| Drink range | Coffee, matcha, tea, and everything between. Mugsy keeps the little moments that would otherwise disappear. |
| Map headline | Watch your world take shape. |
| Saved headline | Never forget the cafe you meant to try. |
| Saved explanation | Favorites, Want to Try, and Lists keep the next plan one tap away. |
| Journal headline | A memory, not just a rating. |
| Journal explanation | Keep the photo, the feeling, the recipe, and the details you would otherwise forget. |
| Friends headline | Your people. Your pace. Your privacy. |
| Private notes | Private notes stay private. Choose who can see each post you share. |
| Tasting principle | Your reaction is the score |
| Account invitation | Start your sip journal. |

## Reference applications

| File | Format | Purpose |
| --- | --- | --- |
| [Website reference](templates/landing.html) | Responsive HTML | Cream-led landing page with source imagery, serif hierarchy, and sage actions. |
| [Square social](templates/social-square.html) | 1080 x 1080 composition | Photo and journal headline; editable HTML with print styling. |
| [Portrait social](templates/social-portrait.html) | 1080 x 1350 composition | Drink photo, Capture Every Sip, and a quiet brand signature. |
| [Email reference](templates/email.html) | Responsive table HTML | Original app icon, cream surface, source copy, and an explicit CTA integration slot. |

Templates use the current imagery and remain editable local HTML references. They make no App Store, beta,
pricing, or live-account claim. Email has an explicit link-integration slot;
social templates have fixed composition ratios and print CSS. Check the real
audience, destination, and release state before publishing any downstream work.

## Asset library

| Asset | Original pixels | Use |
| --- | --- | --- |
| [app-icon](assets/mugshot-app-icon.png) | 1024 x 1024 | Unchanged original app icon; retain its full source canvas. |
| [mugsy-identity-master](assets/mugsy-identity-master.png) | 500 x 500 | Immutable original identity reference; do not replace it with a generated variant. |
| [mugsy-wave](assets/mugsy-wave.png) | 1254 x 1254 | Welcome wave; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-wishlist](assets/mugsy-wishlist.png) | 1254 x 1254 | Want to Try; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-favorites](assets/mugsy-favorites.png) | 1254 x 1254 | Favorites; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-scout](assets/mugsy-scout.png) | 1254 x 1254 | Cafe scout; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-friends](assets/mugsy-friends.png) | 1254 x 1254 | Friends hello; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-builder](assets/mugsy-builder.png) | 1254 x 1254 | Careful builder; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-camera](assets/mugsy-camera.png) | 1254 x 1254 | Camera companion; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-journal](assets/mugsy-journal.png) | 1254 x 1254 | Journal keeper; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-cozy](assets/mugsy-cozy.png) | 1254 x 1254 | Cozy ritual; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-celebrate](assets/mugsy-celebrate.png) | 1254 x 1254 | First-sip celebration; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-map](assets/mugsy-map.png) | 1254 x 1254 | Map explorer; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-beans](assets/mugsy-beans.png) | 1254 x 1254 | Bean keeper; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-matcha](assets/mugsy-matcha.png) | 1254 x 1254 | Matcha maker; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-pourover](assets/mugsy-pourover.png) | 1254 x 1254 | Pour-over barista; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-takeaway](assets/mugsy-takeaway.png) | 1254 x 1254 | Takeaway companion; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-tasting](assets/mugsy-tasting.png) | 1254 x 1254 | Taste explorer; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-guide](assets/mugsy-guide.png) | 1254 x 1254 | Helpful guide; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [mugsy-pause](assets/mugsy-pause.png) | 1254 x 1254 | Quiet pause; reviewed OpenAI-generated pose, paired with MugsyCatalogPose. |
| [orange-hero](assets/orange-hero.png) | 1536 x 1024 | OpenAI-generated signature iced coffee and orange-peel scene; not a real venue claim. |
| [orange-square](assets/orange-square.png) | 1254 x 1254 | OpenAI-generated square signature drink scene. |
| [orange-detail](assets/orange-detail.png) | 1254 x 1254 | OpenAI-generated close view of ice, milk, glass, and orange peel. |
| [latte](assets/creamy-latte.png) | 1254 x 1254 | OpenAI-generated flat white and ceramic texture scene. |
| [cafe-corner](assets/cafe-corner.png) | 1254 x 1254 | OpenAI-generated fictional neighborhood cafe; no named venue claim. |

Additional exported resources: [Adobe swatches](palette.ase), [plain RGB palette](palette.gpl),
[CSS tokens](tokens.css), and [JSON tokens](tokens.json).
The optional PDF and ZIP exports are derived distribution artifacts; their
source remains this versioned directory. Generated local output is not committed.

## Governance and adoption

Owner: **Mugshot product owner**.
Any identity change updates this kit, its source mapping, the changelog, and affected consumers in the same reviewed change. Do not create a competing palette or voice guide in a downstream repository.

Patch: clarification or export repair. Minor: compatible addition. Major: changed identity, semantics, or a breaking token contract.

Pin the kit version and source commit. Import tokens.css; use the manifest assets and copy library. Record adoption before claiming the marketing site conforms.

1. Read this guide and the website handoff before changing a Mugshot surface.
2. Update brand.json for editorial policy; update the native owning file for a
   primitive change. Review whether the version must change.
3. Run `python3 scripts/brand-kit.py --build` to regenerate exports and exact asset copies.
4. Run `python3 scripts/brand-kit.py --check`, `./scripts/check-documentation.sh`,
   and `git diff --check`. Inspect the complete scoped diff.
5. Review desktop/mobile layouts, focus, text growth, contrast, source asset use,
   truthful copy, and motion where a consumer UI changes.
6. Publish through a reviewed branch and PR; record actual adoption separately
   from the existence of the kit. Follow app release gates for app delivery.

`--check` verifies source-to-export equality, exact copy strings, accessible
approved pairs, local links, asset hashes, and generated token outputs. It fails
when exports drift. Rebuilding is an intentional change to review, not a way to
silently accept a changed identity.

Run `python3 scripts/mugsy-catalog.py --check` to verify the immutable master,
seven core shapes, typed catalog, reviewed image hashes, alpha, margins, and
native preview freshness. Generation still requires optical identity review.
`python3 scripts/render-mugsy-catalog.py` renders native references on macOS
from production SwiftUI source without launching a Simulator.

To package a handoff, run `python3 scripts/brand-kit.py --package`. The ZIP
contains the standalone brand book, templates, assets, tokens, swatches, and
provenance manifests. Its PACKAGE.json pins version and file hashes. PDF export
is optional via `scripts/brand-kit-pdf.py` and requires ReportLab.

## Source evidence

- [palette](../../testMugshot/Design/BrandColors.swift)
- [system](../../testMugshot/Design/DesignSystem.swift)
- [motion](../../testMugshot/Design/MugshotMotionSystem.swift)
- [character](../../testMugshot/Design/MugsyDesignSystem.swift)
- [onboarding](../../testMugshot/Views/Onboarding/MugshotOnboardingView.swift)
- [authentication](../../testMugshot/Views/Auth/AuthEntryView.swift)
- [character rules](../../docs/MUGSY_DESIGN_SYSTEM.md)
- [artwork authority](../../docs/MUGSY_ASSET_STATUS.md)
- [character rig](../../testMugshot/Views/Components/MugsyModelView.swift)
- [pose catalog](../../testMugshot/Design/MugsyPoseCatalog.swift)
- [identity contract](../../docs/brand/identity/mugsy-spec.json)

See [verification](VERIFICATION.md) for completed checks and explicit limits.
See [marketing-site handoff](WEBSITE_HANDOFF.md) for the observed drift and
the acceptance contract for adopting this kit.
