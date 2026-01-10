
import AppIntents
import SwiftUI

// MARK: - Add Expense Intent
// MARK: - Add Expense Intent
struct AddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Añadir Gasto"
    static var description = IntentDescription("Abre Clarity para registrar un nuevo gasto, opcionalmente con detalles")
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Frase", description: "El gasto a registrar, ej: '10 euros en tabaco'", requestValueDialog: "¿Qué quieres añadir?")
    var phrase: String?
    
    @MainActor
    func perform() async throws -> some IntentResult {
        // Construct URL
        var urlString = "clarity://add-expense"
        if let phrase = phrase, let encoded = phrase.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            urlString += "?input=\(encoded)"
        }
        
        return .result(opensIntent: OpenURLIntent(URL(string: urlString)!))
    }
}

// MARK: - Shortcuts Provider
struct ClarityShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddExpenseIntent(),
            phrases: [
                "Añadir gasto en \(.applicationName)",
                "Nuevo gasto en \(.applicationName)",
                "Registrar gasto en \(.applicationName)",
                "Crear gasto en \(.applicationName)"
            ],
            shortTitle: "Añadir Gasto",
            systemImageName: "plus.circle.fill"
        )
    }
}
