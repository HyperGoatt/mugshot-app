#!/usr/bin/env python3
"""Build the canonical Mugsy waving Instagram teaser."""

from __future__ import annotations

import json
import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[3]
PACK = Path(__file__).resolve().parent
SOURCE = PACK / "source"
EXPORTS = PACK / "exports"
FRAME_SOURCE = SOURCE / "mugsy-wave-frames"
FINAL_FRAMES = SOURCE / "final-frames"

WIDTH, HEIGHT = 1080, 1920
FPS = 24
DURATION = 6

CREAM = "#FAF6F0"
ESPRESSO = "#1F1712"
SAGE = "#6E8F7C"
SAGE_TEXT = "#4D6F5D"
MINT = "#A8CDB8"
SAND = "#EEE6D8"
GOLD = "#D4AD55"
TERRACOTTA = "#C26355"

SERIF_BOLD = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
SANS = "/System/Library/Fonts/Avenir Next.ttc"

APP_ICON = ROOT / "testMugshot/Assets.xcassets/MugshotAppIcon.imageset/mugshot-app-icon.png"
MUGSY_DESIGN = ROOT / "testMugshot/Design/MugsyDesignSystem.swift"
MUGSY_MODEL = ROOT / "testMugshot/Views/Components/MugsyModelView.swift"
SWIFT_RENDERER = PACK / "render_mugsy_frames.swift"


def font(path: str, size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size, index=index)


def hex_rgba(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[index : index + 2], 16) for index in (0, 2, 4)) + (alpha,)


def ease_out_back(value: float) -> float:
    value = max(0, min(1, value))
    overshoot = 1.70158
    return 1 + (overshoot + 1) * (value - 1) ** 3 + overshoot * (value - 1) ** 2


def cover_icon(size: int) -> Image.Image:
    source = Image.open(APP_ICON).convert("RGB").crop((138, 138, 886, 886))
    source = source.resize((size, size), Image.Resampling.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=round(size * 0.22), fill=255)
    source.putalpha(mask)
    return source


def render_canonical_mugsy_frames() -> None:
    if FRAME_SOURCE.exists():
        shutil.rmtree(FRAME_SOURCE)
    FRAME_SOURCE.mkdir(parents=True)

    renderer_binary = SOURCE / "mugsy-wave-renderer"
    render_model = SOURCE / "MugsyModelView.render.swift"
    model_source = MUGSY_MODEL.read_text()
    preview_marker = "\n#Preview("
    if preview_marker not in model_source:
        raise SystemExit("Could not isolate MugsyModelView preview-only declarations.")
    render_model.write_text(model_source.split(preview_marker, 1)[0] + "\n")

    try:
        subprocess.run(
            [
                "xcrun",
                "swiftc",
                "-parse-as-library",
                str(MUGSY_DESIGN),
                str(render_model),
                str(SWIFT_RENDERER),
                "-o",
                str(renderer_binary),
            ],
            check=True,
        )
        subprocess.run([str(renderer_binary), str(FRAME_SOURCE)], check=True)
    finally:
        renderer_binary.unlink(missing_ok=True)
        render_model.unlink(missing_ok=True)


