# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Clarity is a native iOS expense tracking app built with SwiftUI, targeting iOS 17+. It uses Firebase for backend services and follows Clean Architecture with MVVM presentation.

## Build & Test Commands

```bash
# Build the iOS app
xcodebuild -project Clarity.xcodeproj -scheme Clarity -sdk iphonesimulator -configuration Debug build

# Run unit tests
xcodebuild -project Clarity.xcodeproj -scheme Clarity -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' test

# Run UI tests
xcodebuild -project Clarity.xcodeproj -scheme Clarity -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ClarityUITests test

# Run a single test file/suite (use -only-testing with test target path)
xcodebuild -project Clarity.xcodeproj -scheme Clarity -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ClarityTests/HomeViewModelTests test
```

**Note:** Firebase Cloud Functions are deprecated. Recurring expenses are now managed locally in iOS (see `LocalRecurringExpenseManager`).

## Architecture

### Clean Architecture Layers

```
Domain (innermost)  →  Data  →  Features/Presentation (outermost)
```

- **Domain** (`Clarity/Domain/`): Models, repository protocols, and use cases. No framework imports. Use cases are lightweight structs that hold a repository reference (e.g., `AddExpenseUseCase`, `GetExpensesUseCase`, `DeleteExpenseUseCase`).
- **Data** (`Clarity/Data/`): Repository implementations and data sources. `ExpenseRepository` is a hybrid repository composing three data sources: `FirebaseExpenseDataSource` (remote), `SwiftDataExpenseDataSource` (local cache), and `LocalExpenseDataSource` (legacy JSON, deprecated).
- **Features** (`Clarity/Features/`): Feature modules each containing Views, ViewModels, and feature-specific Services. ViewModels use the `@Observable` macro (Observation framework).

### Dependency Injection

`DependencyContainer` (`Clarity/Core/DI/`) is a `@MainActor` singleton. Repositories are lazy singletons; use cases are created via factory methods (lightweight structs). ViewModels are created via factory methods that wire use cases.

### Concurrency Model

All ViewModels and the DependencyContainer are `@MainActor` isolated. Async operations use Swift structured concurrency (async/await). Tests must also be marked `@MainActor`.

### Testing

Tests use Apple's Swift Testing framework (`import Testing`), not XCTest. Tests use `@Test` attribute and `#expect()` macros. Mock repositories implement the same protocols as production repositories.

### Key Modules

| Feature | Purpose |
|---------|---------|
| `Auth` | Email/password, Apple Sign-in, Google Sign-in via Firebase Auth |
| `AIAdvisor` | Multi-provider AI chat (Gemini, Groq) with `PromptBuilder` for financial context |
| `Voice` | Speech recognition → `SmartTransactionParser` → expense creation, with `UserLearningManager` |
| `Expenses` | CRUD for expenses with pagination and filtering |
| `Budgets` | Monthly budgets, savings goals, spending limits |
| `RecurringExpenses` | Local iOS manager checks and creates recurring expenses on app launch (no Cloud Functions) |
| `Financial` | Analytics, charts, trends, forecasts |

### AI Service Architecture

`AIService` uses a provider pattern (`AIServiceProvider` protocol) with `GeminiProvider` and `GroqProvider` implementations. `PromptBuilder` constructs token-efficient financial context summaries. Groq API key is stored in UserDefaults; Gemini key is configured in code.

### Data Persistence

- **Remote**: Firebase Firestore (collections: `users`, `expenses`, `budgets`, `categories`, `recurringExpenses`)
- **Local cache**: SwiftData (automatic migration from legacy JSON storage)
- **Hybrid**: Repository implementations support `.cacheFirst` and `.networkFirst` strategies

### Recurring Expenses (Local)

`LocalRecurringExpenseManager` handles automatic creation of recurring expenses entirely on-device:
- Runs on app launch via `MainTabView.task`
- `checkAndCreatePendingExpenses()`: Creates expenses due today (runs once per day)
- `recoverMissedExpenses()`: Recovers missed expenses from current month
- Supports monthly, quarterly, semestral, and yearly frequencies
- Uses `billingMonth` field to calculate correct billing cycles for non-monthly frequencies
- Prevents duplicates by checking `expenseExistsForMonth()` before creating
- No Cloud Functions required (deprecated due to Firebase free tier limits)

### UI System

SwiftUI with a custom design system (`Clarity/UI/Theme/DesignSystem.swift`) defining tokens for corner radii, icon sizes, animation durations, and a 12-color palette. Glass morphism components (`GlassCard`, `LiquidGlassCard`). Haptic feedback via `HapticManager` using Core Haptics.

## Key Conventions

- Swift 6.0+ with strict concurrency
- `@Observable` macro for state management (not Combine's ObservableObject)
- Localized in Spanish (primary) and English
- Firebase project ID: `clarity-gastos`
- SPM for iOS dependencies (no CocoaPods)
- Recurring expenses managed locally (no Cloud Functions)
