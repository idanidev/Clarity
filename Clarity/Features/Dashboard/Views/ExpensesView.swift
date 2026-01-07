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
    @State private var showFilterSheet = false
    
    
    var body: some View {
        mainContent
            .background(.regularMaterial)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarBackgroundVisibility(.automatic, for: .navigationBar)
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
            .sheet(isPresented: $showFilterSheet) {
                FilterSheet(
                    searchText: $searchText,
                    filter: $filter,
                    onApply: {
                        updateFilteredExpenses()
                        buildCategoryGroups()
                    }
                )
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
                        DonutChartContent(viewModel: viewModel, filter: filter)
                    }
                case 2:
                    VStack(spacing: 0) {
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
    // MARK: - Bottom Toolbar (Filter + View Modes)
    private var segmentedPicker: some View {
        HStack {
            // Left spacer to balance filter button
            Color.clear.frame(width: 60, height: 1)
            
            Spacer()
            
            // View Mode Selector (Icons) - CENTERED
            HStack(spacing: 0) {
                viewModeButton(icon: "list.bullet", index: 0)
                viewModeButton(icon: "chart.pie.fill", index: 1)
                viewModeButton(icon: "calendar", index: 2)
            }
            .background(Capsule().fill(Color.bgTertiary))
            
            Spacer()
            
            // Clear + Filter buttons (Right)
            HStack(spacing: 4) {
                if filter.hasActiveFilters || !searchText.isEmpty {
                    Button {
                        filter = ExpenseFilter(dateRange: .thisMonth)
                        searchText = ""
                        updateFilteredExpenses()
                        buildCategoryGroups()
                        HapticManager.notification(.success)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Menu {
                    Section("Período") {
                        ForEach(ExpenseFilter.DateRange.allCases, id: \.self) { range in
                            Button {
                                filter.dateRange = range
                                updateFilteredExpenses()
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
                    
                    Section("Método de Pago") {
                        ForEach(["Tarjeta", "Efectivo", "Bizum", "Transferencia"], id: \.self) { method in
                            Button {
                                if filter.selectedPaymentMethods.contains(method) {
                                    filter.selectedPaymentMethods.remove(method)
                                } else {
                                    filter.selectedPaymentMethods.insert(method)
                                }
                                updateFilteredExpenses()
                                HapticManager.selection()
                            } label: {
                                HStack {
                                    Text(method)
                                    if filter.selectedPaymentMethods.contains(method) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    Button {
                        showFilterSheet = true
                    } label: {
                        Label("Más filtros...", systemImage: "slider.horizontal.3")
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle" + (filter.hasActiveFilters || !searchText.isEmpty ? ".fill" : ""))
                        .font(.system(size: 22))
                        .foregroundStyle(filter.hasActiveFilters || !searchText.isEmpty ? Color.clarityPrimary : .secondary)
                }
            }
            .frame(width: 60)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
    }
    
    private func viewModeButton(icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedView = index
            }
            HapticManager.selection()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: selectedView == index ? .semibold : .regular))
                .foregroundStyle(selectedView == index ? Color.clarityPrimary : .secondary)
                .frame(width: 50, height: 32)
        }
        .background(
             Capsule()
                 .fill(selectedView == index ? Color.clarityPrimary.opacity(0.15) : Color.clear)
        )
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
        VStack(spacing: 16) {
            // Stat Cards (3 cards, responsive - fill width)
            HStack(spacing: 12) {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Active filter pills (kept for feedback)
            ActiveFilterPillsView(
                filter: $filter,
                onFilterChange: onBuildCategoryGroups
            )
            .padding(.top, 4)
            
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
        // Get income from Firebase user document
        let monthlyIncome = UserDataManager.shared.userDocument?.income ?? 0
        guard monthlyIncome > 0 else { return 0 }
        
        // Calculate pro-rata: what % of the month has passed?
        let calendar = Calendar.current
        let today = Date()
        let day = calendar.component(.day, from: today)
        let daysInMonth = calendar.range(of: .day, in: .month, for: today)?.count ?? 30
        let monthProgress = Double(day) / Double(daysInMonth)
        
        // Expected spending so far = income * progress
        // If we spent less than expected, we're "saving"
        let expectedSpending = monthlyIncome * monthProgress
        let actualSpending = totalExpenses
        
        // Positive = under budget (saving), Negative = over budget
        return expectedSpending - actualSpending
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

// MARK: - Filter Sheet
struct FilterSheet: View {
    @Binding var searchText: String
    @Binding var filter: ExpenseFilter
    let onApply: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                // Search Section
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Buscar gastos, categorías...", text: $searchText)
                    }
                } header: {
                    Text("Búsqueda")
                }
                
                // Date Range Section
                Section {
                    Picker("Periodo", selection: $filter.dateRange) {
                        ForEach(ExpenseFilter.DateRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                } header: {
                    Text("Fecha")
                }
                
                // Payment Method Section
                Section {
                    ForEach(["Tarjeta", "Efectivo", "Bizum", "Transferencia"], id: \.self) { method in
                        Button {
                            if filter.selectedPaymentMethods.contains(method) {
                                filter.selectedPaymentMethods.remove(method)
                            } else {
                                filter.selectedPaymentMethods.insert(method)
                            }
                        } label: {
                            HStack {
                                Text(method)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if filter.selectedPaymentMethods.contains(method) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.clarityPrimary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Método de Pago")
                }
                
                // Categories would go here if needed, or rely on search
                
                if filter.hasActiveFilters || !searchText.isEmpty {
                    Section {
                        Button("Limpiar todos los filtros", role: .destructive) {
                            filter = ExpenseFilter()
                            searchText = ""
                        }
                    }
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
