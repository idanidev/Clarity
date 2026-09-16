// HomeResumen.swift
// Todo lo que enseña la primera página de la Home, calculado sin SwiftUI (#65).
//
// La regla de la pantalla es que ningún cuadro se queda vacío y que lo que
// sale es lo que más le importa a este usuario este mes: cada hueco tiene una
// lista de lo que le cabe, cada contenido una relevancia, y gana el más
// relevante. Esa resolución vive aquí, en un struct puro, para que se pueda
// probar con un puñado de gastos y sin arrancar nada. La vista solo pinta.

import Foundation

nonisolated struct HomeResumen: Sendable {

    // MARK: - Piezas

    struct Ritmo: Sendable, Equatable {
        let mediaDiaria: Double
        /// Lo que hay más lo que queda: el gasto variable a este ritmo y los
        /// cargos recurrentes que aún no han pasado. Media × días del mes
        /// contaba el alquiler del día 1 como si se repitiera cada día.
        let prevision: Double
        let diasRestantes: Int
        /// Cargos recurrentes que quedan por cobrarse este mes.
        let cargosPendientes: Double
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

    // Lo que sale de "tu normal" (HomeNormal).

    /// Una categoría lejos de lo que este usuario suele gastar en ella.
    struct Desvio: Sendable, Equatable {
        let categoria: String
        let actual: Double
        /// Lo normal a estas alturas del mes.
        let esperado: Double
        let normalMensual: Double
        /// Positivo por encima de lo normal.
        let porcentaje: Int
    }

    /// Un comercio repetido este mes.
    struct Sitio: Sendable, Equatable, Identifiable {
        var id: String { nombre }
        let nombre: String
        let veces: Int
        let total: Double
        var media: Double { veces > 0 ? total / Double(veces) : 0 }
    }

    /// El día de la semana en que más se gasta, según el historial.
    struct DiaSemana: Sendable, Equatable {
        /// Como en `Calendar`: 1 = domingo.
        let dia: Int
        let media: Double
        let mediaResto: Double
        let esHoy: Bool
    }

    struct Hormiga: Sendable, Equatable {
        let umbral: Double
        let cantidad: Int
        let total: Double
    }

    /// Lo que quedará sin gastar si el mes sigue así.
    struct Ahorro: Sendable, Equatable {
        let previsto: Double
        /// Sobre los ingresos: 0,13 = 13 %.
        let porcentaje: Double
        /// La media del usuario, si hay presupuestos anteriores.
        let medio: Double?
    }

    /// Dónde cae este mes entre los anteriores.
    struct Ranking: Sendable, Equatable {
        /// 1 = el más barato.
        let posicion: Int
        let de: Int
        let referencia: Double
        let minimo: Double
        let maximo: Double
        /// `true` si la referencia es la previsión y no el cierre.
        let proyectado: Bool
    }

    struct Racha: Sendable, Equatable {
        let dias: Int
        let record: Int
    }

    /// Una categoría grande sin tope: lo que se suele gastar, para ponerle uno.
    struct LimiteSugerido: Sendable, Equatable {
        let categoria: String
        let normalMensual: Double
        let actual: Double
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
        case fueraDeNormal(Desvio)
        case sitios([Sitio])
        case diaSemana(DiaSemana)
        case hormiga(Hormiga)
        case ahorro(Ahorro)
        case ranking(Ranking)
        case racha(Racha)
        case limiteSugerido(LimiteSugerido)

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
            case .fueraDeNormal: "fueraDeNormal"
            case .sitios: "sitios"
            case .diaSemana: "diaSemana"
            case .hormiga: "hormiga"
            case .ahorro: "ahorro"
            case .ranking: "ranking"
            case .racha: "racha"
            case .limiteSugerido: "limiteSugerido"
            }
        }
    }

    enum Slot: CaseIterable, Sendable {
        case a, b, c, e

        /// Lo que le cabe a cada hueco. A y E son anchos; B y C, medias
        /// tarjetas. Entre lo que cabe gana el más relevante; a igualdad, el
        /// que va antes en la lista.
        var candidatos: [String] {
            switch self {
            case .a: ["limites", "fueraDeNormal", "reparto", "sitios", "limiteSugerido"]
            case .b: ["cargos", "diaCaro", "subeFuerte", "fueraDeNormal", "hormiga", "diaSemana", "ranking", "ahorro", "racha"]
            case .c: ["teDeben", "hucha", "semana", "diaCaro", "ahorro", "diaSemana", "hormiga", "ranking", "racha"]
            case .e: ["hucha", "comparativa", "semanaASemana", "sitios", "limiteSugerido", "subeFuerte", "fueraDeNormal"]
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
    /// Todo lo que había disponible y cuánto importaba, por clase. Para
    /// entender por qué salió lo que salió.
    let relevancias: [String: Double]

    // Lo que pasa el filtro. Sin filtro coincide con el mes entero.
    let totalAnalisis: Double
    let numeroAnalisis: Int
    let mediaDiariaAnalisis: Double
    /// La comparativa de lo filtrado frente a lo filtrado del mes anterior.
    let comparativaAnalisis: Comparativa?

    var libres: Double? { presupuesto.map { $0 - total } }

    /// Lo que se puede gastar cada día, hoy incluido, sin pasarse del
    /// presupuesto. Es el dato con el que se decide; "quedan 17 días" no lo es.
    var disponiblePorDia: Double? {
        guard let libres else { return nil }
        return max(libres, 0) / Double(ritmo.diasRestantes + 1)
    }
    var progresoPresupuesto: Double? { presupuesto.flatMap { $0 > 0 ? min(total / $0, 1) : nil } }

    // MARK: - Cálculo

    /// - Parameters:
    ///   - gastos: los del mes que se enseña.
    ///   - gastosMesAnterior: los del mes anterior completo; vacío si no hay.
    ///   - metas: límites (`spendingLimit`) y huchas (`savingsTarget`).
    ///   - recurrentes: reglas activas.
    ///   - presupuesto: la nómina del mes si está configurada.
    ///   - primerGasto: fecha del primer gasto que apuntó el usuario, para "N días apuntando".
    ///   - normal: la costumbre del usuario, si hay meses detrás. Sin ella, lo
    ///     que se mide contra "tu normal" no sale.
    ///   - preferencias: lo que el usuario ocultó no sale; lo que ordenó gana el hueco.
    ///   - filtro: los filtros puestos en la Home, si hay. Lo que habla de en qué
    ///     se gasta —reparto, día más caro, semanas, subidas, sitios, hormigas y
    ///     comparativa de las tarjetas— mira solo lo que lo pasa. Total, ritmo,
    ///     límites, deudas y lo medido contra tu normal siguen siendo del mes
    ///     entero: presupuesto, topes y costumbre se miden contra todo.
    static func build(
        gastos: [Expense],
        gastosMesAnterior: [Expense],
        metas: [Goal],
        recurrentes: [RecurringExpense],
        presupuesto: Double?,
        primerGasto: Date?,
        hoy: Date = Date(),
        calendar: Calendar = .current,
        normal: HomeNormal? = nil,
        preferencias: HomePreferencias = HomePreferencias(),
        filtro: ((Expense) -> Bool)? = nil
    ) -> HomeResumen {
        let total = gastos.reduce(0) { $0 + $1.amount }
        let diaActual = calendar.component(.day, from: hoy)
        let diasMes = calendar.range(of: .day, in: .month, for: hoy)?.count ?? 30
        let diasRestantes = max(diasMes - diaActual, 0)
        let media = diaActual > 0 ? total / Double(diaActual) : 0

        // Los recurrentes de este mes: los que ya han pasado están en `total`;
        // los que quedan se suman a la previsión tal cual, sin pasarlos por el ritmo.
        let mesActual = calendar.component(.month, from: hoy)
        let recurrentesDelMes = recurrentes
            .filter { $0.active && $0.isValid }
            .filter { $0.frequency == .monthly || $0.billingMonth == mesActual }
        let cargosPendientes = recurrentesDelMes
            .filter { $0.dayOfMonth > diaActual }
            .reduce(0) { $0 + $1.amount }
        let cobradoRecurrente = gastos.filter(\.esRecurrente).reduce(0) { $0 + $1.amount }
        let mediaVariable = diaActual > 0 ? max(total - cobradoRecurrente, 0) / Double(diaActual) : 0
        let ritmo = Ritmo(
            mediaDiaria: media,
            prevision: total + mediaVariable * Double(diasRestantes) + cargosPendientes,
            diasRestantes: diasRestantes,
            cargosPendientes: cargosPendientes
        )

        // Del mes anterior solo cuenta hasta el día en que estamos.
        let anteriorMismoTramo = Self.mismoTramo(gastosMesAnterior, hastaDia: diaActual, calendar: calendar)
        let totalAnterior = anteriorMismoTramo.reduce(0) { $0 + $1.amount }
        let comparativa: Comparativa? = gastosMesAnterior.isEmpty
            ? nil
            : Comparativa(totalAnterior: totalAnterior, totalActual: total,
                          hastaDia: diaActual, parcial: diaActual < diasMes)

        // Lo que pasa el filtro, en este mes y en el anterior.
        let analisis = filtro.map { gastos.filter($0) } ?? gastos
        let anteriorAnalisis = filtro.map { gastosMesAnterior.filter($0) } ?? gastosMesAnterior
        let totalAnalisis = analisis.reduce(0) { $0 + $1.amount }
        let anteriorAnalisisMismoTramo = Self.mismoTramo(anteriorAnalisis, hastaDia: diaActual, calendar: calendar)
        let comparativaAnalisis: Comparativa? = anteriorAnalisis.isEmpty
            ? nil
            : Comparativa(totalAnterior: anteriorAnalisisMismoTramo.reduce(0) { $0 + $1.amount },
                          totalActual: totalAnalisis, hastaDia: diaActual, parcial: diaActual < diasMes)

        let diasApuntando = primerGasto.map {
            max((calendar.dateComponents([.day], from: $0, to: hoy).day ?? 0) + 1, 1)
        } ?? 0

        // Todo lo que existe, sin decidir aún dónde va.
        var disponibles: [String: Contenido] = [:]

        // Los límites miden todo lo gastado en su categoría, haya filtro o no.
        let porCategoria = Dictionary(grouping: gastos, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let porCategoriaAnalisis = Dictionary(grouping: analisis, by: \.category)
            .mapValues { $0.reduce(0) { $0 + $1.amount } }

        let topes = metas.filter { $0.type == .spendingLimit && !$0.isArchived }
        let categoriasConTope = Set(topes.compactMap { $0.linkedCategoryId ?? Optional($0.name) })
        let limites = topes
            .compactMap { meta -> Limite? in
                guard let cat = meta.linkedCategoryId ?? Optional(meta.name) else { return nil }
                return Limite(categoria: cat, gastado: porCategoria[cat] ?? 0, tope: meta.targetAmount)
            }
            .sorted { $0.progreso > $1.progreso }
        if !limites.isEmpty { disponibles["limites"] = .limites(limites) }

        if totalAnalisis > 0 {
            let reparto = porCategoriaAnalisis
                .map { Reparto(categoria: $0.key, importe: $0.value,
                               porcentaje: Int(($0.value / totalAnalisis * 100).rounded())) }
                .sorted { $0.importe > $1.importe }
                .prefix(3)
            disponibles["reparto"] = .reparto(Array(reparto))
        }

        let cargos = recurrentesDelMes
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

        let porDia = Dictionary(grouping: analisis, by: \.date)
        var diaMasCaro: DiaCaro?
        if let (fecha, delDia) = porDia.max(by: { a, b in
            a.value.reduce(0) { $0 + $1.amount } < b.value.reduce(0) { $0 + $1.amount }
        }), let date = Formatters.date(from: fecha), delDia.count > 0 {
            let importe = delDia.reduce(0) { $0 + $1.amount }
            let mayor = delDia.max(by: { $0.amount < $1.amount })?.name ?? ""
            diaMasCaro = DiaCaro(fecha: date, importe: importe, concepto: mayor)
            disponibles["diaCaro"] = .diaCaro(diaMasCaro!)
        }

        if let semana = Self.semanaVsAnterior(gastos: analisis, hoy: hoy, calendar: calendar) {
            disponibles["semana"] = .semana(semana)
        }

        var subidaRelativa = 0.0
        if !anteriorAnalisis.isEmpty {
            let anteriorPorCat = Dictionary(grouping: anteriorAnalisisMismoTramo, by: \.category)
                .mapValues { $0.reduce(0) { $0 + $1.amount } }
            let deltas = porCategoriaAnalisis.map { ($0.key, $0.value - (anteriorPorCat[$0.key] ?? 0)) }
            if let (cat, delta) = deltas.max(by: { $0.1 < $1.1 }), delta > 0 {
                disponibles["subeFuerte"] = .subeFuerte(Subida(categoria: cat, delta: delta))
                let base = anteriorAnalisisMismoTramo.reduce(0) { $0 + $1.amount }
                subidaRelativa = base > 0 ? delta / base : 0
            }
            if let comparativaAnalisis { disponibles["comparativa"] = .comparativa(comparativaAnalisis) }
        }

        let semanas = Self.totalesPorSemana(gastos: analisis, calendar: calendar)
        if semanas.count >= 2 { disponibles["semanaASemana"] = .semanaASemana(semanas) }

        // Comercios repetidos este mes. Los recurrentes no cuentan: ir nueve
        // veces al súper es un hábito; que Netflix cobre una vez, no.
        var porSitio: [String: Sitio] = [:]
        for g in analisis where !g.esRecurrente {
            let clave = Self.normalizar(g.name)
            guard !clave.isEmpty else { continue }
            let previo = porSitio[clave]
            porSitio[clave] = Sitio(nombre: previo?.nombre ?? g.name,
                                    veces: (previo?.veces ?? 0) + 1,
                                    total: (previo?.total ?? 0) + g.amount)
        }
        let sitios = porSitio.values.filter { $0.veces >= 2 }.sorted { $0.total > $1.total }.prefix(3)
        if !sitios.isEmpty { disponibles["sitios"] = .sitios(Array(sitios)) }

        // Gastos hormiga: pequeños y muchos. El umbral es el del usuario si se
        // conoce su costumbre; si no, 5 €.
        let umbralHormiga = normal?.umbralHormiga ?? 5
        let hormigas = analisis.filter { $0.amount <= umbralHormiga && !$0.esRecurrente }
        if hormigas.count >= 5 {
            disponibles["hormiga"] = .hormiga(Hormiga(umbral: umbralHormiga, cantidad: hormigas.count,
                                                      total: hormigas.reduce(0) { $0 + $1.amount }))
        }

        if let presupuesto, presupuesto > 0 {
            let previsto = presupuesto - ritmo.prevision
            disponibles["ahorro"] = .ahorro(Ahorro(previsto: previsto, porcentaje: previsto / presupuesto,
                                                   medio: normal?.ahorroMedio))
        }

        // Racha: días seguidos con algo apuntado, contando hacia atrás desde
        // hoy; si hoy aún no hay nada, desde ayer. Solo en el mes en curso.
        var diasConGasto = Set(gastos.map { String($0.date.prefix(10)) })
        if let normal { diasConGasto.formUnion(normal.diasConGasto) }
        if diasRestantes > 0 {
            let racha = Self.racha(dias: diasConGasto, hoy: hoy, calendar: calendar)
            if racha.dias >= 3 { disponibles["racha"] = .racha(racha) }
        }

        // Lo medido contra tu normal.
        if let normal {
            // Una categoría lejos de lo habitual, a estas alturas del mes. Sin
            // recurrentes a ambos lados, y no antes del día 5: con dos días no
            // hay ritmo que comparar.
            if normal.meses >= 3, diaActual >= 5 || diasRestantes == 0 {
                let fraccion = Double(diaActual) / Double(diasMes)
                let variablePorCategoria = Dictionary(grouping: gastos.filter { !$0.esRecurrente }, by: \.category)
                    .mapValues { $0.reduce(0) { $0 + $1.amount } }
                let desvios = normal.porCategoria.compactMap { (cat, mediana) -> Desvio? in
                    // Solo categorías habituales: un taller suelto no es "tu normal".
                    // Y solo por encima: gastar menos que de costumbre no pide
                    // nada y suele tener una explicación obvia (#68).
                    guard normal.mesesPorCategoria[cat, default: 0] >= 3,
                          mediana >= normal.totalMensual * 0.05, mediana > 0,
                          let actual = variablePorCategoria[cat], actual > 0 else { return nil }
                    let esperado = mediana * fraccion
                    guard esperado >= 15 else { return nil }
                    let pct = (actual - esperado) / esperado
                    guard pct >= 0.3 else { return nil }
                    return Desvio(categoria: cat, actual: actual, esperado: esperado,
                                  normalMensual: mediana, porcentaje: Int((pct * 100).rounded()))
                }
                if let d = desvios.max(by: { abs($0.porcentaje) < abs($1.porcentaje) }) {
                    disponibles["fueraDeNormal"] = .fueraDeNormal(d)
                }
            }

            if let (dia, mediaDia) = normal.porDiaSemana.max(by: { $0.value < $1.value }), mediaDia > 0 {
                let resto = normal.porDiaSemana.filter { $0.key != dia }.values
                let mediaResto = resto.isEmpty ? 0 : resto.reduce(0, +) / Double(resto.count)
                if mediaResto > 0, mediaDia >= mediaResto * 1.3 {
                    let esHoy = diasRestantes > 0 && calendar.component(.weekday, from: hoy) == dia
                    disponibles["diaSemana"] = .diaSemana(DiaSemana(dia: dia, media: mediaDia, mediaResto: mediaResto, esHoy: esHoy))
                }
            }

            if normal.totalesPorMes.count >= 3 {
                let referencia = diasRestantes == 0 ? total : ritmo.prevision
                let otros = normal.totalesPorMes.values.sorted()
                disponibles["ranking"] = .ranking(Ranking(
                    posicion: otros.filter { $0 < referencia }.count + 1,
                    de: otros.count + 1,
                    referencia: referencia,
                    minimo: otros.first ?? 0,
                    maximo: otros.last ?? 0,
                    proyectado: diasRestantes > 0
                ))
            }

            // La categoría grande sin tope que más pesa: lo que se suele
            // gastar en ella, para ponerle uno desde Metas.
            if normal.meses >= 3,
               let (cat, mediana) = normal.porCategoria
                .filter({ !categoriasConTope.contains($0.key) && $0.value >= normal.totalMensual * 0.1
                          && normal.mesesPorCategoria[$0.key, default: 0] >= 3 })
                .max(by: { $0.value < $1.value }) {
                disponibles["limiteSugerido"] = .limiteSugerido(LimiteSugerido(
                    categoria: cat, normalMensual: mediana, actual: porCategoria[cat] ?? 0))
            }
        }

        // Cuánto importa cada cosa, y el reparto: cada hueco toma lo más
        // relevante de lo que le cabe y no se ha usado ya en otro hueco.
        let contexto = Contexto(totalAnalisis: totalAnalisis, subidaRelativa: subidaRelativa,
                                diaActual: diaActual, diasConGasto: porDia.count)
        // Lo que el usuario ocultó no sale, puntúe lo que puntúe.
        for clase in preferencias.ocultas { disponibles[clase] = nil }
        let relevancias = disponibles.mapValues { Self.relevancia($0, contexto) }
        var usados = Set<String>()
        var slots: [Slot: Contenido] = [:]
        for slot in Slot.allCases {
            let opciones = slot.candidatos.enumerated().compactMap { orden, clase -> (orden: Int, clase: String, valor: Double)? in
                guard !usados.contains(clase), let valor = relevancias[clase] else { return nil }
                // Lo que el usuario ordenó va por delante de la relevancia automática.
                return (orden, clase, valor + preferencias.bonus(clase))
            }
            guard let mejor = opciones.max(by: { a, b in
                a.valor < b.valor || (a.valor == b.valor && a.orden > b.orden)
            }) else { continue }
            slots[slot] = disponibles[mejor.clase]
            usados.insert(mejor.clase)
        }

        return HomeResumen(
            total: total,
            numeroGastos: gastos.count,
            presupuesto: presupuesto,
            ritmo: ritmo,
            comparativa: comparativa,
            diasApuntando: diasApuntando,
            slots: slots,
            diaMasCaro: diaMasCaro,
            relevancias: relevancias,
            totalAnalisis: totalAnalisis,
            numeroAnalisis: analisis.count,
            mediaDiariaAnalisis: diaActual > 0 ? totalAnalisis / Double(diaActual) : 0,
            comparativaAnalisis: comparativaAnalisis
        )
    }

    // MARK: - Relevancia

    /// Lo que hace falta del mes para puntuar un contenido.
    struct Contexto: Sendable {
        let totalAnalisis: Double
        /// La mayor subida por categoría frente al mes anterior, como parte de
        /// aquel total: 0,3 = un 30 % más.
        let subidaRelativa: Double
        let diaActual: Int
        /// Días distintos con gasto este mes.
        let diasConGasto: Int
    }

    /// De 0 a 1: cuánto le importa esto a este usuario ahora mismo. Lo que
    /// pide una decisión —un tope a punto, dinero que te deben, pasarse del
    /// presupuesto— pesa más que lo que solo describe.
    static func relevancia(_ contenido: Contenido, _ c: Contexto) -> Double {
        func acotado(_ x: Double) -> Double { min(max(x, 0), 1) }
        func parte(_ importe: Double) -> Double { c.totalAnalisis > 0 ? importe / c.totalAnalisis : 0 }
        switch contenido {
        case .limites(let l):
            if l.contains(where: \.superado) { return 1 }
            return 0.35 + 0.6 * (l.map(\.progreso).max() ?? 0)
        case .reparto:
            return 0.3
        case .cargos(let cargos, _):
            // Con un cargo encima, sube: es lo que va a pasar esta semana.
            let faltan = cargos.first.map { $0.dia - c.diaActual } ?? 99
            return faltan <= 3 ? 0.7 : 0.5
        case .teDeben:
            return 0.8
        case .hucha(let h):
            return 0.3 + 0.4 * h.progreso
        case .diaCaro(let d):
            // Con uno o dos días de gasto, el "más caro" no dice nada.
            guard c.diasConGasto >= 3 else { return 0.15 }
            return 0.15 + 0.6 * acotado(parte(d.importe))
        case .semana(let s):
            return 0.25 + 0.4 * acotado(Double(abs(s.porcentaje)) / 100)
        case .subeFuerte:
            return 0.3 + 0.5 * acotado(c.subidaRelativa)
        case .comparativa(let comp):
            return 0.2 + 0.5 * acotado(Double(abs(comp.porcentaje)) / 50)
        case .semanaASemana:
            return 0.25
        case .fueraDeNormal(let d):
            return 0.45 + 0.5 * acotado(Double(abs(d.porcentaje)) / 100)
        case .sitios(let s):
            return 0.35 + min(0.05 * Double(s.first?.veces ?? 0), 0.3)
        case .diaSemana(let d):
            return d.esHoy ? 0.75 : 0.3
        case .hormiga(let h):
            // Un cuarto del mes en gastos pequeños es el máximo que se puntúa.
            return 0.2 + 0.6 * acotado(parte(h.total) / 0.25)
        case .ahorro(let a):
            if a.previsto < 0 { return 0.8 }
            if let medio = a.medio, abs(a.porcentaje - medio) >= 0.05 { return 0.6 }
            return 0.45
        case .ranking(let r):
            return r.posicion == 1 || r.posicion == r.de ? 0.6 : 0.3
        case .racha(let r):
            return 0.2 + min(Double(r.dias) / 30, 0.45) + (r.dias >= 7 && r.dias >= r.record ? 0.15 : 0)
        case .limiteSugerido:
            return 0.4
        }
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

    /// Días seguidos con gasto hasta hoy (o hasta ayer si hoy no hay nada), y
    /// el récord de todo lo que se conoce.
    static func racha(dias: Set<String>, hoy: Date, calendar: Calendar) -> Racha {
        // Claves con el calendario que llega, no con el del dispositivo: así
        // el cálculo es el mismo en los tests con otro calendario.
        func clave(_ d: Date) -> String {
            let c = calendar.dateComponents([.year, .month, .day], from: d)
            return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
        func fecha(_ clave: String) -> Date? {
            let p = clave.split(separator: "-").compactMap { Int($0) }
            guard p.count == 3 else { return nil }
            return calendar.date(from: DateComponents(year: p[0], month: p[1], day: p[2]))
        }
        var cursor = calendar.startOfDay(for: hoy)
        if !dias.contains(clave(cursor)), let ayer = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = ayer
        }
        var actual = 0
        while dias.contains(clave(cursor)), let anterior = calendar.date(byAdding: .day, value: -1, to: cursor) {
            actual += 1
            cursor = anterior
        }

        // El récord: la tira más larga de días consecutivos.
        let fechas = dias.compactMap { fecha($0) }.sorted()
        var record = 0, tira = 0
        var previa: Date?
        for fecha in fechas {
            if let previa, let siguiente = calendar.date(byAdding: .day, value: 1, to: previa),
               calendar.isDate(siguiente, inSameDayAs: fecha) {
                tira += 1
            } else {
                tira = 1
            }
            record = max(record, tira)
            previa = fecha
        }
        return Racha(dias: actual, record: max(record, actual))
    }

    /// El nombre de un gasto como clave de comercio: sin mayúsculas, acentos
    /// ni espacios de más, para que "Mercadona" y "mercadona " sean el mismo.
    static func normalizar(_ nombre: String) -> String {
        nombre.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
