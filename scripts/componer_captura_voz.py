#!/usr/bin/env python3
"""
componer_captura_voz.py — la captura de "la app escuchando" para la ficha (#71).

El momento exacto en que la app escucha sale mal en una foto estática, y usar
la misma captura de la Home en dos mockups los dejaba iguales en la tienda.
Esto compone, sobre la captura de la Home, el panel de escucha: la Home
desenfocada detrás, la onda de audio, la frase y el gasto ya registrado.

Uso:
    python3 scripts/componer_captura_voz.py
Entrada:  marketing/screenshots/input/1_home.png  (1290x2796)
Salida:   marketing/screenshots/input/4_voice.png y 4_voice_en.png
"""

from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_mockups as g  # load_font y render_emoji

W, H = 1290, 2796
# Paleta Deep Berry de la app (UI/Theme/Colors.swift): la onda y el importe
# en claritySecondary, que sobre el panel oscuro se lee mejor que el orquídea.
ACENTO = (218, 141, 226)   # claritySecondary #DA8DE2
EXITO = (52, 211, 153)     # el verde de «guardado»: semántico, no de marca
VELO = (14, 4, 16, 170)    # sobre la Home desenfocada, hacia clarityBerry
PANEL = (34, 12, 38, 240)  # clarityBerry #58215E muy oscurecido

TEXTOS = {
    "4_voice.png": {
        "estado": "ESCUCHANDO",
        "frase": "«20 euros en gasolina»",
        "nombre": "Gasolina",
        "importe": "20,00 €",
        "guardado": "Guardado en Transporte",
    },
    "4_voice_en.png": {
        "estado": "LISTENING",
        "frase": "“20 euros on gas”",
        "nombre": "Gas",
        "importe": "20,00 €",
        "guardado": "Saved to Transport",
    },
}


def componer(home: Image.Image, t: dict) -> Image.Image:
    lienzo = home.convert("RGBA").resize((W, H), Image.LANCZOS)
    # La Home, detrás y fuera de foco: que se note que es otro momento.
    lienzo = lienzo.filter(ImageFilter.GaussianBlur(radius=22))
    lienzo.alpha_composite(Image.new("RGBA", (W, H), VELO))

    margen = 60
    panel_w, panel_h = W - margen * 2, 1240
    px, py = margen, 1020

    panel = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(panel).rounded_rectangle(
        [(px, py), (px + panel_w, py + panel_h)], radius=84,
        fill=PANEL, outline=(255, 255, 255, 50), width=3,
    )
    lienzo.alpha_composite(panel)
    d = ImageDraw.Draw(lienzo)

    def centrado(texto, fuente, y, color):
        bb = fuente.getbbox(texto)
        d.text((px + (panel_w - (bb[2] - bb[0])) // 2, y), texto, fill=color, font=fuente)

    centrado(t["estado"], g.load_font(40, "Semibold"), py + 70, ACENTO + (255,))

    # Onda de audio: alturas fijas para que el resultado sea reproducible.
    alturas = [22, 46, 78, 120, 158, 190, 150, 96, 132, 176, 205, 168,
               124, 88, 142, 184, 146, 102, 64, 38, 92, 138, 84, 44, 26]
    ancho, hueco, escala = 16, 22, 2.0
    total = len(alturas) * ancho + (len(alturas) - 1) * hueco
    x0 = px + (panel_w - total) // 2
    medio = py + 400
    for i, h in enumerate(alturas):
        x = x0 + i * (ancho + hueco)
        lejos = abs(i - len(alturas) / 2) / (len(alturas) / 2)
        alto = int(h * escala)
        d.rounded_rectangle([(x, medio - alto // 2), (x + ancho, medio + alto // 2)],
                            radius=ancho // 2, fill=ACENTO + (int(255 - lejos * 120),))

    centrado(t["frase"], g.load_font(84, "Bold", rounded=True), py + 670, (255, 255, 255, 255))

    # El gasto ya registrado.
    cx, cw, ch = px + 60, panel_w - 120, 210
    cy = py + panel_h - ch - 150
    tarjeta = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(tarjeta).rounded_rectangle(
        [(cx, cy), (cx + cw, cy + ch)], radius=56,
        fill=(255, 255, 255, 22), outline=(255, 255, 255, 46), width=2,
    )
    lienzo.alpha_composite(tarjeta)
    emoji = g.render_emoji("⛽", 110)
    lienzo.alpha_composite(emoji, dest=(cx + 50, cy + (ch - emoji.size[1]) // 2))
    d = ImageDraw.Draw(lienzo)
    f_nombre = g.load_font(68, "Semibold", rounded=True)
    d.text((cx + 200, cy + (ch - 80) // 2), t["nombre"], fill=(255, 255, 255, 255), font=f_nombre)
    f_importe = g.load_font(72, "Bold", rounded=True)
    bb = f_importe.getbbox(t["importe"])
    d.text((cx + cw - 56 - (bb[2] - bb[0]), cy + (ch - 84) // 2), t["importe"], fill=ACENTO + (255,), font=f_importe)

    centrado("✓  " + t["guardado"], g.load_font(44, "Medium"), cy + ch + 44, EXITO + (255,))
    return lienzo.convert("RGB")


def main():
    entrada = Path(__file__).resolve().parent.parent / "marketing" / "screenshots" / "input"
    home = Image.open(entrada / "1_home.png")
    for nombre, textos in TEXTOS.items():
        componer(home, textos).save(entrada / nombre, "PNG", optimize=True)
        print("->", nombre)


if __name__ == "__main__":
    main()
