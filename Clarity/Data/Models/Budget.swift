// Budget.swift
// Budget data model

import Foundation
import FirebaseFirestore

// Note: Renamed from MonthlyBudget to CategoryBudget to avoid conflict with FinancialModels.MonthlyBudget
struct CategoryBudget: Codable, Identifiable {
    var id: String { month }
    let month: String // "YYYY-MM"
    let categories: [String: Double] // ["Alimentacion🫄": 400, "Ocio 🍻": 200]
    let createdAt: Date?
    let updatedAt: Date?
    
    func budget(for category: String) -> Double {
        categories[category] ?? 0
    }
}

struct BudgetProgress: Identifiable {
    let id = UUID()
    let category: String
    let spent: Double
    let limit: Double
    
    var percentage: Double {
        guard limit > 0 else { return 0 }
        return (spent / limit) * 100
    }
    
    var remaining: Double {
        max(0, limit - spent)
    }
    
    var isOverBudget: Bool {
        spent > limit
    }
    
    var isNearLimit: Bool {
        percentage >= 80 && !isOverBudget
    }
}
