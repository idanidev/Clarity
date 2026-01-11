// DependencyContainer.swift
// Central Dependency Injection Container using Singleton + Lazy Factory pattern

import Foundation

@MainActor
final class DependencyContainer {
    static let shared = DependencyContainer()
    
    private init() {}
    
    // MARK: - Data Sources
    private lazy var firebaseDataSource: FirebaseExpenseDataSource = {
        FirebaseExpenseDataSource()
    }()
    
    private lazy var localDataSource: LocalExpenseDataSource = {
        LocalExpenseDataSource()
    }()
    
    // MARK: - Repositories
    // Public so Intents or other specialized non-VM classes can reuse if strictly needed
    lazy var expenseRepository: ExpenseRepositoryProtocol = {
        ExpenseRepository(
            remote: firebaseDataSource,
            local: localDataSource
        )
    }()
    
    // MARK: - Use Cases Factories
    // We recreate Use Cases intentionally as they are lightweight structs holding references
    
    func makeAddExpenseUseCase() -> AddExpenseUseCase {
        AddExpenseUseCase(repository: expenseRepository)
    }
    
    func makeGetExpensesUseCase() -> GetExpensesUseCase {
        GetExpensesUseCase(repository: expenseRepository)
    }
    
    func makeDeleteExpenseUseCase() -> DeleteExpenseUseCase {
        DeleteExpenseUseCase(repository: expenseRepository)
    }
    
    // MARK: - ViewModel Factories
    
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(
            getExpensesUseCase: makeGetExpensesUseCase(),
            deleteExpenseUseCase: makeDeleteExpenseUseCase(),
            addExpenseUseCase: makeAddExpenseUseCase()
        )
    }
}
