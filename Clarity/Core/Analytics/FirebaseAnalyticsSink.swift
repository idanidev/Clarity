// FirebaseAnalyticsSink.swift
// Adaptador de AnalyticsSink a Firebase Analytics.
//
// Se compila SOLO si el producto `FirebaseAnalytics` está añadido al target
// (Xcode → Package Dependencies → firebase-ios-sdk → FirebaseAnalytics).
// Se deja así a propósito: enlazar Analytics recoge identificadores del
// dispositivo, y eso obliga a declararlo en la ficha de privacidad de App Store
// y en PrivacyInfo.xcprivacy — una declaración que tiene que hacer el
// desarrollador, no el código.

#if canImport(FirebaseAnalytics)
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
#endif

import Foundation

enum AnalyticsBootstrap {
    /// Engancha los destinos disponibles. Llamar una vez al arrancar.
    @MainActor
    static func configure() {
        AnalyticsService.shared.registerFirstOpenIfNeeded()

        // TelemetryDeck es el destino principal: anónimo por diseño (#41).
        if TelemetryDeckConfig.start() {
            AnalyticsService.shared.register(sink: TelemetryDeckSink())
        }

        #if canImport(FirebaseAnalytics)
        AnalyticsService.shared.register(sink: FirebaseAnalyticsSink())
        #endif

        AnalyticsService.shared.startSession()
        AnalyticsService.shared.syncUserProperties()
    }
}
