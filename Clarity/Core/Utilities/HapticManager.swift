import CoreHaptics
// HapticManager.swift
// Sistema avanzado de hápticos con Core Haptics y patrones personalizados
import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    typealias NotificationType = UINotificationFeedbackGenerator.FeedbackType

    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false

    private init() {
        setupEngine()
    }

    // MARK: - Public API (Pro)

    func prepare() {
        // Pre-warm generators
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.prepare()

        let notification = UINotificationFeedbackGenerator()
        notification.prepare()

        let selection = UISelectionFeedbackGenerator()
        selection.prepare()

        // Ensure Core Haptics engine is running
        try? engine?.start()
    }

    func playSoftImpact() {
        // "Mechanical Click" - High precision, low intensity
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.25)
    }

    func playSlideTick() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    func playSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
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

            // Restart engine if needed
            engine?.stoppedHandler = { [weak self] reason in
                Task { @MainActor in
                    try? self?.engine?.start()
                }
            }

            engine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.engine?.start()
                }
            }
        } catch {
            supportsHaptics = false
        }
    }

    // MARK: - Standard Haptics

    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: - Custom Patterns

    func playCustomPattern(_ pattern: HapticPattern) {
        guard supportsHaptics, let engine = engine else {
            fallbackHaptic(for: pattern)
            return
        }

        do {
            let player = try engine.makePlayer(with: pattern.events())
            try player.start(atTime: 0)
        } catch {
            fallbackHaptic(for: pattern)
        }
    }

    private func fallbackHaptic(for pattern: HapticPattern) {
        switch pattern {
        case .expenseAdded, .expenseDeleted, .expenseDuplicated:
            impact(.medium)
        case .expenseEdited:
            impact(.light)
        case .swipeAction:
            selection()
        case .buttonPress:
            impact(.light)
        case .longPress:
            impact(.medium)
        case .dataRefresh:
            impact(.light)
        case .voiceRecognition:
            impact(.light)
        case .voiceSuccess:
            notification(.success)
        case .voiceError:
            notification(.error)
        case .filterApplied:
            selection()
        case .tabSwitch:
            selection()
        }
    }

    // MARK: - Contextual Helpers

    func success() {
        notification(.success)
    }

    func error() {
        notification(.error)
    }

    func warning() {
        notification(.warning)
    }

    func lightTap() {
        impact(.light)
    }

    func mediumTap() {
        impact(.medium)
    }

    func playImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        impact(style)
    }

    func heavyTap() {
        impact(.heavy)
    }

    // MARK: - App-Specific Patterns

    func expenseAdded() {
        playCustomPattern(.expenseAdded)
    }

    func expenseDeleted() {
        playCustomPattern(.expenseDeleted)
    }

    func expenseEdited() {
        playCustomPattern(.expenseEdited)
    }

    func expenseDuplicated() {
        playCustomPattern(.expenseDuplicated)
    }

    func swipeAction() {
        playCustomPattern(.swipeAction)
    }

    func buttonPress() {
        playCustomPattern(.buttonPress)
    }

    func longPress() {
        playCustomPattern(.longPress)
    }

    func dataRefresh() {
        playCustomPattern(.dataRefresh)
    }

    func voiceRecognition() {
        playCustomPattern(.voiceRecognition)
    }

    func voiceSuccess() {
        playCustomPattern(.voiceSuccess)
    }

    func voiceError() {
        playCustomPattern(.voiceError)
    }

    func filterApplied() {
        playCustomPattern(.filterApplied)
    }

    func tabSwitch() {
        playCustomPattern(.tabSwitch)
    }
}

// MARK: - Haptic Patterns

enum HapticPattern {
    case expenseAdded
    case expenseDeleted
    case expenseEdited
    case expenseDuplicated
    case swipeAction
    case buttonPress
    case longPress
    case dataRefresh
    case voiceRecognition
    case voiceSuccess
    case voiceError
    case filterApplied
    case tabSwitch

    func events() -> CHHapticPattern {
        let events: [CHHapticEvent]

        switch self {
        case .expenseAdded:
            // Quick double tap - success feeling
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                    ], relativeTime: 0),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
                    ], relativeTime: 0.08),
            ]

        case .expenseDeleted:
            // Strong single thud - deletion feeling
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                    ], relativeTime: 0)
            ]

        case .expenseEdited:
            // Gentle tap - subtle feedback
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                    ], relativeTime: 0)
            ]

        case .expenseDuplicated:
            // Triple tap - copy feeling
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
                    ], relativeTime: 0),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                    ], relativeTime: 0.06),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8),
                    ], relativeTime: 0.12),
            ]

        case .swipeAction:
            // Light click - interaction feedback
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                    ], relativeTime: 0)
            ]

        case .buttonPress:
            // Crisp tap - button press
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
                    ], relativeTime: 0)
            ]

        case .longPress:
            // Continuous buzz - long press acknowledged
            events = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                    ], relativeTime: 0, duration: 0.15)
            ]

        case .dataRefresh:
            // Quick pulse - refresh feedback
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4),
                    ], relativeTime: 0)
            ]

        case .voiceRecognition:
            // Gentle pulse - listening
            events = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                    ], relativeTime: 0, duration: 0.1)
            ]

        case .voiceSuccess:
            // Success pattern - recognized
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
                    ], relativeTime: 0),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7),
                    ], relativeTime: 0.1),
            ]

        case .voiceError:
            // Error pattern - recognition failed
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
                    ], relativeTime: 0)
            ]

        case .filterApplied:
            // Selection feedback
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                    ], relativeTime: 0)
            ]

        case .tabSwitch:
            // Tab change feedback
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.4),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5),
                    ], relativeTime: 0)
            ]
        }

        return try! CHHapticPattern(events: events, parameters: [])
    }
}
