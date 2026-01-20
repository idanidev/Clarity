// GetExpensesUseCase.swift

import Foundation

struct GetExpensesUseCase {
    private let repository: ExpenseRepositoryProtocol
    
    init(repository: ExpenseRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(filter: ExpenseFilter? = nil, policy: CachePolicy = .cacheFirst()) async throws -> [Expense] {
        let expenses = try await repository.getExpenses(policy: policy)
        
        // Apply Domain Filters if needed here, or pass to repo
        // For now, consistent with user proposal, we return all or handle filtering in VM
        if let filter = filter, filter.hasActiveFilters {
            // Re-implement or reuse helper filtering logic if it moved to Domain
             // For now return raw, VM handles filtering or we move filtering logic here
             return expenses 
        }
        
        return expenses
    }
    
    func executePaginated(page: Int) async throws -> PageResult {
        try await repository.getExpensesPaginated(page: page)
    }
}
