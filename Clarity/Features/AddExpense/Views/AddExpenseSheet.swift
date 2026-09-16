// AddExpenseSheet.swift
// Add new expense form

import SwiftUI


enum AddExpField: Hashable {
    case amount, name, notes
    /// Campos del modo regalo, uno por deudor (#37).
    case debtorName(String)
    case debtorAmount(String)
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
                GiftModeSection(
                    isShared: $viewModel.isShared,
                    debtors: $viewModel.debtors,
                    totalAmount: viewModel.amount ?? 0,
                    focused: $focused
                )
                AddExpNotesSection(viewModel: viewModel, focused: $focused)
            }
            .fondoClarity()
            .scrollDismissesKeyboard(.interactively)
            .trackScreen("anadir_gasto")
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

                // Solo antes de iOS 26: desde iOS 26 (y en 27) esta barra de
                // accesorio se descuelga al cambiar de teclado dentro de una hoja,
                // se queda flotando en medio del formulario y se traga los toques.
                // El teclado se cierra arrastrando el formulario o tocando otro campo.
                if #unavailable(iOS 26) {
                    ToolbarItem(placement: .keyboard) {
                        HStack {
                            Spacer()
                            Button("Hecho") { focused = nil }
                                .fontWeight(.semibold)
                        }
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
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(Color.clarityPrimary)

                // Redondeada y con dígitos de ancho fijo, como las cifras de la
                // Home: el importe no cambia de ancho con cada tecla.
                TextField("0.00", text: $viewModel.amountText)
                    // Sin `minimumScaleFactor` ni `monospacedDigit` sobre el campo: en
                    // iOS 26 esa combinación en un TextField de este tamaño dejaba la
                    // app colgada al aparecer el teclado en algunos iPhone. Las
                    // expresiones largas ("1,50 + 2 × 3") encogen bajando el tamaño.
                    .font(.system(size: tamanoImporte, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.leading)
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
            // Cápsulas tintadas, como las acciones secundarias del resto de la app.
            // Con un estilo propio cada botón conserva su toque dentro de la fila.
            .buttonStyle(.secundarioClarity)

            // Total en vivo en su PROPIA línea → nunca compite por el ancho ni se corta.
            if viewModel.amountIsExpression {
                HStack(spacing: 6) {
                    Image(systemName: "equal.circle.fill")
                        .foregroundStyle(Color.clarityPrimary)
                    Text(viewModel.amount.map { Formatters.currency($0) } ?? "—")
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(viewModel.amount == nil ? Color.textSecondary : Color.clarityPrimary)
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
    /// 48 pt hasta ocho caracteres; menos a partir de ahí, para que quepa.
    private var tamanoImporte: CGFloat {
        let n = viewModel.amountText.count
        return n > 12 ? 26 : (n > 8 ? 34 : 48)
    }

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
                .onChange(of: viewModel.category) { _, newValue in
                    viewModel.categoryPickedByUser(newValue)
                }
            } label: {
                HStack {
                    if viewModel.category.isEmpty {
                        Text("Seleccionar")
                            .foregroundStyle(Color.textSecondary)
                    } else {
                        Text(viewModel.category)
                            .foregroundStyle(.primary)

                        Spacer()

                        if let sub = viewModel.subcategory {
                            Text(sub)
                                .foregroundStyle(Color.textSecondary)
                        } else {
                            Text("Elige subcategoría")
                                .foregroundStyle(Color.warning)
                                .font(.caption.weight(.medium))
                        }

                        if viewModel.wasAutoCategorized && !viewModel.category.isEmpty {
                            Image(systemName: "sparkles")
                                .font(.caption)
                                .foregroundStyle(Color.warning)
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
                    .foregroundStyle(Color.warning)
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
