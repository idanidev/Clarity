// Expense.swift
// Expense data model matching Firestore structure

import Foundation
import FirebaseFirestore
import FirebaseFirestore

struct Expense: Identifiable, Hashable, Codable {
    @DocumentID var id: String?
    let amount: Double
    let name: String
    let category: String
    let subcategory: String?
    let date: String // "YYYY-MM-DD"
    let paymentMethod: String
    let notes: String?
    let isDeductible: Bool?
    let recurring: Bool?
    let isRecurring: Bool?
    let recurringId: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    // Computed property for Date
    var dateAsDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date) ?? Date()
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, amount, name, category, subcategory, date
        case paymentMethod, notes, isDeductible, recurring, isRecurring, recurringId
        case createdAt, updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        _id = try container.decodeIfPresent(DocumentID<String>.self, forKey: .id) ?? DocumentID(wrappedValue: nil)
        amount = try container.decode(Double.self, forKey: .amount)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory)
        date = try container.decode(String.self, forKey: .date)
        paymentMethod = try container.decode(String.self, forKey: .paymentMethod)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        isDeductible = try container.decodeIfPresent(Bool.self, forKey: .isDeductible)
        recurring = try container.decodeIfPresent(Bool.self, forKey: .recurring)
        
        // Handle both Bool and Int for isRecurring (0/1 from web)
        if let boolValue = try? container.decodeIfPresent(Bool.self, forKey: .isRecurring) {
            isRecurring = boolValue
        } else if let intValue = try? container.decodeIfPresent(Int.self, forKey: .isRecurring) {
            isRecurring = intValue != 0
        } else {
            isRecurring = nil
        }
        
        recurringId = try container.decodeIfPresent(String.self, forKey: .recurringId)
        
        // Flexible createdAt: accepts Date timestamp OR ISO string
        if let timestampDate = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = timestampDate
        } else if let stringDate = try? container.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: stringDate)
        } else {
            createdAt = nil
        }
        
        // Flexible updatedAt: accepts Date timestamp OR ISO string
        if let timestampDate = try? container.decodeIfPresent(Date.self, forKey: .updatedAt) {
            updatedAt = timestampDate
        } else if let stringDate = try? container.decodeIfPresent(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: stringDate)
        } else {
            updatedAt = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
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
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
    }
    
    init(
        id: String? = nil,
        amount: Double,
        name: String,
        category: String,
        subcategory: String? = nil,
        date: String,
        paymentMethod: String = "Tarjeta",
        notes: String? = nil,
        isDeductible: Bool? = nil,
        recurring: Bool? = nil,
        isRecurring: Bool? = nil,
        recurringId: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
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
        self.recurring = recurring
        self.isRecurring = isRecurring
        self.recurringId = recurringId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Sample Data
extension Expense {
    static let sample = Expense(
        id: "1",
        amount: 25.50,
        name: "Café con amigos",
        category: "Alimentacion🫄",
        subcategory: "Cafeterías",
        date: "2026-01-02",
        paymentMethod: "Tarjeta"
    )
    
    static let samples: [Expense] = [
        Expense(id: "1", amount: 45.00, name: "Compra semanal", category: "Alimentacion🫄", subcategory: "Supermercado", date: "2026-01-02", paymentMethod: "Tarjeta"),
        Expense(id: "2", amount: 15.99, name: "Netflix", category: "Suscripciones📺", subcategory: "Netflix", date: "2026-01-01", paymentMethod: "Tarjeta"),
        Expense(id: "3", amount: 8.50, name: "Desayuno", category: "Alimentacion🫄", subcategory: "Cafeterías", date: "2026-01-02", paymentMethod: "Efectivo"),
    ]
}
