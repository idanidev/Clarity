// EditExpenseSheet.swift
// Modernized Edit Expense Form

import SwiftUI


struct EditExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: EditExpenseViewModel
    @FocusState private var focused: AddExpField?
    /// «Cancelar» con cambios: pregunta antes de tirarlos (`confirmarDescarte`).
    @State private var preguntarDescarte = false
    let onSave: () -> Void

    init(expense: Expense, onSave: @escaping () -> Void) {
        _viewModel = State(initialValue: EditExpenseViewModel(expense: expense))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                EditExpAmountSection(viewModel: viewModel)
                EditExpDescriptionSection(viewModel: viewModel)
                EditExpCategorySection(viewModel: viewModel)
                EditExpDateSection(viewModel: viewModel)
                EditExpPaymentSection(viewModel: viewModel)
                GiftModeSection(
                    isShared: $viewModel.isShared,
                    debtors: $viewModel.debtors,
                    totalAmount: viewModel.amount ?? 0,
                    focused: $focused
                )
                EditExpNotesSection(viewModel: viewModel)
            }
            .fondoClarity()
            .navigationTitle("Editar Gasto")
            .navigationBarTitleDisplayMode(.large)
            .keyboardDoneToolbar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    BotonCancelarFormulario(
                        preguntando: $preguntarDescarte,
                        hayCambios: viewModel.hayCambios
                    ) { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    EditExpSaveToolbarButton(viewModel: viewModel, onSave: onSave, dismiss: dismiss)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
            }
            // `hayCambios` se lee dentro del modificador, no aquí: este `body` no
            // pasa a depender de cada campo del formulario.
            .confirmarDescarte(
                preguntando: $preguntarDescarte,
                hayCambios: viewModel.hayCambios
            ) { dismiss() }
        }
        .background(EditExpDictado(viewModel: viewModel))
        // Registro de cuelgues: ver `AddExpenseSheet`.
        .onAppear { Migas.deja("hoja editar: aparece") }
        .background(MigasDeFoco(hoja: "hoja editar", foco: $focused))
    }
}

// MARK: - Sections (structs separadas, como en `AddExpenseSheet`: @Observable solo
// re-renderiza la sección cuyas propiedades cambian. Antes eran `var … : some View`
// de la hoja y cada tecla reevaluaba el formulario entero.)

private struct EditExpAmountSection: View {
    @Bindable var viewModel: EditExpenseViewModel

    var body: some View {
        Section {
            HStack(alignment: .center) {
                Text("€")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.clarityPrimary)

                // Texto crudo y no `value:format:`, que convertía Double↔String en
                // cada tecla. El importe sale del texto en el ViewModel.
                TextField("0.00", text: $viewModel.amountText)
                    // Sin `monospacedDigit` sobre el campo: ver AddExpenseSheet (iOS 26).
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    .accessibilityLabel("Cantidad del gasto")
            }
            .padding(.vertical, Spacing.sm)
        }
    }
}

private struct EditExpDescriptionSection: View {
    @Bindable var viewModel: EditExpenseViewModel
    // Sin `@State`: es un singleton `@Observable`, no hay nada que conservar.
    private let speechManager = SpeechRecognitionManager.shared

    var body: some View {
        Section("Descripción") {
            TextField("¿En qué gastaste?", text: $viewModel.name)
                .font(.clarityBody)
                .accessibilityLabel("Descripción del gasto")
                .onChange(of: viewModel.name) { _, newValue in
                    viewModel.onNameChange(newValue)
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
                .foregroundStyle(speechManager.isListening ? Color.error : Color.clarityPrimary)
                .symbolEffect(.pulse, isActive: speechManager.isListening)
            }
        }
    }
}

/// Vuelca lo dictado en la descripción. Vista aparte que no pinta nada, como
/// `MigasDeFoco`: leer `transcript` en el `body` de la hoja la reevaluaba entera
/// con cada palabra reconocida. Va de fondo de la hoja y no dentro de la sección
/// para seguir viva aunque la fila de la descripción se salga de pantalla.
private struct EditExpDictado: View {
    let viewModel: EditExpenseViewModel
    private let speechManager = SpeechRecognitionManager.shared

    var body: some View {
        Color.clear
            .onChange(of: speechManager.transcript) { _, newTranscript in
                if !newTranscript.isEmpty {
                    viewModel.name = newTranscript
                }
            }
    }
}

private struct EditExpCategorySection: View {
    @Bindable var viewModel: EditExpenseViewModel

    var body: some View {
        Section("Categoría") {
            NavigationLink {
                CategoryPickerView(
                    selectedCategory: $viewModel.category,
                    selectedSubcategory: $viewModel.subcategory
                )
            } label: {
                HStack {
                    Text(viewModel.category.isEmpty ? "Seleccionar" : viewModel.category)
                        .foregroundStyle(viewModel.category.isEmpty ? Color.textSecondary : Color.primary)
                    Spacer()
                    if let sub = viewModel.subcategory {
                        Text(sub)
                            .foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
    }
}

private struct EditExpDateSection: View {
    @Bindable var viewModel: EditExpenseViewModel

    var body: some View {
        Section("Fecha") {
            DatePicker(
                "",
                selection: $viewModel.date,
                displayedComponents: .date
            )
            // Compacto, como en Añadir gasto: el calendario gráfico dentro de
            // un Form con campos de texto se reconstruía en cada tecla.
            .datePickerStyle(.compact)
            .tint(Color.clarityPrimary)
            .accessibilityLabel("Fecha del gasto")
        }
    }
}

private struct EditExpPaymentSection: View {
    @Bindable var viewModel: EditExpenseViewModel

    var body: some View {
        Section("Método de pago") {
            Picker("", selection: $viewModel.paymentMethod) {
                ForEach(paymentOptions) { method in
                    Label(method.rawValue, systemImage: method.icon)
                        .tag(method)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }

    /// Métodos comunes + el actual si es legacy (PayPal, Apple Pay…), para que editar
    /// un gasto antiguo NO reescriba su método a "Otro" al no estar en la lista.
    private var paymentOptions: [PaymentMethod] {
        var opts = PaymentMethod.pickerOptions
        if !opts.contains(viewModel.paymentMethod) {
            opts.append(viewModel.paymentMethod)
        }
        return opts
    }
}

private struct EditExpNotesSection: View {
    @Bindable var viewModel: EditExpenseViewModel

    var body: some View {
        Section("Notas") {
            TextField("Notas adicionales...", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
}

private struct EditExpSaveToolbarButton: View {
    @Bindable var viewModel: EditExpenseViewModel
    let onSave: () -> Void
    let dismiss: DismissAction

    var body: some View {
        Button("Guardar") {
            Task {
                await viewModel.save()
                // Si falla, la hoja se queda abierta con la alerta y lo escrito,
                // como en Añadir. Antes se cerraba igual y el error no se veía.
                guard !viewModel.showError else { return }
                onSave()
                dismiss()
            }
        }
        .fontWeight(.semibold)
        .disabled(!viewModel.isValid)
    }
}

#Preview {
    EditExpenseSheet(expense: .sample) {}
}
