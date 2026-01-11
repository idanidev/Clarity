// DashboardView.swift
// Main dashboard with summary cards and expandable expense table

import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @ObservedObject private var userDataManager = UserDataManager.shared
    @State private var searchText = ""
    @State private var filter = ExpenseFilter(dateRange: .thisMonth)
    @State private var categoryGroups: [CategoryGroup] = []
    @State private var expenseToEdit: Expense? = nil
    @State private var showEditSheet = false
    
    var body: some View {
        NavigationStack {
            MainContent(
                viewModel: viewModel,
                searchText: $searchText,
                filter: $filter,
                categoryGroups: $categoryGroups,
                expenseToEdit: $expenseToEdit,
                showEditSheet: $showEditSheet,
                filteredExpenses: filteredExpenses,
                dateFilteredExpenses: dateFilteredExpenses,
                onBuildCategoryGroups: buildCategoryGroups,
                onExpenseDuplicate: duplicateExpense
            )
            .background(Color.black)
            .navigationTitle("Gastos")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
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
    
    // Build hierarchical category groups from flat expense list
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
            
            // Add to subcategory
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
                _ = try await DependencyContainer.shared.expenseRepository.addExpense(duplicated)
                await viewModel.refresh()
                buildCategoryGroups()
                HapticManager.notification(.success)
            } catch {
                print("Error duplicating expense: \(error)")
            }
        }
    }
    
    // MARK: - Filter Logic
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
        // Deduplicate based on document ID (in case Firebase returns duplicates)
        var seen = Set<String>()
        expenses = expenses.filter { expense in
            guard let id = expense.id, !id.isEmpty else { return true }
            if seen.contains(id) {
                return false
            }
            seen.insert(id)
            return true
        }
        
        // Apply date range filter
        let dateRange = filter.dateRangeForQuery()
        expenses = expenses.filter { expense in
            expense.date >= dateRange.0 && expense.date <= dateRange.1
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            expenses = expenses.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText) ||
                ($0.subcategory?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply category filter
        if !filter.selectedCategories.isEmpty {
            expenses = expenses.filter { expense in
                filter.selectedCategories.contains { category in
                    expense.category.localizedCaseInsensitiveContains(category.components(separatedBy: " ").first ?? category)
                }
            }
        }
        
        // Apply payment method filter
        if !filter.selectedPaymentMethods.isEmpty {
            expenses = expenses.filter { expense in
                filter.selectedPaymentMethods.contains(expense.paymentMethod)
            }
        }
        
        return expenses
    }
    
    private var dateFilteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
        // Deduplicate
        var seen = Set<String>()
        expenses = expenses.filter { expense in
            guard let id = expense.id, !id.isEmpty else { return true }
            if seen.contains(id) { return false }
            seen.insert(id)
            return true
        }
        
        // Apply date range filter ONLY
        let dateRange = filter.dateRangeForQuery()
        return expenses.filter { expense in
            expense.date >= dateRange.0 && expense.date <= dateRange.1
        }
    }
    
    // MARK: - Helpers
    private func extractCategoryName(from category: String) -> String {
        let components = category.components(separatedBy: " ")
        return components.first ?? category
    }
    
    private func extractEmoji(from category: String) -> String {
        let components = category.components(separatedBy: " ")
        return components.count > 1 ? components.last ?? "" : ""
    }
    
    private func colorForCategory(_ categoryWithEmoji: String) -> Color {
        // Categories in Firebase use full names like "Alimentacion🫄"
        // So we need to match the full original expense.category
        let userDataManager = UserDataManager.shared
        
        // 1. Clean the input (take first word/component to avoid emoji mismatch)
         let cleanInput = categoryWithEmoji.components(separatedBy: " ").first ?? categoryWithEmoji
        
        // 2. Try to find a category where the clean name matches (robust against emoji differences)
        if let category = userDataManager.categories.first(where: { 
            let cleanStored = $0.name.components(separatedBy: " ").first ?? $0.name
            return cleanStored.localizedCaseInsensitiveCompare(cleanInput) == .orderedSame
        }) {
            return Color(hex: category.color) ?? .gray
        }

        // 3. Fallback: Fuzzy containment scan
        if let category = userDataManager.categories.first(where: {
            $0.name.localizedCaseInsensitiveContains(cleanInput) ||
            cleanInput.localizedCaseInsensitiveContains($0.name)
        }) {
             return Color(hex: category.color) ?? .gray
        }
        
        // 4. Final fallback
        return Color(hex: "#6B7280")!
    }
}

