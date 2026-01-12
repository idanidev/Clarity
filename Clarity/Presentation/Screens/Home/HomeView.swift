// HomeView.swift
// Main screen implementing Clean Architecture + MVVM
// Restored full functionality: Tabs (List/Graph/Calendar), 3-Card Summary, No Title

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @ObservedObject private var userDataManager = UserDataManager.shared
    
    // UI State
    @State private var selectedView = 0 // 0 = Tabla, 1 = Gráfico, 2 = Calendario
    @State private var expenseToEdit: Expense?
    @State private var showEditSheet = false
    @State private var showFilterSheet = false
    
    @MainActor
    init(viewModel: HomeViewModel? = nil) {
        let vm = viewModel ?? DependencyContainer.shared.makeHomeViewModel()
        _viewModel = StateObject(wrappedValue: vm)
    }
    
    var body: some View {
        NavigationStack {
            mainContent
                .background(Color.black) // Nuclear Black option
                .navigationTitle("") // Hidden title as requested
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
                .refreshable { await viewModel.refresh() }
                .task { await viewModel.loadExpenses() }
                .sheet(isPresented: $showEditSheet) {
                    if let expense = expenseToEdit {
                        EditExpenseSheet(expense: expense) {
                            Task { await viewModel.refresh() }
                        }
                    }
                }
                .sheet(isPresented: $showFilterSheet) {
                    ExpenseFilterSheet(
                        filter: $viewModel.selectedFilter,
                        availableCategories: Array(Set(viewModel.allExpenses.map { $0.category })),
                        onApply: {
                            // Filter is bound to ViewModel, changes auto-trigger
                        }
                    )
                }
        }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            Group {
                switch selectedView {
                case 0:
                    listView
                case 1:
                    chartView
                case 2:
                    calendarView
                default:
                    listView
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedView)
            
            // Bottom Picker (Tabs)
            segmentedPicker
        }
    }
    
    // MARK: - Tab 1: List View
    private var listView: some View {
        VStack(spacing: 16) {
            // Stat Cards (3 cards)
            HStack(spacing: 12) {
                StatCard(
                    title: "Total",
                    value: formatCurrency(filteredTotal),
                    color: Color.clarityPrimary
                )
                
                StatCard(
                    title: "Gastos",
                    value: "\(viewModel.filteredExpenses.count)",
                    color: .blue
                )
                
                StatCard(
                    title: "Ahorro",
                    value: formatCurrency(savings),
                    color: savings >= 0 ? .green : .red
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Search Bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Buscar gastos...", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                
                if !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.searchText = ""
                        HapticManager.selection()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black) // Hardcoded Black
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            
            // Active Filters
            ActiveFilterPillsView(
                filter: $viewModel.selectedFilter,
                onFilterChange: { /* Auto-handled */ }
            )
            .padding(.top, 4)
            
            // List Content
            if viewModel.state == .loading && viewModel.allExpenses.isEmpty {
                loadingView
            } else if case .error(let msg) = viewModel.state {
                errorView(msg)
            } else if viewModel.filteredExpenses.isEmpty {
                emptyStateView
            } else {
                ExpandableExpenseList(
                    categories: $viewModel.categoryGroups,
                    onExpenseDelete: { expense in
                        Task { await viewModel.deleteExpense(expense) }
                    },
                    onExpenseEdit: { expense in
                        expenseToEdit = expense
                        showEditSheet = true
                    },
                    onExpenseDuplicate: { expense in
                        Task { await viewModel.duplicateExpense(expense) }
                    }
                )
            }
        }
    }
    
    // MARK: - Tab 2: Chart View
    private var chartView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if viewModel.filteredExpenses.isEmpty {
                   ContentUnavailableView("Sin datos para gráficos", systemImage: "chart.pie")
                } else {
                    // Donut Chart
                    DonutChartView(
                        categoryData: buildChartData(),
                        total: filteredTotal
                    )
                    
                    // Comparison
                    MonthComparisonChart(expenses: viewModel.allExpenses)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 80)
        }
    }
    
    // MARK: - Tab 3: Calendar View
    private var calendarView: some View {
        VStack {
            if viewModel.allExpenses.isEmpty {
                ContentUnavailableView("Sin datos para calendario", systemImage: "calendar")
            } else {
                ExpenseCalendarView(expenses: viewModel.allExpenses)
            }
        }
    }

    // MARK: - Bottom Picker
    private var segmentedPicker: some View {
        HStack {
            Color.clear.frame(width: 60, height: 1)
            Spacer()
            
            HStack(spacing: 0) {
                viewModeButton(icon: "list.bullet", index: 0)
                viewModeButton(icon: "chart.pie.fill", index: 1)
                viewModeButton(icon: "calendar", index: 2)
            }
            .background(Capsule().fill(Color.bgTertiary))
            
            Spacer()
            
            // Buttons Right
            HStack(spacing: 4) {
                 if viewModel.selectedFilter.hasActiveFilters || !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.selectedFilter = ExpenseFilter()
                        viewModel.searchText = ""
                        HapticManager.notification(.success)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    showFilterSheet = true
                    HapticManager.selection()
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle" + (viewModel.selectedFilter.hasActiveFilters ? ".fill" : ""))
                        .font(.system(size: 22))
                        .foregroundStyle(viewModel.selectedFilter.hasActiveFilters ? Color.clarityPrimary : .secondary)
                }
            }
            .frame(width: 60)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(Color.black) // Hardcoded Black, NO material
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
    
    // MARK: - Helpers
    private var monthlyIncome: Double {
        userDataManager.userDocument?.income ?? 0
    }
    
    private var filteredTotal: Double {
        viewModel.filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    private var dateFilteredTotal: Double {
        viewModel.dateFilteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    private var savings: Double {
        monthlyIncome - dateFilteredTotal
    }
    
    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "€"
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f €", value)
    }
    
    private func buildChartData() -> [CategoryChartData] {
        var categoryTotals: [String: (amount: Double, color: Color)] = [:]
        
        for expense in viewModel.filteredExpenses {
            let category = expense.category
            let currentTotal = categoryTotals[category]?.amount ?? 0
            let color = UserDataManager.shared.color(for: category)
            categoryTotals[category] = (currentTotal + expense.amount, color)
        }
        
        return categoryTotals.map { key, value in
            CategoryChartData(
                name: key,
                amount: value.amount,
                percentage: filteredTotal > 0 ? (value.amount / filteredTotal) * 100 : 0,
                color: value.color
            )
        }.sorted { $0.amount > $1.amount }
    }
    
    // MARK: - View States
    private var loadingView: some View {
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
    }
    
    private var emptyStateView: some View {
        VStack {
            Spacer()
            ContentUnavailableView {
                Label("Sin gastos", systemImage: "wallet.bifold")
            } description: {
                Text("Añade tu primer gasto del mes")
            }
            Spacer()
        }
    }
    
    private func errorView(_ msg: String) -> some View {
        ContentUnavailableView {
            Label("Error", systemImage: "exclamationmark.triangle")
        } description: {
            Text(msg)
        } actions: {
            Button("Reintentar") {
                Task { await viewModel.loadExpenses() }
            }
        }
    }
}

#Preview {
    HomeView()
}
