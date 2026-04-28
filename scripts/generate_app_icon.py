"""Generate Clarity app icon — purple donut + euro.

- Diagonal gradient violet→indigo
- Top-left radial highlight
- White donut arc (3/4) with subtle end-dot
- Bold centered euro symbol
Exports 1024×1024 PNGs.
"""
from __future__ import annotations

import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Clarity" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
SIZE = 1024


def hex_to_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))  # type: ignore


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def diagonal_gradient(size: int, tl: tuple[int, int, int], br: tuple[int, int, int]) -> Image.Image:
    img = Image.new("RGB", (size, size), tl)
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = (
                int(lerp(tl[0], br[0], t)),
                int(lerp(tl[1], br[1], t)),
                int(lerp(tl[2], br[2], t)),
            )
    return img


def radial(size: int, cx: float, cy: float, radius: float, alpha_center: int,
           color: tuple[int, int, int] = (255, 255, 255)) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = layer.load()
    r2 = radius * radius
    for y in range(size):
        dy = y - cy
        for x in range(size):
            dx = x - cx
            d2 = dx * dx + dy * dy
            if d2 >= r2:
                continue
            t = 1 - (d2 / r2)
            a = int(alpha_center * (t ** 2))
            px[x, y] = (color[0], color[1], color[2], a)
    return layer


def draw_arc(size: int, cx: int, cy: int, outer_r: int, thickness: int,
             start_deg: float, end_deg: float, color: tuple[int, int, int, int]) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    bbox = [cx - outer_r, cy - outer_r, cx + outer_r, cy + outer_r]
    d.arc(bbox, start=start_deg, end=end_deg, fill=color, width=thickness)
    return layer


def build(bg_top: str, bg_bottom: str, highlight_alpha: int, out_path: Path) -> None:
    tl = hex_to_rgb(bg_top)
    br = hex_to_rgb(bg_bottom)
    base = diagonal_gradient(SIZE, tl, br).convert("RGBA")

    glow = radial(SIZE, SIZE * 0.25, SIZE * 0.22, SIZE * 0.75, highlight_alpha)
    glow = glow.filter(ImageFilter.GaussianBlur(radius=40))
    base = Image.alpha_composite(base, glow)

    dark = radial(SIZE, SIZE * 0.85, SIZE * 0.88, SIZE * 0.55, 90, color=(0, 0, 0))
    dark = dark.filter(ImageFilter.GaussianBlur(radius=30))
    base = Image.alpha_composite(base, dark)

    outer_r = int(SIZE * 0.34)
    thickness = int(SIZE * 0.095)
    cx, cy = SIZE // 2, SIZE // 2

    # Shadow under donut
    shadow_arc = draw_arc(SIZE, cx, cy + 14, outer_r, thickness, 135, 45, (0, 0, 0, 130))
    shadow_arc = shadow_arc.filter(ImageFilter.GaussianBlur(radius=22))
    base = Image.alpha_composite(base, shadow_arc)

    # Donut
    donut = draw_arc(SIZE, cx, cy, outer_r, thickness, 135, 45, (255, 255, 255, 255))
    base = Image.alpha_composite(base, donut)

    # End-of-arc dot
    dot_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    dd = ImageDraw.Draw(dot_layer)
    end_angle_rad = math.radians(45)
    arc_center_r = outer_r - thickness / 2
    ax = cx + arc_center_r * math.cos(end_angle_rad)
    ay = cy + arc_center_r * math.sin(end_angle_rad)
    dot_r = thickness // 2 + 4
    dd.ellipse([ax - dot_r, ay - dot_r, ax + dot_r, ay + dot_r], fill=(255, 255, 255, 255))
    inner_r = dot_r - 16
    bg_mid = tuple(int((tl[i] + br[i]) / 2) for i in range(3)) + (255,)
    dd.ellipse([ax - inner_r, ay - inner_r, ax + inner_r, ay + inner_r], fill=bg_mid)
    base = Image.alpha_composite(base, dot_layer)

    # Euro
    font_size = int(SIZE * 0.48)
    font_paths = [
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    font = ImageFont.load_default()
    for p in font_paths:
        try:
            font = ImageFont.truetype(p, font_size)
            break
        except Exception:
            continue

    euro_layer = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ed = ImageDraw.Draw(euro_layer)
    text = "€"
    bbox = ed.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (SIZE - tw) // 2 - bbox[0]
    ty = (SIZE - th) // 2 - bbox[1] - 10

    shadow_euro = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow_euro)
    sd.text((tx, ty + 10), text, font=font, fill=(0, 0, 0, 110))
    shadow_euro = shadow_euro.filter(ImageFilter.GaussianBlur(radius=14))
    base = Image.alpha_composite(base, shadow_euro)
    ed.text((tx, ty), text, font=font, fill=(255, 255, 255, 255))
    base = Image.alpha_composite(base, euro_layer)

    base.convert("RGB").save(out_path, "PNG", optimize=True)
    print(f"wrote {out_path}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build("#A78BFA", "#4F46E5", 130, OUT_DIR / "AppIcon.png")
    build("#3B1D7A", "#0F0C29", 90, OUT_DIR / "AppIcon-Dark.png")


if __name__ == "__main__":
    main()
