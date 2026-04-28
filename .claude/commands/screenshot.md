---
description: Lanza el simulador iPhone 16 Pro Max y toma capturas para el App Store
argument-hint: [nombre-pantalla]
---

Vamos a tomar capturas del simulador para el App Store.

Dispositivo objetivo: iPhone 16 Pro Max (6.9" — 1320x2868px, el requerido por App Store)

!`xcrun simctl list devices available | grep "iPhone 16 Pro Max"`

Pasos:
1. Lanza el simulador si no está corriendo: `open -a Simulator`
2. Navega a la pantalla: $ARGUMENTS
3. Toma la captura: `xcrun simctl io booted screenshot ~/Desktop/clarity-screenshot-$ARGUMENTS.png`
4. Confirma que se guardó

Las 6 pantallas clave para App Store:
- dashboard → Home con gastos del mes
- voice → Pantalla de voz activa
- charts → Gráficos de categorías
- budgets → Presupuestos del mes
- ai → Chat con IA Advisor
- recurring → Lista de gastos recurrentes
