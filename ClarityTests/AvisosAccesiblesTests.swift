// AvisosAccesiblesTests.swift
// Lo que VoiceOver oye de un aviso y cuánto tiempo tiene para oírlo, y lo que
// la pantalla de bloqueo cuenta cuando la biometría falla.

import Testing
import Foundation
@testable import Clarity

@MainActor
struct AvisosAccesiblesTests {

    // MARK: - Duración del aviso

    @Test("Sin VoiceOver los avisos duran lo de siempre")
    func duracionSinVoiceOver() {
        #expect(FeedbackManager.duracion(.success, conAccion: false, conVoiceOver: false) == .milliseconds(900))
        #expect(FeedbackManager.duracion(.error, conAccion: false, conVoiceOver: false) == .milliseconds(2_200))
        #expect(FeedbackManager.duracion(.success, conAccion: true, conVoiceOver: false) == .seconds(4))
    }

    @Test("Con VoiceOver duran más, y el que trae acción el que más",
          arguments: [FeedbackType.success, .error, .warning, .info], [true, false])
    func duracionConVoiceOver(tipo: FeedbackType, conAccion: Bool) {
        let sin = FeedbackManager.duracion(tipo, conAccion: conAccion, conVoiceOver: false)
        let con = FeedbackManager.duracion(tipo, conAccion: conAccion, conVoiceOver: true)
        #expect(con > sin)
        // Llegar deslizando hasta «Deshacer» lleva más que oír un aviso.
        #expect(FeedbackManager.duracion(tipo, conAccion: true, conVoiceOver: true) >= con)
    }

    // MARK: - Anuncio

    @Test("El anuncio lleva título, detalle y la acción disponible")
    func textoDelAnuncio() {
        #expect(FeedbackManager.textoDelAnuncio(title: "Gasto añadido", message: nil, actionLabel: nil)
                == "Gasto añadido")
        #expect(FeedbackManager.textoDelAnuncio(title: "Gasto añadido", message: "Pan guardado correctamente", actionLabel: nil)
                == "Gasto añadido. Pan guardado correctamente")
        #expect(FeedbackManager.textoDelAnuncio(title: "Gasto eliminado", message: "", actionLabel: "Deshacer")
                == "Gasto eliminado. Acción disponible: Deshacer")
    }

    // MARK: - Pantalla de bloqueo

    @Test("Cancelar no es un fallo: no se dice nada")
    func cancelarNoAvisa() {
        #expect(AppLockManager.mensaje(de: BiometricAuth.BiometricError.cancelled,
                                       biometria: "Face ID", conCodigo: false) == nil)
    }

    @Test("Con la biometría bloqueada o ausente, el aviso manda al código", arguments: [
        BiometricAuth.BiometricError.lockedOut, .notAvailable, .failed("LAError -1"),
    ])
    func falloDeBiometria(error: BiometricAuth.BiometricError) throws {
        let mensaje = try #require(AppLockManager.mensaje(de: error, biometria: "Face ID", conCodigo: false))
        #expect(mensaje.contains("código"))
        // El texto técnico del sistema no llega al usuario.
        #expect(!mensaje.contains("LAError"))
    }

    @Test("Si lo que falla es el código, no se le manda otra vez al código")
    func falloDelCodigo() throws {
        let mensaje = try #require(AppLockManager.mensaje(de: BiometricAuth.BiometricError.failed("x"),
                                                          biometria: "Face ID", conCodigo: true))
        #expect(!mensaje.contains("usa el código"))
    }
}
