// User.swift
// User data model matching Firestore structure

import Foundation
import FirebaseFirestore
import FirebaseFirestore

struct UserDocument: Codable {
    let uid: String
    let email: String
    let displayName: String?
    let role: String // "user" | "admin"
    let createdAt: Date?
    let updatedAt: Date?
    let settings: UserSettings?
    let aiQuotas: AIQuotas?
    let subscription: Subscription?
}

struct UserSettings: Codable {
    let language: String // "es" | "en"
    let theme: String // "dark" | "light" | "system"
    let currency: String // "EUR" | "USD"
    
    static let `default` = UserSettings(language: "es", theme: "system", currency: "EUR")
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
