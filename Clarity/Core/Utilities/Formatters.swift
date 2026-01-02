// Formatters.swift
// Utilidades centralizadas de formateo

import Foundation

enum Formatters {
    
    // MARK: - Currency
    
    private static let currencyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()
    
    static func currency(_ value: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f €", value)
    }
    
    static func currencyCompact(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.1fk €", value / 1000)
        }
        return String(format: "%.0f €", value)
    }
    
    // MARK: - Date
    
    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()
    
    private static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "es_ES")
        return formatter
    }()
    
    private static let shortMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
    
    static func isoString(from date: Date) -> String {
        isoDateFormatter.string(from: date)
    }
    
    static func date(from isoString: String) -> Date? {
        isoDateFormatter.date(from: isoString)
    }
    
    static func displayDate(_ isoString: String) -> String {
        guard let date = date(from: isoString) else { return isoString }
        return displayDateFormatter.string(from: date)
    }
    
    static func monthYear(from date: Date) -> String {
        monthYearFormatter.string(from: date).capitalized
    }
    
    static func currentMonthString() -> String {
        shortMonthFormatter.string(from: Date())
    }
    
    static func monthString(from date: Date) -> String {
        shortMonthFormatter.string(from: date)
    }
}
