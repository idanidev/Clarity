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
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.locale = Locale(identifier: "en_US_POSIX")
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

    /// "yyyy-MM-dd" en TZ LOCAL — usar cuando el `Date` viene de un DatePicker
    /// (DatePicker devuelve midnight local del día elegido; con UTC formatter se
    /// convertiría al día anterior en zonas con offset positivo).
    private static let localDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        // Sin timeZone explícito → usa la del dispositivo
        return f
    }()

    static func localDayString(from date: Date) -> String {
        localDayFormatter.string(from: date)
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

    // MARK: - Month Name

    /// Returns a short Spanish month abbreviation for a 1-based month index (1=Ene, 12=Dic).
    static func shortMonthName(_ month: Int) -> String {
        let names = ["Ene", "Feb", "Mar", "Abr", "May", "Jun",
                     "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"]
        guard month >= 1 && month <= 12 else { return "?" }
        return names[month - 1]
    }

    /// Full Spanish month name for a 1-based month index (1=Enero, 12=Diciembre).
    static func fullMonthName(_ month: Int) -> String {
        guard month >= 1, month <= 12 else { return "?" }
        return spanishMonthSymbols[month - 1]
    }

    private static let spanishMonthSymbols: [String] = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        return fmt.monthSymbols.map { $0.capitalized }
    }()

    // MARK: - Short Display Date

    private static let shortDisplayFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "d MMM"
        fmt.locale = Locale(identifier: "es_ES")
        return fmt
    }()

    /// "3 ene" style from iso string
    static func shortDisplay(_ isoString: String) -> String {
        guard let d = date(from: isoString) else { return isoString }
        return shortDisplayFormatter.string(from: d)
    }

    // MARK: - Time Only

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt
    }()

    static func time(from date: Date) -> String {
        timeFormatter.string(from: date)
    }

    // MARK: - Full Month Name from Date

    private static let fullMonthOnlyFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "es_ES")
        fmt.dateFormat = "MMMM"
        return fmt
    }()

    static func fullMonthName(from date: Date) -> String {
        fullMonthOnlyFormatter.string(from: date).capitalized
    }
}
