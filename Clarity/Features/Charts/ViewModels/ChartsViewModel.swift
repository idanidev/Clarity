// ChartsViewModel.swift
// State & derived analytics for the premium Charts screen.

import Foundation
import Observation

@MainActor
@Observable
final class ChartsViewModel {

    // MARK: - Period

    enum Period: String, CaseIterable, Identifiable {
        case week, month, year, all
        var id: String { rawValue }
        var label: String {
            switch self {
            case .week: return "Semana"
            case .month: return "Mes"
            case .year: return "Año"
            case .all: return "Todo"
            }
        }
    }

    // MARK: - Models

    struct DailyPoint: Identifiable, Hashable {
        // ID estable derivado de la fecha — antes UUID() nuevo en cada compute
        // forzaba re-render completo de ForEach y rompía animaciones.
        var id: TimeInterval { date.timeIntervalSinceReferenceDate }
        let date: Date
        let amount: Double
    }

    struct Insight: Identifiable, Hashable {
        var id: String { title }
        let icon: String
        let title: String
        let subtitle: String
        let tintHex: String
    }

    struct CategoryStat: Identifiable, Hashable {
        var id: String { name }
        let name: String
        let amount: Double
        let percentage: Double
        let colorHex: String
        let sparkline: [Double]
        let deltaVsPrevious: Double // 0.12 = +12%
    }

    // MARK: - State

    var expenses: [Expense] = [] {
        didSet { invalidateCache() }
    }
    var selectedPeriod: Period = .month {
        didSet { invalidateCache() }
    }
    var selectedCategoryName: String?
    var isLoading: Bool = false

    // MARK: - Cache (invalidado en didSet de expenses/selectedPeriod)
    private var _filteredCache: [Expense]?
    private var _previousCache: [Expense]?
    private var _dailyCache: [DailyPoint]?
    private var _categoryStatsCache: [CategoryStat]?

    private func invalidateCache() {
        _filteredCache = nil
        _previousCache = nil
        _dailyCache = nil
        _categoryStatsCache = nil
    }

    // MARK: - Derived

    var filteredExpenses: [Expense] {
        if let cached = _filteredCache { return cached }
        let (start, end) = dateRange(for: selectedPeriod, anchor: Date())
        let result = expenses.filter { exp in
            guard let d = Formatters.date(from: exp.date) else { return false }
            return d >= start && d <= end
        }
        _filteredCache = result
        return result
    }

    var previousPeriodExpenses: [Expense] {
        if let cached = _previousCache { return cached }
        let (pStart, pEnd) = previousDateRange(for: selectedPeriod, anchor: Date())
        let result = expenses.filter { exp in
            guard let d = Formatters.date(from: exp.date) else { return false }
            return d >= pStart && d <= pEnd
        }
        _previousCache = result
        return result
    }

    var total: Double {
        filteredExpenses.reduce(0) { $0 + $1.amount }
    }

    var previousTotal: Double {
        previousPeriodExpenses.reduce(0) { $0 + $1.amount }
    }

    /// 0.0 means neutral; +0.12 = +12% vs previous
    var deltaPercent: Double {
        guard previousTotal > 0 else { return 0 }
        return (total - previousTotal) / previousTotal
    }

