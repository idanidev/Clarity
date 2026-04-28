// VoiceConfirmationSheet.swift
// Expense confirmation with auto-save timer

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
    @State private var countdownCancelled = false
    @State private var isInitialized = false  // guards against onAppear-triggered onChange
    @State private var showNewCategory = false
    @State private var showAddSubcategory = false
    @State private var newSubcategoryName = ""
    @Environment(\.dismiss) private var dismiss

    private let autoConfirmDuration: Double

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
                            .scaledFont(size: 34, weight: .bold, design: .rounded)
                            .onChange(of: amount) { _, _ in cancelCountdown() }
                    }

                    TextField("Descripción del gasto", text: $name)
                        .onChange(of: name) { _, _ in cancelCountdown() }
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
                        cancelCountdown()
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
                        .onChange(of: selectedSubcategory) { _, _ in cancelCountdown() }

                        // Inline add subcategory
                        if showAddSubcategory {
                            HStack {
                                TextField("Nueva subcategoría", text: $newSubcategoryName)
                                    .submitLabel(.done)
                                    .onSubmit { addSubcategory(to: category) }
                                Button {
                                    addSubcategory(to: category)
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .disabled(newSubcategoryName.trimmingCharacters(in: .whitespaces).isEmpty)
                                Button {
                                    showAddSubcategory = false
                                    newSubcategoryName = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            Button {
                                cancelCountdown()
                                showAddSubcategory = true
                            } label: {
                                Label("Nueva subcategoría", systemImage: "plus.circle")
                                    .foregroundStyle(Color.clarityPrimary)
                            }
                        }
                    }

                    Button {
                        cancelCountdown()
                        showNewCategory = true
                        HapticManager.shared.impact(.light)
                    } label: {
                        Label("Nueva categoría", systemImage: "plus.circle.fill")
                            .foregroundStyle(Color.clarityPrimary)
                    }
                }
            }
            .simultaneousGesture(
                TapGesture().onEnded { cancelCountdown() }
            )
            .sheet(isPresented: $showNewCategory) {
                NewCategorySheet()
            }
            // Cancel countdown on Tab key (external keyboard — moves focus to next field)
            .onKeyPress(.tab) {
                cancelCountdown()
                return .ignored  // still let SwiftUI move focus normally
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
                        if !countdownCancelled && timeRemaining > 0 && canSave {
                            SaveCountdownButton(
                                timeRemaining: timeRemaining,
                                progress: progress
                            )
                        } else {
                            Text("Guardar")
                                .fontWeight(.bold)
                        }
                    }
                    .disabled(!canSave)
                }
            }
            // Native iOS bottom bar — replaces the form section banner
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !countdownCancelled && timeRemaining > 0 && canSave {
                    AutoSaveBar(
                        timeRemaining: timeRemaining,
                        progress: progress,
                        onCancel: cancelCountdown
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: countdownCancelled)
        }
        .task {
            // — PHASE 1: All initialization while isInitialized = false —
            // onChange handlers are no-ops until isInitialized = true, so setting state
            // here (including async UserLearningManager) never cancels the countdown.

            amount = String(format: "%.2f", expense.amount)
            name = expense.name

            // Subcategory / category matching (sync)
            let parsedSub = expense.subcategory ?? ""
            let normalizedParsedSub = parsedSub.folding(options: .diacriticInsensitive, locale: .current).lowercased()
            let normalizedName = expense.name.folding(options: .diacriticInsensitive, locale: .current).lowercased()

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

            // Fallback: match expense.category field directly
            if selectedCategory == nil, !expense.category.isEmpty {
                let targetCat = expense.category
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .unicodeScalars
                    .filter { CharacterSet.letters.union(.whitespaces).contains($0) }
                    .reduce("") { $0 + String($1) }
                    .trimmingCharacters(in: .whitespaces)
                selectedCategory = categories.first { cat in
                    let catName = cat.name
                        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                        .unicodeScalars
                        .filter { CharacterSet.letters.union(.whitespaces).contains($0) }
                        .reduce("") { $0 + String($1) }
                        .trimmingCharacters(in: .whitespaces)
                    return catName == targetCat
                }
            }

            // Fallback: UserLearningManager (async — still before isInitialized = true)
            if selectedCategory == nil,
               let learned = await UserLearningManager.shared.getPreference(for: expense.name)
            {
                selectedCategory = categories.first { $0.name == learned.category }
                if let learnedSub = learned.subcategory,
                   let cat = selectedCategory,
                   cat.subcategories.contains(learnedSub)
                {
                    selectedSubcategory = learnedSub
                }
            }

            // — PHASE 2: Unlock onChange cancellation, start countdown —
            // IMPORTANT: sleep one runloop tick BEFORE setting isInitialized = true.
            // After the async UserLearningManager call, SwiftUI queues onChange
            // for selectedCategory/selectedSubcategory on the next run loop.
            // If we set isInitialized = true immediately, those fire with isInitialized = true
            // and call cancelCountdown() — killing the timer before it starts.
            // The 50ms sleep lets them fire safely while isInitialized is still false.
            try? await Task.sleep(nanoseconds: 50_000_000)
            isInitialized = true

            guard autoConfirmDuration > 0, !countdownCancelled, canSave else { return }

            let tickNs: UInt64 = 250_000_000 // 0.25s per tick
            let totalTicks = Int(autoConfirmDuration / 0.25)
            var lastHapticSecond = Int(ceil(autoConfirmDuration)) + 1

            for tick in 1...totalTicks {
                guard !countdownCancelled else { return }
                try? await Task.sleep(nanoseconds: tickNs)
                guard !countdownCancelled else { return }

                let remaining = autoConfirmDuration - Double(tick) * 0.25
                timeRemaining = max(0, remaining)
                progress = max(0, timeRemaining / autoConfirmDuration)

                // Haptic en cada segundo de la cuenta atrás
                let currentSecond = Int(ceil(remaining))
                if currentSecond < lastHapticSecond && currentSecond >= 0 {
                    lastHapticSecond = currentSecond
                    if currentSecond <= 3 && currentSecond > 0 {
                        HapticManager.shared.impact(.medium)
                    } else if currentSecond > 0 {
                        HapticManager.shared.selection()
                    }
                }
            }

            // Countdown complete — auto-save
            guard !countdownCancelled, canSave else { return }
            confirmExpense()
        }
    }

    // MARK: - Helpers

    private func addSubcategory(to category: Category) {
        let trimmed = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !category.subcategories.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            HapticManager.shared.notification(.warning)
            return
        }
        let categoryId = category.id ?? category.name
        let subToAdd = trimmed
        cancelCountdown()
        Task {
            await UserDataManager.shared.addSubcategory(subToAdd, toCategoryId: categoryId)
            await MainActor.run {
                selectedSubcategory = subToAdd
                newSubcategoryName = ""
                showAddSubcategory = false
                HapticManager.shared.notification(.success)
            }
        }
    }

    private func cancelCountdown() {
        guard isInitialized, !countdownCancelled else { return }
        countdownCancelled = true
        timeRemaining = -1
        HapticManager.shared.selection()
    }

    private var canSave: Bool {
        guard let v = Double(amount.replacingOccurrences(of: ",", with: ".")),
              v > 0, v <= 10_000 else {
            return false
        }
        return selectedCategory != nil
    }

    private func confirmExpense() {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
            amountValue > 0,
            let category = selectedCategory
        else { return }

        let categoryName = category.name
        let confirmed = Expense(
            amount: amountValue,
            name: name.isEmpty ? "Gasto por voz" : name,
            category: categoryName,
            subcategory: selectedSubcategory.isEmpty ? nil : selectedSubcategory,
            date: Formatters.isoString(from: Date()),
            paymentMethod: "Tarjeta"
        )

        if !categoryName.isEmpty {
            Task {
                await UserLearningManager.shared.learn(
                    merchant: confirmed.name,
                    category: categoryName,
                    subcategory: selectedSubcategory.isEmpty ? nil : selectedSubcategory
                )
            }
        }

        HapticManager.shared.impact(.medium)
        onConfirm(confirmed)
        dismiss()
    }
}

