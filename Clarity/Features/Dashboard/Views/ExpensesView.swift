// ExpensesView.swift
// Unified view with Tabla and Gráfica tabs

import SwiftUI

struct ExpensesView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var selectedView = 0 // 0 = Tabla, 1 = Gráfico, 2 = Calendario
    @State private var searchText = ""
    @State private var filter = ExpenseFilter(dateRange: .thisMonth)
    @State private var categoryGroups: [CategoryGroup] = []
    @State private var expenseToEdit: Expense?
    
    // Cache for performance
    @State private var cachedFilteredExpenses: [Expense] = []
    
    
    var body: some View {
        NavigationStack {
            mainContent
                .background(.regularMaterial)
                .navigationTitle("Gastos")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
                .toolbar { filterToolbar }
                .refreshable { await viewModel.refresh() }
                .task {
                    await viewModel.loadExpenses()
                    updateFilteredExpenses()
                }
                .onChange(of: viewModel.expenses) { _, _ in updateFilteredExpenses() }
                .onChange(of: filter) { _, _ in updateFilteredExpenses() }
                .onChange(of: searchText) { _, _ in updateFilteredExpenses() }
                .onChange(of: cachedFilteredExpenses) { _, _ in buildCategoryGroups() }
                .sheet(item: $expenseToEdit) { expense in
                    editSheet(for: expense)
                }
                .sheet(isPresented: $viewModel.showAddExpense) { addSheet }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Content based on selection - no TabView swipe to conflict with list swipes
            Group {
                switch selectedView {
                case 0:
                    tableContent
                case 1:
                    VStack(spacing: 0) {
                        filterBar
                        DonutChartContent(viewModel: viewModel, filter: filter)
                    }
                case 2:
                    VStack(spacing: 0) {
                        filterBar
                        CalendarChartContent(viewModel: viewModel)
                    }
                default:
                    tableContent
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedView)
            .onChange(of: selectedView) { _, _ in
                HapticManager.selection()
            }
            
            // Picker at bottom - more accessible for thumb
            segmentedPicker
        }
    }
    
    // MARK: - Segmented Picker
    private var segmentedPicker: some View {
        Picker("Vista", selection: $selectedView) {
            Text("Tabla").tag(0)
            Text("Gráfico").tag(1)
            Text("Calendario").tag(2)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Filter Bar (for charts)
    private var filterBar: some View {
        HStack {
            Spacer()
            
            Menu {
                Section("Período") {
                    ForEach(ExpenseFilter.DateRange.allCases, id: \.self) { range in
                        Button {
                            filter.dateRange = range
                            HapticManager.selection()
                        } label: {
                            HStack {
                                Text(range.rawValue)
                                if filter.dateRange == range {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(filter.dateRange.rawValue)
                        .font(.subheadline)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal)
        .padding(.vertical, Spacing.xs)
    }
    
    // MARK: - Filter Toolbar (empty for now)
    @ToolbarContentBuilder
    private var filterToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            EmptyView()
        }
    }
    
    // MARK: - Sheets
    private func editSheet(for expense: Expense) -> some View {
        EditExpenseSheet(expense: expense) {
            Task { await viewModel.refresh() }
            buildCategoryGroups()
        }
        .presentationDetents([.large])
        .presentationBackground(.regularMaterial)
    }
    
    private var addSheet: some View {
        AddExpenseSheet {
            Task { await viewModel.refresh() }
        }
        .presentationDetents([.large])
        .presentationBackground(.regularMaterial)
    }
    
    private var tableContent: some View {
        VStack(spacing: 0) {
            // Stat Cards (3 cards, responsive - fill width)
            HStack(spacing: 8) {
                StatCard(
                    title: "Total",
                    value: Formatters.currency(totalExpenses),
                    color: Color.clarityPrimary
                )
                
                StatCard(
                    title: "Gastos",
                    value: "\(cachedFilteredExpenses.count)",
                    color: .blue
                )
                
                StatCard(
                    title: "Ahorro",
                    value: Formatters.currency(calculateSavings()),
                    color: calculateSavings() >= 0 ? .green : .red
                )
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Search Bar
            SearchBarView(
                searchText: $searchText,
                filter: $filter,
                onFilterChange: onBuildCategoryGroups
            )
            .padding(.horizontal)
            .padding(.top, 4)
            
            // Active filter pills
            ActiveFilterPillsView(
                filter: $filter,
                onFilterChange: onBuildCategoryGroups
            )
            
            // Content
            ExpenseListContent(
                isLoading: viewModel.isLoading,
                expensesEmpty: viewModel.expenses.isEmpty,
                filteredEmpty: cachedFilteredExpenses.isEmpty,
                activeFilters: filter.hasActiveFilters,
                groupsEmpty: categoryGroups.isEmpty,
                categoryGroups: $categoryGroups,
                onDelete: { expense in
                    Task {
                        await viewModel.deleteExpense(expense)
                        HapticManager.notification(.success)
                    }
                },
                onEdit: { expense in
                    expenseToEdit = expense
                },
                onDuplicate: duplicateExpense,
                onClearFilters: {
                    filter = ExpenseFilter(dateRange: .thisMonth)
                    searchText = ""
                }
            )
        }
    }
    
    private var totalExpenses: Double {
        cachedFilteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    private func calculateSavings() -> Double {
        // Get income from BudgetsViewModel or default to 0
        let monthlyIncome = 2700.0  // This should come from user data
        return monthlyIncome - totalExpenses
    }
    
    private func updateFilteredExpenses() {
        var expenses = viewModel.expenses
        
        // Deduplicate
        var seen = Set<String>()
        expenses = expenses.filter { expense in
            guard let id = expense.id, !id.isEmpty else { return true }
            if seen.contains(id) { return false }
            seen.insert(id)
            return true
        }
        
        // Date filter
        let dateRange = filter.dateRangeForQuery()
        expenses = expenses.filter { $0.date >= dateRange.0 && $0.date <= dateRange.1 }
        
        // Search filter
        if !searchText.isEmpty {
            expenses = expenses.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                ($0.subcategory?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Category filter
        if !filter.selectedCategories.isEmpty {
            expenses = expenses.filter { expense in
                filter.selectedCategories.contains { category in
                    expense.category.localizedCaseInsensitiveContains(category.components(separatedBy: " ").first ?? category)
                }
            }
        }
        
        // Payment method filter
        if !filter.selectedPaymentMethods.isEmpty {
            expenses = expenses.filter { filter.selectedPaymentMethods.contains($0.paymentMethod) }
        }
        
        self.cachedFilteredExpenses = expenses
    }
    
    private func buildCategoryGroups() {
        var groups: [String: CategoryGroup] = [:]
        
        for expense in cachedFilteredExpenses {
            let categoryName = extractCategoryName(from: expense.category)
            let emoji = extractEmoji(from: expense.category)
            
            if groups[categoryName] == nil {
                groups[categoryName] = CategoryGroup(
                    name: categoryName,
                    emoji: emoji,
                    color: colorForCategory(expense.category),  // Use full category name with emoji
                    totalAmount: 0,
                    expenseCount: 0,
                    subcategories: []
                )
            }
            
            groups[categoryName]?.totalAmount += expense.amount
            groups[categoryName]?.expenseCount += 1
            
            let subcategoryName = expense.subcategory ?? "Sin subcategoría"
            if let subIndex = groups[categoryName]?.subcategories.firstIndex(where: { $0.name == subcategoryName }) {
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
        
        categoryGroups = Array(groups.values).sorted { $0.totalAmount > $1.totalAmount }
    }
    
    private func onBuildCategoryGroups() {
        buildCategoryGroups()
    }
    
    private func duplicateExpense(_ expense: Expense) {
        Task {
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
            
            do {
                _ = try await ExpenseRepository().addExpense(duplicated)
                await viewModel.refresh()
                buildCategoryGroups()
                HapticManager.notification(.success)
            } catch {
                print("Error duplicating expense: \(error)")
            }
        }
    }
    
    private func extractCategoryName(from category: String) -> String {
        category.components(separatedBy: " ").first ?? category
    }
    
    private func extractEmoji(from category: String) -> String {
        let components = category.components(separatedBy: " ")
        return components.count > 1 ? components.last ?? "" : ""
    }
    
    private func colorForCategory(_ categoryWithEmoji: String) -> Color {
        // Categories in Firebase use full names like "Alimentacion🫄" 
        // So we need to match the full original expense.category
        let userDataManager = UserDataManager.shared
        
        // First try exact match with the full category name from expense
        if let category = userDataManager.categories.first(where: { 
            $0.name.localizedCaseInsensitiveContains(categoryWithEmoji) ||
            categoryWithEmoji.localizedCaseInsensitiveContains($0.name.components(separatedBy: " ").first ?? $0.name)
        }) {
            return Color(hex: category.color) ?? .gray
        }
        
        // Fallback to default color
        return UserDataManager.shared.color(for: categoryWithEmoji)
    }
}
