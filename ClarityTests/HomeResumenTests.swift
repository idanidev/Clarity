// HomeResumenTests.swift
// La resolución de huecos de la Home: ninguno se queda vacío y gana lo que
// más le importa al usuario (#65).

import Testing
import Foundation
@testable import Clarity

@MainActor
struct HomeResumenTests {

    private let cal = Calendar.current
    /// 10 de abril de 2026, viernes.
    private var hoy: Date { cal.date(from: DateComponents(year: 2026, month: 4, day: 10))! }

    /// Nombre único por defecto: dos gastos con el mismo nombre serían un
    /// "sitio" repetido y colarían esa tarjeta donde no se espera.
    private func gasto(_ amount: Double, _ cat: String, dia: Int, mes: Int = 4, name: String = UUID().uuidString,
                       recurrente: Bool = false, debtors: [Debtor]? = nil) -> Expense {
        Expense(id: UUID().uuidString, amount: amount, name: name, category: cat,
                date: String(format: "2026-%02d-%02d", mes, dia), recurringId: recurrente ? "regla" : nil,
                isShared: debtors != nil, debtors: debtors)
    }

    private func regla(_ n: String, _ amount: Double = 10, dia: Int) -> RecurringExpense {
        RecurringExpense(id: n, amount: amount, name: n, category: "Ocio", subcategory: nil, paymentMethod: "Tarjeta",
                         frequency: .monthly, dayOfMonth: dia, billingMonth: 0, active: true, icon: nil,
                         startDate: nil, endDate: nil, lastCreated: nil, createdAt: nil, updatedAt: nil)
    }

    private func resumen(_ gastos: [Expense], anterior: [Expense] = [], metas: [Goal] = [],
                         recurrentes: [RecurringExpense] = [], presupuesto: Double? = nil,
                         normal: HomeNormal? = nil, filtro: ((Expense) -> Bool)? = nil) -> HomeResumen {
        HomeResumen.build(gastos: gastos, gastosMesAnterior: anterior, metas: metas, recurrentes: recurrentes,
                          presupuesto: presupuesto, primerGasto: nil, hoy: hoy, calendar: cal,
                          normal: normal, filtro: filtro)
    }

    private func contenido(_ clase: String, en r: HomeResumen) -> HomeResumen.Contenido? {
        r.slots.values.first { $0.clase == clase }
    }

    // MARK: - Ritmo

    @Test("Ritmo: media diaria y previsión salen del día del mes")
    func ritmo() {
        let r = resumen([gasto(100, "Ocio", dia: 2), gasto(150, "Ocio", dia: 9)])
        #expect(r.total == 250)
        #expect(abs(r.ritmo.mediaDiaria - 25) < 0.001)
        #expect(abs(r.ritmo.prevision - 750) < 0.001)
        #expect(r.ritmo.diasRestantes == 20)
    }

    @Test("La previsión suma los cargos pendientes tal cual y no repite los ya cobrados")
    func previsionConRecurrentes() {
        // 600 € de alquiler el día 1 (recurrente) y 100 € variables en 10 días.
        let gastos = [gasto(600, "Vivienda", dia: 1, recurrente: true), gasto(100, "Ocio", dia: 5)]
        let r = resumen(gastos, recurrentes: [regla("alquiler", 600, dia: 1), regla("netflix", 12.99, dia: 20)])
        // 700 que hay + 10 €/día variables × 20 días + Netflix, que aún no ha pasado.
        #expect(abs(r.ritmo.prevision - 912.99) < 0.001)
        #expect(abs(r.ritmo.cargosPendientes - 12.99) < 0.001)
    }

    // MARK: - Huecos

