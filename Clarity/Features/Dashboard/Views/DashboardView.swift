// DashboardView.swift
// Main dashboard with summary cards and expandable expense table

import SwiftUI

struct DashboardView: View {
    @State private var viewModel = DashboardViewModel()
    @State private var expenseToEdit: Expense? = nil
    @State private var showEditSheet = false
    
    var body: some View {
        NavigationStack {
            MainContent(
                viewModel: viewModel,
                expenseToEdit: $expenseToEdit,
                showEditSheet: $showEditSheet,
                onExpenseDuplicate: duplicateExpense
            )
            .background {
                ZStack {
                    Color.bgPrimary.ignoresSafeArea() 
                }
            }
            .navigationTitle("Gastos")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.bgPrimary, for: .navigationBar)
            .toolbarBackgroundVisibility(.visible, for: .navigationBar)
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadExpenses()
            }
            // ViewModel handles updates automatically
            .sheet(isPresented: $showEditSheet) {
                if let expense = expenseToEdit {
                    EditExpenseSheet(expense: expense) {
                        Task { await viewModel.refresh() }
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

// MARK: - Subviews

struct MainContent: View {
    @Bindable var viewModel: DashboardViewModel
    @Binding var expenseToEdit: Expense?
    @Binding var showEditSheet: Bool
    let onExpenseDuplicate: (Expense) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Summary Cards
            SummaryCardsView(
                totalExpenses: viewModel.totalFilteredAmount,
                expenseCount: viewModel.filteredExpenses.count,
                savings: viewModel.calculatedSavings,
                savingsPercentage: viewModel.calculatedSavings > 0 
                    ? Int((viewModel.calculatedSavings / (UserDataManager.shared.userDocument?.income ?? 1)) * 100) 
                    : 0,
                available: viewModel.calculatedSavings
            )
            .padding(.horizontal)
            .padding(.top, 4)
            
            // Search Bar with native iOS Menu filter
            SearchBarView(
                searchText: $viewModel.searchText,
                filter: $viewModel.filter,
                onFilterChange: { /* Handled by VM */ }
            )
            .padding(.horizontal)
            .padding(.top, 6)
            
            // Active filter pills
            ActiveFilterPillsView(
                filter: $viewModel.filter,
                onFilterChange: { /* Handled by VM */ }
            )
            
            // Content
            ExpenseListContent(
                isLoading: viewModel.isLoading,
                expensesEmpty: viewModel.expenses.isEmpty,
                filteredEmpty: viewModel.filteredExpenses.isEmpty,
                activeFilters: viewModel.filter.hasActiveFilters,
                groupsEmpty: viewModel.categoryGroups.isEmpty,
                categoryGroups: viewModel.categoryGroups, // Read-only pass
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
                    viewModel.filter = ExpenseFilter()
                    viewModel.searchText = ""
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
    let categoryGroups: [CategoryGroup] // Read-only
    let onDelete: (Expense) -> Void
    let onEdit: (Expense) -> Void
    let onDuplicate: (Expense) -> Void
    let onClearFilters: () -> Void
    
    var body: some View {
        if isLoading {
            ExpenseListSkeleton()
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
                categories: categoryGroups,
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
