// ProLimitsTests.swift
// El tope mensual de gastos por voz del plan gratuito y su puesta a cero al
// cambiar de mes. Con el paywall apagado nadie lo ve, y justo por eso un fallo
// aquí saldría a la luz el día que se encienda: un contador que no se reinicia
// deja sin voz al usuario el día 1, y uno que se reinicia de más regala el plan.
//
// Se prueban las reglas puras. A propósito NO se toca `UserDefaults.standard`
// ni `ProConfig.paywallEnabled`: los tests corren dentro de la app, en un
// simulador con la sesión real, y esas claves son las de verdad.

import Testing
import Foundation
@testable import Clarity

@Suite("Límite mensual de gastos por voz")
@MainActor
struct ProLimitsTests {

    /// Clave de mes de una fecha real, por el mismo camino que usa la app.
    /// A mediodía para que ningún huso horario la mueva de día.
    private func mes(_ anio: Int, _ mes: Int, _ dia: Int) throws -> String {
        let fecha = try #require(Calendar.current.date(
            from: DateComponents(year: anio, month: mes, day: dia, hour: 12)))
        return Formatters.monthString(from: fecha)
    }

    // MARK: - Usados este mes

    @Test("dentro del mismo mes cuenta lo guardado")
    func mismoMes() {
        #expect(ProLimits.vozUsadosEsteMes(guardados: 7, mesGuardado: "2026-09", mesActual: "2026-09") == 7)
    }

    @Test("al cambiar de mes el contador viejo deja de contar")
    func otroMes() {
        #expect(ProLimits.vozUsadosEsteMes(guardados: 30, mesGuardado: "2026-09", mesActual: "2026-10") == 0)
    }

    @Test("sin nada guardado todavía: cero")
    func sinEstadoPrevio() {
        #expect(ProLimits.vozUsadosEsteMes(guardados: 0, mesGuardado: nil, mesActual: "2026-09") == 0)
    }

    // Si la clave fuera solo el mes, enero de un año heredaría el de otro.
    @Test("mismo mes de otro año no es el mismo mes")
    func mismoMesOtroAnio() {
        #expect(ProLimits.vozUsadosEsteMes(guardados: 12, mesGuardado: "2026-01", mesActual: "2027-01") == 0)
    }

    @Test("diciembre → enero con fechas reales: se reinicia")
    func diciembreAEnero() throws {
        let diciembre = try mes(2026, 12, 31)
        let enero = try mes(2027, 1, 1)
        #expect(diciembre != enero)

        #expect(ProLimits.vozUsadosEsteMes(guardados: 30, mesGuardado: diciembre, mesActual: enero) == 0)
        let trasElPrimero = ProLimits.vozTrasRegistrar(guardados: 30, mesGuardado: diciembre, mesActual: enero)
        #expect(trasElPrimero.usados == 1)
        #expect(trasElPrimero.mes == enero)
    }

    @Test("del día 1 al último del mes la clave no cambia")
    func mismoMesConFechasReales() throws {
        #expect(try mes(2026, 2, 1) == mes(2026, 2, 28))
        #expect(try mes(2026, 1, 31) != mes(2026, 2, 1))
    }

    // MARK: - Registrar

    @Test("registrar dentro del mes suma uno y conserva el mes")
    func registrarMismoMes() {
        let nuevo = ProLimits.vozTrasRegistrar(guardados: 4, mesGuardado: "2026-09", mesActual: "2026-09")
        #expect(nuevo.usados == 5)
        #expect(nuevo.mes == "2026-09")
    }

    @Test("el primero del mes nuevo deja el contador en 1, no en «los de antes + 1»")
    func registrarTrasCambioDeMes() {
        let nuevo = ProLimits.vozTrasRegistrar(guardados: 29, mesGuardado: "2026-09", mesActual: "2026-10")
        #expect(nuevo.usados == 1)
        #expect(nuevo.mes == "2026-10")
    }

    @Test("el primer gasto por voz de la historia")
    func registrarSinEstadoPrevio() {
        let nuevo = ProLimits.vozTrasRegistrar(guardados: 0, mesGuardado: nil, mesActual: "2026-09")
        #expect(nuevo.usados == 1)
        #expect(nuevo.mes == "2026-09")
    }

    // MARK: - Tope

    @Test("restantes hasta el tope", arguments: [
        (0, 30), (1, 29), (29, 1), (30, 0),
    ])
    func restantes(_ usados: Int, _ esperado: Int) {
        #expect(ProLimits.vozRestantes(usados: usados, limite: ProLimits.voiceExpensesPerMonth) == esperado)
    }

    @Test("pasado el tope quedan cero, nunca negativos")
    func restantesNuncaNegativos() {
        #expect(ProLimits.vozRestantes(usados: 45, limite: 30) == 0)
    }

    @Test("un mes entero: 30 entran, el 31 ya no, y el mes siguiente vuelve a haber 30")
    func mesCompleto() {
        let limite = ProLimits.voiceExpensesPerMonth
        var guardados = 0
        var mesGuardado: String? = nil

        for _ in 0..<limite {
            let usados = ProLimits.vozUsadosEsteMes(guardados: guardados, mesGuardado: mesGuardado, mesActual: "2026-12")
            #expect(ProLimits.vozRestantes(usados: usados, limite: limite) > 0)
            let nuevo = ProLimits.vozTrasRegistrar(guardados: guardados, mesGuardado: mesGuardado, mesActual: "2026-12")
            guardados = nuevo.usados
            mesGuardado = nuevo.mes
        }

        let usadosDiciembre = ProLimits.vozUsadosEsteMes(guardados: guardados, mesGuardado: mesGuardado, mesActual: "2026-12")
        #expect(usadosDiciembre == limite)
        #expect(ProLimits.vozRestantes(usados: usadosDiciembre, limite: limite) == 0)

        let usadosEnero = ProLimits.vozUsadosEsteMes(guardados: guardados, mesGuardado: mesGuardado, mesActual: "2027-01")
        #expect(ProLimits.vozRestantes(usados: usadosEnero, limite: limite) == limite)
    }

    // El paywall está apagado y así debe seguir: con él apagado no hay tope.
    // Solo se LEE el interruptor; si algún día se enciende, este test lo canta.
    // `#require` y no `#expect`: encendido, la línea siguiente despertaría a
    // `SubscriptionManager.shared` (StoreKit de verdad), y eso un test no lo toca.
    @Test("con el paywall apagado no hay límite")
    func paywallApagadoSinLimite() throws {
        try #require(ProConfig.paywallEnabled == false)
        #expect(ProLimits.remainingVoiceExpenses == .max)
        #expect(ProLimits.canUseVoice)
    }
}
