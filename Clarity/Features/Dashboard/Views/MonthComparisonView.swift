// MonthComparisonView.swift
// Vista premium de comparación de meses para el tab VS

import SwiftUI
import Charts

struct MonthComparisonView: View {
    let expenses: [Expense]
    
    @State private var selectedMonthOffset: Int = 1
    @State private var animateChart = false
    
    private let availableMonths = [1, 2, 3, 6, 12]
    
    init(expenses: [Expense]) {
        self.expenses = expenses
    }
    
    // Legacy init for compatibility
    init(viewModel: HomeViewModel) { // Updated
        self.expenses = viewModel.allExpenses // Updated
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header con gradiente
                headerSection
                
                // Month Selector Pills
                monthSelector
                    .padding(.horizontal)
                
                // Big comparison card
                mainComparisonCard
                    .padding(.horizontal)
                
                // Trend indicator
                trendCard
                    .padding(.horizontal)
                
                // Category breakdown
                categoryBreakdown
                    .padding(.horizontal)
                
                // Top differences
                topDifferencesCard
                    .padding(.horizontal)
                
                Spacer(minLength: 100)
            }
        }
        .background(Color.bgPrimary)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animateChart = true
            }
        }
    }
    
    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Comparativa")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.primary)
            
            Text("Analiza tus gastos entre meses")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .padding(.top, 8)
    }
    
    // MARK: - Month Selector
    private var monthSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(availableMonths, id: \.self) { offset in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMonthOffset = offset
                        }
                        HapticManager.shared.selection()
                    } label: {
                        VStack(spacing: 2) {
                            Text(shortMonthLabel(offset: offset))
                                .font(.system(size: 13, weight: .semibold))
                            Text(monthName(offset: offset))
                                .font(.system(size: 10))
                                .opacity(0.7)
                        }
                        .foregroundStyle(selectedMonthOffset == offset ? .white : .secondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(selectedMonthOffset == offset 
                                      ? Color.clarityPrimary.gradient 
                                      : Color(.secondarySystemGroupedBackground).gradient)
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(selectedMonthOffset == offset ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Main Comparison Card
    private var mainComparisonCard: some View {
        let current = totalForCurrentMonth
        let compared = totalForComparedMonth
        let difference = current - compared
        let percentChange = compared > 0 ? ((difference / compared) * 100) : 0
        
        return VStack(spacing: 0) {
            // Top section - This month
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ESTE MES")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    Text(current.formattedCurrency)
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                
                Spacer()
                
                // Circle progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    
                    Circle()
                        .trim(from: 0, to: animateChart ? min(current / max(compared, 1), 2) / 2 : 0)
                        .stroke(
                            current > compared ? Color.red.gradient : Color.green.gradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    
                    Image(systemName: difference > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(difference > 0 ? .red : .green)
                }
                .frame(width: 56, height: 56)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            
            // Divider with VS
            HStack {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
                
                Text("VS")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 1)
            }
            .padding(.horizontal)
            .background(Color(.secondarySystemGroupedBackground))
            
            // Bottom section - Compared month
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(monthName(offset: selectedMonthOffset).uppercased())
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1)
                    
                    Text(compared.formattedCurrency)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Difference badge
                HStack(spacing: 4) {
                    Image(systemName: difference > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.system(size: 12, weight: .bold))
                    
                    Text("\(String(format: "%.0f", abs(percentChange)))%")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(difference > 0 ? Color.red.gradient : Color.green.gradient)
                )
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
    
    // MARK: - Trend Card
    private var trendCard: some View {
        let current = totalForCurrentMonth
        let compared = totalForComparedMonth
        let difference = current - compared
        
        let message: String
        let icon: String
        let color: Color
        
        if difference > 0 {
            message = "Estás gastando \(difference.formattedCurrency) más que en \(monthName(offset: selectedMonthOffset))"
            icon = "exclamationmark.triangle.fill"
            color = .red
        } else if difference < 0 {
            message = "¡Genial! Has ahorrado \(abs(difference).formattedCurrency) comparado con \(monthName(offset: selectedMonthOffset))"
            icon = "checkmark.seal.fill"
            color = .green
        } else {
            message = "Tus gastos son iguales a los de \(monthName(offset: selectedMonthOffset))"
            icon = "equal.circle.fill"
            color = .blue
        }
        
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(color)
            
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Category Breakdown
    private var categoryBreakdown: some View {
        let data = comparisonByCategory.prefix(6) // Top 6 categories
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Por categoría")
                    .font(.headline)
                
                Spacer()
                
                // Legend
                HStack(spacing: 12) {
                    legendItem(color: Color.clarityPrimary, label: "Actual")
                    legendItem(color: .gray.opacity(0.4), label: "Anterior")
                }
                .font(.caption)
            }
            
            if data.isEmpty {
                ContentUnavailableView("Sin datos", systemImage: "chart.bar", description: Text("No hay gastos para comparar"))
                    .frame(height: 200)
            } else {
                Chart(Array(data)) { item in
                    BarMark(
                        x: .value("Categoría", item.category),
                        y: .value("Actual", animateChart ? item.currentAmount : 0)
                    )
                    .foregroundStyle(Color.clarityPrimary.gradient)
                    .cornerRadius(6)
                    .position(by: .value("Tipo", "Actual"))
                    
                    BarMark(
                        x: .value("Categoría", item.category),
                        y: .value("Comparado", animateChart ? item.comparedAmount : 0)
                    )
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .cornerRadius(6)
                    .position(by: .value("Tipo", "Anterior"))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("\(Int(amount))€")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let cat = value.as(String.self) {
                                Text(cat)
                                    .font(.system(size: 10))
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .frame(height: 220)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Top Differences
    private var topDifferencesCard: some View {
        let differences = comparisonByCategory
            .map { (cat: $0.category, diff: $0.currentAmount - $0.comparedAmount) }
            .sorted { abs($0.diff) > abs($1.diff) }
            .prefix(5)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("Mayores cambios")
                .font(.headline)
            
            if differences.isEmpty {
                Text("No hay diferencias significativas")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(differences), id: \.cat) { item in
                    HStack {
                        Text(item.cat)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: item.diff > 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 10, weight: .bold))
                            
                            Text(item.diff > 0 ? "+\(item.diff.formattedCurrency)" : item.diff.formattedCurrency)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(item.diff > 0 ? .red : .green)
                    }
                    .padding(.vertical, 8)
                    
                    if item.cat != differences.last?.cat {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Helper Views
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Data Calculations
    
    private var totalForCurrentMonth: Double {
        let calendar = Calendar.current
        let now = Date()
        return expenses.filter { expense in
            guard let date = parseDate(expense.date) else { return false }
            return calendar.isDate(date, equalTo: now, toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }
    }
    
    private var totalForComparedMonth: Double {
        let calendar = Calendar.current
        guard let targetMonth = calendar.date(byAdding: .month, value: -selectedMonthOffset, to: Date()) else { return 0 }
        return expenses.filter { expense in
            guard let date = parseDate(expense.date) else { return false }
            return calendar.isDate(date, equalTo: targetMonth, toGranularity: .month)
        }.reduce(0) { $0 + $1.amount }
    }
    
    private var comparisonByCategory: [CategoryComparison] {
        let calendar = Calendar.current
        let now = Date()
        guard let targetMonth = calendar.date(byAdding: .month, value: -selectedMonthOffset, to: Date()) else { return [] }
        
        var categories = Set<String>()
        expenses.forEach { categories.insert(shortCategory($0.category)) }
        
        return categories.compactMap { cat in
            let current = expenses.filter { expense in
                guard let date = parseDate(expense.date) else { return false }
                return calendar.isDate(date, equalTo: now, toGranularity: .month) && shortCategory(expense.category) == cat
            }.reduce(0) { $0 + $1.amount }
            
            let compared = expenses.filter { expense in
                guard let date = parseDate(expense.date) else { return false }
                return calendar.isDate(date, equalTo: targetMonth, toGranularity: .month) && shortCategory(expense.category) == cat
            }.reduce(0) { $0 + $1.amount }
            
            if current == 0 && compared == 0 { return nil }
            return CategoryComparison(category: cat, currentAmount: current, comparedAmount: compared)
        }.sorted { $0.currentAmount > $1.currentAmount }
    }
    
    // MARK: - Helpers
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    private func monthName(offset: Int) -> String {
        let calendar = Calendar.current
        guard let date = calendar.date(byAdding: .month, value: -offset, to: Date()) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMMM"
        return formatter.string(from: date).capitalized
    }
    
    private func shortMonthLabel(offset: Int) -> String {
        switch offset {
        case 1: return "1 mes"
        case 2: return "2 meses"
        case 3: return "3 meses"
        case 6: return "6 meses"
        case 12: return "1 año"
        default: return "\(offset)m"
        }
    }
    
    private func shortCategory(_ category: String) -> String {
        let parts = category.components(separatedBy: " ")
        if parts.count > 1 {
            return parts.dropFirst().joined(separator: " ")
        }
        return String(category.prefix(10))
    }
}

// MARK: - Category Comparison Model
struct CategoryComparison: Identifiable {
    let id = UUID()
    let category: String
    let currentAmount: Double
    let comparedAmount: Double
}

#Preview {
    MonthComparisonView(expenses: [])
}
