# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clarity is a native iOS expense tracking app built with SwiftUI, targeting iOS 17+. It uses Firebase for backend services and follows Clean Architecture with MVVM presentation.

- **Bundle ID**: `com.idanidev.clarity`
- **Branch principal**: `ios-native`
- **Versión actual**: 2.0.5 (próxima: 2.0.6)
- **Firebase project**: `clarity-gastos`
- **Xcode project**: usa `PBXFileSystemSynchronized` (Xcode 16) — los archivos nuevos en disco se incluyen automáticamente en el target, no hay que editar `project.pbxproj`.

## Constraints críticos

- **NUNCA desinstalar la app del iPhone físico del usuario** (`xcrun devicectl device uninstall …`). Es la app que él usa a diario en producción. Reinstalar SIEMPRE encima sin uninstall previo.
- **NUNCA commitear `Secrets.swift`** — está en `.gitignore`. API keys (Gemini, Groq) viven ahí.
- No hacer cambios que no se han pedido. Si hay varias formas, preguntar antes de elegir.
- Commits solo cuando se piden explícitamente.
- IA está **deshabilitada** temporalmente (placeholder `AIDisabledView`). Para reactivar: cambiar `AIDisabledView()` por `AIAdvisorView()` en `MainTabView.swift` y `MoreMenuView.swift`.

## Build & Deploy

### Simulador (test + dev rápido)
```bash
# Build
xcodebuild -project Clarity.xcodeproj -scheme Clarity -sdk iphonesimulator -configuration Debug build

# Tests unitarios
xcodebuild -project Clarity.xcodeproj -scheme Clarity -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test

# Test único
xcodebuild -project Clarity.xcodeproj -scheme Clarity -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ClarityTests/HomeViewModelTests test
```

### iPhone físico (deploy real)
```bash
# Build para device
xcodebuild -project Clarity.xcodeproj -scheme Clarity -sdk iphoneos -configuration Debug -destination 'generic/platform=iOS' build

# Install (sin uninstall previo)
xcrun devicectl device install app --device DC3A9753-6C32-5B4D-9DB5-7384A631B0C4 \
  /Volumes/SSDani/Xcode_DerivedData/Clarity-cjwlvudtapgvkvajnodrsdfvozgs/Build/Products/Debug-iphoneos/Clarity.app
```

- **Device ID iPhone Dani**: `DC3A9753-6C32-5B4D-9DB5-7384A631B0C4`
- **DerivedData**: `/Volumes/SSDani/Xcode_DerivedData/Clarity-cjwlvudtapgvkvajnodrsdfvozgs/`

## Rules autoaplicadas

Hay reglas con scope por glob en `.claude/rules/`. Léelas antes de tocar código en su scope:

- `swift-conventions.md` → `Clarity/**/*.swift`, `ClarityWidget/**/*.swift`
- `ui-design.md` → `Clarity/Features/**/*View.swift`, `Clarity/UI/**/*.swift`, `Clarity/Presentation/**/*.swift`
- `architecture.md` → arquitectura general (capas, DI, recurring local, widget)
- `ai-service.md` → providers, PromptBuilder, voice parser

## Architecture

### Clean Architecture Layers

```
Domain (innermost)  →  Data  →  Features/Presentation (outermost)
```

- **Domain** (`Clarity/Domain/`): Models, repository protocols, use cases. No framework imports. Use cases son structs ligeros con un repo (`AddExpenseUseCase`, `GetExpensesUseCase`, `DeleteExpenseUseCase`).
- **Data** (`Clarity/Data/`): Repository implementations. `ExpenseRepository` es híbrido: `FirebaseExpenseDataSource` (remoto) + `SwiftDataExpenseDataSource` (cache) + `LocalExpenseDataSource` (legacy JSON, deprecated).
- **Features** (`Clarity/Features/`): Views + ViewModels (`@Observable`) + servicios específicos por feature.

### Dependency Injection

`DependencyContainer` (`Clarity/Core/DI/DependencyContainer.swift`) es `@MainActor` singleton. Repos = lazy singletons. Use cases = factory methods (structs). ViewModels = factory methods que cablean use cases.

**Regla**: nunca acceder a `DependencyContainer.shared` desde una `View` directamente — solo desde ViewModels.

### Concurrencia

- Swift 6 strict concurrency. ViewModels + DI + tests = `@MainActor`.
- Sólo `async/await`. Nunca callbacks ni Combine.
- `@Observable` macro para estado. **NUNCA** `ObservableObject` ni `@Published`.

### Testing

Apple Swift Testing (`import Testing`). `@Test` + `#expect()`. **No XCTest**. Mock repos implementan los mismos protocolos.

## Singletons / Managers clave

| Tipo | Path | Para qué |
|------|------|----------|
| `DependencyContainer.shared` | `Core/DI/` | Repos + use cases |
| `UserDataManager.shared` | — | Categorías del usuario, onboarding state |
| `LocalRecurringExpenseManager.shared` | `Features/RecurringExpenses/` | Crea recurrentes al abrir app |
| `UserLearningManager.shared` | `Features/Voice/Managers/` | Actor. Aprende merchant→categoría. `snapshot()` para cachear y evitar await por keystroke |
| `SmartTransactionParser` | `Features/Voice/Services/` | Parsea voz/texto a expense. `suggestCategory(for:)` hardcoded |
| `HapticManager.shared` | `UI/Haptics/` | Todos los haptics. **Nunca usar `UIImpactFeedbackGenerator` directo** |
| `FeedbackManager.shared` | — | Toasts success/error |
| `Formatters` | `Core/Utils/Formatters.swift` | Fechas + moneda. Usar siempre estos |

