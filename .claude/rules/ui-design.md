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
Lista verificada con grep (sep 2026): todo lo de aquí existe y tiene usos reales.

**Tarjetas y vidrio**
- `.glassCard(cornerRadius:tint:interactivo:)` (`UI/Theme/Glass.swift`) — el vidrio de la app; trae la rama de iOS 26. Es lo que se usa para cualquier tarjeta nueva.
- `GlassCard` (struct, `UI/Components/GlassCard.swift`) — el antiguo, sin vidrio de iOS 26. Solo lo usa `CategoryBreakdownTable`; no usarlo en código nuevo.

**Piezas de pantalla** (`UI/Theme/ComponentesClarity.swift`)
- `CirculoIconoClarity` — emoji o SF Symbol en un círculo de color (categorías, metas).
- `CabeceraSeccionClarity` — cabecera de sección en mayúsculas pequeñas, con dato opcional a la derecha.
- `BarraProgresoClarity` — barra de progreso de cápsula (0…1). `BarraOndulada` (`UI/Effects/Vivos.swift`) es su variante para cuando se acerca el límite.
- `BotonSecundarioClarity` — `ButtonStyle` de cápsula tintada para acciones dentro de una tarjeta.
- `EstadoVacioClarity` — estado vacío en tarjeta de vidrio: icono, título, texto y acción.
- `.estiloEtiquetaClarity()` / `.estiloCifraClarity(tamano:)` — etiqueta pequeña en mayúsculas y cifra protagonista de una tarjeta.
- `.filaTarjetaClarity()` — fila de `List` que pinta su propia tarjeta (sin fondo ni separador de sistema).
- `StatCard` — tarjeta de estadística (título + valor).

**Formularios**
- `.confirmarDescarte(...)` + `BotonCancelarFormulario` (`UI/Modifiers/ConfirmarDescarte.swift`) — pregunta antes de tirar un formulario con cambios.
- `.keyboardDoneToolbar()` (`UI/Modifiers/KeyboardDoneToolbar.swift`) — barra de teclado con «Hecho».
- `CategoryPickerView`, `EmojiPickerView`, `ExpenseFilterSheet` — selectores de categoría, emoji y hoja de filtros.

**Avisos, carga y celebración**
- `FeedbackOverlay` — se monta una sola vez en `ClarityApp`; para enseñar un aviso se llama a `FeedbackManager.shared.show(...)`, no se instancia.
- `SuccessToast` — toast de éxito (voz, en `MainTabView`).
- `OfflineBanner` — aviso de sin conexión; ya va montado en `MainTabView`.
- `CargaClarity` / `LoadingView` — estados de carga. `SkeletonView` y `.skeleton(...)` — esqueletos.
- `CelebracionClarity` — tarjeta de enhorabuena con confeti.

Reutilizar siempre estos componentes antes de crear nuevos.

**Siguen en el repo pero sin ningún uso** (no tomarlos como referencia): `CategoryBadge`, `ModernExpenseCard`, `SearchBarView`.

## Estética
- Modo oscuro como base (dark-first)
- Glass morphism con `.ultraThinMaterial` o `.regularMaterial`
- Gradientes suaves en morado/índigo
- Esquinas muy redondeadas (12-20pt)
- Spacing generoso (16-24pt entre elementos)

## Haptics
- Usar `HapticManager` para todos los feedbacks táctiles
- Success: `.success`
- Error: `.error`
- Selección: `.selection`
- Nunca usar `UIImpactFeedbackGenerator` directamente
