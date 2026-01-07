// DesignSystem.swift
// iOS 26 Design System Foundation - Complementary to existing theme files

import SwiftUI

// MARK: - Corner Radius (iOS 26)
enum CornerRadius {
    static let small: CGFloat = 12    // Buttons pequeños
    static let medium: CGFloat = 16   // Cards, sheets
    static let large: CGFloat = 20    // Modals grandes
    static let xlarge: CGFloat = 28   // Full screen cards
}

// MARK: - Icon Sizes (iOS 26)
enum IconSize {
    static let small: CGFloat = 16    // Inline con texto
    static let medium: CGFloat = 20   // Buttons, tabs
    static let large: CGFloat = 24    // Headers
    static let xlarge: CGFloat = 32   // Empty states
    static let xxlarge: CGFloat = 44  // Pantalla completa
}

// MARK: - Animation Durations
enum AnimationDuration {
    static let instant: Double = 0.1    // Haptic feedback visual
    static let fast: Double = 0.2       // Button press, toggles
    static let normal: Double = 0.3     // Expansions, collapses
    static let slow: Double = 0.5       // Sheets, full screen
}

// MARK: - Liquid Glass View Modifier
struct LiquidGlassCard: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.medium
    var material: Material = .ultraThinMaterial
    
    func body(content: Content) -> some View {
        content
            .background(material)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func liquidGlassCard(
        cornerRadius: CGFloat = CornerRadius.medium,
        material: Material = .ultraThinMaterial
    ) -> some View {
        modifier(LiquidGlassCard(cornerRadius: cornerRadius, material: material))
    }
}

// MARK: - Bouncy Animation Extension
extension Animation {
    static var bouncy: Animation {
        .bouncy(duration: AnimationDuration.normal)
    }
    
    static var bouncyFast: Animation {
        .bouncy(duration: AnimationDuration.fast)
    }
}

// MARK: - Skeleton Loading Modifier
struct SkeletonModifier: ViewModifier {
    @State private var isAnimating = false
    
    func body(content: Content) -> some View {
        content
            .opacity(isAnimating ? 0.4 : 1.0)
            .animation(
                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

extension View {
    func skeleton() -> some View {
        modifier(SkeletonModifier())
    }
}

// MARK: - Skeleton Views
struct SkeletonRect: View {
    var width: CGFloat? = nil
    var height: CGFloat = 20
    
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.tertiary)
            .frame(width: width, height: height)
            .skeleton()
    }
}

struct SkeletonCircle: View {
    var size: CGFloat = 44
    
    var body: some View {
        Circle()
            .fill(.tertiary)
            .frame(width: size, height: size)
            .skeleton()
    }
}

// MARK: - Category Colors (Apple-style palette)
enum CategoryColors {
    static let allCases = [
        // Row 1: Vibrant
        red, orange, yellow, green, mint, cyan,
        // Row 2: Blues & Purples
        blue, indigo, purple, pink, brown, gray,
        // Row 3: Soft pastels
        coral, peach, lavender, mint2, sky, slate
    ]
    
    // Vibrant Colors
    static let red = "#FF3B30"
    static let orange = "#FF9500"
    static let yellow = "#FFCC00"
    static let green = "#34C759"
    static let mint = "#00C7BE"
    static let cyan = "#32ADE6"
    
    // Blues & Purples
    static let blue = "#007AFF"
    static let indigo = "#5856D6"
    static let purple = "#AF52DE"
    static let pink = "#FF2D55"
    static let brown = "#A2845E"
    static let gray = "#8E8E93"
    
    // Soft Pastels
    static let coral = "#FF6B6B"
    static let peach = "#FFAB76"
    static let lavender = "#B4A7D6"
    static let mint2 = "#7FDBCA"
    static let sky = "#87CEEB"
    static let slate = "#708090"
    
    // Legacy aliases for backwards compatibility
    static let amber = orange
    static let violet = purple
    static let emerald = green
    static let teal = mint
}
