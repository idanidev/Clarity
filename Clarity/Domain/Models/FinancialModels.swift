//
//  FinancialModels.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-22.
//  Updated: 2026-01-23 - Firebase Schema v2
//

import FirebaseFirestore
import Foundation

// MARK: - Monthly Budget (Firebase Root Document)
/// Tracks a user's financial setup for a specific month.
/// Document ID format: `{userId}_{year}_{month}` (e.g., "abc123_2026_02")
struct MonthlyBudget: Codable, Identifiable, Hashable {
    @DocumentID var documentId: String?

    var id: String { documentId ?? "\(userId)_\(year)_\(month)" }

    var userId: String
    var year: Int
    var month: Int
    var income: Double  // Monthly income/salary
    var currency: String
    var savingsAllocated: Double  // Total moved to Piggy Banks this month
    var createdAt: Date
    var updatedAt: Date

    // Computed helper for display
    var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.monthSymbols[month - 1].capitalized
    }

    static func generateDocumentId(userId: String, year: Int, month: Int) -> String {
        return "\(userId)_\(year)_\(String(format: "%02d", month))"
    }

    init(
        userId: String,
        year: Int,
        month: Int,
        income: Double,
        currency: String = "EUR",
        savingsAllocated: Double = 0
    ) {
        self.userId = userId
        self.year = year
        self.month = month
        self.income = income
        self.currency = currency
        self.savingsAllocated = savingsAllocated
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    enum CodingKeys: String, CodingKey {
        case documentId
        case userId
        case year
        case month
        case income
        case estimatedIncome  // Legacy
        case realIncome  // Legacy
        case currency
        case savingsAllocated
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        _documentId = try container.decode(DocumentID<String>.self, forKey: .documentId)
        userId = try container.decode(String.self, forKey: .userId)
        year = try container.decode(Int.self, forKey: .year)
        month = try container.decode(Int.self, forKey: .month)
        currency = try container.decode(String.self, forKey: .currency)
        savingsAllocated =
            try container.decodeIfPresent(Double.self, forKey: .savingsAllocated) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        // Handle migration from estimatedIncome/realIncome to single income
        if let incomeValue = try container.decodeIfPresent(Double.self, forKey: .income) {
            income = incomeValue
        } else if let estimated = try container.decodeIfPresent(
            Double.self, forKey: .estimatedIncome)
        {
            income = estimated
        } else {
            income = 0
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(_documentId, forKey: .documentId)
        try container.encode(userId, forKey: .userId)
        try container.encode(year, forKey: .year)
        try container.encode(month, forKey: .month)
        try container.encode(income, forKey: .income)
        try container.encode(currency, forKey: .currency)
        try container.encode(savingsAllocated, forKey: .savingsAllocated)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
}

// MARK: - Goal Recurrence
enum GoalRecurrence: String, Codable, CaseIterable {
    case monthly = "monthly"  // Resets each month (Shields)
    case oneTime = "one_time"  // Long-term goal (Piggy Banks)
}

// MARK: - Goal Type
enum GoalType: String, Codable, CaseIterable {
    case savingsTarget = "savings_target"  // Piggy Bank 🐖
    case spendingLimit = "spending_limit"  // Shield 🛡️
}

// MARK: - Goal (Subcollection or Array in User)
/// Unified model for "Savings Targets" (Dreams) and "Spending Limits" (Shields)
struct Goal: Identifiable, Codable, Hashable {
    @DocumentID var documentId: String?

    var id: String { documentId ?? UUID().uuidString }

    var userId: String
    var name: String
    var type: GoalType
    var recurrence: GoalRecurrence
    var targetAmount: Double
    var currentAmount: Double
    var linkedCategoryId: String?  // For Shields
    var deadline: Date?
    var icon: String?  // Emoji fallback
    var systemImage: String?  // SF Symbol (preferred)
    var colorHex: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    // Piggy Bank History
    var savedHistory: [SavedEntry] = []

    struct SavedEntry: Codable, Hashable, Identifiable {
        var id: String = UUID().uuidString
        var amount: Double
        var date: Date
        var note: String?
    }

    init(
        userId: String = "",
        name: String,
        type: GoalType,
        recurrence: GoalRecurrence = .oneTime,
        targetAmount: Double,
        currentAmount: Double = 0,
        linkedCategoryId: String? = nil,
        deadline: Date? = nil,
        icon: String? = nil,
        colorHex: String? = nil
    ) {
        self.userId = userId
        self.name = name
        self.type = type
        self.recurrence = recurrence
        self.targetAmount = targetAmount
        self.currentAmount = currentAmount
        self.linkedCategoryId = linkedCategoryId
        self.deadline = deadline
        self.icon = icon
        self.colorHex = colorHex
        self.isArchived = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Goal Helpers
extension Goal {
    var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(max(currentAmount / targetAmount, 0), 1.0)
    }

    var remaining: Double {
        return max(targetAmount - currentAmount, 0)
    }

    var isOverLimit: Bool {
        return type == .spendingLimit && currentAmount > targetAmount
    }

    var isCompleted: Bool {
        return type == .savingsTarget && currentAmount >= targetAmount
    }

    // Alias for PromptBuilder
    var isAchieved: Bool { isCompleted }

    /// Gamification: Status for UI badges
    var statusLevel: StatusLevel {
        if type == .spendingLimit {
            if progress > 0.9 { return .danger }
            if progress > 0.7 { return .warning }
            return .safe
        } else {
            if isCompleted { return .completed }
            if progress > 0.5 { return .halfway }
            return .starting
        }
    }

    enum StatusLevel {
        case safe, warning, danger  // For Shields
        case starting, halfway, completed  // For Piggy Banks
    }
}

// MARK: - Legacy Compatibility Alias
typealias MonthlyConfig = MonthlyBudget
