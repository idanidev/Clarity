// HomePeriodoTests.swift
// El período de la Home (#78): cuándo es el mes de la cabecera y cuándo un tramo.

import Testing
import Foundation
@testable import Clarity

@Suite("Período de la Home")
@MainActor
struct HomePeriodoTests {

    private let cal = Calendar.current
    private var hoy: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 15))! }
    private var octubre: Date { cal.date(from: DateComponents(year: 2026, month: 10, day: 20))! }

    @Test("Sin período en la hoja, o con los días justos del mes de la cabecera, es el mes")
    func mes() {
        #expect(HomePeriodo.de(ExpenseFilter(), mes: hoy, hoy: hoy, calendar: cal) == .mes)

        // Lo que deja la barra al cambiar de mes.
        var f = ExpenseFilter()
        f.dateRange = .custom
        f.customStartDate = cal.date(from: DateComponents(year: 2026, month: 10, day: 1))!
        f.customEndDate = cal.date(from: DateComponents(year: 2026, month: 10, day: 31))!
        #expect(HomePeriodo.de(f, mes: octubre, hoy: hoy, calendar: cal) == .mes)
        #expect(HomePeriodo.de(f, mes: hoy, hoy: hoy, calendar: cal) != .mes)

        // «Este mes» mirando otro mes no es el mes de la cabecera.
        #expect(HomePeriodo.de(ExpenseFilter(), mes: octubre, hoy: hoy, calendar: cal) != .mes)
        #expect(HomePeriodo.mes.etiquetaCifra == "GASTADO ESTE MES")
        #expect(HomePeriodo.mes.tituloLista == "Gastos del mes")
        #expect(HomePeriodo.mes.nombre == nil)
    }

    @Test("«Todos» y «Este año» son un tramo con su nombre, sus días y sus textos")
    func tramo() throws {
        var todos = ExpenseFilter()
        todos.dateRange = .allTime
        let p = HomePeriodo.de(todos, mes: hoy, hoy: hoy, calendar: cal)
        #expect(!p.esMes)
        #expect(p.nombre == "Todos")
        #expect(p.etiquetaCifra == "GASTADO EN TOTAL")
        #expect(p.tituloLista == "Todos los gastos")

        var anio = ExpenseFilter()
        anio.dateRange = .thisYear
        let q = HomePeriodo.de(anio, mes: hoy, hoy: hoy, calendar: cal)
        #expect(q.etiquetaCifra == "GASTADO · ESTE AÑO")
        #expect(q.tituloLista == "Gastos · Este año")
        guard case .tramo(_, let desde, let hasta) = q else {
            Issue.record("«Este año» tendría que ser un tramo")
            return
        }
        #expect(desde.count == 10 && desde < hasta)
    }
}
