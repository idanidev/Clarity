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

    /// Modo regalo (#37). Los deudores se guardan serializados en JSON para que
    /// añadirlos sea una migración ligera sobre el store existente.
    var isShared: Bool?
    var debtorsData: Data?

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
        isShared: Bool? = nil,
        debtorsData: Data? = nil,
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
        self.isShared = isShared
        self.debtorsData = debtorsData
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
            goalId: domain.goalId,
            isShared: domain.isShared,
            debtorsData: ExpenseModel.encodeDebtors(domain.debtors)
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
            goalId: self.goalId,
            isShared: self.isShared,
            debtors: ExpenseModel.decodeDebtors(self.debtorsData)
        )
    }

    static func encodeDebtors(_ debtors: [Debtor]?) -> Data? {
        guard let debtors, !debtors.isEmpty else { return nil }
        return try? JSONEncoder().encode(debtors)
    }

    static func decodeDebtors(_ data: Data?) -> [Debtor]? {
        guard let data else { return nil }
        return try? JSONDecoder().decode([Debtor].self, from: data)
    }
}
