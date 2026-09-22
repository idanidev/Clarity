// ResumenSemanalTests.swift
// La cuenta del resumen semanal (#57): qué semana se cuenta según el día
// elegido, la comparación con la anterior, los redondeos y el singular.

import Foundation
import Testing
@testable import Clarity

@Suite("ResumenSemanal")
@MainActor
struct ResumenSemanalTests {

    /// Madrid, para que el cambio de hora (25 de octubre de 2026) entre en juego.
    private var madrid: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return c
    }

    /// 22 de septiembre de 2026 es martes; el 27, domingo.
    private func fecha(_ dia: Int, mes: Int = 9, _ hora: Int, _ minuto: Int = 0) -> Date {
        madrid.date(from: DateComponents(year: 2026, month: mes, day: dia, hour: hora, minute: minuto))!
    }

    private func gasto(_ importe: Double, _ dia: String, recurrente: Bool = false) -> Expense {
        Expense(amount: importe, name: "x", category: "Ocio", date: dia, isRecurring: recurrente ? true : nil)
    }

    // MARK: - Cuándo sale

    @Test("entre semana, el próximo aviso es el del día elegido")
    func proximoEntreSemana() {
        let avisos = ResumenSemanal.proximosAvisos(despuesDe: fecha(22, 12), diaSemana: 1, hora: 20, minuto: 0,
                                                   calendar: madrid)
        #expect(avisos.first == fecha(27, 20))
    }

    @Test("el mismo día, antes de la hora, sale ese día")
    func mismoDiaAntes() {
        let avisos = ResumenSemanal.proximosAvisos(despuesDe: fecha(27, 10), diaSemana: 1, hora: 20, minuto: 0,
                                                   calendar: madrid)
        #expect(avisos.first == fecha(27, 20))
    }

    @Test("el mismo día, pasada la hora, pasa a la semana siguiente")
    func mismoDiaDespues() {
        let avisos = ResumenSemanal.proximosAvisos(despuesDe: fecha(27, 21), diaSemana: 1, hora: 20, minuto: 0,
                                                   calendar: madrid)
        #expect(avisos.first == fecha(4, mes: 10, 20))
    }

    @Test("se programan cuatro semanas seguidas")
    func cuatroSemanas() {
        let avisos = ResumenSemanal.proximosAvisos(despuesDe: fecha(22, 12), diaSemana: 1, hora: 20, minuto: 30,
                                                   calendar: madrid)
        #expect(avisos == [fecha(27, 20, 30), fecha(4, mes: 10, 20, 30),
                           fecha(11, mes: 10, 20, 30), fecha(18, mes: 10, 20, 30)])
    }

    @Test("el cambio de hora no mueve la hora del aviso")
    func cambioDeHora() {
        let avisos = ResumenSemanal.proximosAvisos(despuesDe: fecha(12, mes: 10, 12), diaSemana: 1, hora: 20,
                                                   minuto: 0, cuantos: 3, calendar: madrid)
        #expect(avisos.map { madrid.component(.hour, from: $0) } == [20, 20, 20])
        #expect(avisos.last == fecha(1, mes: 11, 20))
    }

    // MARK: - Qué semana se cuenta

    @Test("la semana acaba el día del aviso: con domingo, de lunes a domingo")
    func semanaHastaElDomingo() {
        #expect(ResumenSemanal.semana(delAviso: fecha(27, 20), calendar: madrid) == "2026-09-21"..."2026-09-27")
        #expect(ResumenSemanal.semana(delAviso: fecha(27, 20), semanasAtras: 1, calendar: madrid)
                == "2026-09-14"..."2026-09-20")
    }

    @Test("con el aviso en viernes, la semana va de sábado a viernes")
    func semanaHastaElViernes() {
        #expect(ResumenSemanal.semana(delAviso: fecha(25, 20), calendar: madrid) == "2026-09-19"..."2026-09-25")
    }

    @Test("suma la semana del aviso y la anterior, y deja fuera lo demás")
    func cifras() {
        let gastos = [
            gasto(40, "2026-09-21"),             // lunes: esta semana
            gasto(2.30, "2026-09-22T10:00:00"),  // con hora detrás: esta semana
            gasto(100, "2026-09-27", recurrente: true), // los recurrentes también cuentan
            gasto(15, "2026-09-20"),             // domingo anterior
            gasto(10, "2026-09-14"),             // lunes anterior
            gasto(999, "2026-09-13"),            // hace tres semanas: fuera
            gasto(999, "2026-09-28"),            // después del aviso: fuera
        ]
        let cifras = ResumenSemanal.cifras(de: gastos, aviso: fecha(27, 20), calendar: madrid)
        #expect(cifras.gastos == 3)
        #expect(abs(cifras.total - 142.30) < 0.001)
        #expect(cifras.gastosAnterior == 2)
        #expect(cifras.totalAnterior == 25)
    }

    // MARK: - Qué dice

    @Test("con datos: total, número de gastos y cuánto menos que la anterior")
    func textoMenos() {
        let cifras = ResumenSemanal.Cifras(total: 142.30, gastos: 18, totalAnterior: 165.30, gastosAnterior: 20)
        let contenido = ResumenSemanal.contenido(cifras)
        #expect(contenido.titulo == "Resumen semanal")
        #expect(contenido.cuerpo == "Esta semana llevas \(Formatters.currency(142.30)) en 18 gastos · "
                + "\(Formatters.currencyWithoutDecimals(23)) menos que la anterior")
        #expect(contenido.conDatos)
    }

    @Test("la diferencia se redondea a euros enteros")
    func textoMas() {
        let cifras = ResumenSemanal.Cifras(total: 100, gastos: 4, totalAnterior: 60.40, gastosAnterior: 3)
        #expect(ResumenSemanal.comparacion(cifras) == "\(Formatters.currencyWithoutDecimals(40)) más que la anterior")
    }

    @Test("si la diferencia redondea a cero, es lo mismo")
    func textoIgual() {
        let cifras = ResumenSemanal.Cifras(total: 100, gastos: 4, totalAnterior: 100.40, gastosAnterior: 5)
        #expect(ResumenSemanal.comparacion(cifras) == "lo mismo que la anterior")
    }

    @Test("un solo gasto va en singular")
    func singular() {
        let cifras = ResumenSemanal.Cifras(total: 3, gastos: 1)
        #expect(ResumenSemanal.contenido(cifras).cuerpo == "Esta semana llevas \(Formatters.currency(3)) en 1 gasto")
    }

    @Test("sin gastos la semana anterior no se compara")
    func sinSemanaAnterior() {
        let cifras = ResumenSemanal.Cifras(total: 50, gastos: 2)
        #expect(ResumenSemanal.comparacion(cifras) == nil)
        #expect(!ResumenSemanal.contenido(cifras).cuerpo.contains("·"))
    }

    @Test("una semana sin gastos manda el recordatorio de siempre")
    func sinGastos() {
        let cifras = ResumenSemanal.Cifras(total: 0, gastos: 0, totalAnterior: 80, gastosAnterior: 6)
        let contenido = ResumenSemanal.contenido(cifras)
        #expect(contenido == ResumenSemanal.recordatorio)
        #expect(contenido.titulo == "Recordatorio semanal")
        #expect(contenido.cuerpo == "Recuerda apuntar tus gastos de esta semana")
        #expect(!contenido.conDatos)
    }

    @Test("de los gastos al texto, de punta a punta")
    func deGastosATexto() {
        let gastos = [gasto(12.5, "2026-09-23"), gasto(7.5, "2026-09-24"), gasto(30, "2026-09-16")]
        let cifras = ResumenSemanal.cifras(de: gastos, aviso: fecha(27, 20), calendar: madrid)
        #expect(ResumenSemanal.contenido(cifras).cuerpo
                == "Esta semana llevas \(Formatters.currency(20)) en 2 gastos · "
                + "\(Formatters.currencyWithoutDecimals(10)) menos que la anterior")
    }

    @Test("los euros enteros no llevan céntimos ni abrevian los miles")
    func monedaSinDecimales() {
        #expect(Formatters.currencyWithoutDecimals(22.5) == Formatters.currencyWithoutDecimals(23))
        #expect(!Formatters.currencyWithoutDecimals(23).contains(","))
        #expect(!Formatters.currencyWithoutDecimals(1234.4).contains("k"))
        #expect(Formatters.currencyWithoutDecimals(23).contains("23"))
    }
}
