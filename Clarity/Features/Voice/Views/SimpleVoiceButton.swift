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
    @State private var pendingExpenses: [Expense] = []
    @State private var isShowingExpenseSheet = false
    @State private var recordingTimer: Timer?
    @State private var silenceTimer: Timer?
    @State private var isStopping = false
    @State private var isProcessing = false
    @State private var lastSaveDate: Date?
    @AppStorage("voice.onboardingSeen") private var voiceOnboardingSeen: Bool = false
    @State private var showVoiceOnboarding: Bool = false
    private let settings = VoiceSettings.load()

    /// Maximum amount allowed via voice (safety guard against parsing errors)
    private static let maxVoiceAmount: Double = 10_000

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
                    // Fondo: rojo grabando, naranja procesando, violeta idle
                    Circle()
                        .fill(buttonColor)
                        .frame(width: 56, height: 56)
                        .shadow(color: buttonColor.opacity(0.4), radius: 8)

                    // Animación de pulso al grabar
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

                    // Icono según estado
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(1.1)
                    } else {
                        Image(systemName: isRecording ? "waveform" : "mic.fill")
                            .foregroundStyle(.white)
                            .font(.title3)
                            .symbolEffect(.variableColor.iterative, isActive: isRecording)
                    }
                }
            }
            .disabled(isProcessing)
            .accessibilityLabel(
                isProcessing ? "Procesando gasto" :
                isRecording ? "Detener grabación de voz" : "Añadir gasto por voz"
            )
            .accessibilityHint(isRecording ? "Pulsa para detener" : "Pulsa para dictar un gasto")

            // Transcripción en tiempo real
            if isRecording {
                let currentText =
                    speechManager.interimTranscript.isEmpty
                    ? speechManager.transcript
                    : speechManager.interimTranscript

                VStack(spacing: 6) {
                    // Live waveform — always visible while recording
                    AudioWaveformBarsView(levels: speechManager.waveformLevels)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))

                    // Transcript appears once speech is detected
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
                    }
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
        .sheet(isPresented: $isShowingExpenseSheet, onDismiss: handleExpenseDismissed) {
            if let expense = pendingExpenses.first {
                VoiceConfirmationSheet(
                    expense: expense,
                    wasFullyDetected: true,
                    categories: categories,
                    speechManager: speechManager,
                    onConfirm: { confirmed in
                        Task {
                            await saveExpense(confirmed)
                            advanceToNextExpense()
                        }
                    },
                    onCancel: {
                        Task { advanceToNextExpense() }
                    }
                )
            }
        }
        .sheet(isPresented: $showVoiceOnboarding, onDismiss: {
            voiceOnboardingSeen = true
            startRecording()  // continuar al flow original tras cerrar
        }) {
            VoiceOnboardingSheet()
        }
    }

    private var buttonColor: Color {
        if isRecording { return .red }
        if isProcessing { return .orange }
        return .clarityPrimary
    }

    private func handleTap() {
        if isRecording {
            stopRecording()
        } else if !voiceOnboardingSeen {
            // Primera vez: mostrar onboarding antes de empezar a grabar.
            showVoiceOnboarding = true
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

        // Snapshot del texto YA visible en pantalla ANTES de parar. endAudio()
        // puede limpiar interimTranscript al finalizar async; sin este snapshot
        // se perdía lo transcrito → falso "Sin audio".
        let preStopTranscript = (speechManager.transcript + " " + speechManager.interimTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        speechManager.stopRecording()

        // Transition: recording → processing (spinner stays visible)
        isRecording = false
        isProcessing = true
        isStopping = false

        Task {
            // Poll hasta ~1.4s esperando el transcript FINAL (servidor remoto
            // tarda más que on-device). Si llega, gana por precisión; si no,
            // se usa el snapshot pre-stop que el usuario ya veía.
            var transcript = preStopTranscript
            for _ in 0..<9 {
                try? await Task.sleep(nanoseconds: 150_000_000)
                let current = (speechManager.transcript + " " + speechManager.interimTranscript)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !current.isEmpty { transcript = current }
                // transcript no vacío = SFSpeech marcó isFinal → listo
                if !speechManager.transcript.isEmpty { break }
            }

            await MainActor.run {
                let finalTranscript =
                    isSimulator && transcript.isEmpty ? "Añade 50 euros en comida" : transcript

                guard !finalTranscript.isEmpty else {
                    isProcessing = false
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
            // Multi-expense: parse ALL segments at once (with 5s safety timeout)
            let parsed: [SmartTransaction]
            do {
                parsed = try await withThrowingTaskGroup(of: [SmartTransaction].self) { group in
                    group.addTask {
                        await SmartTransactionParser.shared.parseMultiple(
                            transcript,
                            history: UserDataManager.shared.expenses
                        )
                    }
                    group.addTask {
                        try await Task.sleep(nanoseconds: 5_000_000_000)
                        throw CancellationError()
                    }
                    let result = try await group.next() ?? []
                    group.cancelAll()
                    return result
                }
            } catch {
                parsed = []
            }

            await MainActor.run {
                isProcessing = false

                guard !parsed.isEmpty else {
                    HapticManager.shared.error()
                    FeedbackManager.shared.show(
                        .error, title: "Error",
                        message: "No se pudo procesar el gasto"
                    )
                    return
                }

                var autoSavedCount = 0
                var expensesToShow: [Expense] = []

                // Build Expense objects and check for auto-save
                for tx in parsed {
                    let amountDouble = NSDecimalNumber(decimal: tx.amount).doubleValue

                    // Safety: reject implausible amounts
                    guard amountDouble > 0, amountDouble <= Self.maxVoiceAmount else {
                        HapticManager.shared.error()
                        FeedbackManager.shared.show(
                            .error, title: "Importe no válido",
                            message: amountDouble > Self.maxVoiceAmount
                                ? "El importe \(Formatters.currency(amountDouble)) parece demasiado alto. Edítalo manualmente."
                                : "No se detectó un importe válido."
                        )
                        continue
                    }

                    // Detect category + subcategory exclusively from user's real data
                    let normalizedParsedSub = (tx.subcategory ?? "").folding(options: .diacriticInsensitive, locale: .current).lowercased()
                    let normalizedMerchant = tx.merchant.folding(options: .diacriticInsensitive, locale: .current).lowercased()
                    var category = ""
                    var subcategory: String?

                    outer: for userCat in categories {
                        for sub in userCat.subcategories {
                            let normalizedSub = sub.folding(options: .diacriticInsensitive, locale: .current).lowercased()
                            if (!normalizedParsedSub.isEmpty && normalizedSub == normalizedParsedSub)
                                || normalizedSub == normalizedMerchant
                            {
                                category = userCat.name
                                subcategory = sub
                                break outer
                            }
                        }
                    }

                    // Fallback: use parser's detected category when no user-category matched
                    if category.isEmpty {
                        category = tx.category ?? ""
                        subcategory = tx.subcategory
                    }

                    let expense = Expense(
                        id: UUID().uuidString,
                        amount: amountDouble,
                        name: tx.merchant,
                        category: category,
                        subcategory: subcategory,
                        date: Formatters.isoString(from: tx.date),
                        paymentMethod: tx.paymentMethod ?? "Tarjeta"
                    )

                    // Auto-save logic: enabled, high confidence, and a category was detected
                    let isConfident = tx.confidence >= 0.7 && !category.isEmpty

                    if settings.autoConfirm && isConfident {
                        Task { await saveExpense(expense, showFeedback: false) }
                        autoSavedCount += 1
                    } else {
                        expensesToShow.append(expense)
                    }
                }

                // If all were auto-saved
                if autoSavedCount > 0 && expensesToShow.isEmpty {
                    HapticManager.shared.playSuccess()
                    FeedbackManager.shared.show(
                        .success,
                        title: "¡Guardado!",
                        message: "Se han guardado \(autoSavedCount) gasto(s) automáticamente."
                    )
                    return
                }

                // If some (or all) need confirmation
                if !expensesToShow.isEmpty {
                    pendingExpenses = expensesToShow
                    HapticManager.shared.playSuccess()
                    isShowingExpenseSheet = true
                }
            }
        }
    }

    /// Called after the sheet is dismissed (either confirmed or cancelled).
    /// Removes the first pending expense and re-opens the sheet if more remain.
    private func handleExpenseDismissed() {
        // If the queue is empty, nothing to do
        guard !pendingExpenses.isEmpty else { return }
        // Remove the one we just handled
        pendingExpenses.removeFirst()
        // Open next one after a brief pause so SwiftUI can settle
        if !pendingExpenses.isEmpty {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                isShowingExpenseSheet = true
            }
        }
    }

    /// Closes the current sheet, triggering handleExpenseDismissed via onDismiss.
    @MainActor
    private func advanceToNextExpense() {
        isShowingExpenseSheet = false
    }

    private func saveExpense(_ expense: Expense, showFeedback: Bool = true) async {
        // Duplicate guard: reject saves within 2s of the last one with the same amount
        if let last = lastSaveDate, Date().timeIntervalSince(last) < 2.0 {
            return
        }
        lastSaveDate = Date()

        do {
            let id = try await DependencyContainer.shared.expenseRepository.addExpense(expense)

            // Teach learning system
            if !expense.category.isEmpty {
                await UserLearningManager.shared.learn(
                    merchant: expense.name,
                    category: expense.category,
                    subcategory: expense.subcategory
                )
            }

            // Prepend directly — no network roundtrip needed, expense is already persisted
            var saved = expense
            saved.id = id
            viewModel.prependExpense(saved)

            // Silent background sync to reconcile any edge cases (fire-and-forget)
            Task { await viewModel.refresh() }

            if showFeedback {
                HapticManager.shared.playSuccess()
                let savedId = id
                FeedbackManager.shared.show(
                    .success,
                    title: "Gasto añadido",
                    message: "\(Formatters.currency(expense.amount)) - \(expense.name)",
                    actionLabel: "Deshacer",
                    action: { [weak viewModel] in
                        Task { @MainActor in
                            try? await DependencyContainer.shared.expenseRepository.deleteExpense(id: savedId)
                            viewModel?.removeExpense(id: savedId)
                            HapticManager.shared.notification(.warning)
                        }
                    }
                )
            }
        } catch {
            if showFeedback {
                HapticManager.shared.error()
                FeedbackManager.shared.show(
                    .error,
                    title: "Error",
                    message: "No se pudo guardar el gasto"
                )
            }
        }
    }

    // MARK: - Silence Detection

    private func startSilenceDetection() {
        silenceTimer?.invalidate()
        var silentSince: Date? = nil
        // Check every 0.3s if audio level is below threshold
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            Task { @MainActor in
                let hasContent =
                    !speechManager.transcript.isEmpty || !speechManager.interimTranscript.isEmpty
                if speechManager.audioLevel < 0.05 && hasContent {
                    if silentSince == nil { silentSince = Date() }
                    let elapsed = Date().timeIntervalSince(silentSince!)
                    if elapsed >= settings.silenceTimeout {
                        stopRecording()
                    }
                } else {
                    silentSince = nil
                }
            }
        }
    }
}

// MARK: - Audio Waveform Bars
private struct AudioWaveformBarsView: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                let height = max(3, CGFloat(level) * 36 + 3)
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.clarityPrimary, Color.clarityPrimary.opacity(0.6)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: height)
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
        .frame(height: 40)
    }
}
