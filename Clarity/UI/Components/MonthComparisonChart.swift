// MonthComparisonChart.swift
// Bar chart comparing spending between current month and a selected previous month

import SwiftUI
import Charts

struct MonthComparisonChart: View {
    let expenses: [Expense]
    @State private var selectedMonthOffset: Int = 1 // 1 = last month, 2 = 2 months ago, etc.
    @State private var comparisonData: [MonthData] = []
    
    private let availableMonths = [1, 2, 3, 4, 5, 6] // Últimos 6 meses
    
    struct MonthData: Identifiable {
        let id = UUID()
        let category: String
        let currentAmount: Double
        let comparedAmount: Double
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with month selector
            HStack {
                Text("Comparativa")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // Month Picker
                Menu {
                    ForEach(availableMonths, id: \.self) { offset in
                        Button {
                            selectedMonthOffset = offset
                            calculateComparison()
                        } label: {
                            HStack {
                                Text(monthName(offset: offset))
                                if selectedMonthOffset == offset {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("vs \(monthName(offset: selectedMonthOffset))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.bgTertiary)
                    .clipShape(Capsule())
                }
            }
            
            if comparisonData.isEmpty {
                // Empty state
                Text("Sin datos para comparar")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 40)
            } else {
                // Chart
                Chart(comparisonData) { item in
                    BarMark(
                        x: .value("Categoría", item.category),
                        y: .value("Actual", item.currentAmount)
                    )
                    .foregroundStyle(Color.clarityPrimary.gradient)
                    .cornerRadius(4)
                    .position(by: .value("Tipo", "Actual"))
                    
                    BarMark(
                        x: .value("Categoría", item.category),
                        y: .value("Comparado", item.comparedAmount)
                    )
                    .foregroundStyle(Color.gray.opacity(0.5))
                    .cornerRadius(4)
                    .position(by: .value("Tipo", "Anterior"))
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let amount = value.as(Double.self) {
                                Text("\(Int(amount))€")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let cat = value.as(String.self) {
                                Text(shortCategoryName(cat))
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .chartLegend {
                    HStack(spacing: 16) {
                        LegendItem(color: Color.clarityPrimary, label: "Este mes")
                        LegendItem(color: .gray.opacity(0.5), label: monthName(offset: selectedMonthOffset))
                    }
                    .font(.caption)
                }
                .frame(height: 180)
                
                // Summary
                summaryRow
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onAppear {
            calculateComparison()
        }
    }
    
    // MARK: - Summary Row
    private var summaryRow: some View {
        let currentTotal = comparisonData.reduce(0) { $0 + $1.currentAmount }
        let comparedTotal = comparisonData.reduce(0) { $0 + $1.comparedAmount }
        let difference = currentTotal - comparedTotal
        let percentChange = comparedTotal > 0 ? (difference / comparedTotal) * 100 : 0
        
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Este mes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatters.currency(currentTotal))
                    .font(.subheadline.bold())
            }
            
            Spacer()
            
            // Difference indicator
            HStack(spacing: 4) {
                Image(systemName: difference > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                Text(String(format: "%.1f%%", abs(percentChange)))
                    .font(.caption.bold())
            }
            .foregroundStyle(difference > 0 ? .red : .green)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(difference > 0 ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
            .clipShape(Capsule())
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(monthName(offset: selectedMonthOffset))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatters.currency(comparedTotal))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helpers
    private func monthName(offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .month, value: -offset, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "MMM"
        return formatter.string(from: date).capitalized
    }
    
    private func shortCategoryName(_ name: String) -> String {
        // Remove emoji and truncate
        let cleaned = name.unicodeScalars.filter { !$0.properties.isEmoji }.map { String($0) }.joined()
        return String(cleaned.prefix(6))
    }
    
    private func calculateComparison() {
        let calendar = Calendar.current
        let now = Date()
        
        // Current month range
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        // Compared month range
        let comparedMonthDate = calendar.date(byAdding: .month, value: -selectedMonthOffset, to: now)!
        let comparedMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: comparedMonthDate))!
        let comparedMonthEnd = calendar.date(byAdding: .month, value: 1, to: comparedMonthStart)!
        
        // Group expenses by category
        var currentByCategory: [String: Double] = [:]
        var comparedByCategory: [String: Double] = [:]
        
        for expense in expenses {
            let expenseDate = expense.dateAsDate
            if expenseDate >= currentMonthStart {
                currentByCategory[expense.category, default: 0] += expense.amount
            } else if expenseDate >= comparedMonthStart && expenseDate < comparedMonthEnd {
                comparedByCategory[expense.category, default: 0] += expense.amount
            }
        }
        
        // Create comparison data (top 5 categories)
        let allCategories = Set(currentByCategory.keys).union(Set(comparedByCategory.keys))
        var data: [MonthData] = []
        
        for category in allCategories {
            data.append(MonthData(
                category: category,
                currentAmount: currentByCategory[category] ?? 0,
                comparedAmount: comparedByCategory[category] ?? 0
            ))
        }
        
        // Sort by current amount, take top 5
        comparisonData = Array(data.sorted { $0.currentAmount > $1.currentAmount }.prefix(5))
    }
}

// MARK: - Legend Item
private struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    MonthComparisonChart(expenses: [])
        .padding()
}
