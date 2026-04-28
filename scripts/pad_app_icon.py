"""Shrink AppIcon(.png|-Dark.png) to add more breathing space."""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ICON_DIR = ROOT / "Clarity" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"
SIZE = 1024
SCALE = 0.76  # 24% padding total (12% each side)

for name in ["AppIcon.png", "AppIcon-Dark.png"]:
    p = ICON_DIR / name
    if not p.exists():
        continue
    img = Image.open(p).convert("RGBA")
    # Detect bg color from corner pixel
    bg = img.getpixel((4, 4))
    canvas = Image.new("RGBA", (SIZE, SIZE), bg)
    new_size = int(SIZE * SCALE)
    shrunk = img.resize((new_size, new_size), Image.LANCZOS)
    off = (SIZE - new_size) // 2
    canvas.paste(shrunk, (off, off), shrunk)
    canvas.convert("RGB").save(p, "PNG", optimize=True)
    print(f"padded {p}")
