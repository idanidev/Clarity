// RecurringExpenseDetailView.swift
// Detail view for recurring expenses with actions

import SwiftUI

struct RecurringExpenseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let expense: RecurringExpense
    let onUpdate: () -> Void
    
    @State private var showEditSheet = false
    @State private var showDeleteConfirm = false
    @State private var showChargeConfirm = false
    @State private var isProcessing = false
    
    private var categoryColor: Color {
        UserDataManager.shared.color(for: expense.category)
    }
    
    private var emoji: String {
        // Use saved icon, fallback to extracting from category or default
        if let icon = expense.icon, !icon.isEmpty {
            return icon
        }
        let components = expense.category.components(separatedBy: " ")
        return components.count > 1 ? components.last ?? "💰" : "💰"
    }
    
    var body: some View {
        Form {
            // Hero Section
            Section {
                VStack(spacing: 20) {
                    // Large icon
                    ZStack {
                        Circle()
                            .fill(categoryColor.gradient)
                            .frame(width: 100, height: 100)
                            .shadow(color: categoryColor.opacity(0.3), radius: 20)
                        
                        Text(emoji)
                            .font(.system(size: 50))
                    }
                    
                    // Name and amount
                    VStack(spacing: 8) {
                        Text(expense.name)
                            .font(.title.bold())
                        
                        Text(Formatters.currency(expense.amount))
                            .font(.title2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    
                    // Status badge
                    HStack(spacing: 8) {
                        Image(systemName: expense.active ? "checkmark.circle.fill" : "pause.circle.fill")
                            .foregroundStyle(expense.active ? .green : .orange)
                        Text(expense.active ? "Activo" : "Pausado")
                            .font(.subheadline.weight(.medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        (expense.active ? Color.green : Color.orange).opacity(0.15)
                    )
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
            .listRowBackground(Color.clear)
            
            // Details
            Section("Información") {
                LabeledContent("Categoría", value: expense.category)
                
                if let subcategory = expense.subcategory {
                    LabeledContent("Subcategoría", value: subcategory)
                }
                
                LabeledContent {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                        Text(expense.frequency.displayName)
                    }
                } label: {
                    Text("Frecuencia")
                }
                
                LabeledContent {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("Día \(expense.dayOfMonth)")
                    }
                } label: {
                    Text("Día del cargo")
                }
                
                LabeledContent("Método de pago", value: expense.paymentMethod)
            }
            
            // History
            Section("Historial") {
                if let lastCreated = expense.lastCreated {
                    LabeledContent {
                        Text(lastCreated)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("Último cargo", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                } else {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Aún no se ha creado ningún cargo")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Actions
            Section {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Editar", systemImage: "pencil")
                }
                
                Button {
                    showChargeConfirm = true
                } label: {
                    Label("Crear cargo ahora", systemImage: "plus.circle")
                }
                .disabled(isProcessing)
                
                Button {
                    Task {
                        await toggleActive()
                    }
                } label: {
                    Label(
                        expense.active ? "Pausar" : "Reanudar",
                        systemImage: expense.active ? "pause.circle" : "play.circle"
                    )
                    .foregroundStyle(expense.active ? .orange : .green)
                }
                .disabled(isProcessing)
            }
            
            // Delete
            Section {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label("Eliminar Gasto Recurrente", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text("Esta acción no se puede deshacer.")
                    .font(.caption2)
            }
        }
        .navigationTitle(expense.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditSheet) {
            EditRecurringExpenseSheet(expense: expense) {
                onUpdate()
            }
        }
        .confirmationDialog(
            "¿Crear cargo de \(Formatters.currency(expense.amount))?",
            isPresented: $showChargeConfirm,
            titleVisibility: .visible
        ) {
            Button("Crear Cargo") {
                Task {
                    await createCharge()
                }
            }
        } message: {
            Text("Se creará un gasto inmediato con la información de este gasto recurrente.")
        }
        .confirmationDialog(
            "¿Eliminar \"\(expense.name)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Eliminar", role: .destructive) {
                Task {
                    await deleteExpense()
                }
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }
    
    private func toggleActive() async {
        guard let id = expense.id else { return }
        isProcessing = true
        
        do {
            try await RecurringExpenseRepository().toggleActive(id: id, active: !expense.active)
            HapticManager.notification(.success)
            onUpdate()
            dismiss()
        } catch {
            HapticManager.notification(.error)
            isProcessing = false
        }
    }
    
    private func createCharge() async {
        isProcessing = true
        
        let newExpense = Expense(
            amount: expense.amount,
            name: expense.name,
            category: expense.category,
            subcategory: expense.subcategory,
            date: Formatters.isoString(from: Date()),
            paymentMethod: expense.paymentMethod,
            notes: "Cargo manual de gasto recurrente"
        )
        
        do {
            _ = try await ExpenseRepository().addExpense(newExpense)
            HapticManager.notification(.success)
            dismiss()
        } catch {
            HapticManager.notification(.error)
            isProcessing = false
        }
    }
    
    private func deleteExpense() async {
        guard let id = expense.id else { return }
        
        do {
            try await RecurringExpenseRepository().delete(id: id)
            HapticManager.notification(.success)
            onUpdate()
            dismiss()
        } catch {
            HapticManager.notification(.error)
        }
    }
}

// MARK: - Edit Sheet (reuses AddRecurringExpenseSheet pattern)

struct EditRecurringExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    let expense: RecurringExpense
    let onSuccess: () -> Void
    
    @State private var amountString: String
    @State private var name: String
    @State private var selectedCategory: String
    @State private var selectedSubcategory: String?
    @State private var paymentMethod: String
    @State private var frequency: RecurringFrequency
    @State private var dayOfMonth: Int
    @State private var billingMonth: Int
    @State private var selectedIcon: String
    @State private var showEmojiPicker = false
    @State private var isSaving = false
    
    private let monthNames = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
                              "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
    
    private var categories: [Category] { UserDataManager.shared.categories }
    private var paymentMethods: [String] { UserDataManager.shared.paymentMethods }
    
    init(expense: RecurringExpense, onSuccess: @escaping () -> Void) {
        self.expense = expense
        self.onSuccess = onSuccess
        _amountString = State(initialValue: String(format: "%.2f", expense.amount))
        _name = State(initialValue: expense.name)
        _selectedCategory = State(initialValue: expense.category)
        _selectedSubcategory = State(initialValue: expense.subcategory)
        _paymentMethod = State(initialValue: expense.paymentMethod)
        _frequency = State(initialValue: expense.frequency)
        _dayOfMonth = State(initialValue: expense.dayOfMonth)
        _billingMonth = State(initialValue: expense.billingMonth > 0 ? expense.billingMonth : Calendar.current.component(.month, from: Date()))
        _selectedIcon = State(initialValue: expense.icon ?? "💰")
    }
    
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
                        .buttonStyle(.plain)
                    }
                }
                
                Section {
                    TextField("0.00", text: $amountString)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 32, weight: .bold))
                    
                    TextField("Nombre", text: $name)
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
                    
                    // Month picker - only for non-monthly frequencies
                    if frequency.needsMonthSelection {
                        Picker("Mes de cobro", selection: $billingMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthNames[month - 1]).tag(month)
                            }
                        }
                    }
                } header: {
                    Text("Programación")
                } footer: {
                    if frequency.needsMonthSelection {
                        Text("Se cobrará el día \(dayOfMonth) de \(monthNames[billingMonth - 1])")
                    } else {
                        Text("Se cobrará el día \(dayOfMonth) de cada mes")
                    }
                }
            }
            .navigationTitle("Editar Recurrente")
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
            .fullScreenCover(isPresented: $showEmojiPicker) {
                EmojiPickerView(selectedEmoji: $selectedIcon)
            }
        }
    }
    
    private func saveExpense() {
        guard let amount = Double(amountString.replacingOccurrences(of: ",", with: ".")) else {
            print("❌ Invalid amount: \(amountString)")
            return
        }
        guard let id = expense.id else {
            print("❌ No expense ID")
            return
        }
        
        print("💾 Saving expense: id=\(id), amount=\(amount), name=\(name)")
        isSaving = true
        
        let updated = RecurringExpense(
            id: id,
            amount: amount,
            name: name,
            category: selectedCategory,
            subcategory: selectedSubcategory,
            paymentMethod: paymentMethod,
            frequency: frequency,
            dayOfMonth: dayOfMonth,
            billingMonth: billingMonth,
            active: expense.active,
            icon: selectedIcon,
            startDate: expense.startDate,
            endDate: expense.endDate,
            lastCreated: expense.lastCreated,
            createdAt: expense.createdAt,
            updatedAt: Formatters.isoString(from: Date())
        )
        
        Task {
            do {
                try await RecurringExpenseRepository().update(updated)
                print("✅ Saved successfully")
                await MainActor.run {
                    HapticManager.notification(.success)
                    onSuccess()
                    dismiss()
                }
            } catch {
                print("❌ Error saving: \(error)")
                await MainActor.run {
                    isSaving = false
                }
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

#Preview {
    NavigationStack {
        RecurringExpenseDetailView(expense: .sample, onUpdate: {})
    }
}
