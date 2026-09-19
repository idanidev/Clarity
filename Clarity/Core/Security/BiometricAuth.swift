// BiometricAuth.swift
// Capa 3 de seguridad — autenticación biométrica (Face ID / Touch ID).

import LocalAuthentication

actor BiometricAuth {

    enum BiometricError: LocalizedError {
        case notAvailable
        /// Demasiados intentos fallidos: el sistema no vuelve a ofrecer la
        /// biometría hasta que se introduzca el código del dispositivo.
        case lockedOut
        case failed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notAvailable: "Autenticación biométrica no disponible en este dispositivo"
            case .lockedOut: "Biometría bloqueada por demasiados intentos"
            case .failed(let msg): msg
            case .cancelled: "Autenticación cancelada"
            }
        }
    }

    nonisolated var isBiometricAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    nonisolated var biometryTypeName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        switch context.biometryType {
        case .faceID:   return "Face ID"
        case .touchID:  return "Touch ID"
        case .opticID:  return "Optic ID"
        case .none:     return "Biometría"
        @unknown default: return "Biometría"
        }
    }

    func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = "Usar código"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Con Face ID bloqueado por intentos la política ni siquiera se puede
            // evaluar: se distingue para poder decirle al usuario que use el código.
            if error?.code == LAError.biometryLockout.rawValue {
                throw BiometricError.lockedOut
            }
            throw BiometricError.notAvailable
        }
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.cancelled
            case .userFallback:
                // El usuario eligió usar código — también válido
                try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            case .biometryLockout:
                throw BiometricError.lockedOut
            default:
                throw BiometricError.failed(laError.localizedDescription)
            }
        }
    }

    /// Autentica con el código del dispositivo (`.deviceOwnerAuthentication`).
    ///
    /// Es la salida cuando la biometría no sirve: Face ID bloqueado por intentos,
    /// una mascarilla, o el iPhone usado desde el Mac con iPhone Mirroring. Si la
    /// biometría funciona, el sistema la ofrece primero y deja el código a un toque.
    func authenticateConCodigo(reason: String) async throws {
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            // Sin código configurado en el dispositivo.
            throw BiometricError.notAvailable
        }
        do {
            try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricError.cancelled
            default:
                throw BiometricError.failed(laError.localizedDescription)
            }
        }
    }
}
