#!/usr/bin/env python3
"""Export the Mugshot brand contract as a portable, print-ready reference PDF.

Requires ReportLab; uses only original app assets and PDF built-in fonts.
Run scripts/brand-kit.py --check first. Output stays outside tracked source.
"""

from __future__ import annotations

import hashlib
import json
from html import escape
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.utils import ImageReader
from reportlab.pdfgen import canvas
from reportlab.platypus import Paragraph, Table, TableStyle

ROOT = Path(__file__).resolve().parents[1]
KIT = ROOT / "docs/brand"
OUT = ROOT / "output/pdf"
BRAND = json.loads((KIT / "brand.json").read_text())
TOKENS = json.loads((KIT / "tokens.json").read_text())
ASSETS = json.loads((KIT / "assets.json").read_text())["assets"]
CONTRAST = json.loads((KIT / "contrast.json").read_text())
COLOR = {name: colors.HexColor(value) for name, value in TOKENS["color"].items()}
W, H, M = 612, 792, 44
WIDTH = W - M * 2
OUT.mkdir(parents=True, exist_ok=True)
DESTINATION = OUT / "Mugshot-Brand-Book.pdf"


def clean(value: str) -> str:
    return value.replace("—", " - ").replace("–", "-").replace("−", "-").replace("’", "'").replace("“", '"').replace("”", '"').replace("×", "x").replace("·", " / ")


