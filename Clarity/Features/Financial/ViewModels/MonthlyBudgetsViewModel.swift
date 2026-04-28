//
//  MonthlyBudgetsViewModel.swift
//  Clarity
//
//  Manages monthly income history (MonthlyBudget CRUD)
//

import FirebaseAuth
import Foundation
import Observation

/// A group of budgets for a specific year, with summary stats.
struct YearBudgetGroup: Identifiable {
    let year: Int
    let budgets: [MonthlyBudget]

    var id: Int { year }

    var totalIncome: Double {
        budgets.reduce(0) { $0 + $1.income }
    }

    var averageIncome: Double {
        budgets.isEmpty ? 0 : totalIncome / Double(budgets.count)
    }
}

@MainActor
@Observable
class MonthlyBudgetsViewModel {
    var budgets: [MonthlyBudget] = []
    var isLoading = false
    var errorMessage: String?
    var expandedYears: Set<Int> = []

    private let financialService = DependencyContainer.shared.financialService

    private var userId: String? {
        Auth.auth().currentUser?.uid
    }

    /// Budgets grouped by year, sorted descending.
    var groupedByYear: [YearBudgetGroup] {
        let grouped = Dictionary(grouping: budgets) { $0.year }
        return grouped
            .map { YearBudgetGroup(year: $0.key, budgets: $0.value.sorted { $0.month > $1.month }) }
            .sorted { $0.year > $1.year }
    }

    // MARK: - Lifecycle

    func loadBudgets() async {
        guard userId != nil else { return }

        isLoading = true
        errorMessage = nil

        do {
            let startDate =
                Calendar.current.date(byAdding: .month, value: -24, to: Date()) ?? Date()
            budgets = try await fetchBudgetsInRange(from: startDate, to: Date())

            // Expand current year by default on first load
            if expandedYears.isEmpty {
                let currentYear = Calendar.current.component(.year, from: Date())
                expandedYears.insert(currentYear)
            }
        } catch {
            errorMessage = "Error loading budgets: \(error.safeUserMessage)"
        }

        isLoading = false
    }

    // MARK: - CRUD Operations

    func saveBudget(_ budget: MonthlyBudget) async {
        do {
            try await financialService.saveMonthlyBudget(budget)
            if let index = budgets.firstIndex(where: { $0.year == budget.year && $0.month == budget.month }) {
                budgets[index] = budget
            } else {
                budgets.append(budget)
                budgets.sort { $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month) }
            }
        } catch {
            errorMessage = "Error saving budget: \(error.safeUserMessage)"
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
        let calendar = Calendar.current
        var monthPairs: [(year: Int, month: Int)] = []
        var currentDate = startDate
        while currentDate <= endDate {
            monthPairs.append((
                calendar.component(.year, from: currentDate),
                calendar.component(.month, from: currentDate)
            ))
            guard let next = calendar.date(byAdding: .month, value: 1, to: currentDate) else {
                break
            }
            currentDate = next
        }

        let tasks = monthPairs.map { (year, month) in
            Task { @MainActor in
                try await self.financialService.fetchMonthlyBudget(year: year, month: month)
            }
        }

        var budgets: [MonthlyBudget] = []
        for task in tasks {
            if let budget = try await task.value {
                budgets.append(budget)
            }
        }

        return budgets.sorted {
            $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month)
        }
    }

    func budgetExists(for year: Int, month: Int) -> Bool {
        budgets.contains { $0.year == year && $0.month == month }
    }

    /// Carga los 12 meses de un año concreto (bajo demanda al navegar a años antiguos).
    /// No-op si ya hay budgets de ese año cargados.
    func loadYear(_ year: Int) async {
        guard userId != nil else { return }
        if budgets.contains(where: { $0.year == year }) { return }

        do {
            let monthPairs = (1...12).map { (year: year, month: $0) }
            let tasks = monthPairs.map { (y, m) in
                Task { @MainActor in
                    try await self.financialService.fetchMonthlyBudget(year: y, month: m)
                }
            }
            var fetched: [MonthlyBudget] = []
            for task in tasks {
                if let budget = try await task.value { fetched.append(budget) }
            }
            budgets.append(contentsOf: fetched)
            budgets.sort { $0.year > $1.year || ($0.year == $1.year && $0.month > $1.month) }
        } catch {
            errorMessage = "Error loading year \(year): \(error.safeUserMessage)"
        }
    }
}
