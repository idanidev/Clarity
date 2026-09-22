// AppLockManager.swift
// Capa 5 de seguridad — bloqueo automático de la app tras tiempo en background.

import SwiftUI

@MainActor
@Observable
final class AppLockManager {

    var isLocked = false

    var isBiometricEnabled: Bool {
        get { Self.bloqueoActivadoEnLlavero }
        set {
            APIKeychain.set(newValue ? "1" : "0", forKey: Self.claveBloqueo)
            // El resumen semanal oculta los importes con el bloqueo puesto:
            // se rehace al cambiarlo para que el próximo ya salga como toca.
            RecordatoriosService.shared.reprogramarAhora()
        }
    }

    private static let claveBloqueo = "security.biometricLockEnabled"

    /// Lo mismo que `isBiometricEnabled`, sin instancia: lo lee también
    /// `RecordatoriosService`. Ojo, el llavero no se deja leer con el iPhone
    /// bloqueado y entonces esto contesta `false`.
    static var bloqueoActivadoEnLlavero: Bool {
        APIKeychain.get(claveBloqueo) == "1"
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

    /// Lo que la pantalla de bloqueo le cuenta al usuario cuando no se ha podido
    /// desbloquear. `nil` = nada que contar.
    private(set) var mensajeDeFallo: String?
    /// Hay un diálogo del sistema en pantalla: la pantalla de bloqueo pide
    /// autenticación al aparecer y el usuario puede pulsar un botón a la vez.
    @ObservationIgnored private var autenticando = false

    private let motivo = "Desbloquea Clarity para acceder a tus datos"

    /// Con biometría (Face ID / Touch ID).
    func unlock() async {
        await desbloquear { try await self.biometricAuth.authenticate(reason: self.motivo) }
    }

    /// Con el código del dispositivo. Sin esto, con Face ID bloqueado por
    /// intentos —o usando el iPhone desde el Mac— no había forma de entrar.
    func unlockConCodigo() async {
        await desbloquear(conCodigo: true) {
            try await self.biometricAuth.authenticateConCodigo(reason: self.motivo)
        }
    }

    private func desbloquear(conCodigo: Bool = false, _ autenticar: () async throws -> Void) async {
        guard !autenticando else { return }
        autenticando = true
        defer { autenticando = false }

        do {
            try await autenticar()
            mensajeDeFallo = nil
            isLocked = false
        } catch {
            // Sigue bloqueada, pero ya no en silencio: antes el fallo se tragaba
            // y la pantalla se quedaba igual, sin pista de qué hacer.
            mensajeDeFallo = Self.mensaje(de: error, biometria: biometryTypeName, conCodigo: conCodigo)
        }
    }

    /// El aviso para cada fallo. Breve, y siempre con la salida: el código.
    /// Cancelar no es un fallo —lo ha decidido el usuario— y no dice nada.
    static func mensaje(de error: Error, biometria: String, conCodigo: Bool) -> String? {
        guard let fallo = error as? BiometricAuth.BiometricError else {
            return "No se ha podido verificar tu identidad. Inténtalo de nuevo."
        }
        switch fallo {
        case .cancelled:
            return nil
        case .lockedOut:
            return "\(biometria) está bloqueado por demasiados intentos. Usa el código del iPhone."
        case .notAvailable:
            return conCodigo
                ? "Este iPhone no tiene código. Configúralo en Ajustes para desbloquear Clarity."
                : "\(biometria) no está disponible ahora. Usa el código del iPhone."
        case .failed:
            return conCodigo
                ? "No se ha podido verificar tu identidad. Inténtalo de nuevo."
                : "No se ha podido verificar tu identidad. Inténtalo de nuevo o usa el código."
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
