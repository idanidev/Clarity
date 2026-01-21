// User.swift
// User data model matching Firestore structure

import Foundation
import FirebaseFirestore
import FirebaseFirestore

struct UserDocument: Codable {
    // Core fields
    var email: String?
    var displayName: String?
    var role: String?
    var createdAt: Date?
    var updatedAt: Date?
    
    // Flat settings
    var theme: String?
    var language: String?
    var income: Double?
    
    // Nested objects
    var settings: UserSettings?
    var aiQuotas: AIQuotas?
    var subscription: Subscription?
    var goals: Goals?
    var savedFilters: [ExpenseFilter]?
    
    // Computed
    var isAdmin: Bool { role == "admin" }
    var effectiveTheme: String { theme ?? settings?.theme ?? "system" }
    var effectiveLanguage: String { language ?? settings?.language ?? "es" }
    
    // MARK: - Initializer
    init(email: String? = nil, displayName: String? = nil, role: String? = nil, createdAt: Date? = nil, updatedAt: Date? = nil, theme: String? = nil, language: String? = nil, income: Double? = nil, settings: UserSettings? = nil, aiQuotas: AIQuotas? = nil, subscription: Subscription? = nil, goals: Goals? = nil) {
        self.email = email
        self.displayName = displayName
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.theme = theme
        self.language = language
        self.income = income
        self.settings = settings
        self.aiQuotas = aiQuotas
        self.subscription = subscription
        self.goals = goals
    }
    
    // MARK: - Custom Coding Keys
    enum CodingKeys: String, CodingKey {
        case email, displayName, role, createdAt, updatedAt
        case theme, language, income
        case settings, aiQuotas, subscription, goals
        case savedFilters
    }
    
    // MARK: - Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        email = try container.decodeIfPresent(String.self, forKey: .email)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        role = try container.decodeIfPresent(String.self, forKey: .role)
        theme = try container.decodeIfPresent(String.self, forKey: .theme)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        income = try container.decodeIfPresent(Double.self, forKey: .income)
        settings = try container.decodeIfPresent(UserSettings.self, forKey: .settings)
        aiQuotas = try container.decodeIfPresent(AIQuotas.self, forKey: .aiQuotas)
        subscription = try container.decodeIfPresent(Subscription.self, forKey: .subscription)
        goals = try container.decodeIfPresent(Goals.self, forKey: .goals)
        savedFilters = try container.decodeIfPresent([ExpenseFilter].self, forKey: .savedFilters)
        
        // Robust Date Decoding
        if let date = try? container.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = date
        } else if let dateString = try? container.decodeIfPresent(String.self, forKey: .createdAt) {
             createdAt = Formatters.date(from: dateString)
        }
        
        if let date = try? container.decodeIfPresent(Date.self, forKey: .updatedAt) {
            updatedAt = date
        } else if let dateString = try? container.decodeIfPresent(String.self, forKey: .updatedAt) {
             updatedAt = Formatters.date(from: dateString)
        }
    }
    
    // MARK: - Custom Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(email, forKey: .email)
        try container.encodeIfPresent(displayName, forKey: .displayName)
        try container.encodeIfPresent(role, forKey: .role)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(theme, forKey: .theme)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(income, forKey: .income)
        try container.encodeIfPresent(settings, forKey: .settings)
        try container.encodeIfPresent(aiQuotas, forKey: .aiQuotas)
        try container.encodeIfPresent(subscription, forKey: .subscription)
        try container.encodeIfPresent(goals, forKey: .goals)
        try container.encodeIfPresent(savedFilters, forKey: .savedFilters)
    }
}

// MARK: - Goals (from your Firebase)
struct Goals: Codable {
    var monthlySavingsGoal: Double?
    var totalSavingsGoal: Double?
    var categoryGoals: [String: Double]?
}

struct UserSettings: Codable {
    var language: String? // "es" | "en"
    var theme: String? // "dark" | "light" | "system"
    var currency: String? // "EUR" | "USD"
    var privacyMode: Bool? // Hide amounts
    var defaultDateRange: String? // Legacy, kept for migration
    var defaultFilter: ExpenseFilter? // Full persistable filter
    var hasCompletedOnboarding: Bool?
    
    static let `default` = UserSettings(language: "es", theme: "system", currency: "EUR", privacyMode: false, defaultDateRange: "thisMonth", defaultFilter: nil, hasCompletedOnboarding: false)
}

struct AIQuotas: Codable {
    var monthly: Int // 3 (free), 50 (pro), 999999 (premium/admin)
    var used: Int
    var remaining: Int
    var unlimited: Bool
    var resetDate: String // "YYYY-MM-DD"
    
    static let free = AIQuotas(monthly: 3, used: 0, remaining: 3, unlimited: false, resetDate: "")
}

struct Subscription: Codable {
    let plan: String // "free" | "pro" | "premium"
    let status: String // "active" | "canceled" | "past_due"
    let stripeCustomerId: String?
}

// MARK: - Subscription Plan
enum SubscriptionPlan: String, CaseIterable {
    case free = "free"
    case pro = "pro"
    case premium = "premium"
    
    var monthlyQuota: Int {
        switch self {
        case .free: return 3
        case .pro: return 50
        case .premium: return 999999
        }
    }
    
    var displayName: String {
        switch self {
        case .free: return "Gratis"
        case .pro: return "Pro"
        case .premium: return "Premium"
        }
    }
    
    var price: String {
        switch self {
        case .free: return "Gratis"
        case .pro: return "€4.99/mes"
        case .premium: return "€9.99/mes"
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return ["3 consultas IA/mes", "Gastos ilimitados", "Categorías personalizadas"]
        case .pro:
            return ["50 consultas IA/mes", "Todo de Free", "Análisis avanzado", "Sin anuncios"]
        case .premium:
            return ["Consultas IA ilimitadas", "Todo de Pro", "Soporte prioritario", "Exportación avanzada"]
        }
    }
}
