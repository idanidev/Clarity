// TabBarCenterButton.swift
// Center button overlay for TabBar with radial menu

import SwiftUI

@MainActor
struct TabBarCenterButton: View {
    
    // MARK: - Callbacks
    let onVoiceTap: () -> Void
    let onManualTap: () -> Void
    let onRecurringTap: () -> Void
    
    // MARK: - State
    @State private var isExpanded = false
    @State private var selectedOption: MenuOption? = nil
    @State private var isDragging = false
    
    // MARK: - Constants
    private let buttonSize: CGFloat = 56
    private let optionSize: CGFloat = 50
    private let menuRadius: CGFloat = 80
    private let angleThreshold: Double = 35
    
    // MARK: - Menu Options
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
            // MARK: - Backdrop
            if isExpanded {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeMenu()
                    }
                    .transition(.opacity)
            }
            
            // MARK: - Menu Options
            if isExpanded {
                ForEach(MenuOption.allCases, id: \.self) { option in
                    optionButton(for: option)
                        .offset(
                            x: sin(option.angle * .pi / 180) * menuRadius,
                            y: -cos(option.angle * .pi / 180) * menuRadius
                        )
                        .scaleEffect(selectedOption == option ? 1.15 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)
                        .animation(.spring(response: 0.2), value: selectedOption)
                }
            }
            
            // MARK: - Main Button
            mainButton
        }
        .sensoryFeedback(.selection, trigger: selectedOption)
    }
    
    // MARK: - Main Button
    private var mainButton: some View {
        ZStack {
            // Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.clarityPrimary.opacity(0.4), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 40
                    )
                )
                .frame(width: buttonSize + 16, height: buttonSize + 16)
                .blur(radius: 6)
            
            // Button
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.clarityPrimary, Color.claritySecondary],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: buttonSize, height: buttonSize)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                }
                .shadow(color: Color.clarityPrimary.opacity(0.4), radius: 10, y: 4)
            
            // Icon: + que rota a ×
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(isExpanded ? 45 : 0))
        }
        .scaleEffect(isExpanded ? 0.9 : 1.0)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)
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
                    toggleMenu()
                }
        )
    }
    
    // MARK: - Option Button
    private func optionButton(for option: MenuOption) -> some View {
        Button {
            selectOption(option)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(selectedOption == option ? option.color.gradient : Color(.systemGray5).gradient)
                        .frame(width: optionSize, height: optionSize)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                    
                    Image(systemName: option.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(selectedOption == option ? .white : .primary)
                }
                
                Text(option.label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(selectedOption == option ? .primary : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Gesture Handlers
    
    private func handleDrag(_ value: DragGesture.Value) {
        let distance = hypot(value.translation.width, value.translation.height)
        
        // Abrir menú si arrastra hacia arriba
        if !isExpanded && distance > 20 && value.translation.height < 0 {
            openMenu()
            isDragging = true
        }
        
        guard isExpanded else { return }
        
        // Zona muerta central
        if distance < 30 {
            selectedOption = nil
            return
        }
        
        // Calcular ángulo
        let angle = atan2(value.translation.width, -value.translation.height) * 180 / .pi
        
        // Detectar opción por ángulo
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
        if isDragging, let option = selectedOption {
            selectOption(option)
        }
        isDragging = false
    }
    
    // MARK: - Actions
    
    private func toggleMenu() {
        if isExpanded {
            closeMenu()
        } else {
            openMenu()
        }
    }
    
    private func openMenu() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            isExpanded = true
        }
        HapticManager.impact(.medium)
    }
    
    private func closeMenu() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            isExpanded = false
            selectedOption = nil
        }
    }
    
    private func selectOption(_ option: MenuOption) {
        HapticManager.notification(.success)
        
        // Delay para feedback visual
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            switch option {
            case .manual:
                onManualTap()
            case .voice:
                onVoiceTap()
            case .recurring:
                onRecurringTap()
            }
            closeMenu()
        }
    }
}

// MARK: - Preview
#Preview {
    ZStack {
        Color(.systemBackground).ignoresSafeArea()
        
        VStack {
            Spacer()
            TabBarCenterButton(
                onVoiceTap: { print("Voice") },
                onManualTap: { print("Manual") },
                onRecurringTap: { print("Recurring") }
            )
            .padding(.bottom, 80)
        }
    }
}
