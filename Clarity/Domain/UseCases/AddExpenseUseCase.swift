// AddExpenseUseCase.swift
// Domain logic for adding expenses

import Foundation

struct AddExpenseUseCase {
    private let repository: ExpenseRepositoryProtocol
    
    init(repository: ExpenseRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(_ expense: Expense) async throws {
        // Business Rules
        guard expense.amount > 0 else {
            throw DomainError.invalidAmount
        }
        
        try await repository.addExpense(expense)
    }
}

enum DomainError: LocalizedError {
    case invalidAmount
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount: return "El monto debe ser mayor a 0"
        }
    }
}
