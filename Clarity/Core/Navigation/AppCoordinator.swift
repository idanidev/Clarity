// AppCoordinator.swift
// Coordinador centralizado de navegación
// Maneja la navegación de forma estructurada y desacoplada

import SwiftUI

/// Destinos de navegación en la app
enum AppDestination: Hashable, Identifiable {
    case expenseDetail(String) // expenseId
    case addExpense
    case editExpense(String) // expenseId
    case settings
    case categoryDetail(String) // categoryName
    case recurringExpenses
    case filters
    case voiceInput
    case calendarView
    case chartsView

    var id: String {
        switch self {
        case .expenseDetail(let id): return "expense-\(id)"
        case .addExpense: return "add-expense"
        case .editExpense(let id): return "edit-\(id)"
        case .settings: return "settings"
        case .categoryDetail(let name): return "category-\(name)"
        case .recurringExpenses: return "recurring"
        case .filters: return "filters"
        case .voiceInput: return "voice"
        case .calendarView: return "calendar"
        case .chartsView: return "charts"
        }
    }
}

/// Tab principal de la app
enum AppTab: String, CaseIterable, Identifiable {
    case home
    case charts
    case calendar
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Inicio"
        case .charts: return "Gráficos"
        case .calendar: return "Calendario"
        case .settings: return "Ajustes"
        }
    }

    var icon: String {
        switch self {
        case .home: return "list.bullet"
        case .charts: return "chart.pie.fill"
        case .calendar: return "calendar"
        case .settings: return "gearshape.fill"
        }
    }
}

/// Estado de navegación centralizado
@MainActor
@Observable
final class AppCoordinator {
    // MARK: - Tab Navigation
    var selectedTab: AppTab = .home

    // MARK: - Stack Navigation
    var navigationPath = NavigationPath()

    // MARK: - Sheet Presentation
    var presentedSheet: AppDestination?
    var presentedFullScreen: AppDestination?

    // MARK: - Alert
    var alertTitle: String?
    var alertMessage: String?
    var alertActions: [AlertAction] = []

    // MARK: - Navigation Methods

    func push(_ destination: AppDestination) {
        HapticManager.shared.buttonPress()
        navigationPath.append(destination)
    }

    func pop() {
        HapticManager.shared.buttonPress()
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        }
    }

    func popToRoot() {
        HapticManager.shared.buttonPress()
        navigationPath = NavigationPath()
    }

    func presentSheet(_ destination: AppDestination) {
        HapticManager.shared.buttonPress()
        presentedSheet = destination
    }

    func presentFullScreen(_ destination: AppDestination) {
        HapticManager.shared.buttonPress()
        presentedFullScreen = destination
    }

    func dismissSheet() {
        HapticManager.shared.buttonPress()
        presentedSheet = nil
    }

    func dismissFullScreen() {
        HapticManager.shared.buttonPress()
        presentedFullScreen = nil
    }

    func switchTab(_ tab: AppTab) {
        HapticManager.shared.tabSwitch()
        selectedTab = tab

        // Reset navigation when switching tabs
        if navigationPath.count > 0 {
            navigationPath = NavigationPath()
        }
    }

    // MARK: - Alert Methods

    func showAlert(title: String, message: String, actions: [AlertAction] = []) {
        alertTitle = title
        alertMessage = message
        alertActions = actions.isEmpty ? [.ok] : actions
    }

    func dismissAlert() {
        alertTitle = nil
        alertMessage = nil
        alertActions = []
    }

    // MARK: - Convenience Navigation

    func openAddExpense() {
        presentSheet(.addExpense)
    }

    func openEditExpense(_ expense: Expense) {
        presentSheet(.editExpense(expense.stableId))
    }

    func openExpenseDetail(_ expense: Expense) {
        push(.expenseDetail(expense.stableId))
    }

    func openFilters() {
        presentSheet(.filters)
    }

    func openVoiceInput() {
        presentFullScreen(.voiceInput)
    }

    func openSettings() {
        push(.settings)
    }

    func openCategoryDetail(_ category: CategoryGroup) {
        push(.categoryDetail(category.name))
    }

    func openRecurringExpenses() {
        push(.recurringExpenses)
    }
}

// MARK: - Alert Action

struct AlertAction: Identifiable {
    let id = UUID()
    let title: String
    let role: ButtonRole?
    let action: (() -> Void)?

    init(title: String, role: ButtonRole? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.role = role
        self.action = action
    }

    static var ok: AlertAction {
        AlertAction(title: "OK")
    }

    static var cancel: AlertAction {
        AlertAction(title: "Cancelar", role: .cancel)
    }

    static func destructive(title: String, action: @escaping () -> Void) -> AlertAction {
        AlertAction(title: title, role: .destructive, action: action)
    }
}

// MARK: - Destination View Builder

@MainActor
@ViewBuilder
func destinationView(for destination: AppDestination, coordinator: AppCoordinator) -> some View {
    switch destination {
    case .expenseDetail(let id):
        Text("Detalle de gasto: \(id)")
            .navigationTitle("Detalle")

    case .addExpense:
        AddExpenseSheet(onSave: {})

    case .editExpense(let id):
        Text("Editar gasto: \(id)")
            .navigationTitle("Editar")

    case .settings:
        SettingsView()

    case .categoryDetail:
        Text("Categoría")
            .navigationTitle("Categoría")

    case .recurringExpenses:
        RecurringExpensesView()

    case .filters:
        Text("Filtros")

    case .voiceInput:
        Text("Entrada por voz")

    case .calendarView:
        ExpenseCalendarView(expenses: [])

    case .chartsView:
        ChartsView()
    }
}
