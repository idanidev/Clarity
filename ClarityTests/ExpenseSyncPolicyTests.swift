// ExpenseSyncPolicyTests.swift
// Las reglas de la sincronización de gastos: qué tramo se baja, cuándo toca el
// historial entero, cuándo se purga y cuándo "Todos" sale de la caché.

import Foundation
import Testing
@testable import Clarity

@Suite("ExpenseSyncPolicy")
@MainActor
struct ExpenseSyncPolicyTests {

    private let utc = TimeZone(identifier: "UTC")!

    private func dia(_ iso: String) -> Date {
        Formatters.date(from: iso)!
    }

    private func gasto(_ id: String?, fecha: String) -> Expense {
        Expense(id: id, amount: 1, name: "x", category: "Ocio", date: fecha)
    }

    // MARK: - Ventana

    @Test("La ventana empieza el día 1 de hace dos meses y no tiene tope")
    func ventanaNormal() {
        let ventana = ExpenseSyncPolicy.ventana(para: dia("2026-09-19"), zona: utc)
        #expect(ventana.desde == "2026-07-01")
        #expect(ventana.hasta == "9999-12-31")
    }

    @Test("En enero y febrero la ventana empieza en el año anterior")
    func ventanaConCambioDeAño() {
        #expect(ExpenseSyncPolicy.ventana(para: dia("2026-01-15"), zona: utc).desde == "2025-11-01")
        #expect(ExpenseSyncPolicy.ventana(para: dia("2026-02-28"), zona: utc).desde == "2025-12-01")
        #expect(ExpenseSyncPolicy.ventana(para: dia("2026-03-01"), zona: utc).desde == "2026-01-01")
        #expect(ExpenseSyncPolicy.ventana(para: dia("2026-12-31"), zona: utc).desde == "2026-10-01")
    }

    @Test("El mes de la ventana es el de la zona horaria del dispositivo")
    func ventanaSegunZona() throws {
        // 28 de febrero a las 23:30 UTC ya es 1 de marzo en Madrid.
        let instante = dia("2026-02-28").addingTimeInterval(23.5 * 3600)
        let madrid = try #require(TimeZone(identifier: "Europe/Madrid"))
        #expect(ExpenseSyncPolicy.ventana(para: instante, zona: utc).desde == "2025-12-01")
        #expect(ExpenseSyncPolicy.ventana(para: instante, zona: madrid).desde == "2026-01-01")
    }

    @Test("La ventana contiene sus extremos y las fechas futuras")
    func ventanaContiene() {
        let ventana = ExpenseSyncPolicy.ventana(para: dia("2026-09-19"), zona: utc)
        #expect(ventana.contiene("2026-07-01"))
        #expect(ventana.contiene("2026-09-19"))
        #expect(ventana.contiene("2031-01-01"))
        #expect(!ventana.contiene("2026-06-30"))
    }

    // MARK: - Purga

    @Test("Se purga solo si la respuesta trae al menos la mitad de lo local")
    func decisionDePurga() {
        #expect(ExpenseSyncPolicy.debePurgar(remotos: 10, locales: 10))
        #expect(ExpenseSyncPolicy.debePurgar(remotos: 5, locales: 10))
        #expect(ExpenseSyncPolicy.debePurgar(remotos: 3, locales: 0))
        #expect(!ExpenseSyncPolicy.debePurgar(remotos: 4, locales: 10))
        // Una respuesta vacía nunca vacía la caché, ni con la caché vacía.
        #expect(!ExpenseSyncPolicy.debePurgar(remotos: 0, locales: 10))
        #expect(!ExpenseSyncPolicy.debePurgar(remotos: 0, locales: 0))
    }

    // MARK: - Historial entero

    @Test("Toca completa si nunca se ha hecho o ha pasado una semana")
    func tocaCompleta() {
        let ahora: TimeInterval = 1_800_000_000
        let dia: TimeInterval = 24 * 3600
        #expect(ExpenseSyncPolicy.tocaCompleta(ultimaCompleta: 0, ahora: ahora))
        #expect(!ExpenseSyncPolicy.tocaCompleta(ultimaCompleta: ahora - 60, ahora: ahora))
        #expect(!ExpenseSyncPolicy.tocaCompleta(ultimaCompleta: ahora - 6 * dia, ahora: ahora))
        #expect(ExpenseSyncPolicy.tocaCompleta(ultimaCompleta: ahora - 7 * dia, ahora: ahora))
        #expect(ExpenseSyncPolicy.tocaCompleta(ultimaCompleta: ahora - 30 * dia, ahora: ahora))
    }

