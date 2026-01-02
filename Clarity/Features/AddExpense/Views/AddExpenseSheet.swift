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

// MARK: - Category Picker
struct CategoryPickerView: View {
    @Binding var selectedCategory: String
    @Binding var selectedSubcategory: String?
    @Environment(\.dismiss) private var dismiss
    
    // Use cached categories from UserDataManager
    private var categories: [Category] {
        UserDataManager.shared.categories
    }
    
    var body: some View {
        List {
            if categories.isEmpty {
                // Loading or empty state
                Section {
                    Text("Cargando categorías...")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(categories) { category in
                    Section {
                        // Main category
                        Button {
                            selectedCategory = category.name
                            selectedSubcategory = nil
                            dismiss()
                        } label: {
                            HStack {
                                Circle()
                                    .fill(category.uiColor)
                                    .frame(width: 12, height: 12)
                                
                                Text(category.name)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if selectedCategory == category.name && selectedSubcategory == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.clarityPrimary)
                                }
                            }
                        }
                        
                        // Subcategories
                        ForEach(category.subcategories, id: \.self) { subcategory in
                            Button {
                                selectedCategory = category.name
                                selectedSubcategory = subcategory
                                dismiss()
                            } label: {
                                HStack {
                                    Text(subcategory)
                                        .foregroundStyle(.primary)
                                        .padding(.leading, Spacing.lg)
                                    
                                    Spacer()
                                    
                                    if selectedCategory == category.name && selectedSubcategory == subcategory {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.clarityPrimary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Categoría")
    }
}

#Preview {
    AddExpenseSheet(onSave: {})
}
