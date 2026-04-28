#!/usr/bin/env python3
"""
generate_mockups.py — App Store screenshot mockup generator for Clarity.

Premium 6.7" (1290x2796) mockups in the style of top App Store apps
(Things, Linear, Notion, Duolingo): mesh-gradient background, accent-color
word in the headline, tinted bloom shadow under the device, optional
floating feature callout chip.

Usage:
    python3 scripts/generate_mockups.py
"""

from PIL import Image, ImageDraw, ImageFont, ImageFilter
from pathlib import Path
import math
import random
import sys

# ─── Canvas ───────────────────────────────────────────────────────────
W, H = 1290, 2796

# ─── Device geometry (iPhone 15/16 Pro proportions) ──────────────────
# Real iPhone 15 Pro: 2796x1290 screen, ~10-12px uniform bezel, 55px corner radius
DEVICE_SCREEN_W = 820
DEVICE_SCREEN_H = int(DEVICE_SCREEN_W * (2796 / 1290))
BEZEL = 11
CORNER_OUTER = 68
CORNER_INNER = 58
DEVICE_W = DEVICE_SCREEN_W + BEZEL * 2
DEVICE_H = DEVICE_SCREEN_H + BEZEL * 2

# Dynamic Island — real proportions (~126x37 on 1290-wide screen → scale to our width)
DI_SCALE = DEVICE_SCREEN_W / 1290
DI_W = int(126 * DI_SCALE * 1.55)
DI_H = int(37 * DI_SCALE * 1.55)
DI_RADIUS = DI_H // 2
DI_TOP_OFFSET = int(11 * DI_SCALE * 1.8)

# Buttons
SIDE_BTN_W = 5

# Anchor: leave more room below text, device higher up
DEVICE_X = (W - DEVICE_W) // 2
DEVICE_Y = H - DEVICE_H - 200

SCREEN_X = DEVICE_X + BEZEL
SCREEN_Y = DEVICE_Y + BEZEL

STATUS_BAR_CROP = 130

FONT_PATH = "/System/Library/Fonts/SFNS.ttf"
FONT_ROUNDED_PATH = "/System/Library/Fonts/SFNSRounded.ttf"
EMOJI_FONT_PATH = "/System/Library/Fonts/Apple Color Emoji.ttc"
EMOJI_NATIVE_SIZES = [160, 137, 109, 96, 80, 72, 64, 48, 40, 32]


def render_emoji(emoji: str, target_size: int) -> Image.Image:
    """Render an Apple color emoji at a supported strike size, then scale."""
    font = None
    for size in EMOJI_NATIVE_SIZES:
        try:
            font = ImageFont.truetype(EMOJI_FONT_PATH, size)
            break
        except OSError:
            continue
    if font is None:
        return Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    bb = font.getbbox(emoji)
    w = bb[2] - bb[0] + 20
    h = bb[3] - bb[1] + 20
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    d.text((-bb[0] + 10, -bb[1] + 10), emoji, font=font, embedded_color=True)
    # Scale keeping aspect
    scale = target_size / max(w, h)
    new_size = (max(int(w * scale), 1), max(int(h * scale), 1))
    return layer.resize(new_size, Image.LANCZOS)


