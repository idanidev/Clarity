import AppIntents
import UIKit

// MARK: - Add Expense Intent
//
// NOTE on parameterized phrases:
// Apple's AppShortcut phrases only support .\$param tokens for AppEntity / AppEnum parameters.
// Free-form String parameters cannot be embedded inline in a phrase.
// Solution: use trigger-only phrases → Siri opens the app, then asks "¿Qué gasto quieres añadir?"
// via requestValueDialog, and routes the answer through the voice parser.
//
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Añadir Gasto"
    static var description = IntentDescription(
        "Registra un nuevo gasto en Clarity directamente desde Siri",
        categoryName: "Finanzas"
    )

    // openAppWhenRun brings the app to foreground before perform() runs
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

        // The app is already in the foreground (openAppWhenRun = true).
        // Small delay to ensure the scene is fully active before routing the deep link.
        try await Task.sleep(nanoseconds: 250_000_000)  // 0.25s
        await UIApplication.shared.open(url)

        return .result()
    }
}

// MARK: - Shortcuts Provider
struct ClarityShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                // Trigger phrases — Siri will then ask "¿Qué gasto quieres añadir?"
                // and pass the answer as `phrase` to perform()
                "Añadir gasto en \(.applicationName)",
                "Nuevo gasto en \(.applicationName)",
                "Registrar gasto en \(.applicationName)",
                "Apuntar gasto en \(.applicationName)",
                "Añade un gasto en \(.applicationName)",
            ],
            shortTitle: "Añadir Gasto",
            systemImageName: "plus.circle.fill"
        )
    }
}
