#!/usr/bin/env python3
"""Build deterministic Instagram launch assets for Mugshot."""

from __future__ import annotations

import json
import math
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[3]
PACK = Path(__file__).resolve().parent
SOURCE = PACK / "source"
EXPORTS = PACK / "exports"

W, H = 1080, 1350
RW, RH = 1080, 1920

CREAM = "#FAF6F0"
FOAM = "#FFFFFF"
ESPRESSO = "#1F1712"
ROAST = "#5B4636"
SAGE = "#6E8F7C"
SAGE_TEXT = "#4D6F5D"
MINT = "#A8CDB8"
SAND = "#EEE6D8"
LINE = "#E3DED4"
GOLD = "#D4AD55"
TERRACOTTA = "#C26355"

SERIF = "/System/Library/Fonts/Supplemental/Georgia.ttf"
SERIF_BOLD = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
SANS = "/System/Library/Fonts/Avenir Next.ttc"

APP_ICON = ROOT / "testMugshot/Assets.xcassets/MugshotAppIcon.imageset/mugshot-app-icon.png"
MUGSY = ROOT / "testMugshot/Assets.xcassets/MugsyComingSoon.imageset/MugsyComingSoon.png"
CAPTURE = ROOT / "testMugshot/Assets.xcassets/OnboardingMarketing01Capture.imageset/onboarding-marketing-01-capture.png"
MAP_UI = ROOT / "testMugshot/Assets.xcassets/OnboardingMarketing02Map.imageset/onboarding-marketing-02-map.png"
PASSPORT = ROOT / "testMugshot/Assets.xcassets/OnboardingMarketing07TastePassport.imageset/onboarding-marketing-07-taste-passport.png"
CITRUS_SCENE = SOURCE / "citrus-memory-scene.png"
MAP_SCENE = SOURCE / "coffee-map-scene.png"


def font(path: str, size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size, index=index)


def hex_rgba(value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def cover(image: Image.Image, size: tuple[int, int], focus_y: float = 0.5) -> Image.Image:
    image = image.convert("RGB")
    target_w, target_h = size
    scale = max(target_w / image.width, target_h / image.height)
    resized = image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)
    left = max(0, (resized.width - target_w) // 2)
    max_top = max(0, resized.height - target_h)
    top = round(max_top * min(1, max(0, focus_y)))
    return resized.crop((left, top, left + target_w, top + target_h))


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = image.copy()
    image.thumbnail(size, Image.Resampling.LANCZOS)
    return image


def rounded_image(image: Image.Image, size: tuple[int, int], radius: int) -> Image.Image:
    fitted = cover(image, size)
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    fitted.putalpha(mask)
    return fitted


def vertical_gradient(size: tuple[int, int], top, bottom) -> Image.Image:
    grad = Image.new("RGBA", size)
    px = grad.load()
    for y in range(size[1]):
        t = y / max(1, size[1] - 1)
        c = tuple(round(top[i] * (1 - t) + bottom[i] * t) for i in range(4))
        for x in range(size[0]):
            px[x, y] = c
    return grad


def add_noise(image: Image.Image, opacity: int = 10) -> Image.Image:
    noise = Image.effect_noise(image.size, 18).convert("L")
    grain = Image.merge("RGBA", (noise, noise, noise, Image.new("L", image.size, opacity)))
    return Image.alpha_composite(image.convert("RGBA"), grain)


def wrap(draw: ImageDraw.ImageDraw, text: str, face: ImageFont.FreeTypeFont, max_width: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    current = ""
    for word in words:
        trial = f"{current} {word}".strip()
        if draw.textbbox((0, 0), trial, font=face)[2] <= max_width or not current:
            current = trial
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    return lines


def draw_wrapped(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, face, fill, max_width: int, spacing: int) -> int:
    x, y = xy
    lines = wrap(draw, text, face, max_width)
    ascent, descent = face.getmetrics()
    line_h = ascent + descent + spacing
    for line in lines:
        draw.text((x, y), line, font=face, fill=fill)
        y += line_h
    return y


def draw_wordmark(draw: ImageDraw.ImageDraw, y: int, fill, right: int | None = None, small: bool = False) -> None:
    face = font(SANS, 28 if small else 32)
    text = "MUGSHOT"
    width = draw.textbbox((0, 0), text, font=face)[2]
    x = (right - width) if right is not None else 72
    draw.text((x, y), text, font=face, fill=fill, stroke_width=0)


def draw_coming_soon(draw: ImageDraw.ImageDraw, y: int, fill, x: int = 72) -> None:
    face = font(SANS, 23)
    draw.text((x, y), "COMING SOON", font=face, fill=fill)


def shadowed_panel(base: Image.Image, box: tuple[int, int, int, int], radius: int = 44, fill=FOAM, shadow_alpha: int = 40) -> None:
    x0, y0, x1, y1 = box
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x0, y0 + 18, x1, y1 + 18), radius=radius, fill=(31, 23, 18, shadow_alpha))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    base.alpha_composite(shadow)
    ImageDraw.Draw(base).rounded_rectangle(box, radius=radius, fill=fill, outline=LINE, width=2)


