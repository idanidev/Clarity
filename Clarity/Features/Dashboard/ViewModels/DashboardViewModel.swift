// DashboardViewModel.swift
// Dashboard state management - loads all expenses for local filtering

import Foundation
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var expenses: [Expense] = []
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var showAddExpense = false
    
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
        Task {
            await loadExpenses()
        }
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
        guard let id = expense.id else { return }
        
        do {
            try await repository.deleteExpense(id: id)
            expenses.removeAll { $0.id == id }
        } catch {
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
