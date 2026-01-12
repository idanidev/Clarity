// ExpensesView.swift
// Unified view with Tabla and Gráfica tabs

import SwiftUI

struct ExpensesView: View {
    @State private var viewModel = DashboardViewModel()
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
                    filter: $viewModel.filter,
                    availableCategories: Array(Set(viewModel.expenses.map { $0.category })),
                    onApply: {
                        // Filters apply auto via binding
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
                        DonutChartContent(viewModel: viewModel, filter: viewModel.filter)
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
                if viewModel.filter.hasActiveFilters || !viewModel.searchText.isEmpty {
                    Button {
                        viewModel.filter = ExpenseFilter(dateRange: .thisMonth)
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
                        Image(systemName: "line.3.horizontal.decrease.circle" + (viewModel.filter.hasActiveFilters || !viewModel.searchText.isEmpty ? ".fill" : ""))
                            .font(.system(size: 22))
                            .foregroundStyle(viewModel.filter.hasActiveFilters || !viewModel.searchText.isEmpty ? Color.clarityPrimary : .secondary)
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
                    value: Formatters.currency(viewModel.totalFilteredAmount),
                    color: Color.clarityPrimary
                )
                
                StatCard(
                    title: "Gastos",
                    value: "\(viewModel.filteredExpenses.count)",
                    color: .blue
                )
                
                StatCard(
                    title: "Ahorro",
                    value: Formatters.currency(viewModel.calculatedSavings),
                    color: viewModel.calculatedSavings >= 0 ? .green : .red
                )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Search bar for table
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
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            
            // Active filter pills (kept for feedback)
            ActiveFilterPillsView(
                filter: $viewModel.filter,
                onFilterChange: { /* Handled by VM */ }
            )
            .padding(.top, 4)
            
            // Content
            ExpenseListContent(
                isLoading: viewModel.isLoading,
                expensesEmpty: viewModel.expenses.isEmpty,
                filteredEmpty: viewModel.filteredExpenses.isEmpty,
                activeFilters: viewModel.filter.hasActiveFilters,
                groupsEmpty: viewModel.categoryGroups.isEmpty,
                categoryGroups: viewModel.categoryGroups, // Read-only pass
                // Wait, ExpenseListContent likely expects Binding<[CategoryGroup]> if it handles expansion state within the group model
                // checking usage: categoryGroups: $categoryGroups
                // If CategoryGroup handles expansion state, it needs to be mutable.
                // Since VM owns it now, we pass binding to VM property.
                // But VM property `categoryGroups` is private(set).
                // FIX: DashboardViewModel needs to expose binding or handling for expansion.
                // OR ExpenseListContent manages expansion locally.
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
                    viewModel.filter = ExpenseFilter(dateRange: .thisMonth)
                    viewModel.searchText = ""
                }
            )
        }
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
                HapticManager.notification(.success)
            } catch {
                print("Error duplicating expense: \(error)")
            }
        }
    }
}
