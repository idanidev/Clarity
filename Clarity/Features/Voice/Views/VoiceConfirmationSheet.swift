// VoiceConfirmationSheet.swift
// Expense confirmation dialog with editable fields

import SwiftUI

struct VoiceConfirmationSheet: View {
    @Binding var expense: Expense?
    @Binding var isPresented: Bool
    
    let categories: [Category]
    let wasFullyDetected: Bool
    let onConfirm: (Expense) -> Void
    let onCancel: () -> Void
    
    @State private var amount: String = ""
    @State private var name: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedSubcategory: String = ""
    @State private var showNewSubcategory = false
    @State private var newSubcategoryName = ""
    @State private var hasUserEdited = false
    
    // Auto-confirm countdown
    @State private var countdownSeconds = 5
    @State private var countdownTimer: Timer?
    
    var settings = VoiceSettings.load()
    
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
                            Text(wasFullyDetected ? "Detectado Completamente" : "Necesita Revisión")
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
                            .foregroundStyle(Color.clarityPrimary)
                        
                        // Countdown if applicable
                        if wasFullyDetected && !hasUserEdited && countdownSeconds > 0 {
                            Text("Auto-confirmando en \(countdownSeconds)s...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
                            .onChange(of: amount) { _, _ in
                                hasUserEdited = true
                                stopCountdown()
                            }
                    }
                }
                
                // Description Section
                Section("Descripción") {
                    TextField("Descripción del gasto", text: $name)
                        .onChange(of: name) { _, _ in
                            hasUserEdited = true
                            stopCountdown()
                        }
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
                        hasUserEdited = true
                        stopCountdown()
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
                            .onChange(of: selectedSubcategory) { _, _ in
                                hasUserEdited = true
                                stopCountdown()
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
                    Button("Cancelar") {
                        stopCountdown()
                        onCancel()
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        confirmExpense()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                            Text("Confirmar")
                        }
                        .fontWeight(.semibold)
                    }
                    .disabled(!canConfirm)
                }
            }
        }
        .onAppear {
            if let expense = expense {
                amount = String(format: "%.2f", expense.amount)
                name = expense.name
                selectedCategory = categories.first { $0.name == expense.category }
                selectedSubcategory = expense.subcategory ?? ""
            }
            
            // Start countdown only if fully detected
            if wasFullyDetected && canConfirm {
                startCountdown()
            }
        }
        .onDisappear {
            stopCountdown()
        }
    }
    
    private var canConfirm: Bool {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
              amountValue > 0,
              selectedCategory != nil,
              !selectedSubcategory.isEmpty else {
            return false
        }
        return true
    }
    
    private func confirmExpense() {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
              let category = selectedCategory else {
            return
        }
        
        let confirmed = Expense(
            amount: amountValue,
            name: name.isEmpty ? "Gasto por voz" : name,
            category: category.name,
            subcategory: selectedSubcategory.isEmpty ? nil : selectedSubcategory,
            date: Formatters.isoString(from: Date()),
            paymentMethod: "Tarjeta"
        )
        
        stopCountdown()
        onConfirm(confirmed)
        isPresented = false
    }
    
    private func startCountdown() {
        countdownSeconds = Int(settings.autoConfirmDelay)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdownSeconds > 0 {
                countdownSeconds -= 1
            } else {
                confirmExpense()
            }
        }
    }
    
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        countdownSeconds = 0
    }
}

// Helper extension
extension Date {
    func toString(format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
}

