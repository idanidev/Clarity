// ExpensesView.swift
// Unified view with Tabla and Gráfica tabs

import SwiftUI
import TipKit

struct ExpensesView: View {
    @State private var viewModel = DependencyContainer.shared.makeHomeViewModel() // Updated
    @State private var selectedView = 0 // 0 = Tabla, 1 = Gráfico, 2 = Calendario
    @State private var expenseToEdit: Expense?
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
            }
            // ViewModel handles updates automatically via @Observable
            .sheet(item: $expenseToEdit) { expense in
                editSheet(for: expense)
            }
            .sheet(isPresented: $viewModel.showAddExpense) { addSheet }
            .sheet(isPresented: $showFilterSheet) {
                ExpenseFilterSheet(
                    filter: $viewModel.selectedFilter, // Updated
                    availableCategories: Array(Set(viewModel.allExpenses.map { $0.category })), // Updated
                    onApply: {
                        // Filters apply auto via binding
                    }
                )
            }
    }
    
    // MARK: - Main Content
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Vista actual
            ZStack {
                if selectedView == 0 {
                    tableView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else if selectedView == 1 {
                    donutChartView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else if selectedView == 2 {
                    calendarView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                } else {
                    comparisonView
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: selectedView)

            // Picker at bottom
            segmentedPicker
        }
    }
    
    // Helper para empty states
    private func emptyStateMockup(icon: String, title: String, subtitle: String) -> some View {
        Section {
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.title2.bold())
                Text(subtitle)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 60)
            .padding(.bottom, 60)
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    // MARK: - Segmented Picker
    private var segmentedPicker: some View {
        VStack(spacing: 8) {
            // Fila superior: Botones de filtro
            HStack {
                HStack(spacing: 8) {
                    if viewModel.selectedFilter.hasActiveFilters || !viewModel.searchText.isEmpty { // Updated
                        Button {
                            viewModel.selectedFilter = ExpenseFilter(dateRange: .thisMonth) // Updated
                            viewModel.searchText = ""
                            HapticManager.shared.notification(.success)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                Text("Limpiar")
                                    .font(.system(size: 13, weight: .medium))
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemFill))
                            .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Button {
                    showFilterSheet = true
                    HapticManager.shared.selection()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.system(size: 16))
                        Text("Filtros")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(viewModel.selectedFilter.hasActiveFilters || !viewModel.searchText.isEmpty ? Color.clarityPrimary : .secondary) // Updated
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(viewModel.selectedFilter.hasActiveFilters ? Color.clarityPrimary.opacity(0.15) : Color(.tertiarySystemFill))
                    .clipShape(Capsule())
                }
                .popoverTip(FilterTip())
            }
            .padding(.horizontal, Spacing.md)

            // DEBUG: 4 BOTONES FORZADOS con colores diferentes
            HStack(spacing: 8) {
                // Botón 1: Lista (AZUL)
                Button {
                    selectedView = 0
                    print("🔵 Seleccionado: LISTA (0)")
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(selectedView == 0 ? .white : .blue)
                        .frame(width: 44, height: 44)
                        .background(selectedView == 0 ? Color.blue : Color.blue.opacity(0.2))
                        .clipShape(Circle())
                }
                
                // Botón 2: Gráfico (VERDE)
                Button {
                    selectedView = 1
                    print("🟢 Seleccionado: GRÁFICO (1)")
                } label: {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(selectedView == 1 ? .white : .green)
                        .frame(width: 44, height: 44)
                        .background(selectedView == 1 ? Color.green : Color.green.opacity(0.2))
                        .clipShape(Circle())
                }
                
                // Botón 3: Calendario (NARANJA)
                Button {
                    selectedView = 2
                    print("🟠 Seleccionado: CALENDARIO (2)")
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(selectedView == 2 ? .white : .orange)
                        .frame(width: 44, height: 44)
                        .background(selectedView == 2 ? Color.orange : Color.orange.opacity(0.2))
                        .clipShape(Circle())
                }
                
                // Botón 4: VS COMPARACIÓN (ROJO - IMPOSIBLE DE IGNORAR)
                Button {
                    selectedView = 3
                    print("🔴 Seleccionado: VS COMPARACIÓN (3)")
                } label: {
                    Text("VS")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(selectedView == 3 ? .white : .red)
                        .frame(width: 44, height: 44)
                        .background(selectedView == 3 ? Color.red : Color.red.opacity(0.2))
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .strokeBorder(Color.red, lineWidth: 2)
                        )
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            )
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.sm)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Computed Views for Optimization
    
    private var tableView: some View {
        List {
            headerSection
            listContent
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
    }
    
    private var headerSection: some View {
        Section {
            VStack(spacing: 16) {
                SummaryCardsView(
                    totalExpenses: viewModel.totalFilteredAmount,
                    expenseCount: viewModel.filteredExpenses.count,
                    savings: viewModel.calculatedSavings,
                    savingsPercentage: viewModel.calculatedSavings > 0
                        ? Int((viewModel.calculatedSavings / (UserDataManager.shared.userDocument?.income ?? 1)) * 100)
                        : 0,
                    available: viewModel.calculatedSavings
                )
                .padding(.top, 4)
                
                SearchBarView(
                    searchText: $viewModel.searchText,
                    filter: $viewModel.selectedFilter, // Updated
                    onFilterChange: {}
                )
                
                ActiveFilterPillsView(
                    filter: $viewModel.selectedFilter, // Updated
                    onFilterChange: {}
                )
            }
        }
        .listRowInsets(EdgeInsets())
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }
    
    @ViewBuilder
    private var listContent: some View {
        if viewModel.state == .loading { // Updated
            ProgressView()
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
        } else if viewModel.allExpenses.isEmpty { // Updated
            emptyStateMockup(
                icon: "wallet.bifold",
                title: "Sin gastos",
                subtitle: "Añade tu primer gasto del mes"
            )
        } else if viewModel.filteredExpenses.isEmpty && viewModel.selectedFilter.hasActiveFilters { // Updated
            emptyStateMockup(
                icon: "line.3.horizontal.decrease.circle",
                title: "Sin resultados",
                subtitle: "No hay gastos que coincidan"
            )
        } else {
            expenseGroupsSection
            
            // Infinite Scroll Trigger
            if viewModel.hasMorePages {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                        .onAppear {
                            Task { await viewModel.loadMore() }
                        }
                }
                .listRowSeparator(.hidden)
            }
        }
    }
    
    private var expenseGroupsSection: some View {
        ForEach(viewModel.categoryGroups) { group in
            Section {
                ForEach(group.subcategories) { subcategory in
                    ForEach(subcategory.expenses, id: \.stableId) { expense in
                        ModernExpenseCard(expense: expense)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                // Ambos botones en UNA SOLA llamada a swipeActions
                                Button {
                                    HapticManager.shared.expenseDuplicated()
                                    duplicateExpense(expense)
                                } label: {
                                    Label("Duplicar", systemImage: "doc.on.doc")
                                }
                                .tint(.blue)

                                Button {
                                    HapticManager.shared.swipeAction()
                                    expenseToEdit = expense
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                // Borrar (swipe derecha)
                                Button(role: .destructive) {
                                    Task {
                                        HapticManager.shared.expenseDeleted()
                                        await viewModel.deleteExpense(expense)
                                    }
                                } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                            }
                    }
                }
            } header: {
                // Custom Header
                HStack {
                    CategoryBadge(
                        category: group.name,
                        emoji: group.emoji,
                        size: .small,
                        style: .vibrant,
                        isSelected: true
                    )
                    Spacer()
                    Text(group.totalAmount.formattedCurrency)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
        }
    }
    
    private var donutChartView: some View {
        DonutChartContent(viewModel: viewModel, filter: viewModel.selectedFilter) // Updated
    }
    
    private var calendarView: some View {
        CalendarChartContent(viewModel: viewModel)
    }
    
    private var comparisonView: some View {
        MonthComparisonView(viewModel: viewModel)
    }
    
    // MARK: - Sheets
    private func editSheet(for expense: Expense) -> some View {
        EditExpenseSheet(expense: expense) {
            Task { await viewModel.refresh() }
        }
        .presentationDetents([.large])
    }
    
    private var addSheet: some View {
        AddExpenseSheet {
            Task { await viewModel.refresh() }
        }
        .presentationDetents([.large])
    }
    
    // Helper needed for Duplicate because it uses DependencyContainer directly or VM
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
                FeedbackManager.shared.show(.success, title: "Gasto duplicado", message: "\(expense.name) copiado correctamente")
            } catch {
                FeedbackManager.shared.show(.error, title: "Error al duplicar", message: error.localizedDescription)
            }
        }
    }
}

