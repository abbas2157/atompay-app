"""Renders every launcher icon and launch image from the AtomPay logo.

Run from the repo root after the logo changes:

    python tool/brand/generate_icons.py

Source: tool/brand/atompay_logo_source.png (transparent, mark above the
"Atompay / Pay in Steps" wordmark). Only the AP mark is used.

- Android adaptive icon: white background, the mark in the 66 dp safe zone.
  Android 12+ draws it on the nucleus splash, masked to a circle.
- Android legacy icon (pre-8.0): white rounded square with the mark.
- Launch logo (Android pre-12, iOS): the mark on a white disc, the same
  size Android 12+ shows, on the nucleus background.
- iOS app icons: opaque white square (the App Store rejects alpha).
"""

import json
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SOURCE = os.path.join(ROOT, "tool", "brand", "atompay_logo_source.png")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS = os.path.join(ROOT, "ios", "Runner", "Assets.xcassets")
WHITE = (255, 255, 255, 255)

DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

# Fractions of the canvas the mark's width takes.
ADAPTIVE_MARK = 52 / 108  # inside the 66 dp safe circle
LEGACY_MARK = 0.64
IOS_MARK = 0.62
# Launch disc: 160 dp, the circle Android 12+ masks the icon to, with room
# around the mark. The in-app splash (SplashScreen) draws the same disc.
DISC_DP = 160
DISC_MARK_DP = 100

# iOS launch screen. The storyboard centres this image on `paper`, and the
# Flutter SplashScreen draws the same lockup, so the hand-off doesn't jump:
# a rounded white tile with the mark, then ATOMPAY / PAY IN STEPS.
FONTS = os.path.join(ROOT, "assets", "fonts")
INK = (20, 21, 26, 255)  # tokens.dart `ink`
MUTED = (108, 108, 116, 255)  # tokens.dart `muted`
LAUNCH_TILE_DP = 120
LAUNCH_TILE_MARK_DP = 84
LAUNCH_GAP_DP = 20  # tile to wordmark
LAUNCH_SUB_GAP_DP = 7  # wordmark to tagline
# `t.h1` is 30/w800 and `t.xs` 11/w700; SplashScreen overrides the tracking.
LAUNCH_WORD = ("ATOMPAY", "PlusJakartaSans-ExtraBold.ttf", 30, -0.8, INK)
LAUNCH_SUB = ("PAY IN STEPS", "PlusJakartaSans-Bold.ttf", 11, 3.4, MUTED)


def tracked(draw, xy, text, font, spacing, fill):
    """PIL has no letter-spacing, so step through the glyphs."""
    x, y = xy
    for ch in text:
        draw.text((x, y), ch, font=font, fill=fill)
        x += draw.textlength(ch, font=font) + spacing


def tracked_width(draw, text, font, spacing):
    if not text:
        return 0.0
    return sum(draw.textlength(c, font=font) for c in text) + spacing * (len(text) - 1)


def launch_lockup(scale: int) -> Image.Image:
    """The iOS launch image at `scale`x, on a transparent canvas."""
    tile_px = LAUNCH_TILE_DP * scale
    pad = 24 * scale  # room for the tile's shadow
    probe = ImageDraw.Draw(Image.new("RGBA", (1, 1)))

    rows = []
    for text, file, size, spacing, fill in (LAUNCH_WORD, LAUNCH_SUB):
        font = ImageFont.truetype(os.path.join(FONTS, file), size * scale)
        width = tracked_width(probe, text, font, spacing * scale)
        ascent, descent = font.getmetrics()
        rows.append((text, font, spacing * scale, fill, width, ascent + descent))

    width = round(max([tile_px] + [r[4] for r in rows]) + pad * 2)
    height = round(
        tile_px
        + LAUNCH_GAP_DP * scale
        + rows[0][5]
        + LAUNCH_SUB_GAP_DP * scale
        + rows[1][5]
        + pad * 2
    )
    canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))

    # The splash's `boxShadow`: 0.08 ink, blur 40, offset (0, 16).
    tile = shape(tile_px, "square")
    place(tile, load_mark(), LAUNCH_TILE_MARK_DP * scale)
    tile_x = (width - tile_px) // 2
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow.paste(
        Image.new("RGBA", (tile_px, tile_px), INK[:3] + (20,)),
        (tile_x, pad + 8 * scale),
        tile.getchannel("A"),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10 * scale)))
    canvas.alpha_composite(tile, (tile_x, pad))

    draw = ImageDraw.Draw(canvas)
    y = pad + tile_px + LAUNCH_GAP_DP * scale
    for text, font, spacing, fill, text_w, line_h in rows:
        tracked(draw, ((width - text_w) / 2, y), text, font, spacing, fill)
        y += line_h + LAUNCH_SUB_GAP_DP * scale
    return canvas


