// Expense.swift
// Expense data model matching Firestore structure

import Foundation
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
    
    // Guaranteed unique ID for ForEach (fallback if Firestore ID is nil)
    var stableId: String {
        id ?? "\(name)_\(date)_\(amount)"
    }
    
    // Computed property for Date
    var dateAsDate: Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date) ?? Date()
    }
    
    // NOTE: Using default Codable decoder - custom decoder was breaking @DocumentID
    // Firestore's decoder automatically populates @DocumentID when using doc.data(as:)
    
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
    
    // MARK: - Codable Implementation
    
    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case name
        case category
        case subcategory
        case date
        case paymentMethod
        case notes
        case isDeductible
        case recurring
        case isRecurring
        case recurringId
        case createdAt
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        _id = try container.decode(DocumentID<String>.self, forKey: .id)
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
        
        // Robust Date Decoding
        createdAt = try Expense.decodeDate(from: container, forKey: .createdAt)
        updatedAt = try Expense.decodeDate(from: container, forKey: .updatedAt)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try _id.encode(to: encoder)
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
    
    // Helper for decoding Date/String/Timestamp
    private static func decodeDate(from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Date? {
        // 1. Try generic Date (Timestamp)
        if let date = try? container.decode(Date.self, forKey: key) {
            return date
        }
        
        // 2. Try String (ISO8601)
        if let dateString = try? container.decode(String.self, forKey: key) {
            // ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }
            
            // Fallback: standard ISO8601
            let formatter2 = ISO8601DateFormatter()
             if let date = formatter2.date(from: dateString) {
                return date
            }
        }
        
        return nil
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
