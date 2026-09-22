---
paths:
  - "Clarity/**/*.swift"
  - "ClarityWidget/**/*.swift"
---

# Convenciones Swift para Clarity

## Concurrencia
- El proyecto compila en modo de lenguaje Swift 5 con MainActor por defecto y approachable concurrency (no Swift 6): las carreras son avisos, no errores. Se escribe como si fuera Swift 6 — todos los ViewModels son `@MainActor`, y lo que corra fuera va `nonisolated` explícito
- Usar `async/await` siempre, nunca callbacks ni Combine
- `@Observable` macro para estado (NUNCA `ObservableObject` ni `@Published`)
- Los tests también deben ser `@MainActor`

## Arquitectura
- ViewModels no importan SwiftUI — solo Foundation y los modelos del dominio
- Las Views no tienen lógica — solo layout y bindings
- Nunca acceder a `DependencyContainer.shared` desde una View directamente
- Repositorios son lazy singletons en DependencyContainer
- Use cases son structs ligeros creados via factory methods

## Naming
- Views: `NombreView.swift`
- ViewModels: `NombreViewModel.swift`
- Services: `NombreService.swift`
- Repositories: `NombreRepository.swift`

## UI
- Siempre usar tokens del DesignSystem.swift (cornerRadii, iconSizes, etc.)
- No hardcodear colores — usar la paleta de 12 colores del DesignSystem
- Haptics via HapticManager, nunca UIImpactFeedbackGenerator directamente
- Animaciones: usar las duraciones definidas en DesignSystem.AnimationDurations

## Localización
- Strings de UI siempre en español
- Usar `LocalizedStringKey` o `String(localized:)` para textos que puedan traducirse
- Fechas y moneda con los Formatters de `Formatters.swift`