def load_mark() -> Image.Image:
    logo = Image.open(SOURCE).convert("RGBA")
    alpha = logo.getchannel("A")
    width, height = logo.size
    # The mark is the first band of content from the top; a gap separates
    # it from the wordmark.
    rows = [y for y in range(height) if alpha.crop((0, y, width, y + 1)).getbbox()]
    end = rows[0]
    for y in rows[1:]:
        if y - end > 40:
            break
        end = y
    band = logo.crop((0, rows[0], width, end + 1))
    return band.crop(band.getchannel("A").getbbox())


def place(canvas: Image.Image, mark: Image.Image, mark_width: float) -> None:
    w = round(mark_width)
    h = round(mark.height * w / mark.width)
    scaled = mark.resize((w, h), Image.LANCZOS)
    x = (canvas.width - w) // 2
    y = (canvas.height - h) // 2
    canvas.alpha_composite(scaled, (x, y))


def shape(size: int, kind: str) -> Image.Image:
    """A white circle or rounded square, drawn 4x and scaled for smooth edges."""
    big = size * 4
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    if kind == "circle":
        draw.ellipse((0, 0, big - 1, big - 1), fill=WHITE)
    else:
        draw.rounded_rectangle((0, 0, big - 1, big - 1), radius=big * 0.22, fill=WHITE)
    return img.resize((size, size), Image.LANCZOS)


def save(img: Image.Image, path: str, opaque: bool = False) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    (img.convert("RGB") if opaque else img).save(path, optimize=True)
    print(os.path.relpath(path, ROOT), img.size)


def main() -> None:
    mark = load_mark()

    for name, d in DENSITIES.items():
        # Adaptive foreground: 108 dp, transparent.
        size = round(108 * d)
        fg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        place(fg, mark, size * ADAPTIVE_MARK)
        save(fg, os.path.join(RES, f"mipmap-{name}", "ic_launcher_foreground.png"))

        # Legacy icon: 48 dp.
        size = round(48 * d)
        legacy = shape(size, "square")
        place(legacy, mark, size * LEGACY_MARK)
        save(legacy, os.path.join(RES, f"mipmap-{name}", "ic_launcher.png"))

        # Pre-Android-12 launch logo.
        disc = shape(round(DISC_DP * d), "circle")
        place(disc, mark, DISC_MARK_DP * d)
        save(disc, os.path.join(RES, f"drawable-{name}", "launch_logo.png"))

    # iOS app icons, sized from the asset catalogue.
    icons = os.path.join(IOS, "AppIcon.appiconset")
    with open(os.path.join(icons, "Contents.json"), encoding="utf-8") as f:
        contents = json.load(f)
    done = set()
    for entry in contents["images"]:
        name = entry.get("filename")
        if not name or name in done:
            continue
        done.add(name)
        points = float(entry["size"].split("x")[0])
        size = round(points * int(entry["scale"].rstrip("x")))
        icon = Image.new("RGBA", (size, size), WHITE)
        place(icon, mark, size * IOS_MARK)
        save(icon, os.path.join(icons, name), opaque=True)

    # Push notification small icon: Android draws it as a white silhouette,
    # 24 dp with the mark inside 20 dp.
    for name, d in DENSITIES.items():
        size = round(24 * d)
        stat = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        place(stat, mark, 20 * d)
        alpha = stat.getchannel("A")
        white = Image.new("RGBA", stat.size, WHITE)
        white.putalpha(alpha)
        save(white, os.path.join(RES, f"drawable-{name}", "ic_stat_atompay.png"))

    # The mark alone, for the in-app splash and anywhere it sits on its own
    # background.
    clear = Image.new("RGBA", (1024, round(1024 * mark.height / mark.width)), (0, 0, 0, 0))
    place(clear, mark, 1024)
    save(clear, os.path.join(ROOT, "assets", "images", "atompay_mark_clear.png"))

    # iOS launch image: the full lockup at 1x, 2x and 3x.
    launch = os.path.join(IOS, "LaunchImage.imageset")
    for scale, suffix in [(1, ""), (2, "@2x"), (3, "@3x")]:
        save(launch_lockup(scale), os.path.join(launch, f"LaunchImage{suffix}.png"))


if __name__ == "__main__":
    main()
