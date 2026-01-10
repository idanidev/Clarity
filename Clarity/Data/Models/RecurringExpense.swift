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
    var frequency: RecurringFrequency
    var dayOfMonth: Int  // 1-31, 0 means invalid/missing
    var billingMonth: Int  // 1-12, 0 means not set (only needed for non-monthly)
    
    // Validation: returns true if all required fields are valid
    var isValid: Bool {
        let basicValid = dayOfMonth >= 1 && dayOfMonth <= 31 && !name.isEmpty && amount > 0
        // Month is only required for non-monthly frequencies
        if frequency.needsMonthSelection {
            return basicValid && billingMonth >= 1 && billingMonth <= 12
        }
        return basicValid
    }
    var active: Bool
    var icon: String?
    let startDate: String?
    let endDate: String?
    let lastCreated: String?
    var createdAt: String?
    var updatedAt: String?
    
    // Guaranteed unique ID for ForEach
    var stableId: String {
        id ?? "\(name)_\(dayOfMonth)_\(amount)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id  // Include id so @DocumentID can be decoded
        case amount, name, category, subcategory, paymentMethod
        case frequency, dayOfMonth, billingMonth, active, icon
        case startDate, endDate, lastCreated, createdAt, updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode id properly with DocumentID wrapper
        _id = try container.decode(DocumentID<String>.self, forKey: .id)

        amount = try container.decode(Double.self, forKey: .amount)
        name = try container.decode(String.self, forKey: .name)
        category = try container.decode(String.self, forKey: .category)
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory)
        paymentMethod = try container.decode(String.self, forKey: .paymentMethod)
        // dayOfMonth: required but handle missing/invalid with 0 (invalid marker)
        if let day = try? container.decode(Int.self, forKey: .dayOfMonth), day >= 1, day <= 31 {
            dayOfMonth = day
        } else {
            dayOfMonth = 0  // Invalid - needs user attention
        }
        // billingMonth: required but handle missing/invalid with 0 (invalid marker)
        if let month = try? container.decode(Int.self, forKey: .billingMonth), month >= 1, month <= 12 {
            billingMonth = month
        } else {
            billingMonth = 0  // Invalid - needs user attention
        }
        active = try container.decode(Bool.self, forKey: .active)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        startDate = try container.decodeIfPresent(String.self, forKey: .startDate)
        endDate = try container.decodeIfPresent(String.self, forKey: .endDate)
        lastCreated = try container.decodeIfPresent(String.self, forKey: .lastCreated)
        
        // frequency: optional with default, handle "annual" alias
        if let freqString = try container.decodeIfPresent(String.self, forKey: .frequency) {
            if freqString == "annual" {
                frequency = .yearly
            } else if let freq = RecurringFrequency(rawValue: freqString) {
                frequency = freq
            } else {
                frequency = .monthly // Unknown value fallback
            }
        } else {
            frequency = .monthly // Missing field fallback
        }
        
        // createdAt/updatedAt: handle both String and Timestamp
        createdAt = Self.decodeFlexibleDate(container: container, key: .createdAt)
        updatedAt = Self.decodeFlexibleDate(container: container, key: .updatedAt)
    }
    
    private static func decodeFlexibleDate(container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> String? {
        // Try String first
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        // Try Timestamp
        if let timestamp = try? container.decodeIfPresent(Timestamp.self, forKey: key) {
            return Formatters.isoString(from: timestamp.dateValue())
        }
        return nil
    }
    
    // Standard memberwise init for creating new expenses
    init(id: String?, amount: Double, name: String, category: String, subcategory: String?,
         paymentMethod: String, frequency: RecurringFrequency, dayOfMonth: Int, billingMonth: Int, active: Bool,
         icon: String?, startDate: String?, endDate: String?, lastCreated: String?,
         createdAt: String?, updatedAt: String?) {
        self.id = id
        self.amount = amount
        self.name = name
        self.category = category
        self.subcategory = subcategory
        self.paymentMethod = paymentMethod
        self.frequency = frequency
        self.dayOfMonth = dayOfMonth
        self.billingMonth = billingMonth
        self.active = active
        self.icon = icon
        self.startDate = startDate
        self.endDate = endDate
        self.lastCreated = lastCreated
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum RecurringFrequency: String, Codable, CaseIterable {
    case monthly = "monthly"
    case quarterly = "quarterly"
    case semestral = "semestral"  // Biannual (every 6 months)
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .monthly: return "Mensual"
        case .quarterly: return "Trimestral"
        case .semestral: return "Semestral"
        case .yearly: return "Anual"
        }
    }
    
    /// Returns true if this frequency requires month selection
    var needsMonthSelection: Bool {
        switch self {
        case .monthly: return false  // Happens every month, no need
        case .quarterly, .semestral, .yearly: return true  // Need to know which month
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
        billingMonth: 1,  // January
        active: true,
        icon: "📺",
        startDate: nil,
        endDate: nil,
        lastCreated: nil,
        createdAt: nil,
        updatedAt: nil
    )
}

