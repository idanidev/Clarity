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

    private func gasto(_ id: String, _ amount: Double, name: String = "x") -> Expense {
        Expense(id: id, amount: amount, name: name, category: "Ocio", date: "2026-09-10")
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
}
