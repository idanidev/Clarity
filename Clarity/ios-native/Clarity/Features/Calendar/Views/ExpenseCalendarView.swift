// ExpenseCalendarView.swift
// Calendar view showing daily expenses

import SwiftUI

// MARK: - Day Expense Model
struct DayExpense: Identifiable {
    let id = UUID()
    let day: Int
    let amount: Double
    let date: Date
}

// MARK: - Week Day Data
struct WeekDayData: Identifiable {
    let id = UUID()
    let dayShort: String
    let amount: Double
}

// MARK: - Calendar View
struct ExpenseCalendarView: View {
    let expenses: [Expense]
    @State private var currentMonth: Date = Date()
    @State private var selectedDate: Date? = nil
    
    private let calendar = Calendar.current
    private let weekdays = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    
    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                // Calendar Card
                VStack(spacing: Spacing.md) {
                    // Month header
                    HStack {
                        Text("Calendario de Gastos - \(monthYearString)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Navigation arrows
                        HStack(spacing: Spacing.md) {
                            Button {
                                withAnimation {
                                    previousMonth()
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.gray)
                            }
                            
                            Button {
                                withAnimation {
                                    nextMonth()
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    
                    // Weekday headers
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(weekdays, id: \.self) { day in
                            Text(day)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Days grid
                    LazyVGrid(columns: columns, spacing: 4) {
                        // Empty cells for alignment
                        ForEach(0..<firstDayOffset, id: \.self) { _ in
                            Color.clear
                                .frame(height: 56)
                        }
                        
                        // Day cells
                        ForEach(daysInMonth, id: \.self) { day in
                            CalendarDayCell(
                                day: day,
                                expense: expenseForDay(day),
                                isToday: isToday(day),
                                isSelected: isSelected(day)
                            )
                            .onTapGesture {
                                selectedDate = dateFor(day: day)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.bgSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
                
                // Weekly chart
                WeeklyExpenseChart(
                    weekData: currentWeekData,
                    total: weekTotal
                )
            }
            .padding(.horizontal)
        }
        .background(Color.bgPrimary)
    }
    
    // MARK: - Computed Properties
    
    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter.string(from: currentMonth).capitalized
    }
    
    private var firstDayOffset: Int {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        let weekday = calendar.component(.weekday, from: firstDay)
        // Adjust for Monday start (1 = Sunday in Calendar)
        return weekday == 1 ? 6 : weekday - 2
    }
    
    private var daysInMonth: [Int] {
        guard let range = calendar.range(of: .day, in: .month, for: currentMonth) else { return [] }
        return Array(range)
    }
    
    private func dateFor(day: Int) -> Date {
        var components = calendar.dateComponents([.year, .month], from: currentMonth)
        components.day = day
        return calendar.date(from: components) ?? currentMonth
    }
    
    private func isToday(_ day: Int) -> Bool {
        let date = dateFor(day: day)
        return calendar.isDateInToday(date)
    }
    
    private func isSelected(_ day: Int) -> Bool {
        guard let selected = selectedDate else { return false }
        return calendar.isDate(dateFor(day: day), inSameDayAs: selected)
    }
    
    private func expenseForDay(_ day: Int) -> Double? {
        let date = dateFor(day: day)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        let total = expenses
            .filter { $0.date == dateString }
            .reduce(0) { $0 + $1.amount }
        
        return total > 0 ? total : nil
    }
    
    private var currentWeekData: [WeekDayData] {
        let weekdayShorts = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
        return weekdayShorts.map { day in
            // Simplified - would calculate actual amounts
            WeekDayData(dayShort: day, amount: Double.random(in: 0...100))
        }
    }
    
    private var weekTotal: Double {
        currentWeekData.reduce(0) { $0 + $1.amount }
    }
    
    // MARK: - Navigation
    
    private func previousMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
    
    private func nextMonth() {
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let day: Int
    let expense: Double?
    let isToday: Bool
    let isSelected: Bool
    
    private var hasExpense: Bool {
        expense != nil && expense! > 0
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(day)")
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .white : (hasExpense ? .white : .gray))
            
            if let expense = expense, expense > 0 {
                Text("-\(Int(expense))€")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(isToday ? .white : Color(hex: "#A78BFA")!)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(
            Group {
                if isToday {
                    Color.clarityPrimary
                } else {
                    Color.clear
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    hasExpense && !isToday ? Color.clarityPrimary.opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
    }
}

// MARK: - Weekly Expense Chart
struct WeeklyExpenseChart: View {
    let weekData: [WeekDayData]
    let total: Double
    
    private var maxAmount: Double {
        weekData.map(\.amount).max() ?? 1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Gastos de la Semana")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            // Bar chart
            HStack(alignment: .bottom, spacing: Spacing.xs) {
                ForEach(weekData) { day in
                    VStack(spacing: 4) {
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.brandGradientDiagonal)
                            .frame(width: 28, height: barHeight(for: day.amount))
                        
                        // Day label
                        Text(day.dayShort)
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(height: 120)
            .frame(maxWidth: .infinity)
            
            // Total
            HStack {
                Text("Total de la semana:")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Spacer()
                
                Text(String(format: "%.2f €", total))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cardRadius))
    }
    
    private func barHeight(for amount: Double) -> CGFloat {
        let maxHeight: CGFloat = 80
        return maxAmount > 0 ? CGFloat(amount / maxAmount) * maxHeight : 0
    }
}

// MARK: - Preview
#Preview {
    ExpenseCalendarView(expenses: [])
        .preferredColorScheme(.dark)
}
