// ExpenseSanitizerTests.swift
// Regresión del crash "invalid number of items in section" (NSInternalInconsistencyException)
// al borrar un gasto: la List usa ForEach(id: \.stableId) y el saneador debe garantizar
// stableId único para que la colección no reviente.

import Testing
import Foundation
@testable import Clarity

@Suite("ExpenseSanitizer", .serialized)
@MainActor
struct ExpenseSanitizerTests {

    private func exp(id: String?, name: String = "Café", date: String = "2026-07-01",
                     amount: Double = 2, recurringId: String? = nil) -> Expense {
        Expense(id: id, amount: amount, name: name, category: "Ocio", date: date,
                isRecurring: recurringId != nil, recurringId: recurringId)
    }

    @Test("stableId único tras sanitizar (sin ids)")
    func dedupNilIdsByStableId() {
        // Dos gastos sin id, mismos datos → mismo stableId → uno debe caer.
        let a = exp(id: nil)
        let b = exp(id: nil)
        let result = ExpenseSanitizer.sanitize(expenses: [a, b], rules: [])
        #expect(result.count == 1)
        #expect(Set(result.map { $0.stableId }).count == result.count)
    }

    @Test("ids duplicados → una sola fila")
    func dedupDuplicateIds() {
        let a = exp(id: "rec_x_2026-07")
        let b = exp(id: "rec_x_2026-07")
        let result = ExpenseSanitizer.sanitize(expenses: [a, b], rules: [])
        #expect(result.count == 1)
    }

    @Test("gastos distintos se conservan (stableId distintos)")
    func keepsDistinct() {
        let a = exp(id: "1", name: "Café", amount: 2)
        let b = exp(id: "2", name: "Menú", amount: 12)
        let result = ExpenseSanitizer.sanitize(expenses: [a, b], rules: [])
        #expect(result.count == 2)
        #expect(Set(result.map { $0.stableId }).count == 2)
    }

    @Test("garantía general: nunca hay stableId repetido en la salida")
    func noDuplicateStableIdsInOutput() {
        let input = [
            exp(id: nil, name: "A", amount: 1),
            exp(id: nil, name: "A", amount: 1),   // dup stableId
            exp(id: "x"),
            exp(id: "x"),                          // dup id
            exp(id: "y", name: "B", amount: 3),
        ]
        let result = ExpenseSanitizer.sanitize(expenses: input, rules: [])
        #expect(Set(result.map { $0.stableId }).count == result.count)
    }
}
