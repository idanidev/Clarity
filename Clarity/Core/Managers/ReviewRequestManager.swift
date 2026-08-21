// ReviewRequestManager.swift
// Pide la reseña de App Store en un momento de éxito, no al abrir (#39).
// Reglas: a partir de la Nª sesión, tras una acción positiva, y como mucho
// 3 veces al año — el propio límite que aplica Apple.

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

        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }

        AppStore.requestReview(in: scene)
        recordPrompt()
        AnalyticsService.shared.track(.reviewPrompted)
        logger.info("Solicitada reseña (sesión \(self.sessionCount))")
    }

    // MARK: - Reglas

    private var shouldRequest: Bool {
        guard sessionCount >= Self.minimumSessions else { return false }

        // Una sola petición por versión: si ya se pidió en esta, no insistir.
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        if defaults.string(forKey: Key.lastVersionPrompted) == currentVersion { return false }

        return promptsInLastYear.count < Self.maxPromptsPerYear
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
