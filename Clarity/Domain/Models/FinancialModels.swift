//
//  FinancialModels.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-22.
//  Updated: 2026-01-23 - Firebase Schema v2
//

import Foundation
import FirebaseFirestore

// MARK: - Monthly Budget (Firebase Root Document)
/// Tracks a user's financial setup for a specific month.
/// Document ID format: `{userId}_{year}_{month}` (e.g., "abc123_2026_02")
struct MonthlyBudget: Codable, Identifiable, Hashable {
    @DocumentID var documentId: String?
    
    var id: String { documentId ?? "\(userId)_\(year)_\(month)" }
    
    var userId: String
    var year: Int
    var month: Int
    var estimatedIncome: Double // "Energy" - User's projection
    var realIncome: Double? // Optional: Actual income if user updates
    var currency: String
    var savingsAllocated: Double // Total moved to Piggy Banks this month
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
        estimatedIncome: Double,
        realIncome: Double? = nil,
        currency: String = "EUR",
        savingsAllocated: Double = 0
    ) {
        self.userId = userId
        self.year = year
        self.month = month
        self.estimatedIncome = estimatedIncome
        self.realIncome = realIncome
        self.currency = currency
        self.savingsAllocated = savingsAllocated
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// MARK: - Goal Recurrence
enum GoalRecurrence: String, Codable, CaseIterable {
    case monthly = "monthly"   // Resets each month (Shields)
    case oneTime = "one_time"  // Long-term goal (Piggy Banks)
}

// MARK: - Goal Type
enum GoalType: String, Codable, CaseIterable {
    case savingsTarget = "savings_target" // Piggy Bank 🐖
    case spendingLimit = "spending_limit" // Shield 🛡️
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
    var currentAmount: Double // For Savings: Saved so far. For Limit: Spent so far (computed externally).
    var linkedCategoryId: String? // For Shields: Auto-fill from expenses in this category
    var deadline: Date?
    var icon: String? // Emoji
    var colorHex: String?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date
    
    // Manual entries for Piggy Banks
    var savedHistory: [SavedEntry]
    
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
        self.savedHistory = []
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
        case safe, warning, danger // For Shields
        case starting, halfway, completed // For Piggy Banks
    }
}

// MARK: - Legacy Compatibility Alias
typealias MonthlyConfig = MonthlyBudget
