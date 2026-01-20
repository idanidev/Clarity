// MockExpenseRepository.swift
import Foundation
@testable import Clarity

final class MockExpenseRepository: ExpenseRepositoryProtocol, @unchecked Sendable {
    
    // In-memory store
    var expenses: [Expense] = []
    
    // Configurable behaviors
    var shouldFail = false
    var failureError: AppError = .unknown("Mock error")
    
    // MARK: - Protocol Implementation
    
    func getExpenses(policy: CachePolicy) async throws -> [Expense] {
        if shouldFail {
            throw failureError
        }
        return expenses
    }
    
    func getExpenses() async throws -> [Expense] {
        if shouldFail {
            throw failureError
        }
        return expenses
    }
    
    func addExpense(_ expense: Expense) async throws -> String {
        if shouldFail {
            throw failureError
        }
        // Simulate generating an ID
        let id = UUID().uuidString
        var newExpense = expense
        // Attempt to modify ID if struct is mutable, but Expense is likely let properties?
        // Assuming Expense is a struct, we can't 'mutate' it in place easily if properties are let.
        // But typically we return the ID.
        expenses.append(newExpense)
        return id
    }
    
    func deleteExpense(id: String) async throws {
        if shouldFail {
            throw failureError
        }
        expenses.removeAll { $0.id == id }
    }
    
    func updateExpense(_ expense: Expense) async throws {
        if shouldFail {
            throw failureError
        }
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
        }
    }
}