class Book:
    def __init__(self) -> None:
        self.canvas = canvas.Canvas(str(DESTINATION), pagesize=(W, H), pageCompression=1, invariant=1)
        self.canvas.setTitle("Mugshot Brand Book / " + BRAND["version"])
        self.canvas.setAuthor("Mugshot")
        self.canvas.setSubject("App-derived identity, color, typography, imagery, voice, applications and governance")
        self.number = 0
        self.titles = []
        self.y = H - 130

    def page(self, title: str, introduction: str = "") -> None:
        if self.number:
            self.footer()
            self.canvas.showPage()
        self.number += 1
        self.titles.append(title)
        self.canvas.setFillColor(COLOR["creamWhite"])
        self.canvas.rect(0, 0, W, H, fill=1, stroke=0)
        self.canvas.setFillColor(COLOR["espressoBrown"])
        self.canvas.setFont("Times-Roman", 24)
        self.canvas.drawString(M, H - 48, "Mugshot")
        self.canvas.setFont("Helvetica", 8)
        self.canvas.setFillColor(COLOR["roastBrown"])
        self.canvas.drawRightString(W - M, H - 43, "BRAND BOOK  " + BRAND["version"])
        self.canvas.setStrokeColor(COLOR["mugshotLine"])
        self.canvas.line(M, H - 66, W - M, H - 66)
        self.y = H - 96
        self.y = self.text(title, size=34, font="Times-Roman", leading=37, color="espressoBrown", gap=18)
        if introduction:
            self.y = self.text(introduction, size=11, leading=16, gap=26)

    def footer(self) -> None:
        c = self.canvas
        c.setStrokeColor(COLOR["mugshotLine"])
        c.line(M, 40, W - M, 40)
        c.setFillColor(COLOR["roastBrown"])
        c.setFont("Helvetica", 8)
        c.drawString(M, 25, "Mugshot / App-derived brand authority / November 24, 2026")
        c.drawRightString(W - M, 25, str(self.number))

    def text(self, value: str, x: float = M, y: float | None = None, width: float = WIDTH, size: float = 10.5, leading: float = 16, font: str = "Helvetica", color: str = "roastBrown", gap: float = 14) -> float:
        if y is None:
            y = self.y
        style = ParagraphStyle("book", fontName=font, fontSize=size, leading=leading, textColor=COLOR[color], alignment=TA_LEFT)
        paragraph = Paragraph(escape(clean(value)).replace("\n", "<br/>"), style)
        _, height = paragraph.wrap(width, H)
        if y - height < 52:
            raise ValueError(f"PDF overflow on page {self.number} ({self.titles[-1]}): {value[:65]}")
        paragraph.drawOn(self.canvas, x, y - height)
        return y - height - gap

    def block(self, title: str, body: str, x: float = M, width: float = WIDTH) -> None:
        self.y = self.text(title, x=x, width=width, size=16, font="Times-Roman", leading=20, color="espressoBrown", gap=7)
        self.y = self.text(body, x=x, width=width, gap=22)

    def image(self, asset_id: str, x: float, y: float, width: float, height: float, crop: bool = False) -> None:
        asset = next(asset for asset in ASSETS if asset["id"] == asset_id)
        image = ImageReader(str(KIT / asset["path"]))
        c = self.canvas
        if crop:
            scale = max(width / asset["width"], height / asset["height"])
            drawn_w, drawn_h = asset["width"] * scale, asset["height"] * scale
            c.saveState()
            path = c.beginPath()
            path.rect(x, y, width, height)
            c.clipPath(path, stroke=0)
            c.drawImage(image, x + (width - drawn_w) / 2, y + (height - drawn_h) / 2, drawn_w, drawn_h, mask="auto")
            c.restoreState()
        else:
            c.drawImage(image, x, y, width, height, preserveAspectRatio=True, anchor="c", mask="auto")

    def table(self, headers: list[str], rows: list[list[str]], widths: list[float], size: float = 9) -> None:
        normal = ParagraphStyle("cell", fontName="Helvetica", fontSize=size, leading=size * 1.5, textColor=COLOR["roastBrown"])
        head = ParagraphStyle("header", parent=normal, fontName="Helvetica-Bold", textColor=COLOR["espressoBrown"])
        values = [[Paragraph(escape(clean(str(value))), head if index == 0 else normal) for value in row] for index, row in enumerate([headers, *rows])]
        table = Table(values, colWidths=widths, hAlign="LEFT")
        table.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "TOP"), ("LEFTPADDING", (0, 0), (-1, -1), 0), ("RIGHTPADDING", (0, 0), (-1, -1), 12), ("TOPPADDING", (0, 0), (-1, -1), 7), ("BOTTOMPADDING", (0, 0), (-1, -1), 7), ("LINEBELOW", (0, 0), (-1, -1), .5, COLOR["mugshotLine"])]))
        _, height = table.wrap(WIDTH, H)
        if self.y - height < 52:
            raise ValueError(f"PDF table overflow on page {self.number}")
        table.drawOn(self.canvas, M, self.y - height)
        self.y -= height + 24

    def finish(self) -> None:
        self.footer()
        self.canvas.save()
        contract = b"".join((KIT / name).read_bytes() for name in ("brand.json", "tokens.json", "assets.json"))
        metadata = {"version": BRAND["version"], "pages": self.number, "titles": self.titles, "contract_sha256": hashlib.sha256(contract).hexdigest(), "pdf_sha256": hashlib.sha256(DESTINATION.read_bytes()).hexdigest(), "fonts": "PDF built-in Times / Helvetica; role-preserving fallback, not embedded native fonts"}
        (OUT / "brand-book-manifest.json").write_text(json.dumps(metadata, indent=2) + "\n")
        print(f"Exported {self.number} pages: {DESTINATION}")


book = Book()
book.page("Capture Every Sip", "The Mugshot brand book. One app-derived standard for every place the brand appears.")
book.image("orange-hero", M, 285, WIDTH, 310, crop=True)
book.y = 253
book.y = book.text("The drink. The place. The little moment around it.", font="Times-Roman", size=24, leading=28, color="espressoBrown", gap=22)
book.y = book.text("Identity, color, typography, imagery, Mugsy, voice, components, reference applications, and brand governance.", size=11, leading=17)
book.y = book.text("Version 1.0.0 / November 24, 2026\nNative assets and language only. No new app release or website deployment is claimed.", size=9, leading=14)

book.page("A little moment, remembered.", BRAND["positioning"]["description"])
book.block("For the person remembering it", BRAND["positioning"]["audience"])
book.block("The promise", BRAND["positioning"]["promise"])
book.y = book.text("Warm. Observant. Personal. Calm. Quietly playful.", font="Times-Roman", size=23, leading=28, color="mugshotSageText", gap=26)
for principle in BRAND["positioning"]["principles"]:
    book.block(principle["title"], principle["body"])

