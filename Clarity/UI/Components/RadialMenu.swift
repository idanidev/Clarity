// RadialMenu.swift
// Radial fan menu overlay with drag-to-select

import SwiftUI

struct RadialMenu: View {
    @Binding var isPresented: Bool
    
    let onVoiceTap: () -> Void
    let onManualTap: () -> Void
    let onRecurringTap: () -> Void
    
    @State private var selectedOption: MenuOption? = nil
    @State private var isDragging = false
    
    private let menuRadius: CGFloat = 80
    private let angleThreshold: Double = 35
    private let buttonSize: CGFloat = 56
    
    enum MenuOption: CaseIterable {
        case manual, voice, recurring
        
        var icon: String {
            switch self {
            case .manual: "pencil.line"
            case .voice: "mic.fill"
            case .recurring: "arrow.triangle.2.circlepath"
            }
        }
        
        var label: String {
            switch self {
            case .manual: "Manual"
            case .voice: "Voz"
            case .recurring: "Recurrente"
            }
        }
        
        var angle: Double {
            switch self {
            case .manual: -45
            case .voice: 0
            case .recurring: 45
            }
        }
        
        var color: Color {
            switch self {
            case .manual: .blue
            case .voice: .purple
            case .recurring: .orange
            }
        }
    }
    
    var body: some View {
        ZStack {
            // Backdrop
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    close()
                }
            
            // Menu container
            VStack {
                Spacer()
                
                ZStack {
                    // Options in fan layout
                    ForEach(MenuOption.allCases, id: \.self) { option in
                        optionButton(option)
                            .offset(
                                x: sin(option.angle * .pi / 180) * menuRadius,
                                y: -cos(option.angle * .pi / 180) * menuRadius
                            )
                    }
                    
                    // Center button with drag gesture
                    centerButton
                }
                .padding(.bottom, 80)
            }
        }
        .transition(.opacity)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isPresented)
        .sensoryFeedback(.selection, trigger: selectedOption)
    }
    
    // MARK: - Center Button with Drag
    private var centerButton: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.clarityPrimary, Color.claritySecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: buttonSize, height: buttonSize)
                .shadow(color: Color.clarityPrimary.opacity(0.4), radius: 8, y: 2)
            
            Image(systemName: "xmark")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
        }
        .scaleEffect(isDragging ? 0.9 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    handleDrag(value)
                }
                .onEnded { value in
                    handleDragEnd(value)
                }
        )
        .simultaneousGesture(
            TapGesture()
                .onEnded {
                    close()
                }
        )
    }
    
    // MARK: - Option Button
    private func optionButton(_ option: MenuOption) -> some View {
        Button {
            selectOption(option)
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(selectedOption == option ? option.color.gradient : Color(.systemGray5).gradient)
                        .frame(width: buttonSize, height: buttonSize)
                        .shadow(
                            color: selectedOption == option ? option.color.opacity(0.5) : .black.opacity(0.1),
                            radius: selectedOption == option ? 10 : 4,
                            y: 2
                        )
                    
                    Image(systemName: option.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(selectedOption == option ? .white : .primary)
                }
                .scaleEffect(selectedOption == option ? 1.15 : 1.0)
                
                Text(option.label)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(selectedOption == option ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.2), value: selectedOption)
    }
    
    // MARK: - Drag Handlers
    private func handleDrag(_ value: DragGesture.Value) {
        isDragging = true
        
        let distance = hypot(value.translation.width, value.translation.height)
        
        // Dead zone in center
        if distance < 25 {
            selectedOption = nil
            return
        }
        
        // Calculate angle (0 is up)
        let angle = atan2(value.translation.width, -value.translation.height) * 180 / .pi
        
        // Match to option by angle
        if abs(angle - MenuOption.manual.angle) < angleThreshold {
            selectedOption = .manual
        } else if abs(angle - MenuOption.voice.angle) < angleThreshold {
            selectedOption = .voice
        } else if abs(angle - MenuOption.recurring.angle) < angleThreshold {
            selectedOption = .recurring
        } else {
            selectedOption = nil
        }
    }
    
    private func handleDragEnd(_ value: DragGesture.Value) {
        isDragging = false
        
        if let option = selectedOption {
            selectOption(option)
        } else {
            // If released in center, close
            let distance = hypot(value.translation.width, value.translation.height)
            if distance < 25 {
                close()
            }
        }
    }
    
    // MARK: - Actions
    private func selectOption(_ option: MenuOption) {
        selectedOption = option
        HapticManager.notification(.success)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch option {
            case .manual: onManualTap()
            case .voice: onVoiceTap()
            case .recurring: onRecurringTap()
            }
            close()
        }
    }
    
    private func close() {
        withAnimation(.spring(response: 0.3)) {
            isPresented = false
        }
        selectedOption = nil
    }
}
