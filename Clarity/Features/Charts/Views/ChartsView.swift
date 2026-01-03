// ChartsView.swift
// Charts view with donut chart and category breakdown

import SwiftUI
import Charts

struct ChartsView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var selectedTab = 0
    @State private var filter = ExpenseFilter(dateRange: .thisYear)
    
    // Default colors for categories (in order)
    private let defaultColors: [Color] = [
        Color(hex: "#8B5CF6")!,  // Violet
        Color(hex: "#3B82F6")!,  // Blue
        Color(hex: "#10B981")!,  // Green
        Color(hex: "#F59E0B")!,  // Amber
        Color(hex: "#EF4444")!,  // Red
        Color(hex: "#EC4899")!,  // Pink
        Color(hex: "#14B8A6")!,  // Teal
        Color(hex: "#FBBF24")!,  // Yellow
        Color(hex: "#6366F1")!,  // Indigo
        Color(hex: "#6B7280")!,  // Gray
    ]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Vista", selection: $selectedTab) {
                    Text("Gráfico").tag(0)
                    Text("Calendario").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color.bgSecondary)
                
                // Content
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
                        message: filter.hasActiveFilters ? "No hay gastos con estos filtros" : "Añade gastos para ver tus estadísticas"
                    )
                    Spacer()
                } else {
                    switch selectedTab {
                    case 0:
                        // Donut Chart View
                        DonutChartView(
                            categoryData: buildChartData(),
                            total: filteredTotal
                        )
                    case 1:
                        // Calendar View
                        ExpenseCalendarView(expenses: filteredExpenses)
                    default:
                        EmptyView()
                    }
                }
            }
            .background(Color.bgPrimary)
            .navigationTitle("Gráficos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Native iOS Menu for quick filter actions
                    Menu {
                        Section("Período") {
                            ForEach(ExpenseFilter.DateRange.allCases, id: \.self) { range in
                                Button {
                                    filter.dateRange = range
                                } label: {
                                    HStack {
                                        Text(range.rawValue)
                                        if filter.dateRange == range {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Section("Método de Pago") {
                            ForEach(["Tarjeta", "Efectivo", "Bizum", "Transferencia"], id: \.self) { method in
                                Button {
                                    if filter.selectedPaymentMethods.contains(method) {
                                        filter.selectedPaymentMethods.remove(method)
                                    } else {
                                        filter.selectedPaymentMethods.insert(method)
                                    }
                                } label: {
                                    HStack {
                                        Text(method)
                                        if filter.selectedPaymentMethods.contains(method) {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        
                        if filter.hasActiveFilters {
                            Divider()
                            
                            Button(role: .destructive) {
                                filter = ExpenseFilter()
                            } label: {
                                Label("Limpiar filtros", systemImage: "xmark.circle")
                            }
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.system(size: 18))
                                .foregroundColor(filter.hasActiveFilters ? Color.clarityPrimary : .gray)
                            
                            if filter.hasActiveFilters {
                                Circle()
                                    .fill(Color.clarityPrimary)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .task {
                await viewModel.loadExpenses()
            }
            .refreshable {
                await viewModel.refresh()
            }
        }
    }
    
    // MARK: - Filtered Data
    
    private var filteredExpenses: [Expense] {
        var expenses = viewModel.expenses
        
        print("📊 CHARTS: Total expenses from VM: \(expenses.count)")
        
        // Apply date range filter
        let dateRange = filter.dateRangeForQuery()
        print("📊 CHARTS: Filter range: \(dateRange.0) to \(dateRange.1)")
        
        expenses = expenses.filter { expense in
            expense.date >= dateRange.0 && expense.date <= dateRange.1
        }
        
        print("📊 CHARTS: After date filter: \(expenses.count)")
        
        // Apply category filter
        if !filter.selectedCategories.isEmpty {
            expenses = expenses.filter { expense in
                filter.selectedCategories.contains { category in
                    expense.category.localizedCaseInsensitiveContains(category.components(separatedBy: " ").first ?? category)
                }
            }
            print("📊 CHARTS: After category filter: \(expenses.count)")
        }
        
        // Apply payment method filter
        if !filter.selectedPaymentMethods.isEmpty {
            expenses = expenses.filter { expense in
                filter.selectedPaymentMethods.contains(expense.paymentMethod)
            }
            print("📊 CHARTS: After payment filter: \(expenses.count)")
        }
        
        return expenses
    }
    
    private var filteredTotal: Double {
        let total = filteredExpenses.reduce(0) { $0 + $1.amount }
        print("📊 CHARTS: Total amount: \(total)€")
        return total
    }
    
    private var filteredCategoryTotals: [(category: String, total: Double)] {
        var totals: [String: Double] = [:]
        for expense in filteredExpenses {
            totals[expense.category, default: 0] += expense.amount
        }
        let result = totals.map { (category: $0.key, total: $0.value) }
            .sorted { $0.total > $1.total }
        print("📊 CHARTS: Category totals: \(result.map { "\($0.category): \($0.total)€" })")
        return result
    }
    
    private func buildChartData() -> [CategoryChartData] {
        let data = filteredCategoryTotals.enumerated().map { index, item in
            let percentage = filteredTotal > 0
                ? (item.total / filteredTotal) * 100
                : 0
            
            return CategoryChartData(
                name: item.category,
                amount: item.total,
                percentage: percentage,
                color: colorForCategory(item.category, index: index)
            )
        }
        print("📊 CHARTS: buildChartData returned \(data.count) items")
        return data
    }
    
    private func colorForCategory(_ category: String, index: Int) -> Color {
        // Try to match known category names
        let categoryMap: [String: Color] = [
            "Vivienda": Color(hex: "#3B82F6")!,
            "Alimentacion": Color(hex: "#6366F1")!,
            "Alimentación": Color(hex: "#6366F1")!,
            "Ocio": Color(hex: "#10B981")!,
            "Coche": Color(hex: "#F59E0B")!,
            "Moto": Color(hex: "#F59E0B")!,
            "Compras": Color(hex: "#FBBF24")!,
            "Salud": Color(hex: "#EF4444")!,
            "Educacion": Color(hex: "#EC4899")!,
            "Educación": Color(hex: "#EC4899")!,
            "Transporte": Color(hex: "#14B8A6")!,
            "Suscripciones": Color(hex: "#8B5CF6")!,
            "Otros": Color(hex: "#6B7280")!,
        ]
        
        // Check if category name contains any known key
        for (key, color) in categoryMap {
            if category.localizedCaseInsensitiveContains(key) {
                return color
            }
        }
        
        // Fallback to indexed color
        return defaultColors[index % defaultColors.count]
    }
    
    // Use cached categories from UserDataManager (loaded on login)
    private var userCategories: [String] {
        UserDataManager.shared.categoryNames
    }
    
    // Use cached payment methods from UserDataManager
    private var userPaymentMethods: [String] {
        UserDataManager.shared.paymentMethods
    }
}

#Preview {
    ChartsView()
}
