// Double+Currency.swift
// Centralized formatting extension

import Foundation

extension Double {
    /// Returns the value formatted as currency (e.g., "1,234.56 €")
    var formattedCurrency: String {
        Formatters.currency(self)
    }
}
