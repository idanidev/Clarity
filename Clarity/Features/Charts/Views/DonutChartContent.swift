// DonutChartContent.swift
// Extracted donut chart content for unified picker

import SwiftUI
import Charts

struct DonutChartContent: View {
    @ObservedObject var viewModel: DashboardViewModel
    var filter: ExpenseFilter
    
    private let defaultColors: [Color] = [
        Color(hex: "#8B5CF6")!,
        Color(hex: "#3B82F6")!,
        Color(hex: "#10B981")!,
        Color(hex: "#F59E0B")!,
        Color(hex: "#EF4444")!,
        Color(hex: "#EC4899")!,
        Color(hex: "#14B8A6")!,
        Color(hex: "#FBBF24")!,
    ]
    
    var body: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
                .tint(Color.clarityPrimary)
            Spacer()
        } else if filteredExpenses.isEmpty {
            Spacer()
            EmptyStateView(
                icon: "chart.pie",
                title: "Sin datos",
                message: "Añade gastos para ver tus estadísticas"
            )
            Spacer()
        } else {
            DonutChartView(
                categoryData: buildChartData(),
                total: filteredTotal
            )
        }
    }
    
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
        // Apply date range filter
        let dateRange = filter.dateRangeForQuery()
        expenses = expenses.filter { expense in
            expense.date >= dateRange.start && expense.date <= dateRange.end
        }
        
        // Apply payment method filter
        if !filter.selectedPaymentMethods.isEmpty {
            expenses = expenses.filter { filter.selectedPaymentMethods.contains($0.paymentMethod) }
        }
        
        // Apply category filter
        if !filter.selectedCategories.isEmpty {
            expenses = expenses.filter { filter.selectedCategories.contains($0.category) }
        }
        
        return expenses
    }
    
    private var filteredTotal: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }
    
    private func buildChartData() -> [CategoryChartData] {
        var categoryTotals: [String: (amount: Double, color: Color)] = [:]
        
        for expense in filteredExpenses {
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
}

// MARK: - Calendar Chart Content
struct CalendarChartContent: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        if viewModel.isLoading {
            Spacer()
            ProgressView()
                .tint(Color.clarityPrimary)
            Spacer()
        } else if viewModel.expenses.isEmpty {
            Spacer()
            EmptyStateView(
                icon: "calendar",
                title: "Sin datos",
                message: "Añade gastos para ver el calendario"
            )
            Spacer()
        } else {
            ExpenseCalendarView(expenses: viewModel.expenses)
        }
    }
}
