// AnalyticsFirebaseTests.swift
// Lo que sale hacia Firebase (2.4.0): pantallas con nombre también en iOS 27,
// números como número, motivos de fallo de voz cerrados y los orígenes que
// antes no llegaban nunca (widget, controles, Apple Pay, recurrentes, CSV).

import Testing
import Foundation
import StoreKit
@testable import Clarity

@Suite("Analytics hacia Firebase")
@MainActor
struct AnalyticsFirebaseTests {

    @Test("una pantalla sale como screen_view con nombre, clase y el nombre repetido en «pantalla»")
    func pantallaConNombreRepetido() {
        let evento = AnalyticsEvent.screenViewed(name: "home")
        let salida = AnalyticsEvent.paraFirebase(nombre: evento.name, parametros: evento.parameters)
        #expect(salida.nombre == "screen_view")
        #expect(salida.parametros["screen_name"] as? String == "home")
        #expect(salida.parametros["screen_class"] as? String == "home")
        #expect(salida.parametros["pantalla"] as? String == "home")
        #expect(salida.parametros.count == 3)
    }

    @Test("la duración de la sesión llega como número, para que la métrica de GA sume")
    func duracionComoNumero() {
        let evento = AnalyticsEvent.sessionEnded(seconds: 95)
        let salida = AnalyticsEvent.paraFirebase(nombre: evento.name, parametros: evento.parameters)
        #expect(salida.nombre == "session_ended")
        #expect(salida.parametros["duration_seconds"] as? Int == 95)
    }

    @Test("el resto de parámetros sigue viajando como texto")
    func restoComoTexto() {
        let evento = AnalyticsEvent.budgetLimitReached(percent: 80)
        let salida = AnalyticsEvent.paraFirebase(nombre: evento.name, parametros: evento.parameters)
        // `percent` está dado de alta como dimensión: tiene que seguir siendo texto.
        #expect(salida.parametros["percent"] as? String == "80")
    }

    @Test("el fallo de voz manda un motivo del vocabulario cerrado")
    func falloDeVoz() {
        let evento = AnalyticsEvent.voiceExpenseFailed(reason: .sinImporte)
        #expect(evento.name == "voice_expense_failed")
        #expect(evento.parameters == ["reason": "sin_importe"])
    }

    @Test("cada error del parser tiene su motivo")
    func motivosDelParser() {
        #expect(FalloVoz(.noAmountFound) == .sinImporte)
        #expect(FalloVoz(.emptyInput) == .sinAudio)
        #expect(FalloVoz(.invalidFormat) == .formato)
        // Las candidatas no viajan: el motivo es solo el nombre del caso.
        #expect(FalloVoz(.ambiguousCategory(candidates: ["Ocio", "Salud"])).rawValue == "categoria_ambigua")
    }

    @Test("abrir la app desde fuera lleva el origen en «method», que GA ya trae")
    func entradaExterna() {
        #expect(AnalyticsEvent.entradaExterna(.widget).name == "entrada_externa")
        #expect(AnalyticsEvent.entradaExterna(.widget).parameters == ["method": "widget"])
        #expect(AnalyticsEvent.entradaExterna(.controlDictar).parameters == ["method": "control_dictar"])
        #expect(AnalyticsEvent.entradaExterna(.siri).parameters == ["method": "siri"])
        #expect(AnalyticsEvent.entradaExterna(.applePay).parameters == ["method": "apple_pay"])
    }

    @Test("los cargos recurrentes y la importación van aparte de expense_added")
    func recurrentesEImportacion() {
        #expect(AnalyticsEvent.recurringExpenseCreated.name == "gasto_recurrente_creado")
        #expect(AnalyticsEvent.recurringExpenseCreated.parameters.isEmpty)
        #expect(AnalyticsEvent.csvImported.name == "importacion_csv")
        #expect(AnalyticsEvent.csvImported.parameters.isEmpty)
    }

    @Test("un gasto del Atajo de Apple Pay se cuenta como apple_pay, no como voz")
    func applePay() {
        let evento = AnalyticsEvent.expenseAdded(method: .applePay, category: "Ocio")
        #expect(evento.parameters["method"] == "apple_pay")
    }

    @Test("la versión de instalación: la actual para quien se estrena, y una marca para quien ya estaba")
    func versionDeInstalacion() {
        #expect(AnalyticsService.versionDeInstalacion(yaHabiaArrancado: false, actual: "2.4.0") == "2.4.0")
        #expect(AnalyticsService.versionDeInstalacion(yaHabiaArrancado: true, actual: "2.4.0") == "anterior_a_2.4.0")
    }

    @Test("el entorno separa App Store, sandbox (TestFlight y App Review) y Xcode")
    func entorno() {
        #expect(EntornoApp.nombre(de: .production) == "appstore")
        #expect(EntornoApp.nombre(de: .sandbox) == "sandbox")
        #expect(EntornoApp.nombre(de: .xcode) == "xcode")
    }
}
