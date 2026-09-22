# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clarity is a native iOS expense tracking app built with SwiftUI, targeting iOS 17+. It uses Firebase for backend services and follows Clean Architecture with MVVM presentation.

- **Bundle ID**: `com.idanidev.clarity`
- **Branch principal**: `ios-native`
- **Versión actual**: 2.3.1 (en preparación: 2.4.0, rama `version-2.4`)
- **Firebase project**: `clarity-gastos`
- **Xcode project**: usa `PBXFileSystemSynchronized` (Xcode 16) — los archivos nuevos en disco se incluyen automáticamente en el target, no hay que editar `project.pbxproj`.

## Constraints críticos

- **NUNCA desinstalar la app del iPhone físico del usuario** (`xcrun devicectl device uninstall …`). Es la app que él usa a diario en producción. Reinstalar SIEMPRE encima sin uninstall previo.
- **NUNCA commitear `Secrets.swift`** — está en `.gitignore`. API keys (Gemini, Groq) viven ahí.
- No hacer cambios que no se han pedido. Si hay varias formas, preguntar antes de elegir.
- Commits solo cuando se piden explícitamente.
- IA está **deshabilitada**. `AIAdvisorView` y todo el `AIService` siguen en el
  repo; lo que no hay es forma de llegar a ellos. Para reactivar: devolver la
  pestaña a `MainTabView.swift` apuntando a `AIAdvisorView()`.
- No hay placeholder de "Próximamente" en ninguna parte, y no debe volver a
  haberlo: una función anunciada en la interfaz que al tocarla no hace nada es
  contenido de relleno, y App Review la rechaza por la guideline 2.1.

## Build & Deploy

### App Store (fastlane)

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
FASTLANE_XCODEBUILD_SETTINGS_TIMEOUT=180 FASTLANE_XCODEBUILD_SETTINGS_RETRIES=3 \
LANG=en_US.UTF-8 fastlane release
```

Cuatro trampas que ya han costado un intento fallido cada una:

- **Para la tienda, Xcode 26.5.** El Xcode activo (`xcode-select`) es el 27.1
  de `/Volumes/SSDani/Xcode/Xcode-27.app`, necesario para instalar en el iPhone
  18 Pro, pero App Store Connect aún no acepta builds suyas: la 2.3.1 (43) se
  subió y al enviarla dio `The build's Xcode build is not yet supported`. Con
  `DEVELOPER_DIR` apuntando al 26.5 se compila con él sin tocar `xcode-select`.
  Cuando Apple admita el 27, quitar esa línea.
- **`xcodebuild -showBuildSettings` tarda ~50 s** con Xcode en el disco externo
  y fastlane solo espera unos segundos por defecto: sin las dos variables
  `FASTLANE_XCODEBUILD_SETTINGS_*` falla antes de compilar, con el número de
  build ya subido.

- **`LANG` en UTF-8 es obligatorio.** Sin él, `xcodeproj` revienta leyendo el
  pbxproj con `invalid byte sequence in US-ASCII` (hay acentos dentro). Peta
  *después* de `increment_build_number`, así que el número queda subido y el
  binario no: hay que `git checkout Clarity.xcodeproj/project.pbxproj` antes de
  reintentar o te saltas un build.
- **No hay Gemfile** — `bundle exec fastlane` falla con "Could not locate
  Gemfile". Se invoca `fastlane` a pelo.

La lane `release` lleva `submit_for_review: false`: sube binario + metadata y
deja la versión lista, pero enviar a revisión es siempre manual (o con
spaceship: `Build.all(app_id:build_number:)` hasta `VALID`,
`version.select_build`, `get_ready_review_submission || create_review_submission`,
`add_app_store_version_to_review_items`, `submit_for_review`; Ruby de rbenv
`/Users/dani/.rbenv/versions/3.3.0/bin/ruby`, el del sistema no tiene spaceship).

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
# Build para el iPhone 18 Pro (con Xcode 27.1, el activo: el 26.5 no lo reconoce)
xcodebuild -project Clarity.xcodeproj -scheme Clarity -configuration Debug \
  -destination 'id=00008160-00092C9C28C1400A' -allowProvisioningUpdates build

# Install (sin uninstall previo)
xcrun devicectl device install app --device 00008160-00092C9C28C1400A \
  /Volumes/SSDani/Xcode_DerivedData/Clarity-cjwlvudtapgvkvajnodrsdfvozgs/Build/Products/Debug-iphoneos/Clarity.app
```

- **iPhone Dani (18 Pro, iOS 27)**: `00008160-00092C9C28C1400A`. Xcode 27.1 necesita
  el Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`) por los
  shaders de la Home.
- **iPhone anterior (15 Pro Max)**: `DC3A9753-6C32-5B4D-9DB5-7384A631B0C4`
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
- **Data** (`Clarity/Data/`): Repository implementations. `ExpenseRepository` es híbrido: `FirebaseExpenseDataSource` (remoto) + `SwiftDataExpenseDataSource` (cache). La sincronización de fondo va **por ventana** (desde el día 1 de hace dos meses, con purga de huérfanos solo ahí) y hay una completa cada 7 días o con la caché vacía; la política está en funciones puras en `ExpenseSyncPolicy`. Quien escriba gastos en Firestore por fuera del repositorio debe llamar a `ExpenseSyncPolicy.olvidarMarcas()`.
- **Features** (`Clarity/Features/`): Views + ViewModels (`@Observable`) + servicios específicos por feature.

### Dependency Injection

`DependencyContainer` (`Clarity/Core/DI/DependencyContainer.swift`) es `@MainActor` singleton. Repos = lazy singletons. Use cases = factory methods (structs). ViewModels = factory methods que cablean use cases.

