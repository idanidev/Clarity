// VoiceExpenseCoordinator.swift
// Coordinator for voice expense flow

import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
class VoiceExpenseCoordinator {
    // UI State
    var showRecording = false
    var showConfirmation = false
    var showSuccessToast = false
    var showError = false
    
    // Data State
    var pendingExpense: Expense?
    var wasFullyDetected = false
    var isProcessing = false
    
    // Messages
    var errorMessage: String?
    var successMessage = ""
    
    // Dependencies
    private var stats = VoiceStats.load()
    private var settings = VoiceSettings.load()
    
    enum State: Equatable {
        case idle
        case requesting
        case recording
        case processing
        case confirming
        case saving
        case success
        case error(String)
    }
    
    private(set) var state: State = .idle
    
    // MARK: - Computed Properties for UI
    
    var buttonGradient: LinearGradient {
        switch state {
        case .recording:
            return LinearGradient(
                colors: [.red, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .processing:
            return LinearGradient(
                colors: [.orange, .yellow],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [.purple, .blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    var buttonIcon: String {
        switch state {
        case .recording: return "mic.fill"
        case .processing: return "waveform"
        default: return "mic"
        }
    }
    
    var shadowColor: Color {
        switch state {
        case .recording: return .red.opacity(0.5)
        case .processing: return .orange.opacity(0.5)
        default: return .purple.opacity(0.5)
        }
    }
    
    // MARK: - Actions
    
    // MARK: - Actions (New Inline Logic)
    
    /// Starts recording immediately (called on Hold/Tap)
    func startRecording(speechManager: SpeechRecognitionManager) {
        guard !isProcessing, state == .idle else { return }
        
        Task {
            // Check permissions silently (assumed handled by onboarding, but safety check)
            if !speechManager.checkPermissions() {
                // Determine if we should request? For now, if no permission, show error
                await MainActor.run {
                    errorMessage = "Faltan permisos de micrófono"
                    showError = true
                }
                return
            }
            
            do {
                try speechManager.startRecording()
                await MainActor.run {
                    state = .recording
                    showRecording = true // Used for UI visibility if needed, or remove if fully inline
                    if settings.vibration {
                        HapticManager.shared.impact(.medium)
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Error al iniciar: \(error.localizedDescription)"
                    showError = true
                    state = .idle
                }
            }
        }
    }
    
    /// Cancels current recording (called on Slide Left)
    func cancelRecording(speechManager: SpeechRecognitionManager) {
        guard state == .recording || state == .processing else { return }
        
        speechManager.stopRecording()
        reset()
        
        if settings.vibration {
            HapticManager.shared.notification(.error)
        }
    }
    
    /// Stops recording and processes the result (called on Release)
    func stopAndFinish(speechManager: SpeechRecognitionManager) {
        guard state == .recording else { return }
        
        // Manual stop logic
        // Get transcript before stop (or from manager buffer)
        // SpeechManager usually updates `transcript` property
        
        // We let the manager know we want to stop
        speechManager.stopRecording()
        
        // Trigger processing processing
        let text = (speechManager.transcript + " " + speechManager.interimTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        handleTranscript(text, categories: UserDataManager.shared.categories)
    }

    /// Transitions to locked state (Hands-free)
    func lockRecording() {
        // Just state update if needed, mostly UI handled
        // Could ensure coordinator knows we are locked 
    }
    
    func handleTranscript(_ transcript: String, categories: [Category]) {
        state = .processing
        
        print("📝 Transcript: '\(transcript)'")
        
        guard !transcript.isEmpty else {
            errorMessage = "No se detectó ningún gasto. Intenta de nuevo."
            showError = true
            stats.recordFailure()
            reset()
            return
        }
        
        // Parse
        guard let parsed = ExpenseParser.parse(transcript, categories: categories) else {
            errorMessage = "No se pudo entender el gasto. Intenta ser más específico (ej: '25 en supermercado')"
            showError = true
            stats.recordFailure()
            reset()
            return
        }
        
        print("✅ Parsed: amount=\(parsed.amount), category=\(parsed.category ?? "nil"), confidence=\(parsed.confidence)")
        
        // Create pending expense
        let categoryName = parsed.category ?? categories.first?.name ?? "Otros"
        
        pendingExpense = Expense(
            amount: parsed.amount,
            name: parsed.name,
            category: categoryName,
            subcategory: parsed.subcategory,
            date: Formatters.isoString(from: Date()),
            paymentMethod: "Tarjeta"
        )
        
        wasFullyDetected = parsed.confidence >= 0.8 && 
                          parsed.category != nil && 
                          parsed.subcategory != nil
        
        state = .confirming
        showConfirmation = true
    }
    
    func saveExpense(_ expense: Expense, viewModel: HomeViewModel) async {
        state = .saving
        
        do {
            let repository = DependencyContainer.shared.expenseRepository
            _ = try await repository.addExpense(expense)
            
            // Success!
            stats.recordSuccess()
            successMessage = "\(Formatters.currency(expense.amount)) - \(expense.name)"
            
            await MainActor.run {
                showConfirmation = false
                state = .success
                
                withAnimation(.bouncy) {
                    showSuccessToast = true
                }
                
                if settings.vibration {
                    HapticManager.shared.notification(.success)
                }
            }
            
            // Reload expenses
            await viewModel.loadExpenses(silent: true)
            
            // Auto-hide toast
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.bouncy) {
                    showSuccessToast = false
                }
                reset()
            }
            
        } catch {
            stats.recordFailure()
            errorMessage = "Error al guardar: \(error.localizedDescription)"
            showError = true
            
            if settings.vibration {
                HapticManager.shared.notification(.error)
            }
            
            reset()
        }
    }
    
    func reset() {
            // Reset
            state = .idle
            pendingExpense = nil
            wasFullyDetected = false
            isProcessing = false
            showRecording = false
            showConfirmation = false
    }
    
    func clearError() {
        showError = false
        errorMessage = nil
    }
}
