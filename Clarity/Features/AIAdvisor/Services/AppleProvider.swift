// AppleProvider.swift
// Clara corriendo en el propio iPhone, con el modelo de Apple Intelligence.
//
// Es el tercer proveedor, junto a Gemini y Groq, y el único sin clave: el
// modelo va dentro del sistema. Para una app donde el usuario mete su nómina y
// sus gastos, que la conversación no salga del dispositivo no es un detalle
// técnico, es el motivo de que Clara pueda volver a existir.
//
// A cambio es un modelo pequeño: se le da bien resumir y responder sobre datos
// que tiene delante, y mal el conocimiento abierto. El prompt se recorta más
// que con los proveedores remotos porque el techo son 4.096 tokens contando
// instrucciones, conversación y respuesta.

import Foundation
import OSLog

#if canImport(FoundationModels)
import FoundationModels
#endif

struct AppleProvider: AIServiceProvider {
    let name = "Apple · en el dispositivo"

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "AppleProvider")

    /// No hay clave que configurar: o el dispositivo puede, o no.
    var hasKey: Bool { Self.disponibilidad.esUsable }

    /// Historial que se le pasa. Los proveedores remotos usan 12 intercambios;
    /// aquí entran menos porque compiten por el mismo techo de tokens que el
    /// contexto financiero y la respuesta.
    private static let maxIntercambios = 4

    // MARK: - Disponibilidad

    enum Disponibilidad: Equatable {
        case disponible
        case dispositivoNoCompatible
        case appleIntelligenceDesactivada
        case modeloDescargando
        case noSoportado  // iOS anterior a 26
        case otra(String)

        var esUsable: Bool { self == .disponible }

        /// Explicación para el usuario. Sin jerga y diciendo qué puede hacer.
        var mensaje: String {
            switch self {
            case .disponible:
                return ""
            case .dispositivoNoCompatible:
                return "Clara funciona dentro de tu iPhone, sin enviar tus datos a ningún sitio. Para eso necesita un iPhone 15 Pro o posterior."
            case .appleIntelligenceDesactivada:
                return "Activa Apple Intelligence en Ajustes para que Clara pueda funcionar sin sacar tus datos del iPhone."
            case .modeloDescargando:
                return "El sistema está descargando el modelo. Vuelve en un rato."
            case .noSoportado:
                return "Clara necesita iOS 26 o posterior para funcionar dentro de tu iPhone."
            case .otra(let motivo):
                return "Clara no está disponible ahora mismo: \(motivo)"
            }
        }
    }

    static var disponibilidad: Disponibilidad {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *) else { return .noSoportado }
        switch SystemLanguageModel.default.availability {
        case .available:
            return .disponible
        case .unavailable(.deviceNotEligible):
            return .dispositivoNoCompatible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceDesactivada
        case .unavailable(.modelNotReady):
            return .modeloDescargando
        case .unavailable(let otra):
            return .otra(String(describing: otra))
        @unknown default:
            return .otra("desconocido")
        }
        #else
        return .noSoportado
        #endif
    }

    // MARK: - Envío

    func send(messages: [[String: String]]) async throws -> String {
        #if canImport(FoundationModels)
        guard #available(iOS 26.0, *), Self.disponibilidad.esUsable else {
            throw AIServiceError.modeloNoDisponible(Self.disponibilidad.mensaje)
        }

        // El array viene en formato OpenAI. El mensaje `system` es la persona y
        // el contexto financiero: va a `instructions`, que el modelo respeta por
        // encima del prompt.
        let instrucciones = messages
            .filter { $0["role"] == "system" }
            .compactMap { $0["content"] }
            .joined(separator: "\n\n")

        let conversacion = messages.filter { $0["role"] != "system" }
        let recientes = conversacion.suffix(Self.maxIntercambios * 2)

        // Sin API de historial estructurado: la conversación se pliega en un
        // único prompt, marcando quién habla.
        let prompt = recientes
            .map { mensaje -> String in
                let quien = mensaje["role"] == "assistant" ? "Clara" : "Usuario"
                return "\(quien): \(mensaje["content"] ?? "")"
            }
            .joined(separator: "\n")

        let session = LanguageModelSession(instructions: instrucciones)
        logger.info("🧠 Consultando el modelo del dispositivo (\(prompt.count) caracteres)")

        let respuesta = try await session.respond(to: prompt)
        return respuesta.content
        #else
        throw AIServiceError.modeloNoDisponible(Disponibilidad.noSoportado.mensaje)
        #endif
    }
}
