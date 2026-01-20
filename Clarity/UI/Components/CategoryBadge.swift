// CategoryBadge.swift
// Badge moderno para categorías estilo SkillsMP
// Con gradientes personalizados y efectos glassmórficos

import SwiftUI

/// Badge moderno para categorías con efectos visuales mejorados
struct CategoryBadge: View {
    let category: String
    let emoji: String
    var size: BadgeSize = .medium
    var style: BadgeStyle = .glass
    var isSelected: Bool = false
    var onTap: (() -> Void)? = nil
    
    enum BadgeSize {
        case small, medium, large
        
        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 24
            case .large: return 32
            }
        }
        
        var fontSize: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }
        
        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            case .medium: return EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
            case .large: return EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
            }
        }
    }
    
    enum BadgeStyle {
        case glass       // Glassmórfico sutil
        case vibrant     // Con gradiente colorido
        case solid       // Color sólido
    }
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 8) {
                // Emoji de categoría
                Text(emoji)
                    .font(.system(size: size.iconSize))
                
                // Nombre de categoría
                Text(categoryName)
                    .font(size.fontSize)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundStyle(textColor)
            }
            .padding(size.padding)
            .background(backgroundContent)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 1)
            )
            .shadow(
                color: isSelected ? categoryColor.opacity(0.3) : .clear,
                radius: isSelected ? 8 : 0,
                y: isSelected ? 4 : 0
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.bouncy(duration: 0.3), value: isSelected)
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }
    
    // MARK: - Computed Properties
    
    private var categoryName: String {
        // Extraer solo el nombre sin emoji si viene incluido
        category.split(separator: " ").dropFirst().joined(separator: " ")
            .isEmpty ? category : String(category.split(separator: " ").dropFirst().joined(separator: " "))
    }
    
    @ViewBuilder
    private var backgroundContent: some View {
        switch style {
        case .glass:
            ZStack {
                Color.glassBackground
                if isSelected {
                    categoryGradient.opacity(0.2)
                }
            }
        case .vibrant:
            categoryGradient.opacity(isSelected ? 0.3 : 0.15)
        case .solid:
            categoryColor
                .opacity(isSelected ? 0.3 : 0.15)
        }
    }
    
    private var textColor: Color {
        isSelected ? .white : .secondary
    }
    
    private var borderColor: Color {
        if isSelected {
            return categoryColor
        }
        return Color.glassBorder
    }
    
    private var categoryColor: Color {
        // Obtener color basado en la categoría
        getCategoryColor(for: category)
    }
    
    private var categoryGradient: LinearGradient {
        // Gradiente personalizado según categoría
        getCategoryGradient(for: category)
    }
}

// MARK: - Helper Functions

extension CategoryBadge {
    /// Obtiene el color principal para una categoría
    private func getCategoryColor(for category: String) -> Color {
        let cat = category.lowercased()
        
        if cat.contains("vivienda") || cat.contains("casa") || cat.contains("hogar") {
            return Color(hex: "#3B82F6")!  // Azul
        } else if cat.contains("comida") || cat.contains("alimenta") || cat.contains("restaurante") {
            return Color(hex: "#10B981")!  // Verde
        } else if cat.contains("transporte") || cat.contains("coche") || cat.contains("moto") {
            return Color(hex: "#F59E0B")!  // Ámbar
        } else if cat.contains("ocio") || cat.contains("entretenimiento") {
            return Color(hex: "#EC4899")!  // Rosa
        } else if cat.contains("salud") {
            return Color(hex: "#EF4444")!  // Rojo
        } else if cat.contains("educación") || cat.contains("educacion") {
            return Color(hex: "#8B5CF6")!  // Violeta
        } else if cat.contains("compras") {
            return Color(hex: "#FBBF24")!  // Amarillo
        } else {
            return Color(hex: "#6B7280")!  // Gris
        }
    }
    
