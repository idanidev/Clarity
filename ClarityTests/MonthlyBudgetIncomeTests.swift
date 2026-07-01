// MonthlyBudgetIncomeTests.swift
// Regresión de la feature "ingresos extra vinculados a nómina":
// totalIncome = nómina + extras, y compat con docs sin el campo.
// (No se testea decode de MonthlyBudget completo: @DocumentID solo
// decodifica con Firestore.Decoder, no con JSONDecoder.)

import Testing
import Foundation
@testable import Clarity

@Suite("MonthlyBudget ingresos extra", .serialized)
@MainActor
struct MonthlyBudgetIncomeTests {

    private func makeBudget(income: Double, extras: [IncomeEntry] = []) -> MonthlyBudget {
        MonthlyBudget(userId: "u1", year: 2026, month: 6, income: income, extraIncomes: extras)
    }

    @Test("totalIncome = nómina + extras")
    func totalIncomeSumsExtras() {
        let extras = [
            IncomeEntry(name: "Bonus", amount: 300, date: "2026-06-10"),
            IncomeEntry(name: "Venta", amount: 120.5, date: "2026-06-11"),
        ]
        let budget = makeBudget(income: 2000, extras: extras)
        #expect(budget.extraIncomeTotal == 420.5)
        #expect(budget.totalIncome == 2420.5)
    }

    @Test("sin extras: totalIncome == nómina (compat docs antiguos)")
    func totalIncomeWithoutExtras() {
        let budget = makeBudget(income: 1800)
        #expect(budget.extraIncomes.isEmpty)
        #expect(budget.extraIncomeTotal == 0)
        #expect(budget.totalIncome == 1800)
    }

    @Test("IncomeEntry: round-trip Codable estable")
    func incomeEntryRoundTrip() throws {
        let entry = IncomeEntry(id: "e1", name: "Freelance", amount: 250, date: "2026-06-05")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(IncomeEntry.self, from: data)
        #expect(decoded.id == "e1")
        #expect(decoded.name == "Freelance")
        #expect(decoded.amount == 250)
        #expect(decoded.date == "2026-06-05")
    }

    @Test("IncomeEntry: ids únicos por defecto")
    func incomeEntryUniqueIds() {
        let a = IncomeEntry(name: "A", amount: 1, date: "2026-06-01")
        let b = IncomeEntry(name: "B", amount: 2, date: "2026-06-01")
        #expect(a.id != b.id)
    }
}
