// VoiceExpenseCoordinator.swift
// Coordinator for voice expense flow
// Optimized: Unified state, removed redundant showConfirmation

import Foundation
import OSLog
import Observation
import SwiftUI

// MARK: - Unified Voice State (Single Source of Truth)
enum VoiceFlowState: Equatable {
    case idle
    case recording
    case locked  // Recording but hands-free
    case processing
    case confirming  // Data ready, waiting for sheet
    case saving
    case success
    case error(String)
}

@MainActor
@Observable
class VoiceExpenseCoordinator {
    // MARK: - State (SINGLE SOURCE OF TRUTH)
    private(set) var state: VoiceFlowState = .idle
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Clarity", category: "VoiceCoordinator")

    // UI State (derived from state for specific needs)
    var showSuccessToast = false

    var showError: Bool {
        if case .error(_) = state { return true }
        return false
    }

    // Data State
    var pendingExpense: Expense?
    var wasFullyDetected = false

    // Messages
    var errorMessage: String? {
        if case .error(let msg) = state { return msg }
        return nil
    }
    var successMessage = ""

    // Dependencies
    private var stats = VoiceStats.load()
    private var settings = VoiceSettings.load()

    // MARK: - Computed Properties for UI

    var buttonColor: Color {
        switch state {
        case .recording, .locked: return .white
        case .processing: return .orange
        case .success: return .green
        case .error: return .red
        case .idle, .confirming, .saving: return Color.clarityPrimary
        }
    }

    var buttonIcon: String {
        switch state {
        case .idle: return "mic.fill"
        case .recording: return "mic.fill"
        case .locked: return "stop.fill"
        case .processing: return "waveform"
        case .success: return "checkmark"
        case .error: return "exclamationmark.triangle.fill"
        default: return "mic.fill"
        }
    }

    var isRecordingActive: Bool {
        state == .recording || state == .locked
    }

    // MARK: - Actions

    func startRecording(speechManager: SpeechRecognitionManager) {
        guard state == .idle else { return }

        Task {
            if !speechManager.checkPermissions() {
                await MainActor.run {
                    state = .error("Faltan permisos de micrófono")
                }
                return
            }

            // Instant Visual Feedback
            await MainActor.run {
                state = .recording
                // Haptics handled by Button/Engine but we can reinforce here if needed
            }

            do {
                // Audio + Technical Delay (0.2s) happens here
                try await speechManager.startRecording()

                await MainActor.run {
                    if settings.vibration {
                        VoiceHapticsEngine.shared.playRecordingStart()
                    }
                }
            } catch {
                await MainActor.run {
                    state = .error("Error al iniciar: \(error.safeUserMessage)")  // Will revert UI
                    SoundManager.shared.play(.error)
                }
            }
        }
    }

    func lockRecording() {
        guard state == .recording else { return }
        state = .locked
    }

    func cancelRecording(speechManager: SpeechRecognitionManager) {
        guard state == .recording || state == .locked else { return }

        speechManager.stopRecording()
        reset()

        if settings.vibration {
            HapticManager.shared.notification(.error)
        }
    }

    func stopAndFinish(speechManager: SpeechRecognitionManager) {
        guard state == .recording || state == .locked else { return }

        speechManager.stopRecording()
        SoundManager.shared.play(.endRecording)
        if settings.vibration { VoiceHapticsEngine.shared.playRecordingEnd() }

        let text = (speechManager.transcript + " " + speechManager.interimTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        handleTranscript(text, categories: UserDataManager.shared.categories)
    }

    func handleTranscript(_ transcript: String, categories: [Category]) {
        state = .processing

        logger.debug("[Coordinator] Transcript: '\(transcript)'")

        guard !transcript.isEmpty else {
            state = .error("No se detectó ningún gasto. Intenta de nuevo.")
            stats.recordFailure()
            return
        }

        Task {
            // Ultimate Parser: Adaptive Intelligence (History Injection)
            let result = await SmartTransactionParser.shared.parse(
                transcript,
                history: UserDataManager.shared.expenses
            )

            SoundManager.shared.play(.success)
            if settings.vibration { VoiceHapticsEngine.shared.playSuccess() }

            switch result {
            case .success(let parsed):
                logger.debug(
                    "[Coordinator] Parsed: \(parsed.merchant) -> \(parsed.category ?? "nil") via \(parsed.detectionSource.rawValue)"
                )

                let categoryName = parsed.category ?? categories.first?.name ?? "Otros"

                // Decimal -> Double bridge for legacy model
                let amountDouble = NSDecimalNumber(decimal: parsed.amount).doubleValue

                pendingExpense = Expense(
                    amount: amountDouble,
                    name: parsed.merchant,
                    category: categoryName,
                    subcategory: parsed.subcategory,
                    date: Formatters.isoString(from: parsed.date),
                    paymentMethod: parsed.paymentMethod ?? "Tarjeta"
                )

                wasFullyDetected =
                    parsed.confidence >= 0.8 && parsed.category != nil && parsed.subcategory != nil

                state = .confirming

            case .failure(let error):
                // Specific error messages
                SoundManager.shared.play(.error)
                if settings.vibration { VoiceHapticsEngine.shared.playError() }

                state = .error(error.safeUserMessage)
                stats.recordFailure()
            }
        }
    }

    func saveExpense(_ expense: Expense, viewModel: HomeViewModel) async {
        state = .saving

        do {
            let repository = DependencyContainer.shared.expenseRepository
            let id = try await repository.addExpense(expense)

            stats.recordSuccess()
            successMessage = "\(Formatters.currency(expense.amount)) - \(expense.name)"

            // Prepend directly — no blocking reload, expense is already persisted
            var saved = expense
            saved.id = id
            viewModel.prependExpense(saved)

            // Silent background sync (fire-and-forget)
            Task { await viewModel.refresh() }
            NotificationCenter.default.post(name: .expenseDidChange, object: nil)
            NotificationsView.cancelInactivityReminder()

            await MainActor.run {
                state = .success

                withAnimation(.bouncy) {
                    showSuccessToast = true
                }

                if settings.vibration {
                    HapticManager.shared.notification(.success)
                }
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.bouncy) {
                    showSuccessToast = false
                }
                reset()
            }

        } catch {
            stats.recordFailure()
            state = .error("Error al guardar: \(error.safeUserMessage)")

            if settings.vibration {
                HapticManager.shared.notification(.error)
            }
        }
    }

    /// Rellena un gasto directamente desde datos estructurados (ej: Apple Pay via deep link).
    /// No usa el SmartTransactionParser — el comercio y el importe vienen ya parseados.
    func populateFromApplePay(merchant: String, amount: Double) {
        let suggestion = SmartTransactionParser.shared.suggestCategory(for: merchant)
        let categoryName = suggestion?.category ?? UserDataManager.shared.categories.first?.name ?? "Otros"

        pendingExpense = Expense(
            amount: amount,
            name: merchant,
            category: categoryName,
            subcategory: suggestion?.subcategory,
            date: Formatters.isoString(from: Date()),
            paymentMethod: "Tarjeta"
        )

        wasFullyDetected = suggestion != nil
        state = .confirming
    }

    func reset() {
        state = .idle
        pendingExpense = nil
        wasFullyDetected = false
    }

    func clearError() {
        if case .error = state {
            state = .idle
        }
    }
}
