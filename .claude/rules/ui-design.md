---
paths:
  - "Clarity/Features/**/*View.swift"
  - "Clarity/UI/**/*.swift"
  - "Clarity/Presentation/**/*.swift"
---

# Reglas de Diseño UI — Clarity

## Design System
- Todos los valores de diseño están en `Clarity/UI/Theme/DesignSystem.swift`
- Corner radii: usar `DesignSystem.CornerRadius.*` — nunca valores hardcoded
- Icon sizes: usar `DesignSystem.IconSize.*`
- Animaciones: usar `DesignSystem.AnimationDuration.*`
- Paleta de 12 colores — consultar DesignSystem antes de añadir cualquier color nuevo

## Componentes disponibles
- `GlassCard` / `LiquidGlassCard` — tarjetas con glass morphism
- `CategoryBadge` — badge de categoría con emoji + nombre
- `ModernExpenseCard` — tarjeta de gasto
- `SummaryCardsView` — resumen financiero del mes
- `MonthSelectorView` — selector de mes
- `SearchBarView` — barra de búsqueda
- `FeedbackOverlay` — overlay de feedback con animación
- `SuccessToast` — toast de éxito

Reutilizar siempre estos componentes antes de crear nuevos.

## Estética
- Modo oscuro como base (dark-first)
- Glass morphism con `.ultraThinMaterial` o `.regularMaterial`
- Paleta de marca en la familia Deep Berry (desde la 2.3.1): `clarityPrimary` #BF4DCB (orquídea), `claritySecondary` #DA8DE2, `clarityAccent` #8D3B96, y `clarityBerry` #58215E para el brillo del fondo
- Un único acento cálido, `clarityMango` #FFCE6B, para lo que tiene que destacar (cifra del héroe cuando vas bien, barra de presupuesto, botón principal). Sobre mango el texto va en `clarityBerry` (8:1), nunca en blanco
- Los colores de categorías y de métodos de pago son DATOS, no marca: no se tocan al cambiar la paleta
- Esquinas muy redondeadas (12-20pt)
- Spacing generoso (16-24pt entre elementos)

## Haptics
- Usar `HapticManager` para todos los feedbacks táctiles
- Success: `.success`
- Error: `.error`
- Selección: `.selection`
- Nunca usar `UIImpactFeedbackGenerator` directamente
