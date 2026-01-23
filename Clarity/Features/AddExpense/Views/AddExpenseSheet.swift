// AddExpenseSheet.swift
// Add new expense form

import SwiftUI
import TipKit // Added for potential future tips in this sheet

struct AddExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AddExpenseViewModel()
    @State private var speechManager = SpeechRecognitionManager()
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
        .onChange(of: speechManager.transcript) { _, newTranscript in
            if !newTranscript.isEmpty {
                viewModel.name = newTranscript
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
                    // Auto-categorize only if category empty or was auto-filled
                    guard viewModel.category.isEmpty || viewModel.wasAutoCategorized else { return }
                    guard newValue.count >= 3 else { return } // Wait for 3+ chars
                    
                    // Use SmartTransactionParser helper if available, or fallback to new Parser
                    if let suggestion = SmartTransactionParser.suggestCategory(for: newValue) {
                        viewModel.category = suggestion.0
                        viewModel.subcategory = suggestion.1
                        viewModel.wasAutoCategorized = true
                    }
                }
            
            // Dictate button
            Button {
                if speechManager.isListening {
                    speechManager.stopRecording()
                } else {
                    HapticManager.shared.impact(.medium)
                    Task {
                        try? await speechManager.startRecording()
                    }
                }
            } label: {
                Label(speechManager.isListening ? "Escuchando..." : "Dictar",
                      systemImage: speechManager.isListening ? "waveform.circle.fill" : "mic.fill")
                    .foregroundStyle(speechManager.isListening ? .red : Color.clarityPrimary)
                    .symbolEffect(.pulse, isActive: speechManager.isListening)
            }
        }
    }
    
    private var categorySection: some View {
        Section("Categoría") {
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
                    Text(viewModel.category.isEmpty ? "Seleccionar" : viewModel.category)
                        .foregroundStyle(viewModel.category.isEmpty ? .secondary : .primary)
                    Spacer()
                    if let sub = viewModel.subcategory {
                        Text(sub)
                            .foregroundStyle(.secondary)
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
