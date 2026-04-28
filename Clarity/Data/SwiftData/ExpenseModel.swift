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
    var recurringId: String?
    var isRecurring: Bool?
    var goalId: String?

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
        recurringId: String? = nil,
        isRecurring: Bool? = nil,
        goalId: String? = nil,
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
        self.recurringId = recurringId
        self.isRecurring = isRecurring
        self.goalId = goalId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Mapping Helpers
extension ExpenseModel {
    convenience init(from domain: Expense) {
        let dateObj = Formatters.date(from: domain.date) ?? Date.distantPast

        self.init(
            id: domain.id ?? UUID().uuidString,
            amount: domain.amount,
            name: domain.name,
            category: domain.category,
            subcategory: domain.subcategory,
            date: dateObj,
            paymentMethod: domain.paymentMethod,
            notes: domain.notes,
            isDeductible: domain.isDeductible ?? false,
            recurringId: domain.recurringId,
            isRecurring: domain.isRecurring,
            goalId: domain.goalId
        )
    }

    func toDomain() -> Expense {
        Expense(
            id: self.id,
            amount: self.amount,
            name: self.name,
            category: self.category,
            subcategory: self.subcategory,
            date: Formatters.isoString(from: self.date),
            paymentMethod: self.paymentMethod,
            notes: self.notes,
            isDeductible: self.isDeductible,
            isRecurring: self.isRecurring,
            recurringId: self.recurringId,
            goalId: self.goalId
        )
    }
}
