#!/usr/bin/env python3
"""Build/check the app-derived brand contract with the Python standard library.

No network calls, app build, user content, or backend access. Run from any cwd.
Native token or asset drift requires an intentional kit/version review.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "docs/brand"
CONFIG = KIT / "brand.json"

MUGSY_SPEC = KIT / "identity/mugsy-spec.json"
POSES = json.loads(MUGSY_SPEC.read_text())["poses"]
ASSETS = [
    ("app-icon", "AppIcon.appiconset/mugshot-app-icon.png", "mugshot-app-icon.png", "identity", "Unchanged original app icon; retain its full source canvas."),
    ("mugsy-identity-master", "MugsyIdentityMaster.imageset/mugsy-identity-master.png", "mugsy-identity-master.png", "character-master", "Immutable original identity reference; do not replace it with a generated variant."),
    *[("mugsy-" + pose["id"], pose["asset_name"] + ".imageset/" + pose["asset_name"] + ".png", pose["export_name"], "character-pose", pose["title"] + "; reviewed OpenAI-generated pose, paired with MugsyCatalogPose." ) for pose in POSES],
    ("orange-hero", "V3OrangeCreamsicleHeroV2.imageset/v3-orange-creamsicle-hero-v2.png", "orange-hero.png", "photography", "OpenAI-generated signature iced coffee and orange-peel scene; not a real venue claim."),
    ("orange-square", "V3OrangeCreamsicleSquare.imageset/v3-orange-creamsicle-square.png", "orange-square.png", "photography", "OpenAI-generated square signature drink scene."),
    ("orange-detail", "V3OrangeCitrusDetail.imageset/v3-orange-citrus-detail.png", "orange-detail.png", "photography", "OpenAI-generated close view of ice, milk, glass, and orange peel."),
    ("latte", "V3CreamyLatte.imageset/v3-creamy-latte.png", "creamy-latte.png", "photography", "OpenAI-generated flat white and ceramic texture scene."),
    ("cafe-corner", "V3QuietCafeCorner.imageset/v3-quiet-cafe-corner.png", "cafe-corner.png", "photography", "OpenAI-generated fictional neighborhood cafe; no named venue claim."),
]


def encoded(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode()


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def css_key(name: str) -> str:
    if name.startswith("mugshot"):
        name = name[7:]
    return re.sub(r"(?<!^)(?=[A-Z])", "-", name).lower()


def luminance(hex_value: str) -> float:
    channels = [int(hex_value[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return sum(c * w for c, w in zip(linear, (0.2126, 0.7152, 0.0722)))


def ratio(foreground: str, background: str) -> float:
    light, dark = sorted((luminance(foreground), luminance(background)), reverse=True)
    return (light + 0.05) / (dark + 0.05)


def read_scale(source: str, enum: str) -> dict[str, int]:
    body = re.search(r"enum " + enum + r"\s*\{([^}]+)\}", source)
    if not body:
        raise ValueError(f"Missing native {enum} scale")
    return {name: int(value) for name, value in re.findall(r"static let (\w+): CGFloat = (\d+)", body[1])}


def palette_ase(colors: dict[str, str]) -> bytes:
    blocks = []
    for name, value in colors.items():
        label = (name + "\0").encode("utf-16-be")
        channels = [int(value[i:i + 2], 16) / 255 for i in (1, 3, 5)]
        body = struct.pack(">H", len(name) + 1) + label + b"RGB " + struct.pack(">fffH", *channels, 0)
        blocks.append(struct.pack(">HI", 1, len(body)) + body)
    return b"ASEF" + struct.pack(">HHI", 1, 0, len(blocks)) + b"".join(blocks)


def render_readme(brand: dict, tokens: dict, assets: list, contrast: list) -> str:
    colors = "\n".join(f"| `{key}` | `{value}` | {brand['color_usage'][key]} |" for key, value in tokens["color"].items())
    pairs = "\n".join(f"| {p['foreground']} / {p['background']} | {p['ratio']:.2f}:1 | {'Pass' if p['normal_text'] else 'Fail'} | {p['use']} |" for p in contrast)
    type_rows = "\n".join(f"| {r['role']} | {r['size']} pt | {r['weight']} |" for r in brand["typography"]["native_roles"])
    web_rows = "\n".join(f"| {r['role']} | `{r['value']}` | {r['purpose']} |" for r in brand["typography"]["web_roles"])
    copy_rows = "\n".join(f"| {r['role']} | {r['text']} |" for r in brand["copy"])
    asset_rows = "\n".join(f"| [{a['id']}]({a['path']}) | {a['width']} x {a['height']} | {a['use']} |" for a in assets)
    principles = "\n\n".join(f"**{p['title']}** {p['body']}" for p in brand["positioning"]["principles"])
    character = "\n".join(f"- {r}" for r in brand["character"]["rules"])
    imagery = "\n".join(f"- {r}" for r in brand["imagery"]["rules"])
    tones = "\n".join(f"| {r['context']} | {r['rule']} |" for r in brand["voice"]["tones"])
    apps = "\n".join(f"| [{r['name']}]({r['path']}) | {r['format']} | {r['purpose']} |" for r in brand["applications"])
    sources = "\n".join(f"- [{key.replace('_', ' ')}](../../{path})" for key, path in brand["sources"].items())
    return f"""---
