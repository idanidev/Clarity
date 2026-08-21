// SupportContact.swift
// Canal de contacto con quien usa la app (#50).
//
// Hasta ahora no había ninguno: de las personas que instalaban y abandonaban no
// se podía saber nada, y la única fuente cualitativa era la intuición del propio
// desarrollador. Con volúmenes pequeños, un correo vale más que cualquier panel.

import Foundation
import UIKit

enum SupportContact {
    /// Dirección de soporte. La misma que figura como contacto de revisión en
    /// App Store Connect.
    static let email = "idanideveloper@gmail.com"

    /// Datos técnicos que ahorran la primera ronda de preguntas. Solo versión,
    /// modelo e iOS: nada de la cuenta ni de los gastos de quien escribe.
    static var diagnosticsFooter: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return """


        ---
        Clarity \(version) (\(build))
        \(deviceModel) · iOS \(UIDevice.current.systemVersion)
        """
    }

    /// Identificador de hardware ("iPhone16,2"). No identifica a la persona.
    private static var deviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let identifier = Mirror(reflecting: systemInfo.machine).children
            .reduce(into: "") { partial, element in
                guard let value = element.value as? Int8, value != 0 else { return }
                partial.append(Character(UnicodeScalar(UInt8(value))))
            }
        return identifier.isEmpty ? "iPhone" : identifier
    }

    /// URL de correo con asunto y plantilla ya puestos.
    static func mailURL(for reason: Reason) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        components.queryItems = [
            URLQueryItem(name: "subject", value: reason.subject),
            URLQueryItem(name: "body", value: reason.prompt + diagnosticsFooter),
        ]
        return components.url
    }

    /// Motivos de contacto. Separarlos permite saber de qué escribe la gente sin
    /// tener que abrir cada correo.
    enum Reason: String, CaseIterable, Identifiable {
        case problem
        case idea

        var id: String { rawValue }

        var subject: String {
            switch self {
            case .problem: return "Clarity — algo no funciona"
            case .idea: return "Clarity — una idea"
            }
        }

        var prompt: String {
            switch self {
            case .problem: return "Cuéntame qué ha pasado y en qué pantalla:\n\n"
            case .idea: return "Cuéntame qué echas en falta o qué cambiarías:\n\n"
            }
        }

        var label: String {
            switch self {
            case .problem: return "Algo no funciona"
            case .idea: return "Tengo una idea"
            }
        }

        var icon: String {
            switch self {
            case .problem: return "exclamationmark.bubble"
            case .idea: return "lightbulb"
            }
        }
    }
}
