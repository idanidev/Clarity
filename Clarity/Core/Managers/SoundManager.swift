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

/// Pro-Audio Manager implementing robust playback and session management.
/// Ensures audio plays even in silent mode and handles session lifecycles correctly.
@MainActor
final class SoundManager: NSObject {

    static let shared = SoundManager()

    // MARK: - Configuration

    enum SoundEffect: String {
        case startRecording = "start_record"
        case endRecording = "end_record"
        case success = "success"
        case error = "error"

        // System Sound IDs as fallback
        var systemSoundID: SystemSoundID {
            switch self {
            case .startRecording: return 1104  // Tock
            case .endRecording: return 1105  // Tock (High)
            case .success: return 1001  // Mail Sent (placeholder)
            case .error: return 1002  // Mail Received (placeholder)
            }
        }
    }

    private var players: [SoundEffect: AVAudioPlayer] = [:]
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "SoundManager")

    override private init() {
        super.init()
        preloadSounds()
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

    /// Restaura la sesión de audio a la config normal tras una grabación.
    func restoreAfterRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord, mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("✅ Audio Session restored to playback mode")
        } catch {
            logger.error("❌ Failed to restore audio session: \(error.localizedDescription)")
        }
    }

    /// Deactivates the session (optional, usually left active or managed by SpeechManager)
    func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(
                false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("❌ Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Playback

    /// Plays a sound effect with robust fallback and silent mode override.
    /// - Parameter effect: The specific sound cue to play.
    func play(_ effect: SoundEffect) {
        // 1. Ensure Session is Active (Crucial for silent mode override)
        // We do not force configure here to avoid overriding specific SpeechManager settings,
        // but we ensure category is correct if strictly playing.
        // In the context of VoiceExpenseButton, SpeechManager handles the session activation usually.

        // 2. Try AVAudioPlayer (File-based)
        if let player = players[effect] {
            logger.info("🔊 Playing \(effect.rawValue) via AVAudioPlayer")
            if player.isPlaying { player.stop() }
            player.currentTime = 0
            player.play()
        } else {
            // 3. Fallback: Log only (To prevent unwanted system vibrations)
            // User feedback indicated SystemID 1104 was too strong.
            // We rely on HapticManager for tactile feedback.
            logger.warning(
                "⚠️ File not found for \(effect.rawValue). Skipping fallback to avoid vibration conflict."
            )
            // AudioServicesPlaySystemSound(effect.systemSoundID)
        }
    }

    // MARK: - Setup

    private func preloadSounds() {
        for effect in [SoundEffect.startRecording, .endRecording, .success, .error] {
            guard
                let url = Bundle.main.url(forResource: effect.rawValue, withExtension: "m4a")
                    ?? Bundle.main.url(forResource: effect.rawValue, withExtension: "wav")
                    ?? Bundle.main.url(forResource: effect.rawValue, withExtension: "mp3")
            else {
                logger.warning("⚠️ Sound file not found: \(effect.rawValue) (Will use fallback)")
                continue
            }

            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[effect] = player
                logger.debug("✅ Preloaded sound: \(effect.rawValue)")
            } catch {
                logger.error(
                    "❌ Failed to load sound \(effect.rawValue): \(error.localizedDescription)")
            }
        }
    }
}
