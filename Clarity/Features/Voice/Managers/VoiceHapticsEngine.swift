// VoiceHapticsEngine.swift
// Core Haptics Engine for immersive voice feedback patterns
// iOS 26 Elite Edition - Premium tactile experience

import CoreHaptics
import OSLog
import UIKit

/// Advanced haptic feedback engine with custom patterns for voice recording
@MainActor
class VoiceHapticsEngine {
    static let shared = VoiceHapticsEngine()

    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "Haptics")

    private init() {
        setupEngine()
    }

    // MARK: - Setup

    private func setupEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            supportsHaptics = false
            return
        }

        do {
            engine = try CHHapticEngine()
            try engine?.start()
            supportsHaptics = true

            // Handle engine reset (e.g., after interruption)
            engine?.resetHandler = { [weak self] in
                do {
                    try self?.engine?.start()
                } catch {
                    self?.logger.warning("⚠️ Haptic engine reset failed: \(error.localizedDescription)")
                }
            }

            // Handle engine stopped
            engine?.stoppedHandler = { [weak self] reason in
                self?.logger.warning("Haptic engine stopped: \(reason.rawValue)")
            }

        } catch {
            supportsHaptics = false
            logger.warning("Haptic engine creation failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Public Patterns

    /// Sharp click for recording start (0.1s, intensity=0.8)
    func playRecordingStart() {
        guard supportsHaptics else {
            fallbackImpact(.medium)
            return
        }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: 0.1
        )

        playPattern([event])
    }

    /// Subtle pulse for recording end (0.2s, intensity=0.5)
    func playRecordingEnd() {
        guard supportsHaptics else {
            fallbackImpact(.light)
            return
        }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)

        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: 0.2
        )

        playPattern([event])
    }

    /// Crescendo pattern for success (0.1→1.0 over 0.4s)
    func playSuccess() {
        guard supportsHaptics else {
            fallbackNotification(.success)
            return
        }

        var events: [CHHapticEvent] = []
        let steps = 4

        for i in 0..<steps {
            let intensity = 0.1 + (0.9 * Float(i) / Float(steps - 1))
            let time = 0.1 * Double(i)

            let intensityParam = CHHapticEventParameter(
                parameterID: .hapticIntensity, value: intensity)
            let sharpnessParam = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)

            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensityParam, sharpnessParam],
                relativeTime: time
            )

            events.append(event)
        }

        playPattern(events)
    }

    /// Double thud for error (2 clicks, 0.15s gap, intensity=0.9)
    func playError() {
        guard supportsHaptics else {
            fallbackNotification(.error)
            return
        }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)

        let event1 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0
        )

        let event2 = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0.15
        )

        playPattern([event1, event2])
    }

    /// Continuous pulse synced with audio level (for future use)
    func playAudioPulse(level: Float) {
        guard supportsHaptics else { return }

        let clampedLevel = max(0.1, min(1.0, level))
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedLevel)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)

        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [intensity, sharpness],
            relativeTime: 0,
            duration: 0.1
        )

        playPattern([event])
    }

    // MARK: - Private Helpers

    private func playPattern(_ events: [CHHapticEvent]) {
        guard let engine = engine, supportsHaptics else { return }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            logger.warning("⚠️ Haptic pattern play failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Fallbacks (UIKit)

    private func fallbackImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    private func fallbackNotification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}
