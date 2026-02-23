// HomeViewModel.swift
// ViewModel for the main expense list/dashboard

import Foundation
import OSLog
import SwiftUI

enum HomeViewState: Equatable {
    case idle
    case loading
    case loaded([Expense])
    case error(AppError)  // Changed from String
    case empty

    static func == (lhs: HomeViewState, rhs: HomeViewState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.empty, .empty): return true
        case (.loaded(let l), .loaded(let r)): return l == r
        case (.error(let l), .error(let r)): return l == r
        default: return false
        }
    }
}

@MainActor
@Observable
final class HomeViewModel {

    // Output
    private(set) var state: HomeViewState = .idle

    // Month selector state
    var selectedMonth: Date = Date() {
        didSet {
            updateFilterForSelectedMonth()
        }
    }

    var selectedFilter: ExpenseFilter = ExpenseFilter() {
        didSet { applyFilters() }
    }
    var searchText: String = "" {
        didSet {
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms
                if !Task.isCancelled {
                    applyFilters()
                }
            }
        }
    }

    private var searchTask: Task<Void, Never>?

    // Data for View
    var categoryGroups: [CategoryGroup] = []
    var filteredExpenses: [Expense] = []
    var dateFilteredExpenses: [Expense] = []  // For filtered view
    var currentMonthExpenses: [Expense] = []  // Para cálculo de AHORROS (sin filtros)
    var income: Double = 0
    var showAddExpense = false  // From DashboardViewModel
    var currentMonthlyBudget: MonthlyBudget? = nil  // For savingsAllocated
    var previousMonthlyBudget: MonthlyBudget? = nil  // Para cálculo de ahorros

    // Computed properties (from DashboardViewModel)
    var totalFilteredAmount: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    var calculatedSavings: Double {
        // Ahorro = Ingreso del mes anterior - Gastos REALES del mes seleccionado - Ahorro asignado
        // NUNCA depende de los filtros del usuario, siempre usa el mes seleccionado completo
        let periodExpenses = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        let savingsAllocated = currentMonthlyBudget?.savingsAllocated ?? 0

        logger.debug("💰 CALCULANDO AHORROS:")
        logger.debug(
            "   - Gastos reales del mes: \(self.currentMonthExpenses.count) gastos = €\(periodExpenses)"
        )
        logger.debug("   - Ingreso mes anterior: €\(self.previousMonthIncome)")
        logger.debug("   - Ahorro asignado: €\(savingsAllocated)")

        return previousMonthIncome - periodExpenses - savingsAllocated
    }

    /// Income for the currently selected month (from MonthlyBudget)
    private var monthlyIncome: Double {
        return currentMonthlyBudget?.income ?? income
    }

    /// Income del mes ANTERIOR al seleccionado (para cálculo de ahorros)
    /// La nómina de diciembre se usa para pagar gastos de enero
    private var previousMonthIncome: Double {
        // Si tenemos el budget del mes anterior cargado, usarlo
        if let previousBudget = previousMonthlyBudget {
            return previousBudget.income
        }

        // Fallback: usar el mismo income del mes actual
        // (asumiendo que la nómina es estable)
        return currentMonthlyBudget?.income ?? income
    }

    /// Load MonthlyBudget from Firebase for a specific month
    private func loadMonthlyBudget(for date: Date) async {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        do {
            currentMonthlyBudget = try await financialService.fetchMonthlyBudget(
                year: year,
                month: month
            )

            if let budget = currentMonthlyBudget {
                logger.debug("💰 Loaded budget for \(month)/\(year): €\(budget.income)")
            } else {
                logger.info("⚠️ No budget found for \(month)/\(year), using global income fallback")
            }
        } catch {
            print("❌ Error loading budget for \(month)/\(year): \(error.localizedDescription)")
            currentMonthlyBudget = nil
        }

        // Cargar también el budget del mes ANTERIOR para cálculo de ahorros
        guard let previousDate = calendar.date(byAdding: .month, value: -1, to: date) else {
            return
        }

        let previousYear = calendar.component(.year, from: previousDate)
        let previousMonth = calendar.component(.month, from: previousDate)

        do {
            previousMonthlyBudget = try await financialService.fetchMonthlyBudget(
                year: previousYear,
                month: previousMonth
            )

            if let prevBudget = previousMonthlyBudget {
                logger.debug(
                    "💰 Loaded PREVIOUS month budget (\(previousMonth)/\(previousYear)): €\(prevBudget.income)"
                )
            } else {
                logger.info(
                    "⚠️ No budget found for previous month (\(previousMonth)/\(previousYear))")
            }
        } catch {
            logger.error("❌ Error loading previous month budget: \(error.localizedDescription)")
            previousMonthlyBudget = nil
        }
    }

    // Internal
    private let getExpensesUseCase: GetExpensesUseCase
    private let deleteExpenseUseCase: DeleteExpenseUseCase
    private let addExpenseUseCase: AddExpenseUseCase
    private let recurringRepository = RecurringExpenseRepository()
    private let financialService = FinancialService()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "HomeViewModel")

    // Cached formatters (DateFormatter is expensive to create)
    private let filterDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private let monthDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    // Exposed for View Logic (loading check)
    var allExpenses: [Expense] = []
    var allRecurringRules: [RecurringExpense] = []  // Keep them for reference

    // Pagination
    var currentPage = 0
    var hasMorePages = true
    var isLoadingMore = false

    init(
        getExpensesUseCase: GetExpensesUseCase,
        deleteExpenseUseCase: DeleteExpenseUseCase,
        addExpenseUseCase: AddExpenseUseCase
    ) {
        self.getExpensesUseCase = getExpensesUseCase
        self.deleteExpenseUseCase = deleteExpenseUseCase
        self.addExpenseUseCase = addExpenseUseCase

        // Load income
        self.income = UserDataManager.shared.userDocument?.income ?? 0

        // ✅ FIX: Force "This Month" filter by default to prevent summing ALL history
        if let savedDefault = UserDataManager.shared.defaultFilter {
            self.selectedFilter = savedDefault
        } else {
            // Default to current month to show realistic savings (income - current month expenses)
            self.selectedFilter = ExpenseFilter(dateRange: .thisMonth)
            print("📅 No saved filter - defaulting to This Month to prevent historical accumulation")
        }

        // 🆕 Load current month's budget for accurate income
        Task {
            await loadMonthlyBudget(for: Date())
        }
    }

    // MARK: - Intents

    func deleteExpense(_ expense: Expense) async {
        guard let id = expense.id else { return }
        do {
            try await deleteExpenseUseCase.execute(id: id)
            await loadExpenses()
            FeedbackManager.shared.show(
                .success, title: "Gasto eliminado",
                message: "\(expense.name) se ha borrado correctamente")
        } catch {
            state = .error(.deletionFailed(error.localizedDescription))
            FeedbackManager.shared.show(
                .error, title: "Error al borrar", message: error.localizedDescription)
        }
    }

    // Flag to track if we've attempted to apply the default filter
    private var hasAppliedDefaultFilter = false

    func loadExpenses(silent: Bool = false) async {
        print("🔍 loadExpenses called (silent: \(silent))")

        // ✅ ESPERAR a que UserDataManager termine de cargar ANTES de continuar
        if !UserDataManager.shared.hasLoaded {
            logger.info("⏳ Waiting for UserDataManager to load...")
            await UserDataManager.shared.loadUserData()
            logger.info("✅ UserDataManager loaded!")
        }

        // Refresh income
        self.income = UserDataManager.shared.userDocument?.income ?? 0

        // SIEMPRE intentar aplicar filtro predeterminado si existe y aún no se ha aplicado
        if !hasAppliedDefaultFilter {
            if let defaultFilter = UserDataManager.shared.defaultFilter {
                logger.debug("🏠 ✅ Applying Default Filter: '\(defaultFilter.name ?? "Unnamed")'")
                self.selectedFilter = defaultFilter
                self.hasAppliedDefaultFilter = true
            } else {
                logger.debug("🏠 ⚠️ No default filter found, using 'Este mes'")
                self.hasAppliedDefaultFilter = true
            }
        }

        if !silent && allExpenses.isEmpty {
            state = .loading
        }

        currentPage = 0
        hasMorePages = true

        do {
            // Load current month's budget to get savingsAllocated
            let calendar = Calendar.current
            let now = Date()
            let currentYear = calendar.component(.year, from: now)
            let currentMonth = calendar.component(.month, from: now)

            do {
                self.currentMonthlyBudget = try await financialService.fetchMonthlyBudget(
                    year: currentYear, month: currentMonth)
                logger.debug(
                    "💰 Loaded monthly budget with savingsAllocated: €\(self.currentMonthlyBudget?.savingsAllocated ?? 0)"
                )
            } catch {
                logger.warning("⚠️ Failed to load monthly budget: \(error)")
            }

            // Build a date-only filter for the selected month (no category/payment filters)
            // This is used ONLY to calculate real savings — unaffected by user filters
            let calendar2 = Calendar.current
            let monthComponents = calendar2.dateComponents([.year, .month], from: selectedMonth)
            let monthStart = calendar2.date(from: monthComponents) ?? selectedMonth
            let monthEnd =
                calendar2.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart)
                ?? selectedMonth
            let monthOnlyFilter = ExpenseFilter(
                dateRange: .custom,
                customStartDate: monthStart,
                customEndDate: monthEnd
            )

            // Fetch Expenses in parallel:
            // 1. With user's filter (for display)
            // 2. With month-only filter (for savings calculation - no category/payment filters)
            async let expensesTask = getExpensesUseCase.executePaginated(
                page: 0, filter: selectedFilter)
            async let monthExpensesTask = getExpensesUseCase.executePaginated(
                page: 0, filter: monthOnlyFilter)

            var rules: [RecurringExpense] = []
            do {
                rules = try await recurringRepository.fetchAll()
            } catch {
                logger.warning("⚠️ Failed to load recurring rules: \(error)")
            }

            let result = try await expensesTask
            let monthResult = try await monthExpensesTask
            self.allRecurringRules = rules

            // Sanitize Result
            // Logic: Deduplicate by period and remove misplaced annuals
            let sanitized = ExpenseSanitizer.sanitize(expenses: result.expenses, rules: rules)
            let sanitizedMonth = ExpenseSanitizer.sanitize(
                expenses: monthResult.expenses, rules: rules)

            self.allExpenses = sanitized
            self.currentMonthExpenses = sanitizedMonth  // ✅ Real month expenses, no user filters
            self.hasMorePages = result.hasMore

            let totalRealExpenses = sanitizedMonth.reduce(0) { $0 + $1.amount }
            logger.debug(
                "💰 Gastos REALES del mes (sin filtros): \(sanitizedMonth.count) gastos = €\(totalRealExpenses)"
            )

            applyFilters()
        } catch {
            logger.error("❌ Error loading expenses: \(error)")
            if !silent {
                state = .error(.dataLoadingFailed(error.localizedDescription))
            }
        }
    }

    func loadMore() async {
        guard hasMorePages, !isLoadingMore else { return }
        isLoadingMore = true

        do {
            currentPage += 1
            let result = try await getExpensesUseCase.executePaginated(
                page: currentPage, filter: selectedFilter)

            self.allExpenses.append(contentsOf: result.expenses)
            self.hasMorePages = result.hasMore

            applyFilters()  // Re-apply filters to new full set
        } catch {
            // Silently fail or show toast? For infinite scroll, usually silent or small indicator
            print("Error loading more: \(error)")
            currentPage -= 1  // Revert page logic
        }

        isLoadingMore = false
    }

    func refresh() async {
        await loadExpenses(silent: true)
    }

    // MARK: - Helpers

    /// Updates the filter to match the selected month (used by MonthSelectorView)
    private func updateFilterForSelectedMonth() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: selectedMonth)

        guard let startOfMonth = calendar.date(from: components),
            let endOfMonth = calendar.date(
                byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)
        else {
            return
        }

        var newFilter = selectedFilter
        newFilter.dateRange = .custom
        newFilter.customStartDate = startOfMonth
        newFilter.customEndDate = endOfMonth
        selectedFilter = newFilter

        logger.debug(
            "📅 Month changed to: \(self.monthDateFormatter.string(from: self.selectedMonth))")
    }

    /// Called when month selector changes (triggers refresh)
    func onMonthChanged() async {
        await loadMonthlyBudget(for: selectedMonth)
        await loadExpenses()
    }

    // monthDateFormatter is defined as a private let above

    private func applyFilters() {
        logger.debug("📋 Applying filters: \(self.selectedFilter.dateRange.rawValue)")
        // NOTE: currentMonthExpenses is populated in loadExpenses() with a month-only fetch.
        // We do NOT recompute it here to avoid overwriting with already-filtered allExpenses.

        // Filter by date range (según filtro del usuario)
        let (startStr, endStr) = selectedFilter.dateRangeForQuery()
        dateFilteredExpenses = allExpenses.filter { expense in
            expense.date >= startStr && expense.date <= endStr
        }

        // 3. Apply other filters (Category, Payment, Search)
        var result = dateFilteredExpenses  // Use the newly filtered dateFilteredExpenses

        // Search
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.category.localizedCaseInsensitiveContains(searchText)
                    || ($0.subcategory?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Category Filter
        if !selectedFilter.selectedCategories.isEmpty {
            result = result.filter { expense in
                selectedFilter.selectedCategories.contains { filterCategory in
                    // Normalizar categorías: reemplazar `/` y `-` por espacios para comparación
                    let normalizedExpenseCategory = expense.category
                        .replacingOccurrences(of: " / ", with: " ")
                        .replacingOccurrences(of: " - ", with: " ")
                        .lowercased()

                    let normalizedFilterCategory =
                        filterCategory
                        .replacingOccurrences(of: " / ", with: " ")
                        .replacingOccurrences(of: " - ", with: " ")
                        .lowercased()

                    // Comparar solo la primera palabra (categoría principal)
                    let expenseFirstWord =
                        normalizedExpenseCategory.components(separatedBy: " ").first ?? ""
                    let filterFirstWord =
                        normalizedFilterCategory.components(separatedBy: " ").first ?? ""

                    return expenseFirstWord == filterFirstWord
                }
            }
        }

        // Payment Method Filter
        if !selectedFilter.selectedPaymentMethods.isEmpty {
            result = result.filter { expense in
                selectedFilter.selectedPaymentMethods.contains(expense.paymentMethod)
            }
        }

        self.filteredExpenses = result

        // 4. Build Groups
        buildCategoryGroups(from: result)

        if result.isEmpty {
            state = .empty
        } else {
            state = .loaded(result)
        }
    }

    private func deduplicate(expenses: [Expense]) -> [Expense] {
        var seen = Set<String>()
        return expenses.filter { expense in
            guard let id = expense.id, !id.isEmpty else { return true }
            if seen.contains(id) { return false }
            seen.insert(id)
            return true
        }
    }

    private func buildCategoryGroups(from expenses: [Expense]) {
        var groups: [String: CategoryGroup] = [:]

        for expense in expenses {
            let categoryName = extractCategoryName(from: expense.category)
            let emoji = extractEmoji(from: expense.category)

            if groups[categoryName] == nil {
                groups[categoryName] = CategoryGroup(
                    name: categoryName,
                    emoji: emoji,
                    color: colorForCategory(categoryName),
                    totalAmount: 0,
                    expenseCount: 0,
                    subcategories: []
                )
            }

            groups[categoryName]?.totalAmount += expense.amount
            groups[categoryName]?.expenseCount += 1

            // Add to subcategory
            let subcategoryName = expense.subcategory ?? "Sin subcategoría"
            if let subIndex = groups[categoryName]?.subcategories.firstIndex(where: {
                $0.name == subcategoryName
            }) {
                groups[categoryName]?.subcategories[subIndex].totalAmount += expense.amount
                groups[categoryName]?.subcategories[subIndex].expenseCount += 1
                groups[categoryName]?.subcategories[subIndex].expenses.append(expense)
            } else {
                groups[categoryName]?.subcategories.append(
                    SubcategoryGroup(
                        name: subcategoryName,
                        totalAmount: expense.amount,
                        expenseCount: 1,
                        expenses: [expense]
                    )
                )
            }
        }

        self.categoryGroups = Array(groups.values).sorted {
            if $0.totalAmount == $1.totalAmount {
                return $0.name < $1.name
            }
            return $0.totalAmount > $1.totalAmount
        }
    }

    // MARK: - Helpers
    private func extractCategoryName(from category: String) -> String {
        let components = category.components(separatedBy: " ")
        return components.first ?? category
    }

    private func extractEmoji(from category: String) -> String {
        // Extract all emoji characters from the string (works with or without spaces)
        return category.filter { scalar in
            scalar.unicodeScalars.contains {
                $0.properties.isEmoji && $0.properties.isEmojiPresentation
            }
        }.map { String($0) }.joined()
    }

    private func colorForCategory(_ name: String) -> Color {
        UserDataManager.shared.color(for: name)
    }
}
