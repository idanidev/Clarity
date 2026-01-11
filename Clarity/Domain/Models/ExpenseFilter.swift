// ExpenseFilter.swift
// Domain model for filtering expenses

import Foundation

struct ExpenseFilter: Equatable, Sendable {
    var selectedCategories: Set<String> = []
    var selectedPaymentMethods: Set<String> = []
    var dateRange: DateRange = .thisMonth
    var customStartDate: Date = Date()
    var customEndDate: Date = Date()
    var minAmount: Double? = nil
    var maxAmount: Double? = nil
    var sortBy: SortOption = .dateDesc
    var showOnlyRecurring: Bool = false
    
    enum DateRange: String, CaseIterable, Sendable {
        case allTime = "Todos"
        case today = "Hoy"
        case yesterday = "Ayer"
        case thisWeek = "Esta semana"
        case lastWeek = "Semana pasada"
        case thisMonth = "Este mes"
        case lastMonth = "Mes anterior"
        case last3Months = "Últimos 3 meses"
        case last6Months = "Últimos 6 meses"
        case last12Months = "Últimos 12 meses"
        case thisYear = "Este año"
        case lastYear = "Año pasado"
        case custom = "Personalizado"
    }
    
    enum SortOption: String, CaseIterable, Sendable {
        case dateDesc = "Más recientes"
        case dateAsc = "Más antiguos"
        case amountDesc = "Mayor importe"
        case amountAsc = "Menor importe"
        case nameAsc = "A-Z"
        case nameDesc = "Z-A"
    }
    
    var hasActiveFilters: Bool {
        !selectedCategories.isEmpty || 
        !selectedPaymentMethods.isEmpty || 
        dateRange != .thisMonth ||
        minAmount != nil ||
        maxAmount != nil ||
        showOnlyRecurring ||
        sortBy != .dateDesc
    }
    
    // MARK: - Filtering Logic
    
    func apply(to expenses: [Expense]) -> [Expense] {
        var result = expenses
        
        // Deduplicate (if needed, though Domain implies clean data, Repository usually handles this)
        // Ignoring dedupe for now, assuming Repository provides unique items
        
        // Date Range
        let (start, end) = dateRangeForQuery()
        result = result.filter { $0.date >= start && $0.date <= end }
        
        // Categories service
        if !selectedCategories.isEmpty {
            result = result.filter { expense in
                selectedCategories.contains { cat in
                    // Flexible matching (e.g. "Food 🍔" matches "Food")
                    expense.category.localizedCaseInsensitiveContains(cat.components(separatedBy: " ").first ?? cat)
                }
            }
        }
        
        // Payment Methods
        if !selectedPaymentMethods.isEmpty {
            result = result.filter { selectedPaymentMethods.contains($0.paymentMethod) }
        }
        
        // Amount
        if let min = minAmount {
            result = result.filter { $0.amount >= min }
        }
        if let max = maxAmount {
            result = result.filter { $0.amount <= max }
        }
        
        // Recurring
        if showOnlyRecurring {
            result = result.filter { $0.isRecurring == true }
        }
        
        // Sort
        switch sortBy {
        case .dateDesc:
            result.sort { $0.date > $1.date }
        case .dateAsc:
            result.sort { $0.date < $1.date }
        case .amountDesc:
            result.sort { $0.amount > $1.amount }
        case .amountAsc:
            result.sort { $0.amount < $1.amount }
        case .nameAsc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDesc:
            result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        }
        
        return result
    }
    
    // Helper used by UI and Logic
    func dateRangeForQuery() -> (start: String, end: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        let calendar = Calendar.current
        let now = Date()
        
        let (startDate, endDate): (Date, Date) = {
            switch dateRange {
            case .allTime:
                let start = calendar.date(byAdding: .year, value: -10, to: now)!
                return (start, now)
            case .today:
                let start = calendar.startOfDay(for: now)
                return (start, now)
            case .yesterday:
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
                let start = calendar.startOfDay(for: yesterday)
                let end = calendar.date(byAdding: .day, value: 1, to: start)!
                return (start, end)
            case .thisWeek:
                let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                return (start, now)
            case .lastWeek:
                let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
                let start = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)!
                return (start, thisWeekStart)
            case .thisMonth:
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start)!
                return (start, end)
            case .lastMonth:
                let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
                let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart)!
                return (start, thisMonthStart)
            case .last3Months:
                let start = calendar.date(byAdding: .month, value: -3, to: now)!
                return (start, now)
            case .last6Months:
                let start = calendar.date(byAdding: .month, value: -6, to: now)!
                return (start, now)
            case .last12Months:
                let start = calendar.date(byAdding: .month, value: -12, to: now)!
                return (start, now)
            case .thisYear:
                let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
                return (start, now)
            case .lastYear:
                let thisYearStart = calendar.date(from: calendar.dateComponents([.year], from: now))!
                let start = calendar.date(byAdding: .year, value: -1, to: thisYearStart)!
                return (start, thisYearStart)
            case .custom:
                return (customStartDate, customEndDate)
            }
        }()
        
        return (formatter.string(from: startDate), formatter.string(from: endDate))
    }
}
