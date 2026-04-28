// OpenAddExpenseIntent.swift
// Lightweight AppIntent for the widget "Add Expense" button.
// Sets a flag in the shared App Group so the main app opens the
// manual-expense sheet on launch.

import AppIntents

struct OpenAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Añadir Gasto"
    static var description = IntentDescription("Abre Clarity para registrar un nuevo gasto")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        if let defaults = UserDefaults(suiteName: "group.com.idanidev.clarity") {
            defaults.set(true, forKey: "widget_open_add_expense")
        }
        return .result()
    }
}
