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
    private(set) var hasLoaded = false  // Prevents redundant reloads on tab switch

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
                    // Reload with allTime filter when searching so results cross all months;
                    // applyFilters() will skip the date filter while searchText is non-empty.
                    await loadExpenses(silent: true)
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
        let periodExpenses = currentMonthExpenses.reduce(0) { $0 + $1.amount }
        let savingsAllocated = currentMonthlyBudget?.savingsAllocated ?? 0
        return monthlyIncome - periodExpenses - savingsAllocated
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

            if currentMonthlyBudget == nil {
                // Only auto-create for the actual current month (not historical months)
                let calendar2 = Calendar.current
                let realYear = calendar2.component(.year, from: Date())
                let realMonth = calendar2.component(.month, from: Date())
                if year == realYear && month == realMonth {
                    await autoCreateBudgetIfFixedSalary(year: year, month: month)
                }
            }
        } catch {
            logger.error("❌ Error loading budget for \(month)/\(year): \(error.localizedDescription)")
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

        } catch {
            logger.error("❌ Error loading previous month budget: \(error.localizedDescription)")
            previousMonthlyBudget = nil
        }
    }

    /// Auto-creates the monthly budget if the user has a fixed recurring salary configured.
    /// Uses the cached UserDocument from UserDataManager (no extra auth import needed).
    /// FinancialService handles auth internally.
    private func autoCreateBudgetIfFixedSalary(year: Int, month: Int) async {
        let doc = UserDataManager.shared.userDocument
        guard let fixedIncome = doc?.income,
            fixedIncome > 0,
            doc?.settings?.isSalaryRecurring == true
        else { return }

        logger.info(
            "🔄 Nómina fija (€\(fixedIncome)). Creando presupuesto \(month)/\(year) automáticamente..."
        )
        // userId is resolved by FinancialService internally from FirebaseAuth
        let budget = MonthlyBudget(
            userId: "",  // overridden by saveMonthlyBudget
            year: year,
            month: month,
            income: fixedIncome
        )
        do {
            try await financialService.saveMonthlyBudget(budget)
            currentMonthlyBudget = budget
            logger.info("✅ Presupuesto de nómina fija creado: €\(fixedIncome)")
        } catch {
            logger.error("❌ Error auto-creating fixed salary budget: \(error.localizedDescription)")
        }
    }

    // Internal
    private let getExpensesUseCase: GetExpensesUseCase
    private let deleteExpenseUseCase: DeleteExpenseUseCase
    private let addExpenseUseCase: AddExpenseUseCase
    private let recurringRepository = DependencyContainer.shared.recurringExpenseRepository
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
    /// All historical expenses (from cache, not paginated). Used by MonthComparison, Charts.
    private(set) var allHistoricalExpenses: [Expense] = []
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
            self.selectedFilter = ExpenseFilter(dateRange: .thisMonth)
        }
    }

    // MARK: - Intents

    func deleteExpense(_ expense: Expense) async {
        guard let id = expense.id else { return }
        do {
            try await deleteExpenseUseCase.execute(id: id)

            // Rollback linked piggy bank if this expense was a savings contribution
            if let goalId = expense.goalId {
                let comps = Calendar.current.dateComponents([.year, .month], from: expense.dateAsDate)
                if let year = comps.year, let month = comps.month {
                    try? await financialService.refundPiggyBank(goalId: goalId, amount: expense.amount)
                    try? await financialService.updateSavingsAllocated(year: year, month: month, amount: -expense.amount)
                }
            }

            await loadExpenses()
            WidgetDataManager.shared.updateFromExpenses(
                currentMonthExpenses,
                monthBudget: currentMonthlyBudget?.income
            )
            // Avisar a otras VMs (FinancialHub escudos/metas) para refresh inmediato
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
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

    /// Called from .task — skips if data already loaded to avoid re-fetching on tab switch.
    /// Use refresh() or loadExpenses() directly for forced reloads.
    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await loadExpenses()
    }

    func loadExpenses(silent: Bool = false) async {

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
            // Load budget for the SELECTED month (not necessarily current month)
            let calendar = Calendar.current
            let selectedYear = calendar.component(.year, from: selectedMonth)
            let selectedMonthNum = calendar.component(.month, from: selectedMonth)

            do {
                self.currentMonthlyBudget = try await financialService.fetchMonthlyBudget(
                    year: selectedYear, month: selectedMonthNum)
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

            // Launch month-savings and rules fetches in parallel
            async let monthExpensesTask = getExpensesUseCase.executePaginated(
                page: 0, filter: monthOnlyFilter)
            async let rulesTask = recurringRepository.fetchAll()

            // For display:
            // • Searching → use local SwiftData cache (ALL expenses, no Firebase pagination limit)
            //   so annual/old expenses are always findable regardless of month.
            // • Browsing → paginated Firebase fetch with the selected date filter.
            let displayExpenses: [Expense]
            let morePages: Bool
            if !searchText.isEmpty {
                displayExpenses = (try? await getExpensesUseCase.execute()) ?? []
                morePages = false
            } else {
                let result = try await getExpensesUseCase.executePaginated(
                    page: 0, filter: selectedFilter)
                displayExpenses = result.expenses
                morePages = result.hasMore
            }

            let monthResult = try await monthExpensesTask
            let rules = (try? await rulesTask) ?? []
            self.allRecurringRules = rules

            let sanitized = ExpenseSanitizer.sanitize(expenses: displayExpenses, rules: rules)
            let sanitizedMonth = ExpenseSanitizer.sanitize(
                expenses: monthResult.expenses, rules: rules)

            self.allExpenses = sanitized
            self.currentMonthExpenses = sanitizedMonth
            self.hasMorePages = morePages

            // Solo cargar historial completo si está vacío (no en cada keystroke
            // de búsqueda / cada delete). Decodificar cientos de records en
            // @MainActor bloqueaba el hilo en cada loadExpenses.
            if allHistoricalExpenses.isEmpty,
               let allCached = try? await getExpensesUseCase.execute(policy: .cacheFirst()) {
                self.allHistoricalExpenses = ExpenseSanitizer.sanitize(expenses: allCached, rules: rules)
            }

            applyFilters()
            hasLoaded = true

            // ── Widget update ──
            WidgetDataManager.shared.updateFromExpenses(
                sanitizedMonth,
                monthBudget: currentMonthlyBudget?.income
            )
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
            self.allExpenses = deduplicate(expenses: self.allExpenses)
            self.hasMorePages = result.hasMore

            applyFilters()  // Re-apply filters to new full set
        } catch {
            // Silently fail or show toast? For infinite scroll, usually silent or small indicator
            logger.error("Error loading more: \(error)")
            currentPage -= 1  // Revert page logic
        }

        isLoadingMore = false
    }

    func refresh() async {
        await loadExpenses(silent: true)
    }

    /// Inserts an expense directly into in-memory state — no network roundtrip.
    /// Used by the voice flow after a successful save so the UI updates instantly.
    func prependExpense(_ expense: Expense) {
        allExpenses.insert(expense, at: 0)

        // Also add to current-month array if the expense belongs to this month
        let monthPrefix = String(format: "%04d-%02d",
                                 Calendar.current.component(.year, from: Date()),
                                 Calendar.current.component(.month, from: Date()))
        if expense.date.hasPrefix(monthPrefix) {
            currentMonthExpenses.insert(expense, at: 0)
        }

        // Keep UserDataManager in sync so GoalCardView / FinancialDashboard see the new expense
        UserDataManager.shared.expenses.insert(expense, at: 0)

        applyFilters()

        // ── Widget update (inmediato, sin esperar red) ──
        WidgetDataManager.shared.updateFromExpenses(
            currentMonthExpenses,
            monthBudget: currentMonthlyBudget?.income
        )
    }

    /// Removes an expense from in-memory state (used by undo).
    func removeExpense(id: String) {
        allExpenses.removeAll { $0.id == id }
        currentMonthExpenses.removeAll { $0.id == id }
        UserDataManager.shared.expenses.removeAll { $0.id == id }
        applyFilters()
        WidgetDataManager.shared.updateFromExpenses(
            currentMonthExpenses,
            monthBudget: currentMonthlyBudget?.income
        )
    }

    /// Duplicates an expense — saves to repository and refreshes state.
    func duplicateExpense(_ expense: Expense) async throws {
        let duplicated = Expense(
            amount: expense.amount,
            name: expense.name,
            category: expense.category,
            subcategory: expense.subcategory,
            date: Formatters.isoString(from: Date()),
            paymentMethod: expense.paymentMethod,
            notes: expense.notes,
            isDeductible: expense.isDeductible
        )
        let id = try await addExpenseUseCase.execute(duplicated)
        var saved = duplicated
        saved.id = id
        prependExpense(saved)
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

        // When searching we already fetched allTime data, so skip the date filter here.
        // Otherwise, filter by the selected date range.
        var result: [Expense]
        if !searchText.isEmpty {
            dateFilteredExpenses = allExpenses
            result = allExpenses
        } else {
            let (startStr, endStr) = selectedFilter.dateRangeForQuery()
            dateFilteredExpenses = allExpenses.filter { expense in
                expense.date >= startStr && expense.date <= endStr
            }
            result = dateFilteredExpenses
        }

        // Search
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.category.localizedCaseInsensitiveContains(searchText)
                    || ($0.subcategory?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        // Category Filter — pre-normaliza UNA vez las categorías del filtro
        // (antes recreaba la closure + normalizaba por cada par gasto×categoría).
        if !selectedFilter.selectedCategories.isEmpty {
            func firstWord(_ s: String) -> String {
                s.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .replacingOccurrences(of: " / ", with: " ")
                    .replacingOccurrences(of: " - ", with: " ")
                    .components(separatedBy: " ").first ?? ""
            }
            let filterFirstWords = Set(selectedFilter.selectedCategories.map(firstWord))
            result = result.filter { filterFirstWords.contains(firstWord($0.category)) }
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
