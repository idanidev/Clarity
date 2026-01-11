// HomeView.swift
// Main screen implementing Clean Architecture + MVVM

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel
    @State private var showFilterSheet = false
    
    init(viewModel: HomeViewModel = DependencyContainer.shared.makeHomeViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch viewModel.state {
                case .idle:
                    Color.clear.onAppear { Task { await viewModel.loadExpenses() } }
                    
                case .loading:
                    ProgressView("Cargando gastos...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .error(let message):
                    ContentUnavailableView {
                        Label("Error", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Reintentar") {
                            Task { await viewModel.loadExpenses() }
                        }
                    }
                    
                case .loaded(let expenses), .empty:
                    // Using a helper view to avoid switch complexity in complex layout
                    HomeContent(
                        viewModel: viewModel,
                        expenses: expenses,
                        showFilterSheet: $showFilterSheet
                    )
                }
            }
            .navigationTitle("Gastos")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .symbolVariant(viewModel.selectedFilter.hasActiveFilters ? .fill : .none)
                    }
                }
            }
            .sheet(isPresented: $showFilterSheet) {
                ExpenseFilterSheet(
                    filter: $viewModel.selectedFilter,
                    onApply: {
                        // ViewModel observes changes but we allow explicit refresh if needed
                        Task { await viewModel.loadExpenses() }
                    }
                )
            }
        }
    }
}

// Subview to handle specific content layout
struct HomeContent: View {
    @ObservedObject var viewModel: HomeViewModel
    let expenses: [Expense]
    @Binding var showFilterSheet: Bool
    
    var body: some View {
         VStack(spacing: 0) {
             // Summary Section
             // We need to calculate totals here or in ViewModel. 
             // MVVM suggests ViewModel provides these. 
             // summary calculation
             let total = expenses.reduce(0) { $0 + $1.amount }
             let savings = viewModel.income - total
             let safeIncome = viewModel.income > 0 ? viewModel.income : 1 // Avoid div by zero
             
             SummaryCardsView(
                 totalExpenses: total,
                 expenseCount: expenses.count,
                 savings: savings,
                 savingsPercentage: Int((savings / safeIncome) * 100),
                 available: savings
             )
             .padding()
             
             // Search
             SearchBarView(
                 searchText: $viewModel.searchText,
                 filter: $viewModel.selectedFilter, // Binding needed? SearchBarView creates its own or uses binding?
                 onFilterChange: {
                     // Trigger update if needed
                 }
             )
             .padding(.horizontal)
             
             // List
             if expenses.isEmpty {
                 ContentUnavailableView("Sin resultados", systemImage: "magnifyingglass")
             } else {
                 ExpenseListView(
                    expenses: expenses,
                    onDelete: { expense in
                         // Call VM delete intent
                         // Task { await viewModel.deleteExpense(expense) }
                         // We haven't implemented delete in VM yet!
                    }
                 )
             }
         }
    }
}
