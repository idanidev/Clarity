// Colors.swift
// App color palette - Dark Theme

import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let clarityPrimary = Color(hex: "#8B5CF6")!    // Violet
    static let claritySecondary = Color(hex: "#A855F7")!  // Purple
    static let clarityAccent = Color(hex: "#6366F1")!     // Indigo
    
    // MARK: - Background Colors (Dark Theme) - OLED UPDATED
    static let bgPrimary = Color.black                 // Main background (OLED Pure Black)
    static let bgSecondary = Color(hex: "#0A0A0A")!    // Cards, sections (Almost Black)
    static let bgTertiary = Color(hex: "#121212")!     // Inputs, interactive elements
    static let bgCard = Color(hex: "#050505")!         // Subcategories (Very dark)
    
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