def phone_screen(screen_path: Path, width: int) -> Image.Image:
    screen = Image.open(screen_path).convert("RGB")
    height = round(width * screen.height / screen.width)
    screen = screen.resize((width, height), Image.Resampling.LANCZOS)
    radius = round(width * 0.095)
    mask = Image.new("L", screen.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, screen.width, screen.height), radius=radius, fill=255)
    screen.putalpha(mask)
    frame = Image.new("RGBA", (width + 20, height + 20), (0, 0, 0, 0))
    ImageDraw.Draw(frame).rounded_rectangle((0, 0, frame.width - 1, frame.height - 1), radius=radius + 10, fill=ESPRESSO)
    frame.alpha_composite(screen, (10, 10))
    return frame


def save(image: Image.Image, filename: str) -> None:
    out = EXPORTS / filename
    image.convert("RGB").save(out, "PNG", optimize=True)


def post_01() -> None:
    bg = cover(Image.open(CITRUS_SCENE), (W, H), focus_y=0.36).convert("RGBA")
    bg = ImageEnhance.Color(bg).enhance(0.88)
    bg = ImageEnhance.Contrast(bg).enhance(1.06)
    bg = Image.alpha_composite(bg, vertical_gradient((W, H), (15, 10, 7, 172), (15, 10, 7, 35)))
    bg = add_noise(bg, 8)
    d = ImageDraw.Draw(bg)
    draw_wordmark(d, 62, FOAM)
    draw_coming_soon(d, 104, hex_rgba(FOAM, 205))
    y = draw_wrapped(d, (72, 222), "Something worth remembering is brewing.", font(SERIF_BOLD, 89), FOAM, 820, 4)
    d.line((72, y + 22, 286, y + 22), fill=MINT, width=7)
    d.text((72, H - 104), "01 / THE FIRST SIP", font=font(SANS, 22), fill=hex_rgba(FOAM, 220))
    save(bg, "01-something-is-brewing.png")


def post_02() -> None:
    bg = cover(Image.open(MAP_SCENE), (W, H), focus_y=0.42).convert("RGBA")
    bg = ImageEnhance.Color(bg).enhance(0.82)
    bg = Image.alpha_composite(bg, vertical_gradient((W, H), (250, 246, 240, 230), (250, 246, 240, 12)))
    bg = add_noise(bg, 7)
    d = ImageDraw.Draw(bg)
    draw_wordmark(d, 62, ESPRESSO)
    y = draw_wrapped(d, (72, 175), "What if every sip left a pin?", font(SERIF_BOLD, 86), ESPRESSO, 820, 3)
    d.text((76, y + 18), "Your coffee world is about to take shape.", font=font(SANS, 29), fill=ROAST)
    for i, (x, color) in enumerate([(760, SAGE), (840, GOLD), (920, TERRACOTTA)]):
        d.ellipse((x - 23, H - 112, x + 23, H - 66), fill=color, outline=FOAM, width=4)
        d.polygon([(x - 12, H - 72), (x + 12, H - 72), (x, H - 52)], fill=color)
    save(bg, "02-every-sip-leaves-a-pin.png")


