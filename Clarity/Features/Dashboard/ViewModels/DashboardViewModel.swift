// DashboardViewModel.swift
// Dashboard state management - loads all expenses for local filtering

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
class DashboardViewModel {
    // MARK: - Properties
    var expenses: [Expense] = []
    var isLoading = false
    var errorMessage: String?
    var showAddExpense = false
    
    // Filtering State (Moved from View)
    var searchText: String = "" {
        didSet {
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
                if !Task.isCancelled {
                    applyFilters()
                }
            }
        }
    }
    
    private var searchTask: Task<Void, Never>?
    
    var filter = ExpenseFilter(dateRange: .thisMonth) {
        didSet { applyFilters() }
    }
    
    // Output Data
    private(set) var filteredExpenses: [Expense] = []
    private(set) var dateFilteredExpenses: [Expense] = [] // For Savings (Date only)
    private(set) var categoryGroups: [CategoryGroup] = []
    
    // Computed (for View)
    var totalFilteredAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var calculatedSavings: Double {
        let monthlyIncome = UserDataManager.shared.userDocument?.income ?? 0
        let periodExpenses = dateFilteredExpenses.reduce(0) { $0 + $1.amount }
        return monthlyIncome - periodExpenses
    }
    
    // MARK: - Dependencies
    private let repository = DependencyContainer.shared.expenseRepository
    
    // MARK: - Init
    init() {
        // Initial load handled by View task
    }
    
    // MARK: - Methods
    
    /// Loads expenses with optional policy. Refreshes use .networkFirst
    func loadExpenses(policy: CachePolicy = .cacheFirst()) async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Load ALL expenses
            expenses = try await repository.getExpenses(policy: policy)
            applyFilters() // Apply local filters after load
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
            applyFilters() // Re-filter after deletion
            print("✅ Expense deleted successfully")
        } catch {
            print("❌ Delete failed: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    func refresh() async {
        await loadExpenses(policy: .networkFirst)
    }
    
    // MARK: - Filtering Logic
    
    private func applyFilters() {
        // 1. Deduplicate
        var result = deduplicate(expenses: expenses)
        
        // 2. Date Filter (Base for everything)
        let dateRange = filter.dateRangeForQuery()
        result = result.filter { $0.date >= dateRange.0 && $0.date <= dateRange.1 }
        
        // Save for Savings Calculation (Date only)
        self.dateFilteredExpenses = result
        
        // 3. Search Filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                ($0.subcategory?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // 4. Category Filter
        if !filter.selectedCategories.isEmpty {
            result = result.filter { expense in
                filter.selectedCategories.contains { category in
                    expense.category.localizedCaseInsensitiveContains(category.components(separatedBy: " ").first ?? category)
                }
            }
        }
        
        // 5. Payment Method Filter
        if !filter.selectedPaymentMethods.isEmpty {
            result = result.filter { filter.selectedPaymentMethods.contains($0.paymentMethod) }
        }
        
        // 6. Amount Range
        if let minAmount = filter.minAmount {
            result = result.filter { $0.amount >= minAmount }
        }
        if let maxAmount = filter.maxAmount {
            result = result.filter { $0.amount <= maxAmount }
        }
        
        // 7. Recurring Only
        if filter.showOnlyRecurring {
            result = result.filter { $0.isRecurring == true }
        }
        
        // 8. Sort
        switch filter.sortBy {
        case .dateDesc:
            result.sort { $0.date > $1.date }
        case .dateAsc:
            result.sort { $0.date < $1.date }
        case .amountDesc:
            result.sort { $0.amount > $1.amount }
        case .amountAsc:
            result.sort { $0.amount < $1.amount }
        case .nameAsc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
        
        self.filteredExpenses = result
        
        // 9. Build Groups
        buildCategoryGroups()
    }
    
    private func deduplicate(expenses: [Expense]) -> [Expense] {
        var seen = Set<String>()
        return expenses.filter { expense in
            guard let id = expense.id, !id.isEmpty else { return true }
            if seen.contains(id) { return false }
            seen.insert(id)
            return true
        }
    }
    
    private func buildCategoryGroups() {
        var groups: [String: CategoryGroup] = [:]
        
        for expense in filteredExpenses {
            let categoryName = extractCategoryName(from: expense.category)
            let emoji = extractEmoji(from: expense.category)
            
            if groups[categoryName] == nil {
                groups[categoryName] = CategoryGroup(
                    name: categoryName,
                    emoji: emoji,
                    color: colorForCategory(expense.category),
                    totalAmount: 0,
                    expenseCount: 0,
                    subcategories: []
                )
            }
            
            groups[categoryName]?.totalAmount += expense.amount
            groups[categoryName]?.expenseCount += 1
            
            let subcategoryName = expense.subcategory ?? "Sin subcategoría"
            if let subIndex = groups[categoryName]?.subcategories.firstIndex(where: { $0.name == subcategoryName }) {
                groups[categoryName]?.subcategories[subIndex].totalAmount += expense.amount
                groups[categoryName]?.subcategories[subIndex].expenseCount += 1
                groups[categoryName]?.subcategories[subIndex].expenses.append(expense)
            } else {
                groups[categoryName]?.subcategories.append(
                    SubcategoryGroup(
                        name: subcategoryName,
                        totalAmount: expense.amount,
                        expenseCount: 1,
                        expenses: [expense]
                    )
                )
            }
        }
        
        self.categoryGroups = Array(groups.values).sorted { $0.totalAmount > $1.totalAmount }
    }
    
    // Helpers
    private func extractCategoryName(from category: String) -> String {
        category.components(separatedBy: " ").first ?? category
    }
    
    private func extractEmoji(from category: String) -> String {
        let components = category.components(separatedBy: " ")
        return components.count > 1 ? components.last ?? "" : ""
    }
    
    private func colorForCategory(_ categoryWithEmoji: String) -> Color {
        let userDataManager = UserDataManager.shared
        if let category = userDataManager.categories.first(where: {
            $0.name.localizedCaseInsensitiveContains(categoryWithEmoji) ||
            categoryWithEmoji.localizedCaseInsensitiveContains($0.name.components(separatedBy: " ").first ?? $0.name)
        }) {
            return Color(hex: category.color) ?? .gray
        }
        return UserDataManager.shared.color(for: categoryWithEmoji)
    }
}

// MARK: - Supporting Types
struct CategoryTotal: Identifiable {
    let id = UUID()
    let category: String
    let total: Double
    let count: Int
}
