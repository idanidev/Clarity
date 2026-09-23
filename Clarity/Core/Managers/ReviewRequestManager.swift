// ReviewRequestManager.swift
// Pide la reseña de App Store en un momento de éxito, no al abrir (#39).
//
// Reglas (2.4.1): solo a quien ya usa la app de verdad —3 sesiones, 3 días
// distintos con gastos y 5 gastos apuntados—, un momento después de una acción
// que ha salido bien, una vez por versión y como mucho 3 veces al año (el
// propio límite de Apple). Hasta la 2.4.0 bastaba la tercera sesión: se pedía
// en el primer gasto de esa sesión, a gente que apenas conocía la app, y de 48
// personas a las que se pidió salieron 4 valoraciones.

import Foundation
import OSLog
import StoreKit
import UIKit

@MainActor
final class ReviewRequestManager {
    static let shared = ReviewRequestManager()

    private enum Key {
        static let sessionCount = "review.sessionCount"
        static let promptDates = "review.promptDates"
        static let lastVersionPrompted = "review.lastVersionPrompted"
    }

    /// Antes de esta sesión no se pide nada: el usuario aún no conoce la app.
    private static let minimumSessions = 3
    /// Días distintos con algún gasto: que apuntar ya sea costumbre.
    private static let minimoDiasConGasto = 3
    /// Gastos apuntados en total.
    private static let minimoGastos = 5
    /// Lo que se espera tras la acción: que se cierre la hoja y se vea el
    /// aviso de «guardado» antes de la ventana del sistema.
    private static let espera: Duration = .milliseconds(1500)

    /// La ficha de la App Store con el formulario de reseña abierto. Para la
    /// fila de Ajustes: ahí la valoración la pide el usuario, no la app.
    static let urlEscribirResena = URL(string: "https://apps.apple.com/app/id6762994393?action=write-review")!
    /// Límite de Apple: 3 peticiones por usuario y año.
    private static let maxPromptsPerYear = 3

    private let defaults = UserDefaults.standard
    private let logger = Logger(subsystem: "com.idanidev.clarity", category: "ReviewRequest")

    private init() {}

    /// Llamar una vez por lanzamiento en frío.
    func registerSession() {
        defaults.set(sessionCount + 1, forKey: Key.sessionCount)
    }

    var sessionCount: Int {
        defaults.integer(forKey: Key.sessionCount)
    }

    /// Llamar tras una acción que haya salido bien (gasto guardado, meta
    /// alcanzada, deuda cobrada). No pide nada si no toca.
    func requestReviewIfAppropriate() {
        guard shouldRequest else { return }

        Task { [weak self] in
            try? await Task.sleep(for: Self.espera)
            // Tras la espera se vuelve a mirar: pudo pedirse ya desde otro
            // sitio, o la app pudo pasar a segundo plano.
            guard let self, self.shouldRequest,
                  let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive })
            else { return }

            AppStore.requestReview(in: scene)
            self.recordPrompt()
            AnalyticsService.shared.track(.reviewPrompted)
            self.logger.info("Solicitada reseña (sesión \(self.sessionCount))")
        }
    }

    // MARK: - Reglas

    private var shouldRequest: Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        return Self.tocaPedir(
            sesiones: sessionCount,
            diasConGasto: AnalyticsService.shared.activeDays.count,
            gastos: AnalyticsService.shared.totalExpensesLogged,
            yaPedidaEnEstaVersion: defaults.string(forKey: Key.lastVersionPrompted) == currentVersion,
            pedidasEnElUltimoAno: promptsInLastYear.count
        )
    }

    /// La decisión, sin estado, para poder probarla.
    static func tocaPedir(
        sesiones: Int,
        diasConGasto: Int,
        gastos: Int,
        yaPedidaEnEstaVersion: Bool,
        pedidasEnElUltimoAno: Int
    ) -> Bool {
        sesiones >= minimumSessions
            && diasConGasto >= minimoDiasConGasto
            && gastos >= minimoGastos
            // Una sola petición por versión: si ya se pidió en esta, no insistir.
            && !yaPedidaEnEstaVersion
            && pedidasEnElUltimoAno < maxPromptsPerYear
    }

    private var promptsInLastYear: [Date] {
        let stored = defaults.array(forKey: Key.promptDates) as? [Double] ?? []
        let cutoff = Date().addingTimeInterval(-365 * 24 * 60 * 60).timeIntervalSince1970
        return stored.filter { $0 >= cutoff }.map { Date(timeIntervalSince1970: $0) }
    }

    private func recordPrompt() {
        var stored = promptsInLastYear.map(\.timeIntervalSince1970)
        stored.append(Date().timeIntervalSince1970)
        defaults.set(stored, forKey: Key.promptDates)

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        defaults.set(currentVersion, forKey: Key.lastVersionPrompted)
    }
}
