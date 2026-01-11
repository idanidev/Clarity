// ExpenseRepositoryProtocol.swift
// Domain layer contract for expense operations

import Foundation

protocol ExpenseRepositoryProtocol: Sendable {
    func getExpenses() async throws -> [Expense]
    func addExpense(_ expense: Expense) async throws
    func deleteExpense(id: String) async throws
    func updateExpense(_ expense: Expense) async throws
}
