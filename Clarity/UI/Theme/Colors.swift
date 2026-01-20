// Colors.swift
// App color palette - Dark Theme

import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let clarityPrimary = Color(hex: "#8B5CF6")!    // Violet
    static let claritySecondary = Color(hex: "#A855F7")!  // Purple
    static let clarityAccent = Color(hex: "#6366F1")!     // Indigo
    
    // MARK: - Background Colors (Adaptive: OLED Dark vs Standard Light)
    static let bgPrimary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? .black : .systemBackground
    })
    
    static let bgSecondary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.04, green: 0.04, blue: 0.04, alpha: 1) : .secondarySystemBackground
    })
    
    static let bgTertiary = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1) : .tertiarySystemBackground
    })
    
    static let bgCard = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(red: 0.02, green: 0.02, blue: 0.02, alpha: 1) : .secondarySystemGroupedBackground
    })
    
    // Legacy aliases for compatibility
    static let cardBackground = bgSecondary
    static let secondaryBackground = bgTertiary
    static let tertiaryBackground = bgCard
    
    // MARK: - Border Colors
    static let borderDefault = Color(hex: "#2D2D3D")!     // Subtle borders
    static let borderActive = Color(hex: "#8B5CF6")!      // Active/selected
    static let borderSubtle = Color(hex: "#3D3D5C")!      // Very subtle
    
    // MARK: - Text Colors
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.9)
    static let textTertiary = Color.gray
    static let textAccent = Color(hex: "#8B5CF6")!
    
    // MARK: - Semantic Colors
    static let success = Color(hex: "#10B981")!
    static let warning = Color(hex: "#F59E0B")!
    static let error = Color(hex: "#EF4444")!
    static let info = Color(hex: "#3B82F6")!
    
    // MARK: - Category Colors
    static let categoryColors: [String: Color] = [
        "Vivienda": Color(hex: "#3B82F6")!,      // Blue
        "Ocio": Color(hex: "#10B981")!,          // Green
        "Coche/Moto": Color(hex: "#F59E0B")!,    // Amber
        "Compras": Color(hex: "#FBBF24")!,       // Yellow
        "Salud": Color(hex: "#EF4444")!,         // Red
        "Educacion": Color(hex: "#EC4899")!,     // Pink
        "Alimentacion": Color(hex: "#6366F1")!,  // Indigo
        "Transporte": Color(hex: "#14B8A6")!,    // Teal
        "Suscripciones": Color(hex: "#8B5CF6")!, // Violet
        "Otros": Color(hex: "#6B7280")!,         // Gray
    ]
    
    // MARK: - Glassmorphism Colors
    /// Fondos con efecto glass para tarjetas modernas
    static let glassBackground = Color.white.opacity(0.05)
    static let glassBackgroundLight = Color.white.opacity(0.08)
    static let glassBackgroundHeavy = Color.white.opacity(0.12)
    
    /// Bordes glassmórficos
    static let glassBorder = Color.white.opacity(0.1)
    static let glassBorderStrong = Color.white.opacity(0.2)
    
    /// Overlay sutil para efectos de profundidad
    static let glassOverlay = Color.white.opacity(0.03)
    
    // MARK: - Gradients
    static let clarityGradient = LinearGradient(
        colors: [clarityPrimary, claritySecondary],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let clarityGradientVertical = LinearGradient(
        colors: [clarityPrimary, clarityAccent],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let brandGradient = LinearGradient(
        colors: [Color(hex: "#3B82F6")!, Color(hex: "#8B5CF6")!],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let brandGradientDiagonal = LinearGradient(
        colors: [Color(hex: "#8B5CF6")!, Color(hex: "#6366F1")!],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Gradientes Vibrantes Multi-Color
    /// Gradiente vibrante estilo SkillsMP para acentos especiales
    static let vibrantGradient = LinearGradient(
        colors: [
            Color(hex: "#FF6B6B")!,  // Coral
            Color(hex: "#4ECDC4")!,  // Turquesa
            Color(hex: "#45B7D1")!   // Azul cielo
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Gradiente sunset cálido
    static let sunsetGradient = LinearGradient(
        colors: [
            Color(hex: "#FF6B9D")!,  // Rosa
            Color(hex: "#FFA07A")!,  // Salmón
            Color(hex: "#FFD93D")!   // Amarillo dorado
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Gradiente océano fresco
    static let oceanGradient = LinearGradient(
        colors: [
            Color(hex: "#667EEA")!,  // Índigo
            Color(hex: "#764BA2")!,  // Púrpura
            Color(hex: "#F093FB")!   // Rosa claro
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Gradiente aurora boreal
    static let auroraGradient = LinearGradient(
        colors: [
            Color(hex: "#00F260")!,  // Verde brillante
            Color(hex: "#0575E6")!,  // Azul eléctrico
            Color(hex: "#00F260")!   // Verde brillante
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Hex Color Extension
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b)
    }
    
    var hexString: String {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return "#000000"
        }
        let r = Int(components[0] * 255.0)
        let g = Int(components[1] * 255.0)
        let b = Int(components[2] * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
