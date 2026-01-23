//
//  FinancialHubViewModel.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-23.
//  Brain for Financial Hub: Month detection, state management, freeCash calculation
//

import Foundation
import SwiftUI
import Observation
import FirebaseAuth

@MainActor
@Observable
class FinancialHubViewModel {
    // MARK: - State
    private(set) var currentBudget: MonthlyBudget?
    private(set) var goals: [Goal] = []
    private(set) var isLoading = false
    private(set) var error: String?
    
    // Monthly Setup Wizard
    var showMonthlySetup = false
    var previousMonthIncome: Double?
    
    // Services
    private let service = FinancialService.shared
    
    // MARK: - Computed Properties
    
    /// Current month/year based on device date
    var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }
    
    var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }
    
    var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.monthSymbols[currentMonth - 1].capitalized
    }
    
    /// The "Energy" available for spending
    var estimatedIncome: Double {
        currentBudget?.estimatedIncome ?? 0
    }
    
    /// Total allocated to Piggy Banks this month
    var savingsAllocated: Double {
        currentBudget?.savingsAllocated ?? 0
    }
    
    /// Separated goal lists
    var spendingLimits: [Goal] {
        goals.filter { $0.type == .spendingLimit }
    }
    
    var savingsTargets: [Goal] {
        goals.filter { $0.type == .savingsTarget }
    }
    
    /// Free Cash = Income - (Real Expenses + Savings Allocated)
    /// For now, we compute: Income - Savings Allocated (expenses come from ExpenseRepository later)
    var freeCash: Double {
        // TODO: Inject real expenses from ExpenseRepository
        // let totalExpenses = await expenseRepository.getMonthTotal(year:month:)
        let totalExpenses: Double = 0 // Placeholder
        return estimatedIncome - (totalExpenses + savingsAllocated)
    }
    
    /// Percentage of income remaining
    var freeCashPercentage: Double {
        guard estimatedIncome > 0 else { return 0 }
        return max(0, min(1, freeCash / estimatedIncome))
    }
    
    // MARK: - Lifecycle
    
    func load() async {
        isLoading = true
        error = nil
        
        do {
            // 1. Check if budget exists for current month
            if let budget = try await service.fetchMonthlyBudget(year: currentYear, month: currentMonth) {
                currentBudget = budget
            } else {
                // No budget for this month → Trigger wizard
                // Also fetch previous month's income for "Use same" feature
                if let previous = try await service.fetchPreviousMonthBudget() {
                    previousMonthIncome = previous.estimatedIncome
                }
                showMonthlySetup = true
            }
            
            // 2. Load goals
            goals = try await service.fetchGoals()
            
        } catch {
            self.error = error.localizedDescription
            print("❌ FinancialHubViewModel.load() error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Monthly Setup Actions
    
    /// Called when user completes the Monthly Setup Wizard
    func createMonthlyBudget(estimatedIncome: Double) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "No autenticado"
            return
        }
        
        let budget = MonthlyBudget(
            userId: userId,
            year: currentYear,
            month: currentMonth,
            estimatedIncome: estimatedIncome
        )
        
        do {
            try await service.saveMonthlyBudget(budget)
            currentBudget = budget
            showMonthlySetup = false
            HapticManager.shared.playSuccess()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    /// Update the estimated income (tap on Energy Tank)
    func updateEstimatedIncome(_ newIncome: Double) async {
        guard var budget = currentBudget else { return }
        
        budget.estimatedIncome = newIncome
        
        do {
            try await service.saveMonthlyBudget(budget)
            currentBudget = budget
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Goal Actions
    
    /// Feed a Piggy Bank: Subtract from freeCash, add to goal
    func feedPiggyBank(goalId: String, amount: Double) async {
        guard let goalIndex = goals.firstIndex(where: { $0.id == goalId }) else { return }
        
        // Optimistic UI update
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            goals[goalIndex].currentAmount += amount
        }
        
        do {
            // 1. Update goal in Firebase
            try await service.feedPiggyBank(goalId: goalId, amount: amount)
            
            // 2. Update savingsAllocated in budget
            try await service.updateSavingsAllocated(year: currentYear, month: currentMonth, amount: amount)
            
            // 3. Refresh local budget state
            if var budget = currentBudget {
                budget.savingsAllocated += amount
                currentBudget = budget
            }
            
            HapticManager.shared.playCustomPattern(.expenseAdded)
            
        } catch {
            // Rollback on error
            goals[goalIndex].currentAmount -= amount
            self.error = error.localizedDescription
        }
    }
    
    /// Create a new goal
    func createGoal(_ goal: Goal) async {
        do {
            try await service.saveGoal(goal)
            goals.append(goal)
            HapticManager.shared.playSuccess()
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    /// Archive a goal
    func archiveGoal(_ goalId: String) async {
        do {
            try await service.archiveGoal(goalId)
            goals.removeAll { $0.id == goalId }
        } catch {
            self.error = error.localizedDescription
        }
    }
    
    // MARK: - Helpers
    
    /// Get spent amount for a category (for Shields)
    /// TODO: Inject ExpenseRepository to query real expenses
    func getSpentAmount(for categoryId: String) -> Double {
        // Placeholder - In production, query ExpenseRepository
        // return expenseRepository.getSpentAmount(categoryId: categoryId, year: currentYear, month: currentMonth)
        return 0
    }
    
    /// Clear error state (for UI bindings)
    func clearError() {
        error = nil
    }
}
