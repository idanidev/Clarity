// SwiftDataExpenseDataSource.swift
// Local Data Source using SwiftData

import Foundation
import SwiftData

@MainActor
final class SwiftDataExpenseDataSource {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    // MARK: - CRUD
    
    func fetchExpenses() throws -> [Expense] {
        let descriptor = FetchDescriptor<ExpenseModel>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        let models = try context.fetch(descriptor)
        return models.map { $0.toDomain() }
    }

    /// Cuántos gastos hay en la caché, sin cargarlos.
    func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<ExpenseModel>())
    }

    /// Cuántos hay con fecha dentro del tramo, sin cargarlos.
    func count(en ventana: ExpenseSyncPolicy.Ventana) throws -> Int {
        let (desde, hasta) = Self.limites(de: ventana)
        return try context.fetchCount(FetchDescriptor<ExpenseModel>(
            predicate: #Predicate { $0.date >= desde && $0.date <= hasta }))
    }

    /// El tramo, en las fechas del modelo. Un gasto se guarda como la
    /// medianoche UTC de su día —con `Formatters.date(from:)`, el mismo parser
    /// que aquí—, así que comparar `Date` equivale a comparar el texto.
    private static func limites(de ventana: ExpenseSyncPolicy.Ventana) -> (desde: Date, hasta: Date) {
        (Formatters.date(from: ventana.desde) ?? .distantPast,
         Formatters.date(from: ventana.hasta) ?? .distantFuture)
    }

    /// Vuelca lo remoto en bloque: un solo fetch de todo, se toca solo lo que
    /// difiere y un único `save` al final.
    ///
    /// Antes era `upsertExpense` por gasto —un fetch y un save cada uno, en el
    /// hilo principal— en cada arranque: con cientos de gastos de historial la
    /// app se quedaba congelada un segundo largo justo al aparecer el total del
    /// mes. Con `purgandoHuerfanos`, borra además los que ya no están en
    /// `expenses` (eliminados desde otro dispositivo).
    ///
    /// Con `ventana`, `expenses` es solo ese tramo del remoto y la purga se
    /// queda dentro de él: lo de fuera no se ha pedido, así que su ausencia no
    /// dice nada. Sin `ventana` la purga es global, para cuando se baja todo.
    func upsertAll(
        _ expenses: [Expense],
        purgandoHuerfanos: Bool = false,
        soloEn ventana: ExpenseSyncPolicy.Ventana? = nil
    ) throws {
        // Solo los modelos del lote, salvo al purgar, que hay que mirar además
        // el tramo purgado (o todo el almacén, sin tramo). Cargarlo entero para
        // guardar un mes —tres o cuatro veces al arrancar y en cada búsqueda—
        // eran segundos de hilo principal con miles de gastos.
        let ids = expenses.compactMap(\.id)
        let limites = ventana.map(Self.limites(de:))
        var existentes: [ExpenseModel]
        if purgandoHuerfanos, limites == nil {
            existentes = try context.fetch(FetchDescriptor<ExpenseModel>())
        } else {
            guard !ids.isEmpty || purgandoHuerfanos else { return }
            // Por id aunque se purgue por tramo: un gasto cuya fecha se movió
            // desde fuera hacia dentro de la ventana está en el lote, pero su
            // modelo local sigue fuera de ella.
            existentes = ids.isEmpty ? [] : try context.fetch(
                FetchDescriptor<ExpenseModel>(predicate: #Predicate { ids.contains($0.id) }))
            if purgandoHuerfanos, let (desde, hasta) = limites {
                existentes += try context.fetch(FetchDescriptor<ExpenseModel>(
                    predicate: #Predicate { $0.date >= desde && $0.date <= hasta }))
            }
        }
        var porId: [String: ExpenseModel] = [:]
        porId.reserveCapacity(existentes.count)
        for modelo in existentes { porId[modelo.id] = modelo }

        var vistos = Set<String>()
        for expense in expenses {
            guard let id = expense.id else { continue }
            vistos.insert(id)
            if let modelo = porId[id] {
                modelo.apply(expense)
            } else {
                context.insert(ExpenseModel(from: expense))
            }
        }
        if purgandoHuerfanos {
            for (id, modelo) in porId where !vistos.contains(id) {
                // La fecha se mira con la que tenía antes del lote: los que
                // están aquí sin haber venido en él no se han tocado.
                if let (desde, hasta) = limites, modelo.date < desde || modelo.date > hasta { continue }
                context.delete(modelo)
            }
        }
        if context.hasChanges { try context.save() }
    }

    /// Aplica una respuesta de sincronización: la ventana pedida, o el
    /// historial entero si `ventana` es `nil`. La purga va con su salvaguarda,
    /// medida contra los locales del mismo tramo que se pidió.
    func volcarSincronizacion(_ remotos: [Expense], ventana: ExpenseSyncPolicy.Ventana?) throws {
        let locales = try ventana.map { try count(en: $0) } ?? count()
        let purgar = ExpenseSyncPolicy.debePurgar(remotos: remotos.count, locales: locales)
        try upsertAll(remotos, purgandoHuerfanos: purgar, soloEn: ventana)
    }
    
    func addExpense(_ expense: Expense) throws {
        let model = ExpenseModel(from: expense)
        context.insert(model)
        try context.save()
    }
    
    func updateExpense(_ expense: Expense) throws {
        guard let id = expense.id else { return }
        let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.id == id })
        
        if let model = try context.fetch(descriptor).first {
            // Con `apply`, como la sincronización: copiaba los campos a mano y
            // se había quedado atrás (ni deducible ni los de recurrente). Y
            // solo se guarda si algo cambia: `apply` no toca nada —ni
            // `updatedAt`— cuando el gasto llega igual que estaba.
            model.apply(expense)
            if context.hasChanges { try context.save() }
        }
    }

    func deleteExpense(_ expenseId: String) throws {
        let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.id == expenseId })
        if let model = try context.fetch(descriptor).first {
            context.delete(model)
            try context.save()
        }
    }
    
    func clearAll() throws {
        try context.delete(model: ExpenseModel.self)
        try context.save()
    }
}
