//
//  VoiceExpenseButton.swift
//  Clarity
//
//  Created by Clarity AI on 2026-01-22.
//  Motion Design: Butter Smooth (iOS 17+)
//

import SwiftUI
import AVFoundation
import AudioToolbox // Essential for System Sounds
import CoreHaptics

struct VoiceExpenseButton: View {
    // Dependencies
    var viewModel: HomeViewModel
    let categories: [Category]
    
    @State private var speechManager = SpeechRecognitionManager()
    @State private var voiceCoordinator = VoiceExpenseCoordinator()
    
    // Choreography State
    @State private var interactionState: InteractionState = .idle
    @State private var dragOffset: CGSize = .zero
    @State private var showSheet = false
    @State private var showSuccess = false
    @State private var rippleTrigger = 0 // Increment to trigger ripple
    
    // Thresholds
    private let lockThreshold: CGFloat = -80
    private let cancelThreshold: CGFloat = -100
    
    @Namespace private var namespace
    
    // MARK: - Definition
    
    enum InteractionState: Equatable {
        case idle
        case touching       // Phase 1: Touch Down (Scale + Ripple)
        case recording      // Phase 2: Recording (Breathing)
        case locked         // Phase 2b: Hands-free
        case processing     // Phase 3: Spinner (Morph)
        case success        // Phase 4: Checkmark (Bounce)
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            
            // 1. Recording Capsule (Expands from Button)
            if isExpandedState {
                recordingCapsule
                    .matchedGeometryEffect(id: "container", in: namespace)
                    .transition(.opacity.animation(.linear(duration: 0.2)))
            }
            
