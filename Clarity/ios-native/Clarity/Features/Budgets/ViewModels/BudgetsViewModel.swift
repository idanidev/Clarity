// BudgetsViewModel.swift
// Budgets state management

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class BudgetsViewModel: ObservableObject {
    @Published var budgetProgress: [BudgetProgress] = []
    @Published var budgetLimits: [String: Double] = [:]
    @Published var showEditBudgets = false
    @Published var isLoading = false
    
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
                .collection("budgets")
                .document(currentMonth)
                .getDocument()
            
            if doc.exists, let data = doc.data() {
                if let categories = data["categories"] as? [String: Double] {
                    budgetLimits = categories
                }
            }
        } catch {
            print("Error loading budgets: \(error)")
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
        
        let data: [String: Any] = [
            "month": currentMonth,
            "categories": nonZeroBudgets,
            "updatedAt": Timestamp(date: Date())
        ]
        
        do {
            try await db.collection("users")
                .document(userId)
                .collection("budgets")
                .document(currentMonth)
                .setData(data, merge: true)
            
            await calculateProgress()
        } catch {
            print("Error saving budgets: \(error)")
        }
    }
}