def load_font(size: int, weight: str = "Bold", rounded: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_ROUNDED_PATH if rounded else FONT_PATH
    font = ImageFont.truetype(path, size)
    try:
        font.set_variation_by_name(weight.encode())
    except Exception:
        pass
    return font


# ─── Mockup configurations ────────────────────────────────────────────
# `accent`: word(s) inside `headline` that get colored (case-insensitive match)
# `blobs`: list of (x_frac, y_frac, radius, rgb, alpha) for mesh gradient
# `chip`: optional floating feature pill (text, emoji, position anchor)
MOCKUPS = [
    {
        "input": "1_home.png",
        "output": "mockup_01_home.png",
        "headline": "Controla tus gastos\nal instante",
        "accent": "gastos",
        "subtitle": "Todo tu dinero, en un vistazo",
        "bg_base": (28, 12, 52),
        "blobs": [
            (0.18, 0.18, 900, (155, 80, 255), 160),
            (0.85, 0.35, 750, (95, 40, 200), 130),
            (0.50, 0.75, 1100, (60, 20, 140), 110),
        ],
        "accent_color": (210, 170, 255),
        "shadow_tint": (120, 60, 230),
        "chip": {"emoji": "💸", "text": "Gasto añadido", "side": "left"},
    },
    {
        "input": "2_chart.png",
        "output": "mockup_02_chart.png",
        "headline": "Visualiza en qué\ngastas más",
        "accent": "más",
        "subtitle": "Gráficos claros e intuitivos",
        "bg_base": (8, 18, 55),
        "blobs": [
            (0.22, 0.20, 900, (60, 140, 255), 160),
            (0.82, 0.30, 780, (20, 80, 210), 140),
            (0.50, 0.78, 1100, (10, 40, 120), 110),
        ],
        "accent_color": (140, 200, 255),
        "shadow_tint": (40, 120, 240),
        "chip": {"emoji": "📊", "text": "Categorías", "side": "right"},
    },
    {
        "input": "3_goals.png",
        "output": "mockup_03_goals.png",
        "headline": "Ahorra con\nobjetivos claros",
        "accent": "objetivos",
        "subtitle": "Metas, huchas y presupuestos",
        "bg_base": (5, 45, 35),
        "blobs": [
            (0.20, 0.20, 900, (60, 220, 160), 160),
            (0.82, 0.32, 780, (20, 170, 120), 140),
            (0.50, 0.78, 1100, (5, 70, 55), 110),
        ],
        "accent_color": (150, 245, 200),
        "shadow_tint": (50, 200, 140),
        "chip": {"emoji": "🐖", "text": "+200 €", "side": "right"},
    },
    {
        "input": "4_ai.png",
        "output": "mockup_04_ai.png",
        "headline": "Tu asesora\nfinanciera con IA",
        "accent": "IA",
        "subtitle": "Clara analiza tus datos reales",
        "bg_base": (30, 10, 60),
        "blobs": [
            (0.20, 0.18, 900, (190, 100, 255), 160),
            (0.85, 0.35, 780, (130, 50, 230), 140),
            (0.50, 0.78, 1100, (55, 15, 110), 110),
        ],
        "accent_color": (220, 175, 255),
        "shadow_tint": (150, 70, 240),
        "chip": {"emoji": "✨", "text": "Clara IA", "side": "left"},
    },
]


# ─── Background: mesh gradient ────────────────────────────────────────

def create_mesh_gradient(base: tuple, blobs: list) -> Image.Image:
    """Flat base color + multiple soft radial blobs composited together."""
    canvas = Image.new("RGBA", (W, H), (*base, 255))

    for x_frac, y_frac, radius, color, alpha in blobs:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        draw = ImageDraw.Draw(layer)
        cx, cy = int(W * x_frac), int(H * y_frac)
        steps = 50
        for i in range(steps):
            t = i / steps
            r = int(radius * (1 - t * 0.85))
            a = int(alpha * (1 - t) ** 2.2)
            if r <= 0 or a <= 0:
                continue
            draw.ellipse(
                [(cx - r, cy - r), (cx + r, cy + r)],
                fill=(*color, a),
            )
        layer = layer.filter(ImageFilter.GaussianBlur(radius=90))
        canvas = Image.alpha_composite(canvas, layer)

    # Diagonal light streak (very subtle sheen)
    streak = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(streak)
    sd.polygon(
        [(-200, 400), (W + 200, 100), (W + 200, 260), (-200, 560)],
        fill=(255, 255, 255, 14),
    )
    streak = streak.filter(ImageFilter.GaussianBlur(radius=60))
    canvas = Image.alpha_composite(canvas, streak)

    return canvas


def add_grain(canvas: Image.Image, amount: int = 10):
    """Subtle film grain for premium feel."""
    noise = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    pixels = noise.load()
    for y in range(0, canvas.size[1], 2):
        for x in range(0, canvas.size[0], 2):
            v = random.randint(-amount, amount)
            a = abs(v) * 2
            if v > 0:
                pixels[x, y] = (255, 255, 255, min(a, 22))
            else:
                pixels[x, y] = (0, 0, 0, min(a, 16))
    canvas.alpha_composite(noise)


# ─── Device frame ─────────────────────────────────────────────────────

def rounded_rect_mask(w: int, h: int, radius: int) -> Image.Image:
    scale = 2
    mask = Image.new("L", (w * scale, h * scale), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        [(0, 0), (w * scale - 1, h * scale - 1)],
        radius=radius * scale,
        fill=255,
    )
    return mask.resize((w, h), Image.LANCZOS)


def draw_tinted_shadow(canvas: Image.Image, tint: tuple):
    """Big colored bloom shadow behind device + tighter dark drop shadow."""
    # Colored bloom
    bloom = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    bd = ImageDraw.Draw(bloom)
    expand = 90
    bd.rounded_rectangle(
        [(DEVICE_X - expand, DEVICE_Y - expand // 2),
         (DEVICE_X + DEVICE_W + expand, DEVICE_Y + DEVICE_H + expand)],
        radius=CORNER_OUTER + expand,
        fill=(*tint, 90),
    )
    bloom = bloom.filter(ImageFilter.GaussianBlur(radius=90))
    canvas.alpha_composite(bloom)

    # Tighter dark drop
    drop = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    dd = ImageDraw.Draw(drop)
    dd.rounded_rectangle(
        [(DEVICE_X - 12, DEVICE_Y + 20),
         (DEVICE_X + DEVICE_W + 12, DEVICE_Y + DEVICE_H + 40)],
        radius=CORNER_OUTER,
        fill=(0, 0, 0, 110),
    )
    drop = drop.filter(ImageFilter.GaussianBlur(radius=30))
    canvas.alpha_composite(drop)


def draw_device(canvas: Image.Image, screenshot: Image.Image, shadow_tint: tuple) -> Image.Image:
    draw_tinted_shadow(canvas, shadow_tint)

    draw = ImageDraw.Draw(canvas)

    # ── Titanium frame body: horizontal gradient for polished metal look ──
    body = Image.new("RGB", (DEVICE_W, DEVICE_H))
    px = body.load()
    # Natural Titanium: warm gray with subtle brushed-metal gradient
    for x in range(DEVICE_W):
        # Horizontal light curve (brighter at center edges, darker at center)
        t = x / max(DEVICE_W - 1, 1)
        curve = 1 - abs(t - 0.5) * 1.6
        curve = max(0, min(1, curve))
        base = 62 - int(curve * 18)  # darker in middle, lighter at sides
        for y in range(DEVICE_H):
            ty = y / max(DEVICE_H - 1, 1)
            v_offset = int((1 - ty) * 6)
            r = min(base + v_offset, 255)
            g = min(base + v_offset, 255)
            b = min(base + v_offset + 3, 255)
            px[x, y] = (r, g, b)
    body_mask = rounded_rect_mask(DEVICE_W, DEVICE_H, CORNER_OUTER)
    canvas.paste(body, (DEVICE_X, DEVICE_Y), body_mask)

    # ── Outer polished rim (titanium highlight) ──
    rim = Image.new("RGBA", (DEVICE_W, DEVICE_H), (0, 0, 0, 0))
    rd = ImageDraw.Draw(rim)
    rd.rounded_rectangle(
        [(0, 0), (DEVICE_W - 1, DEVICE_H - 1)],
        radius=CORNER_OUTER,
        outline=(180, 180, 188, 200), width=2,
    )
    rd.rounded_rectangle(
        [(2, 2), (DEVICE_W - 3, DEVICE_H - 3)],
        radius=CORNER_OUTER - 2,
        outline=(90, 90, 95, 140), width=1,
    )
    rd.rounded_rectangle(
        [(4, 4), (DEVICE_W - 5, DEVICE_H - 5)],
        radius=CORNER_OUTER - 4,
        outline=(20, 20, 25, 180), width=1,
    )
    canvas.paste(rim, (DEVICE_X, DEVICE_Y), rim)

    # ── Side buttons (iPhone 15/16 Pro: Action button + Volume up/down on left, Power on right) ──
    btn_fill = (48, 48, 52)
    btn_hi = (90, 90, 96, 180)

    def draw_button(x: int, y: int, w: int, h: int):
        # Shadow notch (indent)
        draw.rounded_rectangle([(x, y), (x + w, y + h)], radius=2, fill=btn_fill)
        # Highlight line
        ImageDraw.Draw(canvas).line([(x, y + 1), (x + w, y + 1)], fill=btn_hi, width=1)

    # Left side: Action button (top) + Volume Up + Volume Down
    left_x = DEVICE_X - SIDE_BTN_W
    # Action button (shorter/squarer) — iPhone 15/16 Pro replaced mute switch
    draw_button(left_x, DEVICE_Y + 285, SIDE_BTN_W, 55)
    # Volume Up
    draw_button(left_x, DEVICE_Y + 390, SIDE_BTN_W, 85)
    # Volume Down
    draw_button(left_x, DEVICE_Y + 495, SIDE_BTN_W, 85)

    # Right side: Power button (longer)
    right_x = DEVICE_X + DEVICE_W
    draw_button(right_x, DEVICE_Y + 360, SIDE_BTN_W, 135)

    # Screen
    sc = screenshot.copy()
    if STATUS_BAR_CROP > 0:
        sc = sc.crop((0, STATUS_BAR_CROP, sc.width, sc.height))
    sc = sc.resize((DEVICE_SCREEN_W, DEVICE_SCREEN_H), Image.LANCZOS)
    screen_mask = rounded_rect_mask(DEVICE_SCREEN_W, DEVICE_SCREEN_H, CORNER_INNER)
    canvas.paste(sc, (SCREEN_X, SCREEN_Y), screen_mask)

    # Dynamic Island
    di_x = SCREEN_X + (DEVICE_SCREEN_W - DI_W) // 2
    di_y = SCREEN_Y + DI_TOP_OFFSET
    di_shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ds = ImageDraw.Draw(di_shadow)
    ds.rounded_rectangle(
        [(di_x - 2, di_y - 1), (di_x + DI_W + 2, di_y + DI_H + 3)],
        radius=DI_RADIUS + 2, fill=(0, 0, 0, 50),
    )
    di_shadow = di_shadow.filter(ImageFilter.GaussianBlur(radius=5))
    canvas.alpha_composite(di_shadow)
    draw.rounded_rectangle(
        [(di_x, di_y), (di_x + DI_W, di_y + DI_H)],
        radius=DI_RADIUS, fill=(8, 8, 8),
    )
    draw.rounded_rectangle(
        [(di_x + 1, di_y + 1), (di_x + DI_W - 1, di_y + DI_H - 1)],
        radius=DI_RADIUS - 1, outline=(50, 50, 55, 60), width=1,
    )

    # Screen inner shadow
    inner = Image.new("RGBA", (DEVICE_SCREEN_W, DEVICE_SCREEN_H), (0, 0, 0, 0))
    idraw = ImageDraw.Draw(inner)
    idraw.rounded_rectangle(
        [(0, 0), (DEVICE_SCREEN_W - 1, DEVICE_SCREEN_H - 1)],
        radius=CORNER_INNER, outline=(0, 0, 0, 50), width=2,
    )
    inner = inner.filter(ImageFilter.GaussianBlur(radius=3))
    shadow_full = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shadow_full.paste(inner, (SCREEN_X, SCREEN_Y))
    canvas = Image.alpha_composite(canvas, shadow_full)

    return canvas


# ─── Typography ───────────────────────────────────────────────────────

def draw_headline_with_accent(canvas: Image.Image, headline: str, accent: str,
                               subtitle: str, accent_color: tuple):
    """Headline with one accent-colored word, bloom glow behind accent."""
    draw = ImageDraw.Draw(canvas)

    text_top = 110
    text_bottom = DEVICE_Y - 60
    center_y = (text_top + text_bottom) // 2

    font_head = load_font(128, "Heavy")
    font_sub = load_font(48, "Medium")

    lines = headline.split("\n")
    # Measure
    def measure_line(line: str):
        bb = font_head.getbbox(line)
        return bb[2] - bb[0], bb[3] - bb[1]

    line_h = max(measure_line(l)[1] for l in lines)
    spacing = 18
    total_h = line_h * len(lines) + spacing * (len(lines) - 1)

    sub_bb = font_sub.getbbox(subtitle)
    sub_h = sub_bb[3] - sub_bb[1]
    gap = 44

    block_h = total_h + gap + sub_h
    block_top = center_y - block_h // 2

    # Accent-word bloom layer
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)

    y = block_top
    for line in lines:
        lw, _ = measure_line(line)
        x = (W - lw) // 2

        # Find accent word (case-insensitive) in this line
        lower = line.lower()
        acc_lower = accent.lower().strip()
        if acc_lower and acc_lower in lower:
            start = lower.index(acc_lower)
            end = start + len(acc_lower)
            before = line[:start]
            middle = line[start:end]
            after = line[end:]

            before_w = font_head.getbbox(before)[2] - font_head.getbbox(before)[0] if before else 0
            middle_w = font_head.getbbox(middle)[2] - font_head.getbbox(middle)[0]

            # Glow only behind accent
            gd.text((x + before_w, y), middle, fill=(*accent_color, 180), font=font_head)

        y += line_h + spacing

    glow = glow.filter(ImageFilter.GaussianBlur(radius=36))
    canvas.alpha_composite(glow)

    # Draw actual text
    y = block_top
    for line in lines:
        lw, _ = measure_line(line)
        x = (W - lw) // 2

        lower = line.lower()
        acc_lower = accent.lower().strip()
        if acc_lower and acc_lower in lower:
            start = lower.index(acc_lower)
            end = start + len(acc_lower)
            before = line[:start]
            middle = line[start:end]
            after = line[end:]

            before_w = font_head.getbbox(before)[2] - font_head.getbbox(before)[0] if before else 0
            middle_w = font_head.getbbox(middle)[2] - font_head.getbbox(middle)[0]

            # Drop shadow
            draw.text((x + 2, y + 4), before, fill=(0, 0, 0, 70), font=font_head)
            draw.text((x + before_w + 2, y + 4), middle, fill=(0, 0, 0, 70), font=font_head)
            draw.text((x + before_w + middle_w + 2, y + 4), after, fill=(0, 0, 0, 70), font=font_head)

            draw.text((x, y), before, fill=(255, 255, 255), font=font_head)
            draw.text((x + before_w, y), middle, fill=accent_color, font=font_head)
            draw.text((x + before_w + middle_w, y), after, fill=(255, 255, 255), font=font_head)
        else:
            draw.text((x + 2, y + 4), line, fill=(0, 0, 0, 70), font=font_head)
            draw.text((x, y), line, fill=(255, 255, 255), font=font_head)

        y += line_h + spacing

    # Subtitle
    y = block_top + total_h + gap
    sub_w = sub_bb[2] - sub_bb[0]
    sub_x = (W - sub_w) // 2
    draw.text((sub_x + 1, y + 2), subtitle, fill=(0, 0, 0, 40), font=font_sub)
    draw.text((sub_x, y), subtitle, fill=(255, 255, 255, 200), font=font_sub)


# ─── Floating callout chip ────────────────────────────────────────────

def draw_chip(canvas: Image.Image, chip: dict, accent_color: tuple):
    """Glass-morphism pill floating next to device with emoji + text."""
    emoji = chip.get("emoji", "")
    text = chip.get("text", "")
    side = chip.get("side", "left")

    font_chip = load_font(46, "Semibold")
    emoji_size = 64

    pad_x, pad_y = 36, 22
    gap = 18

    text_bb = font_chip.getbbox(text)
    text_w = text_bb[2] - text_bb[0]
    text_h = text_bb[3] - text_bb[1]

    emoji_img = render_emoji(emoji, emoji_size) if emoji else None
    emoji_w = emoji_img.size[0] if emoji_img else 0
    emoji_h = emoji_img.size[1] if emoji_img else 0

    chip_w = pad_x * 2 + emoji_w + (gap if emoji_img else 0) + text_w
    chip_h = pad_y * 2 + max(text_h, emoji_h) + 10

    # Anchor: overlapping the device edge on chosen side, roughly at mid-device
    if side == "left":
        cx = DEVICE_X - 80
    else:
        cx = DEVICE_X + DEVICE_W - chip_w + 80
    cy = DEVICE_Y + DEVICE_H // 3

    # Shadow
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    shd = ImageDraw.Draw(sh)
    shd.rounded_rectangle(
        [(cx - 6, cy + 10), (cx + chip_w + 6, cy + chip_h + 22)],
        radius=chip_h // 2 + 4, fill=(0, 0, 0, 130),
    )
    sh = sh.filter(ImageFilter.GaussianBlur(radius=18))
    canvas.alpha_composite(sh)

    # Glass body
    glass = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glass)
    gd.rounded_rectangle(
        [(cx, cy), (cx + chip_w, cy + chip_h)],
        radius=chip_h // 2, fill=(255, 255, 255, 28),
        outline=(255, 255, 255, 90), width=2,
    )
    canvas.alpha_composite(glass)

    # Emoji + text
    ex = cx + pad_x
    if emoji_img is not None:
        ey = cy + (chip_h - emoji_h) // 2
        canvas.alpha_composite(emoji_img, dest=(ex, ey))
        tx = ex + emoji_w + gap
    else:
        tx = ex

    ty = cy + (chip_h - text_h) // 2 - 4
    ImageDraw.Draw(canvas).text((tx, ty), text, fill=(255, 255, 255), font=font_chip)


