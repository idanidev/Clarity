// AddRecurringExpenseSheet.swift
// Form to add a new recurring expense

import SwiftUI

struct AddRecurringExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSuccess: () -> Void
    
    @StateObject private var repository = RecurringExpenseRepository()
    
    @State private var amountString = ""
    @State private var name = ""
    @State private var selectedCategory = ""
    @State private var selectedSubcategory: String? = nil
    @State private var paymentMethod = "Tarjeta"
    @State private var frequency: RecurringFrequency = .monthly
    @State private var dayOfMonth: Int = 1
    @State private var selectedIcon = "💰"
    @State private var showEmojiPicker = false
    @State private var isSaving = false
    
    // Cached data from singleton
    private var categories: [Category] { UserDataManager.shared.categories }
    private var paymentMethods: [String] { UserDataManager.shared.paymentMethods }
    
    var body: some View {
        NavigationStack {
            Form {
                // Icon section
                Section {
                    HStack {
                        Text("Icono")
                        Spacer()
                        Button {
                            showEmojiPicker = true
                        } label: {
                            Text(selectedIcon)
                                .font(.system(size: 40))
                                .padding(8)
                                .background(Color.clarityPrimary.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                
                Section {
                    TextField("0.00", text: $amountString)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .bold))
                    
                    TextField("Nombre (ej. Netflix)", text: $name)
                }
                
                Section {
                    NavigationLink(destination: CategoryPickerView(
                        selectedCategory: $selectedCategory,
                        selectedSubcategory: $selectedSubcategory
                    )) {
                        HStack {
                            Text("Categoría")
                            Spacer()
                            Text(formatCategorySelection())
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Picker("Método de Pago", selection: $paymentMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                }
                
                Section {
                    Picker("Frecuencia", selection: $frequency) {
                        ForEach(RecurringFrequency.allCases, id: \.self) { freq in
                            Text(freq.displayName).tag(freq)
                        }
                    }
                    
                    Picker("Día del cargo", selection: $dayOfMonth) {
                        ForEach(1...31, id: \.self) { day in
                            Text("Día \(day)").tag(day)
                        }
                    }
                }
            }
            .navigationTitle("Nuevo Recurrente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveExpense()
                    }
                    .disabled(amountString.isEmpty || name.isEmpty || selectedCategory.isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $selectedIcon)
            }
        }
    }
    
    private func saveExpense() {
        guard let amount = Double(amountString.replacingOccurrences(of: ",", with: ".")) else { return }
        
        isSaving = true
        
        let newExpense = RecurringExpense(
            id: nil,
            amount: amount,
            name: name,
            category: selectedCategory,
            subcategory: selectedSubcategory,
            paymentMethod: paymentMethod,
            frequency: frequency,
            dayOfMonth: dayOfMonth,
            active: true,
            icon: selectedIcon,
            startDate: Formatters.isoString(from: Date()),
            endDate: nil,
            lastCreated: nil,
            createdAt: Formatters.isoString(from: Date()),
            updatedAt: Formatters.isoString(from: Date())
        )
        
        Task {
            do {
                _ = try await repository.add(newExpense)
                HapticManager.notification(.success)
                onSuccess()
                dismiss()
            } catch {
                print("Error saving recurring expense: \(error)")
                isSaving = false
            }
        }
    }
    
    private func formatCategorySelection() -> String {
        if selectedCategory.isEmpty { return "Requerido" }
        if let sub = selectedSubcategory {
            return "\(selectedCategory) > \(sub)"
        }
        return selectedCategory
    }
}

