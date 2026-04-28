// AppLockManager.swift
// Capa 5 de seguridad — bloqueo automático de la app tras tiempo en background.

import SwiftUI

@MainActor
@Observable
final class AppLockManager {

    var isLocked = false

    var isBiometricEnabled: Bool {
        get { APIKeychain.get("security.biometricLockEnabled") == "1" }
        set { APIKeychain.set(newValue ? "1" : "0", forKey: "security.biometricLockEnabled") }
    }

    private var backgroundDate: Date?
    /// Tiempo en background antes de bloquear (segundos)
    private let lockTimeout: TimeInterval = 30
    private let biometricAuth = BiometricAuth()

    var isBiometricAvailable: Bool { biometricAuth.isBiometricAvailable }
    var biometryTypeName: String { biometricAuth.biometryTypeName }

    // MARK: - Scene transitions

    func sceneDidEnterBackground() {
        guard isBiometricEnabled else { return }
        backgroundDate = Date()
    }

    func sceneWillEnterForeground() {
        guard isBiometricEnabled, let date = backgroundDate else { return }
        if Date().timeIntervalSince(date) > lockTimeout {
            isLocked = true
        }
        backgroundDate = nil
    }

    // MARK: - Unlock

    func unlock() async {
        do {
            try await biometricAuth.authenticate(reason: "Desbloquea Clarity para acceder a tus datos")
            isLocked = false
        } catch {
            // Permanece bloqueada — no exponer error
        }
    }

    // MARK: - Toggle desde Settings

    /// Devuelve true si el toggle tuvo éxito.
    func toggleBiometric() async -> Bool {
        if isBiometricEnabled {
            isBiometricEnabled = false
            isLocked = false
            return true
        } else {
            do {
                try await biometricAuth.authenticate(
                    reason: "Confirma tu identidad para activar el bloqueo biométrico"
                )
                isBiometricEnabled = true
                return true
            } catch {
                return false
            }
        }
    }
}
