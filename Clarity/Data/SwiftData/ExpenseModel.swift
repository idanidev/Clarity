// ExpenseModel.swift
// SwiftData model for Expense entity

import Foundation
import SwiftData

@Model
final class ExpenseModel {
    @Attribute(.unique) var id: String
    var amount: Double
    var name: String
    var category: String
    var subcategory: String?
    var date: Date
    var paymentMethod: String
    var notes: String?
    var isDeductible: Bool
    
    // Audit
    var createdAt: Date
    var updatedAt: Date
    
    init(
        id: String = UUID().uuidString,
        amount: Double,
        name: String,
        category: String,
        subcategory: String? = nil,
        date: Date,
        paymentMethod: String,
        notes: String? = nil,
        isDeductible: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.amount = amount
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.date = date
        self.paymentMethod = paymentMethod
        self.notes = notes
        self.isDeductible = isDeductible
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Mapping Helpers
extension ExpenseModel {
    convenience init(from domain: Expense) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateObj = formatter.date(from: domain.date) ?? Date()
        
        self.init(
            id: domain.id ?? UUID().uuidString,
            amount: domain.amount,
            name: domain.name,
            category: domain.category,
            subcategory: domain.subcategory,
            date: dateObj,
            paymentMethod: domain.paymentMethod,
            notes: domain.notes,
            isDeductible: domain.isDeductible ?? false
        )
    }
    
    func toDomain() -> Expense {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        return Expense(
            id: self.id,
            amount: self.amount,
            name: self.name,
            category: self.category,
            subcategory: self.subcategory,
            date: formatter.string(from: self.date),
            paymentMethod: self.paymentMethod,
            notes: self.notes,
            isDeductible: self.isDeductible
        )
    }
}
