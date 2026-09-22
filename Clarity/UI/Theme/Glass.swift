// Glass.swift
// El vidrio de la Home nueva, con respaldo para iOS 17 (#65).
//
// Liquid Glass es iOS 26. El target sigue en 17, así que el mismo modificador
// pinta vidrio de verdad donde lo hay y un material fino con borde donde no.
// La vista no sabe cuál le ha tocado, y no tiene por qué.

import SwiftUI

extension View {
    /// Tarjeta de vidrio: fondo translúcido, borde fino y esquinas continuas.
    ///
    /// - Parameter interactivo: en iOS 26 el vidrio reacciona al dedo —se
    ///   ilumina y cede un poco— como los controles del sistema. Para tarjetas
    ///   que se pueden tocar; en las que solo enseñan datos, mejor quieto.
    func glassCard(cornerRadius: CGFloat = CornerRadius.large, tint: Color? = nil, interactivo: Bool = false) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, tint: tint, interactivo: interactivo))
    }
}

extension EnvironmentValues {
    /// Pinta el vidrio de antes de iOS 26 también en iOS 26. Solo para las
    /// capturas de los tests: `ImageRenderer` no sabe pintar Liquid Glass, y el
    /// texto encima, que es vibrante, sale transparente. La app no lo toca.
    @Entry var vidrioSinLiquidGlass = false
}

private struct GlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color?
    let interactivo: Bool
    @Environment(\.vidrioSinLiquidGlass) private var sinLiquidGlass

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(iOS 26, *), !sinLiquidGlass {
            let vidrio = tint.map { Glass.regular.tint($0) } ?? .regular
            content
                .glassEffect(vidrio.interactive(interactivo), in: shape)
        } else {
            // El material a secas sale casi negro sobre fondo oscuro y la tarjeta
            // parece un rectángulo opaco: el velo blanco es lo que la lee como vidrio.
            content
                .background(Color.white.opacity(0.035), in: shape)
                .background(Color.black.opacity(0.22), in: shape)
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
                }
                .overlay {
                    if let tint {
                        shape.fill(tint.opacity(0.18))
                    }
                }
        }
    }
}
