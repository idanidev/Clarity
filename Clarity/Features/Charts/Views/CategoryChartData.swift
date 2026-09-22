// CategoryChartData.swift
// Dato de una categoría para el desglose (`CategoryBreakdownTable`).
// Vivía en DonutChartView.swift, que se eliminó junto con la pestaña de Análisis.

import SwiftUI

// MARK: - Chart Data Model
struct CategoryChartData: Identifiable, Equatable {
    var id: String { name }   // estable: antes UUID() rompía animaciones
    let name: String
    let amount: Double
    let percentage: Double
    let color: Color
    /// Variación vs mismo periodo anterior. nil = sin datos previos.
    /// 0.28 = +28%, -0.15 = -15%.
    var deltaVsPrevious: Double? = nil

    static func == (lhs: CategoryChartData, rhs: CategoryChartData) -> Bool {
        lhs.name == rhs.name && lhs.amount == rhs.amount
            && lhs.deltaVsPrevious == rhs.deltaVsPrevious
    }
}
