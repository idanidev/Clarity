// AddExpenseSheet.swift
// Add new expense form

import SwiftUI


struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddExpenseViewModel()
    let onSave: () -> Void
    
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
            .navigationTitle("Nuevo Gasto")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task {
                            await viewModel.save()
                            // Solo cerrar si el guardado tuvo éxito (sino el alert sigue visible)
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
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
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
                    viewModel.onNameChange(newValue)
                }
        }
    }
    
    private var categorySection: some View {
        Section {
            NavigationLink {
                CategoryPickerView(
                    selectedCategory: $viewModel.category,
                    selectedSubcategory: $viewModel.subcategory
                )
                .onAppear {
                    // User manually selecting = no longer auto-categorized
                    viewModel.wasAutoCategorized = false
                }
            } label: {
                HStack {
                    // Si no hay categoría seleccionada
                    if viewModel.category.isEmpty {
                        Text("Seleccionar")
                            .foregroundStyle(.secondary)
                    } else {
                        // Mostrar categoría
                        Text(viewModel.category)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        // Mostrar subcategoría (OBLIGATORIO)
                        if let sub = viewModel.subcategory {
                            Text(sub)
                                .foregroundStyle(.secondary)
                        } else {
                            // Si hay categoría pero no subcategoría, mostrar advertencia
                            Text("Elige subcategoría")
                                .foregroundStyle(.orange)
                                .font(.caption.weight(.medium))
                        }
                        
                        // Auto-fill indicator
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
        Section("Notas (opcional)") {
            TextField("Notas adicionales...", text: $viewModel.notes, axis: .vertical)
                .lineLimit(3...6)
        }
    }
}

#Preview {
    AddExpenseSheet(onSave: {})
}
