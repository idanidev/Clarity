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
                    .focused(focused, equals: .amount)
                    .submitLabel(.next)
                    .accessibilityLabel("Cantidad del gasto")
            }
            .padding(.vertical, Spacing.sm)
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
            Picker("", selection: $viewModel.paymentMethod) {
                ForEach(PaymentMethod.allCases) { method in
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
