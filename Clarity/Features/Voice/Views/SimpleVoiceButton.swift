//
//  SimpleVoiceButton.swift
//  Clarity
//
//  Simplified voice recording button with tap-to-record/tap-to-stop
//

import SwiftUI

struct SimpleVoiceButton: View {
    var viewModel: HomeViewModel
    let categories: [Category]

    @State private var speechManager = SpeechRecognitionManager.shared
    @State private var isRecording = false
    @State private var parsedExpense: Expense?
    @State private var recordingTimer: Timer?
    @State private var silenceTimer: Timer?
    @State private var isStopping = false
    @State private var isProcessing = false
    private let settings = VoiceSettings.load()

    // Debug mode for simulator (speech recognition doesn't work in simulator)
    #if targetEnvironment(simulator)
        private let isSimulator = true
    #else
        private let isSimulator = false
    #endif

    var body: some View {
        VStack(spacing: 8) {
            // Botón más pequeño y limpio
            Button {
                handleTap()
            } label: {
                ZStack {
                    // Fondo simple sin visualizador canvas horrible
                    Circle()
                        .fill(isRecording ? Color.red : Color.clarityPrimary)
                        .frame(width: 56, height: 56)
                        .shadow(
                            color: isRecording ? .red.opacity(0.4) : .black.opacity(0.2), radius: 8)

                    // Animación de pulso sutil
                    if isRecording {
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 2)
                            .frame(width: 56, height: 56)
                            .scaleEffect(1.3)
                            .opacity(0.5)
                            .animation(
                                .easeInOut(duration: 1).repeatForever(autoreverses: true),
                                value: isRecording)
                    }

                    // Icono
                    Image(systemName: isRecording ? "waveform" : "mic.fill")
                        .foregroundStyle(.white)
                        .font(.title3)
                        .symbolEffect(.variableColor.iterative, isActive: isRecording)
                }
            }

            // Transcripción en tiempo real
            if isRecording {
                let currentText =
                    speechManager.interimTranscript.isEmpty
                    ? speechManager.transcript
                    : speechManager.interimTranscript

                if !currentText.isEmpty {
                    Text(currentText)
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Escuchando...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            } else if isProcessing {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Procesando...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.3), value: isRecording)
        .animation(.spring(response: 0.3), value: isProcessing)
        .animation(.spring(response: 0.3), value: speechManager.interimTranscript)
        .sheet(item: $parsedExpense) { expense in
            VoiceConfirmationSheet(
                expense: expense,
                wasFullyDetected: true,
                categories: categories,
                speechManager: speechManager,
                onConfirm: { confirmed in
                    Task {
                        await saveExpense(confirmed)
                        parsedExpense = nil
                    }
                },
                onCancel: {
                    parsedExpense = nil
                }
            )
        }
    }

    private func handleTap() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        Task {
            do {
                if !speechManager.checkPermissions() {
                    try await speechManager.requestPermissions()
                }

                try await speechManager.startRecording()
                await MainActor.run {
                    isRecording = true
                    HapticManager.shared.impact(.light)

                    // Max recording time based on user settings (safety cap)
                    recordingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) {
                        _ in
                        if isRecording {
                            stopRecording()
                        }
                    }

                    // Silence-based auto-stop using user's configured timeout
                    startSilenceDetection()
                }
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                }
            }
        }
    }

    private func stopRecording() {
        guard !isStopping else { return }
        isStopping = true

        recordingTimer?.invalidate()
        recordingTimer = nil
        silenceTimer?.invalidate()
        silenceTimer = nil

        // Vibración suave al detener
        HapticManager.shared.impact(.light)

        speechManager.stopRecording()
        isProcessing = true

        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)

            await MainActor.run {
                isRecording = false
                isStopping = false
                isProcessing = false

                let transcript = (speechManager.transcript + " " + speechManager.interimTranscript)
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let finalTranscript =
                    isSimulator && transcript.isEmpty ? "Añade 50 euros en comida" : transcript

                guard !finalTranscript.isEmpty else {
                    HapticManager.shared.error()
                    FeedbackManager.shared.show(
                        .error,
                        title: "Sin audio",
                        message: "No se detectó ningún audio. Intenta de nuevo."
                    )
                    return
                }

                processTranscript(finalTranscript)
            }
        }
    }

    private func processTranscript(_ transcript: String) {
        Task {
            let result = await SmartTransactionParser.shared.parse(
                transcript,
                history: UserDataManager.shared.expenses
            )

            await MainActor.run {
                switch result {
                case .success(let parsed):
                    let categoryName = parsed.category  // nil = user must pick in sheet
                    parsedExpense = Expense(
                        id: UUID().uuidString,
                        amount: NSDecimalNumber(decimal: parsed.amount).doubleValue,
                        name: parsed.merchant,
                        category: categoryName ?? "",
                        subcategory: parsed.subcategory,
                        date: Formatters.isoString(from: parsed.date),
                        paymentMethod: parsed.paymentMethod ?? "Tarjeta"
                    )
                    HapticManager.shared.playSuccess()

                case .failure:
                    HapticManager.shared.error()
                    FeedbackManager.shared.show(
                        .error,
                        title: "Error",
                        message: "No se pudo procesar el gasto"
                    )
                }
            }
        }
    }

    private func saveExpense(_ expense: Expense) async {
        do {
            _ = try await DependencyContainer.shared.expenseRepository.addExpense(expense)
            await viewModel.refresh()
            HapticManager.shared.playSuccess()
            FeedbackManager.shared.show(
                .success,
                title: "Gasto añadido",
                message: nil
            )
        } catch {
            HapticManager.shared.error()
            FeedbackManager.shared.show(
                .error,
                title: "Error",
                message: "No se pudo guardar el gasto"
            )
        }
    }

    // MARK: - Silence Detection

    private func startSilenceDetection() {
        silenceTimer?.invalidate()
        var silentSince: Date? = nil
        // Check every 0.3s if audio level is below threshold
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [self] _ in
            let hasContent =
                !speechManager.transcript.isEmpty || !speechManager.interimTranscript.isEmpty
            if speechManager.audioLevel < 0.05 && hasContent {
                if silentSince == nil { silentSince = Date() }
                let elapsed = Date().timeIntervalSince(silentSince!)
                if elapsed >= settings.silenceTimeout {
                    stopRecording()
                }
            } else {
                silentSince = nil  // Reset when speaking
            }
        }
    }
}
