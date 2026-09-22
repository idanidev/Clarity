// PaymentMethodsFromCacheTests.swift
// Los métodos de pago del picker salen de los gastos que ya están en SwiftData,
// no de una consulta a Firestore en cada `loadUserData()`.

import Foundation
import Testing
@testable import Clarity

@Suite("Métodos de pago desde la caché")
@MainActor
struct PaymentMethodsFromCacheTests {

    private func gasto(_ id: String, metodo: String) -> Expense {
        Expense(id: id, amount: 10, name: id, category: "Ocio", date: "2026-09-10", paymentMethod: metodo)
    }

    @Test("Se cosechan los métodos de todos los gastos, sin repetir")
    func cosecha() {
        let gastos = [
            gasto("a", metodo: "Tarjeta"),
            gasto("b", metodo: "PayPal"),
            gasto("c", metodo: "Tarjeta"),
            gasto("d", metodo: "Apple Pay"),
        ]
        #expect(UserDataManager.metodosDePago(en: gastos) == ["Tarjeta", "PayPal", "Apple Pay"])
        #expect(UserDataManager.metodosDePago(en: []).isEmpty)
    }

    @Test("Con los de siempre, el picker queda como antes: unión ordenada")
    func unionConLosPredeterminados() {
        // Lo que hace `loadUserData` con el resultado, venga de donde venga.
        var todos = Set(PaymentMethod.pickerOptions.map(\.rawValue))
        todos.formUnion(UserDataManager.metodosDePago(en: [gasto("a", metodo: "PayPal"), gasto("b", metodo: "Bizum")]))

        #expect(todos.sorted() == ["Bizum", "Efectivo", "Otro", "PayPal", "Tarjeta", "Transferencia"])
    }
}
