// VoiceExpenseButton.swift
// Voice Expense Button - Stable & Audible Version
// Solution: Magician's Trick (Visual Feedback -> Sound -> Safe Delay -> Mic)

import SwiftUI
import AVFoundation
import AudioToolbox // Essential for System Sounds

struct VoiceExpenseButton: View {
    // Dependencies
    var viewModel: HomeViewModel
    let categories: [Category]
    
    @State private var speechManager = SpeechRecognitionManager()
    @State private var voiceCoordinator = VoiceExpenseCoordinator()
    
    // UI State
    @State private var isRecording = false
    @State private var isLocked = false
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var dragOffset: CGSize = .zero
    @State private var showSheet = false
    
    // Thresholds
    private let lockThreshold: CGFloat = -80
    private let cancelThreshold: CGFloat = -100
    
    @Namespace private var namespace

    var body: some View {
        ZStack(alignment: .trailing) {
            // Recording Capsule
            if isRecording || isLocked {
                recordingCapsule
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9, anchor: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .matchedGeometryEffect(id: "voiceButton", in: namespace, isSource: true)
            }
            
            // Main Button
            mainButton
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .sheet(isPresented: $showSheet) {
            if let expense = voiceCoordinator.pendingExpense {
                VoiceConfirmationSheet(
                    expense: expense,
                    wasFullyDetected: voiceCoordinator.wasFullyDetected,
                    categories: categories,
                    speechManager: speechManager,
                    onConfirm: { confirmed in
                        Task {
                            await voiceCoordinator.saveExpense(confirmed, viewModel: viewModel)
                            showSheet = false
                            // Success sound for save
                            AudioServicesPlaySystemSound(1001)
                            resetState()
                        }
                    },
                    onCancel: {
                        showSheet = false
                        resetState()
                        voiceCoordinator.reset()
                    }
                )
                .presentationDetents([.medium, .fraction(0.7)])
            }
        }
        .onAppear {
            speechManager.prepare()
            // Configure audio session for system sounds
            configureAudioSession()
        }
    }
    
    // MARK: - Recording Capsule
    
    private var recordingCapsule: some View {
        HStack {
            // Visualizer
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { i in
                    VisualizerBar(audioLevel: speechManager.audioLevel, index: i)
                }
            }
            .padding(.leading, 12)
            
            Text(isLocked ? "Grabando..." : "Suelta para enviar")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.leading, 4)
            
            Spacer()
            
            if !isLocked {
                HStack(spacing: 0) {
                    Image(systemName: "chevron.left")
                        .font(.caption2)
                    Text("Desliza para cancelar")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.7))
                .opacity(dragOffset.width < -40 ? 0.4 : 1.0)
                .padding(.trailing, 12)
                .offset(x: min(0, max(dragOffset.width + 20, -20)))
            }
        }
        .frame(height: 56)
        .frame(maxWidth: isLocked ? 160 : .infinity)
        .background(
            Capsule()
                .fill(Color.clarityPrimary)
                .shadow(color: Color.clarityPrimary.opacity(0.4), radius: 10, y: 5)
        )
    }
    
    // MARK: - Main Button
    
    private var mainButton: some View {
        ZStack {
            // Background
            Circle()
                .fill(buttonColor)
                .frame(width: 60, height: 60)
                .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                .matchedGeometryEffect(id: "voiceButton", in: namespace, isSource: false)
            
            // Icon
            buttonIcon
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
        .offset(
            x: isLocked ? 0 : dragOffset.width,
            y: isLocked ? 0 : dragOffset.height
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dragOffset)
        .accessibilityLabel("Grabar gasto por voz")
        .accessibilityHint("Mantén presionado para grabar")
    }
    
    @ViewBuilder
    private var buttonIcon: some View {
        if showSuccess {
            Image(systemName: "checkmark")
                .font(.title.bold())
                .foregroundStyle(.white)
        } else if isProcessing {
            ProgressView()
                .tint(.white)
        } else if isLocked {
            Image(systemName: "stop.fill")
                .font(.title2)
                .foregroundStyle(Color.clarityPrimary)
        } else if isRecording {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(Color.clarityPrimary)
                .scaleEffect(1.2)
        } else {
            Image(systemName: "mic.fill")
                .font(.title2)
                .foregroundStyle(.white)
        }
    }
    
    private var buttonColor: Color {
        if showSuccess { return .green }
        if isProcessing { return .orange }
        if isRecording || isLocked { return .white }
        return Color.clarityPrimary
    }
    
    // MARK: - Gesture Handling
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if !isRecording && !isLocked && !isProcessing {
            startRecordingSequence()
        }
        
        guard isRecording && !isLocked else { return }
        
        let translation = value.translation
        
        // Lock (Up)
        if translation.height < lockThreshold && abs(translation.width) < 60 {
            lockRecording()
        }
        // Cancel visual feedback (Left)
        else if translation.width < 0 && translation.height > -60 {
            dragOffset.width = translation.width
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        if isLocked {
            finishRecording()
            return
        }
        
        guard isRecording else { return }
        
        if value.translation.width < cancelThreshold {
            cancelRecording()
        } else {
            finishRecording()
        }
    }
    
    // MARK: - Actions (The Fix)
    
    private func startRecordingSequence() {
        // 1. IMMEDIATE Feedback (Visual + Haptic - Subtle)
        HapticManager.shared.impact(.light)
        
        withAnimation(.spring(response: 0.3)) {
            isRecording = true
        }
        
        // 2. Audible Feedback (Fire and Forget) - LOUDER with Alert
        // SystemSoundID 1104 is standard "Begin Recording"
        AudioServicesPlayAlertSound(1104)
        
        // 3. Microphone Start with SAFETY DELAY
        // 0.25s is invisible because animation started, but allows System Sound to clear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            do {
                try speechManager.startRecording()
                voiceCoordinator.startRecording(speechManager: speechManager) 
            } catch {
                print("Error starting mic: \(error)")
                resetState()
            }
        }
    }
    
    private func lockRecording() {
        // Haptic: Locked feedback
        HapticManager.shared.impact(.heavy)
        
        withAnimation(.spring(response: 0.3)) {
            isLocked = true
            dragOffset = .zero
        }
    }
    
    private func finishRecording() {
        // Haptic + Sound: End Recording (LOUDER)
        HapticManager.shared.impact(.light)
        AudioServicesPlayAlertSound(1105) // End Recording sound
        speechManager.stopRecording()
        
        withAnimation(.spring(response: 0.3)) {
            isRecording = false
            isLocked = false
            isProcessing = true
            dragOffset = .zero
        }
        
        Task {
            // Simulate thinking (UX)
            try? await Task.sleep(nanoseconds: 800_000_000)
            
            // Process
            voiceCoordinator.stopAndFinish(speechManager: speechManager)
            
            // Wait for coordinator to update state
            try? await Task.sleep(nanoseconds: 200_000_000)
            
            await MainActor.run {
                // Check for ERROR first (priority)
                if case .error = voiceCoordinator.state {
                    // ERROR - No audio, parsing failed, etc.
                    AudioServicesPlaySystemSound(1053) // Error sound
                    HapticManager.shared.notification(.error)
                    resetState()
                } else if voiceCoordinator.state == .confirming || voiceCoordinator.pendingExpense != nil {
                    // SUCCESS - Valid expense detected
                    AudioServicesPlaySystemSound(1001) // Success chime
                    HapticManager.shared.notification(.success)
                    
                    withAnimation(.spring(response: 0.3)) {
                        isProcessing = false
                        showSuccess = true
                    }
                    
                    // Show sheet AFTER checkmark animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        showSuccess = false
                        showSheet = true
                    }
                } else {
                    // FALLBACK - Unexpected state
                    AudioServicesPlaySystemSound(1053)
                    HapticManager.shared.notification(.error)
                    resetState()
                }
            }
        }
    }
    
    private func cancelRecording() {
        // Sound: Cancel/Delete
        AudioServicesPlaySystemSound(1004)
        HapticManager.shared.notification(.warning)
        
        speechManager.stopRecording()
        voiceCoordinator.cancelRecording(speechManager: speechManager)
        
        withAnimation(.spring(response: 0.3)) {
            resetState()
        }
    }
    
    private func resetState() {
        isRecording = false
        isLocked = false
        isProcessing = false
        showSuccess = false
        dragOffset = .zero
    }
    
    private func configureAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("⚠️ Failed to configure audio session: \(error)")
        }
    }
}