def post_03() -> None:
    base = Image.new("RGBA", (W, H), CREAM)
    d = ImageDraw.Draw(base)
    d.ellipse((760, -90, 1180, 330), fill=hex_rgba(MINT, 90))
    d.ellipse((-180, 990, 300, 1470), fill=hex_rgba(SAND, 210))
    draw_wordmark(d, 62, ESPRESSO)
    d.text((72, 158), "The drink.", font=font(SERIF_BOLD, 80), fill=ESPRESSO)
    d.text((72, 247), "The place.", font=font(SERIF_BOLD, 80), fill=SAGE_TEXT)
    d.text((72, 336), "The little moment.", font=font(SERIF_BOLD, 80), fill=ESPRESSO)
    d.text((75, 445), "Keep all three.", font=font(SANS, 30), fill=ROAST)

    panel = (116, 540, 823, 1326)
    shadowed_panel(base, panel, radius=52)
    screenshot = Image.open(CAPTURE).convert("RGB")
    crop = screenshot.crop((0, 0, screenshot.width, 1120))
    shot = rounded_image(crop, (675, 752), 38)
    base.alpha_composite(shot, (132, 557))
    save(add_noise(base, 4), "03-the-little-moment.png")


def post_04() -> None:
    base = Image.new("RGBA", (W, H), SAGE)
    d = ImageDraw.Draw(base)
    for y in range(85, H, 92):
        d.line((0, y, W, y - 180), fill=hex_rgba(MINT, 45), width=2)
    draw_wordmark(d, 62, FOAM)
    d.text((72, 160), "Your taste", font=font(SERIF_BOLD, 89), fill=FOAM)
    d.text((72, 258), "has a story.", font=font(SERIF_BOLD, 89), fill=FOAM)
    d.text((77, 371), "Mugshot helps you see the pattern.", font=font(SANS, 29), fill=hex_rgba(FOAM, 225))

    phone = phone_screen(PASSPORT, 500)
    phone = phone.rotate(-4, resample=Image.Resampling.BICUBIC, expand=True)
    phone_shadow = Image.new("RGBA", phone.size, (31, 23, 18, 0))
    phone_shadow.putalpha(phone.getchannel("A").point(lambda alpha: round(alpha * 0.38)))
    phone_shadow = phone_shadow.filter(ImageFilter.GaussianBlur(32))
    base.alpha_composite(phone_shadow, (450, 476))
    base.alpha_composite(phone, (450, 450))

    stamp = Image.new("RGBA", (285, 285), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stamp)
    sd.ellipse((10, 10, 275, 275), outline=FOAM, width=7)
    sd.ellipse((31, 31, 254, 254), outline=hex_rgba(FOAM, 170), width=3)
    sd.text((66, 76), "TASTE", font=font(SANS, 31), fill=FOAM)
    sd.text((47, 121), "PASSPORT", font=font(SANS, 31), fill=FOAM)
    sd.arc((90, 160, 195, 238), 200, 340, fill=MINT, width=9)
    stamp = stamp.rotate(7, resample=Image.Resampling.BICUBIC, expand=True)
    base.alpha_composite(stamp, (86, 915))
    save(add_noise(base, 6), "04-your-taste-has-a-story.png")


def post_05() -> None:
    base = Image.new("RGBA", (W, H), CREAM)
    d = ImageDraw.Draw(base)
    d.rounded_rectangle((40, 40, W - 40, H - 40), radius=58, outline=MINT, width=3)
    draw_wordmark(d, 72, ESPRESSO)
    d.text((72, 164), "Meet Mugsy.", font=font(SERIF_BOLD, 94), fill=ESPRESSO)
    y = draw_wrapped(d, (75, 282), "Your guide to the sips worth remembering.", font(SANS, 32), ROAST, 690, 4)

    orbit = (198, 480, 898, 1180)
    d.ellipse(orbit, fill=hex_rgba(SAND, 120), outline=hex_rgba(MINT, 185), width=5)
    for angle, symbol, color in [(20, "PIN", SAGE), (110, "SIP", GOLD), (200, "SAVE", TERRACOTTA), (290, "TASTE", SAGE_TEXT)]:
        r = 348
        cx, cy = 548, 830
        x = cx + math.cos(math.radians(angle)) * r
        y0 = cy + math.sin(math.radians(angle)) * r
        d.ellipse((x - 54, y0 - 54, x + 54, y0 + 54), fill=FOAM, outline=LINE, width=3)
        face = font(SANS, 18)
        tw = d.textbbox((0, 0), symbol, font=face)[2]
        d.text((x - tw / 2, y0 - 12), symbol, font=face, fill=color)
    mugsy = contain(Image.open(MUGSY).convert("RGBA"), (640, 550))
    base.alpha_composite(mugsy, (220, 570))
    d.text((72, H - 113), "MUGSHOT · COMING SOON", font=font(SANS, 25), fill=SAGE_TEXT)
    save(add_noise(base, 5), "05-meet-mugsy.png")


