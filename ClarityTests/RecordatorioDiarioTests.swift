// RecordatorioDiarioTests.swift
// Cuándo sale el recordatorio diario (#57): siete avisos por delante, sin el
// de hoy si ya se ha apuntado algo hoy.

import Foundation
import Testing
@testable import Clarity

@Suite("RecordatorioDiario")
@MainActor
struct RecordatorioDiarioTests {

    private var madrid: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Madrid")!
        return c
    }

    private func fecha(_ dia: Int, mes: Int = 9, _ hora: Int, _ minuto: Int = 0) -> Date {
        madrid.date(from: DateComponents(year: 2026, month: mes, day: dia, hour: hora, minute: minuto))!
    }

    // MARK: - Cuándo sale

    @Test("antes de la hora y sin gasto de hoy, el primero es hoy")
    func hoyEntra() {
        let avisos = RecordatorioDiario.proximosAvisos(desde: fecha(22, 12), hora: 21, minuto: 0,
                                                       hayGastoHoy: false, calendar: madrid)
        #expect(avisos.count == 7)
        #expect(avisos.first == fecha(22, 21))
        #expect(avisos.last == fecha(28, 21))
    }

    @Test("con gasto de hoy, se salta hoy y siguen siendo siete")
    func hoySeSalta() {
        let avisos = RecordatorioDiario.proximosAvisos(desde: fecha(22, 12), hora: 21, minuto: 0,
                                                       hayGastoHoy: true, calendar: madrid)
        #expect(avisos.count == 7)
        #expect(avisos.first == fecha(23, 21))
        #expect(avisos.last == fecha(29, 21))
    }

    @Test("pasada la hora, el primero es mañana")
    func pasadaLaHora() {
        let avisos = RecordatorioDiario.proximosAvisos(desde: fecha(22, 21, 5), hora: 21, minuto: 0,
                                                       hayGastoHoy: false, calendar: madrid)
        #expect(avisos.first == fecha(23, 21))
        #expect(avisos.count == 7)
    }

    @Test("respeta la hora y el minuto elegidos")
    func horaElegida() {
        let avisos = RecordatorioDiario.proximosAvisos(desde: fecha(22, 7), hora: 8, minuto: 30,
                                                       hayGastoHoy: false, calendar: madrid)
        #expect(avisos.first == fecha(22, 8, 30))
    }

    @Test("el cambio de hora no mueve la hora del aviso")
    func cambioDeHora() {
        let avisos = RecordatorioDiario.proximosAvisos(desde: fecha(22, mes: 10, 12), hora: 21, minuto: 0,
                                                       hayGastoHoy: false, calendar: madrid)
        #expect(avisos.map { madrid.component(.hour, from: $0) } == Array(repeating: 21, count: 7))
    }

    // MARK: - ¿Hay gasto de hoy?

    @Test("un gasto con fecha de hoy cuenta, aunque lleve la hora detrás")
    func gastoDeHoy() {
        let ahora = fecha(22, 20)
        #expect(RecordatorioDiario.hayGastoApuntadoHoy(
            [Expense(amount: 3, name: "Café", category: "Ocio", date: "2026-09-22")], ahora: ahora, calendar: madrid))
        #expect(RecordatorioDiario.hayGastoApuntadoHoy(
            [Expense(amount: 3, name: "Café", category: "Ocio", date: "2026-09-22T09:00:00")],
            ahora: ahora, calendar: madrid))
    }

    @Test("los de otros días no cuentan")
    func gastoDeAyer() {
        #expect(!RecordatorioDiario.hayGastoApuntadoHoy(
            [Expense(amount: 3, name: "Café", category: "Ocio", date: "2026-09-21")],
            ahora: fecha(22, 20), calendar: madrid))
    }

    @Test("un recurrente creado hoy por la app no cuenta como apuntado")
    func recurrenteNoCuenta() {
        let gastos = [
            Expense(amount: 12.99, name: "Netflix", category: "Suscripciones", date: "2026-09-22", isRecurring: true),
            Expense(amount: 9.99, name: "Spotify", category: "Suscripciones", date: "2026-09-22", recurringId: "r1"),
        ]
        #expect(!RecordatorioDiario.hayGastoApuntadoHoy(gastos, ahora: fecha(22, 20), calendar: madrid))
    }
}
