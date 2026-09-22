// MockRecurringExpenseRepository.swift
// Doble de RecurringExpenseRepository para los tests de
// LocalRecurringExpenseManager. Mismo estilo que MockExpenseRepository: estado
// a la vista, un interruptor de fallo y contadores para saber qué se llamó.

import Foundation
@testable import Clarity

@MainActor
final class MockRecurringExpenseRepository: RecurringExpenseRepositoryProtocol {

    /// Las reglas que «hay en Firestore».
    var rules: [RecurringExpense] = []
    var shouldFail = false
    var failureError: AppError = .networkError("Mock error")

    /// Cuántas veces se han pedido las reglas: el candado diario se nota aquí.
    private(set) var fetchAllCalls = 0
    /// Reglas que el manager ha mandado actualizar (p. ej. al desactivar una expirada).
    private(set) var updated: [RecurringExpense] = []

    func fetchAll() async throws -> [RecurringExpense] {
        fetchAllCalls += 1
        if shouldFail { throw failureError }
        return rules
    }

    func update(_ expense: RecurringExpense) async throws {
        if shouldFail { throw failureError }
        updated.append(expense)
        if let index = rules.firstIndex(where: { $0.id == expense.id }) {
            rules[index] = expense
        }
    }
}