def eased(t: float) -> float:
    return 1 - (1 - max(0, min(1, t))) ** 3


def centered_text(draw, text, y, face, fill):
    box = draw.textbbox((0, 0), text, font=face)
    draw.text(((RW - (box[2] - box[0])) / 2, y), text, font=face, fill=fill)


def reel_frame(t: float) -> Image.Image:
    base = Image.new("RGBA", (RW, RH), CREAM)
    d = ImageDraw.Draw(base)
    d.ellipse((-260, -240, 700, 720), fill=hex_rgba(MINT, 72))
    d.ellipse((610, 1260, 1370, 2020), fill=hex_rgba(SAND, 190))
    draw_wordmark(d, 130, ESPRESSO)

    beats = [(0.0, 1.35, "A sip."), (1.35, 2.7, "A place."), (2.7, 4.15, "A little moment.")]
    active = next((b for b in beats if b[0] <= t < b[1]), None)
    if active:
        p = eased(min((t - active[0]) / 0.35, (active[1] - t) / 0.28, 1))
        alpha = round(255 * max(0, p))
        y = round(690 + 24 * (1 - p))
        centered_text(d, active[2], y, font(SERIF_BOLD, 104), hex_rgba(ESPRESSO, alpha))
        d.ellipse((RW / 2 - 12, 920, RW / 2 + 12, 944), fill=hex_rgba(SAGE, alpha))
    else:
        p = eased(min((t - 4.15) / 0.55, (7.0 - t) / 0.35, 1))
        icon_src = Image.open(APP_ICON).convert("RGB").crop((138, 138, 886, 886))
        size = round(270 * (0.9 + 0.1 * p))
        icon = rounded_image(icon_src, (size, size), round(size * 0.2))
        base.alpha_composite(icon, ((RW - size) // 2, 430))
        centered_text(d, "Remember it all.", 790, font(SERIF_BOLD, 92), hex_rgba(ESPRESSO, round(255 * p)))
        centered_text(d, "MUGSHOT", 935, font(SANS, 35), hex_rgba(SAGE_TEXT, round(255 * p)))
        centered_text(d, "COMING SOON", 990, font(SANS, 23), hex_rgba(ROAST, round(220 * p)))

    mugsy = contain(Image.open(MUGSY).convert("RGBA"), (300, 260))
    bob = round(math.sin(t * math.pi * 2 / 1.4) * 7)
    base.alpha_composite(mugsy, (RW - 350, RH - 650 + bob))
    return add_noise(base, 4).convert("RGB")


def build_reel() -> None:
    frames = SOURCE / "reel-frames"
    if frames.exists():
        shutil.rmtree(frames)
    frames.mkdir(parents=True)
    fps = 24
    duration = 7
    for i in range(fps * duration):
        reel_frame(i / fps).save(frames / f"frame-{i:04d}.png", optimize=False)

    mp4 = EXPORTS / "06-mugshot-teaser-reel.mp4"
    gif = EXPORTS / "06-mugshot-teaser-reel-preview.gif"
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
        "-i", str(frames / "frame-%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart", "-crf", "18", str(mp4),
    ], check=True)
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-framerate", str(fps),
        "-i", str(frames / "frame-%04d.png"), "-filter_complex",
        "[0:v]fps=8,scale=360:-1:flags=lanczos,split[s0][s1];"
        "[s0]palettegen=max_colors=128:stats_mode=diff[p];"
        "[s1][p]paletteuse=dither=bayer:bayer_scale=3:diff_mode=rectangle",
        "-loop", "0", str(gif),
    ], check=True)
    shutil.rmtree(frames)


