// VoiceExpenseButton.swift
// Floating action button for voice expense entry - using Coordinator pattern

import SwiftUI

struct VoiceExpenseButton: View {
    var viewModel: HomeViewModel
    let categories: [Category]
    
    @StateObject private var speechManager = SpeechRecognitionManager()
    @StateObject private var voiceCoordinator = VoiceExpenseCoordinator()
    
    var body: some View {
        Button {
            voiceCoordinator.handleButtonTap(speechManager: speechManager)
        } label: {
            voiceButtonContent
        }
        .disabled(voiceCoordinator.isProcessing)
        .shadow(color: voiceCoordinator.shadowColor, radius: 20)
        .accessibilityLabel("Grabar gasto por voz")
        .accessibilityHint("Toca para empezar a hablar")
        // Sheets managed by coordinator logic
        .sheet(isPresented: $voiceCoordinator.showRecording) {
            VoiceRecordingSheet(
                speechManager: speechManager,
                onComplete: { transcript in
                    voiceCoordinator.handleTranscript(
                        transcript,
                        categories: categories
                    )
                }
            )
        }
        .sheet(isPresented: $voiceCoordinator.showConfirmation) {
            if let expense = voiceCoordinator.pendingExpense {
                VoiceConfirmationSheet(
                    expense: expense,
                    wasFullyDetected: voiceCoordinator.wasFullyDetected,
                    categories: categories,
                    speechManager: speechManager,
                    onConfirm: { confirmed in
                        Task {
                            await voiceCoordinator.saveExpense(
                                confirmed,
                                viewModel: viewModel
                            )
                        }
                    },
                    onCancel: {
                        voiceCoordinator.reset()
                    }
                )
            }
        }
        .alert("Error de Voz", isPresented: $voiceCoordinator.showError) {
            Button("OK", role: .cancel) {
                voiceCoordinator.clearError()
            }
        } message: {
            Text(voiceCoordinator.errorMessage ?? "Error desconocido")
        }
        .onChange(of: speechManager.didStopDueToSilence) { _, stopped in
            if stopped && voiceCoordinator.showRecording {
                // Manually trigger stop on silence
                let fullTranscript = (speechManager.transcript + " " + speechManager.interimTranscript)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                speechManager.stopRecording()
                voiceCoordinator.showRecording = false
                voiceCoordinator.handleTranscript(fullTranscript, categories: categories)
            }
        }
        .overlay(alignment: .top) {
            if voiceCoordinator.showSuccessToast {
                SuccessToast(message: voiceCoordinator.successMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Button Content
    
    private var voiceButtonContent: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(voiceCoordinator.buttonGradient)
                .frame(width: 70, height: 70)
                .blur(radius: 15)
                .opacity(0.6)
            
            // Main button
            Circle()
                .fill(voiceCoordinator.buttonGradient)
                .frame(width: 60, height: 60)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
            
            // Icon
            Image(systemName: voiceCoordinator.buttonIcon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
            
            // Processing indicator
            if voiceCoordinator.isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
        }
        .scaleEffect(speechManager.isListening ? 1.1 : 1.0)
        .animation(.bouncy(duration: 0.3), value: speechManager.isListening)
    }
}

struct SuccessToast: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10)
        .padding(.horizontal)
        .padding(.top, 60)
    }
}


