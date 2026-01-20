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

// MARK: - Sombras Multi-Capa
enum Shadows {
    /// Sombra sutil para elementos elevados ligeramente
    static func soft(color: Color = .black) -> some View {
        EmptyView()
            .shadow(color: color.opacity(0.1), radius: 8, x: 0, y: 2)
            .shadow(color: color.opacity(0.05), radius: 4, x: 0, y: 1)
    }
    
    /// Sombra media para tarjetas standard
    static func medium(color: Color = .black) -> some View {
        EmptyView()
            .shadow(color: color.opacity(0.15), radius: 12, x: 0, y: 4)
            .shadow(color: color.opacity(0.08), radius: 6, x: 0, y: 2)
    }
    
    /// Sombra pronunciada para elementos flotantes
    static func heavy(color: Color = .black) -> some View {
        EmptyView()
            .shadow(color: color.opacity(0.2), radius: 20, x: 0, y: 10)
            .shadow(color: color.opacity(0.12), radius: 12, x: 0, y: 5)
            .shadow(color: color.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Modificadores de Tarjeta Glassmórfica
struct ModernGlassCard: ViewModifier {
    var cornerRadius: CGFloat = CornerRadius.medium
    var blur: Material = .ultraThinMaterial
    var opacity: Double = 0.05
    var borderOpacity: Double = 0.1
    var shadowIntensity: GlassShadowIntensity = .medium
    

    
    func body(content: Content) -> some View {
        content
            .background(blur)
            .background(Color.white.opacity(opacity))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
            )
            .applyShadow(intensity: shadowIntensity)
    }
}

// Extensión para aplicar sombras según intensidad
extension View {
    func applyShadow(intensity: GlassShadowIntensity) -> some View {
        Group {
            switch intensity {
            case .none:
                self
            case .soft:
                self
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
                    .shadow(color: .black.opacity(0.05), radius: 4, y: 1)
            case .medium:
                self
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            case .heavy:
                self
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
                    .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
            }
        }
    }
}



extension View {
    /// Tarjeta con efecto glass moderno y sombras multi-capa
    func modernGlassCard(
        cornerRadius: CGFloat = CornerRadius.medium,
        blur: Material = .ultraThinMaterial,
        opacity: Double = 0.05,
        borderOpacity: Double = 0.1,
        shadowIntensity: GlassShadowIntensity = .medium
    ) -> some View {
        modifier(ModernGlassCard(
            cornerRadius: cornerRadius,
            blur: blur,
            opacity: opacity,
            borderOpacity: borderOpacity,
            shadowIntensity: shadowIntensity
        ))
    }
    
    func liquidGlassCard(color: Color) -> some View {
        modifier(LiquidGlassCard(color: color))
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

// MARK: - Category Colors (Curated Palette)
enum CategoryColors {
    // A simplified palette of 12 distinct, vibrant colors
    static let allCases = [
        red, orange, yellow, green, mint, cyan,
        blue, indigo, purple, pink, brown, gray
    ]
    
    // Vibrant Colors
    static let red = "#FF3B30"
    static let orange = "#FF9500"
    static let yellow = "#FFCC00"
    static let green = "#34C759"
    static let mint = "#00C7BE"
    static let cyan = "#32ADE6"
    
    // Blues & Purples & Neutrals
    static let blue = "#007AFF"
    static let indigo = "#5856D6"
    static let purple = "#AF52DE"
    static let pink = "#FF2D55"
    static let brown = "#A2845E"
    static let gray = "#8E8E93"
}