def write_manifest() -> None:
    manifest = {
        "campaign": "Mugshot launch hype — soft reveal v1",
        "status": "locally generated social assets; no launch date or App Store availability claim",
        "feed_spec": {"pixels": "1080x1350", "aspect_ratio": "4:5", "format": "PNG"},
        "reel_spec": {"pixels": "1080x1920", "aspect_ratio": "9:16", "duration_seconds": 7, "format": "MP4 (H.264), silent"},
        "palette": {"cream": CREAM, "espresso": ESPRESSO, "sage": SAGE, "mint": MINT, "sand": SAND},
        "assets": [
            {
                "file": "exports/01-something-is-brewing.png",
                "role": "mystery teaser",
                "caption": "Coffee has a funny way of becoming a timestamp—a table, a person, a rainy Tuesday. We’re building a place to keep all of it. Mugshot is coming soon.\n\n#MugshotApp #CoffeeJournal #ComingSoon",
                "alt_text": "An iced citrus latte in warm cafe light behind the headline ‘Something worth remembering is brewing.’",
                "source": "source/citrus-memory-scene.png; native ImageGen background with deterministic text overlay",
            },
            {
                "file": "exports/02-every-sip-leaves-a-pin.png",
                "role": "map feature tease",
                "caption": "Your coffee map shouldn’t be a list of pins. It should be a map of moments. Soon.\n\n#MugshotApp #CoffeeLovers #CafeHopping",
                "alt_text": "A tactile cafe map and espresso still life behind the question ‘What if every sip left a pin?’",
                "source": "source/coffee-map-scene.png; native ImageGen background with deterministic text overlay",
            },
            {
                "file": "exports/03-the-little-moment.png",
                "role": "product promise",
                "caption": "The drink. The place. The little moment around it. Capture every sip with Mugshot. Coming soon.\n\n#MugshotApp #CoffeeMemories #CoffeeJournal",
                "alt_text": "Mugshot’s Capture Every Sip screen and Mugsy beneath the words ‘The drink. The place. The little moment.’",
                "source": "repository onboarding artwork and Mugsy asset",
            },
            {
                "file": "exports/04-your-taste-has-a-story.png",
                "role": "Taste Passport reveal",
                "caption": "Over time, your orders start telling a story. Mugshot turns those memories into a Taste Passport that grows with you.\n\n#MugshotApp #TastePassport #CoffeeLovers",
                "alt_text": "The Mugshot Taste Passport screen on a sage background beneath the headline ‘Your taste has a story.’",
                "source": "repository Taste Passport onboarding artwork",
            },
            {
                "file": "exports/05-meet-mugsy.png",
                "role": "mascot reveal",
                "caption": "Meet Mugsy: part guide, part memory-keeper, fully invested in your next great sip.\n\n#MeetMugsy #MugshotApp #ComingSoon",
                "alt_text": "Mugsy, Mugshot’s smiling mug mascot, surrounded by orbiting labels for sip, pin, save, and taste.",
                "source": "repository Mugsy asset",
            },
            {
                "file": "exports/06-mugshot-teaser-reel.mp4",
                "role": "7-second Reel or Story teaser",
                "caption": "A sip. A place. A little moment. Remember it all. Mugshot is coming soon.\n\n#MugshotApp #CoffeeJournal #ComingSoon",
                "alt_text": "Animated words build from a sip and a place to a little moment, ending on the Mugshot mark and Mugsy.",
                "source": "deterministic animation using repository app icon and Mugsy asset",
            },
        ],
        "suggested_sequence": [
            "Day 1: mystery teaser",
            "Day 3: map feature tease",
            "Day 5: product promise",
            "Day 7: Taste Passport reveal",
            "Day 9: meet Mugsy",
            "Day 11: Reel recap; pin this post",
        ],
        "provenance": {
            "native_image_generation": ["source/citrus-memory-scene.png", "source/coffee-map-scene.png"],
            "generation_prompts": ["source/citrus-memory-scene.prompt.txt", "source/coffee-map-scene.prompt.txt"],
            "deterministic_composition": "build_assets.py using Pillow and ffmpeg",
            "brand_sources": [str(APP_ICON.relative_to(ROOT)), str(MUGSY.relative_to(ROOT)), str(CAPTURE.relative_to(ROOT)), str(PASSPORT.relative_to(ROOT))],
        },
    }
    (PACK / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")


def validate_inputs() -> None:
    missing = [path for path in [APP_ICON, MUGSY, CAPTURE, PASSPORT, CITRUS_SCENE, MAP_SCENE] if not path.exists() or path.stat().st_size == 0]
    if missing:
        raise SystemExit("Missing required source assets:\n" + "\n".join(str(path) for path in missing))


def main() -> None:
    EXPORTS.mkdir(parents=True, exist_ok=True)
    validate_inputs()
    post_01()
    post_02()
    post_03()
    post_04()
    post_05()
    build_reel()
    write_manifest()
    print(f"Built Mugshot launch pack in {EXPORTS}")


if __name__ == "__main__":
    main()
