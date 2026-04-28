import AppIntents
import UIKit

// MARK: - Add Expense Intent
//
// NOTE on parameterized phrases:
// Apple's AppShortcut phrases only support .$param tokens for AppEntity / AppEnum parameters.
// Free-form String parameters cannot be embedded inline in a phrase.
// Solution: use trigger-only phrases → Siri opens the app, then asks "¿Qué gasto quieres añadir?"
// via requestValueDialog, and routes the answer through the voice parser.
//
// IMPORTANT: Phrases MUST start with \(.applicationName) to avoid Siri disambiguation
// with other apps (e.g. Notes asking "¿En Notas o en Clarity?"). When the app name
// leads the phrase, iOS routes directly without asking.
//
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Añadir Gasto"
    static var description = IntentDescription(
        "Registra un nuevo gasto en Clarity por voz",
        categoryName: "Finanzas"
    )

    static var openAppWhenRun: Bool = true

    @Parameter(
        title: "Gasto",
        description: "Describe el gasto (ej: \"13 euros Mercadona\")",
        requestValueDialog: IntentDialog("¿Qué gasto quieres añadir?")
    )
    var phrase: String

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let encoded = phrase.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "clarity://add-expense?input=\(encoded)")
        else {
            return .result()
        }

        try await Task.sleep(nanoseconds: 250_000_000)
        await UIApplication.shared.open(url)

        return .result()
    }
}

// MARK: - Get Spending Summary Intent

struct GetSpendingSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Resumen de gastos"
    static var description = IntentDescription(
        "Consulta cuánto llevas gastado este mes por voz",
        categoryName: "Finanzas"
    )

    static var openAppWhenRun: Bool = false

    private nonisolated func loadWidgetData() -> SharedWidgetData? {
        let appGroupID = "group.com.idanidev.clarity"
        let widgetKey  = "widgetData_v2"
        guard
            let defaults = UserDefaults(suiteName: appGroupID),
            let raw = defaults.data(forKey: widgetKey)
        else { return nil }
        return try? JSONDecoder().decode(SharedWidgetData.self, from: raw)
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let data = loadWidgetData() else {
            return .result(dialog: "No tengo datos de gastos disponibles. Abre Clarity para sincronizar.")
        }

        let monthTotal = Int(data.monthTotal)
        let monthName = data.monthName

        if let budget = data.monthBudget, budget > 0 {
            let budgetInt = Int(budget)
            let remaining = max(budgetInt - monthTotal, 0)
            return .result(
                dialog: "En \(monthName) llevas gastados \(monthTotal) euros de \(budgetInt) euros de presupuesto. Te quedan \(remaining) euros."
            )
        } else {
            return .result(
                dialog: "En \(monthName) llevas gastados \(monthTotal) euros."
            )
        }
    }
}

// MARK: - Shortcuts Provider
struct ClarityShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                // App name FIRST avoids Siri disambiguation with Notes/Reminders.
                // "Clarity, añade un gasto" routes directly.
                // NEVER put app name at end — "Añadir gasto en Clarity" conflicts with Notes.
                "\(.applicationName) añade un gasto",
                "\(.applicationName) nuevo gasto",
                "\(.applicationName) registra un gasto",
                "\(.applicationName) apunta un gasto",
                "\(.applicationName) meter gasto",
                "\(.applicationName) gasto",
                "\(.applicationName) añadir gasto",
                // App-name-at-end: Siri pregunta 1 vez Clarity vs Notas, luego recuerda.
                "añade un gasto en \(.applicationName)",
                "apunta un gasto en \(.applicationName)",
                "nuevo gasto en \(.applicationName)",
                "registra un gasto en \(.applicationName)",
            ],
            shortTitle: "Añadir Gasto",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: GetSpendingSummaryIntent(),
            phrases: [
                "\(.applicationName) cuánto llevo gastado",
                "\(.applicationName) resumen de gastos",
                "\(.applicationName) cuánto me queda",
                "cuánto llevo gastado en \(.applicationName)",
                "cuánto me queda en \(.applicationName)",
                "resumen de gastos en \(.applicationName)",
            ],
            shortTitle: "Resumen de gastos",
            systemImageName: "chart.bar.fill"
        )
    }
}
