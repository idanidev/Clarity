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
            
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            if let dateObj = formatter.date(from: expense.date) {
                model.date = dateObj
            }
            
            model.paymentMethod = expense.paymentMethod
            model.notes = expense.notes
            model.updatedAt = Date()
            
            try context.save()
        }
    }
    
    /// Inserts or Updates based on ID existence
    func upsertExpense(_ expense: Expense) throws {
         guard let id = expense.id else { return }
         let descriptor = FetchDescriptor<ExpenseModel>(predicate: #Predicate { $0.id == id })
         
         if let model = try context.fetch(descriptor).first {
             // Update
             model.amount = expense.amount
             model.name = expense.name
             model.category = expense.category
             model.subcategory = expense.subcategory
             
             let formatter = DateFormatter()
             formatter.dateFormat = "yyyy-MM-dd"
             if let dateObj = formatter.date(from: expense.date) {
                 model.date = dateObj
             }
             
             model.paymentMethod = expense.paymentMethod
             model.notes = expense.notes
             model.updatedAt = Date()
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
