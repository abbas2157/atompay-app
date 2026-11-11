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

from PIL import Image, ImageDraw

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

    # iOS launch image: the disc at 1x, 2x and 3x.
    launch = os.path.join(IOS, "LaunchImage.imageset")
    for scale, suffix in [(1, ""), (2, "@2x"), (3, "@3x")]:
        disc = shape(DISC_DP * scale, "circle")
        place(disc, mark, DISC_MARK_DP * scale)
        save(disc, os.path.join(launch, f"LaunchImage{suffix}.png"))


if __name__ == "__main__":
    main()
