// BarraInferior.swift
// La barra de pestañas flota sobre el contenido, no debajo de él (#65).
//
// Antes la barra ocupaba su propia franja bajo el TabView y el contenido se
// cortaba en seco contra ella, como si fueran dos pantallas. Ahora cada pestaña
// llega hasta abajo, deja al final el hueco de la barra y lo que pasa por
// debajo se funde con el fondo.

import SwiftUI

/// Lo que ocupa la barra flotante, medido por quien la pinta.
struct MedidaBarraInferior: Equatable {
    /// Alto de la barra, sin el área segura de debajo.
    var alto: CGFloat
    /// Área segura bajo la barra: el indicador de inicio.
    var margenInferior: CGFloat

    /// Desde el borde inferior de la pantalla hasta el borde superior de la barra.
    var total: CGFloat { alto + margenInferior }
}

extension EnvironmentValues {
    /// Para las vistas que llegan hasta el borde inferior ignorando el área
    /// segura —el carrusel de la Home— y tienen que dejar el hueco a mano.
    @Entry var medidaBarraInferior = MedidaBarraInferior(alto: 66, margenInferior: 34)
}

extension View {
    /// Deja al final de cada lista y scroll de la pestaña el hueco de la barra,
    /// que siguen pasando por debajo de ella.
    ///
    /// Es margen de contenido y no área segura: con `safeAreaInset` sobre la
    /// pestaña el hueco no llegaba a Ajustes ni a Metas —llevan su propio
    /// `NavigationStack` dentro— y la última fila quedaba tapada por la barra.
    /// El margen va por el entorno y sí llega, también a lo que se abre desde
    /// ahí. Los scrolls horizontales lo reponen con `sinHuecoBarraInferior()`.
    func huecoBarraInferior(_ alto: CGFloat) -> some View {
        contentMargins(.bottom, alto, for: .scrollContent)
    }

    /// Para scrolls horizontales dentro de una pestaña: a lo ancho no hay barra
    /// que esquivar, y el hueco heredado haría crecer la fila hacia abajo.
    /// `nil` devuelve el margen que el sistema pone por defecto.
    func sinHuecoBarraInferior() -> some View {
        contentMargins(.bottom, nil, for: .scrollContent)
    }
}

/// Velo detrás de la barra: el contenido que baja se apaga hacia el fondo en
/// vez de cortarse contra ella. Un degradado y no un material: está siempre en
/// pantalla y un desenfoque ahí se recalcula con cada píxel que se desplaza.
struct VeloBarraInferior: View {
    /// Desde el borde inferior de la pantalla, indicador de inicio incluido.
    let alto: CGFloat

    var body: some View {
        // Un contenedor a pantalla completa que ignora el área segura, con el
        // degradado abajo del todo. Con `ignoresSafeArea` sobre el degradado de
        // alto fijo, el velo se quedaba cortado encima del indicador de inicio
        // y lo que pasaba por ahí se leía nítido.
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                stops: [
                    .init(color: DesignTokens.Colors.background.opacity(0), location: 0),
                    .init(color: DesignTokens.Colors.background.opacity(0.72), location: 0.45),
                    .init(color: DesignTokens.Colors.background.opacity(0.95), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: alto)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