document_type: living
status: current
last_verified: {brand['last_verified']}
---

# Mugshot brand kit

Version **{brand['version']}**. {brand['authority']}

Open the [visual brand book](index.html), use the [machine-readable policy](brand.json),
or start with the [marketing-site handoff](WEBSITE_HANDOFF.md).
This file is generated from brand.json and the native sources; edit those inputs,
then run the build command. Do not maintain a competing guide elsewhere.

## Authority and status

{brand['scope']}

The kit is the canonical brand contract for app, web, email, social, and future
collateral. [brand.json](brand.json) owns identity, voice, source mappings, and web
application rules. [tokens.json](tokens.json) and [tokens.css](tokens.css) are
generated from the app's existing primitive values. [assets.json](assets.json)
records exact source paths, dimensions, allowed uses, and SHA-256 hashes.
[source-manifest.json](source-manifest.json) records the audited source files.

Native source base: `{brand['source_revision']}` plus this reviewed kit change. Current per-file hashes are in source-manifest.json.
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

**Positioning:** {brand['positioning']['description']}

{brand['positioning']['status']}

**Audience:** {brand['positioning']['audience']}

**Promise:** {brand['positioning']['promise']}

**Personality:** {', '.join(brand['positioning']['personality'])}.

{principles}

## Name, icon, and wordmark

Write **Mugshot** and **Mugsy**. New brand copy uses this casing even where legacy
code strings vary. The existing app-icon PNG is the canonical supplied mark.

{brand['logo']['wordmark_rule']}

- {brand['logo']['clear_space']}
- {brand['logo']['minimum']}
- {brand['logo']['lockup_gap']}
- {brand['logo']['backgrounds']}

Do not redraw, trace, recolor, mirror, stretch, crop source padding, or invent
inverse/monochrome versions. Typography and surrounding layout can adapt to the
channel; the original mark stays intact.

**Asset gap:** {brand['logo']['gap']}

## Color

Use cream as the canvas, espresso for primary text, roast for supporting text,
and mint for quiet accents. Accessible actions use the existing sage-text token.
Map rating colors retain their semantic purpose; they are not campaign colors.
Character colors are a separate locked palette.

| Native token | sRGB hex | Application |
| --- | --- | --- |
{colors}

### Accessible combinations

Ratios below are calculated from the exact sRGB tokens using relative luminance.
Normal text requires 4.5:1; large text requires 3:1. A normal-text pass is not an
app-wide accessibility certification. Always inspect the final size and context.

| Foreground / background | Contrast | Normal text | Application |
| --- | --- | --- | --- |
{pairs}

Use espresso text on mint. Use white on sage-text. Do not use white on the softer
sage token for normal text, or use mint as a pale text color on cream. A quiet
line separator is not sufficient contrast for an essential input boundary; web
fields pair a visible label with a sage-text outline. Focus is visible and
keyboard reachable. Color never carries rating, privacy, or error meaning alone.

## Typography

Native display: `{brand['typography']['native_display']}`.

Native body: {brand['typography']['native_body']}

| Observed native role | Default source size | Weight |
| --- | --- | --- |
{type_rows}

Web display stack: `{brand['typography']['web_display']}`.

Web body stack: `{brand['typography']['web_body']}`.

