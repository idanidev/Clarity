// MonthlySpending.swift
// Modelo ligero para series temporales de gasto mensual (gráfica evolución).

import Foundation

struct MonthlySpending: Identifiable, Equatable, Sendable {
    var id: String { key }
    let key: String      // "YYYY-MM"
    let label: String    // "Ene"
    let total: Double
}
