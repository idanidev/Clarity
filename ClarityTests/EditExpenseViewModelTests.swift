// EditExpenseViewModelTests.swift
// Editar un gasto no toca lo que el formulario no enseña.

import Testing
import Foundation
@testable import Clarity

@MainActor
struct EditExpenseViewModelTests {

    private func gasto(paymentMethod: String = "Tarjeta") -> Expense {
        Expense(id: "g1", amount: 40, name: "Zapatillas", category: "Ropa", subcategory: "Calzado",
                date: "2026-09-10", paymentMethod: paymentMethod, isDeductible: true,
                isRecurring: true, recurringId: "regla-1", goalId: "hucha-1")
    }

    @Test("Guardar conserva la hucha, el recurrente y el resto de campos ocultos")
    func conservaCamposOcultos() async {
        let repo = MockExpenseRepository()
        repo.expenses = [gasto()]
        let vm = EditExpenseViewModel(expense: gasto(), repository: repo)

        vm.amount = 55
        await vm.save()

        let guardado = repo.expenses.first
        #expect(guardado?.amount == 55)
        #expect(guardado?.goalId == "hucha-1")
        #expect(guardado?.recurringId == "regla-1")
        #expect(guardado?.isRecurring == true)
        #expect(guardado?.isDeductible == true)
    }

    @Test("Un método de pago fuera de la lista se conserva si no se cambia")
    func metodoDePagoDesconocido() async {
        let repo = MockExpenseRepository()
        repo.expenses = [gasto(paymentMethod: "Cheque regalo")]
        let vm = EditExpenseViewModel(expense: gasto(paymentMethod: "Cheque regalo"), repository: repo)

        vm.amount = 12
        await vm.save()
        #expect(repo.expenses.first?.paymentMethod == "Cheque regalo")

        vm.paymentMethod = .efectivo
        await vm.save()
        #expect(repo.expenses.first?.paymentMethod == PaymentMethod.efectivo.rawValue)
    }
}
