// HomeResumen.swift
// Todo lo que enseña la primera página de la Home, calculado sin SwiftUI (#65).
//
// La regla de la pantalla es que ningún cuadro se queda vacío: cada hueco tiene
// una cola de candidatos y gana el primero que tenga datos. Esa resolución vive
// aquí, en un struct puro, para que se pueda probar con un puñado de gastos y
// sin arrancar nada. La vista solo pinta lo que sale.

import Foundation

nonisolated struct HomeResumen: Sendable {

    // MARK: - Piezas

    struct Ritmo: Sendable, Equatable {
        let mediaDiaria: Double
        let prevision: Double
        let diasRestantes: Int
    }

    /// Frente al mes anterior, pero solo hasta el mismo día: a mediados de mes,
    /// compararse con el mes anterior entero da siempre "menos" y no dice nada.
    struct Comparativa: Sendable, Equatable {
        let totalAnterior: Double
        /// Negativo cuando se gasta menos que el mes anterior.
        var delta: Double { totalActual - totalAnterior }
        var porcentaje: Int { totalAnterior > 0 ? Int(((delta / totalAnterior) * 100).rounded()) : 0 }
        let totalActual: Double
        /// Día del mes hasta el que se compara. Si es el mes completo, coincide
        /// con su último día.
        let hastaDia: Int
        /// `true` cuando el tramo es parcial: hay que decirlo en pantalla.
        let parcial: Bool
    }

    struct Limite: Sendable, Equatable, Identifiable {
        var id: String { categoria }
        let categoria: String
        let gastado: Double
        let tope: Double
        var progreso: Double { tope > 0 ? min(gastado / tope, 1) : 0 }
        var restante: Double { tope - gastado }
        var superado: Bool { gastado > tope }
    }

    struct Reparto: Sendable, Equatable, Identifiable {
        var id: String { categoria }
        let categoria: String
        let importe: Double
        let porcentaje: Int
    }

    struct Cargo: Sendable, Equatable, Identifiable {
        var id: String { nombre + "\(dia)" }
        let nombre: String
        let importe: Double
        let dia: Int
    }

    struct Deuda: Sendable, Equatable, Identifiable {
        var id: String { nombre }
        let nombre: String
        let importe: Double
    }

    struct Hucha: Sendable, Equatable {
        let nombre: String
        let actual: Double
        let objetivo: Double
        var progreso: Double { objetivo > 0 ? min(actual / objetivo, 1) : 0 }
    }

    struct DiaCaro: Sendable, Equatable {
        let fecha: Date
        let importe: Double
        let concepto: String
    }

    struct Semana: Sendable, Equatable {
        let actual: Double
        let anterior: Double
        var porcentaje: Int { anterior > 0 ? Int((((actual - anterior) / anterior) * 100).rounded()) : 0 }
    }

    struct Subida: Sendable, Equatable {
        let categoria: String
        let delta: Double
    }

    /// Lo que puede ocupar un hueco. Los casos son los candidatos de todas las
    /// colas; cada hueco tiene la suya en `Slot.candidatos`.
    enum Contenido: Sendable, Equatable {
        case limites([Limite])
        case reparto([Reparto])
        case cargos([Cargo], total: Double)
        case teDeben([Deuda], total: Double)
        case hucha(Hucha)
        case diaCaro(DiaCaro)
        case semana(Semana)
        case subeFuerte(Subida)
        case comparativa(Comparativa)
        case semanaASemana([Double])

        var clase: String {
            switch self {
            case .limites: "limites"
            case .reparto: "reparto"
            case .cargos: "cargos"
            case .teDeben: "teDeben"
            case .hucha: "hucha"
            case .diaCaro: "diaCaro"
            case .semana: "semana"
            case .subeFuerte: "subeFuerte"
            case .comparativa: "comparativa"
            case .semanaASemana: "semanaASemana"
            }
        }
    }

    enum Slot: CaseIterable, Sendable {
        case a, b, c, e

        /// La cola de cada hueco, por orden. Es la tabla del lienzo, en código.
        var candidatos: [String] {
            switch self {
            case .a: ["limites", "reparto"]
            case .b: ["cargos", "diaCaro", "subeFuerte"]
            case .c: ["teDeben", "hucha", "semana", "diaCaro"]
            case .e: ["hucha", "comparativa", "semanaASemana", "subeFuerte"]
            }
        }
    }

    // MARK: - Resultado

    let total: Double
    let numeroGastos: Int
    let presupuesto: Double?
    let ritmo: Ritmo
    let comparativa: Comparativa?
    let diasApuntando: Int
    let slots: [Slot: Contenido]
    /// Aparte de los huecos: Gráficas lo señala aunque el hueco B lo ocupe otra cosa.
    let diaMasCaro: DiaCaro?

    var libres: Double? { presupuesto.map { $0 - total } }
    var progresoPresupuesto: Double? { presupuesto.flatMap { $0 > 0 ? min(total / $0, 1) : nil } }

    // MARK: - Cálculo

    /// - Parameters:
    ///   - gastos: los del mes que se enseña.
    ///   - gastosMesAnterior: los del mes anterior completo; vacío si no hay.
    ///   - metas: límites (`spendingLimit`) y huchas (`savingsTarget`).
    ///   - recurrentes: reglas activas.
    ///   - presupuesto: la nómina del mes si está configurada.
    ///   - primerGasto: fecha del primer gasto que apuntó el usuario, para "N días apuntando".
    static func build(
        gastos: [Expense],
        gastosMesAnterior: [Expense],
        metas: [Goal],
        recurrentes: [RecurringExpense],
        presupuesto: Double?,
        primerGasto: Date?,
        hoy: Date = Date(),
        calendar: Calendar = .current
    ) -> HomeResumen {
        let total = gastos.reduce(0) { $0 + $1.amount }
        let diaActual = calendar.component(.day, from: hoy)
        let diasMes = calendar.range(of: .day, in: .month, for: hoy)?.count ?? 30
        let media = diaActual > 0 ? total / Double(diaActual) : 0
        let ritmo = Ritmo(
            mediaDiaria: media,
            prevision: media * Double(diasMes),
            diasRestantes: max(diasMes - diaActual, 0)
        )

        // Del mes anterior solo cuenta hasta el día en que estamos.
        let anteriorMismoTramo = Self.mismoTramo(gastosMesAnterior, hastaDia: diaActual, calendar: calendar)
        let totalAnterior = anteriorMismoTramo.reduce(0) { $0 + $1.amount }
        let comparativa: Comparativa? = gastosMesAnterior.isEmpty
            ? nil
            : Comparativa(totalAnterior: totalAnterior, totalActual: total,
                          hastaDia: diaActual, parcial: diaActual < diasMes)

        let diasApuntando = primerGasto.map {
            max((calendar.dateComponents([.day], from: $0, to: hoy).day ?? 0) + 1, 1)
        } ?? 0

        // Todo lo que existe, sin decidir aún dónde va.
        var disponibles: [String: Contenido] = [:]

        let porCategoria = Dictionary(grouping: gastos, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }

        let limites = metas
            .filter { $0.type == .spendingLimit && !$0.isArchived }
            .compactMap { meta -> Limite? in
                guard let cat = meta.linkedCategoryId ?? Optional(meta.name) else { return nil }
                return Limite(categoria: cat, gastado: porCategoria[cat] ?? 0, tope: meta.targetAmount)
            }
            .sorted { $0.progreso > $1.progreso }
        if !limites.isEmpty { disponibles["limites"] = .limites(limites) }

        if total > 0 {
            let reparto = porCategoria
                .map { Reparto(categoria: $0.key, importe: $0.value,
                               porcentaje: Int(($0.value / total * 100).rounded())) }
                .sorted { $0.importe > $1.importe }
                .prefix(3)
            disponibles["reparto"] = .reparto(Array(reparto))
        }

        let mesActual = calendar.component(.month, from: hoy)
        let cargos = recurrentes
            .filter { $0.active && $0.isValid }
            .filter { $0.frequency == .monthly || $0.billingMonth == mesActual }
            .filter { $0.dayOfMonth >= diaActual }
            .sorted { $0.dayOfMonth < $1.dayOfMonth }
            .prefix(3)
            .map { Cargo(nombre: $0.name, importe: $0.amount, dia: $0.dayOfMonth) }
        if !cargos.isEmpty {
            disponibles["cargos"] = .cargos(Array(cargos), total: cargos.reduce(0) { $0 + $1.importe })
        }

        var deudasPorNombre: [String: Double] = [:]
        for gasto in gastos {
            for deudor in gasto.debtors ?? [] where !deudor.isPaid {
                deudasPorNombre[deudor.name, default: 0] += deudor.amount
            }
        }
        let deudas = deudasPorNombre
            .map { Deuda(nombre: $0.key, importe: $0.value) }
            .sorted { $0.importe > $1.importe }
        if !deudas.isEmpty {
            disponibles["teDeben"] = .teDeben(deudas, total: deudas.reduce(0) { $0 + $1.importe })
        }

        // Una hucha a 0 € no es información: el hueco lo ocupa lo siguiente de
        // la cola. Entre las que tienen algo, la más avanzada.
        if let meta = metas
            .filter({ $0.type == .savingsTarget && !$0.isArchived && $0.currentAmount > 0 })
            .max(by: { ($0.currentAmount / max($0.targetAmount, 1)) < ($1.currentAmount / max($1.targetAmount, 1)) }) {
            disponibles["hucha"] = .hucha(Hucha(nombre: meta.name, actual: meta.currentAmount, objetivo: meta.targetAmount))
        }

        let porDia = Dictionary(grouping: gastos, by: \.date)
        var diaMasCaro: DiaCaro?
        if let (fecha, delDia) = porDia.max(by: { a, b in
            a.value.reduce(0) { $0 + $1.amount } < b.value.reduce(0) { $0 + $1.amount }
        }), let date = Formatters.date(from: fecha), delDia.count > 0 {
            let importe = delDia.reduce(0) { $0 + $1.amount }
            let mayor = delDia.max(by: { $0.amount < $1.amount })?.name ?? ""
            diaMasCaro = DiaCaro(fecha: date, importe: importe, concepto: mayor)
            disponibles["diaCaro"] = .diaCaro(diaMasCaro!)
        }

        if let semana = Self.semanaVsAnterior(gastos: gastos, hoy: hoy, calendar: calendar) {
            disponibles["semana"] = .semana(semana)
        }

        if !gastosMesAnterior.isEmpty {
            let anteriorPorCat = Dictionary(grouping: anteriorMismoTramo, by: \.category)
                .mapValues { $0.reduce(0) { $0 + $1.amount } }
            let deltas = porCategoria.map { ($0.key, $0.value - (anteriorPorCat[$0.key] ?? 0)) }
            if let (cat, delta) = deltas.max(by: { $0.1 < $1.1 }), delta > 0 {
                disponibles["subeFuerte"] = .subeFuerte(Subida(categoria: cat, delta: delta))
            }
            if let comparativa { disponibles["comparativa"] = .comparativa(comparativa) }
        }

        let semanas = Self.totalesPorSemana(gastos: gastos, calendar: calendar)
        if semanas.count >= 2 { disponibles["semanaASemana"] = .semanaASemana(semanas) }

        // Reparto: cada hueco toma el primero de su cola que exista y que no
        // se haya usado ya en otro hueco.
        var usados = Set<String>()
        var slots: [Slot: Contenido] = [:]
        for slot in Slot.allCases {
            for clase in slot.candidatos where !usados.contains(clase) {
                if let contenido = disponibles[clase] {
                    slots[slot] = contenido
                    usados.insert(clase)
                    break
                }
            }
        }

        return HomeResumen(
            total: total,
            numeroGastos: gastos.count,
            presupuesto: presupuesto,
            ritmo: ritmo,
            comparativa: comparativa,
            diasApuntando: diasApuntando,
            slots: slots,
            diaMasCaro: diaMasCaro
        )
    }

    // MARK: - Helpers

    /// Los gastos de un mes hasta un día incluido. Para comparar como es debido.
    static func mismoTramo(_ gastos: [Expense], hastaDia: Int, calendar: Calendar) -> [Expense] {
        gastos.filter { calendar.component(.day, from: $0.dateAsDate) <= hastaDia }
    }

    /// Esta semana frente a la anterior HASTA EL MISMO DÍA de la semana: un
    /// miércoles se compara lunes–miércoles con lunes–miércoles, no con la
    /// semana pasada entera, que siempre saldría mayor.
    private static func semanaVsAnterior(gastos: [Expense], hoy: Date, calendar: Calendar) -> Semana? {
        guard let inicioSemana = calendar.dateInterval(of: .weekOfYear, for: hoy)?.start,
              let inicioAnterior = calendar.date(byAdding: .day, value: -7, to: inicioSemana),
              let finHoy = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: hoy)),
              let finTramoAnterior = calendar.date(byAdding: .day, value: -7, to: finHoy)
        else { return nil }
        var actual = 0.0, anterior = 0.0
        for g in gastos {
            let d = g.dateAsDate
            if d >= inicioSemana && d < finHoy { actual += g.amount }
            else if d >= inicioAnterior && d < finTramoAnterior { anterior += g.amount }
        }
        guard anterior > 0 else { return nil }
        return Semana(actual: actual, anterior: anterior)
    }

    /// Totales de las semanas del mes que ya tienen gastos, en orden.
    private static func totalesPorSemana(gastos: [Expense], calendar: Calendar) -> [Double] {
        var porSemana: [Int: Double] = [:]
        for g in gastos {
            porSemana[calendar.component(.weekOfMonth, from: g.dateAsDate), default: 0] += g.amount
        }
        return porSemana.keys.sorted().map { porSemana[$0] ?? 0 }
    }
}
