// ExpenseFilter.swift
// Domain model for filtering expenses

import Foundation

struct ExpenseFilter: Identifiable, Equatable, Sendable, Codable {
    var id: UUID = UUID()
    var name: String?
    var createdAt: Date? = Date()
    
    var selectedCategories: Set<String> = []
    var selectedPaymentMethods: Set<String> = []
    var dateRange: DateRange = .thisMonth
    var customStartDate: Date = Date()
    var customEndDate: Date = Date()
    var minAmount: Double? = nil
    var maxAmount: Double? = nil
    var sortBy: SortOption = .dateDesc
    var showOnlyRecurring: Bool = false
    
    enum SortOption: String, CaseIterable, Sendable, Codable {
        case dateDesc = "Más recientes"
        case dateAsc = "Más antiguos"
        case amountDesc = "Mayor importe"
        case amountAsc = "Menor importe"
        case nameAsc = "A-Z"
        case nameDesc = "Z-A"
    }
    
    enum DateRange: String, CaseIterable, Sendable, Codable {
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
    
    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, selectedCategories, selectedPaymentMethods, dateRange
        case customStartDate, customEndDate, minAmount, maxAmount, sortBy, showOnlyRecurring
    }
    
    init(
        id: UUID = UUID(),
        name: String? = nil,
        createdAt: Date? = Date(),
        selectedCategories: Set<String> = [],
        selectedPaymentMethods: Set<String> = [],
        dateRange: DateRange = .thisMonth,
        customStartDate: Date = Date(),
        customEndDate: Date = Date(),
        minAmount: Double? = nil,
        maxAmount: Double? = nil,
        sortBy: SortOption = .dateDesc,
        showOnlyRecurring: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.selectedCategories = selectedCategories
        self.selectedPaymentMethods = selectedPaymentMethods
        self.dateRange = dateRange
        self.customStartDate = customStartDate
        self.customEndDate = customEndDate
        self.minAmount = minAmount
        self.maxAmount = maxAmount
        self.sortBy = sortBy
        self.showOnlyRecurring = showOnlyRecurring
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Graceful fallback for ID if missing in legacy data
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        
        // Decode as Arrays for safety (Firestore might return arrays)
        let categoriesArray = try container.decodeIfPresent([String].self, forKey: .selectedCategories) ?? []
        self.selectedCategories = Set(categoriesArray)
        
        let methodsArray = try container.decodeIfPresent([String].self, forKey: .selectedPaymentMethods) ?? []
        self.selectedPaymentMethods = Set(methodsArray)
        
        self.dateRange = try container.decodeIfPresent(DateRange.self, forKey: .dateRange) ?? .thisMonth
        
        self.customStartDate = try container.decodeIfPresent(Date.self, forKey: .customStartDate) ?? Date()
        self.customEndDate = try container.decodeIfPresent(Date.self, forKey: .customEndDate) ?? Date()
        
        self.minAmount = try container.decodeIfPresent(Double.self, forKey: .minAmount)
        self.maxAmount = try container.decodeIfPresent(Double.self, forKey: .maxAmount)
        
        self.sortBy = try container.decodeIfPresent(SortOption.self, forKey: .sortBy) ?? .dateDesc
        self.showOnlyRecurring = try container.decodeIfPresent(Bool.self, forKey: .showOnlyRecurring) ?? false
    }
    
    // Explicit encode needed if we want to be safe, though synthesized usually works with CodingKeys defined.
    // However, for symmetry and control:
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        
        // Encode Sets as Arrays
        try container.encode(Array(selectedCategories), forKey: .selectedCategories)
        try container.encode(Array(selectedPaymentMethods), forKey: .selectedPaymentMethods)
        
        try container.encode(dateRange, forKey: .dateRange)
        try container.encode(customStartDate, forKey: .customStartDate)
        try container.encode(customEndDate, forKey: .customEndDate)
        try container.encodeIfPresent(minAmount, forKey: .minAmount)
        try container.encodeIfPresent(maxAmount, forKey: .maxAmount)
        try container.encode(sortBy, forKey: .sortBy)
        try container.encode(showOnlyRecurring, forKey: .showOnlyRecurring)
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
        if dateRange != .allTime {
            let (start, end) = dateRangeForQuery()
            result = result.filter { $0.date >= start && $0.date <= end }
        }
        
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
        return Self.queryRange(for: dateRange, customStart: customStartDate, customEnd: customEndDate)
    }
    
    // Static helper to avoid actor isolation issues
    nonisolated static func queryRange(for range: DateRange, customStart: Date, customEnd: Date) -> (start: String, end: String) {
        let calendar = Calendar.current
        let now = Date()
        
        let (startDate, endDate): (Date, Date) = {
            switch range {
            case .allTime:
                let start = calendar.date(byAdding: .year, value: -20, to: now) ?? now
                let end = calendar.date(byAdding: .year, value: 50, to: now) ?? now
                return (start, end)
            case .today:
                let start = calendar.startOfDay(for: now)
                return (start, now)
            case .yesterday:
                let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
                let start = calendar.startOfDay(for: yesterday)
                let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
                return (start, end)
            case .thisWeek:
                let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
                return (start, now)
            case .lastWeek:
                let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) ?? now
                let start = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? now
                return (start, thisWeekStart)
            case .thisMonth:
                let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
                let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? now
                return (start, end)
            case .lastMonth:
                let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
                let start = calendar.date(byAdding: .month, value: -1, to: thisMonthStart) ?? now
                let end = calendar.date(byAdding: .day, value: -1, to: thisMonthStart) ?? now
                return (start, end)
            case .last3Months:
                let start = calendar.date(byAdding: .month, value: -3, to: now) ?? now
                return (start, now)
            case .last6Months:
                let start = calendar.date(byAdding: .month, value: -6, to: now) ?? now
                return (start, now)
            case .last12Months:
                let start = calendar.date(byAdding: .month, value: -12, to: now) ?? now
                return (start, now)
            case .thisYear:
                let start = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
                return (start, now)
            case .lastYear:
                let thisYearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
                let start = calendar.date(byAdding: .year, value: -1, to: thisYearStart) ?? now
                return (start, thisYearStart)
            case .custom:
                return (customStart, customEnd)
            }
        }()
        
        // Las fechas en queryRange se calculan con Calendar.current (LOCAL).
        // Las fechas guardadas (vía DatePicker → localDayString) también son LOCAL.
        // Para que coincidan formateamos sin TZ explícita (= local del dispositivo).
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return (fmt.string(from: startDate), fmt.string(from: endDate))
    }
}
