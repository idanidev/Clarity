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
    @State private var showSuccessToast = false
    @State private var savedExpenseName = ""
    @State private var isProcessing = false // Debounce state
    
    var body: some View {
        Button {
            guard !isProcessing else { return }
            isProcessing = true
            
            Task {
                await handleButtonTap()
                // 0.5s debounce to prevent double taps
                try? await Task.sleep(nanoseconds: 500_000_000)
                isProcessing = false
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
            .animation(.bouncy(duration: 0.3), value: speechManager.isListening)
        }
        .shadow(color: speechManager.isListening ? .red.opacity(0.5) : .purple.opacity(0.5), radius: 20)
        .accessibilityLabel("Grabar gasto por voz")
        .accessibilityHint("Mantén presionado para hablar")
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
        .overlay(alignment: .top) {
            // Success toast
            if showSuccessToast {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Gasto guardado")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text(savedExpenseName)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.9))
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 10)
                    )
                    .padding(.horizontal)
                    .padding(.top, 60)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
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
        if settings.autoConfirm && parsed.subcategory != nil && parsed.confidence > 0.8 {
            // High confidence: auto-confirm directly
            Task {
                await addExpense(pendingExpense!)
            }
        } else {
            // Show confirmation sheet
            showConfirmationSheet = true
        }
    }
    
    private func addExpense(_ expense: Expense) async {
        do {
            let repository = ExpenseRepository()
            _ = try await repository.addExpense(expense)
            
            // Close confirmation sheet immediately
            await MainActor.run {
                showConfirmationSheet = false
            }
            
            // Reload expenses
            await viewModel.loadExpenses()
            
            // Update stats
            stats.recordSuccess()
            
            // Show success toast
            await MainActor.run {
                savedExpenseName = "\(String(format: "%.2f", expense.amount))€ - \(expense.name)"
                withAnimation(.bouncy(duration: 0.4)) {
                    showSuccessToast = true
                }
            }
            
            // Auto-hide toast after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.bouncy(duration: 0.4)) {
                    showSuccessToast = false
                }
            }
            
            // Haptic feedback
            if settings.vibration {
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.success)
                }
            }
            
            // Reset state
            await MainActor.run {
                pendingExpense = nil
                speechManager.transcript = ""
                speechManager.interimTranscript = ""
            }
        } catch {
            print("Error adding expense: \(error)")
            stats.recordFailure()
            
            if settings.vibration {
                await MainActor.run {
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.error)
                }
            }
        }
    }
}
