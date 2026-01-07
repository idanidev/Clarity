// RadialAddButton.swift
// WhatsApp-style animated radial menu for adding expenses

import SwiftUI

struct RadialAddButton: View {
    // Callbacks
    let onManualExpense: () -> Void
    let onVoiceExpense: () -> Void
    let onRecurringExpense: () -> Void
    
    // State
    @State private var isExpanded = false
    @State private var selectedOption: AddOption? = nil
    @State private var dragLocation: CGPoint = .zero
    @GestureState private var isLongPressing = false
    
    enum AddOption: CaseIterable {
        case voice, manual, recurring
        
        var icon: String {
            switch self {
            case .voice: return "mic.fill"
            case .manual: return "pencil"
            case .recurring: return "arrow.clockwise"
            }
        }
        
        var label: String {
            switch self {
            case .voice: return "Voz"
            case .manual: return "Manual"
            case .recurring: return "Recurrente"
            }
        }
        
        var color: Color {
            switch self {
            case .voice: return .purple
            case .manual: return .blue
            case .recurring: return .orange
            }
        }
        
        // Angle in the fan (from center)
        var angle: Double {
            switch self {
            case .manual: return -50
            case .voice: return 0
            case .recurring: return 50
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Expanded options
            if isExpanded {
                ForEach(AddOption.allCases, id: \.self) { option in
                    optionButton(option)
                        .offset(offsetFor(option))
                        .scaleEffect(selectedOption == option ? 1.2 : 1.0)
                        .opacity(isExpanded ? 1 : 0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isExpanded)
                }
            }
            
            // Main button
            mainButton
        }
    }
    
    // MARK: - Main Button
    private var mainButton: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: isExpanded ? [.purple, .pink] : [Color.clarityPrimary, Color.clarityPrimary.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 56, height: 56)
            .overlay(
                Image(systemName: isExpanded ? "xmark" : "mic.badge.plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            )
            .shadow(color: Color.clarityPrimary.opacity(0.4), radius: isExpanded ? 15 : 8)
            .scaleEffect(isLongPressing ? 0.9 : 1.0)
            .gesture(combinedGesture)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
            .animation(.spring(response: 0.2), value: isLongPressing)
    }
    
    // MARK: - Option Button
    private func optionButton(_ option: AddOption) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(option.color.gradient)
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: option.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                )
                .shadow(color: option.color.opacity(0.4), radius: 8)
            
            Text(option.label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
        }
    }
    
    // MARK: - Gesture
    private var combinedGesture: some Gesture {
        // Tap for manual expense
        let tap = TapGesture()
            .onEnded {
                HapticManager.selection()
                onManualExpense()
            }
        
        // Long press to expand radial menu
        let longPress = LongPressGesture(minimumDuration: 0.3)
            .updating($isLongPressing) { value, state, _ in
                state = value
            }
            .onEnded { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded = true
                }
                HapticManager.impact(.medium)
            }
        
        // Drag to select option
        let drag = DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard isExpanded else { return }
                dragLocation = value.location
                
                // Check which option is closest
                let newSelection = findClosestOption(to: value.location)
                if newSelection != selectedOption {
                    selectedOption = newSelection
                    if newSelection != nil {
                        HapticManager.selection()
                    }
                }
            }
            .onEnded { _ in
                if let selected = selectedOption {
                    executeOption(selected)
                }
                closeMenu()
            }
        
        return tap.simultaneously(with: longPress.sequenced(before: drag))
    }
    
    // MARK: - Helpers
    private func offsetFor(_ option: AddOption) -> CGSize {
        let radius: CGFloat = 90
        let angleRad = option.angle * .pi / 180
        return CGSize(
            width: sin(angleRad) * radius,
            height: -cos(angleRad) * radius - 20
        )
    }
    
    private func findClosestOption(to point: CGPoint) -> AddOption? {
        var closest: AddOption? = nil
        var minDistance: CGFloat = 60 // Threshold
        
        for option in AddOption.allCases {
            let offset = offsetFor(option)
            let optionCenter = CGPoint(x: offset.width, y: offset.height)
            let distance = hypot(point.x - optionCenter.x, point.y - optionCenter.y)
            
            if distance < minDistance {
                minDistance = distance
                closest = option
            }
        }
        return closest
    }
    
    private func executeOption(_ option: AddOption) {
        HapticManager.notification(.success)
        switch option {
        case .voice:
            onVoiceExpense()
        case .manual:
            onManualExpense()
        case .recurring:
            onRecurringExpense()
        }
    }
    
    private func closeMenu() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isExpanded = false
            selectedOption = nil
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            RadialAddButton(
                onManualExpense: { print("Manual") },
                onVoiceExpense: { print("Voice") },
                onRecurringExpense: { print("Recurring") }
            )
            .padding(.bottom, 100)
        }
    }
}
