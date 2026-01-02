// RecurringExpense.swift
// Recurring expense data model

import Foundation
import FirebaseFirestore

struct RecurringExpense: Codable, Identifiable {
    @DocumentID var id: String?
    let amount: Double
    let name: String
    let category: String
    let subcategory: String?
    let paymentMethod: String
    let frequency: RecurringFrequency
    let dayOfMonth: Int // 1-31
    var active: Bool
    let startDate: String?
    let endDate: String? // null = sin fin
    let lastCreated: String? // Última vez que se creó gasto
    let createdAt: Date?
    let updatedAt: Date?
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .monthly: return "Mensual"
        case .quarterly: return "Trimestral"
        case .yearly: return "Anual"
        }
    }
}

extension RecurringExpense {
    static let sample = RecurringExpense(
        id: "1",
        amount: 15.99,
        name: "Netflix",
        category: "Suscripciones📺",
        subcategory: "Netflix",
        paymentMethod: "Tarjeta",
        frequency: .monthly,
        dayOfMonth: 15,
        active: true,
        startDate: nil,
        endDate: nil,
        lastCreated: nil,
        createdAt: nil,
        updatedAt: nil
    )
}
