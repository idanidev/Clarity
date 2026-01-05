// ExpensesView.swift
// Unified view with Tabla and Gráfica tabs

import SwiftUI

struct ExpensesView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedView = 0 // 0 = Tabla, 1 = Gráfica
    @State private var searchText = ""
    @State private var filter = ExpenseFilter(dateRange: .thisMonth)
    @State private var categoryGroups: [CategoryGroup] = []
    @State private var expenseToEdit: Expense?
    @State private var showEditSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented Control (no interfiere con swipes)
                Picker("Vista", selection: $selectedView) {
                    Text("Tabla").tag(0)
                    Text("Gráfica").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Content based on selection
                if selectedView == 0 {
                    tableContent
                } else {
                    ChartsView()
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("Gastos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadExpenses()
                buildCategoryGroups()
            }
            .onChange(of: viewModel.expenses) { _, _ in
                buildCategoryGroups()
            }
            .onChange(of: filter) { _, _ in
                buildCategoryGroups()
            }
            .onChange(of: searchText) { _, _ in
                buildCategoryGroups()
            }
            .sheet(isPresented: $showEditSheet) {
                if let expense = expenseToEdit {
                    EditExpenseSheet(expense: expense) {
                        Task { await viewModel.refresh() }
                        buildCategoryGroups()
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddExpense) {
                AddExpenseSheet {
                    Task { await viewModel.refresh() }
                }
            }
        }
    }
    
    private var tableContent: some View {
        VStack(spacing: 0) {
            // Stat Cards (compact and beautiful)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    StatCard(
                        title: "Total",
                        value: Formatters.currency(totalExpenses),
                        color: Color.clarityPrimary
                    )
                    
                    StatCard(
                        title: "Gastos",
                        value: "\(filteredExpenses.count)",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Ahorro",
                        value: Formatters.currency(calculateSavings()),
                        color: calculateSavings() >= 0 ? .green : .red
                    )

                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            
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
                filteredEmpty: filteredExpenses.isEmpty,
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
                    showEditSheet = true
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
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    private func calculateSavings() -> Double {
        // Get income from user data (would need to add this to UserDataManager)
        let monthlyIncome = 2700.0 // TODO: Get from Firebase
        return monthlyIncome - totalExpenses
    }

    
    private var filteredExpenses: [Expense] {
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
        
        return expenses
    }
    
    private func buildCategoryGroups() {
        var groups: [String: CategoryGroup] = [:]
        
        for expense in filteredExpenses {
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
    
    private func colorForCategory(_ name: String) -> Color {
        let userDataManager = UserDataManager.shared
        if let category = userDataManager.categories.first(where: { $0.name == name }) {
            return Color(hex: category.color) ?? .gray
        }
        return .gray
    }
}
