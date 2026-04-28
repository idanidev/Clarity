// GetExpensesUseCase.swift

import Foundation

struct GetExpensesUseCase {
    private let repository: ExpenseRepositoryProtocol

    init(repository: ExpenseRepositoryProtocol) {
        self.repository = repository
    }

    func execute(filter: ExpenseFilter? = nil, policy: CachePolicy = .cacheFirst()) async throws -> [Expense] {
        try await repository.getExpenses(policy: policy)
    }

    func executePaginated(page: Int, filter: ExpenseFilter? = nil) async throws -> PageResult {
        try await repository.getExpensesPaginated(page: page, filter: filter)
    }
}
