// GastoDeFueraTests.swift
// Un cargo recurrente creado fuera de la Home tiene que salir en la lista
// general y en el historial de la regla sin recargar nada (fallo de la 2.4.1:
// no salía en ninguna de las dos hasta reabrir la app).

import Testing
import Foundation
@testable import Clarity

@Suite("Gasto guardado fuera de la Home", .serialized)
@MainActor
struct GastoDeFueraTests {

    private func vm() -> HomeViewModel {
        let repo = MockExpenseRepository()
        return HomeViewModel(
            getExpensesUseCase: GetExpensesUseCase(repository: repo),
            deleteExpenseUseCase: DeleteExpenseUseCase(repository: repo),
            addExpenseUseCase: AddExpenseUseCase(repository: repo)
        )
    }

    private func gasto(_ id: String, _ fecha: String) -> Expense {
        Expense(id: id, amount: 9.99, name: "Spotify", category: "Suscripciones", date: fecha)
    }

    /// Fecha de este mes o de hace `meses`, con el día indicado.
    private func fecha(dia: Int, meses: Int = 0) -> String {
        let cal = Calendar.current
        let base = cal.date(byAdding: .month, value: -meses, to: Date())!
        var c = cal.dateComponents([.year, .month], from: base)
        c.day = dia
        return Formatters.localDayString(from: cal.date(from: c)!)
    }

    @Test("entra en la lista general, en su sitio por fecha")
    func ordenPorFecha() {
        let m = vm()
        m.allExpenses = [gasto("c", fecha(dia: 3, meses: 2)), gasto("a", fecha(dia: 1, meses: 2))]
        m.incorporarGastoDeFuera(gasto("b", fecha(dia: 2, meses: 2)))
        #expect(m.allExpenses.map(\.id) == ["c", "b", "a"])
    }

    @Test("si ya estaba, no se duplica (el cargo del mes reescribe el mismo documento)")
    func sinDuplicar() {
        let m = vm()
        m.allExpenses = [gasto("r1", fecha(dia: 5, meses: 2))]
        m.incorporarGastoDeFuera(gasto("r1", fecha(dia: 5, meses: 2)))
        #expect(m.allExpenses.count == 1)
    }

    @Test("cuenta en el mes que se está viendo, y no en otro")
    func mesVisto() {
        let m = vm()
        m.incorporarGastoDeFuera(gasto("hoy", fecha(dia: 1)))
        m.incorporarGastoDeFuera(gasto("viejo", fecha(dia: 1, meses: 3)))
        #expect(m.currentMonthExpenses.map(\.id) == ["hoy"])
        #expect(Set(m.allExpenses.map(\.id)) == ["hoy", "viejo"])
    }

    @Test("la copia en memoria (historial de la regla) lo recibe una sola vez")
    func copiaEnMemoria() {
        let manager = UserDataManager(service: MockUserDataStore(), userIdProvider: { "test-uid" })
        manager.anadirGastoAlCache(gasto("r1", fecha(dia: 5)))
        manager.anadirGastoAlCache(gasto("r1", fecha(dia: 5)))
        manager.anadirGastoAlCache(gasto("r2", fecha(dia: 6)))
        #expect(manager.expenses.map(\.id) == ["r2", "r1"])
    }
}
