// DonutChartContent.swift
// Extracted donut chart content for unified picker

import SwiftUI
import Charts

struct DonutChartContent: View {
    var viewModel: HomeViewModel // Updated
    var filter: ExpenseFilter
    
    private let defaultColors: [Color] = [
        Color(hex: "#8B5CF6"),
        Color(hex: "#3B82F6"),
        Color(hex: "#10B981"),
        Color(hex: "#F59E0B"),
        Color(hex: "#EF4444"),
        Color(hex: "#EC4899"),
        Color(hex: "#14B8A6"),
        Color(hex: "#FBBF24"),
    ]
    
    var body: some View {
        if viewModel.state == .loading { // Updated
            Spacer()
            ProgressView()
                .tint(Color.clarityPrimary)
            Spacer()
        } else if filteredExpenses.isEmpty {
            Spacer()
            ContentUnavailableView {
                Label("Sin datos", systemImage: "chart.pie")
            } description: {
                Text("Añade gastos para ver tus estadísticas")
            }
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    // Donut Chart - ahora más grande sin comparativa (está en tab VS)
                    DonutChartView(
                        categoryData: buildChartData(),
                        total: filteredTotal
                    )
                }
                .padding(.bottom, 100)
            }
        }
    }
    
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.allExpenses // Updated
        
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
    var viewModel: HomeViewModel // Updated
    
    var body: some View {
        if viewModel.state == .loading { // Updated
            Spacer()
            ProgressView()
                .tint(Color.clarityPrimary)
            Spacer()
        } else if viewModel.allExpenses.isEmpty { // Updated
            Spacer()
            ContentUnavailableView {
                Label("Sin datos", systemImage: "calendar")
            } description: {
                Text("Añade gastos para ver el calendario")
            }
            Spacer()
        } else {
            ExpenseCalendarView(expenses: viewModel.allExpenses) // Updated
        }
    }
}

