// EditExpenseSheet.swift
// Edit existing expense form

import SwiftUI

struct EditExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let expense: Expense
    let onSave: () -> Void
    
    @State private var amount: Double
    @State private var name: String
    @State private var category: String
    @State private var subcategory: String?
    @State private var date: Date
    @State private var paymentMethod: String
    @State private var notes: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    
    private let repository = ExpenseRepository()
    
    init(expense: Expense, onSave: @escaping () -> Void) {
        self.expense = expense
        self.onSave = onSave
        
        _amount = State(initialValue: expense.amount)
        _name = State(initialValue: expense.name)
        _category = State(initialValue: expense.category)
        _subcategory = State(initialValue: expense.subcategory)
        _paymentMethod = State(initialValue: expense.paymentMethod)
        _notes = State(initialValue: expense.notes ?? "")
        
        // Parse date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        _date = State(initialValue: formatter.date(from: expense.date) ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Amount Section
                Section {
                    HStack(alignment: .center) {
                        Text("€")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        
                        TextField("0.00", value: $amount, format: .number)
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(.vertical, Spacing.sm)
                }
                
                // Name Section
                Section("Descripción") {
                    TextField("¿En qué gastaste?", text: $name)
                }
                
                // Category Section
                Section("Categoría") {
                    NavigationLink {
                        CategoryPickerView(
                            selectedCategory: $category,
                            selectedSubcategory: $subcategory
                        )
                    } label: {
                        HStack {
                            Text(category.isEmpty ? "Seleccionar" : category)
                                .foregroundColor(category.isEmpty ? .gray : .primary)
                            Spacer()
                            if let sub = subcategory, !sub.isEmpty {
                                Text(sub)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                // Date Section
                Section("Fecha") {
                    DatePicker("Fecha", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(Color.clarityPrimary)
                }
                
                // Payment Method
                Section("Método de Pago") {
                    Picker("Método", selection: $paymentMethod) {
                        Text("Tarjeta").tag("Tarjeta")
                        Text("Efectivo").tag("Efectivo")
                        Text("Transferencia").tag("Transferencia")
                        Text("Bizum").tag("Bizum")
                    }
                    .pickerStyle(.segmented)
                }
                
                // Notes
                Section("Notas") {
                    TextField("Notas opcionales", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Error Message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(Color.error)
                    }
                }
            }
            .navigationTitle("Editar Gasto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveExpense()
                    }
                    .disabled(isSaving || name.isEmpty || amount <= 0)
                    .fontWeight(.semibold)
                }
            }
            .tint(Color.clarityPrimary)
        }
    }
    
    private func saveExpense() {
        guard let expenseId = expense.id else { return }
        
        isSaving = true
        errorMessage = nil
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        
        let updatedExpense = Expense(
            id: expenseId,
            amount: amount,
            name: name,
            category: category,
            subcategory: subcategory,
            date: dateString,
            paymentMethod: paymentMethod,
            notes: notes.isEmpty ? nil : notes
        )
        
        Task {
            do {
                try await repository.updateExpense(updatedExpense)
                await MainActor.run {
                    isSaving = false
                    onSave()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    EditExpenseSheet(expense: .sample) {}
}
