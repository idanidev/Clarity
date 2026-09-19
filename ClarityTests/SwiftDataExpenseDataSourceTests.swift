// SwiftDataExpenseDataSourceTests.swift
// El volcado en bloque de la caché: solo toca lo que difiere y no carga el
// almacén entero para guardar un lote.

import Foundation
import SwiftData
import Testing
@testable import Clarity

@Suite("SwiftDataExpenseDataSource")
@MainActor
struct SwiftDataExpenseDataSourceTests {

    private func almacen() throws -> (SwiftDataExpenseDataSource, ModelContext) {
        let contenedor = try ModelContainer(
            for: ExpenseModel.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let contexto = ModelContext(contenedor)
        return (SwiftDataExpenseDataSource(context: contexto), contexto)
    }

    private func gasto(_ id: String, _ amount: Double, name: String = "x", fecha: String = "2026-09-10") -> Expense {
        Expense(id: id, amount: amount, name: name, category: "Ocio", date: fecha)
    }

    /// La ventana de sincronización de un 19 de septiembre de 2026.
    private let ventana = ExpenseSyncPolicy.Ventana(desde: "2026-07-01", hasta: ExpenseSyncPolicy.finAbierto)

    private func ids(_ fuente: SwiftDataExpenseDataSource) throws -> [String] {
        try fuente.fetchExpenses().compactMap(\.id).sorted()
    }

    @Test("upsertAll inserta lo nuevo, actualiza lo que cambia y deja el resto")
    func upsertEnBloque() throws {
        let (fuente, _) = try almacen()
        try fuente.upsertAll([gasto("a", 10), gasto("b", 20), gasto("c", 30)])
        #expect(try fuente.count() == 3)

        // Un lote parcial: "b" cambia, "d" es nuevo, "a" y "c" ni se miran.
        try fuente.upsertAll([gasto("b", 25, name: "cambiado"), gasto("d", 40)])
        let todos = try fuente.fetchExpenses()
        #expect(todos.count == 4)
        #expect(todos.first { $0.id == "b" }?.amount == 25)
        #expect(todos.first { $0.id == "b" }?.name == "cambiado")
        #expect(todos.first { $0.id == "a" }?.amount == 10)
        #expect(todos.first { $0.id == "d" }?.amount == 40)
    }

    @Test("Purgar huérfanos borra lo que ya no está en remoto")
    func purga() throws {
        let (fuente, _) = try almacen()
        try fuente.upsertAll([gasto("a", 10), gasto("b", 20), gasto("c", 30)])
        try fuente.upsertAll([gasto("a", 10), gasto("c", 31)], purgandoHuerfanos: true)
        let todos = try fuente.fetchExpenses()
        #expect(todos.map(\.id).compactMap { $0 }.sorted() == ["a", "c"])
        #expect(todos.first { $0.id == "c" }?.amount == 31)
    }

    @Test("Un lote sin cambios no ensucia el contexto")
    func sinCambios() throws {
        let (fuente, contexto) = try almacen()
        try fuente.upsertAll([gasto("a", 10), gasto("b", 20)])
        #expect(!contexto.hasChanges)
        try fuente.upsertAll([gasto("a", 10), gasto("b", 20)])
        #expect(!contexto.hasChanges)
    }

    // MARK: - Purga por ventana

    @Test("count(en:) cuenta solo el tramo, extremos y fechas futuras incluidos")
    func contarEnVentana() throws {
        let (fuente, _) = try almacen()
        try fuente.upsertAll([
            gasto("viejo", 1, fecha: "2026-06-30"),
            gasto("borde", 1, fecha: "2026-07-01"),
            gasto("hoy", 1, fecha: "2026-09-19"),
            gasto("futuro", 1, fecha: "2031-01-01"),
        ])
        #expect(try fuente.count() == 4)
        #expect(try fuente.count(en: ventana) == 3)
        #expect(try fuente.count(en: .init(desde: "2026-07-01", hasta: "2026-07-31")) == 1)
    }

    @Test("La purga por ventana borra solo los huérfanos de dentro y respeta los de fuera")
    func purgaEnVentana() throws {
        let (fuente, _) = try almacen()
        try fuente.upsertAll([
            gasto("antiguo", 1, fecha: "2024-03-05"),
            gasto("junio", 2, fecha: "2026-06-30"),
            gasto("julio", 3, fecha: "2026-07-01"),
            gasto("agosto", 4, fecha: "2026-08-15"),
            gasto("sept", 5, fecha: "2026-09-10"),
        ])

        // El remoto, para la ventana, ya no trae "agosto" (borrado en otro
        // dispositivo). "antiguo" y "junio" no se han pedido: no son huérfanos.
        try fuente.upsertAll(
            [gasto("julio", 3, fecha: "2026-07-01"), gasto("sept", 6, fecha: "2026-09-10")],
            purgandoHuerfanos: true, soloEn: ventana)

        #expect(try ids(fuente) == ["antiguo", "julio", "junio", "sept"])
        #expect(try fuente.fetchExpenses().first { $0.id == "sept" }?.amount == 6)
    }

    @Test("Sin ventana la purga sigue siendo global")
    func purgaGlobalIntacta() throws {
        let (fuente, _) = try almacen()
        try fuente.upsertAll([
            gasto("antiguo", 1, fecha: "2024-03-05"),
            gasto("agosto", 4, fecha: "2026-08-15"),
            gasto("sept", 5, fecha: "2026-09-10"),
        ])
        try fuente.volcarSincronizacion(
            [gasto("agosto", 4, fecha: "2026-08-15"), gasto("sept", 5, fecha: "2026-09-10")], ventana: nil)
        #expect(try ids(fuente) == ["agosto", "sept"])
    }

    @Test("Una respuesta a medias no purga: la salvaguarda no se cumple")
    func salvaguardaEnVentana() throws {
        let (fuente, _) = try almacen()
        try fuente.upsertAll((1...6).map { gasto("g\($0)", Double($0), fecha: "2026-09-0\($0)") })

        // 2 remotos frente a 6 locales en la ventana: menos de la mitad.
        try fuente.volcarSincronizacion(
            [gasto("g1", 1, fecha: "2026-09-01"), gasto("g2", 20, fecha: "2026-09-02")], ventana: ventana)

        #expect(try fuente.count() == 6)
        // Lo que sí trae se aplica igual.
        #expect(try fuente.fetchExpenses().first { $0.id == "g2" }?.amount == 20)

        // Y una respuesta vacía tampoco borra nada.
        try fuente.volcarSincronizacion([], ventana: ventana)
        #expect(try fuente.count() == 6)
    }

    @Test("La salvaguarda se mide contra los locales de la ventana, no contra todo el almacén")
    func salvaguardaMideLaVentana() throws {
        let (fuente, _) = try almacen()
        let antiguos = (1...9).map { gasto("v\($0)", 1, fecha: "2023-01-0\($0)") }
        try fuente.upsertAll(antiguos + [
            gasto("a", 1, fecha: "2026-09-01"),
            gasto("b", 2, fecha: "2026-09-02"),
        ])

        // 1 remoto frente a 2 locales en la ventana basta (contra los 11 del
        // almacén no bastaría, y los borrados recientes no se purgarían nunca).
        try fuente.volcarSincronizacion([gasto("a", 1, fecha: "2026-09-01")], ventana: ventana)

        #expect(try fuente.count() == 10)
        #expect(try !ids(fuente).contains("b"))
        #expect(try fuente.count(en: .init(desde: "2023-01-01", hasta: "2023-12-31")) == 9)
    }

    @Test("Un gasto cuya fecha entra en la ventana se actualiza, no se duplica")
    func fechaMovidaHaciaLaVentana() throws {
        let (fuente, _) = try almacen()
        try fuente.upsertAll([
            gasto("movido", 7, fecha: "2025-02-01"),
            gasto("sept", 5, fecha: "2026-09-10"),
        ])

        // Editado desde otro dispositivo: ahora es de agosto de 2026. Su modelo
        // local está fuera de la ventana, pero viene en el lote.
        try fuente.volcarSincronizacion(
            [gasto("movido", 7, fecha: "2026-08-20"), gasto("sept", 5, fecha: "2026-09-10")], ventana: ventana)

        let todos = try fuente.fetchExpenses()
        #expect(todos.count == 2)
        #expect(todos.first { $0.id == "movido" }?.date == "2026-08-20")
    }

    // MARK: - "Todos" desde la caché

    @Test("La caché devuelve el historial entero en el orden del remoto")
    func todosDesdeCache() throws {
        let (fuente, _) = try almacen()
        try fuente.upsertAll([
            gasto("b", 1, fecha: "2026-09-10"),
            gasto("z", 2, fecha: "2019-05-01"),
            gasto("c", 3, fecha: "2026-09-10"),
            gasto("a", 4, fecha: "2026-09-11"),
        ])

        // Lo que hace `ExpenseRepository.getExpensesPaginated` sin filtro o con
        // "Todos": decidir con la política y servir la caché ordenada.
        let cached = try fuente.fetchExpenses()
        #expect(ExpenseSyncPolicy.respondeDesdeCache(
            filter: ExpenseFilter(dateRange: .allTime), cacheVacia: cached.isEmpty, ultimaCompleta: 1_800_000_000))
        let pagina = PageResult(expenses: ExpenseSyncPolicy.enOrdenRemoto(cached), hasMore: false)

        #expect(pagina.expenses.map(\.id) == ["a", "c", "b", "z"])
        #expect(!pagina.hasMore)
        // Las fechas salen de la caché tal y como entraron.
        #expect(pagina.expenses.map(\.date) == ["2026-09-11", "2026-09-10", "2026-09-10", "2019-05-01"])
    }
}
