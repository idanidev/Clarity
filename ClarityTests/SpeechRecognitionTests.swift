// SpeechRecognitionTests.swift
// Estado del reconocimiento de voz y del coordinador que lo usa.
//
// Era la única clase XCTest del bundle, y de ahí salía un aborto intermitente
// del proceso anfitrión: `malloc: pointer being freed was not allocated` dentro
// de `VoiceExpenseCoordinator.__deallocating_deinit`.
//
// La causa no estaba en el coordinador. Con el aislamiento por defecto en
// `MainActor`, toda clase sin `deinit` propio recibe uno aislado, que pasa por
// `swift_task_deinitOnExecutor`. Ese camino aborta si se ejecuta en el hilo
// principal FUERA de una `Task` y con un `TaskLocal` enlazado de forma
// síncrona… que es justo lo que hace XCTest alrededor de cada método de un
// `XCTestCase` (`XCTSwiftErrorObservation` enlaza `$currentErrorTracker`). En el
// test `async` XCTest hacía girar el run loop principal dentro de ese ámbito;
// si en ese rato SwiftUI rehacía `HomeView` —que crea y suelta un coordinador en
// cada `init`—, el deinit caía en la trampa. Por eso «a veces».
//
// Se reprodujo de forma determinista con un método XCTest síncrono que solo
// hacía `_ = VoiceExpenseCoordinator()`. En Swift Testing los tests corren
// dentro de una `Task` y nadie enlaza `TaskLocal` en el hilo principal por
// fuera, así que el mismo gesto es inofensivo: el último test lo deja escrito.

import AVFoundation
import Speech
import Testing

@testable import Clarity

@Suite("Reconocimiento de voz", .serialized)
@MainActor
struct SpeechRecognitionTests {

    private let manager = SpeechRecognitionManager.shared

    @Test("Estado inicial: ni escucha ni arrastra texto")
    func estadoInicial() {
        #expect(!manager.isListening)
        #expect(manager.transcript.isEmpty)
    }

    @Test("checkPermissions exige los dos permisos: voz y micrófono")
    func permisosCoherentes() {
        let esperado =
            SFSpeechRecognizer.authorizationStatus() == .authorized
            && AVAudioApplication.shared.recordPermission == .granted
        #expect(manager.checkPermissions() == esperado)
    }

    @Test("Arrancar y parar seguido deja el gestor sin escuchar")
    func cambiosRapidosDeEstado() async {
        // En el simulador `startRecording` lanza (no hay micro): lo que se
        // comprueba es que el ir y venir no deja el estado a medias.
        try? await manager.startRecording()
        manager.stopRecording()
        #expect(!manager.isListening)

        try? await manager.startRecording()
        manager.stopRecording()
        #expect(!manager.isListening)
    }

    @Test("Crear y soltar coordinadores no tumba el proceso")
    func crearYSoltarCoordinadores() {
        // Lo que hace SwiftUI con el `@State` de `HomeView` en cada `init`.
        for _ in 0..<5 { _ = VoiceExpenseCoordinator() }
        #expect(VoiceExpenseCoordinator().state == .idle)
    }
}
