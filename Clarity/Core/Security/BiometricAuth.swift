// BiometricAuth.swift
// Capa 3 de seguridad — autenticación biométrica (Face ID / Touch ID).

import LocalAuthentication

actor BiometricAuth {

    enum BiometricError: LocalizedError {
        case notAvailable
        case failed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notAvailable: "Autenticación biométrica no disponible en este dispositivo"
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
            default:
                throw BiometricError.failed(laError.localizedDescription)
            }
        }
    }
}
