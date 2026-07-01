// AddExpenseSheet.swift
// Add new expense form

import SwiftUI


enum AddExpField: Hashable {
    case amount, name, notes
}

struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddExpenseViewModel()
    @FocusState private var focused: AddExpField?
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                AddExpAmountSection(viewModel: viewModel, focused: $focused)
                AddExpDescriptionSection(viewModel: viewModel, focused: $focused)
                AddExpCategorySection(viewModel: viewModel)
                AddExpDateSection(viewModel: viewModel)
                AddExpPaymentSection(viewModel: viewModel)
                AddExpNotesSection(viewModel: viewModel, focused: $focused)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Nuevo Gasto")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.warmup()
                // Foco inicial en importe
                if focused == nil { focused = .amount }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    AddExpSaveToolbarButton(viewModel: viewModel, onSave: onSave, dismiss: dismiss)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Hecho") { focused = nil }
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
            }
        }
    }
}

// MARK: - Sections (structs separadas para que @Observable solo re-renderice
// las secciones cuyas propiedades cambian — evita re-render global al teclear)

private struct AddExpAmountSection: View {
    @Bindable var viewModel: AddExpenseViewModel
    var focused: FocusState<AddExpField?>.Binding

    var body: some View {
        Section {
            HStack(alignment: .center) {
                Text("€")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)

                TextField("0.00", text: $viewModel.amountText)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
                    // Responsive: expresiones largas ("1,50 + 2 × 3") encogen para caber
                    // en pantallas pequeñas (iPhone SE) en vez de cortarse.
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .focused(focused, equals: .amount)
                    .submitLabel(.next)
                    .accessibilityLabel("Cantidad del gasto")
            }
            .padding(.vertical, Spacing.sm)

            // Operadores para combinar importes en un mismo gasto (una fanta y unas patatas).
            // El teclado numérico no los tiene → estos botones los insertan. Iconos compactos
            // + Spacer → caben en cualquier móvil sin desbordar.
            HStack(spacing: 8) {
                operatorButton("+", icon: "plus")
                operatorButton("-", icon: "minus")
                operatorButton("×", icon: "multiply")
                operatorButton("÷", icon: "divide")
                Spacer(minLength: 0)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.small)

            // Total en vivo en su PROPIA línea → nunca compite por el ancho ni se corta.
            if viewModel.amountIsExpression {
                HStack(spacing: 6) {
                    Image(systemName: "equal.circle.fill")
                        .foregroundStyle(Color.clarityPrimary)
                    Text(viewModel.amount.map { Formatters.currency($0) } ?? "—")
                        .fontWeight(.bold)
                        .foregroundStyle(viewModel.amount == nil ? .secondary : Color.clarityPrimary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .font(.headline)
            }
        } footer: {
            Text("¿Varias cosas en un ticket? Escribe un importe, pulsa un operador y añade el siguiente.")
        }
    }

    /// Botón de operador (icono compacto) que lo inserta en el importe y mantiene el foco.
    private func operatorButton(_ symbol: String, icon: String) -> some View {
        Button {
            viewModel.appendAmountOperator(symbol)
            focused.wrappedValue = .amount
        } label: {
            Image(systemName: icon)
                .frame(minWidth: 24, minHeight: 20)
        }
        .accessibilityLabel(operatorLabel(symbol))
    }

    private func operatorLabel(_ symbol: String) -> String {
        switch symbol {
        case "+": return "Sumar"
        case "-": return "Restar"
        case "×": return "Multiplicar"
        case "÷": return "Dividir"
        default: return symbol
        }
    }
}

private struct AddExpDescriptionSection: View {
    @Bindable var viewModel: AddExpenseViewModel
    var focused: FocusState<AddExpField?>.Binding

    var body: some View {
        Section("Descripción") {
            TextField("¿En qué gastaste?", text: $viewModel.name)
                .font(.clarityBody)
                .focused(focused, equals: .name)
                .submitLabel(.next)
                .onSubmit { focused.wrappedValue = nil }
                .accessibilityLabel("Descripción del gasto")
                .onChange(of: viewModel.name) { _, newValue in
                    viewModel.onNameChange(newValue)
                }
        }
    }
}

private struct AddExpCategorySection: View {
    @Bindable var viewModel: AddExpenseViewModel

    var body: some View {
        Section {
            NavigationLink {
                CategoryPickerView(
                    selectedCategory: $viewModel.category,
                    selectedSubcategory: $viewModel.subcategory
                )
                .onAppear {
                    viewModel.wasAutoCategorized = false
                }
            } label: {
                HStack {
                    if viewModel.category.isEmpty {
                        Text("Seleccionar")
                            .foregroundStyle(.secondary)
                    } else {
                        Text(viewModel.category)
                            .foregroundStyle(.primary)

                        Spacer()

                        if let sub = viewModel.subcategory {
                            Text(sub)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Elige subcategoría")
                                .foregroundStyle(.orange)
                                .font(.caption.weight(.medium))
                        }

                        if viewModel.wasAutoCategorized && !viewModel.category.isEmpty {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
        } header: {
            Text("Categoría")
        } footer: {
            if !viewModel.category.isEmpty && viewModel.subcategory == nil {
                Text("⚠️ Las subcategorías son obligatorias para todos los gastos")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct AddExpDateSection: View {
    @Bindable var viewModel: AddExpenseViewModel

    var body: some View {
        Section("Fecha") {
            DatePicker(
                "Fecha",
                selection: $viewModel.date,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .tint(Color.clarityPrimary)
            .accessibilityLabel("Fecha del gasto")
        }
    }
}

private struct AddExpPaymentSection: View {
    @Bindable var viewModel: AddExpenseViewModel

    var body: some View {
        Section("Método de pago") {
            // Solo los métodos comunes (la gente usa 4-5). Gasto nuevo → no hay valor legacy.
            Picker("", selection: $viewModel.paymentMethod) {
                ForEach(PaymentMethod.pickerOptions) { method in
                    Label(method.rawValue, systemImage: method.icon)
                        .tag(method)
                }
            }
            .pickerStyle(.navigationLink)
        }
    }
}

private struct AddExpNotesSection: View {
    @Bindable var viewModel: AddExpenseViewModel
    var focused: FocusState<AddExpField?>.Binding

    var body: some View {
        Section("Notas (opcional)") {
            TextField("Notas adicionales...", text: $viewModel.notes, axis: .vertical)
                .focused(focused, equals: .notes)
                .lineLimit(3...6)
        }
    }
}

private struct AddExpSaveToolbarButton: View {
    @Bindable var viewModel: AddExpenseViewModel
    let onSave: () -> Void
    let dismiss: DismissAction

    var body: some View {
        Button("Guardar") {
            Task {
                await viewModel.save()
                guard !viewModel.showError else { return }
                UserDataManager.shared.completeOnboarding()
                onSave()
                dismiss()
            }
        }
        .fontWeight(.semibold)
        .disabled(!viewModel.isValid)
    }
}

#Preview {
    AddExpenseSheet(onSave: {})
}
