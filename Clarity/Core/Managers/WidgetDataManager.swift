// WidgetDataManager.swift
// Manages data sharing between main app and widget via App Group

import Foundation
import OSLog
import WidgetKit

@MainActor
final class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let appGroupID  = "group.com.idanidev.clarity"
    private let widgetKey   = "widgetData_v2"
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "WidgetDataManager")

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    // MARK: - Public API

    /// Full update: call this whenever expenses or budget changes.
    func updateFromExpenses(_ expenses: [Expense], monthBudget: Double? = nil) {
        let calendar = Calendar.current
        let now      = Date()

        let weekStart = calendar.date(
            from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        ) ?? now
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: now)
        ) ?? now

        // ── Single-pass accumulation ──
        var todayTotal: Double = 0
        var weekTotal: Double = 0
        var monthTotal: Double = 0
        var todayCategoryTotals: [String: Double] = [:]
        var monthCategoryTotals: [String: Double] = [:]

        for expense in expenses {
            guard let d = Formatters.date(from: expense.date) else { continue }
            let amount = expense.amount

            if d >= monthStart && d <= now {
                monthTotal += amount
                monthCategoryTotals[expense.category, default: 0] += amount
            }
            if d >= weekStart && d <= now {
                weekTotal += amount
            }
            if calendar.isDateInToday(d) {
                todayTotal += amount
                todayCategoryTotals[expense.category, default: 0] += amount
            }
        }

        let topCategory = todayCategoryTotals.max(by: { $0.value < $1.value })?.key
        let topEmoji = topCategory.map { categoryEmoji(for: $0) } ?? "💳"

        // ── Top 3 categorías del mes ──
        let topMonthCats: [WidgetCategoryStat] = monthCategoryTotals
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { (cat, amount) in
                WidgetCategoryStat(
                    name: cat,
                    emoji: categoryEmoji(for: cat),
                    amount: amount,
                    percent: monthTotal > 0 ? min(amount / monthTotal, 1.0) : 0
                )
            }

        // ── Recent 5 expenses (partial sort) ──
        let recentExpenses = expenses
            .sorted { ($0.date, $0.name) > ($1.date, $1.name) }
            .prefix(5)
            .map { e -> WidgetExpense in
                WidgetExpense(
                    name:     e.name,
                    amount:   e.amount,
                    emoji:    categoryEmoji(for: e.category),
                    category: e.category,
                    timeAgo:  formatTimeAgo(e.date, calendar: calendar)
                )
            }

        // ── Month name ──
        let monthName = Formatters.fullMonthName(from: now)

        var data = SharedWidgetData(
            todayTotal:       todayTotal,
            weekTotal:        weekTotal,
            monthTotal:       monthTotal,
            monthBudget:      monthBudget,   // Lo pasa el caller (HomeVM con income - savings)
            recentExpenses:   Array(recentExpenses),
            topCategoryEmoji: topEmoji,
            currency:         "€",
            monthName:        monthName,
            updatedAt:        now
        )
        data.topMonthCategories = topMonthCats

        save(data)
        logger.debug("✅ [Widget] Updated — Hoy: \(todayTotal)€, Mes: \(monthTotal)€")
    }

    // MARK: - Read (for debugging)

    func getCurrentWidgetData() -> SharedWidgetData? {
        guard
            let defaults = sharedDefaults,
            let raw      = defaults.data(forKey: widgetKey),
            let decoded  = try? JSONDecoder().decode(SharedWidgetData.self, from: raw)
        else { return nil }
        return decoded
    }

    // MARK: - Clear

    func clearWidgetData() {
        sharedDefaults?.removeObject(forKey: widgetKey)
        WidgetCenter.shared.reloadAllTimelines()
        logger.debug("🗑️ [Widget] Data cleared")
    }

    // MARK: - Private

    private func save(_ data: SharedWidgetData) {
        guard let defaults = sharedDefaults else {
            logger.warning("⚠️ [Widget] Cannot access App Group UserDefaults (\(self.appGroupID))")
            return
        }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: widgetKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Category → Emoji
    // Las categorías de Clarity ya llevan el emoji dentro (ej: "Ocio 🍻", "Alimentación 🛒")
    // Lo extraemos directamente en lugar de usar una tabla hardcodeada.

    private func categoryEmoji(for category: String) -> String {
        // Buscar el primer emoji real (codepoint > 127) en la cadena
        for scalar in category.unicodeScalars {
            if scalar.properties.isEmoji && scalar.value > 127 {
                return String(scalar)
            }
        }
        return "💳"
    }

    /// Elimina los emojis del nombre de categoría para mostrar solo el texto
    private func cleanCategory(_ raw: String) -> String {
        raw.unicodeScalars
            .filter { !$0.properties.isEmoji || $0.value < 127 }
            .map { Character($0) }
            .reduce("") { $0 + String($1) }
            .trimmingCharacters(in: .whitespaces)
    }

    // MARK: - Time Ago

    private func formatTimeAgo(_ dateString: String, calendar: Calendar) -> String {
        guard let date = Formatters.date(from: dateString) else { return "" }
        if calendar.isDateInToday(date) {
            return Formatters.time(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            let diff = calendar.dateComponents([.day], from: date, to: Date())
            return "Hace \(diff.day ?? 0)d"
        }
    }
}
