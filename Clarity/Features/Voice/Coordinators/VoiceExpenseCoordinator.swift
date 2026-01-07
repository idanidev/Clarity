// VoiceExpenseCoordinator.swift
// Coordinator for voice expense flow

import Foundation
import SwiftUI
import Combine

@MainActor
class VoiceExpenseCoordinator: ObservableObject {
    // UI State
    @Published var showRecording = false
    @Published var showConfirmation = false
    @Published var showSuccessToast = false
    @Published var showError = false
    
    // Data State
    @Published var pendingExpense: Expense?
    @Published var wasFullyDetected = false
    @Published var isProcessing = false
    
    // Messages
    @Published var errorMessage: String?
    @Published var successMessage = ""
    
    // Dependencies
    private var stats = VoiceStats.load()
    private var settings = VoiceSettings.load()
    
    enum State {
        case idle
        case requesting
        case recording
        case processing
        case confirming
        case saving
        case success
        case error(String)
    }
    
    @Published private(set) var state: State = .idle
    
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
    
    func handleButtonTap(speechManager: SpeechRecognitionManager) {
        guard !isProcessing else { return }
        
        if speechManager.isListening {
            // Stop recording
            speechManager.stopRecording()
            showRecording = false
            state = .idle
        } else {
            // Start recording
            Task {
                await startRecording(speechManager: speechManager)
            }
        }
    }
    
    private func startRecording(speechManager: SpeechRecognitionManager) async {
        isProcessing = true
        state = .requesting
        
        // Check permissions
        if !speechManager.checkPermissions() {
            let granted = await speechManager.requestPermissions()
            guard granted else {
                errorMessage = "Se necesitan permisos de micrófono y reconocimiento de voz"
                showError = true
                isProcessing = false
                state = .idle
                return
            }
        }
        
        // Start recording
        do {
            try speechManager.startRecording()
            state = .recording
            showRecording = true
            if settings.vibration {
                HapticManager.impact(.medium)
            }
        } catch {
            errorMessage = "No se pudo iniciar la grabación: \(error.localizedDescription)"
            showError = true
            state = .idle
        }
        
        isProcessing = false
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
    
    func saveExpense(_ expense: Expense, viewModel: DashboardViewModel) async {
        state = .saving
        
        do {
            let repository = ExpenseRepository()
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
                    HapticManager.notification(.success)
                }
            }
            
            // Reload expenses
            await viewModel.loadExpenses()
            
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
                HapticManager.notification(.error)
            }
            
            reset()
        }
    }
    
    func reset() {
        state = .idle
        pendingExpense = nil
        wasFullyDetected = false
        isProcessing = false
    }
    
    func clearError() {
        showError = false
        errorMessage = nil
    }
}
