//
//  SoundManager.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-22.
//

import AVFoundation
import Foundation
import OSLog
import UIKit

/// La sesión de audio del dictado: tomarla para grabar y soltarla al terminar.
///
/// Aquí vivían también los sonidos de inicio, fin, éxito y error, pero la app
/// nunca llevó los ficheros de audio y la alternativa con sonidos del sistema
/// se desactivó por vibrar demasiado: no sonaba nada. El aviso al usuario es
/// háptico (`HapticManager`).
@MainActor
final class SoundManager: NSObject {

    static let shared = SoundManager()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "SoundManager")

    override private init() {
        super.init()
    }

    // MARK: - Session Management

    /// Configures the shared AVAudioSession for 'Pro' audio behavior.
    /// - Set to .playAndRecord to allow simultaneous playback and recording.
    /// - Options: .defaultToSpeaker (loud), .allowBluetooth (AirPods), .duckOthers (polite).
    func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord, mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("✅ Audio Session configured: PlayAndRecord, DefaultToSpeaker, DuckOthers")
        } catch {
            logger.error("❌ Audio Session configuration failed: \(error.localizedDescription)")
        }
    }

    /// Configures the audio session specifically for speech recording.
    /// NO usa .defaultToSpeaker para que los AirPods (y otros Bluetooth) puedan
    /// activar HFP y usar su micrófono correctamente.
    /// Usa .measurement mode para mayor precisión en reconocimiento de voz.
    func configureForRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .measurement,           // mejor para speech recognition
                options: [
                    .allowBluetoothA2DP,      // A2DP (AirPods Pro, etc.)
                    .allowBluetoothHFP,       // HFP mic input
                    .duckOthers,
                    .mixWithOthers            // no interrumpe otras apps
                ]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("✅ Audio Session configured for recording (Bluetooth-compatible, no speaker override)")
        } catch {
            logger.error("❌ Recording session configuration failed: \(error.localizedDescription)")
            // Fallback a la config general
            configureAudioSession()
        }
    }

    /// Suelta la sesión de audio al terminar de grabar.
    ///
    /// Antes la dejaba en `.playAndRecord` con HFP y `duckOthers`, y ACTIVA: tras
    /// el primer dictado unos AirPods se quedaban en HFP (mono, calidad de
    /// llamada) y el audio de las demás apps atenuado mientras Clarity siguiera
    /// abierta. Ahora:
    ///
    /// 1. Se desactiva avisando a las demás, que recuperan volumen y ruta.
    /// 2. Queda puesta una categoría que NO graba ni molesta a nadie
    ///    (`.ambient`): la app no reproduce audio, así que no tiene nada que
    ///    reclamar hasta el siguiente dictado.
    ///
    /// El orden importa: primero soltar (todavía con la categoría de grabación,
    /// que es la que tiene tomada la ruta) y luego cambiar la categoría, que con
    /// la sesión inactiva no mueve nada. Si soltar falla por estar ocupada, el
    /// cambio de categoría se hace igual: al menos deja de pedir micro.
    func restoreAfterRecording() {
        deactivateSession()
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            logger.info("✅ Audio Session released after recording (ambient)")
        } catch {
            logger.error("❌ Failed to restore audio session: \(error.localizedDescription)")
        }
    }

    /// Desactiva la sesión avisando a las demás apps para que reanuden lo suyo.
    func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("❌ Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

}
