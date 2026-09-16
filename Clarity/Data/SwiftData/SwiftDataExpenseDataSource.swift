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

    /// Vuelca lo remoto en bloque: un solo fetch de todo, se toca solo lo que
    /// difiere y un único `save` al final.
    ///
    /// Antes era `upsertExpense` por gasto —un fetch y un save cada uno, en el
    /// hilo principal— en cada arranque: con cientos de gastos de historial la
    /// app se quedaba congelada un segundo largo justo al aparecer el total del
    /// mes. Con `purgandoHuerfanos`, borra además los que ya no están en
    /// `expenses` (eliminados desde otro dispositivo).
    func upsertAll(_ expenses: [Expense], purgandoHuerfanos: Bool = false) throws {
        // Solo los modelos del lote, salvo al purgar, que hay que mirar todo el
        // almacén. Cargarlo entero para guardar un mes —tres o cuatro veces al
        // arrancar y en cada búsqueda— eran segundos de hilo principal con
        // miles de gastos.
        let ids = expenses.compactMap(\.id)
        let existentes: [ExpenseModel]
        if purgandoHuerfanos {
            existentes = try context.fetch(FetchDescriptor<ExpenseModel>())
        } else {
            guard !ids.isEmpty else { return }
            existentes = try context.fetch(FetchDescriptor<ExpenseModel>(predicate: #Predicate { ids.contains($0.id) }))
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
                context.delete(modelo)
            }
        }
        if context.hasChanges { try context.save() }
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
            // Update fields
            model.amount = expense.amount
            model.name = expense.name
            model.category = expense.category
            model.subcategory = expense.subcategory
            
            // Usar parser UTC compartido (un DateFormatter sin TZ deriva la fecha al editar)
            if let dateObj = Formatters.date(from: expense.date) {
                model.date = dateObj
            }
            
            model.paymentMethod = expense.paymentMethod
            model.notes = expense.notes
            model.goalId = expense.goalId
            model.isShared = expense.isShared
            model.debtorsData = ExpenseModel.encodeDebtors(expense.debtors)
            model.updatedAt = Date()

            try context.save()
        }
    }

    /// Inserts or Updates based on ID existence
    func upsertExpense(_ expense: Expense) throws {
         guard let id = expense.id else { return }
         let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.id == id })
         
         if let model = try context.fetch(descriptor).first {
             model.apply(expense)
         } else {
             // Insert
             let model = ExpenseModel(from: expense)
             context.insert(model)
         }
         try context.save()
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
