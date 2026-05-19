// SharedWidgetData.swift — ClarityWidget Extension
// Shared model between main app and widget via App Group UserDefaults.
// Only Foundation — no Firebase, no AVFoundation.

import Foundation

// MARK: - Shared Widget Data Model

struct SharedWidgetData: Codable {
    let todayTotal: Double
    let weekTotal: Double
    let monthTotal: Double
    let monthBudget: Double?
    let recentExpenses: [WidgetExpense]
    let topCategoryEmoji: String
    let currency: String
    let monthName: String
    let updatedAt: Date
    /// Top categorías del MES. Default vacío para back-compat con datos antiguos.
    var topMonthCategories: [WidgetCategoryStat] = []

    // MARK: Computed

    var budgetPercent: Double? {
        guard let budget = monthBudget, budget > 0 else { return nil }
        return min(monthTotal / budget, 1.0)
    }

    /// Detecta si el usuario aún no tiene gastos este mes/semana/hoy.
    var isEmpty: Bool {
        todayTotal == 0 && weekTotal == 0 && monthTotal == 0 && recentExpenses.isEmpty
    }

    var formattedToday: String   { format(todayTotal) }
    var formattedWeek: String    { format(weekTotal) }
    var formattedMonth: String   { format(monthTotal) }
    var formattedBudget: String? { monthBudget.map { format($0) } }

    private func format(_ amount: Double) -> String {
        if amount >= 1000 {
            return "\(currency)\(String(format: "%.1f", amount / 1000))k"
        }
        return "\(currency)\(String(format: "%.2f", amount))"
    }

    // MARK: Placeholder

    static var placeholder: SharedWidgetData {
        var d = SharedWidgetData(
            todayTotal: 34.50,
            weekTotal: 120.80,
            monthTotal: 312.40,
            monthBudget: 400.0,
            recentExpenses: [
                WidgetExpense(name: "Mercadona", amount: 45.00, emoji: "🛒", category: "Alimentación", timeAgo: "10:30"),
                WidgetExpense(name: "Cerveza",   amount: 10.00, emoji: "🍺", category: "Ocio",         timeAgo: "17:08"),
                WidgetExpense(name: "Gasolina",  amount: 65.00, emoji: "⛽", category: "Transporte",   timeAgo: "Ayer"),
                WidgetExpense(name: "Gimnasio",  amount: 39.99, emoji: "🏋️", category: "Deporte",      timeAgo: "Hace 2d"),
            ],
            topCategoryEmoji: "🛒",
            currency: "€",
            monthName: "Marzo",
            updatedAt: Date()
        )
        d.topMonthCategories = [
            WidgetCategoryStat(name: "Alimentación", emoji: "🛒", amount: 145, percent: 0.46),
            WidgetCategoryStat(name: "Ocio",         emoji: "🍻", amount: 88,  percent: 0.28),
            WidgetCategoryStat(name: "Transporte",   emoji: "⛽", amount: 65,  percent: 0.21),
        ]
        return d
    }
}

// MARK: - Widget Expense

struct WidgetExpense: Codable, Identifiable {
    let id: UUID
    let name: String
    let amount: Double
    let emoji: String
    let category: String
    let timeAgo: String

    init(name: String, amount: Double, emoji: String, category: String, timeAgo: String) {
        self.id       = UUID()
        self.name     = name
        self.amount   = amount
        self.emoji    = emoji
        self.category = category
        self.timeAgo  = timeAgo
    }

    var formattedAmount: String {
        String(format: "€%.2f", amount)
    }
}

// MARK: - Widget Category Stat

struct WidgetCategoryStat: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let amount: Double
    let percent: Double

    init(name: String, emoji: String, amount: Double, percent: Double) {
        self.id = name
        self.name = name
        self.emoji = emoji
        self.amount = amount
        self.percent = percent
    }

    var formattedAmount: String {
        if amount >= 1000 { return String(format: "€%.1fk", amount / 1000) }
        return String(format: "€%.0f", amount)
    }
}