    @Test("Sin nada configurado, los cuatro huecos siguen llenos")
    func huecosNuncaVacios() {
        let gastos = [
            gasto(20, "Alimentación", dia: 1), gasto(30, "Ocio", dia: 2),
            gasto(46, "Ocio", dia: 4, name: "Cena"), gasto(12, "Transporte", dia: 8), gasto(9, "Alimentación", dia: 9),
        ]
        let r = resumen(gastos)
        #expect(r.slots[HomeResumen.Slot.a]?.clase == "reparto")
        #expect(r.slots[HomeResumen.Slot.b]?.clase == "diaCaro")
        #expect(r.slots[HomeResumen.Slot.c]?.clase == "semana")
        #expect(r.slots[HomeResumen.Slot.e]?.clase == "semanaASemana")
        if case .diaCaro(let d) = r.slots[HomeResumen.Slot.b]! { #expect(d.importe == 46); #expect(d.concepto == "Cena") }
    }

    @Test("Con todo configurado, cada hueco enseña lo más relevante de lo que le cabe")
    func huecosCompletos() {
        let metas = [
            Goal(name: "Ocio", type: .spendingLimit, targetAmount: 300, linkedCategoryId: "Ocio"),
            Goal(name: "Moto", type: .savingsTarget, targetAmount: 5000, currentAmount: 200),
        ]
        let gastos = [gasto(209.54, "Ocio", dia: 3, debtors: [Debtor(name: "Marcos", amount: 40)])]
        let r = resumen(gastos, anterior: [gasto(260, "Ocio", dia: 5, mes: 3)], metas: metas,
                        recurrentes: [regla("Netflix", 12.99, dia: 15)], presupuesto: 2080)
        #expect(r.slots[HomeResumen.Slot.a]?.clase == "limites")
        #expect(r.slots[HomeResumen.Slot.b]?.clase == "cargos")
        #expect(r.slots[HomeResumen.Slot.c]?.clase == "teDeben")
        // Un −19 % frente al mes pasado dice más que una hucha al 4 %.
        #expect(r.slots[HomeResumen.Slot.e]?.clase == "comparativa")
        #expect(abs((r.libres ?? 0) - 1870.46) < 0.01)
        if case .limites(let l) = r.slots[HomeResumen.Slot.a]! { #expect(l[0].restante > 90 && l[0].restante < 91) }
        if case .teDeben(_, let total) = r.slots[HomeResumen.Slot.c]! { #expect(total == 40) }
    }

    @Test("Un mismo contenido no sale en dos huecos")
    func sinDuplicados() {
        let metas = [Goal(name: "Moto", type: .savingsTarget, targetAmount: 5000, currentAmount: 200)]
        let r = resumen([gasto(10, "Ocio", dia: 1)], metas: metas)
        let clases = r.slots.values.map(\.clase)
        #expect(Set(clases).count == clases.count)
        #expect(clases.contains("hucha"))
    }

    @Test("Una hucha a 0 € no ocupa hueco: entra lo siguiente")
    func huchaVaciaNoCuenta() {
        let metas = [Goal(name: "Moto", type: .savingsTarget, targetAmount: 3000, currentAmount: 0)]
        let r = resumen([gasto(10, "Ocio", dia: 1), gasto(20, "Ocio", dia: 8)], metas: metas)
        #expect(!r.slots.values.map(\.clase).contains("hucha"))
        #expect(r.slots[HomeResumen.Slot.e] != nil)
    }

    @Test("Un límite superado es lo más relevante que hay")
    func limiteSuperado() {
        let metas = [Goal(name: "Coche-Moto", type: .spendingLimit, targetAmount: 400, linkedCategoryId: "Coche-Moto")]
        let r = resumen([gasto(501, "Coche-Moto", dia: 10)], metas: metas)
        guard case .limites(let l) = r.slots[HomeResumen.Slot.a]! else { Issue.record("sin límites"); return }
        #expect(l[0].superado)
        #expect(l[0].progreso == 1)
        #expect(abs(l[0].restante + 101) < 0.001)
        #expect(r.relevancias["limites"] == 1)
    }

    @Test("Los cargos pasados de este mes no cuentan como próximos, y uno encima pesa más")
    func cargosSoloFuturos() {
        let r = resumen([gasto(1, "Ocio", dia: 1)],
                        recurrentes: [regla("pasado", dia: 3), regla("hoy", dia: 10), regla("luego", dia: 20)])
        guard case .cargos(let c, let total) = r.slots[HomeResumen.Slot.b]! else { Issue.record("sin cargos"); return }
        #expect(c.map(\.nombre) == ["hoy", "luego"])
        #expect(total == 20)
        #expect(r.relevancias["cargos"] == 0.7)
    }

    // MARK: - Comparativas

    @Test("Esta semana se compara con la anterior hasta el mismo día")
    func semanaMismoTramo() {
        // hoy = viernes 10 de abril de 2026. Semana actual lun 6 – vie 10.
        // Anterior hasta el mismo día: lun 30 mar – vie 3 abr. El sáb 4 no cuenta.
        let gastos = [
            gasto(50, "Ocio", dia: 7),               // esta semana
            gasto(40, "Ocio", dia: 1),               // semana anterior, antes del viernes
            gasto(500, "Ocio", dia: 4),              // sábado de la semana anterior: fuera
        ]
        var c = Calendar(identifier: .gregorian); c.firstWeekday = 2; c.timeZone = cal.timeZone
        let r = HomeResumen.build(gastos: gastos, gastosMesAnterior: [], metas: [], recurrentes: [],
                                  presupuesto: nil, primerGasto: nil, hoy: hoy, calendar: c)
        let semana = r.slots.values.compactMap { if case .semana(let s) = $0 { s } else { nil } }.first
        #expect(semana?.anterior == 40)
        #expect(semana?.actual == 50)
    }

    @Test("Disponible por día: lo libre repartido entre los días que quedan, hoy incluido")
    func disponiblePorDia() {
        let r = resumen([gasto(759.68, "Ocio", dia: 2)], presupuesto: 2080)
        // Abril: 30 días, hoy 10 → quedan 20 más hoy = 21.
        #expect(abs((r.disponiblePorDia ?? 0) - 1320.32 / 21) < 0.01)
        #expect(resumen([gasto(10, "Ocio", dia: 2)]).disponiblePorDia == nil)
    }

    @Test("Comparativa: menos que el mes anterior sale en negativo")
    func comparativa() {
        let r = resumen([gasto(759.68, "Ocio", dia: 1)], anterior: [gasto(863, "Ocio", dia: 1, mes: 3)])
        #expect(r.comparativa?.porcentaje == -12)
        #expect(r.comparativa?.parcial == true)
        #expect(r.comparativa?.hastaDia == 10)
    }

    @Test("A mediados de mes solo se compara con el mismo tramo del anterior")
    func comparativaMismoTramo() {
        // Marzo: 100 € el día 5 (cuenta) y 900 € el día 25 (no cuenta: hoy es 10).
        let r = resumen([gasto(120, "Ocio", dia: 3)],
                        anterior: [gasto(100, "Ocio", dia: 5, mes: 3), gasto(900, "Ocio", dia: 25, mes: 3)])
        #expect(r.comparativa?.totalAnterior == 100)
        #expect(r.comparativa?.porcentaje == 20)
    }

    @Test("Con filtro, lo que habla de en qué se gasta mira lo filtrado; total y límites, el mes entero")
    func filtroSoloEnElAnalisis() {
        let metas = [Goal(name: "Ocio", type: .spendingLimit, targetAmount: 300, linkedCategoryId: "Ocio")]
        let gastos = [
            gasto(100, "Ocio", dia: 2),
            gasto(40, "Compras", dia: 3, name: "Zapatillas"),
            gasto(10, "Compras", dia: 9),
        ]
        let r = resumen(gastos, metas: metas, presupuesto: 1000, filtro: { $0.category == "Compras" })
        #expect(r.total == 150)
        #expect(r.totalAnalisis == 50)
        #expect(r.numeroAnalisis == 2)
        // El límite de Ocio cuenta lo gastado en Ocio aunque el filtro lo deje fuera.
        guard case .limites(let limites) = r.slots[HomeResumen.Slot.a]! else { Issue.record("sin límites"); return }
        #expect(limites.first?.gastado == 100)
        // El día más caro sale de lo filtrado: los 40 € de Zapatillas, no los 100 de Ocio.
        #expect(r.diaMasCaro?.importe == 40)
        #expect(r.diaMasCaro?.concepto == "Zapatillas")
    }

    // MARK: - Lo que sale de tu normal

    /// Tres meses con 100 € en Restaurantes y 300 € en Súper cada uno.
    private var normalDeTresMeses: HomeNormal {
        var historico: [Expense] = []
        for mes in 1...3 {
            historico.append(gasto(100, "Restaurantes", dia: 6, mes: mes))
            historico.append(gasto(300, "Súper", dia: 7, mes: mes))
        }
        return HomeNormal.build(historico: historico, mes: hoy, calendar: cal)!
    }

    @Test("Fuera de lo normal: la categoría que más se desvía de tu mediana, a estas alturas del mes")
    func fueraDeNormal() {
        // A día 10 de 30, lo normal en Restaurantes son 33 €; llevas 90.
        // En Súper lo normal son 100 y llevas 100: no se desvía.
        let r = resumen([gasto(90, "Restaurantes", dia: 8), gasto(100, "Súper", dia: 9)], normal: normalDeTresMeses)
        guard case .fueraDeNormal(let d)? = contenido("fueraDeNormal", en: r) else { Issue.record("sin desvío"); return }
        #expect(d.categoria == "Restaurantes")
        #expect(d.porcentaje == 170)
        #expect(abs(d.esperado - 100.0 / 3) < 0.01)
        #expect(d.normalMensual == 100)
    }

    @Test("Fuera de lo normal no sale antes del día 5 ni con menos de tres meses")
    func fueraDeNormalPrudente() {
        let dia3 = cal.date(from: DateComponents(year: 2026, month: 4, day: 3))!
        let r = HomeResumen.build(gastos: [gasto(90, "Restaurantes", dia: 2)], gastosMesAnterior: [], metas: [],
                                  recurrentes: [], presupuesto: nil, primerGasto: nil, hoy: dia3, calendar: cal,
                                  normal: normalDeTresMeses)
        #expect(r.relevancias["fueraDeNormal"] == nil)
        let dosMeses = HomeNormal.build(historico: [gasto(100, "Restaurantes", dia: 6, mes: 2), gasto(100, "Restaurantes", dia: 6, mes: 3)],
                                        mes: hoy, calendar: cal)
        #expect(resumen([gasto(90, "Restaurantes", dia: 8)], normal: dosMeses).relevancias["fueraDeNormal"] == nil)
    }

    @Test("Tus sitios: comercios repetidos este mes, sin recurrentes, y el nombre normalizado")
    func sitios() {
        let gastos = [
            gasto(20, "Súper", dia: 2, name: "Mercadona"), gasto(25, "Súper", dia: 5, name: "mercadona "),
            gasto(30, "Súper", dia: 9, name: "MERCADONA"),
            gasto(12.99, "Ocio", dia: 3, name: "Netflix", recurrente: true), gasto(12.99, "Ocio", dia: 4, name: "Netflix", recurrente: true),
            gasto(15, "Ocio", dia: 6, name: "Bar Pepe"),
        ]
        let r = resumen(gastos)
        guard case .sitios(let sitios)? = contenido("sitios", en: r) else { Issue.record("sin sitios"); return }
        #expect(sitios.count == 1)
        #expect(sitios[0].nombre == "Mercadona")
        #expect(sitios[0].veces == 3)
        #expect(sitios[0].total == 75)
        #expect(sitios[0].media == 25)
    }

    @Test("Gastos hormiga: cinco o más por debajo del umbral")
    func hormiga() {
        // Solo hormigas: son todo el gasto del mes y pesan más que nada.
        let seis = (1...6).map { gasto(2, "Ocio", dia: $0) }
        let r = resumen(seis)
        #expect(r.relevancias["hormiga"] == 0.8)
        guard case .hormiga(let h)? = contenido("hormiga", en: r) else { Issue.record("sin hormigas"); return }
        #expect(h.cantidad == 6)
        #expect(h.total == 12)
        #expect(h.umbral == 5)
        #expect(resumen(Array(seis.prefix(4))).relevancias["hormiga"] == nil)
    }

    @Test("Racha: días seguidos hasta hoy o hasta ayer, y el récord de todo lo conocido")
    func racha() {
        let dias: Set<String> = ["2026-04-07", "2026-04-08", "2026-04-09",
                                 "2026-03-01", "2026-03-02", "2026-03-03", "2026-03-04"]
        let r = HomeResumen.racha(dias: dias, hoy: hoy, calendar: cal)
        #expect(r.dias == 3)
        #expect(r.record == 4)
        let conHoy = HomeResumen.racha(dias: dias.union(["2026-04-10"]), hoy: hoy, calendar: cal)
        #expect(conHoy.dias == 4)
        #expect(conHoy.record == 4)
        #expect(HomeResumen.racha(dias: ["2026-04-01"], hoy: hoy, calendar: cal).dias == 0)
    }

    @Test("Ranking: dónde cae la previsión del mes entre los anteriores")
    func ranking() {
        let historico = [gasto(500, "Ocio", dia: 3, mes: 1), gasto(700, "Ocio", dia: 3, mes: 2), gasto(900, "Ocio", dia: 3, mes: 3)]
        let normal = HomeNormal.build(historico: historico, mes: hoy, calendar: cal)
        // 200 € en 10 días → previsión 600: segundo más barato de cuatro.
        let r = resumen([gasto(200, "Ocio", dia: 5)], normal: normal)
        #expect(r.relevancias["ranking"] != nil)
        guard case .ranking(let k)? = contenido("ranking", en: r) else { Issue.record("sin ranking"); return }
        #expect(k.posicion == 2)
        #expect(k.de == 4)
        #expect(k.proyectado)
        #expect(k.minimo == 500 && k.maximo == 900)
    }

    @Test("Ahorro previsto: con presupuesto, y por delante de todo si el mes se pasa")
    func ahorroPrevisto() {
        // 900 € en 10 días con 1000 de presupuesto: previsión 2700, te pasas.
        let r = resumen([gasto(900, "Ocio", dia: 5)], presupuesto: 1000)
        #expect(r.relevancias["ahorro"] == 0.8)
        guard case .ahorro(let a)? = contenido("ahorro", en: r) else { Issue.record("sin ahorro"); return }
        #expect(abs(a.previsto + 1700) < 0.001)
        #expect(resumen([gasto(10, "Ocio", dia: 5)]).relevancias["ahorro"] == nil)
    }

    @Test("Límite sugerido: la categoría grande sin tope, con lo que se suele gastar")
    func limiteSugerido() {
        let metas = [Goal(name: "Súper", type: .spendingLimit, targetAmount: 350, linkedCategoryId: "Súper")]
        let r = resumen([gasto(40, "Restaurantes", dia: 8)], metas: metas, normal: normalDeTresMeses)
        guard case .limiteSugerido(let s)? = contenido("limiteSugerido", en: r) else { Issue.record("sin sugerencia"); return }
        #expect(s.categoria == "Restaurantes")
        #expect(s.normalMensual == 100)
        #expect(s.actual == 40)
    }

    @Test("Tu día caro sale del historial y avisa cuando es hoy")
    func diaSemana() {
        // Todo el historial cae en viernes; hoy, 10 de abril de 2026, es viernes.
        let viernes = [(1, 2), (1, 9), (1, 16), (2, 6), (2, 13), (3, 6), (3, 13)]
        let historico = viernes.map { gasto(50, "Ocio", dia: $0.1, mes: $0.0) } + [gasto(5, "Ocio", dia: 5, mes: 1)]
        let normal = HomeNormal.build(historico: historico, mes: hoy, calendar: cal)
        let r = resumen([gasto(10, "Ocio", dia: 3)], normal: normal)
        #expect(r.relevancias["diaSemana"] == 0.75)
        guard case .diaSemana(let d)? = contenido("diaSemana", en: r) else { Issue.record("sin día"); return }
        #expect(d.dia == 6)
        #expect(d.esHoy)
    }
}
