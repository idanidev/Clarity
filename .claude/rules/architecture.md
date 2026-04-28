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
