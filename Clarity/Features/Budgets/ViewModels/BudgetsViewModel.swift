// BudgetsViewModel.swift
// Budgets state management

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Observation

@MainActor
@Observable
class BudgetsViewModel {
    var budgetProgress: [BudgetProgress] = []
    var budgetLimits: [String: Double] = [:]
    var monthlySavingsGoal: Double = 0
    var currentSavings: Double = 0
    var income: Double = 0
    var showEditBudgets = false
    var isLoading = false
    
    private let db = Firestore.firestore()
    private let expenseRepository = ExpenseRepository()
    
    private var userId: String? {
        Auth.auth().currentUser?.uid
    }
    
    private var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
    
    init() {
        Task {
            await loadData()
        }
    }
    
    func loadData() async {
        isLoading = true
        
        // Load budgets
        await loadBudgets()
        
        // Load expenses and calculate progress
        await calculateProgress()
        
        isLoading = false
    }
    
    private func loadBudgets() async {
        guard let userId = userId else { return }
        
        do {
            let doc = try await db.collection("users")
                .document(userId)
                .getDocument()
            
            if doc.exists, let data = doc.data() {
                // Extract goals
                if let goals = data["goals"] as? [String: Any] {
                    // Category goals
                    if let categoryGoals = goals["categoryGoals"] as? [String: Double] {
                        budgetLimits = categoryGoals
                    }
                    
                    // Monthly savings goal
                    if let savingsGoal = goals["monthlySavingsGoal"] as? Double {
                        monthlySavingsGoal = savingsGoal
                    }
                    
                    // Current month savings
                    if let monthlyHistory = goals["monthlyHistory"] as? [String: Any],
                       let currentMonthData = monthlyHistory[currentMonth] as? [String: Any],
                       let savings = currentMonthData["savings"] as? Double {
                        currentSavings = savings
                    }
                } else {
                    budgetLimits = [:]
                }
                
                // Load income (root level field)
                if let userIncome = data["income"] as? Double {
                    income = userIncome
                }
            } else {
                budgetLimits = [:]
            }
        } catch {
            print("Error loading budgets: \(error.localizedDescription)")
        }
    }
    
    private func calculateProgress() async {
        do {
            let expenses = try await expenseRepository.fetchExpenses(for: currentMonth)
            
            // Group by category
            var categoryTotals: [String: Double] = [:]
            for expense in expenses {
                categoryTotals[expense.category, default: 0] += expense.amount
            }
            
            // Create progress items
            var progress: [BudgetProgress] = []
            
            for (category, limit) in budgetLimits where limit > 0 {
                let spent = categoryTotals[category] ?? 0
                progress.append(BudgetProgress(
                    category: category,
                    spent: spent,
                    limit: limit
                ))
            }
            
            budgetProgress = progress.sorted { $0.percentage > $1.percentage }
            
        } catch {
            print("Error calculating progress: \(error)")
        }
    }
    
    func saveBudgets() async {
        guard let userId = userId else { return }
        
        // Filter out zero budgets
        let nonZeroBudgets = budgetLimits.filter { $0.value > 0 }
        
        do {
            // Update goals.categoryGoals in user document
            try await db.collection("users")
                .document(userId)
                .setData([
                    "goals": [
                        "categoryGoals": nonZeroBudgets,
                        "updatedAt": Timestamp(date: Date())
                    ]
                ], merge: true)
            
            await calculateProgress()
        } catch {
            print("❌ Error saving budgets: \(error)")
        }
    }
}
