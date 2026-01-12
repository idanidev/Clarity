// HomeViewModel.swift
// ViewModel for the main expense list/dashboard

import Foundation
import Combine
import SwiftUI

enum HomeViewState: Equatable {
    case idle
    case loading
    case loaded([Expense])
    case error(String)
    case empty
    
    static func == (lhs: HomeViewState, rhs: HomeViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.empty, .empty): return true
        case (.loaded(let l), .loaded(let r)): return l == r
        case (.error(let l), .error(let r)): return l == r
        default: return false
        }
    }
}

@MainActor
final class HomeViewModel: ObservableObject {
    
    // Output
    @Published private(set) var state: HomeViewState = .idle
    @Published var selectedFilter: ExpenseFilter = ExpenseFilter() {
        didSet { applyFilters() }
    }
    @Published var searchText: String = "" {
        didSet { applyFilters() }
    }
    
    // Data for View
    @Published var categoryGroups: [CategoryGroup] = []
    @Published var filteredExpenses: [Expense] = []
    @Published var dateFilteredExpenses: [Expense] = [] // For Savings calculation
    @Published var income: Double = 0
    
    // Internal
    private let getExpensesUseCase: GetExpensesUseCase
    private let deleteExpenseUseCase: DeleteExpenseUseCase
    private let addExpenseUseCase: AddExpenseUseCase
    
    // Exposed for View Logic (loading check)
    var allExpenses: [Expense] = []
    
    init(
        getExpensesUseCase: GetExpensesUseCase,
        deleteExpenseUseCase: DeleteExpenseUseCase,
        addExpenseUseCase: AddExpenseUseCase
    ) {
        self.getExpensesUseCase = getExpensesUseCase
        self.deleteExpenseUseCase = deleteExpenseUseCase
        self.addExpenseUseCase = addExpenseUseCase
        
        // Load income - temporary direct access to keep parity
        self.income = UserDataManager.shared.userDocument?.income ?? 0
    }
    
    // MARK: - Intents
    
    func duplicateExpense(_ expense: Expense) async {
        let duplicated = Expense(
            amount: expense.amount,
            name: expense.name,
            category: expense.category,
            subcategory: expense.subcategory,
            date: Formatters.isoString(from: Date()), // Current date
            paymentMethod: expense.paymentMethod,
            notes: expense.notes,
            isDeductible: expense.isDeductible
        )
        
        do {
            try await addExpenseUseCase.execute(duplicated)
            await loadExpenses()
        } catch {
            state = .error("Error al duplicar: \(error.localizedDescription)")
        }
    }
    
    func deleteExpense(_ expense: Expense) async {
        guard let id = expense.id else { return }
        do {
            try await deleteExpenseUseCase.execute(id: id)
            await loadExpenses()
        } catch {
            state = .error("Error al eliminar: \(error.localizedDescription)")
        }
    }
    
    func loadExpenses() async {
        // Refresh income
        self.income = UserDataManager.shared.userDocument?.income ?? 0
        
        state = .loading
        do {
            let expenses = try await getExpensesUseCase.execute(filter: nil)
            self.allExpenses = expenses
            
            applyFilters()
            state = .loaded(filteredExpenses)
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func refresh() async {
        await loadExpenses()
    }
    
    // MARK: - Logic
    
    private func applyFilters() {
        // 1. Deduplicate (just in case)
        let uniqueExpenses = deduplicate(expenses: allExpenses)
        
        // 2. Date Filter (Base for everything)
        let dateRange = selectedFilter.dateRangeForQuery()
        let inDateRange = uniqueExpenses.filter {
            $0.date >= dateRange.0 && $0.date <= dateRange.1
        }
        self.dateFilteredExpenses = inDateRange
        
        // 3. Apply other filters (Category, Payment, Search)
        var result = inDateRange
        
        // Search
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                ($0.subcategory?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Category Filter
        if !selectedFilter.selectedCategories.isEmpty {
            result = result.filter { expense in
                selectedFilter.selectedCategories.contains { category in
                    expense.category.localizedCaseInsensitiveContains(category.components(separatedBy: " ").first ?? category)
                }
            }
        }
        
        // Payment Method Filter
        if !selectedFilter.selectedPaymentMethods.isEmpty {
            result = result.filter { expense in
                selectedFilter.selectedPaymentMethods.contains(expense.paymentMethod)
            }
        }
        
        self.filteredExpenses = result
        
        // 4. Build Groups
        buildCategoryGroups(from: result)
        
        if result.isEmpty {
            state = .empty
        } else {
            state = .loaded(result)
        }
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
    
    private func buildCategoryGroups(from expenses: [Expense]) {
        var groups: [String: CategoryGroup] = [:]
        
        for expense in expenses {
            let categoryName = extractCategoryName(from: expense.category)
            let emoji = extractEmoji(from: expense.category)
            
            if groups[categoryName] == nil {
                groups[categoryName] = CategoryGroup(
                    name: categoryName,
                    emoji: emoji,
                    color: colorForCategory(categoryName),
                    totalAmount: 0,
                    expenseCount: 0,
                    subcategories: []
                )
            }
            
            groups[categoryName]?.totalAmount += expense.amount
            groups[categoryName]?.expenseCount += 1
            
            // Add to subcategory
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
    
    // MARK: - Helpers
    private func extractCategoryName(from category: String) -> String {
        let components = category.components(separatedBy: " ")
        return components.first ?? category
    }
    
    private func extractEmoji(from category: String) -> String {
        let components = category.components(separatedBy: " ")
        return components.count > 1 ? components.last ?? "" : ""
    }
    
    private func colorForCategory(_ name: String) -> Color {
        UserDataManager.shared.color(for: name)
    }
}
