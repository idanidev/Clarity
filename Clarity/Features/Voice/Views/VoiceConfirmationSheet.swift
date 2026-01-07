// VoiceConfirmationSheet.swift
// Expense confirmation dialog with editable fields

import SwiftUI

struct VoiceConfirmationSheet: View {
    let expense: Expense
    let wasFullyDetected: Bool
    let categories: [Category]
    let onConfirm: (Expense) -> Void
    let onCancel: () -> Void
    
    @State private var amount: String = ""
    @State private var name: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedSubcategory: String = ""
    @State private var showNewSubcategory = false
    @State private var newSubcategoryName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                // Status Badge Section
                Section {
                    VStack(spacing: 16) {
                        // Status badge
                        HStack(spacing: 8) {
                            Image(systemName: wasFullyDetected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(wasFullyDetected ? .green : .orange)
                            Text(wasFullyDetected ? "Gasto detectado" : "Revisar detalles")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            (wasFullyDetected ? Color.green : Color.orange).opacity(0.15)
                        )
                        .clipShape(Capsule())
                        
                        // Amount preview
                        Text(amount.isEmpty ? "€0.00" : "€\(amount)")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)
                
                // Amount Section
                Section("Cantidad") {
                    HStack {
                        Text("€")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title3.weight(.semibold))
                    }
                }
                
                // Description Section
                Section("Descripción") {
                    TextField("Descripción del gasto", text: $name)
                }
                
                // Category Section
                Section("Categoría") {
                    Picker("Categoría", selection: $selectedCategory) {
                        Text("-- Selecciona --").tag(nil as Category?)
                        ForEach(categories) { category in
                            Text(category.name).tag(category as Category?)
                        }
                    }
                    .onChange(of: selectedCategory) { old, new in
                        if old?.id != new?.id {
                            selectedSubcategory = ""
                        }
                    }
                }
                
                // Subcategory Section
                if let category = selectedCategory {
                    Section {
                        if showNewSubcategory {
                            HStack {
                                TextField("Nueva subcategoría", text: $newSubcategoryName)
                                
                                Button {
                                    if !newSubcategoryName.isEmpty {
                                        selectedSubcategory = newSubcategoryName
                                        showNewSubcategory = false
                                    }
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .disabled(newSubcategoryName.isEmpty)
                            }
                        } else {
                            Picker("Subcategoría", selection: $selectedSubcategory) {
                                Text("-- Selecciona --").tag("")
                                ForEach(category.subcategories, id: \.self) { sub in
                                    Text(sub).tag(sub)
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Subcategoría")
                            Spacer()
                            Button {
                                showNewSubcategory.toggle()
                                newSubcategoryName = ""
                            } label: {
                                Label("Nueva", systemImage: "plus")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Confirmar Gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar", action: onCancel)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        confirmExpense()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Guardar")
                        }
                        .fontWeight(.semibold)
                    }
                    .disabled(!canConfirm)
                }
            }
        }
        .onAppear {
            initializeFields()
        }
    }
    
    private func initializeFields() {
        amount = String(format: "%.2f", expense.amount)
        name = expense.name
        selectedCategory = categories.first { $0.name == expense.category }
        selectedSubcategory = expense.subcategory ?? ""
    }
    
    private var canConfirm: Bool {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
              amountValue > 0,
              selectedCategory != nil else {
            return false
        }
        return true
    }
    
    private func confirmExpense() {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
              let category = selectedCategory else {
            return
        }
        
        let finalSubcategory = selectedSubcategory.isEmpty ? nil : selectedSubcategory
        
        let confirmed = Expense(
            amount: amountValue,
            name: name.isEmpty ? "Gasto por voz" : name,
            category: category.name,
            subcategory: finalSubcategory,
            date: Formatters.isoString(from: Date()),
            paymentMethod: "Tarjeta"
        )
        
        onConfirm(confirmed)
    }
}