// MARK: - Auto-Save Bottom Bar (native iOS style)

private struct AutoSaveBar: View {
    let timeRemaining: Double
    let progress: Double
    let onCancel: () -> Void

    private var secondsLeft: Int { max(0, Int(ceil(timeRemaining))) }

    private var accentColor: Color {
        switch secondsLeft {
        case 4...: return .green
        case 2...3: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Thin progress line at top edge
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(.systemGray5))
                    Rectangle()
                        .fill(accentColor)
                        .frame(width: geo.size.width * progress)
                        .animation(.linear(duration: 0.25), value: progress)
                }
            }
            .frame(height: 2)

            // Content row
            HStack(spacing: 12) {
                // Animated checkmark icon
                Image(systemName: "checkmark.circle.fill")
                    .scaledFont(size: 18, weight: .semibold)
                    .foregroundStyle(accentColor)
                    .symbolEffect(.pulse, isActive: secondsLeft <= 3)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Guardando automáticamente")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("en \(secondsLeft) segundo\(secondsLeft == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeInOut(duration: 0.2), value: secondsLeft)
                }

                Spacer()

                Button(action: onCancel) {
                    Text("Cancelar")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(accentColor.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.bar)  // system-standard material (adapts to dark mode)
        }
        .onTapGesture { onCancel() }  // tap anywhere on the bar also cancels
    }
}

// MARK: - Toolbar Countdown Ring

struct SaveCountdownButton: View {
    let timeRemaining: Double
    let progress: Double

    private var secondsLeft: Int { Int(ceil(timeRemaining)) }

    private var ringColor: Color {
        switch secondsLeft {
        case 4...: return .green
        case 2...3: return .orange
        default: return .red
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: 2.5)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: progress)

            Text("\(secondsLeft)")
                .scaledFont(size: 13, weight: .bold, design: .rounded)
                .foregroundStyle(ringColor)
                .contentTransition(.numericText(countsDown: true))
                .animation(.easeInOut(duration: 0.2), value: secondsLeft)
        }
        .frame(width: 30, height: 30)
        .scaleEffect(secondsLeft <= 3 ? 1.1 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: secondsLeft <= 3)
    }
}