# ─── Pipeline ─────────────────────────────────────────────────────────

def generate_mockup(config: dict, input_dir: Path, output_dir: Path) -> bool:
    input_path = input_dir / config["input"]
    if not input_path.exists():
        print(f"  SKIP: {config['input']} not found")
        return False

    print(f"  Processing {config['input']}...")

    screenshot = Image.open(input_path).convert("RGB")

    canvas = create_mesh_gradient(config["bg_base"], config["blobs"])
    add_grain(canvas, amount=7)

    canvas = draw_device(canvas, screenshot, config["shadow_tint"])

    draw_headline_with_accent(
        canvas,
        config["headline"],
        config.get("accent", ""),
        config.get("subtitle", ""),
        config["accent_color"],
    )

    output_path = output_dir / config["output"]
    canvas.convert("RGB").save(output_path, "PNG", optimize=True)
    print(f"  -> {output_path.name} ({W}x{H})")
    return True


def main():
    base = Path(__file__).resolve().parent.parent / "marketing" / "screenshots"
    input_dir = base / "input"
    output_dir = base / "output"

    input_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    print("App Store Mockup Generator — Premium v2")
    print(f"  Input:  {input_dir}")
    print(f"  Output: {output_dir}")
    print(f"  Canvas: {W}x{H} (6.7\")")
    print()

    inputs = list(input_dir.glob("*.png")) + list(input_dir.glob("*.jpg"))
    if not inputs:
        print("No screenshots found. Place them in:")
        print(f"  {input_dir}")
        sys.exit(1)

    generated = 0
    for config in MOCKUPS:
        if generate_mockup(config, input_dir, output_dir):
            generated += 1

    print(f"\nDone: {generated}/{len(MOCKUPS)} mockups generated")


if __name__ == "__main__":
    main()
