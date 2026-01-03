// AddExpenseSheet.swift
// Add new expense form

import SwiftUI

struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = AddExpenseViewModel()
    let onSave: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                // Amount Section
                Section {
                    HStack(alignment: .center) {
                        Text("€")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        
                        TextField("0.00", value: $viewModel.amount, format: .number)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, Spacing.sm)
                }
                
                // Name Section
                Section("Descripción") {
                    TextField("¿En qué gastaste?", text: $viewModel.name)
                        .font(.clarityBody)
                    
                    // Quick voice input button (placeholder)
                    Button {
                        // TODO: Implement voice input
                    } label: {
                        Label("Dictar", systemImage: "mic.fill")
                            .foregroundStyle(Color.clarityPrimary)
                    }
                }
                
                // Category Section
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
                
                // Date Section
                Section("Fecha") {
                    DatePicker(
                        "",
                        selection: $viewModel.date,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(Color.clarityPrimary)
                }
                
                // Payment Method Section
                Section("Método de pago") {
                    Picker("", selection: $viewModel.paymentMethod) {
                        ForEach(PaymentMethod.allCases) { method in
                            Label(method.rawValue, systemImage: method.icon)
                                .tag(method)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // Notes Section
                Section("Notas (opcional)") {
                    TextField("Notas adicionales...", text: $viewModel.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Nuevo Gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
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
                Button("OK") { }
            } message: {
                Text(viewModel.errorMessage ?? "Error desconocido")
            }
        }
    }
}

#Preview {
    AddExpenseSheet(onSave: {})
}