    /// Obtiene el gradiente personalizado para una categoría
    private func getCategoryGradient(for category: String) -> LinearGradient {
        let cat = category.lowercased()
        
        if cat.contains("vivienda") || cat.contains("casa") {
            return LinearGradient(
                colors: [Color(hex: "#3B82F6")!, Color(hex: "#2563EB")!],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if cat.contains("comida") || cat.contains("alimenta") {
            return LinearGradient(
                colors: [Color(hex: "#10B981")!, Color(hex: "#059669")!],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if cat.contains("transporte") || cat.contains("coche") {
            return LinearGradient(
                colors: [Color(hex: "#F59E0B")!, Color(hex: "#D97706")!],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if cat.contains("ocio") {
            return LinearGradient(
                colors: [Color(hex: "#EC4899")!, Color(hex: "#DB2777")!],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if cat.contains("salud") {
            return LinearGradient(
                colors: [Color(hex: "#EF4444")!, Color(hex: "#DC2626")!],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                colors: [Color(hex: "#8B5CF6")!, Color(hex: "#7C3AED")!],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - Variantes Convenientes

extension CategoryBadge {
    /// Badge pequeño para uso en listas compactas
    static func small(category: String, emoji: String, isSelected: Bool = false) -> CategoryBadge {
        CategoryBadge(category: category, emoji: emoji, size: .small, isSelected: isSelected)
    }
    
    /// Badge estándar para uso general
    static func standard(category: String, emoji: String, isSelected: Bool = false, onTap: (() -> Void)? = nil) -> CategoryBadge {
        CategoryBadge(category: category, emoji: emoji, size: .medium, isSelected: isSelected, onTap: onTap)
    }
    
    /// Badge grande para elementos destacados
    static func large(category: String, emoji: String, isSelected: Bool = false, onTap: (() -> Void)? = nil) -> CategoryBadge {
        CategoryBadge(category: category, emoji: emoji, size: .large, isSelected: isSelected, onTap: onTap)
    }
}

// MARK: - Preview

#Preview("Badges Estilo SkillsMP") {
    ZStack {
        Color.bgPrimary.ignoresSafeArea()
        
        VStack(spacing: 32) {
            // Ejemplo de tags seleccionables
            VStack(alignment: .leading, spacing: 16) {
                Text("Selecciona categorías")
                    .font(.title2)
                    .fontWeight(.bold)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        CategoryBadge(category: "🏡 Vivienda", emoji: "🏡", style: .vibrant, isSelected: true)
                        CategoryBadge(category: "🍕 Comida", emoji: "🍕", style: .vibrant, isSelected: false)
                        CategoryBadge(category: "🚗 Transporte", emoji: "🚗", style: .vibrant, isSelected: true)
                        CategoryBadge(category: "🎮 Ocio", emoji: "🎮", style: .vibrant, isSelected: false)
                        CategoryBadge(category: "💊 Salud", emoji: "💊", style: .vibrant, isSelected: false)
                    }
                }
            }
            
            // Tamaños diferentes
            VStack(alignment: .leading, spacing: 16) {
                Text("Diferentes tamaños")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 12) {
                    CategoryBadge.small(category: "Pequeño", emoji: "🏷️", isSelected: true)
                    CategoryBadge.standard(category: "Mediano", emoji: "🏷️", isSelected: true)
                    CategoryBadge.large(category: "Grande", emoji: "🏷️", isSelected: true)
                }
            }
            
            // Estilos diferentes
            VStack(alignment: .leading, spacing: 16) {
                Text("Diferentes estilos")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 12) {
                    CategoryBadge(category: "Glass", emoji: "✨", style: .glass, isSelected: true)
                    CategoryBadge(category: "Vibrante", emoji: "🌈", style: .vibrant, isSelected: true)
                    CategoryBadge(category: "Sólido", emoji: "🎨", style: .solid, isSelected: true)
                }
            }
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
