// HomeView.swift
// Main screen implementing Clean Architecture + MVVM
// Restored full functionality: Tabs (List/Graph/Calendar), 3-Card Summary, No Title

import SwiftUI

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    private var userDataManager = UserDataManager.shared
    
    // UI State
    @State private var selectedView = 0 // 0 = Tabla, 1 = Gráfico, 2 = Calendario, 3 = VS
    @State private var expenseToEdit: Expense?
    @State private var showFilterSheet = false
    
    // Voice & FAB
    // showVoiceSheet removed
    @State private var showAddExpense = false // New state for manual entry
    @State private var voiceCoordinator = VoiceExpenseCoordinator()
    @State private var speechManager = SpeechRecognitionManager()
    
    @MainActor
    init(viewModel: HomeViewModel? = nil) {
        let vm = viewModel ?? DependencyContainer.shared.makeHomeViewModel()
        _viewModel = State(initialValue: vm)
    }
    
    var body: some View {
        mainContent
                .background(DesignTokens.Colors.background) // Adaptive background
                .navigationTitle("") // Hidden title as requested
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(DesignTokens.Colors.background, for: .navigationBar)
                .toolbarBackgroundVisibility(.visible, for: .navigationBar)
                .refreshable { await viewModel.refresh() }
                .task { await viewModel.loadExpenses() }
                .sheet(item: $expenseToEdit) { expense in
                    EditExpenseSheet(expense: expense) {
                        Task { await viewModel.refresh() }
                    }
                    .presentationDetents([.large])
                }
                .sheet(isPresented: $showAddExpense) {
                    AddExpenseSheet {
                        Task { await viewModel.refresh() }
                    }
                    .presentationDetents([.large])
                }
                .sheet(isPresented: $showFilterSheet) {
                    ExpenseFilterSheet(
                        filter: $viewModel.selectedFilter,
                        availableCategories: UserDataManager.shared.categoryNames,
                        onApply: {
                            // Trigger reload to fetch data if date range changed
                            Task { await viewModel.loadExpenses() }
                        }
                    )
                }
                // VoiceRecordingSheet removed - migrated to inline VoiceExpenseButton

                .sheet(isPresented: $voiceCoordinator.showConfirmation) {
                    if let expense = voiceCoordinator.pendingExpense {
                        VoiceConfirmationSheet(
                            expense: expense,
                            wasFullyDetected: voiceCoordinator.wasFullyDetected,
                            categories: UserDataManager.shared.categories,
                            speechManager: speechManager,
                            onConfirm: { confirmed in
                                Task {
                                    await voiceCoordinator.saveExpense(confirmed, viewModel: viewModel)
                                    UserDataManager.shared.completeOnboarding() // Sync onboarding
                                }
                            },
                            onCancel: {
                                voiceCoordinator.reset()
                            }
                        )
                    }
                }
                .onChange(of: voiceCoordinator.errorMessage) { _, newValue in
                    if let error = newValue {
                        FeedbackManager.shared.show(.error, title: "Error de Voz", message: error)
                        voiceCoordinator.clearError()
                    }
                }
                // onChange for silence removed - logic moved to VoiceExpenseCoordinator inside Button
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        ZStack(alignment: .bottom) {
            // Views (List, Chart, etc.)
            Group {
                switch selectedView {
                case 0:
                    listView
                case 1:
                    chartView
                case 2:
                    calendarView
                case 3:
                    comparisonView
                default:
                    listView
                }
            }
            .animation(.easeInOut(duration: 0.2), value: selectedView)
            .padding(.bottom, 60) // Space for floating bar
            
            // Floating Bottom Bar
            segmentedPicker
        }
    }

    // MARK: - Bottom Picker
    private var segmentedPicker: some View {
        ZStack(alignment: .bottom) {
            // Centered Pills (Floating Island)
            HStack(spacing: 0) {
                viewModeButton(icon: "list.bullet", index: 0)
                viewModeButton(icon: "chart.pie.fill", index: 1)
                viewModeButton(icon: "calendar", index: 2)
                viewModeButton(icon: "arrow.left.arrow.right", index: 3)
            }
            .padding(4)
            .background(.regularMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
            .frame(maxWidth: .infinity, alignment: .center) // Force center
            
            // Voice Button Aligned Right
            HStack {
                Spacer()
                VoiceExpenseButton(
                    viewModel: viewModel,
                    categories: UserDataManager.shared.categories
                )
                .offset(y: 4) // "mas abajo" slightly to align nicely vs capsule
            }
            .padding(.trailing, DesignTokens.Spacing.md)
        }
        .padding(.bottom, DesignTokens.Spacing.sm)
    }
    
    // MARK: - Tab 1: List View
    private var listView: some View {
        VStack(spacing: 0) {
            // Header Content (Cards + Search) - Fixed at top
            VStack(spacing: DesignTokens.Spacing.sm) {
                // Summary Cards Modernas
                SummaryCardsView(
                    totalExpenses: filteredTotal,
                    expenseCount: viewModel.filteredExpenses.count,
                    savings: savings,
                    savingsPercentage: savings > 0
                        ? Int((savings / (monthlyIncome > 0 ? monthlyIncome : 1)) * 100)
                        : 0,
                    available: savings
                )
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.top, DesignTokens.Spacing.xxs)

                // Search Bar Moderna + Filter Button
                HStack(spacing: DesignTokens.Spacing.xs) {
                    SearchBarView(
                        searchText: $viewModel.searchText,
                        filter: $viewModel.selectedFilter,
                        onFilterChange: {
                            // Handled automatically by ViewModel bindings
                        }
                    )
                    
                    // Clear Filter Button (only if active)
                    if viewModel.selectedFilter.hasActiveFilters {
                        Button {
                            viewModel.selectedFilter = ExpenseFilter() // Reset
                            HapticManager.shared.notification(.success)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(DesignTokens.Colors.textSecondary)
                                .frame(width: 44, height: 44)
                                .background(DesignTokens.Colors.surface)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    Button {
                        showFilterSheet = true
                        HapticManager.shared.selection()
                    } label: {
                        // Purple icon if active filters
                        Image(systemName: viewModel.selectedFilter.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.system(size: 22))
                            .foregroundColor(viewModel.selectedFilter.hasActiveFilters ? DesignTokens.Colors.accent : DesignTokens.Colors.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(DesignTokens.Colors.surface)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                // ActiveFilterPillsView removed as requested
            }
            .background(DesignTokens.Colors.background)

            // List Content - Scrollable
            if viewModel.state == .loading && viewModel.allExpenses.isEmpty {
                loadingView
            } else if case .error(let error) = viewModel.state {
                errorView(error.localizedDescription)
            } else if viewModel.filteredExpenses.isEmpty {
                emptyStateView
            } else {
                ExpandableExpenseList(
                    categories: viewModel.categoryGroups,
                    onExpenseDelete: { expense in
                        Task { await viewModel.deleteExpense(expense) }
                    },
                    onExpenseEdit: { expense in
                        expenseToEdit = expense
                    },
                    onLoadMore: {
                        Task { await viewModel.loadMore() }
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
                    // Donut Chart - Comparativa ahora en tab VS de ExpensesView
                    DonutChartView(
                        categoryData: buildChartData(),
                        total: filteredTotal
                    )
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

    
    private func viewModeButton(icon: String, index: Int) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedView = index
            }
            HapticManager.shared.selection()
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: selectedView == index ? .semibold : .medium)) // Slightly smaller icon
                .foregroundStyle(selectedView == index ? Color.white : Color.primary.opacity(0.5))
                .frame(width: 44, height: 36) // More compact
        }
        .background(
             Capsule()
                 .fill(selectedView == index ? DesignTokens.Colors.accent : Color.clear)
        )
    }
    
    // MARK: - Tab 4: Comparison View (VS)
    private var comparisonView: some View {
        MonthComparisonView(expenses: viewModel.allExpenses)
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
        ExpenseListSkeleton()
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
