// WidgetDataManager.swift
// Manages data sharing between main app and widget via App Group

import Foundation
import WidgetKit

final class WidgetDataManager {
    static let shared = WidgetDataManager()

    private let appGroupID = "group.com.clarity.app"
    private let todaySpendingKey = "todaySpending"
    private let weekSpendingKey = "weekSpending"
    private let lastUpdateKey = "lastWidgetUpdate"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private init() {}

    /// Update widget with current spending data
    /// - Parameters:
    ///   - todayTotal: Total spending for today
    ///   - weekTotal: Total spending for current week
    func updateWidgetData(todayTotal: Double, weekTotal: Double) {
        guard let defaults = sharedDefaults else {
            print("⚠️ Failed to access App Group UserDefaults for widget")
            return
        }

        defaults.set(todayTotal, forKey: todaySpendingKey)
        defaults.set(weekTotal, forKey: weekSpendingKey)
        defaults.set(Date(), forKey: lastUpdateKey)

        // Trigger widget refresh
        WidgetCenter.shared.reloadAllTimelines()

        print("✅ Widget data updated: Today=\(todayTotal), Week=\(weekTotal)")
    }

    /// Calculate and update widget data from expenses
    /// - Parameter expenses: Array of expenses to calculate from
    func updateFromExpenses(_ expenses: [Expense]) {
        let calendar = Calendar.current
        let now = Date()

        // Calculate today's total
        let todayTotal = expenses
            .filter { expense in
                guard let date = Formatters.date(from: expense.date) else { return false }
                return calendar.isDateInToday(date)
            }
            .reduce(0) { $0 + $1.amount }

        // Calculate this week's total
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekTotal = expenses
            .filter { expense in
                guard let date = Formatters.date(from: expense.date) else { return false }
                return date >= weekStart && date <= now
            }
            .reduce(0) { $0 + $1.amount }

        updateWidgetData(todayTotal: todayTotal, weekTotal: weekTotal)
    }

    /// Get current widget data (for debugging)
    func getCurrentWidgetData() -> (today: Double, week: Double)? {
        guard let defaults = sharedDefaults else { return nil }
        let today = defaults.double(forKey: todaySpendingKey)
        let week = defaults.double(forKey: weekSpendingKey)
        return (today, week)
    }

    /// Clear widget data
    func clearWidgetData() {
        guard let defaults = sharedDefaults else { return }
        defaults.removeObject(forKey: todaySpendingKey)
        defaults.removeObject(forKey: weekSpendingKey)
        defaults.removeObject(forKey: lastUpdateKey)
        WidgetCenter.shared.reloadAllTimelines()
        print("🗑️ Widget data cleared")
    }
}
