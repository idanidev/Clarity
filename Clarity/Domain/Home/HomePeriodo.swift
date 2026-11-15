// HomePeriodo.swift
// El tramo de tiempo que enseña la Home (#78). De normal, el mes de la
// cabecera: con presupuesto, ritmo y comparativa. Con un período en la hoja de
// filtros («Todos», «Este año», «Mes anterior», uno a mano) la cifra, el anillo
// y la lista se calculan sobre ese tramo, sin presupuesto ni ritmo, que son
// cosas de un mes. Antes el período solo tocaba la lista, y solo tras pulsar
// Aplicar: poner «Todos» no cambiaba nada a la vista.

import Foundation

nonisolated enum HomePeriodo: Equatable, Sendable {
    /// El mes de la cabecera: la Home de siempre.
    case mes
    /// Otro tramo, con el nombre del período y sus días ("yyyy-MM-dd", ambos incluidos).
    case tramo(nombre: String, desde: String, hasta: String)

    var esMes: Bool {
        if case .mes = self { return true }
        return false
    }

    /// El nombre del período fuera del mes; `nil` en el mes.
    var nombre: String? {
        if case .tramo(let nombre, _, _) = self { return nombre }
        return nil
    }

    private var esTodo: Bool { nombre == ExpenseFilter.DateRange.allTime.rawValue }

    /// La etiqueta sobre la cifra grande.
    var etiquetaCifra: String {
        switch self {
        case .mes: "GASTADO ESTE MES"
        case .tramo(let nombre, _, _): esTodo ? "GASTADO EN TOTAL" : "GASTADO · \(nombre.uppercased())"
        }
    }

    /// La cabecera de la lista de gastos.
    var tituloLista: String {
        switch self {
        case .mes: "Gastos del mes"
        case .tramo(let nombre, _, _): esTodo ? "Todos los gastos" : "Gastos · \(nombre)"
        }
    }

    /// Lo que pide el filtro respecto al mes que se enseña. Un rango a mano
    /// con los días justos del mes, o «Este mes» mirando el mes actual, son el
    /// mes: así lo deja la barra al cambiar de mes. Cualquier otra cosa es un tramo.
    static func de(_ filtro: ExpenseFilter, mes: Date, hoy: Date = Date(), calendar: Calendar = .current) -> HomePeriodo {
        let (desde, hasta) = filtro.dateRangeForQuery()
        switch filtro.dateRange {
        case .thisMonth where calendar.isDate(mes, equalTo: hoy, toGranularity: .month):
            return .mes
        case .custom:
            let inicio = calendar.date(from: calendar.dateComponents([.year, .month], from: mes)) ?? mes
            let fin = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: inicio) ?? mes
            if desde == Formatters.localDayString(from: inicio), hasta == Formatters.localDayString(from: fin) {
                return .mes
            }
            return .tramo(nombre: filtro.dateRange.rawValue, desde: desde, hasta: hasta)
        default:
            return .tramo(nombre: filtro.dateRange.rawValue, desde: desde, hasta: hasta)
        }
    }
}