book.page("Always Mugshot.", "The original app icon and a regular serif name carry the identity.")
book.canvas.setFillColor(COLOR["foamWhite"])
book.canvas.roundRect(M, 402, WIDTH, 190, 16, stroke=0, fill=1)
book.image("app-icon", 119, 440, 104, 104)
book.text("Mugshot", x=235, y=509, width=260, font="Times-Roman", size=48, leading=52, color="espressoBrown")
book.y = 370
book.block("Preserve the supplied mark", "Use the full original PNG. Keep its white canvas, source padding, proportions, and orientation. Do not redraw, recolor, trace, stretch, mirror, or create new inverse and monochrome versions.")
book.block("Live type, not a new logo", BRAND["logo"]["wordmark_rule"])
book.block("Web application rules", "Leave one quarter of the displayed icon width clear around a lockup. Use the app's 12 px spacing step between icon and name. Keep the complete icon at least 48 CSS px wide; otherwise use text only.")
book.y = book.text("No approved standalone vector logo, inverse mark, monochrome master, CMYK master, or favicon-size redraw was found in the app. These remain explicit gaps.", size=9, leading=14)

book.page("Cream, espresso, and green.", "The core palette comes directly from native BrandColors.swift. Cream holds the page; photography supplies vivid color.")
core = ["creamWhite", "espressoBrown", "mugshotMint", "mugshotSageText", "roastBrown", "sandBeige"]
top = book.y
for index, key in enumerate(core):
    x = M + (index % 2) * 274
    y = top - (index // 2) * 139
    book.canvas.setFillColor(COLOR[key])
    book.canvas.setStrokeColor(COLOR["mugshotLine"])
    book.canvas.roundRect(x, y - 76, 250, 76, 12, fill=1, stroke=1)
    book.text(key + " / " + TOKENS["color"][key], x=x, y=y - 90, width=250, font="Helvetica-Bold", size=9, leading=13)
book.y = top - 422
book.y = book.text("Use espresso on cream or mint. Use white on the darker sage-text token for accessible actions. Soft sage, matcha, and latte are supporting accents. Map colors retain their rating meaning.", size=10, leading=15)

book.page("The complete UI palette.", "Exact sRGB values. Legacy sageGray aliases the same mint; it is not a separate color.")
book.table(["Native token", "Hex", "Role"], [[key, value, BRAND["color_usage"][key].split(".")[0]] for key, value in TOKENS["color"].items()], [130, 70, WIDTH - 200], size=8)
book.y = book.text("Digital swatches are supplied as palette.ase and palette.gpl. No unverified CMYK or Pantone equivalent is specified. Print requires its own proof.", size=9, leading=14)

book.page("Readability is part of the brand.", "Normal text requires 4.5:1; large text requires 3:1. Ratios use exact native sRGB token values.")
book.table(["Foreground / background", "Ratio", "Normal text"], [[p["foreground"] + " / " + p["background"], f"{p['ratio']:.2f}:1", "Pass" if p["normal_text"] else "Fail - avoid"] for p in CONTRAST], [310, 76, WIDTH - 386], size=9)
book.block("Choose the right sage", "White on soft sage is 3.57:1 and fails normal text. White on sage-text is 5.60:1. Use the existing darker companion for readable actions.")
book.block("Readable controls", "Use visible labels, a sage-text field outline, and clear focus. Quiet line color alone is not sufficient for an essential field boundary. Never communicate a rating, privacy state, or error by color alone.")
book.y = book.text("A color-pair check is not an app-wide accessibility certification. Check actual font size, background, focus, text growth, and interaction in context.", size=9, leading=14)

book.page("A journal's warmth. An app's clarity.", "Native regular system serif for expressive moments. Native system sans for body, labels, and controls.")
book.y = book.text("Aa Bb Cc", font="Times-Roman", size=64, leading=70, color="espressoBrown", gap=24)
book.y = book.text("The little moment around it.", font="Times-Roman", size=30, leading=36, color="espressoBrown", gap=22)
book.y = book.text("ABCDEFGHIJKLMNOPQRSTUVWXYZ\nabcdefghijklmnopqrstuvwxyz\n0123456789 & ? !", size=13, leading=23, gap=26)
book.table(["Observed native role", "Default size", "Weight"], [[r["role"], str(r["size"]) + " pt", str(r["weight"])] for r in BRAND["typography"]["native_roles"]], [260, 130, WIDTH - 390])
book.block("Use roles across platforms", "Web display: ui-serif, Georgia, Times New Roman, serif. Web body: -apple-system, BlinkMacSystemFont, Segoe UI, system-ui, sans-serif. There are no bundled custom font files.")
book.y = book.text("This PDF uses built-in Times and Helvetica to preserve the role relationship. It does not claim exact native SF Serif parity or redistribute Apple fonts.", size=9, leading=14)

book.page("Room for the little details.", "The app's primitive scales give every surface a familiar rhythm. Web values are documented translations, not frozen native layouts.")
for key, value in TOKENS["space"].items():
    book.y = book.text(f"{key} / {value} pt native, {value} px web", size=10, leading=14, gap=10)
    book.canvas.setFillColor(COLOR["mugshotSageText"])
    book.canvas.roundRect(M + 255, book.y + 11, value * 5, 7, 3, fill=1, stroke=0)
book.y -= 24
book.block("Shape", "8 px small elements. 12 px controls. 16 px cards. 20 px hero cards. 24 px sheets. Capsule controls use a pill radius. Keep the page composition responsive.")
book.block("Soft depth", "Cards: black at 8%, blur 12, offset 0/4. Subtle: black at 6%, blur 2, offset 0/1. Overlays: black at 12%, blur 30, offset 0/12. The native white surface, quiet line, and offset shadow work together.")
book.block("Quiet at rest", "Base transitions: 150, 200, and 250 ms ease-out. Press scale: 0.98. Respect reduced motion with a still state. Marketing does not need ambient mascot loops; acknowledge an actual completed action.")
book.y = book.text("Native spring motion stays in its native subsystem. CSS ease-out is an approximation, not a spring simulation.", size=9, leading=14)

book.page("Familiar in every detail.", "Translate the app's hierarchy into the right medium. Keep controls clear and the drink primary.")
for title, body in [
    ("Primary action", "Existing sage-text token, white semibold sans text, capsule shape. 24 px horizontal / 13 px vertical padding; minimum 44 px web target."),
    ("Secondary action", "White fill, espresso text, quiet line border, capsule. 24 px horizontal / 12 px vertical padding."),
    ("Field", "Persistent label, white surface, espresso value, 12 px radius. Web fields use an accessible sage-text outline; placeholder is supplementary."),
    ("Card and rating", "Photo first. White card, 16 px corners, soft offset depth. Keep score below the photo with a readable out-of-five label. Example scores must be marked illustrative."),
    ("Filters and navigation", "Use clear text labels and a semantic selected state. Capsule visual height may be smaller than the 44 px web hit area."),
    ("Empty and recovery", "Use approved positive contextual Mugsy scenes for true emptiness. Hidden content, offline, image failure, and permission denial need accurate recovery states.")
]:
    book.block(title, body)
book.y = book.text("Older native controls may still use softer sage or quiet borders. This kit does not claim those instances have been migrated. SF Symbols remain native; their glyphs are not exported.", size=9, leading=14)

book.page("Meet Mugsy.", "A white ceramic mug, permanent glasses, and a gentle presence. Preserve the supplied artwork exactly.")
book.canvas.setFillColor(COLOR["mugshotMint"])
book.canvas.roundRect(M, 388, WIDTH, 220, 16, fill=1, stroke=0)
book.image("mugsy-wishlist", 187, 396, 238, 204)
book.y = 358
book.block("The original master", "MugsyNoWishlist is the canonical front-facing identity master. The bookmark beneath his crossed arms is a prop, not anatomy. Preserve its original expression, orientation, proportions, and padding.")
book.block("Permanent identity", "White ceramic, glasses, the approved rim and handle, compact limbs, and controlled asymmetry remain intact. Do not mirror, recolor, stretch, crop the handle, or invent new anatomy.")
book.block("A companion, not pressure", "The legacy raster poses preserve original identity evidence. Current native scenes favor positive, context-aware expressions. Do not turn sad poses into guilt-based marketing. Builder is for coming-soon and maintenance only.")
book.y = book.text("The code-native vector reference is review-only. It does not replace shipping PNGs or grant authority to new derived artwork.", size=9, leading=14)

book.page("A character with a clear identity.", "Artwork colors belong to Mugsy. They do not replace the UI palette.")
for index, key in enumerate(["mugsy-favorites", "mugsy-cafes", "mugsy-friends", "mugsy-builder"]):
    x = M + index * 134
    book.image(key, x, 460, 122, 122)
    book.text(key.replace("mugsy-", "").capitalize(), x=x, y=447, width=122, size=9, leading=13)
book.y = 401
book.table(["Character token", "Locked hex"], [[key, value] for key, value in TOKENS["characterColor"].items()], [310, WIDTH - 310])
book.block("Source orientation and motion", "The normalized native model keeps the handle on Mugsy's right. Original raster references can differ; preserve each file exactly as supplied. Do not mirror a source to force visual uniformity.")
book.y = book.text("Construction, anchor, prop, placement, and animation rules remain in docs/MUGSY_DESIGN_SYSTEM.md. The kit is the entry point; that document is its character subsystem.", size=9, leading=14)

book.page("Make the drink the main character.", "Natural light, warm surroundings, and texture. Use the app's existing imagery.")
for index, (key, label) in enumerate([("orange-square", "Drink first"), ("latte", "Texture and warmth"), ("cafe-corner", "A sense of place")]):
    x = M + index * 180
    book.image(key, x, 411, 164, 188, crop=True)
    book.text(label, x=x, y=397, width=164, size=9, leading=13)
book.y = 350
book.block("Compose around the moment", "Keep the drink's focal point visible when cropping photography. Never stretch. Use cream panels behind copy whenever image contrast would be uncertain. Let photographs supply the vivid color.")
book.block("Use what is supplied", "All included images are exact copies of bundled app resources. No outside stock, new generated imagery, live user accounts, or private journals enter this kit.")
book.block("Truthful context", "Bundled drink and cafe imagery is illustration, not evidence of a real venue or current account. Source provenance is not independent verification of every underlying license.")

book.page("Show the app honestly.", "Complete onboarding artwork is a visual reference. It is not an editable screen or an exact release capture.")
for index, key in enumerate(["onboarding-capture", "onboarding-map", "onboarding-journal"]):
    book.image(key, M + index * 180, 246, 164, 356)
book.y = 213
book.block("Keep the source intact", "Retain baked-in labels and original artwork. Do not crop away text to imply a new app state. Before using real runtime screens downstream, verify their build, account safety, and current feature availability.")
book.y = book.text("Onboarding reference images retain their original progress labels and presentation. This brand kit does not represent them as screenshots of the currently installed app.", size=9, leading=14)

book.page("Sound like a good memory.", BRAND["voice"]["profile"])
book.y = book.text("The drink. The place. The little moment around it. Mugshot helps you remember it all.", font="Times-Roman", size=27, leading=32, color="espressoBrown", gap=28)
book.block("Perspective and rhythm", BRAND["voice"]["perspective"] + " " + BRAND["voice"]["rhythm"])
book.block("Spelling and names", BRAND["voice"]["capitalization"] + " " + BRAND["voice"]["spelling"])
book.block("Keep the promise precise", BRAND["voice"]["privacy"])
book.block("Leave out", "Hype, status competition, expert-only language, guilt, invented numbers, reviews, awards, pricing, availability, and blanket privacy claims. Sharing remains a choice.")

book.page("The source-copy library.", "These lines exist in native onboarding and authentication. Their exact strings are checked against source.")
for sample in BRAND["copy"][:6]:
    book.block(sample["role"], sample["text"])
book.y = book.text("Use this language as a starting point. It expresses the brand, not proof that every pictured feature is in a current distributed build.", size=9, leading=14)

book.page("Words for the everyday moments.", "The journal, your people, and the next sip. Keep the language personal and concrete.")
for sample in BRAND["copy"][6:]:
    book.block(sample["role"], sample["text"])

book.page("One brand, every channel.", "Editable local HTML reference applications show how the app's identity translates into web, social, and email.")
for application in BRAND["applications"]:
    book.block(application["name"] + " / " + application["format"], application["purpose"] + " File: " + application["path"])
book.block("Website composition", "Cream-led canvas, regular serif headline, system sans details, original drink photography, and sage-text actions. Preserve working routes, legal content, and actual destinations in a real migration.")
book.block("Publication boundary", "No template announces an App Store release or sends a message. Email has a named CTA integration slot. Verify destination, audience, and release state before publishing. Social files preserve square or portrait ratios in print.")

book.page("Bring the website home.", "The local marketing source audit found a separate visual world. The kit supplies a concrete replacement contract.")
book.table(["Observed in marketing source", "Required Mugshot standard"], [
    ["Neon lime #abff44 and cyan #91dbda", "Cream canvas, muted mint, natural drink color"],
    ["Heavy sans headings / weight 800", "Regular serif display and system sans details"],
    ["Independent forest and neutral values", "Exact generated CSS/JSON tokens"],
    ["Independent motion and depth", "Native base timing, soft offset shadows, reduced motion"],
    ["Product-looking reference UI", "Source artwork and truthful reference labels"]
], [260, WIDTH - 260], size=9)
book.block("Adopt the contract", "Pin kit version and source commit. Import tokens.css once. Remove competing palettes. Use manifest assets and the source-copy library. Validate mobile and desktop layouts, text growth, focus, contrast, navigation, and real CTA destinations.")
book.block("Record actual adoption", "Marketing source inspected at 924cbc2 on November 24. This kit does not claim a live-site visual inspection, migration, or deployment. The website handoff carries its acceptance checklist.")

book.page("A standard that stays current.", "The product owner owns identity decisions. Change the kit and affected consumers together.")
book.block("One authority", "docs/brand/README.md is the human entry point. brand.json owns policy and source mappings. tokens.css and tokens.json expose generated primitives. assets.json records exact source paths, dimensions, uses, and SHA-256 hashes.")
book.block("Change and version", BRAND["governance"]["versioning"] + " Do not hand-maintain a second palette or voice guide downstream.")
book.block("Review the change", "Build: python3 scripts/brand-kit.py --build. Check: python3 scripts/brand-kit.py --check. Run documentation and diff checks. Inspect the complete scoped diff, source hashes, accessible pairs, and consumer UI.")
book.block("Distribute a pinned kit", "Package: python3 scripts/brand-kit.py --package. The standalone ZIP includes this visual book's source, original assets, templates, swatches, tokens, provenance manifests, and a per-file hash manifest. The PDF is a derived reference export.")
book.block("Respect evidence boundaries", "No native app build, device acceptance, backend mutation, TestFlight step, website deployment, or sent campaign is implied. Missing artwork masters remain explicit gaps.")

book.page("Everything starts in the app.", "The brand kit traces every primitive, asset, and source-copy sample to the native repository.")
book.y = book.text("Native baseline: " + BRAND["source_revision"], size=9, leading=14, gap=24)
for role, path in BRAND["sources"].items():
    book.y = book.text(role.replace("_", " ").capitalize(), font="Helvetica-Bold", size=9, leading=13, color="espressoBrown", gap=2)
    book.y = book.text(path, size=8.5, leading=13, gap=16)
book.y = book.text("Full file hashes: source-manifest.json. Exact raster hashes and dimensions: assets.json. Completed verification and limits: VERIFICATION.md. The native sources are evidence pointers; they are not copied into the standalone kit.", size=9, leading=14)
book.finish()
