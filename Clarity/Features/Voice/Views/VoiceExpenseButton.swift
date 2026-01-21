// VoiceExpenseButton.swift
// Advanced high-fidelity voice button with zero-latency gesture controls
// "WhatsApp Style" - Hold to record, Slide to cancel, Slide up to lock

import SwiftUI

struct VoiceExpenseButton: View {
    var viewModel: HomeViewModel
    let categories: [Category]
    
    @State private var speechManager = SpeechRecognitionManager()
    @State private var voiceCoordinator = VoiceExpenseCoordinator()
    
    // UI State for Gestures & Morphing
    @State private var isRecording = false
    @State private var isLocked = false
    @State private var dragOffset: CGSize = .zero
    
    // Haptics configuration
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    // Gesture Thresholds
    let lockThreshold: CGFloat = -80  // Up
    let cancelThreshold: CGFloat = -100 // Left
    
    // Pre-warming
    @State private var hasPreWarmed = false

    var body: some View {
        ZStack(alignment: .trailing) {
            
            // 1. RECORDING CAPSULE (Morphing UI)
            if isRecording || isLocked {
                HStack {
                    // Audio Visualizer (Simulated pulses based on audio level)
                    // In a real scenario, bind to speechManager.audioLevel
                    HStack(spacing: 3) {
                        ForEach(0..<4) { i in
                            VisualizerBar(audioLevel: speechManager.audioLevel, index: i)
                        }
                    }
                    .padding(.leading, 12)
                    
                    // Timer / Status Text
                    Text(isLocked ? "Grabando..." : "Suelta para enviar")
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.medium)
                        .foregroundStyle(Color.white)
                        .padding(.leading, 4)
                        .transaction { transaction in
                            transaction.animation = nil // Avoid text animation jitter
                        }
                    
                    Spacer()
                    
                    // Slide to cancel hint
                    if !isLocked {
                        HStack(spacing: 0) {
                            Image(systemName: "chevron.left")
                                .font(.caption2)
                            Text("Desliza para cancelar")
                                .font(.caption2)
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .opacity(dragOffset.width < -40 ? 0.4 : 1.0)
                        .padding(.trailing, 12)
                        .offset(x: min(0, max(dragOffset.width + 20, -20))) // Subtle hint movement
                    }
                }
                .frame(height: 56)
                .frame(maxWidth: isLocked ? 160 : .infinity) // Shrink if locked
                .background(
                    Capsule()
                        .fill(Color.clarityPrimary) // or Red/Gradient
                        .shadow(color: Color.clarityPrimary.opacity(0.4), radius: 10, y: 5)
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.9, anchor: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
                .matchedGeometryEffect(id: "capsule", in: namespace, isSource: true)
                .zIndex(0)
            }
            
            // 2. MICROPHONE BUTTON (Interactive)
            ZStack {
                // Background Circle (Morphs or Disappears)
                if !isRecording && !isLocked {
                    Circle()
                        .fill(voiceCoordinator.buttonGradient)
                        .frame(width: 60, height: 60)
                        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
                        .matchedGeometryEffect(id: "capsule", in: namespace, isSource: false)
                }
                
                // Active recording circle (follows finger)
                if isRecording || isLocked {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 80, height: 80)
                        .shadow(color: .black.opacity(0.15), radius: 8)
                        .scaleEffect(isLocked ? 1.0 : 1.2) // Puff effect
                }
                
                // Icon
                Image(systemName: isLocked ? "stop.fill" : (isRecording ? "mic.fill" : "mic.fill"))
                    .font(.title2)
                    .foregroundColor(isRecording || isLocked ? .clarityPrimary : .white)
                    .scaleEffect(isRecording && !isLocked ? 1.3 : 1.0)
                    .contentTransition(.symbolEffect(.replace))
            }
            // GESTURE HANDLER
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
            .zIndex(1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        // Coordinators & Sheets
        .sheet(isPresented: $voiceCoordinator.showConfirmation) {
            if let expense = voiceCoordinator.pendingExpense {
                VoiceConfirmationSheet(
                    expense: expense,
                    wasFullyDetected: voiceCoordinator.wasFullyDetected,
                    categories: categories,
                    speechManager: speechManager,
                    onConfirm: { confirmed in
                        Task {
                            await voiceCoordinator.saveExpense(
                                confirmed,
                                viewModel: viewModel
                            )
                        }
                    },
                    onCancel: {
                        voiceCoordinator.reset()
                    }
                )
                .presentationDetents([.medium, .fraction(0.7)])
            }
        }
        .overlay(alignment: .top) {
            if voiceCoordinator.showSuccessToast {
                SuccessToast(message: voiceCoordinator.successMessage)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, -100) // Adjust based on position
            }
        }
        .onAppear {
            speechManager.prepare()
        }
    }
    
    @Namespace private var namespace
    
    // MARK: - Gesture Logic
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if !isRecording && !isLocked {
            startRecording()
        }
        
        let translation = value.translation
        
        // 1. Lock Logic (Up)
        if translation.height < 0 && abs(translation.width) < 60 {
            // Only move Y if not canceling
            dragOffset.height = translation.height
            dragOffset.width = 0
            
            // Check lock threshold
            if translation.height < lockThreshold {
                if !isLocked {
                    isLocked = true
                    dragOffset = .zero // Snap back
                    impactFeedback.impactOccurred(intensity: 1.0)
                    voiceCoordinator.lockRecording()
                }
            }
        }
        // 2. Cancel Logic (Left)
        else if translation.width < 0 && translation.height > -60 {
            dragOffset.width = translation.width
            dragOffset.height = 0
            
            // Check cancel threshold
            if translation.width < cancelThreshold {
                 // Provide haptic feedback at threshold
                if translation.width < cancelThreshold + 10 && translation.width > cancelThreshold - 10 {
                    selectionFeedback.selectionChanged()
                }
            }
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        // If locked, tap (drag ended quickly) stops it
        if isLocked {
            stopRecordingAndSend()
            return
        }
        
        let translation = value.translation
        
        // 1. Cancel
        if translation.width < cancelThreshold {
            cancelRecording()
        }
        // 2. Send
        else {
            stopRecordingAndSend()
        }
    }
    
    // MARK: - Actions
    
    private func startRecording() {
        isRecording = true
        impactFeedback.impactOccurred(intensity: 1.0)
        voiceCoordinator.startRecording(speechManager: speechManager)
    }
    
    private func stopRecordingAndSend() {
        // Haptic for success
        notificationFeedback.notificationOccurred(.success)
        
        // Reset local state
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isRecording = false
            isLocked = false
            dragOffset = .zero
        }
        
        // Coordinator Action
        voiceCoordinator.stopAndFinish(speechManager: speechManager)
    }
    
    private func cancelRecording() {
        // Haptic for error/cancel
        notificationFeedback.notificationOccurred(.error)
        
        // Reset local state
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isRecording = false
            dragOffset = .zero
        }
        
        // Coordinator Action
        voiceCoordinator.cancelRecording(speechManager: speechManager)
    }
}

// MARK: - Visual Components

struct VisualizerBar: View {
    let audioLevel: Float
    let index: Int
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Color.white.opacity(0.9))
            .frame(width: 3, height: height(for: index))
            .animation(.easeInOut(duration: 0.1), value: audioLevel)
    }
    
    private func height(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let variability = CGFloat(index + 1) * 2
        // Dynamic height based on level, clamped
        let levelHeight = CGFloat(audioLevel) * 25.0
        return min(30, max(baseHeight, levelHeight + variability))
    }
}

// MARK: - Helper Views

struct SuccessToast: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.green)
            
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding()
        .background(Material.ultraThin)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.2), radius: 10)
        .padding(.horizontal)
    }
}



