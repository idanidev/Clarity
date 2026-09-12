// HomeResumenTests.swift
// La resolución de huecos de la Home: ninguno se queda vacío (#65).

import Testing
import Foundation
@testable import Clarity

@MainActor
struct HomeResumenTests {

    private let cal = Calendar.current
    /// 10 de abril de 2026, viernes.
    private var hoy: Date { cal.date(from: DateComponents(year: 2026, month: 4, day: 10))! }

    private func gasto(_ amount: Double, _ cat: String, dia: Int, mes: Int = 4, name: String = "x",
                       debtors: [Debtor]? = nil) -> Expense {
        Expense(id: UUID().uuidString, amount: amount, name: name, category: cat,
                date: String(format: "2026-%02d-%02d", mes, dia), isShared: debtors != nil, debtors: debtors)
    }

    @Test("Ritmo: media diaria y previsión salen del día del mes")
    func ritmo() {
        let r = HomeResumen.build(gastos: [gasto(100, "Ocio", dia: 2), gasto(150, "Ocio", dia: 9)],
                                  gastosMesAnterior: [], metas: [], recurrentes: [],
                                  presupuesto: nil, primerGasto: nil, hoy: hoy, calendar: cal)
        #expect(r.total == 250)
        #expect(abs(r.ritmo.mediaDiaria - 25) < 0.001)
        #expect(abs(r.ritmo.prevision - 750) < 0.001)
        #expect(r.ritmo.diasRestantes == 20)
    }

    @Test("Sin nada configurado, los cuatro huecos siguen llenos")
    func huecosNuncaVacios() {
        let gastos = [
            gasto(20, "Alimentación", dia: 1), gasto(30, "Ocio", dia: 2),
            gasto(46, "Ocio", dia: 4, name: "Cena"), gasto(12, "Transporte", dia: 8), gasto(9, "Alimentación", dia: 9),
        ]
        let r = HomeResumen.build(gastos: gastos, gastosMesAnterior: [], metas: [], recurrentes: [],
                                  presupuesto: nil, primerGasto: nil, hoy: hoy, calendar: cal)
        #expect(r.slots[HomeResumen.Slot.a]?.clase == "reparto")
        #expect(r.slots[HomeResumen.Slot.b]?.clase == "diaCaro")
        #expect(r.slots[HomeResumen.Slot.c]?.clase == "semana")
        #expect(r.slots[HomeResumen.Slot.e]?.clase == "semanaASemana")
        if case .diaCaro(let d) = r.slots[HomeResumen.Slot.b]! { #expect(d.importe == 46); #expect(d.concepto == "Cena") }
    }

    @Test("Con todo configurado, cada hueco enseña su primera opción")
    func huecosCompletos() {
        let metas = [
            Goal(name: "Ocio", type: .spendingLimit, targetAmount: 300, linkedCategoryId: "Ocio"),
            Goal(name: "Moto", type: .savingsTarget, targetAmount: 5000, currentAmount: 200),
        ]
        let cargo = RecurringExpense(id: "r1", amount: 12.99, name: "Netflix", category: "Ocio", subcategory: nil,
                                     paymentMethod: "Tarjeta", frequency: .monthly, dayOfMonth: 15, billingMonth: 0,
                                     active: true, icon: nil, startDate: nil, endDate: nil, lastCreated: nil, createdAt: nil, updatedAt: nil)
        let gastos = [gasto(209.54, "Ocio", dia: 3, debtors: [Debtor(name: "Marcos", amount: 40)])]
        let r = HomeResumen.build(gastos: gastos, gastosMesAnterior: [gasto(260, "Ocio", dia: 5, mes: 3)],
                                  metas: metas, recurrentes: [cargo], presupuesto: 2080, primerGasto: nil,
                                  hoy: hoy, calendar: cal)
        #expect(r.slots[HomeResumen.Slot.a]?.clase == "limites")
        #expect(r.slots[HomeResumen.Slot.b]?.clase == "cargos")
        #expect(r.slots[HomeResumen.Slot.c]?.clase == "teDeben")
        #expect(r.slots[HomeResumen.Slot.e]?.clase == "hucha")
        #expect(abs((r.libres ?? 0) - 1870.46) < 0.01)
        if case .limites(let l) = r.slots[HomeResumen.Slot.a]! { #expect(l[0].restante > 90 && l[0].restante < 91) }
        if case .teDeben(_, let total) = r.slots[HomeResumen.Slot.c]! { #expect(total == 40) }
    }

    @Test("Un mismo contenido no sale en dos huecos")
    func sinDuplicados() {
        let metas = [Goal(name: "Moto", type: .savingsTarget, targetAmount: 5000, currentAmount: 200)]
        let r = HomeResumen.build(gastos: [gasto(10, "Ocio", dia: 1)], gastosMesAnterior: [], metas: metas,
                                  recurrentes: [], presupuesto: nil, primerGasto: nil, hoy: hoy, calendar: cal)
        let clases = r.slots.values.map(\.clase)
        #expect(Set(clases).count == clases.count)
        #expect(clases.contains("hucha"))
    }

    @Test("Un límite superado se marca como tal")
    func limiteSuperado() {
        let metas = [Goal(name: "Coche-Moto", type: .spendingLimit, targetAmount: 400, linkedCategoryId: "Coche-Moto")]
        let r = HomeResumen.build(gastos: [gasto(501, "Coche-Moto", dia: 10)], gastosMesAnterior: [], metas: metas,
                                  recurrentes: [], presupuesto: nil, primerGasto: nil, hoy: hoy, calendar: cal)
        guard case .limites(let l) = r.slots[HomeResumen.Slot.a]! else { Issue.record("sin límites"); return }
        #expect(l[0].superado)
        #expect(l[0].progreso == 1)
        #expect(abs(l[0].restante + 101) < 0.001)
    }

    @Test("Los cargos pasados de este mes no cuentan como próximos")
    func cargosSoloFuturos() {
        func regla(_ n: String, dia: Int) -> RecurringExpense {
            RecurringExpense(id: n, amount: 10, name: n, category: "Ocio", subcategory: nil, paymentMethod: "Tarjeta",
                             frequency: .monthly, dayOfMonth: dia, billingMonth: 0, active: true, icon: nil,
                             startDate: nil, endDate: nil, lastCreated: nil, createdAt: nil, updatedAt: nil)
        }
        let r = HomeResumen.build(gastos: [gasto(1, "Ocio", dia: 1)], gastosMesAnterior: [], metas: [],
                                  recurrentes: [regla("pasado", dia: 3), regla("hoy", dia: 10), regla("luego", dia: 20)],
                                  presupuesto: nil, primerGasto: nil, hoy: hoy, calendar: cal)
        guard case .cargos(let c, let total) = r.slots[HomeResumen.Slot.b]! else { Issue.record("sin cargos"); return }
        #expect(c.map(\.nombre) == ["hoy", "luego"])
        #expect(total == 20)
    }

    @Test("Comparativa: menos que el mes anterior sale en negativo")
    func comparativa() {
        let r = HomeResumen.build(gastos: [gasto(759.68, "Ocio", dia: 1)],
                                  gastosMesAnterior: [gasto(863, "Ocio", dia: 1, mes: 3)], metas: [],
                                  recurrentes: [], presupuesto: nil, primerGasto: nil, hoy: hoy, calendar: cal)
        #expect(r.comparativa?.porcentaje == -12)
    }
}
