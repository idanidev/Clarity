//
//  FinancialHubViewModel.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-23.
//  Brain for Financial Hub: Month detection, state management, freeCash calculation
//

import FirebaseAuth
import FirebaseFirestore
import Foundation
import Observation
// SwiftUI removed — animations belong in the View layer

@MainActor
@Observable
class FinancialHubViewModel {
    // MARK: - State
    private(set) var currentBudget: MonthlyBudget?
    private(set) var goals: [Goal] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var error: String?

    // Monthly Setup Wizard
    var showMonthlySetup = false
    var previousMonthIncome: Double?

    // Salary Settings
    var isSalaryRecurring = false
    var showSalarySettings = false
    var showAddGoal = false
    var editingGoal: Goal? = nil

    // Services
    private let service: FinancialService
    private let getExpensesUseCase: GetExpensesUseCase
    private let recurringRepository: RecurringExpenseRepository

    nonisolated(unsafe) private var expenseObserver: Any?

    init() {
        self.service = DependencyContainer.shared.financialService
        self.getExpensesUseCase = DependencyContainer.shared.makeGetExpensesUseCase()
        self.recurringRepository = DependencyContainer.shared.recurringExpenseRepository

        // Listen for expense changes even when the view isn't visible
        expenseObserver = NotificationCenter.default.addObserver(
            forName: .expenseDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.hasLoaded else { return }
                await self.refreshCurrentMonthExpenses()
            }
        }
    }

    deinit {
        if let observer = expenseObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Computed Properties

    /// Current month/year based on device date
    var currentYear: Int {
        Calendar.current.component(.year, from: Date())
    }

    var currentMonth: Int {
        Calendar.current.component(.month, from: Date())
    }

    var currentMonthName: String {
        Formatters.fullMonthName(currentMonth)
    }

    /// The "Energy" available for spending
    var income: Double {
        currentBudget?.income ?? 0
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

    /// All expenses for the current month, loaded server-side for accuracy.
    /// Refreshed on demand via refreshCurrentMonthExpenses().
    private(set) var currentMonthExpenses: [Expense] = []

    /// Total spent this month.
    var totalSpent: Double {
        currentMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    /// Free Cash = Income - Total Spent (savingsAllocated shown separately)
    var freeCash: Double { income - totalSpent }

    /// Percentage of income remaining
    var freeCashPercentage: Double {
        guard income > 0 else { return 0 }
        return max(0, min(1, freeCash / income))
    }

    // MARK: - Lifecycle

    func load() async {
        guard !hasLoaded && !isLoading else { return }

        // Esperar a que Auth restaure sesión (crítico en simulador donde tarda más)
        if Auth.auth().currentUser == nil {
            for _ in 0..<5 {
                try? await Task.sleep(for: .milliseconds(300))
                if Auth.auth().currentUser != nil { break }
            }
            guard Auth.auth().currentUser != nil else {
                error = "No autenticado"
                return
            }
        }

        isLoading = true
        error = nil

        do {
            // 0. Load User Settings first to check recurring preference
            if let userId = Auth.auth().currentUser?.uid,
                let doc = try await UserDataService.shared.loadUserDocument(userId: userId)
            {
                self.isSalaryRecurring = doc.settings?.isSalaryRecurring ?? false
            }

            // 1. Check if budget exists for current month
            if let budget = try await service.fetchMonthlyBudget(
                year: currentYear, month: currentMonth)
            {
                currentBudget = budget
            } else {
                // CHECK RECURRING HERE
                if let userId = Auth.auth().currentUser?.uid,
                    let doc = try await UserDataService.shared.loadUserDocument(userId: userId),
                    let baseIncome = doc.income,
                    doc.settings?.isSalaryRecurring == true
                {
                    await createMonthlyBudget(income: baseIncome)
                } else {
                    // No budget & No recurring → Trigger wizard
                    if let previous = try await service.fetchPreviousMonthBudget() {
                        previousMonthIncome = previous.income
                    }
                    showMonthlySetup = true
                }
            }

            // 2. Load goals + current month expenses in parallel
            let calendar = Calendar.current
            let monthComponents = DateComponents(year: currentYear, month: currentMonth)
            let monthStart = calendar.date(from: monthComponents) ?? Date()
            let monthEnd = calendar.date(
                byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? Date()
            let monthFilter = ExpenseFilter(
                dateRange: .custom,
                customStartDate: monthStart,
                customEndDate: monthEnd
            )

            async let goalsTask = service.fetchGoals()
            async let expensesTask = getExpensesUseCase
                .executePaginated(page: 0, filter: monthFilter)
            async let rulesTask = recurringRepository.fetchAll()

            goals = try await goalsTask
            let expensesResult = (try? await expensesTask) ?? PageResult(expenses: [], hasMore: false)
            let rules = (try? await rulesTask) ?? []
            currentMonthExpenses = ExpenseSanitizer.sanitize(
                expenses: expensesResult.expenses, rules: rules)

            hasLoaded = true

        } catch {
            self.error = error.safeUserMessage
        }

        isLoading = false
    }

    // MARK: - Monthly Setup Actions

    /// Called when user completes the Monthly Setup Wizard
    func createMonthlyBudget(income: Double) async {
        guard let userId = Auth.auth().currentUser?.uid else {
            error = "No autenticado"
            return
        }

        let budget = MonthlyBudget(
            userId: userId,
            year: currentYear,
            month: currentMonth,
            income: income
        )

        do {
            try await service.saveMonthlyBudget(budget)
            currentBudget = budget
            showMonthlySetup = false
            HapticManager.shared.playSuccess()
        } catch {
            self.error = error.safeUserMessage
        }
    }

    func updateIncome(_ newIncome: Double) async {
        guard var budget = currentBudget else { return }

        budget.income = newIncome

        do {
            try await service.saveMonthlyBudget(budget)
            currentBudget = budget
        } catch {
            self.error = error.safeUserMessage
        }
    }

    /// Update Salary Settings from Sheet
    func updateSalarySettings(amount: Double, recurring: Bool) async {
        guard let userId = Auth.auth().currentUser?.uid else { return }

        isSalaryRecurring = recurring

        do {
            // 1. Update Remote User
            try await Firestore.firestore().collection("users").document(userId).updateData([
                "income": amount,
                "settings.isSalaryRecurring": recurring,
                "updatedAt": FieldValue.serverTimestamp(),
            ])

            // 2. Update Current Month Budget if valid
            if var budget = currentBudget {
                budget.income = amount
                try await service.saveMonthlyBudget(budget)
                currentBudget = budget
            }

            HapticManager.shared.playSuccess()
        } catch {
            self.error = "Error al guardar ajustes: \(error.safeUserMessage)"
        }
    }

    // MARK: - Goal Actions

    /// Feed a Piggy Bank: Subtract from freeCash, add to goal, and record an expense
    func feedPiggyBank(goalId: String, amount: Double) async {
        guard let goalIndex = goals.firstIndex(where: { $0.id == goalId }) else { return }
        let goalName = goals[goalIndex].name
        let category = goals[goalIndex].savingsExpenseCategory ?? "Ahorros"
        let subcategory = goals[goalIndex].savingsExpenseSubcategory

        // Optimistic UI update (animation handled by View)
        goals[goalIndex].currentAmount += amount

        do {
            // 1. Update goal in Firebase
            try await service.feedPiggyBank(goalId: goalId, amount: amount)

            // 2. Update savingsAllocated in budget
            try await service.updateSavingsAllocated(
                year: currentYear, month: currentMonth, amount: amount)

            // 3. Refresh local budget state
            if var budget = currentBudget {
                budget.savingsAllocated += amount
                currentBudget = budget
            }

            // 4. Create a real expense so it appears in the expense list
            let expense = Expense(
                amount: amount,
                name: "Aportación a \(goalName)",
                category: category,
                subcategory: subcategory,
                date: Formatters.isoString(from: Date()),
                paymentMethod: "Transferencia",
                goalId: goalId
            )
            do {
                _ = try await DependencyContainer.shared.expenseRepository.addExpense(expense)
            } catch {
                self.error = "Error al registrar aportación: \(error.safeUserMessage)"
            }

            HapticManager.shared.playCustomPattern(.expenseAdded)

        } catch {
            // Rollback on error
            goals[goalIndex].currentAmount -= amount
            self.error = error.safeUserMessage
        }
    }

    /// Create a new goal
    func createGoal(_ goal: Goal) async {
        do {
            try await service.saveGoal(goal)
            goals.append(goal)
            HapticManager.shared.playSuccess()
        } catch {
            self.error = error.safeUserMessage
        }
    }

    /// Update an existing goal
    func updateGoal(_ goal: Goal) async {
        do {
            try await service.saveGoal(goal)
            if let idx = goals.firstIndex(where: { $0.id == goal.id }) {
                goals[idx] = goal
            }
            HapticManager.shared.playSuccess()
        } catch {
            self.error = error.safeUserMessage
        }
    }

    /// Delete a goal permanently
    func deleteGoal(_ goalId: String) async {
        do {
            try await service.deleteGoal(goalId)
            goals.removeAll { $0.id == goalId }
            HapticManager.shared.notification(.success)
        } catch {
            self.error = error.safeUserMessage
        }
    }

    // MARK: - Helpers

    /// Spent amount for a category this month, computed from sanitized currentMonthExpenses.
    /// Used by GoalCardView (Shields) via spentAmountProvider closure.
    func getSpentAmount(for categoryId: String) -> Double {
        guard !categoryId.isEmpty else { return 0 }
        let target = Self.normalizeCategory(categoryId)
        return currentMonthExpenses
            .filter {
                let catPart = $0.category.components(separatedBy: " / ").first ?? $0.category
                return Self.normalizeCategory(catPart) == target
            }
            .reduce(0) { $0 + $1.amount }
    }

    private static func normalizeCategory(_ s: String) -> String {
        s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .unicodeScalars
            .filter { CharacterSet.letters.union(.whitespaces).contains($0) }
            .reduce("") { $0 + String($1) }
            .trimmingCharacters(in: .whitespaces)
    }

    /// Lightweight refresh of current month expenses — called every time the tab appears
    /// so the spending shields stay up to date without a full reload.
    func refreshCurrentMonthExpenses() async {
        let calendar = Calendar.current
        let monthComponents = DateComponents(year: currentYear, month: currentMonth)
        let monthStart = calendar.date(from: monthComponents) ?? Date()
        let monthEnd = calendar.date(
            byAdding: DateComponents(month: 1, day: -1), to: monthStart) ?? Date()
        let monthFilter = ExpenseFilter(
            dateRange: .custom,
            customStartDate: monthStart,
            customEndDate: monthEnd
        )
        guard let result = try? await getExpensesUseCase
            .executePaginated(page: 0, filter: monthFilter),
              let rules = try? await recurringRepository.fetchAll()
        else { return }
        currentMonthExpenses = ExpenseSanitizer.sanitize(
            expenses: result.expenses, rules: rules)
    }

    /// Force reload (e.g. after adding/archiving a goal)
    func reload() async {
        hasLoaded = false
        await load()
    }

    /// Clear error state (for UI bindings)
    func clearError() {
        error = nil
    }
}
