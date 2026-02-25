// GlassCard.swift
// Componente reutilizable de tarjeta glassmórfica moderna
// Inspirado en el diseño SkillsMP

import SwiftUI

/// Intensidad de la sombra para GlassCard
enum GlassShadowIntensity {
    case none, soft, medium, heavy
}

/// Tarjeta con efecto glassmórfico configurable
struct GlassCard<Content: View>: View {
    let content: Content
    var cornerRadius: CGFloat = CornerRadius.medium
    var blur: Material = .ultraThinMaterial
    var backgroundOpacity: Double = 0.05
    var borderOpacity: Double = 0.1
    var shadowIntensity: GlassShadowIntensity = .medium
    var gradient: LinearGradient? = nil
    
    init(
        cornerRadius: CGFloat = CornerRadius.medium,
        blur: Material = .ultraThinMaterial,
        backgroundOpacity: Double = 0.05,
        borderOpacity: Double = 0.1,
        shadowIntensity: GlassShadowIntensity = .medium,
        gradient: LinearGradient? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.blur = blur
        self.backgroundOpacity = backgroundOpacity
        self.borderOpacity = borderOpacity
        self.shadowIntensity = shadowIntensity
        self.gradient = gradient
    }
    
    var body: some View {
        content
            .background {
                ZStack {
                    // Gradiente de fondo si se proporciona
                    if let gradient = gradient {
                        gradient.opacity(0.15)
                    }
                    
                    // Material blur (wrapped in Rectangle to conform to View)
                    Rectangle()
                        .fill(blur)
                    
                    // Overlay glassmórfico
                    Color.white.opacity(backgroundOpacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
            )
            .applyShadow(intensity: shadowIntensity)
    }
}



// MARK: - Variantes Predefinidas

extension GlassCard where Content == EmptyView {
    /// Tarjeta glass ligera - para elementos sutiles
    static func light<C: View>(@ViewBuilder content: () -> C) -> GlassCard<C> {
        GlassCard<C>(
            blur: .ultraThinMaterial,
            backgroundOpacity: 0.03,
            borderOpacity: 0.08,
            shadowIntensity: .soft,
            content: content
        )
    }
    
    /// Tarjeta glass estándar - uso general
    static func standard<C: View>(@ViewBuilder content: () -> C) -> GlassCard<C> {
        GlassCard<C>(
            blur: .ultraThinMaterial,
            backgroundOpacity: 0.05,
            borderOpacity: 0.1,
            shadowIntensity: .medium,
            content: content
        )
    }
    
    /// Tarjeta glass pronunciada - para elementos destacados
    static func heavy<C: View>(@ViewBuilder content: () -> C) -> GlassCard<C> {
        GlassCard<C>(
            blur: .regularMaterial,
            backgroundOpacity: 0.12,
            borderOpacity: 0.2,
            shadowIntensity: .heavy,
            content: content
        )
    }
    
    /// Tarjeta glass con gradiente - para elementos especiales
    static func withGradient<C: View>(
        _ gradient: LinearGradient,
        @ViewBuilder content: () -> C
    ) -> GlassCard<C> {
        GlassCard<C>(
            blur: .ultraThinMaterial,
            backgroundOpacity: 0.05,
            borderOpacity: 0.15,
            shadowIntensity: .medium,
            gradient: gradient,
            content: content
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        // Fondo oscuro para visualizar el efecto glass
        LinearGradient(
            colors: [.black, Color(hex: "#1a1a2e")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        
        VStack(spacing: 24) {
            // Tarjeta ligera
            GlassCard.light {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tarjeta Ligera")
                        .font(.headline)
                    Text("Efecto glassmórfico sutil para elementos secundarios")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            
            // Tarjeta estándar
            GlassCard.standard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tarjeta Estándar")
                        .font(.headline)
                    Text("Balance perfecto entre visibilidad y sutileza")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            
            // Tarjeta pronunciada
            GlassCard.heavy {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tarjeta Pronunciada")
                        .font(.headline)
                    Text("Máxima visibilidad para elementos importantes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            
            // Tarjeta con gradiente
            GlassCard.withGradient(Color.vibrantGradient) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tarjeta con Gradiente")
                        .font(.headline)
                    Text("Acentos coloridos para elementos especiales")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .padding()
    }
}
