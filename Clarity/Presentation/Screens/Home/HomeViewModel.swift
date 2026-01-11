// HomeViewModel.swift
// ViewModel for the main expense list/dashboard

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    
    enum ViewState {
        case idle
        case loading
        case loaded([Expense])
        case error(String)
        case empty
    }
    
    // Output
    @Published private(set) var state: ViewState = .idle
    @Published var selectedFilter: ExpenseFilter = ExpenseFilter() // Default filter
    @Published var searchText: String = ""
    
    // Internal
    private let getExpensesUseCase: GetExpensesUseCase
    private let deleteExpenseUseCase: DeleteExpenseUseCase
    private var allExpenses: [Expense] = []
    
    // User Data (Pragmatic approach: access singleton or inject wrapper. 
    // Ideally this would be another UseCase: GetUserProfileUseCase)
    @Published var income: Double = 0
    
    init(
        getExpensesUseCase: GetExpensesUseCase,
        deleteExpenseUseCase: DeleteExpenseUseCase
    ) {
        self.getExpensesUseCase = getExpensesUseCase
        self.deleteExpenseUseCase = deleteExpenseUseCase
        
        // Load income - temporary direct access to keep parity
        self.income = UserDataManager.shared.userDocument?.income ?? 0
    }
    
    // MARK: - Intents
    
    func deleteExpense(_ expense: Expense) async {
        guard let id = expense.id else { return }
        do {
            try await deleteExpenseUseCase.execute(id: id)
            // Refresh
            await loadExpenses()
        } catch {
            state = .error("Error al eliminar: \(error.localizedDescription)")
        }
    }
    
    func loadExpenses() async {
        self.income = UserDataManager.shared.userDocument?.income ?? 0
        state = .loading
        do {
            // Retrieve all (Repository handles sync/cache)
            let expenses = try await getExpensesUseCase.execute(filter: nil)
            self.allExpenses = expenses
            
            // Apply current filters
            applyFilters()
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func updateFilter(_ filter: ExpenseFilter) {
        self.selectedFilter = filter
        applyFilters()
    }
    
    func updateSearch(_ text: String) {
        self.searchText = text
        applyFilters()
    }
    
    // MARK: - Logic
    
    private func applyFilters() {
        var result = allExpenses
        
        // 1. Domain Filter
        result = selectedFilter.apply(to: result)
        
        // 2. Search Text (Presentation Logic, or could be in Domain Filter too)
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                ($0.subcategory?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        if result.isEmpty {
            state = .empty
        } else {
            state = .loaded(result)
        }
    }
}