    var dailySeries: [DailyPoint] {
        if let cached = _dailyCache { return cached }
        let (start, end) = dateRange(for: selectedPeriod, anchor: Date())
        let cal = Calendar.current
        guard let dayCount = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: end)).day
        else { _dailyCache = []; return [] }

        // Group expenses by day
        var byDay: [Date: Double] = [:]
        for e in filteredExpenses {
            guard let d = Formatters.date(from: e.date) else { continue }
            let key = cal.startOfDay(for: d)
            byDay[key, default: 0] += e.amount
        }

        // Dense series: every day in range even if 0
        var points: [DailyPoint] = []
        var cursor = cal.startOfDay(for: start)
        for _ in 0...max(dayCount, 0) {
            points.append(DailyPoint(date: cursor, amount: byDay[cursor] ?? 0))
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        _dailyCache = points
        return points
    }

    var categoryStats: [CategoryStat] {
        if let cached = _categoryStatsCache { return cached }
        let result = computeCategoryStats()
        _categoryStatsCache = result
        return result
    }

    private func computeCategoryStats() -> [CategoryStat] {
        let total = self.total
        guard total > 0 else { return [] }

        // Current period: group by category
        var current: [String: Double] = [:]
        for e in filteredExpenses {
            current[e.category, default: 0] += e.amount
        }

        // Previous period: group by category
        var previous: [String: Double] = [:]
        for e in previousPeriodExpenses {
            previous[e.category, default: 0] += e.amount
        }

        // Sparkline per category: last N days of current period
        let points = dailySeries
        let pointsCount = points.count

        return current
            .map { (name, amount) -> CategoryStat in
                let pct = (amount / total) * 100
                let prev = previous[name] ?? 0
                let delta = prev > 0 ? (amount - prev) / prev : 0
                let sparkline = pointsCount > 0
                    ? dailyAmounts(for: name, over: points)
                    : []
                return CategoryStat(
                    name: name,
                    amount: amount,
                    percentage: pct,
                    colorHex: Self.colorHex(for: name, amongAll: Array(current.keys).sorted()),
                    sparkline: sparkline,
                    deltaVsPrevious: delta
                )
            }
            .sorted { $0.amount > $1.amount }
    }

    var insights: [Insight] {
        var out: [Insight] = []
        let stats = categoryStats

        if let top = stats.first {
            out.append(Insight(
                icon: "crown.fill",
                title: "Tu mayor categoría",
                subtitle: "\(top.name) · \(Formatters.currency(top.amount))",
                tintHex: top.colorHex
            ))
        }

        if abs(deltaPercent) >= 0.1, previousTotal > 0 {
            let up = deltaPercent > 0
            out.append(Insight(
                icon: up ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill",
                title: up ? "Gastas más que el periodo anterior" : "Gastas menos que el periodo anterior",
                subtitle: "\(up ? "+" : "")\(Int((deltaPercent * 100).rounded()))% vs \(previousLabel)",
                tintHex: up ? "#FF9500" : "#34C759"
            ))
        }

        if let worstDay = dailySeries.max(by: { $0.amount < $1.amount }), worstDay.amount > 0 {
            let df = DateFormatter()
            df.locale = Locale(identifier: "es_ES")
            df.dateFormat = "EEEE d 'de' MMM"
            out.append(Insight(
                icon: "calendar.badge.exclamationmark",
                title: "Día más caro",
                subtitle: "\(df.string(from: worstDay.date).capitalized) · \(Formatters.currency(worstDay.amount))",
                tintHex: "#AF52DE"
            ))
        }

        let days = max(dailySeries.count, 1)
        let avg = total / Double(days)
        if total > 0 {
            out.append(Insight(
                icon: "chart.line.uptrend.xyaxis",
                title: "Media diaria",
                subtitle: Formatters.currency(avg),
                tintHex: "#007AFF"
            ))
        }

        if let topCat = stats.first(where: { $0.deltaVsPrevious > 0.2 }) {
            out.append(Insight(
                icon: "flame.fill",
                title: "Sube fuerte: \(topCat.name)",
                subtitle: "+\(Int((topCat.deltaVsPrevious * 100).rounded()))% vs \(previousLabel)",
                tintHex: topCat.colorHex
            ))
        }

        return out
    }

    // MARK: - Helpers

    private var previousLabel: String {
        switch selectedPeriod {
        case .week: return "sem. anterior"
        case .month: return "mes anterior"
        case .year: return "año anterior"
        case .all: return "periodo"
        }
    }

    private func dailyAmounts(for category: String, over points: [DailyPoint]) -> [Double] {
        let cal = Calendar.current
        var byDay: [Date: Double] = [:]
        for e in filteredExpenses where e.category == category {
            guard let d = Formatters.date(from: e.date) else { continue }
            byDay[cal.startOfDay(for: d), default: 0] += e.amount
        }
        return points.map { byDay[$0.date] ?? 0 }
    }

    private func dateRange(for period: Period, anchor: Date) -> (Date, Date) {
        let cal = Calendar.current
        let now = cal.startOfDay(for: anchor)
        switch period {
        case .week:
            let start = cal.date(byAdding: .day, value: -6, to: now) ?? now
            return (start, anchor)
        case .month:
            let start = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? now
            return (start, anchor)
        case .year:
            let start = cal.date(from: cal.dateComponents([.year], from: now)) ?? now
            return (start, anchor)
        case .all:
            let far = cal.date(byAdding: .year, value: -10, to: now) ?? now
            return (far, anchor)
        }
    }

    private func previousDateRange(for period: Period, anchor: Date) -> (Date, Date) {
        let cal = Calendar.current
        let now = cal.startOfDay(for: anchor)
        switch period {
        case .week:
            let end = cal.date(byAdding: .day, value: -7, to: now) ?? now
            let start = cal.date(byAdding: .day, value: -6, to: end) ?? end
            return (start, end)
        case .month:
            guard let prevMonth = cal.date(byAdding: .month, value: -1, to: now) else { return (now, now) }
            let start = cal.date(from: cal.dateComponents([.year, .month], from: prevMonth)) ?? prevMonth
            let end = cal.date(byAdding: .month, value: 1, to: start).map { cal.date(byAdding: .day, value: -1, to: $0) ?? $0 } ?? prevMonth
            return (start, end)
        case .year:
            guard let prevYear = cal.date(byAdding: .year, value: -1, to: now) else { return (now, now) }
            let start = cal.date(from: cal.dateComponents([.year], from: prevYear)) ?? prevYear
            let end = cal.date(byAdding: .year, value: 1, to: start).map { cal.date(byAdding: .day, value: -1, to: $0) ?? $0 } ?? prevYear
            return (start, end)
        case .all:
            return (now, now)
        }
    }

    private static let paletteHex: [String] = [
        "#AF52DE", "#007AFF", "#34C759", "#FF9500",
        "#FF3B30", "#FF2D55", "#00C7BE", "#FFCC00",
        "#5856D6", "#8E8E93", "#A2845E", "#32ADE6",
    ]

    private static func colorHex(for category: String, amongAll all: [String]) -> String {
        // Known-name mapping (keep semantic colors consistent with existing logic)
        let map: [String: String] = [
            "vivienda": "#007AFF",
            "alimentacion": "#5856D6",
            "alimentación": "#5856D6",
            "ocio": "#34C759",
            "coche": "#FF9500",
            "moto": "#FF9500",
            "compras": "#FFCC00",
            "salud": "#FF3B30",
            "educacion": "#FF2D55",
            "educación": "#FF2D55",
            "transporte": "#00C7BE",
            "suscripciones": "#AF52DE",
            "otros": "#8E8E93",
        ]
        let lower = category.lowercased()
        for (key, hex) in map where lower.contains(key) {
            return hex
        }
        let idx = (all.firstIndex(of: category) ?? 0) % paletteHex.count
        return paletteHex[idx]
    }

    // MARK: - Data load

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let repo = DependencyContainer.shared.expenseRepository
            let all = try await repo.getExpenses()
            let rules = (try? await DependencyContainer.shared.recurringExpenseRepository.fetchAll()) ?? []
            expenses = ExpenseSanitizer.sanitize(expenses: all, rules: rules)
        } catch {
            expenses = []
        }
    }
}
