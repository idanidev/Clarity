// EditExpenseSheet.swift
// Modernized Edit Expense Form

import SwiftUI


struct EditExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditExpenseViewModel
    @State private var speechManager = SpeechRecognitionManager.shared
    let onSave: () -> Void

    init(expense: Expense, onSave: @escaping () -> Void) {
        _viewModel = State(initialValue: EditExpenseViewModel(expense: expense))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                amountSection
                descriptionSection
                categorySection
                dateSection
                paymentSection
                notesSection
            }
            .navigationTitle("Editar Gasto")
            .navigationBarTitleDisplayMode(.large)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            await viewModel.save()
                            onSave()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(!viewModel.isValid)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
            }
        }
        .onChange(of: speechManager.transcript) { _, newTranscript in
            if !newTranscript.isEmpty {
                viewModel.name = newTranscript
            }
        }
    }

    // MARK: - Sections

    private var amountSection: some View {
        Section {
            HStack(alignment: .center) {
                Text("€")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                TextField("0.00", value: $viewModel.amount, format: .number)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .accessibilityLabel("Cantidad del gasto")
            }
            .padding(.vertical, Spacing.sm)
        }
    }

    private var descriptionSection: some View {
        Section("Descripción") {
            TextField("¿En qué gastaste?", text: $viewModel.name)
                .font(.clarityBody)
                .accessibilityLabel("Descripción del gasto")
                .onChange(of: viewModel.name) { _, newValue in
                    if viewModel.category.isEmpty {
                        guard newValue.count >= 3 else { return }
                        // Solo aplicar sugerencia si match con categorías reales del user
                        if let suggestion = SmartTransactionParser.suggestCategory(for: newValue),
                           let resolved = resolveSuggestion(suggestion) {
                            viewModel.category = resolved.0
                            viewModel.subcategory = resolved.1
                        }
                    }
                }

            // Dictate button
            Button {
                if speechManager.isListening {
                    speechManager.stopRecording()
                } else {
                    HapticManager.shared.impact(.medium)
                    Task {
                        try? await speechManager.startRecording()
                    }
                }
            } label: {
                Label(
                    speechManager.isListening ? "Escuchando..." : "Dictar",
                    systemImage: speechManager.isListening ? "waveform.circle.fill" : "mic.fill"
                )
                .foregroundStyle(speechManager.isListening ? .red : Color.clarityPrimary)
                .symbolEffect(.pulse, isActive: speechManager.isListening)
            }
        }
    }

    private var categorySection: some View {
        Section("Categoría") {
            NavigationLink {
                CategoryPickerView(
                    selectedCategory: $viewModel.category,
                    selectedSubcategory: $viewModel.subcategory
                )
            } label: {
                HStack {
                    Text(viewModel.category.isEmpty ? "Seleccionar" : viewModel.category)
                        .foregroundStyle(viewModel.category.isEmpty ? .secondary : .primary)
                    Spacer()
                    if let sub = viewModel.subcategory {
                        Text(sub)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var dateSection: some View {
        Section("Fecha") {
            DatePicker(
                "",
                selection: $viewModel.date,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(Color.clarityPrimary)
            .accessibilityLabel("Fecha del gasto")
        }
    }

    private var paymentSection: some View {
        Section("Método de pago") {
            Picker("", selection: $viewModel.paymentMethod) {
                ForEach(PaymentMethod.allCases) { method in
                    Label(method.rawValue, systemImage: method.icon)
                        .tag(method)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    private var notesSection: some View {
        Section("Notas") {
            TextField("Notas adicionales...", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }

    /// Mapea sugerencia hardcoded del parser a categorías reales del usuario.
    /// Devuelve nil si no hay match → no se aplica la sugerencia.
    private func resolveSuggestion(_ suggestion: (String, String?)) -> (String, String?)? {
        let userCats = UserDataManager.shared.categories
        let target = suggestion.0
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        if let cat = userCats.first(where: {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(target)
        }) {
            let sub = suggestion.1.flatMap { sugSub in
                cat.subcategories.first {
                    $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                        == sugSub.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                }
            }
            return (cat.name, sub)
        }
        if let sugSub = suggestion.1?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current),
           let cat = userCats.first(where: {
               $0.subcategories.contains {
                   $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == sugSub
               }
           }),
           let realSub = cat.subcategories.first(where: {
               $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current) == sugSub
           })
        {
            return (cat.name, realSub)
        }
        return nil
    }
}

#Preview {
    EditExpenseSheet(expense: .sample) {}
}