def draw_soft_background() -> Image.Image:
    background = Image.new("RGBA", (WIDTH, HEIGHT), CREAM)
    shapes = Image.new("RGBA", background.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(shapes)
    draw.ellipse((-330, 110, 1410, 1570), fill=hex_rgba(MINT, 55))
    draw.ellipse((725, -180, 1280, 375), fill=hex_rgba(SAND, 225))
    draw.ellipse((-170, 1570, 360, 2100), fill=hex_rgba(SAND, 185))
    shapes = shapes.filter(ImageFilter.GaussianBlur(4))
    return Image.alpha_composite(background, shapes)


def draw_logo(base: Image.Image) -> None:
    icon = cover_icon(88)
    base.alpha_composite(icon, (72, 108))
    draw = ImageDraw.Draw(base)
    draw.text((182, 126), "MUGSHOT", font=font(SANS, 30), fill=ESPRESSO)


def draw_sparkle(draw: ImageDraw.ImageDraw, center: tuple[float, float], radius: float, fill) -> None:
    x, y = center
    draw.polygon(
        [
            (x, y - radius),
            (x + radius * 0.28, y - radius * 0.28),
            (x + radius, y),
            (x + radius * 0.28, y + radius * 0.28),
            (x, y + radius),
            (x - radius * 0.28, y + radius * 0.28),
            (x - radius, y),
            (x - radius * 0.28, y - radius * 0.28),
        ],
        fill=fill,
    )


def compose_frame(frame_index: int, mugsy_frames: list[Path]) -> Image.Image:
    t = frame_index / FPS
    base = draw_soft_background()
    draw_logo(base)

    mugsy_path = mugsy_frames[frame_index % len(mugsy_frames)]
    mugsy = Image.open(mugsy_path).convert("RGBA")

    entrance = ease_out_back(min(1, (t + 0.24) / 0.82))
    breathe = 1 + math.sin(t * math.pi * 2 / 1.5) * 0.008
    scale = max(0.01, (0.86 + 0.04 * entrance) * breathe)
    size = round(900 * scale)
    mugsy = mugsy.resize((size, size), Image.Resampling.LANCZOS)
    rotation = math.sin(t * math.pi * 2 / 1.5) * 1.25
    mugsy = mugsy.rotate(rotation, resample=Image.Resampling.BICUBIC, expand=True)

    bob = round(math.sin(t * math.pi * 2 / 1.5) * 7)
    mugsy_x = round((WIDTH - mugsy.width) / 2)
    mugsy_y = round(330 + (1 - entrance) * 90 + bob)

    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse((260, 1110, 820, 1190), fill=hex_rgba(ESPRESSO, 36))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    base.alpha_composite(shadow)
    base.alpha_composite(mugsy, (mugsy_x, mugsy_y))

    accents = Image.new("RGBA", base.size, (0, 0, 0, 0))
    accent_draw = ImageDraw.Draw(accents)
    wave = (math.sin(t * math.pi * 4 / 1.5) + 1) / 2
    accent_alpha = round(70 + 130 * wave)
    accent_draw.arc((747, 570, 835, 735), 284, 72, fill=hex_rgba(SAGE, accent_alpha), width=7)
    accent_draw.arc((775, 532, 887, 755), 286, 70, fill=hex_rgba(SAGE, round(accent_alpha * 0.58)), width=5)

    sparkle_pulse = (math.sin(t * math.pi * 2 / 1.5 - 0.7) + 1) / 2
    draw_sparkle(accent_draw, (224, 604), 17 + sparkle_pulse * 7, hex_rgba(GOLD, 155))
    draw_sparkle(accent_draw, (852, 950), 13 + (1 - sparkle_pulse) * 6, hex_rgba(TERRACOTTA, 130))
    accent_draw.ellipse((199, 917, 222, 940), fill=hex_rgba(SAGE, 135))
    base.alpha_composite(accents)

    text_layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    text_draw = ImageDraw.Draw(text_layer)
    headline = font(SERIF_BOLD, 78)
    line_one = "Something good"
    line_two = "is brewing."
    width_one = text_draw.textbbox((0, 0), line_one, font=headline)[2]
    width_two = text_draw.textbbox((0, 0), line_two, font=headline)[2]
    text_draw.text(((WIDTH - width_one) / 2, 1290), line_one, font=headline, fill=ESPRESSO)
    text_draw.text(((WIDTH - width_two) / 2, 1380), line_two, font=headline, fill=ESPRESSO)

    subcopy = "COMING SOON"
    subcopy_font = font(SANS, 27)
    subcopy_width = text_draw.textbbox((0, 0), subcopy, font=subcopy_font)[2]
    text_draw.text(((WIDTH - subcopy_width) / 2, 1515), subcopy, font=subcopy_font, fill=SAGE_TEXT)
    base.alpha_composite(text_layer)

    grain = Image.effect_noise(base.size, 16).convert("L")
    grain_layer = Image.merge("RGBA", (grain, grain, grain, Image.new("L", base.size, 4)))
    return Image.alpha_composite(base, grain_layer).convert("RGB")


def encode_exports() -> None:
    mp4 = EXPORTS / "mugsy-wave-coming-soon.mp4"
    gif = EXPORTS / "mugsy-wave-coming-soon-preview.gif"

    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-framerate",
            str(FPS),
            "-i",
            str(FINAL_FRAMES / "frame-%04d.png"),
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            "-movflags",
            "+faststart",
            "-crf",
            "18",
            str(mp4),
        ],
        check=True,
    )
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-loglevel",
            "error",
            "-i",
            str(mp4),
            "-filter_complex",
            "[0:v]fps=8,scale=360:-1:flags=lanczos,split[s0][s1];"
            "[s0]palettegen=max_colors=128:stats_mode=diff[p];"
            "[s1][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle",
            "-loop",
            "0",
            str(gif),
        ],
        check=True,
    )


def write_manifest() -> None:
    manifest = {
        "campaign": "Mugsy waving — coming soon teaser",
        "status": "locally generated social asset; no launch date or App Store availability claim",
        "format": {
            "pixels": "1080x1920",
            "aspect_ratio": "9:16",
            "duration_seconds": DURATION,
            "frame_rate": FPS,
            "video": "H.264 MP4, silent",
        },
        "on_frame_copy": {
            "headline": "Something good is brewing.",
            "support": "COMING SOON",
        },
        "caption": "Mugsy says hi. 👋 Something good is brewing. Mugshot is coming soon.\n\n#MugshotApp #MeetMugsy #ComingSoon",
        "alt_text": "Mugsy, Mugshot’s smiling mug character, waves and blinks on a warm cream and mint background beside the words ‘Something good is brewing.’",
        "provenance": {
            "character": "Canonical MugsyModelView and playfulWavingMugsy configuration rendered from repository SwiftUI geometry.",
            "logo": str(APP_ICON.relative_to(ROOT)),
            "composition": "build_asset.py using Pillow and ffmpeg",
            "native_image_generation": "none",
        },
        "exports": [
            "exports/mugsy-wave-coming-soon.mp4",
            "exports/mugsy-wave-coming-soon-preview.gif",
            "exports/mugsy-wave-coming-soon-cover.png",
        ],
    }
    (PACK / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")


def main() -> None:
    EXPORTS.mkdir(parents=True, exist_ok=True)
    render_canonical_mugsy_frames()
    if FINAL_FRAMES.exists():
        shutil.rmtree(FINAL_FRAMES)
    FINAL_FRAMES.mkdir(parents=True)

    mugsy_frames = sorted(FRAME_SOURCE.glob("mugsy-wave-*.png"))
    if len(mugsy_frames) != 36:
        raise SystemExit(f"Expected 36 Mugsy frames, found {len(mugsy_frames)}")

    for index in range(FPS * DURATION):
        frame = compose_frame(index, mugsy_frames)
        frame.save(FINAL_FRAMES / f"frame-{index:04d}.png", optimize=False)

    cover = compose_frame(27, mugsy_frames)
    cover.save(EXPORTS / "mugsy-wave-coming-soon-cover.png", optimize=True)
    encode_exports()
    write_manifest()

    shutil.rmtree(FRAME_SOURCE)
    shutil.rmtree(FINAL_FRAMES)
    print(f"Built Mugsy waving teaser in {EXPORTS}")


if __name__ == "__main__":
    main()
