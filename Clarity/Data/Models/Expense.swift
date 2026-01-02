// Expense.swift
// Expense data model matching Firestore structure

import Foundation
import FirebaseFirestore
import FirebaseFirestore

struct Expense: Codable, Identifiable, Hashable {
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
