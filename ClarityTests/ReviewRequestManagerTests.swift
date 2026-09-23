// ReviewRequestManagerTests.swift
// Cuándo se pide la valoración (2.4.1): solo a quien ya usa la app de verdad.

import Testing
import Foundation
@testable import Clarity

@Suite("Cuándo se pide la valoración")
@MainActor
struct ReviewRequestManagerTests {

    private func toca(sesiones: Int = 5, dias: Int = 4, gastos: Int = 8,
                      yaPedida: Bool = false, pedidas: Int = 0) -> Bool {
        ReviewRequestManager.tocaPedir(sesiones: sesiones, diasConGasto: dias, gastos: gastos,
                                       yaPedidaEnEstaVersion: yaPedida, pedidasEnElUltimoAno: pedidas)
    }

    @Test("a quien ya apunta a menudo, sí")
    func usuarioHabitual() { #expect(toca()) }

    @Test("en la tercera sesión, sin costumbre todavía, no (lo que pasaba hasta la 2.4.0)")
    func pocoUso() {
        #expect(!toca(sesiones: 3, dias: 1, gastos: 1))
        #expect(!toca(dias: 2))
        #expect(!toca(gastos: 4))
        #expect(!toca(sesiones: 2))
    }

    @Test("justo en los mínimos, sí")
    func minimos() { #expect(toca(sesiones: 3, dias: 3, gastos: 5)) }

    @Test("una vez por versión y como mucho tres al año")
    func limites() {
        #expect(!toca(yaPedida: true))
        #expect(!toca(pedidas: 3))
        #expect(toca(pedidas: 2))
    }

    @Test("el enlace abre el formulario de reseña de la ficha de Clarity")
    func enlace() {
        let url = ReviewRequestManager.urlEscribirResena.absoluteString
        #expect(url.contains("id6762994393"))
        #expect(url.contains("action=write-review"))
    }

    @Test("tocar «Valorar» en Ajustes se mide")
    func evento() {
        #expect(AnalyticsEvent.reviewLinkOpened.name == "valorar_desde_ajustes")
        #expect(AnalyticsEvent.reviewLinkOpened.parameters.isEmpty)
    }
}