            // 2. Main Button (Morphs into capsule background or stays as button)
            if !isExpandedState {
                mainButton
                    .matchedGeometryEffect(id: "container", in: namespace)
                    .zIndex(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        // Global Sheet
        .sheet(isPresented: $showSheet) {
            sheetContent
        }
        .onAppear {
            HapticManager.shared.prepare()
        }
    }
    
    private var isExpandedState: Bool {
        return interactionState == .recording || interactionState == .locked
    }
    
    // MARK: - Components
    
    private var mainButton: some View {
        ZStack {
            // Ripple Effect (Keyframe Animator)
            Circle()
                .fill(Color.clarityPrimary.opacity(0.3))
                .frame(width: 60, height: 60)
                .keyframeAnimator(initialValue: AnimationValues(), trigger: rippleTrigger) { content, value in
                    content
                        .scaleEffect(value.scale)
                        .opacity(value.opacity)
                } keyframes: { _ in
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(1.5, duration: 0.4, spring: .snappy)
                        SpringKeyframe(1.0, duration: 0.0) // Reset
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0.0, duration: 0.4)
                        LinearKeyframe(1.0, duration: 0.0) // Reset
                    }
                }
            
            // Base Circle
            Circle()
                .fill(buttonColor)
                .frame(width: 60, height: 60)
                .shadow(color: buttonColor.opacity(0.4), radius: 10, y: 5)
                .scaleEffect(interactionState == .touching ? 0.9 : (interactionState == .success ? 1.1 : 1.0))
            
            // Icon
            iconView
                .foregroundStyle(.white)
                .font(.title2)
                .scaleEffect(interactionState == .touching ? 0.8 : 1.0)
        }
        // Physics-based Spring for Touch Interaction
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: interactionState)
        .offset(
            x: interactionState == .locked ? 0 : dragOffset.width,
            y: interactionState == .locked ? 0 : dragOffset.height
        )
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    handleDragChanged(value)
                }
                .onEnded { value in
                    handleDragEnded(value)
                }
        )
    }
    
    private var recordingCapsule: some View {
        HStack {
            // Visualizer
            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { i in
                    VisualizerBar(audioLevel: speechManager.audioLevel, index: i)
                }
            }
            .frame(width: 24, height: 24)
            .padding(.leading, 16)
            
            Text(interactionState == .locked ? "Grabando..." : "Suelta para enviar")
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            
            Spacer()
            
            // Slide to Cancel Hint
            if interactionState != .locked {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left")
                    Text("Cancelar")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.trailing, 16)
                .opacity(dragOffset.width < -40 ? 0.6 : 1.0)
            } else {
                // Stop Button
                Image(systemName: "square.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Circle().fill(.white.opacity(0.2)))
                    .padding(.trailing, 6)
                    .onTapGesture {
                        finishRecording()
                    }
            }
        }
        .frame(height: 60)
        .frame(maxWidth: interactionState == .locked ? 180 : .infinity)
        .background(
            Capsule()
                .fill(Color.clarityPrimary)
                .shadow(color: Color.clarityPrimary.opacity(0.3), radius: 15, y: 8)
        )
        // Fluid size transition
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: interactionState)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: dragOffset)
    }
    
    @ViewBuilder
    private var iconView: some View {
        switch interactionState {
        case .idle, .touching:
            Image(systemName: "mic.fill")
                .transition(.scale.combined(with: .opacity))
        case .recording, .locked:
            Image(systemName: "mic.fill")
                .symbolEffect(.pulse, options: .repeating) // Breathing
        case .processing:
            ProgressView()
                .tint(.white)
                .transition(.scale.combined(with: .opacity))
        case .success:
            Image(systemName: "checkmark")
                .symbolEffect(.bounce, value: showSuccess) // iOS 17 Bounce
                .fontWeight(.bold)
        }
    }
    
    // MARK: - Choreography Logic
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        // Phase 1: Touch Down (The "Pop")
        if interactionState == .idle || interactionState == .success {
            startInteraction()
        }
        
        guard interactionState == .recording || interactionState == .touching else { return }
        
        // Drag Logic
        dragOffset = value.translation
        
        // Lock Logic (Up)
        if value.translation.height < lockThreshold && interactionState == .recording {
            lockRecording()
        }
        
        // Cancel Logic Visuals
        if value.translation.width < cancelThreshold {
             // Maybe dim the capsule? handled by SwiftUI responsiveness
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        if interactionState == .locked { return } // Must tap stop
        
        // Cancel?
        if value.translation.width < cancelThreshold {
            cancelRecording()
        } else {
            // Normal Release -> Send
            finishRecording()
        }
    }
    
    // MARK: - Sequence Methods
    
    private func startInteraction() {
        // 1. Tactile & Visual Pop
        HapticManager.shared.playSoftImpact()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            interactionState = .touching
        }
        
        // 2. Ripple & Audio (Synchronized)
        rippleTrigger += 1
        // Sound is handled by startRecordingSequence inside VoiceCoordinator logic roughly, 
        // but we want tight UI control. Ideally, sound plays HERE.
        // Coordinator manages the "Real" recording.
        
        startRecordingSequence()
    }
    
    private func startRecordingSequence() {
        // 3. Audio & Delay
        // Fire and forget sound for zero latency
        AudioServicesPlaySystemSound(1104) // Tock
        
        // 4. Expand to Capsule (Morph)
        // Wait 0.25s for sound to clear, then morph
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // Start Mic
            Task {
                do {
                    try await speechManager.startRecording()
                    // If successful, morph
                    await MainActor.run {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                            interactionState = .recording
                        }
                        // Feedback that recording is LIVE
                        HapticManager.shared.playSoftImpact()
                    }
                } catch {
                    print("Mic Error: \(error)")
                    resetState()
                }
            }
        }
    }
    
    private func lockRecording() {
        HapticManager.shared.impact(.medium) // Distinct click
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            interactionState = .locked
            dragOffset = .zero
        }
    }
    
    private func finishRecording() {
        // 1. Audio/Haptic Stop
        AudioServicesPlaySystemSound(1105) // Tock High
        HapticManager.shared.playSoftImpact()
        
        // 2. Stop Mic
        speechManager.stopRecording()
        
        // 3. Morph to Spinner
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            interactionState = .processing
            dragOffset = .zero
        }
        
        // 4. Process Logic (Async)
        processTranscript()
    }
    
    private func cancelRecording() {
        // Cancel sound
        AudioServicesPlaySystemSound(1004)
        HapticManager.shared.notification(.warning)
        
        speechManager.stopRecording()
        
        withAnimation(.spring(response: 0.3)) {
            resetState()
        }
    }
    
    private func processTranscript() {
        let text = (speechManager.transcript + " " + speechManager.interimTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        guard !text.isEmpty else {
            HapticManager.shared.error() // Error haptic
            resetState()
            return
        }
        
        // Simulate "Thinking" time (min 0.8s for UX pacing)
        Task {
            // Coordinator Logic (Parsing)
            // We call parse manually to handle UI state here
            let result = await SmartTransactionParser.shared.parse(text, history: UserDataManager.shared.expenses)
            
            // Min delay
            try? await Task.sleep(nanoseconds: 600_000_000)
            
            await MainActor.run {
                switch result {
                case .success(let parsed):
                    handleSuccess(parsed)
                case .failure:
                    handleError()
                }
            }
        }
    }
    
    private func handleSuccess(_ transaction: SmartTransaction) {
        // 1. Success State (Green Checkmark)
        HapticManager.shared.playSuccess() // Double crisp vibration
        AudioServicesPlaySystemSound(1001) // Mail Sent
        
        // Prepare pending expense for sheet
        let categoryName = transaction.category ?? categories.first?.name ?? "Otros"
        let expense = Expense(
            amount: NSDecimalNumber(decimal: transaction.amount).doubleValue,
            name: transaction.merchant,
            category: categoryName,
            subcategory: transaction.subcategory,
            date: Formatters.isoString(from: transaction.date)
        )
        voiceCoordinator.pendingExpense = expense
        voiceCoordinator.wasFullyDetected = transaction.confidence >= 0.8
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { // Bouncy
            interactionState = .success
            showSuccess = true // Triggers symbol effect
        }
        
        // 2. Pause Dramática (0.8s) -> Open Sheet
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            showSheet = true // Slide up
        }
    }
    
    private func handleError() {
        HapticManager.shared.error()
        AudioServicesPlaySystemSound(1053)
        withAnimation {
            resetState()
        }
    }
    
    private func resetState() {
        interactionState = .idle
        dragOffset = .zero
        showSuccess = false
        speechManager.stopRecording()
    }
    
    // MARK: - Helpers
    
    private var buttonColor: Color {
        switch interactionState {
        case .success: return .green
        case .processing: return .clarityPrimary // Or a slightly lighter shade
        case .locked, .recording: return .white // Not visible typically (covered by capsule)
        default: return .clarityPrimary
        }
    }
    
    private var sheetContent: some View {
        Group {
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
                            // Closing Wink ;)
                            winkButton()
                        }
                    },
                    onCancel: {
                        showSheet = false
                        resetState()
                    }
                )
                .presentationDetents([.medium, .fraction(0.7)])
            }
        }
    }
    
    private func winkButton() {
        // Quick scale animation to welcome user back
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            resetState()
        }
    }
    
    struct AnimationValues {
        var scale = 1.0
        var opacity = 0.0
    }
}


