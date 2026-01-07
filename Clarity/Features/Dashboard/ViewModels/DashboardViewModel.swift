// DashboardViewModel.swift
// Dashboard state management - loads all expenses for local filtering

import Foundation
import Observation

@MainActor
@Observable
class DashboardViewModel {
    // MARK: - Properties (NO @Published needed with @Observable)
    var expenses: [Expense] = []
    var isLoading = false
    var errorMessage: String?
    var showAddExpense = false
    
    // MARK: - Computed Properties
    var monthlyTotal: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    var groupedByCategory: [String: [Expense]] {
        Dictionary(grouping: expenses, by: { $0.category })
    }
    
    var categoryTotals: [CategoryTotal] {
        groupedByCategory.map { category, expenses in
            CategoryTotal(
                category: category,
                total: expenses.reduce(0) { $0 + $1.amount },
                count: expenses.count
            )
        }.sorted { $0.total > $1.total }
    }
    
    // MARK: - Dependencies
    private let repository = ExpenseRepository()
    
    // MARK: - Init
    init() {
        // Initial load is handled by .task in the view
    }
    
    // MARK: - Methods
    
    /// Loads ALL expenses (no date filter - filtering happens locally in the view)
    func loadExpenses() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load without date filter - view will filter locally
            expenses = try await repository.fetchExpenses(for: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func deleteExpense(_ expense: Expense) async {
        guard let id = expense.id else {
            print("❌ Cannot delete expense: ID is nil. Expense name: \(expense.name)")
            errorMessage = "Error: No se puede eliminar el gasto (ID no encontrado)"
            return
        }
        
        print("🗑️ Deleting expense: \(id) - \(expense.name)")
        
        do {
            try await repository.deleteExpense(id: id)
            expenses.removeAll { $0.id == id }
            print("✅ Expense deleted successfully")
        } catch {
            print("❌ Delete failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func refresh() async {
        await loadExpenses()
    }
}

// MARK: - Supporting Types
struct CategoryTotal: Identifiable {
    let id = UUID()
    let category: String
    let total: Double
    let count: Int
}