    @Test("Una marca en el futuro no aplaza la completa")
    func tocaCompletaConRelojAtrasado() {
        let ahora: TimeInterval = 1_800_000_000
        #expect(ExpenseSyncPolicy.tocaCompleta(ultimaCompleta: ahora + 3600, ahora: ahora))
    }

    // MARK: - "Todos" desde la caché

    @Test("Sin filtro o con Todos se responde desde la caché si está completa")
    func todosDesdeCache() {
        let completa: TimeInterval = 1_800_000_000
        #expect(ExpenseSyncPolicy.respondeDesdeCache(filter: nil, cacheVacia: false, ultimaCompleta: completa))
        #expect(ExpenseSyncPolicy.respondeDesdeCache(
            filter: ExpenseFilter(dateRange: .allTime), cacheVacia: false, ultimaCompleta: completa))
        // Lo demás del filtro no cambia la decisión: el remoto tampoco lo mira.
        #expect(ExpenseSyncPolicy.respondeDesdeCache(
            filter: ExpenseFilter(selectedCategories: ["Ocio"], dateRange: .allTime, sortBy: .amountDesc),
            cacheVacia: false, ultimaCompleta: completa))
    }

    @Test("Con la caché vacía o sin haberla bajado entera se va a remoto")
    func todosARemoto() {
        let completa: TimeInterval = 1_800_000_000
        #expect(!ExpenseSyncPolicy.respondeDesdeCache(filter: nil, cacheVacia: true, ultimaCompleta: completa))
        // Caché con solo el mes que guarda la Home: "Todos" enseñaría un mes.
        #expect(!ExpenseSyncPolicy.respondeDesdeCache(filter: nil, cacheVacia: false, ultimaCompleta: 0))
        #expect(!ExpenseSyncPolicy.respondeDesdeCache(
            filter: ExpenseFilter(dateRange: .allTime), cacheVacia: false, ultimaCompleta: 0))
    }

    @Test("El resto de rangos siguen yendo a remoto", arguments: ExpenseFilter.DateRange.allCases.filter { $0 != .allTime })
    func otrosRangosARemoto(rango: ExpenseFilter.DateRange) {
        #expect(!ExpenseSyncPolicy.respondeDesdeCache(
            filter: ExpenseFilter(dateRange: rango), cacheVacia: false, ultimaCompleta: 1_800_000_000))
    }

    @Test("El orden es el del remoto: fecha descendente y, a igualdad, id descendente")
    func ordenRemoto() {
        let desordenados = [
            gasto("b", fecha: "2026-09-10"),
            gasto("z", fecha: "2025-01-01"),
            gasto("c", fecha: "2026-09-10"),
            gasto("a", fecha: "2026-09-11"),
            gasto("a2", fecha: "2026-09-10"),
        ]
        let ids = ExpenseSyncPolicy.enOrdenRemoto(desordenados).map(\.id)
        #expect(ids == ["a", "c", "b", "a2", "z"])
    }

    // MARK: - Marcas

    @Test("Olvidar las marcas borra la de la última sincronización y la de la completa")
    func olvidarMarcas() throws {
        let suite = "ExpenseSyncPolicyTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(123.0, forKey: ExpenseSyncPolicy.lastSyncKey)
        defaults.set(456.0, forKey: ExpenseSyncPolicy.lastFullSyncKey)
        defaults.set("se queda", forKey: "otra.clave")

        ExpenseSyncPolicy.olvidarMarcas(en: defaults)

        #expect(defaults.object(forKey: ExpenseSyncPolicy.lastSyncKey) == nil)
        #expect(defaults.object(forKey: ExpenseSyncPolicy.lastFullSyncKey) == nil)
        #expect(defaults.string(forKey: "otra.clave") == "se queda")
        // Sin marca, la siguiente sincronización baja todo.
        #expect(ExpenseSyncPolicy.tocaCompleta(
            ultimaCompleta: defaults.double(forKey: ExpenseSyncPolicy.lastFullSyncKey), ahora: 1_800_000_000))
    }
}
