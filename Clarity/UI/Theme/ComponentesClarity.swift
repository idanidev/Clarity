// ComponentesClarity.swift
// Las piezas del estilo nuevo, compartidas (#65).
//
// La Home y Recurrentes se rediseñaron con tarjetas de vidrio, cabeceras en
// mayúsculas pequeñas, cifras redondeadas y barras de cápsula. El resto de
// pantallas usan estas piezas para hablar igual sin copiar cada una su versión.
//
// Lo que ya existe y también es parte del estilo:
// - `glassCard(cornerRadius:tint:)`  (Glass.swift): la tarjeta de vidrio.
// - `fondoClarity()` y `HomeFondo`   (Efectos.swift): el fondo de la app.
// - `TarjetaButtonStyle`             (Efectos.swift): tarjetas pulsables.
// - `sinHuecoBarraInferior()`        (BarraInferior.swift): scrolls horizontales.

import SwiftUI

// MARK: - Textos

extension View {
    /// Etiqueta pequeña en mayúsculas encima de una cifra: "GASTADO ESTE MES".
    func estiloEtiquetaClarity() -> some View {
        self
            .font(.caption2.weight(.medium))
            .tracking(0.7)
            .textCase(.uppercase)
            .foregroundStyle(Color.textSecondary)
    }

    /// La cifra protagonista de una tarjeta.
    func estiloCifraClarity(tamano: CGFloat = 40) -> some View {
        self
            .font(.system(size: tamano, weight: .bold, design: .rounded))
            .tracking(-1)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
    }
}

/// Cabecera de sección en mayúsculas pequeñas, con un dato opcional a la
/// derecha. Para pantallas hechas con tarjetas; en `List` y `Form` sirve como
/// `header:` de la sección.
struct CabeceraSeccionClarity: View {
    let titulo: String
    var detalle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(titulo)
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(Color.textSecondary)
            Spacer(minLength: 8)
            if let detalle {
                Text(detalle)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 6)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Progreso e iconos

/// Barra de progreso de cápsula. `progreso` va de 0 a 1; lo que sobre se recorta.
struct BarraProgresoClarity: View {
    let progreso: Double
    var color: Color = .clarityPrimary
    var alto: CGFloat = 6

    private var acotado: Double { progreso.isFinite ? min(max(progreso, 0), 1) : 0 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(color)
                    .frame(width: geo.size.width * acotado)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: acotado)
            }
        }
        .frame(height: alto)
        .accessibilityElement()
        .accessibilityValue("\(Int((acotado * 100).rounded())) %")
    }
}

/// Un emoji o un SF Symbol en un círculo del color que toque, como las
/// categorías de la Home.
struct CirculoIconoClarity: View {
    /// Un emoji, o el nombre de un SF Symbol si `esSimbolo` es `true`.
    let icono: String
    var color: Color = .clarityPrimary
    var tamano: CGFloat = 44
    var esSimbolo = false

    var body: some View {
        ZStack {
            Circle().fill(color.opacity(0.22))
            Circle().strokeBorder(color.opacity(0.5), lineWidth: 0.5)
            if esSimbolo {
                Image(systemName: icono)
                    .font(.system(size: tamano * 0.42, weight: .semibold))
                    .foregroundStyle(color)
            } else {
                // Hay iconos guardados con más de un emoji: encogen para caber.
                Text(icono)
                    .font(.system(size: tamano * 0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(tamano * 0.12)
            }
        }
        .frame(width: tamano, height: tamano)
        .accessibilityHidden(true)
    }
}

// MARK: - Botones

/// Botón principal a lo ancho: mango con texto Deep Berry
/// (8:1); el blanco sobre mango no se leería.
struct BotonPrincipalClarity: ButtonStyle {
    @Environment(\.isEnabled) private var activo

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.clarityBerry)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 16)
            .background(
                Color.clarityMango.opacity(activo ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Botón secundario: cápsula tintada, para acciones dentro de una tarjeta.
struct BotonSecundarioClarity: ButtonStyle {
    var color: Color = .clarityPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(color.opacity(0.16), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BotonPrincipalClarity {
    /// `.buttonStyle(.principalClarity)`
    static var principalClarity: BotonPrincipalClarity { BotonPrincipalClarity() }
}

extension ButtonStyle where Self == BotonSecundarioClarity {
    /// `.buttonStyle(.secundarioClarity)`
    static var secundarioClarity: BotonSecundarioClarity { BotonSecundarioClarity() }
}

// MARK: - Estados y filas

/// Estado vacío en una tarjeta de vidrio: icono, título, texto y una acción.
struct EstadoVacioClarity<Accion: View>: View {
    /// SF Symbol.
    let icono: String
    let titulo: String
    let texto: String
    @ViewBuilder var accion: () -> Accion

    var body: some View {
        VStack(spacing: 14) {
            CirculoIconoClarity(icono: icono, tamano: 64, esSimbolo: true)
            VStack(spacing: 6) {
                Text(titulo)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text(texto)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            accion()
                .padding(.top, 4)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .glassCard(cornerRadius: CornerRadius.xlarge)
    }
}

extension EstadoVacioClarity where Accion == EmptyView {
    init(icono: String, titulo: String, texto: String) {
        self.init(icono: icono, titulo: titulo, texto: texto) { EmptyView() }
    }
}

extension View {
    /// Fila de `List` que pinta una tarjeta propia: sin fondo ni separador de
    /// sistema, con el aire de la Home.
    func filaTarjetaClarity(arriba: CGFloat = 5, abajo: CGFloat = 5, lados: CGFloat = Spacing.sm) -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: arriba, leading: lados, bottom: abajo, trailing: lados))
    }
}
