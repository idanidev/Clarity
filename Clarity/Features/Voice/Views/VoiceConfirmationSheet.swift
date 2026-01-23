// VoiceConfirmationSheet.swift
// Expense confirmation dialog with editable fields

import SwiftUI
import Combine

struct VoiceConfirmationSheet: View {
    let expense: Expense
    let wasFullyDetected: Bool
    let categories: [Category]
    var speechManager: SpeechRecognitionManager
    let onConfirm: (Expense) -> Void
    let onCancel: () -> Void
    
    @State private var amount: String = ""
    @State private var name: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedSubcategory: String = ""
    @State private var showNewSubcategory = false
    @State private var newSubcategoryName = ""
    
    // New Features State
    @State private var timeRemaining: Double = 6.0
    @State private var isTimerActive = false
    @State private var progress: Double = 1.0
    @State private var isUserInteracting = false
    @State private var showNewCategoryAlert = false
    @State private var newCategoryName = ""
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationStack {
            Form {
                // Status Badge Section
                Section {
                    VStack(spacing: 16) {
                        // Status badge
                        HStack(spacing: 8) {
                            if isTimerActive {
                                Image(systemName: "mic.fill")
                                    .foregroundStyle(.blue)
                                    .symbolEffect(.pulse)
                                Text("Di 'OK' para confirmar")
                                    .font(.subheadline.weight(.medium))
                            } else {
                                Image(systemName: wasFullyDetected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(wasFullyDetected ? .green : .orange)
                                Text(wasFullyDetected ? "Gasto detectado" : "Revisar detalles")
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            (isTimerActive ? Color.blue : (wasFullyDetected ? Color.green : Color.orange)).opacity(0.15)
                        )
                        .clipShape(Capsule())
                        .animation(.easeInOut, value: isTimerActive)
                        
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
                            .onChange(of: amount) { _, _ in userDidInteract() }
                    }
                }
                
                // Description Section
                Section("Descripción") {
                    TextField("Descripción del gasto", text: $name)
                        .onChange(of: name) { _, _ in userDidInteract() }
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
                        userDidInteract()
                        if old?.id != new?.id {
                            // Only clear if current subcategory is NOT valid for new category
                            // This prevents clearing the voice-detected subcategory on initial load
                            if let newCategory = new, !newCategory.subcategories.contains(selectedSubcategory) {
                                selectedSubcategory = ""
                            }
                        }
                    }
                    
                    Button {
                        userDidInteract()
                        showNewCategoryAlert = true
                    } label: {
                        Label("Nueva Categoría", systemImage: "plus")
                    }
                }
                
                // Subcategory Section
                if let category = selectedCategory {
                    Section {
                        if showNewSubcategory {
                            HStack {
                                TextField("Nueva subcategoría", text: $newSubcategoryName)
                                    .onChange(of: newSubcategoryName) { _, _ in userDidInteract() }
                                
                                Button {
                                    if !newSubcategoryName.isEmpty {
                                        selectedSubcategory = newSubcategoryName
                                        showNewSubcategory = false
                                        userDidInteract()
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
                            .onChange(of: selectedSubcategory) { _, _ in userDidInteract() }
                        }
                    } header: {
                        HStack {
                            Text("Subcategoría")
                            Spacer()
                            Button {
                                showNewSubcategory.toggle()
                                newSubcategoryName = ""
                                userDidInteract()
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
                    Button("Cancelar", action: {
                        stopTimer()
                        onCancel()
                    })
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        confirmExpense()
                    } label: {
                        HStack(spacing: 6) {
                            if isTimerActive {
                                ZStack {
                                    Circle()
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                                    Circle()
                                        .trim(from: 0, to: CGFloat(progress))
                                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                        .rotationEffect(.degrees(-90))
                                        .animation(.linear(duration: 0.1), value: progress)
                                }
                                .frame(width: 20, height: 20)
                                Text("\(Int(ceil(timeRemaining)))s")
                                    .monospacedDigit()
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text("Guardar")
                        }
                        .fontWeight(.semibold)
                    }
                    .disabled(!canConfirm)
                }
            }
            .alert("Nueva Categoría", isPresented: $showNewCategoryAlert) {
                TextField("Nombre", text: $newCategoryName)
                Button("Cancelar", role: .cancel) { }
                Button("Crear") {
                    createNewCategory()
                }
            }
        }
        .onAppear {
            initializeFields()
            startAutoSave()
        }
        .onDisappear {
            stopTimer()
        }
        .onReceive(timer) { _ in
            guard isTimerActive else { return }
            
            if timeRemaining > 0 {
                timeRemaining -= 0.1
                progress = timeRemaining / 6.0
            } else {
                confirmExpense()
            }
        }
        .onChange(of: speechManager.transcript) { _, newTranscript in
            checkVoiceCommand(newTranscript)
        }
    }
    
    // MARK: - Logic
    
    private func initializeFields() {
        amount = String(format: "%.2f", expense.amount)
        name = expense.name
        selectedCategory = categories.first { $0.name == expense.category }
        selectedSubcategory = expense.subcategory ?? ""
    }
    
    // MARK: - Auto Save & Voice
    
    private func startAutoSave() {
        // Only auto-save if detection was high quality
        guard wasFullyDetected else { return }
        
        isTimerActive = true
        timeRemaining = 6.0
        progress = 1.0
        
        // Start listening for commands
        Task {
            try? await speechManager.startRecording()
        }
    }
    
    private func stopTimer() {
        isTimerActive = false
        speechManager.stopRecording()
    }
    
    private func userDidInteract() {
        if isTimerActive {
            stopTimer()
            HapticManager.shared.selection()
        }
    }
    
    private func checkVoiceCommand(_ transcript: String) {
        guard isTimerActive else { return }
        
        let command = transcript.lowercased()
        if command.contains("ok") || 
           command.contains("vale") || 
           command.contains("guardar") || 
           command.contains("confirmar") ||
           command.contains("sí") {
            confirmExpense()
        }
    }
    
    // MARK: - Category Management
    
    private func createNewCategory() {
        guard !newCategoryName.isEmpty else { return }
        
        // In a real app we'd save this to Firebase likely
        // For now we simulate selection locally as if it existed
        // Ideally we should have a callback to create it upstream
        
        // NOTE: Since Categories are Model objects, we might need a workaround 
        // if we can't create them here. Let's assume we can select it temporarily.
        // For full feature we'd need a viewModel for categories.
        
        // Temporary dummy category for UI selection
        let newCat = Category(
            id: UUID().uuidString,
            name: newCategoryName + " ✨", 
            color: "#808080",
            subcategories: [], // No subcategories for new category
            order: 999 // New categories last
        )
        selectedCategory = newCat
        newCategoryName = ""
        userDidInteract()
    }
    
    // MARK: - Validation & Confirmation
    
    private var canConfirm: Bool {
        guard let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")),
              amountValue > 0,
              selectedCategory != nil else {
            return false
        }
        return true
    }
    
    private func confirmExpense() {
        stopTimer()
        
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
            paymentMethod: "Tarjeta" // Default
        )
        
        onConfirm(confirmed)
    }
}

