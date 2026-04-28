// ExpenseDTO.swift
// Private DTO isolated from MainActor context

import Foundation

struct ExpenseDTO: Codable, Sendable {
    let amount: Double
    let name: String
    let category: String
    let subcategory: String?
    let date: String
    let paymentMethod: String
    let notes: String?
    let isDeductible: Bool?
    let recurring: Bool?
    let isRecurring: Bool?
    let recurringId: String?
    let goalId: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    // Explicitly nonisolated mapping
    nonisolated func toDomain(id: String) -> Expense {
        Expense(
            id: id,
            amount: amount,
            name: name,
            category: category,
            subcategory: subcategory,
            date: date,
            paymentMethod: paymentMethod,
            notes: notes,
            isDeductible: isDeductible,
            recurring: recurring,
            isRecurring: isRecurring,
            recurringId: recurringId,
            goalId: goalId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    nonisolated init(from domain: Expense) {
        self.amount = domain.amount
        self.name = domain.name
        self.category = domain.category
        self.subcategory = domain.subcategory
        self.date = domain.date
        self.paymentMethod = domain.paymentMethod
        self.notes = domain.notes
        self.isDeductible = domain.isDeductible
        self.recurring = domain.recurring
        self.isRecurring = domain.isRecurring
        self.recurringId = domain.recurringId
        self.goalId = domain.goalId
        self.createdAt = domain.createdAt
        self.updatedAt = domain.updatedAt
    }
    
    // MARK: - Manual Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case amount, name, category, subcategory, date, paymentMethod, notes
        case isDeductible, recurring, isRecurring, recurringId, goalId
        case createdAt, updatedAt
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        amount = try container.decode(Double.self, forKey: .amount)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory)
        date = try container.decode(String.self, forKey: .date)
        paymentMethod = try container.decodeIfPresent(String.self, forKey: .paymentMethod) ?? "Tarjeta"
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isDeductible = try container.decodeIfPresent(Bool.self, forKey: .isDeductible)
        recurring = try container.decodeIfPresent(Bool.self, forKey: .recurring)
        isRecurring = try container.decodeIfPresent(Bool.self, forKey: .isRecurring)
        recurringId = try container.decodeIfPresent(String.self, forKey: .recurringId)
        goalId = try container.decodeIfPresent(String.self, forKey: .goalId)

        createdAt = Self.decodeDate(from: container, forKey: .createdAt)
        updatedAt = Self.decodeDate(from: container, forKey: .updatedAt)
    }
    
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(amount, forKey: .amount)
        try container.encode(name, forKey: .name)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(subcategory, forKey: .subcategory)
        try container.encode(date, forKey: .date)
        try container.encode(paymentMethod, forKey: .paymentMethod)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(isDeductible, forKey: .isDeductible)
        try container.encodeIfPresent(recurring, forKey: .recurring)
        try container.encodeIfPresent(isRecurring, forKey: .isRecurring)
        try container.encodeIfPresent(recurringId, forKey: .recurringId)
        try container.encodeIfPresent(goalId, forKey: .goalId)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
    
    // Helper for decoding Date/String/Timestamp - must be nonisolated static
    private nonisolated static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) -> Date? {
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        if let dateString = try? container.decode(String.self, forKey: key) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) { return date }
            
            let formatter2 = ISO8601DateFormatter()
            if let date = formatter2.date(from: dateString) { return date }
        }
        return nil
    }
}
