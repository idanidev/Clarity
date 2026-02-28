//
//  MonthlyBudgetsViewModel.swift
//  Clarity
//
//  Manages monthly income history (MonthlyBudget CRUD)
//

import Combine
import FirebaseAuth
import Foundation
import SwiftUI

@MainActor
class MonthlyBudgetsViewModel: ObservableObject {
    @Published var budgets: [MonthlyBudget] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let financialService = FinancialService.shared

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    // MARK: - Lifecycle

    func loadBudgets() async {
        guard let userId = userId else { return }

        isLoading = true
        errorMessage = nil

        do {
            // Load last 24 months of budgets
            let startDate =
                Calendar.current.date(byAdding: .month, value: -24, to: Date()) ?? Date()
            budgets = try await fetchBudgetsInRange(from: startDate, to: Date())

            print("📊 Loaded \(budgets.count) monthly budgets")
        } catch {
            errorMessage = "Error loading budgets: \(error.localizedDescription)"
            print("❌ \(errorMessage ?? "")")
        }

        isLoading = false
    }

    // MARK: - CRUD Operations

    func saveBudget(_ budget: MonthlyBudget) async {
        do {
            try await financialService.saveMonthlyBudget(budget)
            // Update local state directly — no need to re-fetch 24 months from Firestore
            if let index = budgets.firstIndex(where: { $0.year == budget.year && $0.month == budget.month }) {
                budgets[index] = budget
            } else {
                budgets.append(budget)
                budgets.sort { $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month) }
            }
            print("✅ Saved budget for \(budget.month)/\(budget.year)")
        } catch {
            errorMessage = "Error saving budget: \(error.localizedDescription)"
            print("❌ \(errorMessage ?? "")")
        }
    }

    func createBudgetForMonth(year: Int, month: Int, income: Double) async {
        guard let userId = userId else { return }

        let budget = MonthlyBudget(
            userId: userId,
            year: year,
            month: month,
            income: income,
            currency: "EUR"
        )

        await saveBudget(budget)
    }

    // MARK: - Helpers

    private func fetchBudgetsInRange(from startDate: Date, to endDate: Date) async throws
        -> [MonthlyBudget]
    {
        var allBudgets: [MonthlyBudget] = []
        let calendar = Calendar.current

        var currentDate = startDate
        while currentDate <= endDate {
            let year = calendar.component(.year, from: currentDate)
            let month = calendar.component(.month, from: currentDate)

            if let budget = try await financialService.fetchMonthlyBudget(year: year, month: month)
            {
                allBudgets.append(budget)
            }

            // Move to next month
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextMonth
        }

        // Sort descending (newest first)
        return allBudgets.sorted {
            $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month)
        }
    }

    func budgetExists(for year: Int, month: Int) -> Bool {
        budgets.contains { $0.year == year && $0.month == month }
    }
}
