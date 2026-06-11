# Arquitectura Clarity — Reglas generales

## Capas (de adentro hacia afuera)
```
Domain → Data → Features/Presentation
```
- **Domain**: modelos, protocolos de repositorio, use cases. Sin imports de frameworks externos.
- **Data**: implementaciones de repositorios. Hybrid: FirebaseDataSource + SwiftDataCache.
- **Features**: Views + ViewModels + Services específicos de cada feature.

## Recurring Expenses
- Gestionados LOCALMENTE en iOS — NO hay Cloud Functions
- `LocalRecurringExpenseManager` corre en `MainTabView.task` al arrancar
- Nunca intentar migrar esto de vuelta a Firebase (deprecated por límites del free tier)

## Categorías (REGLAS CRÍTICAS — hubo pérdida de datos real, jun 2026)
- Source of truth: map `users/{uid}.categories` = `{id: {name, color, subcategories}}`.
- **PROHIBIDO** escribir una entrada del map (dot-path o FieldPath) sin garantizar
  antes que el map completo está persistido → usar SIEMPRE
  `persistCategoriesIfMissing` antes de add/update/delete/addSubcategory.
- **PROHIBIDO** el estado "defaults solo en memoria": si `loadCategories` no
  encuentra map (o está vacío), siembra los defaults en Firestore EN ESE MOMENTO.
  (Bug histórico: defaults en memoria + primer write dot-path → map quedaba con
  1 sola entrada → el resto de categorías "desaparecía".)
- **PROHIBIDO** `setData` del campo `categories` completo sin verificación previa
  contra SERVER. Solo `persistCategoriesIfMissing` escribe el map entero.
- Ids de defaults llevan emoji → field-paths con `FieldPath(["categories", id])`,
  no interpolación string.
- Defaults hardcodeados (`DefaultCategory`) = SOLO seed inicial. Nunca fallback
  visual si el usuario ya tiene datos persistidos.

## Firebase
- Firestore collections: `users`, `expenses`, `budgets`, `categories`, `recurringExpenses`
- Estrategias de caché: `.cacheFirst` para reads, `.networkFirst` para datos críticos
- Firebase Auth: email/password + Apple Sign-in + Google Sign-in

## Widget
- Target separado: `ClarityWidget`
- Comparte datos via App Group: `group.com.idanidev.clarity`
- Key de UserDefaults: `widgetData_v2`
- Assets propios en `ClarityWidget/Assets.xcassets/`

## DI
- `DependencyContainer` es `@MainActor` singleton
- ViewModels creados via factory methods, nunca instanciados directamente en Views

## Tests
- Framework: Swift Testing (`import Testing`), NO XCTest
- `@Test` y `#expect()` — nunca `XCTAssert`
- Mock repositories implementan los mismos protocolos que los reales
