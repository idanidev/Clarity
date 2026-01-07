// VoiceExpenseButton.swift
// Floating action button for voice expense entry

import SwiftUI

struct VoiceExpenseButton: View {
    var viewModel: DashboardViewModel
    @StateObject private var speechManager = SpeechRecognitionManager()
    
    let categories: [Category]
    
    @State private var showRecordingSheet = false
    @State private var showConfirmationSheet = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var pendingExpense: Expense?
    @State private var parsedData: ParsedExpense?
    @State private var settings = VoiceSettings.load()
    @State private var stats = VoiceStats.load()
    @State private var showSuccessToast = false
    @State private var savedExpenseName = ""
    @State private var isProcessing = false
    
    var body: some View {
        Button {
            guard !isProcessing else { return }
            isProcessing = true
            
            Task {
                await handleButtonTap()
                try? await Task.sleep(nanoseconds: 500_000_000)
                isProcessing = false
            }
        } label: {
            voiceButtonContent
        }
        .shadow(color: speechManager.isListening ? .red.opacity(0.5) : .purple.opacity(0.5), radius: 20)
        .accessibilityLabel("Grabar gasto por voz")
        .accessibilityHint("Toca para empezar a hablar")
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
                    wasFullyDetected: (parsedData?.confidence ?? 0) > 0.7 && 
                                     parsedData?.category != nil && 
                                     parsedData?.subcategory != nil,
                    onConfirm: { confirmed in
                        Task {
                            await addExpense(confirmed)
                        }
                    },
                    onCancel: {
                        pendingExpense = nil
                        parsedData = nil
                    }
                )
            }
        }
        .alert("Error de Voz", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onChange(of: speechManager.isListening) { _, newValue in
            if newValue {
                HapticManager.impact(.medium)
            }
        }
        .onChange(of: speechManager.didStopDueToSilence) { _, stopped in
            if stopped && showRecordingSheet {
                showRecordingSheet = false
                // handleRecordingEnd() will be called via onDisappear
            }
        }
        .overlay(alignment: .top) {
            successToastView
        }
    }
    
    // MARK: - Button Content
    
    private var voiceButtonContent: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(buttonGradient)
                .frame(width: 70, height: 70)
                .blur(radius: 15)
                .opacity(0.6)
            
            // Main button
            Circle()
                .fill(buttonGradient)
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
    
    private var buttonGradient: LinearGradient {
        LinearGradient(
            colors: speechManager.isListening ? [.red, .pink] : [.purple, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Success Toast
    
    @ViewBuilder
    private var successToastView: some View {
        if showSuccessToast {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Gasto guardado")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                    Text(savedExpenseName)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.2), radius: 10)
            .padding(.horizontal)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
            .zIndex(999)
        }
    }
    
    // MARK: - Actions
    
    private func handleButtonTap() async {
        if speechManager.isListening {
            speechManager.stopRecording()
            showRecordingSheet = false
        } else {
            // Check permissions
            if !speechManager.checkPermissions() {
                let granted = await speechManager.requestPermissions()
                guard granted else {
                    await MainActor.run {
                        errorMessage = "Se necesitan permisos de micrófono y reconocimiento de voz. Actívalos en Ajustes."
                        showErrorAlert = true
                    }
                    return
                }
            }
            
            // Start recording with retry
            do {
                try await speechManager.startRecordingWithRetry()
                showRecordingSheet = true
            } catch {
                await MainActor.run {
                    errorMessage = speechManager.lastError?.localizedDescription ?? error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func handleRecordingEnd() {
        let fullTranscript = (speechManager.transcript + " " + speechManager.interimTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !fullTranscript.isEmpty else {
            print("⚠️ Empty transcript")
            return
        }
        
        print("📝 Processing transcript: '\(fullTranscript)'")
        
        // Parse the transcript
        guard let parsed = ExpenseParser.parse(fullTranscript, categories: categories) else {
            stats.recordFailure()
            errorMessage = "No se pudo entender el gasto. Intenta decir algo como '25 en supermercado'."
            showErrorAlert = true
            return
        }
        
        parsedData = parsed
        
        // Create pending expense with proper date format
        pendingExpense = Expense(
            amount: parsed.amount,
            name: parsed.name,
            category: parsed.category ?? categories.first?.name ?? "Sin categoría",
            subcategory: parsed.subcategory,
            date: Formatters.isoString(from: Date()),
            paymentMethod: "Tarjeta"
        )
        
        // Show confirmation or auto-confirm
        if settings.autoConfirm && parsed.subcategory != nil && parsed.confidence > 0.8 {
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
            
            await MainActor.run {
                showConfirmationSheet = false
            }
            
            await viewModel.loadExpenses()
            stats.recordSuccess()
            
            await MainActor.run {
                savedExpenseName = "\(Formatters.currency(expense.amount)) - \(expense.name)"
                withAnimation(.bouncy(duration: 0.4)) {
                    showSuccessToast = true
                }
            }
            
            // Auto-hide toast
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            await MainActor.run {
                withAnimation(.bouncy(duration: 0.4)) {
                    showSuccessToast = false
                }
            }
            
            if settings.vibration {
                HapticManager.notification(.success)
            }
            
            await MainActor.run {
                pendingExpense = nil
                parsedData = nil
                speechManager.transcript = ""
                speechManager.interimTranscript = ""
            }
        } catch {
            print("❌ Error adding expense: \(error)")
            stats.recordFailure()
            
            await MainActor.run {
                errorMessage = "Error al guardar el gasto. Inténtalo de nuevo."
                showErrorAlert = true
            }
            
            if settings.vibration {
                HapticManager.notification(.error)
            }
        }
    }
}

