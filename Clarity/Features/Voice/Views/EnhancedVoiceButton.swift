// EnhancedVoiceButton.swift
// Radial drag-to-select button for expense actions (Swift 6)

import SwiftUI

@MainActor
struct EnhancedVoiceButton: View {
    
    // MARK: - Actions
    let onVoiceTap: () -> Void
    let onManualTap: () -> Void
    let onRecurringTap: () -> Void
    
    // MARK: - State
    @State private var isDragging = false
    @State private var dragLocation: CGPoint = .zero
    @State private var selectedOption: RadialOption? = nil
    @State private var activationProgress: CGFloat = 0.0
    @State private var pulsePhase: CGFloat = 0
    
    // MARK: - Constants
    private let buttonSize: CGFloat = 56
    private let menuRadius: CGFloat = 60
    private let selectionThreshold: CGFloat = 25
    private let angleThreshold: Double = 35
    
    var body: some View {
        ZStack {
            // MARK: - Radial Menu Overlay
            if isDragging {
                // Backdrop
                Color.black.opacity(0.2)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                // Satellite Options
                ForEach(RadialOption.allCases) { option in
                    satelliteButton(for: option)
                }
            }
            
            // MARK: - Main Button
            mainButton
        }
        .sensoryFeedback(.selection, trigger: selectedOption)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulsePhase = 1
            }
        }
    }
    
    // MARK: - Main Button
    private var mainButton: some View {
        ZStack {
            // Glow ring - subtle pulse
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.clarityPrimary.opacity(0.5),
                            Color.claritySecondary.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: buttonSize + 8, height: buttonSize + 8)
                .scaleEffect(isDragging ? 1.0 : (1 + pulsePhase * 0.08))
                .opacity(isDragging ? 0.3 : (0.6 - pulsePhase * 0.3))
            
            // Soft glow background
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.clarityPrimary.opacity(0.4),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 15,
                        endRadius: 35
                    )
                )
                .frame(width: buttonSize + 20, height: buttonSize + 20)
                .blur(radius: 8)
                .opacity(isDragging ? 0.5 : 1.0)
            
            // Main gradient circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.clarityPrimary,
                            Color.claritySecondary
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: buttonSize, height: buttonSize)
                .overlay {
                    // Top shine
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .center
                            )
                        )
                }
                .overlay {
                    // Border
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
                .shadow(
                    color: Color.clarityPrimary.opacity(0.4),
                    radius: isDragging ? 8 : 12,
                    y: isDragging ? 2 : 4
                )
                .scaleEffect(isDragging ? 0.9 : 1.0)
            
            // Icon
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .scaleEffect(isDragging ? 0.8 : 1.0)
        }
        .animation(.bouncy(duration: 0.3), value: isDragging)
        .animation(.easeInOut, value: pulsePhase)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged(handleDrag)
                .onEnded(handleRelease)
        )
    }
    
    // MARK: - Satellite Button
    @ViewBuilder
    private func satelliteButton(for option: RadialOption) -> some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(selectedOption == option ? Color.clarityPrimary.gradient : Color(.systemGray6).gradient)
                    .frame(width: 56, height: 56)
                    .shadow(
                        color: selectedOption == option ? Color.clarityPrimary.opacity(0.4) : .black.opacity(0.1),
                        radius: selectedOption == option ? 8 : 4,
                        y: 2
                    )
                
                Image(systemName: option.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selectedOption == option ? .white : .primary)
            }
            .scaleEffect(selectedOption == option ? 1.25 : 1.0)
            
            Text(option.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(selectedOption == option ? .primary : .secondary)
        }
        .offset(
            x: sin(option.angle * .pi / 180) * menuRadius * activationProgress,
            y: -cos(option.angle * .pi / 180) * menuRadius * activationProgress - 10
        )
        .animation(.bouncy(duration: 0.4, extraBounce: 0.1), value: activationProgress)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedOption)
    }
    
    // MARK: - Gesture Handlers
    
    private func handleDrag(_ value: DragGesture.Value) {
        if !isDragging {
            withAnimation(.bouncy(duration: 0.3)) {
                isDragging = true
                activationProgress = 1.0
            }
            HapticManager.impact(.medium)
        }
        
        dragLocation = value.location
        
        // Calculate distance from center
        let distance = hypot(value.translation.width, value.translation.height)
        
        // Dead zone (center)
        if distance < selectionThreshold {
            if selectedOption != nil {
                selectedOption = nil
            }
            return
        }
        
        // Calculate angle to determine which sector we're in
        // -90 is left, 0 is top, 90 is right
        let angle = atan2(value.translation.width, -value.translation.height) * 180 / .pi
        
        // Assign selection based on angular proximity
        let newSelection: RadialOption?
        
        if abs(angle - RadialOption.manual.angle) < angleThreshold {
            newSelection = .manual
        } else if abs(angle - RadialOption.voice.angle) < angleThreshold {
            newSelection = .voice
        } else if abs(angle - RadialOption.recurring.angle) < angleThreshold {
            newSelection = .recurring
        } else {
            newSelection = nil
        }
        
        if newSelection != selectedOption {
            selectedOption = newSelection
        }
    }
    
    private func handleRelease(_ value: DragGesture.Value) {
        // Execute action
        if let option = selectedOption {
            HapticManager.notification(.success)
            switch option {
            case .manual:
                onManualTap()
            case .voice:
                onVoiceTap()
            case .recurring:
                onRecurringTap()
            }
        } else {
            // If released in center without dragging much, it's a normal tap
            let distance = hypot(value.translation.width, value.translation.height)
            if distance < selectionThreshold {
                HapticManager.impact(.light)
                onVoiceTap()
            }
        }
        
        // Reset
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isDragging = false
            activationProgress = 0.0
            selectedOption = nil
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        
        VStack {
            Spacer()
            EnhancedVoiceButton(
                onVoiceTap: { print("Voice") },
                onManualTap: { print("Manual") },
                onRecurringTap: { print("Recurring") }
            )
            .padding(.bottom, 100)
        }
    }
}
