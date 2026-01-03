// VoiceExpenseButton.swift
// Floating action button for voice expense entry

import SwiftUI

struct VoiceExpenseButton: View {
    @ObservedObject var viewModel: DashboardViewModel
    @StateObject private var speechManager = SpeechRecognitionManager()
    
    let categories: [Category]
    
    @State private var showRecordingSheet = false
    @State private var showConfirmationSheet = false
    @State private var pendingExpense: Expense?
    @State private var parsedData: ParsedExpense?
    @State private var settings = VoiceSettings.load()
    @State private var stats = VoiceStats.load()
    
    var body: some View {
        Button {
            Task {
                await handleButtonTap()
            }
        } label: {
            ZStack {
                // Glow effect
                Circle()
                    .fill(
                        LinearGradient(
                            colors: speechManager.isListening ? [.red, .pink] : [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .blur(radius: 15)
                    .opacity(0.6)
                
                // Main button
                Circle()
                    .fill(
                        LinearGradient(
                            colors: speechManager.isListening ? [.red, .pink] : [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                
                // Icon
                Image(systemName: speechManager.isListening ? "mic.fill" : "mic")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(speechManager.isListening ? 1.1 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: speechManager.isListening)
        }
        .shadow(color: speechManager.isListening ? .red.opacity(0.5) : .purple.opacity(0.5), radius: 20)
        .sheet(isPresented: $showRecordingSheet) {
            VoiceRecordingSheet(
                speechManager: speechManager,
                isPresented: $showRecordingSheet
            )
            .onDisappear {
                handleRecordingEnd()
            }
        }
        .sheet(isPresented: $showConfirmationSheet) {
            if pendingExpense != nil {
                VoiceConfirmationSheet(
                    expense: $pendingExpense,
                    isPresented: $showConfirmationSheet,
                    categories: categories,
                    wasFullyDetected: parsedData?.confidence ?? 0 > 0.7 && parsedData?.category != nil && parsedData?.subcategory != nil,
                    onConfirm: { confirmed in
                        Task {
                            await addExpense(confirmed)
                        }
                    },
                    onCancel: {
                        pendingExpense = nil
                    }
                )
            }
        }
        .onChange(of: speechManager.isListening) { oldValue, newValue in
            if newValue {
                // Haptic feedback when starting
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
            }
        }
    }
    
    private func handleButtonTap() async {
        if speechManager.isListening {
            // Stop recording
            speechManager.stopRecording()
            showRecordingSheet = false
        } else {
            // Check permissions
            if !speechManager.checkPermissions() {
                let granted = await speechManager.requestPermissions()
                guard granted else {
                    // Show alert
                    return
                }
            }
            
            // Start recording
            do {
                try speechManager.startRecording()
                showRecordingSheet = true
            } catch {
                print("Error starting recording: \(error)")
            }
        }
    }
    
    private func handleRecordingEnd() {
        let fullTranscript = (speechManager.transcript + " " + speechManager.interimTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !fullTranscript.isEmpty else {
            return
        }
        
        // Parse the transcript
        guard let parsed = ExpenseParser.parse(fullTranscript, categories: categories) else {
            // Failed to parse
            stats.recordFailure()
            return
        }
        
        parsedData = parsed
        
        // Create pending expense
        pendingExpense = Expense(
            amount: parsed.amount,
            name: parsed.name,
            category: parsed.category ?? categories.first?.name ?? "Sin categoría",
            subcategory: parsed.subcategory,
            date: Date().toString(format: "yyyy-MM-dd"),
            paymentMethod: "Tarjeta"
        )
        
        // Show confirmation or auto-confirm
        if settings.autoConfirm && parsed.subcategory != nil {
            Task {
                await addExpense(pendingExpense!)
            }
        } else {
            showConfirmationSheet = true
        }
    }
    
    private func addExpense(_ expense: Expense) async {
        do {
            let repository = ExpenseRepository()
            _ = try await repository.addExpense(expense)
            
            // Reload expenses
            await viewModel.loadExpenses()
            
            // Update stats
            stats.recordSuccess()
            
            // Haptic feedback
            if settings.vibration {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
            
            // Reset state
            pendingExpense = nil
            speechManager.transcript = ""
            speechManager.interimTranscript = ""
        } catch {
            print("Error adding expense: \(error)")
            stats.recordFailure()
            
            if settings.vibration {
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.error)
            }
        }
    }
}
