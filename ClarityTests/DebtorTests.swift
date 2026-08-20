// DebtorTests.swift
// Reparto y totales del modo regalo (#37).

import Testing
import Foundation
@testable import Clarity

@Suite("Debtor")
struct DebtorTests {

    private func people(_ names: String...) -> [Debtor] {
        names.map { Debtor(name: $0, amount: 0) }
    }

    @Test("reparto a partes iguales incluyéndome")
    func splitEvenlyIncludingMe() {
        // 40 € entre 3 deudores + yo = 10 € cada uno.
        let result = people("Ana", "Luis", "Marta").splitEvenly(total: 40)
        #expect(result.map(\.amount) == [10, 10, 10])
    }

    @Test("reparto a partes iguales sin contarme")
    func splitEvenlyExcludingMe() {
        // Un regalo que adelanto yo pero pagan ellos: 30 € entre 3 = 10 cada uno.
        let result = people("Ana", "Luis", "Marta").splitEvenly(total: 30, includingMe: false)
        #expect(result.reduce(0) { $0 + $1.amount } == 30)
    }

    @Test("los céntimos que no cuadran no inflan el total")
    func splitEvenlyHandlesRounding() {
        // 10 € entre 2 deudores + yo → 3,33 cada uno; lo que me deben nunca
        // puede pasar de 10 − mi parte.
        let result = people("Ana", "Luis").splitEvenly(total: 10)
        let owed = result.reduce(0) { $0 + $1.amount }
        #expect(owed <= 10 - 3.33 + 0.001)
        #expect(owed > 6.6)
    }

    @Test("pendiente y cobrado se separan")
    func pendingAndPaidTotals() {
        let debtors = [
            Debtor(name: "Ana", amount: 10, isPaid: true),
            Debtor(name: "Luis", amount: 15),
        ]
        #expect(debtors.paidAmount == 10)
        #expect(debtors.pendingAmount == 15)
        #expect(debtors.hasPending)
    }

    @Test("sin deudores pendientes no hay deuda")
    func noPendingWhenAllPaid() {
        let debtors = [Debtor(name: "Ana", amount: 10, isPaid: true)]
        #expect(!debtors.hasPending)
        #expect(debtors.pendingAmount == 0)
    }

    @Test("un gasto normal no arrastra deuda")
    func plainExpenseHasNoDebt() {
        let expense = Expense(amount: 20, name: "Café", category: "Ocio", date: "2026-08-20")
        #expect(!expense.hasPendingDebt)
        #expect(expense.pendingDebtAmount == 0)
        #expect(expense.netAmount == 20)
    }

    @Test("el coste neto descuenta lo que te devuelven")
    func netAmountSubtractsDebtors() {
        let expense = Expense(
            amount: 60,
            name: "Regalo de Marta",
            category: "Ocio",
            date: "2026-08-20",
            isShared: true,
            debtors: [
                Debtor(name: "Ana", amount: 20),
                Debtor(name: "Luis", amount: 20),
            ]
        )
        #expect(expense.netAmount == 20)
        #expect(expense.pendingDebtAmount == 40)
        #expect(expense.hasPendingDebt)
    }

    @Test("marcar pagado no cambia el coste neto, solo lo pendiente")
    func settlingKeepsNetAmount() {
        let expense = Expense(
            amount: 60,
            name: "Cena",
            category: "Ocio",
            date: "2026-08-20",
            isShared: true,
            debtors: [
                Debtor(name: "Ana", amount: 20, isPaid: true),
                Debtor(name: "Luis", amount: 20),
            ]
        )
        #expect(expense.netAmount == 20)
        #expect(expense.pendingDebtAmount == 20)
    }
}