## Módulos

| Feature | Path | Estado |
|---------|------|--------|
| `Auth` | `Features/Auth/` | Email/password + Apple + Google |
| `AIAdvisor` | `Features/AIAdvisor/` | **Deshabilitado** (placeholder `AIDisabledView`) |
| `Voice` | `Features/Voice/` | Speech → parser → expense |
| `Expenses` / `AddExpense` | `Features/Expenses/`, `Features/AddExpense/` | CRUD + paginación |
| `Budgets` | `Features/Budgets/` | Presupuestos mensuales + metas |
| `RecurringExpenses` | `Features/RecurringExpenses/` | LOCAL (NO Cloud Functions) |
| `Financial` | `Features/Financial/` | Analytics, charts, trends |
| `Charts` | `Features/Charts/` | Donut + monthly evolution |

## Data Persistence

- **Remote**: Firestore. Colecciones: `users`, `expenses`, `budgets`, `categories`, `recurringExpenses`.
- **Local cache**: SwiftData (migración auto desde JSON legacy).
- **Híbrido**: `.cacheFirst` para reads, `.networkFirst` para datos críticos.

## Recurring Expenses (LOCAL — no Cloud Functions)

`LocalRecurringExpenseManager`:
- Corre en `MainTabView.task` al arrancar.
- `checkAndCreatePendingExpenses()` — crea gastos de hoy (1× al día).
- `recoverMissedExpenses()` — recupera del mes en curso.
- Frecuencias: monthly, quarterly, semestral, yearly.
- Usa `billingMonth` para ciclos no mensuales.
- `expenseExistsForMonth()` evita duplicados.
- **NUNCA migrar de vuelta a Firebase** (deprecated por límites free tier).

## Widget

- Target separado: `ClarityWidget` (Xcode target independiente).
- App Group: `group.com.idanidev.clarity`.
- UserDefaults key: `widgetData_v2`.
- Assets propios en `ClarityWidget/Assets.xcassets/`.

## AI Service Architecture (deshabilitada, mantenida)

`AIService` con provider pattern (`AIServiceProvider`). Implementaciones: `GeminiProvider`, `GroqProvider`. `PromptBuilder` arma contexto financiero (~500 tokens máx). Groq key en UserDefaults, Gemini en código (Secrets.swift).

## UI System

- Design System en `Clarity/UI/Theme/DesignSystem.swift`. Tokens para corner radii, icon sizes, animation durations, paleta de 12 colores.
- Glass morphism: `GlassCard`, `LiquidGlassCard`.
- Haptics: `HapticManager` + Core Haptics.
- **Nunca hardcodear colores** — usar paleta del DesignSystem.
- Esquinas 12-20pt, spacing 16-24pt, dark-first.

### Performance patterns SwiftUI (críticos)

1. **Sections como structs `View` separadas**, no `var someSection: some View` computadas. Las computadas re-evalúan el body entero del padre en cada mutación `@Observable`. Las structs se diffean por su propio body → tracking granular.
2. **`@Bindable var viewModel`** dentro de la subview, pasar el VM (no bindings sueltos).
3. **`@ObservationIgnored`** para caches privados del VM que no deben disparar re-render.
4. **Debounce** las acciones de `onChange(of:)` que tocan IO (`try? await Task.sleep` antes del trabajo, cancelar Task previa).
5. **Pre-cache** repo + actor en `warmup()` al abrir vistas pesadas → cero IO en typing.
6. **DatePicker `.compact`** en forms. **NUNCA `.graphical`** dentro de un `Form` con TextFields — re-render del calendario por tecla.
7. **`TextField(text:)` con `String`** en inputs grandes/monospaced. Evitar `value: + format:` (parsea Double↔String por keystroke).
8. **FocusState** con enum + `.focused($focused, equals: .x)` para flujo de teclado.
9. **Equatable/Hashable customs** para modelos en listas grandes — excluir timestamps (cambian en cada save y disparan diffs/re-render innecesarios).

## Localización

- UI siempre en español (primario) + inglés.
- `LocalizedStringKey` o `String(localized:)` para textos traducibles.
- Fechas + moneda **siempre** con `Formatters.swift`.

## claude-mem

MCP server `claude-mem` disponible. Usar `mem-search` skill para contexto histórico (decisiones, bugs resueltos, intentos previos). `smart_outline(path)` da estructura del archivo en pocos tokens antes de `Read`.

## Convenciones Swift rápidas

- Swift 6.0+ strict concurrency.
- `@Observable` (no Combine).
- SwiftUI > UIKit siempre que se pueda.
- ViewModels solo importan Foundation + domain models (no `import SwiftUI`).
- Views sin lógica — solo layout + bindings.
- Naming: `NombreView.swift`, `NombreViewModel.swift`, `NombreService.swift`, `NombreRepository.swift`.
- SPM para deps iOS (no CocoaPods).
