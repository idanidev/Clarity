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
                ResumenIngresosMes(
                    mes: "\(viewModel.currentMonthName.capitalized) \(String(viewModel.currentYear))",
                    nomina: viewModel.baseSalary,
                    extras: extrasTotal,
                    total: viewModel.income,
                    hayExtras: !viewModel.extraIncomes.isEmpty
                )
                .filaTarjetaClarity(arriba: 0, abajo: 0, lados: 0)
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
                                .buttonStyle(.secundarioClarity)
                            }
                        }
                    }
                    // A lo ancho no hay barra de pestañas que esquivar.
                    .sinHuecoBarraInferior()
                    .listRowSeparator(.hidden)

                    HStack {
                        TextField("Importe", text: $amountText)
                            .keyboardType(.decimalPad)
                            .focused($focused, equals: .amount)
                        Text("€").foregroundStyle(Color.textSecondary)
                    }
                }

                // En su propia sección y sin fondo de celda: el botón ancho de marca
                // no cabe bien dentro del grupo de campos.
                Section {
                    Button {
                        guard let amount else { return }
                        let conceptName = name
                        Task { await viewModel.addExtraIncome(name: conceptName, amount: amount) }
                        name = ""
                        amountText = ""
                        focused = .name
                    } label: {
                        Label("Añadir ingreso", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.principalClarity)
                    .disabled(!canSave)
                    .filaTarjetaClarity(arriba: 0, abajo: 0, lados: 0)
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
                                        .foregroundStyle(Color.textSecondary)
                                }
                                Spacer()
                                Text("+\(Formatters.currency(entry.amount))")
                                    .monospacedDigit()
                                    .foregroundStyle(Color.clarityPrimary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.textTertiary)
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
        .fondoClarity()
        .sheet(item: $editingEntry) { entry in
            ExtraIncomeEditSheet(entry: entry, viewModel: viewModel)
        }
        .trackScreen("ingresos_extra")
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

// MARK: - Resumen del mes

/// El desglose del mes en tarjeta: la cifra grande es el total si hay extras y
/// la nómina si no; debajo, de qué sale ese total.
private struct ResumenIngresosMes: View {
    let mes: String
    let nomina: Double
    let extras: Double
    let total: Double
    let hayExtras: Bool

    var body: some View {
        let cifra = hayExtras ? total : nomina

        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(hayExtras ? "Total del mes" : "Nómina")
                    .estiloEtiquetaClarity()
                Spacer(minLength: 8)
                Text(mes)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
            }

            Text(Formatters.currency(cifra))
                .estiloCifraClarity()
                .contentTransition(.numericText(value: cifra))
                .padding(.top, 4)

            if hayExtras {
                VStack(spacing: 6) {
                    HStack {
                        Text("Nómina")
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text(Formatters.currency(nomina))
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Extras")
                            .foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text("+\(Formatters.currency(extras))")
                            .monospacedDigit()
                            .foregroundStyle(Color.clarityPrimary)
                    }
                }
                .font(.subheadline)
                .padding(.top, Spacing.sm)
            }
        }
        .padding(20)
        .glassCard(cornerRadius: CornerRadius.xlarge)
        .accessibilityElement(children: .combine)
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
                        Text("€").foregroundStyle(Color.textSecondary)
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
            .fondoClarity()
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