**Regla**: nunca acceder a `DependencyContainer.shared` desde una `View` directamente — solo desde ViewModels.

### Concurrencia

- El proyecto compila en **modo de lenguaje Swift 5** (`SWIFT_VERSION = 5.0`) con approachable concurrency y `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`: todo tipo sin anotar es `@MainActor`, y lo que deba correr fuera va `nonisolated` explícito. Las carreras de datos son avisos, no errores, y no hay comprobaciones de aislamiento en ejecución: que compile no prueba que sea seguro. Se escribe como si fuera Swift 6.
- ViewModels + DI + tests = `@MainActor`.
- Sólo `async/await`. Nunca callbacks ni Combine.
- `@Observable` macro para estado. **NUNCA** `ObservableObject` ni `@Published`.
- Lecturas remotas que gatean una pantalla: `withTimeout` (`Core/Utilities/AsyncTimeout.swift`). Firestore no atiende a la cancelación, por eso no usa `TaskGroup`.

### Testing

Apple Swift Testing (`import Testing`). `@Test` + `#expect()` + `try #require()`. **No XCTest** en `ClarityTests/`: además de la convención, XCTest enlaza un `TaskLocal` por método que hace abortar el proceso de tests con los deinit aislados de la app. Mock repos implementan los mismos protocolos. **Ningún test toca Firestore, Auth ni la red reales**: los tests corren dentro de la app con la sesión iniciada.

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
| `AIAdvisor` | `Features/AIAdvisor/` | **Deshabilitado** — sin entrada en la UI |
| `Voice` | `Features/Voice/` | Speech → parser → expense |
| `Expenses` / `AddExpense` | `Features/Expenses/`, `Features/AddExpense/` | CRUD + paginación |
| `RecurringExpenses` | `Features/RecurringExpenses/` | LOCAL (NO Cloud Functions) |
| `Financial` | `Features/Financial/` | Pestaña Metas (`FinancialDashboardView`): metas, nómina/presupuesto mensual (`MonthlyBudgetsViewModel`), ingresos extra |
| `Charts` | `Features/Charts/` | Solo `CategoryBreakdownTable` (desglose de una categoría, menú contextual de `ResumenPage`). Las gráficas viven en la Home: `Presentation/Screens/Home/Pages/GraficasPage.swift` |

## Data Persistence

- **Remote**: Firestore. Colecciones: `users`, `expenses`, `budgets`, `categories`, `recurringExpenses`.
- **Local cache**: SwiftData (migración auto desde JSON legacy).
- **Híbrido**: `.cacheFirst` para reads, `.networkFirst` para datos críticos.

## Recurring Expenses (LOCAL — no Cloud Functions)

`LocalRecurringExpenseManager`:
- Corre en `MainTabView.task` al arrancar.
- `checkAndCreatePendingExpenses()` — crea gastos de hoy (1× al día).
- `recoverMissedExpenses()` — recupera los cargos que falten en los últimos 12 meses, pero **solo desde el alta de la regla** (`RecurringScheduler.mesesRecuperables`). Se lanza desde la pantalla de Recurrentes, una vez al día.
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

`AIService` con provider pattern (`AIServiceProvider`). Implementaciones: `GeminiProvider`, `GroqProvider`. `PromptBuilder` arma contexto financiero (~500 tokens máx). Las claves de Gemini y Groq se guardan en el llavero (`APIKeychain`), con migración desde UserDefaults.

## Diagnóstico de cuelgues

`Clarity/Core/Diagnostics/`: migas de pan (`Migas.deja("…")`, **solo nombres de pantalla y de acción, nunca importes, nombres de gasto ni datos de la cuenta**), vigilante del hilo principal (informe a disco si pasa de 3 s), suscriptor de MetricKit y volcado de las migas al salir de la app. El pie del correo de soporte (`SupportContact`) lleva el resumen del último cuelgue o de la sesión anterior. No quitar las migas al mover código de `MainTabView`, `AddExpenseSheet` o `EditExpenseSheet`.

## Formularios

- «Cancelar» y deslizar pasan por `confirmarDescarte(hayCambios:)` (`UI/Modifiers/ConfirmarDescarte.swift`): con cambios respecto al estado inicial, pregunta antes de tirar lo escrito.
- La barra «Hecho» del teclado y la transición de zoom de las hojas dependen de la versión de iOS (`#unavailable(iOS 27)`, `transicionZoomDeHoja`). Cada detalle está ahí por un cuelgue real: no tocarlos sin poder probar en iOS 26 y en iOS 27.

## UI System

- Design System en `Clarity/UI/Theme/DesignSystem.swift`. Tokens para corner radii, icon sizes, animation durations, paleta de 12 colores. Los colores de marca viven en `UI/Theme/Colors.swift`: familia Deep Berry (`clarityPrimary` #BF4DCB) con `clarityMango` #FFCE6B como único acento cálido; el widget repite el de marca en `EstiloWidget.marca`.
- Vidrio: el helper `glassCard(cornerRadius:)` de `UI/Theme/Glass.swift` (trae la rama de iOS 26). `GlassCard` (struct) es el antiguo, sin vidrio de iOS 26.
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

- Modo de lenguaje Swift 5 con MainActor por defecto (ver «Concurrencia»); se escribe como si fuera Swift 6.
- `@Observable` (no Combine).
- SwiftUI > UIKit siempre que se pueda.
- ViewModels solo importan Foundation + domain models (no `import SwiftUI`).
- Views sin lógica — solo layout + bindings.
- Naming: `NombreView.swift`, `NombreViewModel.swift`, `NombreService.swift`, `NombreRepository.swift`.
- SPM para deps iOS (no CocoaPods).