// MARK: - Subviews

struct MainContent: View {
    var viewModel: DashboardViewModel
    @Binding var searchText: String
    @Binding var filter: ExpenseFilter
    @Binding var categoryGroups: [CategoryGroup]
    @Binding var expenseToEdit: Expense?
    @Binding var showEditSheet: Bool
    let filteredExpenses: [Expense]
    let dateFilteredExpenses: [Expense]
    let onBuildCategoryGroups: () -> Void
    let onExpenseDuplicate: (Expense) -> Void
    
    // Total of expenses shown in list (respects all filters)
    private var filteredTotal: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    // Total of expenses in date range (ignores category/search)
    private var dateFilteredTotal: Double {
        dateFilteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    // User Income
    private var monthlyIncome: Double {
        UserDataManager.shared.userDocument?.income ?? 0
    }
    
    // Savings = Income - DateFilteredExpenses
    private var savings: Double {
        monthlyIncome - dateFilteredTotal
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Summary Cards
            SummaryCardsView(
                totalExpenses: filteredTotal,
                expenseCount: filteredExpenses.count,
                savings: savings,
                savingsPercentage: monthlyIncome > 0 ? Int((savings / monthlyIncome) * 100) : 0,
                available: savings // Available is typically same as savings (remaining budget)
            )
            .padding(.horizontal)
            .padding(.top, 4)
            
            // Search Bar with native iOS Menu filter
            SearchBarView(
                searchText: $searchText,
                filter: $filter,
                onFilterChange: onBuildCategoryGroups
            )
            .padding(.horizontal)
            .padding(.top, 6)
            
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
                onDuplicate: onExpenseDuplicate,
                onClearFilters: {
                    filter = ExpenseFilter()
                    onBuildCategoryGroups()
                }
            )
        }
    }
}

struct ExpenseListContent: View {
    let isLoading: Bool
    let expensesEmpty: Bool
    let filteredEmpty: Bool
    let activeFilters: Bool
    let groupsEmpty: Bool
    @Binding var categoryGroups: [CategoryGroup]
    let onDelete: (Expense) -> Void
    let onEdit: (Expense) -> Void
    let onDuplicate: (Expense) -> Void
    let onClearFilters: () -> Void
    
    var body: some View {
        if isLoading {
            List {
                ForEach(0..<5) { _ in
                    HStack {
                        SkeletonView().frame(width: 40, height: 40).cornerRadius(20)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonView().frame(width: 150, height: 16)
                            SkeletonView().frame(width: 100, height: 12)
                        }
                        Spacer()
                        SkeletonView().frame(width: 80, height: 20)
                    }
                    .padding(.vertical, 8)
                    .listRowBackground(Color.bgPrimary)
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(.regularMaterial)
        } else if expensesEmpty {
            Spacer()
            ContentUnavailableView {
                Label("Sin gastos", systemImage: "wallet.bifold")
            } description: {
                Text("Añade tu primer gasto del mes")
            }
            Spacer()
        } else if filteredEmpty && activeFilters {
            Spacer()
            VStack(spacing: Spacing.md) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                
                Text("Sin resultados")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                
                Text("No hay gastos que coincidan con tus filtros")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Button(action: onClearFilters) {
                    Text("Limpiar filtros")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.clarityPrimary)
                }
                .padding(.top, Spacing.sm)
            }
            Spacer()
        } else if groupsEmpty {
            Spacer()
            ProgressView().tint(Color.clarityPrimary)
            Spacer()
        } else {
            ExpandableExpenseList(
                categories: $categoryGroups,
                onExpenseDelete: onDelete,
                onExpenseEdit: onEdit,
                onExpenseDuplicate: onDuplicate
            )
        }
    }
}

#Preview {
    DashboardView()
}
