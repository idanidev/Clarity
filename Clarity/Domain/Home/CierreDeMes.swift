// CierreDeMes.swift
// Si toca celebrar que el mes anterior se cerró dentro del presupuesto (#65).
//
// Sin SwiftUI: la decisión es pura para poder probarla con unas fechas y unos
// importes. La vista solo enseña la tarjeta cuando esto devuelve algo.

import Foundation

nonisolated enum CierreDeMes {
    /// Días del mes nuevo en los que todavía tiene sentido felicitar por el
    /// anterior. Pasada la primera semana ya no es noticia.
    static let diasParaCelebrar = 7

    /// Lo que sobró del mes anterior si se cerró dentro del presupuesto y toca
    /// celebrarlo; `nil` si no.
    ///
    /// - Parameters:
    ///   - hoy: fecha actual; solo cuenta en los primeros días del mes.
    ///   - totalAnterior: lo gastado el mes anterior.
    ///   - presupuestoAnterior: ingresos del mes anterior, si estaban configurados.
    ///   - yaCelebrado: si ese mes ya se celebró antes.
    static func sobrante(
        hoy: Date,
        totalAnterior: Double,
        presupuestoAnterior: Double?,
        yaCelebrado: Bool,
        calendar: Calendar = .current
    ) -> Double? {
        guard !yaCelebrado,
              let presupuesto = presupuestoAnterior, presupuesto > 0,
              totalAnterior > 0, totalAnterior <= presupuesto,
              calendar.component(.day, from: hoy) <= diasParaCelebrar
        else { return nil }
        return presupuesto - totalAnterior
    }
}
