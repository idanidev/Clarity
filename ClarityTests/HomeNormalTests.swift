// HomeNormalTests.swift
// La costumbre del usuario a partir de sus últimos meses (#65).

import Testing
import Foundation
@testable import Clarity

@MainActor
struct HomeNormalTests {

    private let cal = Calendar.current
    /// Abril de 2026: el mes que se enseña. El tramo son los anteriores.
    private var abril: Date { cal.date(from: DateComponents(year: 2026, month: 4, day: 10))! }

    private func gasto(_ amount: Double, _ cat: String, mes: Int, dia: Int, recurrente: Bool = false) -> Expense {
        Expense(id: UUID().uuidString, amount: amount, name: "g\(amount)-\(mes)-\(dia)", category: cat,
                date: String(format: "2026-%02d-%02d", mes, dia), recurringId: recurrente ? "regla" : nil)
    }

    @Test("Con menos de dos meses de gastos no hay normal")
    func minimoDeMeses() {
        #expect(HomeNormal.build(historico: [gasto(10, "Ocio", mes: 3, dia: 1)], mes: abril, calendar: cal) == nil)
        #expect(HomeNormal.build(historico: [], mes: abril, calendar: cal) == nil)
    }

    @Test("Solo cuentan los meses de la ventana, y el mes que se enseña queda fuera")
    func ventana() {
        let historico = [
            gasto(10, "Ocio", mes: 1, dia: 5), gasto(20, "Ocio", mes: 2, dia: 5),
            gasto(30, "Ocio", mes: 3, dia: 5), gasto(999, "Ocio", mes: 4, dia: 5),
        ]
        let n = HomeNormal.build(historico: historico, mes: abril, meses: 2, calendar: cal)
        #expect(n?.meses == 2)
        #expect(n?.totalesPorMes.keys.sorted() == ["2026-02", "2026-03"])
        #expect(n?.totalMensual == 25)
    }

    @Test("Mediana por categoría: los meses sin ella cuentan como 0 y los recurrentes no entran")
    func medianaPorCategoria() throws {
        let historico = [
            gasto(100, "Ocio", mes: 1, dia: 3), gasto(300, "Ocio", mes: 2, dia: 3), gasto(200, "Ocio", mes: 3, dia: 3),
            gasto(50, "Súper", mes: 1, dia: 4),
            gasto(600, "Vivienda", mes: 1, dia: 1, recurrente: true),
            gasto(600, "Vivienda", mes: 2, dia: 1, recurrente: true),
            gasto(600, "Vivienda", mes: 3, dia: 1, recurrente: true),
        ]
        let n = try #require(HomeNormal.build(historico: historico, mes: abril, calendar: cal))
        #expect(n.meses == 3)
        #expect(n.porCategoria["Ocio"] == 200)
        #expect(n.porCategoria["Súper"] == 0)
        #expect(n.porCategoria["Vivienda"] == nil)
        #expect(n.mesesPorCategoria["Ocio"] == 3)
        #expect(n.mesesPorCategoria["Súper"] == 1)
        // El total del mes sí lo cuenta todo: 750, 900 y 800.
        #expect(n.totalMensual == 800)
    }

    @Test("Umbral hormiga: el cuartil bajo de los importes, entre 3 y 10 €")
    func umbralHormiga() {
        let pequenos = [1.0, 1, 1, 1, 50, 60, 70, 80].enumerated().map { i, a in gasto(a, "Ocio", mes: 1 + i % 2, dia: 2 + i) }
        #expect(HomeNormal.build(historico: pequenos, mes: abril, calendar: cal)?.umbralHormiga == 3)
        let grandes = (0..<8).map { i in gasto(100, "Ocio", mes: 1 + i % 2, dia: 2 + i) }
        #expect(HomeNormal.build(historico: grandes, mes: abril, calendar: cal)?.umbralHormiga == 10)
        let medios = [4.0, 4, 6, 6, 8, 8, 9, 9].enumerated().map { i, a in gasto(a, "Ocio", mes: 1 + i % 2, dia: 2 + i) }
        #expect(HomeNormal.build(historico: medios, mes: abril, calendar: cal)?.umbralHormiga == 6)
    }

    @Test("Ahorro medio: lo que quedó sin gastar de los ingresos, de media, solo en meses con presupuesto")
    func ahorroMedio() throws {
        let historico = [gasto(750, "Ocio", mes: 1, dia: 3), gasto(900, "Ocio", mes: 2, dia: 3), gasto(100, "Ocio", mes: 3, dia: 3)]
        let n = try #require(HomeNormal.build(historico: historico, mes: abril,
                                              presupuestos: ["2026-01": 1000, "2026-02": 1000], calendar: cal))
        #expect(abs((n.ahorroMedio ?? 0) - 0.175) < 0.0001)
        #expect(HomeNormal.build(historico: historico, mes: abril, calendar: cal)?.ahorroMedio == nil)
    }

    @Test("Día de la semana: lo gastado entre las veces que cae ese día en el tramo")
    func porDiaSemana() throws {
        // Enero y febrero de 2026 tienen 9 viernes entre los dos: 2, 9, 16, 23, 30 y 6, 13, 20, 27.
        let viernes = [(1, 2), (1, 9), (1, 16), (1, 23), (1, 30), (2, 6), (2, 13), (2, 20), (2, 27)]
        let historico = viernes.map { gasto(10, "Ocio", mes: $0.0, dia: $0.1) }
        let marzo = cal.date(from: DateComponents(year: 2026, month: 3, day: 1))!
        let n = try #require(HomeNormal.build(historico: historico, mes: marzo, meses: 2, calendar: cal))
        #expect(abs((n.porDiaSemana[6] ?? 0) - 10) < 0.0001)
        #expect(n.porDiaSemana[2] == nil)
        #expect(n.diasConGasto.count == 9)
    }
}