{brand['typography']['font_files']}
{brand['typography']['portability']}

The following responsive scale is a web translation of that hierarchy. Native
point sizes are evidence, not a mandate to freeze web text at the same number.

| Web role | Size / line height | Application |
| --- | --- | --- |
{web_rows}

Use regular serif headlines, sans body copy, light tracking, and comfortable
reading measures. Wrap headings naturally. Do not replace the hierarchy with
heavy campaign sans, condensed display lettering, or downloaded font files.
Keep labels legible when text grows and preserve browser zoom.

## Spacing, shape, depth, and motion

- Native spacing steps: {', '.join(str(v) for v in tokens['space'].values())} pt.
  The same values become CSS px tokens; responsive section spacing composes them.
- Native radii: {', '.join(f"{k} {v}" for k, v in tokens['radius'].items())} pt.
  Pill radius is a capsule convention, not a 999 px-sized object.
- Cards use the existing white surface, quiet line, 16 px radius, and soft offset
  shadow. Hero cards may use 20 px; sheets use 24 px. Pills belong to controls.
- Native shadow vocabulary: card, subtle, and overlay; see tokens.json for exact
  offsets and opacity. Glass is a contextual native material, not the marketing canvas.
- Native base transitions are 150, 200, and 250 ms ease-out, with a 0.98 press
  scale. Web easing approximates the native curve; it is not a spring simulation.
- {brand['character']['motion']}

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

{character}

The original identity is frozen in [the identity contract](identity/README.md).
The 18 current positive poses include generated cutouts and separate native
render previews. Original supporting poses are archived as historical references.
Production scene details remain in the
[canonical Mugsy subsystem](../MUGSY_DESIGN_SYSTEM.md).

## Photography and product imagery

{imagery}

## Voice and writing

**Voice profile:** {brand['voice']['profile']}

{brand['voice']['perspective']}
{brand['voice']['rhythm']}
{brand['voice']['capitalization']}
{brand['voice']['spelling']}

| Context | Tone rule |
| --- | --- |
{tones}

Avoid hype, rankings, invented numbers, pressure, jargon, and release claims
that lack current evidence. Do not imply social sharing is mandatory.

**Privacy language:** {brand['voice']['privacy']}

### Copy library

These lines exist in the native app and are checked against their exact source.
Use them as the starting point for marketing. They are identity language, not
proof that every pictured feature is available in a current distributed build.

| Role | App-source copy |
| --- | --- |
{copy_rows}

## Reference applications

| File | Format | Purpose |
| --- | --- | --- |
{apps}

Templates use the current imagery and remain editable local HTML references. They make no App Store, beta,
pricing, or live-account claim. Email has an explicit link-integration slot;
social templates have fixed composition ratios and print CSS. Check the real
audience, destination, and release state before publishing any downstream work.

## Asset library

| Asset | Original pixels | Use |
| --- | --- | --- |
{asset_rows}

Additional exported resources: [Adobe swatches](palette.ase), [plain RGB palette](palette.gpl),
[CSS tokens](tokens.css), and [JSON tokens](tokens.json).
The optional PDF and ZIP exports are derived distribution artifacts; their
source remains this versioned directory. Generated local output is not committed.

## Governance and adoption

Owner: **{brand['governance']['owner']}**.
{brand['governance']['change_rule']}

{brand['governance']['versioning']}

{brand['governance']['consumer_rule']}

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

{sources}

