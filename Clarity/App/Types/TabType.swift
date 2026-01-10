// TabType.swift
// Strongly-typed tab navigation for MainTabView

import Foundation

enum TabType: Int, CaseIterable, Sendable {
    case expenses = 0
    case budgets = 1
    case addExpense = 2  // Center placeholder for radial button
    case assistant = 3
    case settings = 4
    
    var icon: String {
        switch self {
        case .expenses: "list.bullet"
        case .budgets: "target"
        case .addExpense: "" // No icon (invisible)
        case .assistant: "sparkles"
        case .settings: "gearshape.fill"
        }
    }
    
    var title: String {
        switch self {
        case .expenses: "Gastos"
        case .budgets: "Metas"
        case .addExpense: "" // No title (invisible)
        case .assistant: "IA"
        case .settings: "Ajustes"
        }
    }
}
