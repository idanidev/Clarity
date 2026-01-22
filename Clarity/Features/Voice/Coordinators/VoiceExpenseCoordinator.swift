// VoiceExpenseCoordinator.swift
// Coordinator for voice expense flow
// Optimized: Unified state, removed redundant showConfirmation

import Foundation
import SwiftUI
import Observation

// MARK: - Unified Voice State (Single Source of Truth)
enum VoiceFlowState: Equatable {
    case idle
    case recording
    case locked        // Recording but hands-free
    case processing
    case confirming    // Data ready, waiting for sheet
    case saving
    case success
    case error(String)
}

@MainActor
@Observable
class VoiceExpenseCoordinator {
    // MARK: - State (SINGLE SOURCE OF TRUTH)
    private(set) var state: VoiceFlowState = .idle
    
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
                        VoiceHapticsEngine.shared.play(.recordingStart)
                    }
                }
            } catch {
                await MainActor.run {
                    state = .error("Error al iniciar: \(error.localizedDescription)") // Will revert UI
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
        if settings.vibration { VoiceHapticsEngine.shared.play(.recordingEnd) }
        
        let text = (speechManager.transcript + " " + speechManager.interimTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        handleTranscript(text, categories: UserDataManager.shared.categories)
    }
    
    func handleTranscript(_ transcript: String, categories: [Category]) {
        state = .processing
        
        print("📝 Transcript: '\(transcript)'")
        
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
            if settings.vibration { VoiceHapticsEngine.shared.play(.success) }
            
            switch result {
            case .success(let parsed):
                print("✅ [Adaptive] Result: \(parsed.merchant) -> \(parsed.category ?? "nil") (Source: \(parsed.detectionSource.rawValue))")
                
                let categoryName = parsed.category ?? categories.first?.name ?? "Otros"
                
                // Decimal -> Double bridge for legacy model
                let amountDouble = NSDecimalNumber(decimal: parsed.amount).doubleValue
                
                pendingExpense = Expense(
                    amount: amountDouble,
                    name: parsed.merchant,
                    category: categoryName,
                    subcategory: parsed.subcategory,
                    date: Formatters.isoString(from: parsed.date),
                    paymentMethod: "Tarjeta"
                )
                
                wasFullyDetected = parsed.confidence >= 0.8 &&
                                  parsed.category != nil &&
                                  parsed.subcategory != nil
                
                wasFullyDetected = parsed.confidence >= 0.8 &&
                                  parsed.category != nil &&
                                  parsed.subcategory != nil
                
                // Note: Learning is now Implicit via History. We don't need explicit 'learn' call.
                
                state = .confirming
                
            case .failure(let error):
                // Specific error messages
                SoundManager.shared.play(.error)
                if settings.vibration { VoiceHapticsEngine.shared.play(.error) }
                
                state = .error(error.localizedDescription)
                stats.recordFailure()
            }
        }
    }
    
    func saveExpense(_ expense: Expense, viewModel: HomeViewModel) async {
        state = .saving
        
        do {
            let repository = DependencyContainer.shared.expenseRepository
            _ = try await repository.addExpense(expense)
            
            stats.recordSuccess()
            successMessage = "\(Formatters.currency(expense.amount)) - \(expense.name)"
            
            await MainActor.run {
                state = .success
                
                withAnimation(.bouncy) {
                    showSuccessToast = true
                }
                
                if settings.vibration {
                    HapticManager.shared.notification(.success)
                }
            }
            
            await viewModel.loadExpenses(silent: true)
            
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.bouncy) {
                    showSuccessToast = false
                }
                reset()
            }
            
        } catch {
            stats.recordFailure()
            state = .error("Error al guardar: \(error.localizedDescription)")
            
            if settings.vibration {
                HapticManager.shared.notification(.error)
            }
        }
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
