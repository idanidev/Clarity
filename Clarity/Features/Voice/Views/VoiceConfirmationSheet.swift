// VoiceConfirmationSheet.swift
// Expense confirmation with auto-save timer

import Combine
import SwiftUI

struct VoiceConfirmationSheet: View {
    let expense: Expense
    let wasFullyDetected: Bool
    let categories: [Category]
    var speechManager: SpeechRecognitionManager
    let onConfirm: (Expense) -> Void
    let onCancel: () -> Void

    @State private var amount: String = ""
    @State private var name: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedSubcategory: String = ""
    @State private var timeRemaining: Double
    @State private var progress: Double = 1.0
    @Environment(\.dismiss) private var dismiss

    private let autoConfirmDuration: Double

    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    init(
        expense: Expense,
        wasFullyDetected: Bool,
        categories: [Category],
        speechManager: SpeechRecognitionManager,
        onConfirm: @escaping (Expense) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.expense = expense
        self.wasFullyDetected = wasFullyDetected
        self.categories = categories
        self.speechManager = speechManager
        self.onConfirm = onConfirm
        self.onCancel = onCancel

        let settings = VoiceSettings.load()
        let duration = settings.autoConfirmDelay
        self.autoConfirmDuration = duration
        self._timeRemaining = State(initialValue: duration)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Amount
                Section {
                    HStack {
                        Text("€")
                            .foregroundStyle(.secondary)
                            .font(.title)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .onChange(of: amount) { _, _ in stopTimer() }
                    }

                    TextField("Descripción del gasto", text: $name)
                        .onChange(of: name) { _, _ in stopTimer() }
                }

                // Category
                Section("Categoría") {
                    Picker("Categoría", selection: $selectedCategory) {
                        Text("Seleccionar").tag(nil as Category?)
                        ForEach(categories) { category in
                            Text(category.name).tag(category as Category?)
                        }
                    }
                    .onChange(of: selectedCategory) { old, new in
                        stopTimer()
                        if old?.id != new?.id,
                            let newCategory = new,
                            !newCategory.subcategories.contains(selectedSubcategory)
                        {
                            selectedSubcategory = ""
                        }
                    }

                    if let category = selectedCategory {
                        Picker("Subcategoría", selection: $selectedSubcategory) {
                            Text("Ninguna").tag("")
                            ForEach(category.subcategories, id: \.self) { sub in
                                Text(sub).tag(sub)
                            }
                        }
                        .onChange(of: selectedSubcategory) { _, _ in stopTimer() }
                    }
                }
            }
            .navigationTitle("Confirmar Gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onCancel()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        confirmExpense()
                    } label: {
                        HStack(spacing: 6) {
                            if timeRemaining > 0 && canConfirm {
                                CircularProgressView(
                                    progress: progress, timeRemaining: timeRemaining)
                            }
                            Text("Guardar")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(!canConfirm)
                }
            }
        }
        .onAppear {
            amount = String(format: "%.2f", expense.amount)
            name = expense.name

            // Detect category + subcategory exclusively from user's real data
            let parsedSub = expense.subcategory ?? ""
            let normalizedParsedSub = parsedSub.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let normalizedName = name.folding(options: .diacriticInsensitive, locale: .current).lowercased()

            // Search all user categories: first try parser's subcategory hint, then expense name
            outer: for category in categories {
                for sub in category.subcategories {
                    let normalizedSub = sub.folding(options: .diacriticInsensitive, locale: .current).lowercased()
                    if (!normalizedParsedSub.isEmpty && normalizedSub == normalizedParsedSub)
                        || normalizedSub == normalizedName
                    {
                        selectedCategory = category
                        selectedSubcategory = sub
                        break outer
                    }
                }
            }

            // If still nothing, check UserLearning (stores real category/subcategory names the user confirmed)
            if selectedCategory == nil {
                Task {
                    if let learned = await UserLearningManager.shared.getPreference(for: name) {
                        selectedCategory = categories.first { $0.name == learned.category }
                        if let learnedSub = learned.subcategory,
                           let cat = selectedCategory,
                           cat.subcategories.contains(learnedSub) {
                            selectedSubcategory = learnedSub
                        }
                    }
                }
            }
        }
        .onReceive(timer) { _ in
            // Only count down if form is valid
            if timeRemaining > 0 && canConfirm {
                let previousTime = timeRemaining
                timeRemaining -= 0.1
                progress = timeRemaining / autoConfirmDuration

                if previousTime > 1.0 && timeRemaining <= 1.0 {
                    HapticManager.shared.notification(.warning)
                }
            } else if timeRemaining > 0 && !canConfirm {
                // Form is invalid, stop timer
                stopTimer()
            } else if timeRemaining > -1 && timeRemaining <= 0 {
                // Timer reached 0 and form is valid
                confirmExpense()
            }
        }
    }

    private func stopTimer() {
        timeRemaining = -1  // Disable timer
        HapticManager.shared.selection()
    }

    private var canConfirm: Bool {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
            amountValue > 0,
            selectedCategory != nil
        else {
            return false
        }
        return true
    }

    private func confirmExpense() {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
            let category = selectedCategory
        else {
            return
        }

        let confirmed = Expense(
            amount: amountValue,
            name: name.isEmpty ? "Gasto por voz" : name,
            category: category.name,
            subcategory: selectedSubcategory.isEmpty ? nil : selectedSubcategory,
            date: Formatters.isoString(from: Date()),
            paymentMethod: "Tarjeta"
        )

        // 🧠 Reinforcement learning: remember this merchant → category mapping
        Task {
            await UserLearningManager.shared.learn(
                merchant: confirmed.name,
                category: category.name,
                subcategory: selectedSubcategory.isEmpty ? nil : selectedSubcategory
            )
        }

        HapticManager.shared.impact(.medium)
        onConfirm(confirmed)
        dismiss()
    }
}

// Circular progress indicator
struct CircularProgressView: View {
    let progress: Double
    let timeRemaining: Double

    private var timeColor: Color {
        switch timeRemaining {
        case 1.5...: return .green
        case 0.75..<1.5: return .yellow
        default: return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(timeColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.1), value: progress)

            Text("\(Int(ceil(timeRemaining)))")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(timeColor)
        }
        .scaleEffect(timeRemaining <= 1 ? 1.15 : 1.0)
        .animation(.spring(response: 0.3), value: timeRemaining <= 1)
        .frame(width: 40, height: 40)
    }
}
