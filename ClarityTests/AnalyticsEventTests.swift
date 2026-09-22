// AnalyticsEventTests.swift
// Nombres y parámetros de los eventos (#41). Si cambian sin querer, los
// paneles de TelemetryDeck dejan de cuadrar en silencio.

import Testing
import Foundation
@testable import Clarity

@Suite("AnalyticsEvent")
struct AnalyticsEventTests {

    @Test("los eventos de Clarity conservan el nombre acordado en el issue")
    func clarityEventNames() {
        #expect(AnalyticsEvent.aiCategoryCorrected(from: "Ocio", to: "Salud").name == "categoria_ia_corregida")
        #expect(AnalyticsEvent.budgetConfigured(source: "month_created").name == "presupuesto_configurado")
        #expect(AnalyticsEvent.budgetLimitReached(percent: 80).name == "limite_alcanzado")
        #expect(AnalyticsEvent.extraIncomeLogged.name == "ingreso_extra_registrado")
    }

    @Test("el gasto lleva el método, que es lo que dice si la voz se usa")
    func expenseAddedCarriesMethod() {
        let event = AnalyticsEvent.expenseAdded(method: .voice, category: "Ocio")
        #expect(event.name == "expense_added")
        #expect(event.parameters["method"] == "voice")
        #expect(event.parameters["category"] == "Ocio")
    }

    @Test("la sesión reporta dispositivo y versión de iOS")
    func sessionCarriesDeviceInfo() {
        let event = AnalyticsEvent.sessionStarted(deviceModel: "iPhone16,1", systemVersion: "18.0")
        #expect(event.parameters["device"] == "iPhone16,1")
        #expect(event.parameters["os_version"] == "18.0")
    }

    @Test("la corrección de categoría solo lleva nombres de categoría")
    func categoryCorrectionHasNoUserContent() {
        // Nunca el concepto ni el importe: son datos del usuario.
        let event = AnalyticsEvent.aiCategoryCorrected(from: "Ocio", to: "Alimentacion")
        #expect(event.parameters == ["from": "Ocio", "to": "Alimentacion"])
    }

    @Test("los eventos sin datos no arrastran parámetros")
    func plainEventsHaveNoParameters() {
        #expect(AnalyticsEvent.extraIncomeLogged.parameters.isEmpty)
        #expect(AnalyticsEvent.reviewPrompted.parameters.isEmpty)
        #expect(AnalyticsEvent.onboardingCompleted.parameters.isEmpty)
    }

    @Test("la duración de sesión viaja como entero en segundos")
    func sessionEndedDuration() {
        #expect(AnalyticsEvent.sessionEnded(seconds: 95).parameters["duration_seconds"] == "95")
    }

    @Test("cada página del onboarding manda su posición y su nombre, nada más")
    @MainActor
    func onboardingStep() {
        let event = PasoOnboarding.primerGasto.evento
        #expect(event.name == "onboarding_step")
        #expect(event.parameters == ["index": "3", "step": "primer_gasto"])
    }

    @Test("los pasos del onboarding conservan nombre y orden")
    @MainActor
    func onboardingStepNames() {
        // Si cambian, el embudo de antes y el de después dejan de cuadrar.
        #expect(PasoOnboarding.allCases.map(\.nombre) == ["bienvenida", "voz", "tutorial", "primer_gasto", "listo"])
        #expect(PasoOnboarding.allCases.map(\.rawValue) == [0, 1, 2, 3, 4])
        // Y las pantallas que ya se mandaban siguen llamándose igual.
        #expect(PasoOnboarding.allCases.map(\.nombrePantalla) == [
            "onboarding_bienvenida", "onboarding_voz", "onboarding_tutorial",
            "onboarding_primer_gasto", "onboarding_listo",
        ])
    }
}