See [verification](VERIFICATION.md) for completed checks and explicit limits.
See [marketing-site handoff](WEBSITE_HANDOFF.md) for the observed drift and
the acceptance contract for adopting this kit.
"""


def outputs() -> dict[Path, bytes]:
    brand = json.loads(CONFIG.read_text())
    sources = {key: (ROOT / path).read_text() for key, path in brand["sources"].items()}
    colors = dict(re.findall(r'static let (\w+) = Color\(hex: "([A-Fa-f0-9]{6})"\)', sources["palette"]))
    colors = {name: "#" + value.upper() for name, value in colors.items()}
    if len(colors) != 16 or set(colors) != set(brand["color_usage"]):
        raise ValueError("Native palette changed: review the complete color contract and kit version")
    for sample in brand["copy"]:
        if sample["text"] not in sources[sample["source"]]:
            raise ValueError(f"App copy no longer matches: {sample['id']}")
    for role in brand["typography"]["native_roles"]:
        if role["evidence"] not in sources[role["source"]]:
            raise ValueError(f"Typography source no longer matches: {role['role']}")
    semantic = {key: colors[value] for key, value in brand["color_roles"].items()}
    character_hex = dict(re.findall(r'static let (\w+)Hex = "([A-Fa-f0-9]{6})"', sources["character"]))
    shadow_matches = re.findall(r'static let (\w+Shadow) = Shadow\(color: \.black.opacity\(([\d.]+)\), radius: (\d+), x: (\d+), y: (\d+)\)', sources["system"])
    motion = {key: round(float(value) * 1000) for key, value in re.findall(r'static let (fast|base|slow) = Animation.easeOut\(duration: ([\d.]+)\)', sources["system"])}
    tokens = {
        "format": "mugshot-brand-tokens/v1", "version": brand["version"],
        "color": colors, "semantic": semantic,
        "semanticSources": brand["color_roles"],
        "characterColor": {key: "#" + value for key, value in character_hex.items()},
        "space": read_scale(sources["system"], "Space"),
        "radius": read_scale(sources["system"], "Radius"),
        "shadow": {name: {"opacity": float(opacity), "blur": int(blur), "x": int(x), "y": int(y)} for name, opacity, blur, x, y in shadow_matches},
        "motionMs": motion,
        "pressScale": float(re.search(r'static let pressScale: CGFloat = ([\d.]+)', sources["system"])[1]),
        "font": {"display": brand["typography"]["web_display"], "body": brand["typography"]["web_body"]},
        "notes": "Colors, spacing, radii, shadows and base motion from native sources. Font fallbacks, responsive type, visible field outline and 44 px web targets are documented web translations."
    }
    if len(character_hex) != 6 or len(shadow_matches) != 3 or len(motion) != 3:
        raise ValueError("Native character, shadow, or motion structure changed; review the extraction")
    result: dict[Path, bytes] = {}
    assets = []
    for asset_id, source_name, filename, kind, use in ASSETS:
        source = "testMugshot/Assets.xcassets/" + source_name
        data = (ROOT / source).read_bytes()
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            raise ValueError(f"Expected original PNG: {source}")
        if kind == "photography":
            receipt = json.loads((KIT / "generation" / ("photo-" + asset_id + ".json")).read_text())
            if not receipt.get("review") or source not in receipt["native_asset_paths"]:
                raise ValueError("Photography receipt or review is missing: " + asset_id)
            for native_path, expected in receipt["native_output_sha256"].items():
                if digest((ROOT / native_path).read_bytes()) != expected:
                    raise ValueError("Photographic scene changed since review: " + native_path)
        width, height = struct.unpack(">II", data[16:24])
        assets.append({"id": asset_id, "path": "assets/" + filename, "source": source, "sha256": digest(data), "bytes": len(data), "width": width, "height": height, "kind": kind, "use": use, "transformation": "none; byte-for-byte native resource copy", "origin": "immutable app identity" if kind in ("identity", "character-master") else "OpenAI-generated source artwork", "native_pose": next((p["native_case"] for p in POSES if asset_id == "mugsy-" + p["id"]), None)})
        result[KIT / "assets" / filename] = data
    checks = [
        ("espressoBrown", "creamWhite", "Primary text", True),
        ("roastBrown", "creamWhite", "Supporting text", True),
        ("espressoBrown", "mugshotMint", "Mint panels", True),
        ("foamWhite", "mugshotSageText", "Primary actions", True),
        ("mugshotSageText", "creamWhite", "Green links", True),
        ("mugshotSageText", "sandBeige", "Green text on sand", True),
        ("foamWhite", "mugshotSage", "Avoid for normal text", False),
        ("mugshotMint", "creamWhite", "Avoid as body text", False),
    ]
    contrast = []
    for foreground, background, use, expected in checks:
        value = ratio(colors[foreground], colors[background])
        normal = value >= 4.5
        if normal != expected:
            raise ValueError(f"Contrast contract changed: {foreground} / {background}")
        contrast.append({"foreground": foreground, "background": background, "ratio": round(value, 4), "normal_text": normal, "large_text": value >= 3, "use": use})
    lines = ["/* Generated by scripts/brand-kit.py; edit native inputs and brand.json. */", ":root {"]
    lines += [f"  --mugshot-color-{css_key(k)}: {v};" for k, v in colors.items()]
    lines += [f"  --mugshot-{css_key(k)}: var(--mugshot-color-{css_key(v)});" for k, v in brand["color_roles"].items()]
    lines += [f"  --mugshot-space-{k}: {v}px;" for k, v in tokens["space"].items()]
    lines += [f"  --mugshot-radius-{k}: {v}px;" for k, v in tokens["radius"].items()]
    for name, value in tokens["shadow"].items():
        lines.append(f"  --mugshot-shadow-{css_key(name.replace('Shadow', ''))}: {value['x']}px {value['y']}px {value['blur']}px rgb(0 0 0 / {value['opacity'] * 100:g}%);")
    lines += [f"  --mugshot-motion-{k}: {v}ms;" for k, v in motion.items()]
    lines += [f"  --mugshot-press-scale: {tokens['pressScale']};", "  --mugshot-ease: ease-out;", f"  --mugshot-font-display: {tokens['font']['display']};", f"  --mugshot-font-body: {tokens['font']['body']};", "  --mugshot-display-tracking: -0.2px;", "}", ""]
    source_manifest = {"version": brand["version"], "native_baseline": brand["source_revision"], "sources": [{"role": role, "path": path, "sha256": digest((ROOT / path).read_bytes())} for role, path in brand["sources"].items()]}
    result[KIT / "tokens.json"] = encoded(tokens)
    result[KIT / "tokens.css"] = "\n".join(lines).encode()
    result[KIT / "assets.json"] = encoded({"version": brand["version"], "assets": assets})
    result[KIT / "source-manifest.json"] = encoded(source_manifest)
    result[KIT / "contrast.json"] = encoded(contrast)
    result[KIT / "brand-data.js"] = b"/* Generated app-source contract. Works offline without fetch. */\nwindow.MUGSHOT_BRAND = " + encoded({"brand": brand, "tokens": tokens, "assets": assets, "contrast": contrast, "mugsy": json.loads(MUGSY_SPEC.read_text())}).rstrip() + b";\n"
    result[KIT / "README.md"] = render_readme(brand, tokens, assets, contrast).encode()
    result[KIT / "palette.ase"] = palette_ase(colors)
    gpl = ["GIMP Palette", "Name: Mugshot " + brand["version"], "Columns: 4", "# Exact app-source sRGB values; no CMYK conversion."]
    gpl += [f"{int(v[1:3], 16):3} {int(v[3:5], 16):3} {int(v[5:7], 16):3}\t{k}" for k, v in colors.items()]
    result[KIT / "palette.gpl"] = ("\n".join(gpl) + "\n").encode()
    return result


def check_links() -> list[str]:
    failures = []
    for path in [*KIT.rglob("*.html"), *KIT.rglob("*.md")]:
        source = path.read_text()
        targets = re.findall(r'(?:href|src)=[\'"]([^\'"]+)', source) if path.suffix == ".html" else re.findall(r'(?<!!)\[[^\]]+\]\(([^)]+)\)', source)
        for target in targets:
            if target.startswith(("https:", "http:", "mailto:", "data:", "#")):
                continue
            resolved = (path.parent / target.split("#")[0]).resolve()
            if not resolved.is_relative_to(ROOT) or not resolved.exists():
                failures.append(f"{path.relative_to(ROOT)}: missing/escaping link {target}")
    return failures


def check_surfaces() -> list[str]:
    """Reject independent colors and unexpected asset copies in the kit UI."""
    failures = []
    brand = json.loads(CONFIG.read_text())
    tokens = json.loads((KIT / "tokens.json").read_text())
    allowed = {value.upper() for value in tokens["color"].values()}
    for path in [*KIT.rglob("*.html"), *KIT.rglob("*.css")]:
        source = path.read_text()
        for value in re.findall(r"#[a-fA-F0-9]{6}\b", source):
            if value.upper() not in allowed:
                failures.append(f"{path.relative_to(ROOT)}: independent color {value}")
        if re.search(r"https?://", source):
            failures.append(f"{path.relative_to(ROOT)}: reference UI must use local resources only")
    expected_assets = {filename for _, _, filename, _, _ in ASSETS}
    actual_assets = {path.name for path in (KIT / "assets").iterdir() if path.is_file()}
    if actual_assets != expected_assets:
        failures.append("Asset directory differs from the app-derived manifest")
    email = (KIT / "templates/email.html").read_text()
    for sample_id in ("hero", "intro", "journal-body", "signup", "privacy"):
        sample = next(item for item in brand["copy"] if item["id"] == sample_id)
        if sample["text"] not in email:
            failures.append(f"Email source copy drift: {sample_id}")
    return failures


def package() -> None:
    destination = ROOT / "output/brand"
    destination.mkdir(parents=True, exist_ok=True)
    brand = json.loads(CONFIG.read_text())
    archive = destination / f"Mugshot-Brand-Kit-{brand['version']}.zip"
    kit_commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    dirty = bool(subprocess.check_output(["git", "status", "--porcelain", "--", "docs/brand", "scripts/brand-kit.py", "scripts/brand-kit-pdf.py"], cwd=ROOT, text=True).strip())
    files = sorted(p for p in KIT.rglob("*") if p.is_file() and p.name != ".DS_Store")
    pdf = ROOT / "output/pdf/Mugshot-Brand-Book.pdf"
    if pdf.exists():
        metadata_path = pdf.parent / "brand-book-manifest.json"
        metadata = json.loads(metadata_path.read_text())
        contract = b"".join((KIT / name).read_bytes() for name in ("brand.json", "tokens.json", "assets.json", "identity/mugsy-spec.json", "native-renders/manifest.json"))
        if metadata["contract_sha256"] != digest(contract) or metadata["pdf_sha256"] != digest(pdf.read_bytes()):
            raise ValueError("PDF export is stale or modified; regenerate before packaging")
        files.append(pdf)
    entries = []
    with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as out:
        for path in files:
            name = path.relative_to(KIT).as_posix() if path.is_relative_to(KIT) else "Mugshot-Brand-Book.pdf"
            data = path.read_bytes()
            if path.suffix == ".md":
                def permalink(match: re.Match) -> str:
                    target = match[2]
                    if target.startswith(("http:", "https:", "#", "mailto:")):
                        return match[0]
                    source_path, separator, anchor = target.partition("#")
                    resolved = (path.parent / source_path).resolve()
                    if resolved.is_relative_to(ROOT) and not resolved.is_relative_to(KIT):
                        url = "https://github.com/HyperGoatt/mugshot-app/blob/" + kit_commit + "/" + resolved.relative_to(ROOT).as_posix()
                        return match[1] + url + (separator + anchor if separator else "") + ")"
                    return match[0]
                data = re.sub(r"(\[[^\]]+\]\()([^)]+)\)", permalink, data.decode()).encode()
            out.writestr(name, data)
            entries.append({"path": name, "sha256": digest(data), "bytes": len(data)})
        out.writestr("PACKAGE.json", encoded({"version": brand["version"], "kit_source_commit": kit_commit, "working_copy_changes": dirty, "native_source_revision": brand["source_revision"], "files": entries, "entry": "index.html", "note": "Open index.html locally. Native evidence links in Markdown point to kit_source_commit; native source code is not included. A dirty package is a draft."}))
    with zipfile.ZipFile(archive) as out:
        assert out.testzip() is None
        for item in entries:
            assert digest(out.read(item["path"])) == item["sha256"]
    print(f"Packaged {len(entries)} files with verified hashes: {archive}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--package", action="store_true")
    args = parser.parse_args()
    try:
        expected = outputs()
        if args.build:
            for path, data in expected.items():
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_bytes(data)
            print(f"Built {len(expected)} app-derived brand outputs.")
        else:
            stale = [str(path.relative_to(ROOT)) for path, data in expected.items() if not path.exists() or path.read_bytes() != data]
            if stale:
                print("Brand contract drift; review inputs and rebuild:\n" + "\n".join(stale), file=sys.stderr)
                return 1
        failures = check_links() + check_surfaces()
        if failures:
            print("\n".join(failures), file=sys.stderr)
            return 1
        if args.package:
            package()
        print("Brand source, copy, typography, token, asset, contrast, and local-link checks passed.")
        return 0
    except (OSError, ValueError, KeyError, AssertionError, subprocess.CalledProcessError) as error:
        print(f"Brand kit check failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
