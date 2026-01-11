// DeleteExpenseUseCase.swift
// Domain logic for deleting expenses

import Foundation

struct DeleteExpenseUseCase {
    private let repository: ExpenseRepositoryProtocol
    
    init(repository: ExpenseRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(id: String) async throws {
        try await repository.deleteExpense(id: id)
    }
}
