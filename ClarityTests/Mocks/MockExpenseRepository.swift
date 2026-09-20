// MockExpenseRepository.swift
import Foundation
@testable import Clarity

final class MockExpenseRepository: ExpenseRepositoryProtocol, @unchecked Sendable {

    var expenses: [Expense] = []
    var shouldFail = false
    var failureError: AppError = .unknown("Mock error")

    func getExpenses(policy: CachePolicy) async throws -> [Expense] {
        if shouldFail { throw failureError }
        return expenses
    }

    func getExpenses() async throws -> [Expense] {
        if shouldFail { throw failureError }
        return expenses
    }

    func getExpenses(from startDate: String, to endDate: String) async throws -> [Expense] {
        if shouldFail { throw failureError }
        return expenses.filter { $0.date >= startDate && $0.date <= endDate }
    }

    /// Lo que se pidió guardar, TAL CUAL llegó (abajo el id se sustituye por un
    /// UUID, como haría un alta normal). Para quien necesita comprobar el id
    /// que eligió el llamante: los recurrentes lo mandan determinista.
    var addedExpenses: [Expense] = []
    /// Solo falla el alta; las lecturas siguen funcionando.
    var shouldFailAdd = false

    func addExpense(_ expense: Expense) async throws -> String {
        if shouldFail || shouldFailAdd { throw failureError }
        addedExpenses.append(expense)
        let id = UUID().uuidString
        var newExpense = expense
        newExpense.id = id
        expenses.append(newExpense)
        return id
    }

    func deleteExpense(id: String) async throws {
        if shouldFail { throw failureError }
        expenses.removeAll { $0.id == id }
    }

    func updateExpense(_ expense: Expense) async throws {
        if shouldFail { throw failureError }
        if let index = expenses.firstIndex(where: { $0.id == expense.id }) {
            expenses[index] = expense
        }
    }

    func getExpensesPaginated(page: Int, filter: ExpenseFilter?) async throws -> PageResult {
        if shouldFail { throw failureError }
        return PageResult(expenses: expenses, hasMore: false)
    }
}
