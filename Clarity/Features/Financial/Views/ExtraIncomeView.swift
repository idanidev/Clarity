// ExtraIncomeView.swift
// Ingresos extra del mes (bonus, freelance, venta...) vinculados a la nómina.
// Pantalla de Ajustes → Ingresos (junto a "Nóminas"): un ingreso extra vive en el
// MonthlyBudget del mes y suma al ingreso efectivo (totalIncome) que usan Home,
// hub financiero y widget. Es una pantalla PUSH (no sheet): dueña de su propio VM.

import SwiftUI

struct ExtraIncomeView: View {
    @State private var viewModel = FinancialHubViewModel()

    @State private var name = ""
    @State private var amountText = ""
    @State private var editingEntry: IncomeEntry?
    @FocusState private var focused: Field?

    private enum Field { case name, amount }

    /// Conceptos rápidos típicos — un tap rellena el nombre.
    private static let quickConcepts = ["Bonus", "Freelance", "Venta", "Regalo", "Devolución"]

    private var amount: Double? {
        let normalized = amountText.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else { return nil }
        return value
    }

    private var canSave: Bool {
        amount != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var extrasTotal: Double {
        viewModel.currentBudget?.extraIncomeTotal ?? 0
    }

    var body: some View {
        Form {
            // Desglose del mes: nómina + extras = total
            Section {
                LabeledContent("Nómina") {
                    Text(Formatters.currency(viewModel.baseSalary))
                        .foregroundStyle(.secondary)
                }
                if !viewModel.extraIncomes.isEmpty {
                    LabeledContent("Extras") {
                        Text("+\(Formatters.currency(extrasTotal))")
                            .foregroundStyle(Color.clarityPrimary)
                    }
                    LabeledContent("Total del mes") {
                        Text(Formatters.currency(viewModel.income))
                            .fontWeight(.semibold)
                    }
                }
            } header: {
                Text("\(viewModel.currentMonthName.capitalized) \(String(viewModel.currentYear))")
            } footer: {
                if viewModel.currentBudget == nil && !viewModel.isLoading {
                    // Sin budget del mes no hay dónde colgar el ingreso: la nómina va primero.
                    Text("Configura primero tu nómina de este mes en «Nóminas».")
                }
            }

            // Alta de nuevo ingreso (solo si ya hay budget del mes)
            if viewModel.currentBudget != nil {
                Section("Nuevo ingreso") {
                    TextField("Concepto (p. ej. Bonus)", text: $name)
                        .focused($focused, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focused = .amount }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.quickConcepts, id: \.self) { concept in
                                Button(concept) {
                                    name = concept
                                    HapticManager.shared.selection()
                                    focused = .amount
                                }
                                .font(.footnote)
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                            }
                        }
                    }
                    .listRowSeparator(.hidden)

                    HStack {
                        TextField("Importe", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($focused, equals: .amount)
                        Text("€").foregroundStyle(.secondary)
                    }

                    Button {
                        guard let amount else { return }
                        let conceptName = name
                        Task { await viewModel.addExtraIncome(name: conceptName, amount: amount) }
                        name = ""
                        amountText = ""
                        focused = .name
                    } label: {
                        Label("Añadir ingreso", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)
                }
            }

            // Extras ya registrados este mes (toca para editar, desliza para borrar)
            if !viewModel.extraIncomes.isEmpty {
                Section {
                    ForEach(viewModel.extraIncomes) { entry in
                        Button {
                            editingEntry = entry
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.name).foregroundStyle(.primary)
                                    Text(Formatters.displayDate(entry.date))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("+\(Formatters.currency(entry.amount))")
                                    .foregroundStyle(Color.clarityPrimary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await viewModel.removeExtraIncome(entry) }
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text("Ingresos extra de este mes")
                } footer: {
                    Text("Toca un ingreso para editarlo o desliza para borrarlo.")
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            ExtraIncomeEditSheet(entry: entry, viewModel: viewModel)
        }
        .navigationTitle("Ingresos extra")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Cerrar") { focused = nil }
            }
        }
        .task { await viewModel.load() }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK") { viewModel.clearError() }
        } message: {
            Text(viewModel.error ?? "")
        }
    }
}

// MARK: - Editor de un ingreso extra (concepto + importe, con eliminar)

private struct ExtraIncomeEditSheet: View {
    let entry: IncomeEntry
    let viewModel: FinancialHubViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var amountText: String
    @FocusState private var amountFocused: Bool

    init(entry: IncomeEntry, viewModel: FinancialHubViewModel) {
        self.entry = entry
        self.viewModel = viewModel
        _name = State(initialValue: entry.name)
        // Sin decimales sobrantes: 12 en vez de 12.0, pero 12,5 se conserva.
        _amountText = State(initialValue: String(format: "%g", entry.amount))
    }

    private var amount: Double? {
        let v = Double(amountText.replacingOccurrences(of: ",", with: "."))
        guard let v, v > 0 else { return nil }
        return v
    }

    private var canSave: Bool {
        amount != nil && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ingreso") {
                    TextField("Concepto", text: $name)
                    HStack {
                        TextField("Importe", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($amountFocused)
                        Text("€").foregroundStyle(.secondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        Task { await viewModel.removeExtraIncome(entry) }
                        dismiss()
                    } label: {
                        Label("Eliminar ingreso", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle("Editar ingreso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        guard let amount else { return }
                        var updated = entry
                        updated.name = name.trimmingCharacters(in: .whitespaces)
                        updated.amount = amount
                        Task { await viewModel.updateExtraIncome(updated) }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Cerrar") { amountFocused = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
