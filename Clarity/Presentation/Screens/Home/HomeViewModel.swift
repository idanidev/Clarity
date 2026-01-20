// HomeViewModel.swift
// ViewModel for the main expense list/dashboard

import Foundation
import SwiftUI

enum HomeViewState: Equatable {
    case idle
    case loading
    case loaded([Expense])
    case error(AppError) // Changed from String
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
@Observable
final class HomeViewModel {
    
    // Output
    private(set) var state: HomeViewState = .idle
    var selectedFilter: ExpenseFilter = ExpenseFilter() {
        didSet { applyFilters() }
    }
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
    
    // Data for View
    var categoryGroups: [CategoryGroup] = []
    var filteredExpenses: [Expense] = []
    var dateFilteredExpenses: [Expense] = [] // For Savings calculation
    var income: Double = 0
    var showAddExpense = false // From DashboardViewModel
    
    // Computed properties (from DashboardViewModel)
    var totalFilteredAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    var calculatedSavings: Double {
        let periodExpenses = dateFilteredExpenses.reduce(0) { $0 + $1.amount }
        return income - periodExpenses
    }
    
    // Internal
    private let getExpensesUseCase: GetExpensesUseCase
    private let deleteExpenseUseCase: DeleteExpenseUseCase
    private let addExpenseUseCase: AddExpenseUseCase
    
    // Exposed for View Logic (loading check)
    var allExpenses: [Expense] = []
    
    // Pagination
    var currentPage = 0
    var hasMorePages = true
    var isLoadingMore = false
    
    init(
        getExpensesUseCase: GetExpensesUseCase,
        deleteExpenseUseCase: DeleteExpenseUseCase,
        addExpenseUseCase: AddExpenseUseCase
    ) {
        self.getExpensesUseCase = getExpensesUseCase
        self.deleteExpenseUseCase = deleteExpenseUseCase
        self.addExpenseUseCase = addExpenseUseCase
        
        // Load income
        self.income = UserDataManager.shared.userDocument?.income ?? 0
    }
    
    // MARK: - Intents
    
    func deleteExpense(_ expense: Expense) async {
        guard let id = expense.id else { return }
        do {
            try await deleteExpenseUseCase.execute(id: id)
            await loadExpenses()
            FeedbackManager.shared.show(.success, title: "Gasto eliminado", message: "\(expense.name) se ha borrado correctamente")
        } catch {
            state = .error(.deletionFailed(error.localizedDescription))
            FeedbackManager.shared.show(.error, title: "Error al borrar", message: error.localizedDescription)
        }
    }
    
    func loadExpenses() async {
        // Refresh income
        self.income = UserDataManager.shared.userDocument?.income ?? 0
        
        state = .loading
        currentPage = 0
        hasMorePages = true
        
        do {
            // Paginated Load (First Page)
            let result = try await getExpensesUseCase.executePaginated(page: 0)
            self.allExpenses = result.expenses
            self.hasMorePages = result.hasMore
            
            applyFilters()
        } catch {
            state = .error(.dataLoadingFailed(error.localizedDescription))
        }
    }
    
    func loadMore() async {
        guard hasMorePages, !isLoadingMore else { return }
        isLoadingMore = true
        
        do {
            currentPage += 1
            let result = try await getExpensesUseCase.executePaginated(page: currentPage)
            
            self.allExpenses.append(contentsOf: result.expenses)
            self.hasMorePages = result.hasMore
            
            applyFilters() // Re-apply filters to new full set
        } catch {
            // Silently fail or show toast? For infinite scroll, usually silent or small indicator
            print("Error loading more: \(error)")
            currentPage -= 1 // Revert page logic
        }
        
        isLoadingMore = false
    }
    
    func refresh() async {
        // Pull-to-refresh should try network first
        do {
            let expenses = try await getExpensesUseCase.execute(filter: nil, policy: .networkFirst)
            self.allExpenses = expenses
            applyFilters()
        } catch {
            // Even with networkFirst, repo falls back to cache. 
            // If we get here, both failed or critical error.
            state = .error(.networkError(error.localizedDescription))
        }
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
