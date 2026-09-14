// CierreDeMesTests.swift
// Cuándo se celebra haber cerrado el mes dentro del presupuesto.

import Foundation
import Testing
@testable import Clarity

@Suite("CierreDeMes")
@MainActor
struct CierreDeMesTests {

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    private func dia(_ d: Int) -> Date {
        utc.date(from: DateComponents(year: 2026, month: 9, day: d, hour: 12))!
    }

    @Test("dentro del presupuesto en la primera semana: se celebra lo que sobró")
    func dentroDelPresupuesto() {
        let sobrante = CierreDeMes.sobrante(hoy: dia(3), totalAnterior: 1800, presupuestoAnterior: 2455,
                                            yaCelebrado: false, calendar: utc)
        #expect(sobrante == 655)
    }

    @Test("justo en el presupuesto también cuenta")
    func justoEnElPresupuesto() {
        let sobrante = CierreDeMes.sobrante(hoy: dia(1), totalAnterior: 2455, presupuestoAnterior: 2455,
                                            yaCelebrado: false, calendar: utc)
        #expect(sobrante == 0)
    }

    @Test("pasada la primera semana ya no se celebra")
    func pasadaLaSemana() {
        #expect(CierreDeMes.sobrante(hoy: dia(8), totalAnterior: 1800, presupuestoAnterior: 2455,
                                     yaCelebrado: false, calendar: utc) == nil)
    }

    @Test("por encima del presupuesto no se celebra")
    func porEncima() {
        #expect(CierreDeMes.sobrante(hoy: dia(2), totalAnterior: 2600, presupuestoAnterior: 2455,
                                     yaCelebrado: false, calendar: utc) == nil)
    }

    @Test("una sola vez por mes")
    func yaCelebrado() {
        #expect(CierreDeMes.sobrante(hoy: dia(2), totalAnterior: 1800, presupuestoAnterior: 2455,
                                     yaCelebrado: true, calendar: utc) == nil)
    }

    @Test("sin presupuesto o sin gastos no hay nada que celebrar")
    func sinDatos() {
        #expect(CierreDeMes.sobrante(hoy: dia(2), totalAnterior: 1800, presupuestoAnterior: nil,
                                     yaCelebrado: false, calendar: utc) == nil)
        #expect(CierreDeMes.sobrante(hoy: dia(2), totalAnterior: 1800, presupuestoAnterior: 0,
                                     yaCelebrado: false, calendar: utc) == nil)
        #expect(CierreDeMes.sobrante(hoy: dia(2), totalAnterior: 0, presupuestoAnterior: 2455,
                                     yaCelebrado: false, calendar: utc) == nil)
    }
}
