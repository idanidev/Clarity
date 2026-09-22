// EntornoApp.swift
// De dónde viene esta instalación: la App Store, el sandbox (TestFlight y
// App Review) o Xcode. Va a Analytics como propiedad de usuario `entorno`.

import StoreKit

enum EntornoApp {
    static func actual() async -> String {
        #if DEBUG
        return nombre(de: .xcode)
        #else
        // `shared` no pide iniciar sesión en la App Store (eso es `refresh()`):
        // devuelve la transacción guardada o la trae en silencio.
        guard let resultado = try? await AppTransaction.shared else { return "desconocido" }
        switch resultado {
        case .verified(let transaccion), .unverified(let transaccion, _):
            return nombre(de: transaccion.environment)
        }
        #endif
    }

    static func nombre(de entorno: AppStore.Environment) -> String {
        switch entorno {
        case .production: return "appstore"
        case .sandbox: return "sandbox"
        case .xcode: return "xcode"
        default: return "desconocido"
        }
    }
}
