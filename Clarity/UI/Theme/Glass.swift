// Glass.swift
// El vidrio de la Home nueva, con respaldo para iOS 17 (#65).
//
// Liquid Glass es iOS 26. El target sigue en 17, así que el mismo modificador
// pinta vidrio de verdad donde lo hay y un material fino con borde donde no.
// La vista no sabe cuál le ha tocado, y no tiene por qué.

import SwiftUI

extension View {
    /// Tarjeta de vidrio: fondo translúcido, borde fino y esquinas continuas.
    func glassCard(cornerRadius: CGFloat = CornerRadius.large, tint: Color? = nil) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint))
    }
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26, *) {
            content
                .glassEffect(tint.map { Glass.regular.tint($0) } ?? .regular, in: shape)
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5)
                }
                .overlay {
                    if let tint {
                        shape.fill(tint.opacity(0.18))
                    }
                }
        }
    }
}
