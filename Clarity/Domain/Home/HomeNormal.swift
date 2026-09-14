// HomeNormal.swift
// Lo normal de este usuario (#65): sus últimos meses resumidos para medir el
// mes que se enseña contra su propia costumbre, no contra el mes pasado ni
// contra un promedio de nadie. Sin SwiftUI: se prueba con un puñado de gastos.

import Foundation

nonisolated struct HomeNormal: Sendable, Equatable {
    /// Por debajo de esto no hay "normal" que valga: no se construye.
    static let minimoMeses = 2

    /// Meses del tramo que tienen algún gasto.
    let meses: Int
    /// Mediana de lo gastado al mes, todo incluido.
    let totalMensual: Double
    /// Mediana mensual por categoría, sin los cargos recurrentes: el alquiler
    /// no es una costumbre que se pueda desviar. Un mes sin esa categoría
    /// cuenta como 0.
    let porCategoria: [String: Double]
    /// Gasto medio por día de la semana, con los números de `Calendar`
    /// (1 = domingo). Sin recurrentes, por lo mismo.
    let porDiaSemana: [Int: Double]
    /// Total de cada mes del tramo, por "yyyy-MM".
    let totalesPorMes: [String: Double]
    /// Un gasto por debajo de esto es "hormiga": el cuartil bajo de los
    /// importes del usuario, entre 3 y 10 €.
    let umbralHormiga: Double
    /// Parte de los ingresos que quedó sin gastar, de media (0,09 = 9 %).
    /// Solo con presupuestos de esos meses.
    let ahorroMedio: Double?
    /// Días con algún gasto en el tramo, "yyyy-MM-dd", para la racha.
    let diasConGasto: Set<String>

    /// - Parameters:
    ///   - historico: gastos de cualquier mes; se usan solo los `ventana`
    ///     meses anteriores a `mes`.
    ///   - mes: el mes que se enseña; queda fuera del tramo.
    ///   - presupuestos: ingresos por "yyyy-MM", si se conocen.
    static func build(
        historico: [Expense],
        mes: Date,
        meses ventana: Int = 6,
        presupuestos: [String: Double] = [:],
        calendar: Calendar = .current
    ) -> HomeNormal? {
        let claves: [String] = (1...max(ventana, 1)).compactMap { atras in
            calendar.date(byAdding: .month, value: -atras, to: mes).map { Self.clave($0, calendar: calendar) }
        }
        let tramo = Set(claves)
        let porMes = Dictionary(grouping: historico.filter { tramo.contains(String($0.date.prefix(7))) },
                                by: { String($0.date.prefix(7)) })
        guard porMes.count >= minimoMeses else { return nil }

        let totalesPorMes = porMes.mapValues { $0.reduce(0) { $0 + $1.amount } }

        // Categorías: la mediana de cada una a lo largo de los meses con datos.
        let variables = porMes.mapValues { $0.filter { !$0.esRecurrente } }
        var porCategoriaYMes: [String: [String: Double]] = [:]
        for (clave, gastos) in variables {
            for g in gastos { porCategoriaYMes[g.category, default: [:]][clave, default: 0] += g.amount }
        }
        let porCategoria = porCategoriaYMes.mapValues { meses in
            Self.mediana(porMes.keys.map { meses[$0] ?? 0 })
        }

        // Día de la semana: la suma de cada uno entre las veces que cae en el tramo.
        var sumaPorDia: [Int: Double] = [:]
        for g in variables.values.joined() {
            guard let fecha = Formatters.date(from: g.date) else { continue }
            sumaPorDia[calendar.component(.weekday, from: fecha), default: 0] += g.amount
        }
        var vecesPorDia: [Int: Int] = [:]
        for clave in porMes.keys {
            guard let inicio = Self.fecha(clave, calendar: calendar),
                  let dias = calendar.range(of: .day, in: .month, for: inicio)?.count else { continue }
            for d in 0..<dias {
                guard let fecha = calendar.date(byAdding: .day, value: d, to: inicio) else { continue }
                vecesPorDia[calendar.component(.weekday, from: fecha), default: 0] += 1
            }
        }
        let porDiaSemana = sumaPorDia.reduce(into: [Int: Double]()) { acc, par in
            let veces = vecesPorDia[par.key] ?? 0
            if veces > 0 { acc[par.key] = par.value / Double(veces) }
        }

        let importes = variables.values.joined().map(\.amount).sorted()
        let cuartil = importes.isEmpty ? 5 : importes[importes.count / 4]
        let umbralHormiga = min(max(cuartil.rounded(), 3), 10)

        let ahorros: [Double] = porMes.keys.compactMap { clave in
            guard let ingresos = presupuestos[clave], ingresos > 0 else { return nil }
            return (ingresos - (totalesPorMes[clave] ?? 0)) / ingresos
        }
        let ahorroMedio = ahorros.isEmpty ? nil : ahorros.reduce(0, +) / Double(ahorros.count)

        return HomeNormal(
            meses: porMes.count,
            totalMensual: Self.mediana(Array(totalesPorMes.values)),
            porCategoria: porCategoria,
            porDiaSemana: porDiaSemana,
            totalesPorMes: totalesPorMes,
            umbralHormiga: umbralHormiga,
            ahorroMedio: ahorroMedio,
            diasConGasto: Set(porMes.values.joined().map { String($0.date.prefix(10)) })
        )
    }

    // MARK: - Helpers

    static func mediana(_ valores: [Double]) -> Double {
        let ordenados = valores.sorted()
        guard !ordenados.isEmpty else { return 0 }
        let mitad = ordenados.count / 2
        return ordenados.count % 2 == 0 ? (ordenados[mitad - 1] + ordenados[mitad]) / 2 : ordenados[mitad]
    }

    /// "yyyy-MM" de una fecha, con el mismo criterio que `Expense.date`.
    static func clave(_ fecha: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month], from: fecha)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private static func fecha(_ clave: String, calendar: Calendar) -> Date? {
        let partes = clave.split(separator: "-")
        guard partes.count == 2, let anio = Int(partes[0]), let mes = Int(partes[1]) else { return nil }
        return calendar.date(from: DateComponents(year: anio, month: mes, day: 1))
    }
}

nonisolated extension Expense {
    /// Creado por una regla recurrente: no dice nada de cómo gasta el usuario.
    var esRecurrente: Bool { recurringId != nil || isRecurring == true || recurring == true }
}
