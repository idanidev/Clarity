---
paths:
  - "Clarity/**/*.swift"
  - "ClarityWidget/**/*.swift"
---

# Convenciones Swift para Clarity

## Concurrencia
- Swift 6 strict concurrency — todos los ViewModels son `@MainActor`
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
