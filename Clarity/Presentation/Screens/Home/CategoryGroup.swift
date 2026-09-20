// CategoryGroup.swift
// Gastos agrupados por categoría y subcategoría: lo que construye
// `HomeViewModel.agrupar` y pintan `ResumenPage` y `GraficasPage`.
// Vivían en ExpandableExpenseList.swift, que se eliminó por no tener usos.

import SwiftUI

// MARK: - Models

struct CategoryGroup: Identifiable, Equatable {
    // Stable ID based on name for consistent diffing
    var id: String { name }
    let name: String
    let emoji: String
    let color: Color
    var totalAmount: Double
    var expenseCount: Int
    // isExpanded removed from logic (handled by View)
    var subcategories: [SubcategoryGroup]

    static func == (lhs: CategoryGroup, rhs: CategoryGroup) -> Bool {
        lhs.id == rhs.id && lhs.totalAmount == rhs.totalAmount
            && lhs.subcategories == rhs.subcategories
    }
}

struct SubcategoryGroup: Identifiable, Equatable {
    var id: String { name }
    let name: String
    var totalAmount: Double
    var expenseCount: Int
    var expenses: [Expense]
}
