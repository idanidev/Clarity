// VoiceConfirmationSheet.swift
// Expense confirmation dialog with editable fields

import SwiftUI
import Speech
import AVFoundation
import Combine

struct VoiceConfirmationSheet: View {
    @Binding var expense: Expense?
    @Binding var isPresented: Bool
    
    let categories: [Category]
    let wasFullyDetected: Bool // NEW: true if category, subcategory, amount all detected
    let onConfirm: (Expense) -> Void
    let onCancel: () -> Void
    
    @State private var amount: String = ""
    @State private var name: String = ""
    @State private var selectedCategory: Category?
    @State private var selectedSubcategory: String = ""
    @State private var showNewSubcategory = false
    @State private var newSubcategoryName = ""
    
    // NEW: Auto-confirm countdown
    @State private var countdownSeconds = 5
    @State private var countdownTimer: Timer?
    @StateObject private var voiceConfirmListener = VoiceConfirmationListener()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header with countdown
                    VStack(spacing: 12) {
                        HStack {
                            Text("Confirmar Gasto")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Spacer()
                            
                            // NEW: Countdown indicator
                            if wasFullyDetected && countdownSeconds > 0 {
                                ZStack {
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 3)
                                        .frame(width: 44, height: 44)
                                    
                                    Circle()
                                        .trim(from: 0, to: CGFloat(countdownSeconds) / 5.0)
                                        .stroke(
                                            LinearGradient(
                                                colors: [.green, .blue],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ),
                                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                        )
                                        .frame(width: 44, height: 44)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.linear(duration: 1), value: countdownSeconds)
                                    
                                    Text("\(countdownSeconds)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        // NEW: Voice prompt
                        if wasFullyDetected && countdownSeconds > 0 {
                            Text("🎤 Di \"confirmar\" o espera \(countdownSeconds)s")
                                .font(.system(size: 13))
                                .foregroundColor(.green)
                                .transition(.opacity)
                        } else {
                            Text("Revisa los datos antes de continuar")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom)
                    
                    // Fields
                    VStack(spacing: 16) {
                        // Amount
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Cantidad (€)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("0.00", text: $amount)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 16, weight: .bold))
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Categoría")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Picker("Categoría", selection: $selectedCategory) {
                                Text("-- Selecciona --").tag(nil as Category?)
                                ForEach(categories) { category in
                                    Text(category.name).tag(category as Category?)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: selectedCategory) { oldValue, newValue in
                                selectedSubcategory = ""
                            }
                        }
                        
                        // Subcategory
                        if let category = selectedCategory {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Subcategoría")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                    
                                    Text("*")
                                        .foregroundColor(.red)
                                    
                                    Spacer()
                                    
                                    Button {
                                        showNewSubcategory.toggle()
                                        if showNewSubcategory {
                                            newSubcategoryName = ""
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "plus")
                                            Text("Nueva")
                                        }
                                        .font(.system(size: 10, weight: .medium))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple.opacity(0.2))
                                        .foregroundColor(.purple)
                                        .cornerRadius(8)
                                    }
                                }
                                
                                if showNewSubcategory {
                                    HStack {
                                        TextField("Nueva subcategoría", text: $newSubcategoryName)
                                            .textFieldStyle(.roundedBorder)
                                        
                                        Button {
                                            if !newSubcategoryName.isEmpty {
                                                selectedSubcategory = newSubcategoryName
                                                showNewSubcategory = false
                                            }
                                        } label: {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.white)
                                                .padding(8)
                                                .background(LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing))
                                                .cornerRadius(8)
                                        }
                                        .disabled(newSubcategoryName.isEmpty)
                                    }
                                } else {
                                    if category.subcategories.isEmpty {
                                        Text("-- No hay subcategorías --")
                                            .foregroundColor(.secondary)
                                            .padding()
                                            .frame(maxWidth: .infinity)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                    } else {
                                        Picker("Subcategoría", selection: $selectedSubcategory) {
                                            Text("-- Selecciona --").tag("")
                                            ForEach(category.subcategories, id: \.self) { sub in
                                                Text(sub).tag(sub)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                    }
                                }
                            }
                        }
                        
                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Descripción")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            TextField("Descripción del gasto", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // Buttons
                    HStack(spacing: 12) {
                        Button {
                            onCancel()
                            isPresented = false
                        } label: {
                            Text("Cancelar")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(16)
                        }
                        
                        Button {
                            confirmExpense()
                        } label: {
                            Text("✅ Confirmar")
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.green, Color(hex: "#10b981")!],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(16)
                        }
                        .disabled(!canConfirm)
                        .opacity(canConfirm ? 1 : 0.5)
                    }
                }
                .padding()
            }
            .background(.ultraThinMaterial)
        }
        .onAppear {
            if let expense = expense {
                amount = String(format: "%.2f", expense.amount)
                name = expense.name
                selectedCategory = categories.first { $0.name == expense.category }
                selectedSubcategory = expense.subcategory ?? ""
            }
            
            // Start countdown and voice listener if fully detected
            if wasFullyDetected && canConfirm {
                startCountdown()
                startVoiceConfirmationListener()
            }
        }
        .onDisappear {
            stopCountdown()
            voiceConfirmListener.stopListening()
        }
        .onChange(of: voiceConfirmListener.detectedCommand) { oldValue, newValue in
            guard let command = newValue else { return }
            
            switch command {
            case .confirm:
                // User said "sí", "ok", "confirmar"
                stopCountdown()
                confirmExpense()
            case .cancel:
                // User said "no", "cancelar"
                stopCountdown()
                onCancel()
                isPresented = false
            }
        }
        // NEW: Stop countdown if user manually edits any field
        .onChange(of: selectedCategory) { _, _ in
            if countdownTimer != nil {
                stopCountdown()
                voiceConfirmListener.stopListening()
            }
        }
        .onChange(of: selectedSubcategory) { _, _ in
            if countdownTimer != nil {
                stopCountdown()
                voiceConfirmListener.stopListening()
            }
        }
        .onChange(of: amount) { _, _ in
            if countdownTimer != nil {
                stopCountdown()
                voiceConfirmListener.stopListening()
            }
        }
        .onChange(of: name) { _, _ in
            if countdownTimer != nil {
                stopCountdown()
                voiceConfirmListener.stopListening()
            }
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
            subcategory: selectedSubcategory,
            date: Date().toString(format: "yyyy-MM-dd"),
            paymentMethod: "Tarjeta"
        )
        
        onConfirm(confirmed)
        isPresented = false
    }
    
    // NEW: Countdown timer
    private func startCountdown() {
        countdownSeconds = 5
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if countdownSeconds > 0 {
                countdownSeconds -= 1
            } else {
                stopCountdown()
                confirmExpense() // Auto-confirm
            }
        }
    }
    
    private func stopCountdown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }
    
    private func startVoiceConfirmationListener() {
        Task {
            await voiceConfirmListener.startListening()
        }
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

// MARK: - Voice Confirmation Listener

enum VoiceCommand {
    case confirm
    case cancel
}

class VoiceConfirmationListener: ObservableObject {
    @Published var detectedCommand: VoiceCommand?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    init() {
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))
    }
    
    func startListening() async {
        do {
            try startRecognition()
        } catch {
            print("Error starting voice confirmation listener: \(error)")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func startRecognition() throws {
        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceConfirmation", code: -1)
        }
        
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                let transcript = result.bestTranscription.formattedString.lowercased()
                
                // Check for confirm commands
                let confirmWords = ["sí", "si", "ok", "vale", "confirmar", "confirma", "adelante"]
                if confirmWords.contains(where: { transcript.contains($0) }) {
                    DispatchQueue.main.async {
                        self.detectedCommand = .confirm
                    }
                    self.stopListening()
                    return
                }
                
                // Check for cancel commands
                let cancelWords = ["no", "cancelar", "cancela", "espera", "para", "detener"]
                if cancelWords.contains(where: { transcript.contains($0) }) {
                    DispatchQueue.main.async {
                        self.detectedCommand = .cancel
                    }
                    self.stopListening()
                    return
                }
            }
            
            if error != nil {
                self.stopListening()
            }
        }
    }
}
