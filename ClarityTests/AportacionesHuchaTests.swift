// AportacionesHuchaTests.swift
// Lo apartado en una hucha no es gasto (2.4.2). Una usuaria apartó 367 € y la
// app se los contaba como gastados y le hacía pasarse de límites.

import Testing
import Foundation
@testable import Clarity

@Suite("Aportaciones a huchas", .serialized)
@MainActor
struct AportacionesHuchaTests {

    private let hoy = Formatters.isoString(from: Date())

    private func gasto(_ id: String, _ importe: Double, categoria: String = "Ocio", hucha: String? = nil) -> Expense {
        Expense(id: id, amount: importe, name: hucha == nil ? "Cena" : "Aportación a Viaje",
                category: categoria, date: hoy, goalId: hucha)
    }

    private func vm() -> HomeViewModel {
        let repo = MockExpenseRepository()
        return HomeViewModel(
            getExpensesUseCase: GetExpensesUseCase(repository: repo),
            deleteExpenseUseCase: DeleteExpenseUseCase(repository: repo),
            addExpenseUseCase: AddExpenseUseCase(repository: repo)
        )
    }

    @Test("una aportación se reconoce por su hucha")
    func reconocida() {
        #expect(gasto("a", 367, hucha: "viaje").esAhorro)
        #expect(!gasto("b", 20).esAhorro)
        #expect(!Expense(id: "c", amount: 5, name: "x", category: "Ocio", date: hoy, goalId: "").esAhorro)
    }

    @Test("no suma en el gastado del mes, pero sí resta de lo libre")
    func gastadoYLibre() {
        let m = vm()
        let cal = Calendar.current
        m.currentMonthlyBudget = MonthlyBudget(userId: "u", year: cal.component(.year, from: Date()),
                                               month: cal.component(.month, from: Date()),
                                               income: 1000, savingsAllocated: 367)
        m.currentMonthExpenses = [gasto("g", 100), gasto("a", 367, categoria: "Ahorros", hucha: "viaje")]
        #expect(m.resumen.total == 100)
        // Antes: 1000 − (100 + 367). Ahora igual, pero lo apartado no es gasto.
        #expect(m.resumen.libres == 533)
        #expect(m.gruposDelMes.map(\.name).contains(where: { $0.hasPrefix("Ahorro") }) == false)
    }

    @Test("una aportación en la categoría de un límite no la hace pasarse")
    func noCuentaEnLimites() {
        let r = HomeResumen.build(
            gastos: [gasto("g", 50)].filter { !$0.esAhorro },
            gastosMesAnterior: [], metas: [], recurrentes: [], presupuesto: 1000,
            primerGasto: nil, apartado: 367)
        #expect(r.total == 50)
        #expect(r.libres == 583)
    }

    @Test("en la lista va aparte: ni en las categorías ni en el total filtrado")
    func listaAparte() {
        let m = vm()
        m.allExpenses = [gasto("g", 100), gasto("a", 367, hucha: "viaje")]
        m.selectedFilter = ExpenseFilter(dateRange: .thisMonth)
        #expect(m.aportacionesFiltradas.map(\.id) == ["a"])
        #expect(m.filteredExpenses.map(\.id) == ["g"])
        #expect(m.totalFilteredAmount == 100)
    }

    @Test("el resumen del domingo no cuenta lo apartado")
    func resumenSemanal() {
        let aviso = Date().addingTimeInterval(3600)
        let sin = ResumenSemanal.cifras(de: [gasto("g", 30)], aviso: aviso, calendar: .current)
        let con = ResumenSemanal.cifras(de: [gasto("g", 30), gasto("a", 367, hucha: "viaje")],
                                        aviso: aviso, calendar: .current)
        #expect(con == sin)
    }
}
