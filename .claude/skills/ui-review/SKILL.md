---
name: ui-review
description: Revisa el diseño y UX de una pantalla SwiftUI de Clarity.
  Usar cuando el usuario comparte capturas de la app, pide mejorar una pantalla,
  o menciona que algo "no queda bien" visualmente.
allowed-tools: Read, Glob, Grep
---

Revisa la pantalla indicada siguiendo las guías de diseño de Clarity.

1. Lee el archivo de la View afectada
2. Comprueba el uso del DesignSystem.swift
3. Evalúa: jerarquía visual, espaciado, contraste, consistencia
4. Referencia: Revolut, Monzo, Copilot Money para inspiración
5. Propón cambios concretos con código SwiftUI

Prioridades en el diseño de Clarity:
- Dark mode como base
- Glass morphism con .ultraThinMaterial
- Gradientes morado/índigo
- Esquinas redondeadas (12-20pt)
- Espaciado generoso (16-24pt)
- Componentes del catálogo existente primero

@../../rules/ui-design.md
