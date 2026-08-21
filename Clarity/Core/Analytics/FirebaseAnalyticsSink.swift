// FirebaseAnalyticsSink.swift
// Adaptador de AnalyticsSink a Firebase Analytics (#41).
//
// Se eligió Firebase por tener las métricas en la misma consola que la base de
// datos. A cambio recoge más que una herramienta anónima: identificador de
// dispositivo, ubicación aproximada por IP y datos de diagnóstico. Eso hay que
// declararlo en el cuestionario de privacidad de App Store Connect — ver
// docs/ASO-y-lanzamiento.md.

import FirebaseAnalytics
import Foundation

struct FirebaseAnalyticsSink: AnalyticsSink {
    func send(name: String, parameters: [String: String]) {
        Analytics.logEvent(name, parameters: parameters)
    }

    func setUserProperty(_ value: String?, for name: String) {
        Analytics.setUserProperty(value, forName: name)
    }
}

enum AnalyticsBootstrap {
    /// Engancha los destinos disponibles. Llamar una vez al arrancar.
    @MainActor
    static func configure() {
        AnalyticsService.shared.registerFirstOpenIfNeeded()

        AnalyticsService.shared.register(sink: FirebaseAnalyticsSink())

        AnalyticsService.shared.startSession()
        AnalyticsService.shared.syncUserProperties()
    }
}
