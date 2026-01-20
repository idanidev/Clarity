// LiquidGlassCard.swift
// Componente "Liquid Glass" que solo se activa en modo oscuro

import SwiftUI

struct LiquidGlassCard: ViewModifier {
    let color: Color
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        content
            .background(backgroundLayer)
    }
    
    @ViewBuilder
    private var backgroundLayer: some View {
        if colorScheme == .dark {
            ZStack {
                // 1. Capa base oscura (Ambient)
                Color.black.opacity(0.4)
                
                // 2. "Mancha" de color vibrante (Liquid glow)
                // Usamos geometría para colocar el glow de forma estética
                GeometryReader { proxy in
                    Circle()
                        .fill(color)
                        .blur(radius: 60) // Blur intenso para efecto líquido
                        .opacity(0.3)     // Opacidad sutil
                        .offset(x: -proxy.size.width * 0.3, y: -proxy.size.height * 0.4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                
                // 3. Material Glass (Frosted effect)
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.9) // Alta opacidad para mezclar bien
                
                // 4. Borde sutil brillante (Rim light)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.6), // Brillo superior
                                .white.opacity(0.1),
                                .white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: color.opacity(0.25), radius: 15, x: 0, y: 8) // Sombra coloreada
        } else {
            // MARK: - Light Mode Fallback (Diseño limpio standard)
            ZStack {
                Color.white
                Color.bgSecondary // Tinte sutil
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
    }
}

extension View {
    func liquidGlassStyle(color: Color) -> some View {
        modifier(LiquidGlassCard(color: color))
    }
}

// Preview
#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack(spacing: 20) {
            Text("Liquid Glass (Dark Mode Only)")
                .foregroundStyle(.white)
            
            HStack {
                Text("Vivienda 🏠")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                Spacer()
                Text("650,00 €")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
            }
            .liquidGlassStyle(color: .blue)
            .frame(height: 80)
            .padding()
            
            HStack {
                Text("Ocio 🍻")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
                Spacer()
                Text("120,50 €")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding()
            }
            .liquidGlassStyle(color: .pink)
            .frame(height: 80)
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}
