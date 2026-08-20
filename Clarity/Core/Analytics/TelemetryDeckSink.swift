// TelemetryDeckSink.swift
// Destino de analytics en TelemetryDeck (#41).
//
// Se eligió frente a Firebase Analytics porque es anónimo por diseño: no
// recoge identificadores del dispositivo ni datos personales, así que no
// obliga a declarar recogida de datos en la ficha de privacidad.

import Foundation
import OSLog
import TelemetryDeck

struct TelemetryDeckSink: AnalyticsSink {
    /// El SDK no tiene propiedades de usuario persistentes, así que se guardan
    /// aquí y se adjuntan a cada señal. Es un `final class` porque el sink se
    /// copia por valor y todas las copias deben ver las mismas propiedades.
    private final class PropertyStore: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: String] = [:]

        func set(_ value: String?, for name: String) {
            lock.lock()
            defer { lock.unlock() }
            if let value { values[name] = value } else { values.removeValue(forKey: name) }
        }

        var snapshot: [String: String] {
            lock.lock()
            defer { lock.unlock() }
            return values
        }
    }

    private let properties = PropertyStore()

    func send(name: String, parameters: [String: String]) {
        TelemetryDeck.signal(name, parameters: properties.snapshot.merging(parameters) { _, new in new })
    }

    func setUserProperty(_ value: String?, for name: String) {
        properties.set(value, for: name)
    }
}

enum TelemetryDeckConfig {
    /// Clave del App ID en Info.plist. No es un secreto (identifica al cliente,
    /// no autentica), pero tampoco tiene por qué vivir en el código.
    private static let appIDKey = "TelemetryDeckAppID"

    static var appID: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: appIDKey) as? String,
              !value.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return value
    }

    /// Arranca el SDK. Sin App ID no hace nada: la app funciona igual y no se
    /// envía ninguna señal.
    @discardableResult
    static func start() -> Bool {
        guard let appID else {
            Logger(subsystem: "com.idanidev.clarity", category: "Analytics")
                .notice("TelemetryDeck sin configurar (falta \(appIDKey) en Info.plist)")
            return false
        }

        let configuration = TelemetryDeck.Config(appID: appID)
        #if DEBUG
        // Las señales de desarrollo se marcan como test para no ensuciar las
        // métricas reales.
        configuration.testMode = true
        #endif
        TelemetryDeck.initialize(config: configuration)
        return true
    }
}
