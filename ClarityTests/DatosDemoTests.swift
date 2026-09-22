// DatosDemoTests.swift
// Los datos inventados del modo demo (capturas de la App Store): que valgan en
// cualquier fecha y que la Home salga sana con ellos.
//
// Solo la generación, que es pura: no arranca el modo demo ni toca Firestore,
// Auth, la red ni la caché de la app.

import Testing
import Foundation
@testable import Clarity

@MainActor
struct DatosDemoTests {

    private let cal = Calendar.current

    private func fecha(_ anio: Int, _ mes: Int, _ dia: Int) -> Date {
        cal.date(from: DateComponents(year: anio, month: mes, day: dia, hour: 12))!
    }

    /// Principio, mitad y final de mes, meses cortos, cambio de año.
    private var fechas: [Date] {
        [fecha(2026, 9, 22), fecha(2026, 1, 1), fecha(2026, 2, 28), fecha(2026, 3, 31),
         fecha(2026, 12, 15), fecha(2027, 6, 3)]
    }

    private func clave(_ d: Date) -> String { String(Formatters.localDayString(from: d).prefix(7)) }

    private func gastosDelMes(_ datos: DatosDemo, hoy: Date) -> [Expense] {
        datos.gastos.filter { $0.date.hasPrefix(clave(hoy)) }
    }

    private func presupuestoDelMes(_ datos: DatosDemo, hoy: Date) -> MonthlyBudget? {
        datos.presupuestos.first {
            $0.year == cal.component(.year, from: hoy) && $0.month == cal.component(.month, from: hoy)
        }
    }

    @Test("Hay gastos del mes en curso, unos 40–60 a día 22")
    func hayGastosDelMes() {
        for hoy in fechas {
            #expect(!gastosDelMes(DatosDemo.generar(hoy: hoy, calendar: cal), hoy: hoy).isEmpty)
        }
        let dia22 = fecha(2026, 9, 22)
        let cuantos = gastosDelMes(DatosDemo.generar(hoy: dia22, calendar: cal), hoy: dia22).count
        #expect((40...60).contains(cuantos))
    }

    @Test("Ninguna fecha es futura")
    func sinFechasFuturas() {
        for hoy in fechas {
            let limite = Formatters.localDayString(from: hoy)
            let datos = DatosDemo.generar(hoy: hoy, calendar: cal)
            #expect(datos.gastos.allSatisfy { $0.date <= limite })
            #expect(datos.gastos.allSatisfy { Formatters.date(from: $0.date) != nil })
        }
    }

    @Test("El mes queda por debajo del presupuesto, también la previsión: ahorro positivo")
    func bajoElPresupuesto() throws {
        for hoy in fechas {
            let datos = DatosDemo.generar(hoy: hoy, calendar: cal)
            let presupuesto = try #require(presupuestoDelMes(datos, hoy: hoy)).totalIncome
            #expect(presupuesto == 2000)

            let gastos = gastosDelMes(datos, hoy: hoy)
            let total = gastos.reduce(0) { $0 + $1.amount }
            #expect(total < presupuesto)

            let resumen = HomeResumen.build(
                gastos: gastos, gastosMesAnterior: [], metas: datos.metas, recurrentes: datos.recurrentes,
                presupuesto: presupuesto, primerGasto: nil, hoy: hoy, calendar: cal)
            #expect(resumen.ritmo.prevision < presupuesto)
        }
    }

    @Test("Hay al menos cinco meses anteriores con gastos y con presupuesto")
    func mesesAnteriores() {
        let hoy = fecha(2026, 9, 22)
        let datos = DatosDemo.generar(hoy: hoy, calendar: cal)
        let meses = Set(datos.gastos.map { String($0.date.prefix(7)) }).subtracting([clave(hoy)])
        #expect(meses.count >= 5)
        #expect(datos.presupuestos.count >= 6)
    }

    @Test("El límite de Ocio no se supera en ningún mes")
    func limiteDeOcio() throws {
        let datos = DatosDemo.generar(hoy: fecha(2026, 9, 22), calendar: cal)
        let tope = try #require(datos.metas.first { $0.type == .spendingLimit })
        let categoria = try #require(tope.linkedCategoryId)
        let porMes = Dictionary(grouping: datos.gastos.filter { $0.category == categoria }) { String($0.date.prefix(7)) }
        #expect(!porMes.isEmpty)
        for (_, gastos) in porMes {
            #expect(gastos.reduce(0) { $0 + $1.amount } < tope.targetAmount)
        }
    }

    @Test("Ids únicos: la lista de la Home los usa de clave")
    func idsUnicos() {
        for hoy in fechas {
            let ids = DatosDemo.generar(hoy: hoy, calendar: cal).gastos.compactMap(\.id)
            #expect(Set(ids).count == ids.count)
        }
    }

    @Test("En el mes en curso, los cargos recurrentes de hoy en adelante aún no están cobrados")
    func recurrentesPendientes() {
        let hoy = fecha(2026, 9, 22)
        let datos = DatosDemo.generar(hoy: hoy, calendar: cal)
        let delMes = gastosDelMes(datos, hoy: hoy)
        let pendientes = datos.recurrentes.filter { $0.dayOfMonth >= 22 }
        #expect(!pendientes.isEmpty)
        for regla in pendientes {
            #expect(!delMes.contains { $0.recurringId == regla.id })
        }
    }

    @Test("Mismo día, mismos datos")
    func determinista() {
        let hoy = fecha(2026, 9, 22)
        #expect(DatosDemo.generar(hoy: hoy, calendar: cal).gastos == DatosDemo.generar(hoy: hoy, calendar: cal).gastos)
    }
}
