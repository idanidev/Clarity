---
description: Lanza el simulador iPhone 16 Pro Max y toma capturas para el App Store
argument-hint: [nombre-pantalla]
---

Vamos a tomar capturas del simulador para el App Store.

Dispositivo objetivo: **iPhone 16 Plus** — 1290x2796px, que es el tamaño exacto
que espera `scripts/generate_mockups.py`. Con otro simulador las capturas no
encajan en el marco del mockup.

!`xcrun simctl list devices available | grep "iPhone 16 Pro Max"`

Pasos:
1. Lanza el simulador si no está corriendo: `open -a Simulator`
2. Navega a la pantalla: $ARGUMENTS
3. Toma la captura: `xcrun simctl io booted screenshot ~/Desktop/clarity-screenshot-$ARGUMENTS.png`
4. Confirma que se guardó

Las capturas que consume el generador de mockups van en
`marketing/screenshots/input/` con estos nombres exactos:

- `1_home.png` → Home con gastos del mes (se usa en DOS mockups: 01 y 04)
- `2_chart.png` → vista de gráfico de categorías
- `3_goals.png` → Metas

Después: `python3 scripts/generate_mockups.py` compone los cuatro mockups en
`marketing/screenshots/output/`, que es lo que se copia a `fastlane/screenshots/`.

No pidas una captura de IA: esa pantalla ya no existe.
