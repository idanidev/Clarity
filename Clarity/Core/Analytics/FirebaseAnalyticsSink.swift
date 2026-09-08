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
        // El informe de Pantallas de Firebase solo se llena con su evento
        // canónico. Un `screen_viewed` propio queda como un evento suelto y ese
        // informe sale vacío —o peor, con los controladores del sistema que
        // registraba el reporte automático—, así que aquí se traduce. Este es el
        // sitio: el resto del código no sabe ni tiene que saber de Firebase.
        if name == AnalyticsEvent.screenViewedName,
           let screen = parameters[AnalyticsEvent.screenParameter] {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: screen
            ])
            return
        }
        Analytics.logEvent(name, parameters: parameters)
    }

    func setUserProperty(_ value: String?, for name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    /// Firebase recoge sesiones y pantallas por su cuenta, así que no basta con
    /// dejar de mandar eventos propios: hay que apagar el SDK entero.
    func setCollectionEnabled(_ enabled: Bool) {
        Analytics.setAnalyticsCollectionEnabled(enabled)
    }
}

enum AnalyticsBootstrap {
    /// Engancha los destinos disponibles. Llamar una vez al arrancar.
    @MainActor
    static func configure() {
        AnalyticsService.shared.registerFirstOpenIfNeeded()

        AnalyticsService.shared.register(sink: FirebaseAnalyticsSink())
        // Antes de emitir nada: si este dispositivo está excluido, Firebase se
        // apaga aquí y no llega a registrar ni la primera sesión.
        AnalyticsService.shared.applyExclusionToRemoteSinks()

        AnalyticsService.shared.startSession()
        AnalyticsService.shared.syncUserProperties()
    }
}
