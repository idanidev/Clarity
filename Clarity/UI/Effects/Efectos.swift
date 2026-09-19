// Efectos.swift
// Los efectos de la Home nueva (#65). Todos se disparan por un evento —tocar,
// guardar, superar un tope— y ninguno corre en bucle con la pantalla quieta:
// el fondo animado de Análisis ya nos costó los tirones del #63.

import SwiftUI

/// `Shaders.metal` se compila a `default.metallib` dentro del bundle. Si un
/// build sale sin él —un Mac sin el Metal Toolchain, que en Xcode 26 es un
/// componente aparte: `xcodebuild -downloadComponent MetalToolchain`—, los
/// efectos que lo usan se apagan solos en vez de dejar la tarjeta en blanco.
enum Shaders {
    static let disponibles: Bool = Bundle.main.url(forResource: "default", withExtension: "metallib") != nil
}

// Dos reglas que salieron de verlo fallar:
// 1. Los efectos de capa (`distortionEffect`, `colorEffect`) rasterizan lo que
//    envuelven. Van SOBRE el contenido y el vidrio POR FUERA; si envuelven el
//    material, la tarjeta sale negra opaca.
// 2. Dentro de esa capa, `.secondary` y `.tertiary` —estilos vibrantes— se
//    pintan transparentes. Texto secundario con `Color.textSecondary`, que es
//    opacidad explícita y no depende de qué haya debajo.
// 3. En iOS 26, sobre Liquid Glass, TODO el texto es vibrante —también el
//    principal— y dentro de la capa desaparece entero: cifras, nombres, iconos.
//    Ahí los shaders se apagan; el vidrio de iOS 26 ya responde al dedo solo.

// MARK: - Onda desde el dedo

extension View {
    /// Al tocar, una onda sale del punto exacto del dedo y la vista se
    /// estremece. Shader Metal `onda` en Shaders.metal. En iOS 26 no hace nada:
    /// ver la regla 3 de arriba. Con «Reducir movimiento», tampoco.
    @ViewBuilder
    func ondaAlTocar() -> some View {
        if #available(iOS 26, *) { self } else { modifier(OndaAlTocar()) }
    }
}

private struct OndaAlTocar: ViewModifier {
    @State private var origen: CGPoint = .zero
    @State private var tiempo: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    func body(content: Content) -> some View {
        content
            .modifier(OndaModifier(origen: origen, tiempo: tiempo))
            // Simultáneo, no `onTapGesture`: la vista suele ir dentro de un
            // `Button`, y un toque propio se quedaba el gesto y el botón nunca
            // se enteraba — las tarjetas de la Home no llevaban a ningún sitio.
            .simultaneousGesture(
                SpatialTapGesture(coordinateSpace: .local).onEnded { toque in
                    // Con «Reducir movimiento» la tarjeta no se estremece; el
                    // toque sigue llegando al botón igual.
                    guard !reducirMovimiento else { return }
                    origen = toque.location
                    tiempo = 0
                    withAnimation(.linear(duration: 1.4)) { tiempo = 1.4 }
                }
            )
    }
}

/// Animable para que `withAnimation` mueva `tiempo` frame a frame.
private struct OndaModifier: ViewModifier, Animatable {
    var origen: CGPoint
    var tiempo: Double
    var animatableData: Double {
        get { tiempo }
        set { tiempo = newValue }
    }

    func body(content: Content) -> some View {
        content.distortionEffect(
            ShaderLibrary.onda(
                .float2(origen),
                .float(tiempo),
                .float(9),      // amplitud, pt
                .float(16),     // frecuencia
                .float(5),      // decaimiento
                .float(1300)    // velocidad, pt/s
            ),
            maxSampleOffset: CGSize(width: 10, height: 10),
            isEnabled: Shaders.disponibles && tiempo > 0 && tiempo < 1.4
        )
    }
}

// MARK: - Destello

extension View {
    /// Un brillo recorre la vista una vez cada vez que `disparo` cambia.
    /// Shader Metal `destello`. En iOS 26 no hace nada: regla 3. Con «Reducir
    /// movimiento», tampoco.
    @ViewBuilder
    func destello<T: Equatable>(cuando disparo: T) -> some View {
        if #available(iOS 26, *) { self } else { modifier(Destello(disparo: disparo)) }
    }
}

private struct Destello<T: Equatable>: ViewModifier {
    let disparo: T
    @State private var progreso: Double = 2  // fuera de la vista = invisible
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    func body(content: Content) -> some View {
        content
            .modifier(DestelloModifier(progreso: progreso))
            .onChange(of: disparo) { _, _ in
                // Un brillo que cruza la tarjeta también es movimiento.
                guard !reducirMovimiento else { return }
                progreso = 0
                withAnimation(.easeInOut(duration: 0.9)) { progreso = 1 }
            }
    }
}

private struct DestelloModifier: ViewModifier, Animatable {
    var progreso: Double
    var animatableData: Double {
        get { progreso }
        set { progreso = newValue }
    }

    func body(content: Content) -> some View {
        content.visualEffect { view, proxy in
            view.colorEffect(
                ShaderLibrary.destello(.float2(proxy.size), .float(progreso)),
                isEnabled: Shaders.disponibles && progreso >= 0 && progreso <= 1
            )
        }
    }
}

// MARK: - Temblor

extension View {
    /// Tiembla una vez cada vez que `disparo` cambia. Para avisar de que un
    /// tope se ha pasado, junto con un toque háptico de aviso.
    ///
    /// Con «Reducir movimiento» no tiembla, pero el toque háptico se queda: es
    /// lo que sigue avisando.
    func temblor<T: Equatable>(cuando disparo: T) -> some View {
        modifier(Temblor(disparo: disparo))
    }
}

private struct Temblor<T: Equatable>: ViewModifier {
    let disparo: T
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    func body(content: Content) -> some View {
        // Una sola fase = quieto. Cambiar las fases y no la vista: con un `if`
        // la tarjeta se reconstruiría entera al activar el ajuste.
        let fases: [CGFloat] = reducirMovimiento ? [0] : [0, -7, 7, -5, 5, -2, 0]
        content
            .phaseAnimator(fases, trigger: disparo) { vista, fase in
                vista.offset(x: fase)
            } animation: { _ in
                .spring(duration: 0.07, bounce: 0.2)
            }
            .sensoryFeedback(.warning, trigger: disparo)
    }
}

// MARK: - Rebote de símbolo

extension View {
    /// El rebote de un SF Symbol (`symbolEffect(.bounce)`) cada vez que `disparo`
    /// cambia, que con «Reducir movimiento» se queda quieto. El sistema no lo
    /// apaga solo.
    func reboteDeSimbolo<T: Equatable>(cuando disparo: T) -> some View {
        modifier(ReboteDeSimbolo(disparo: disparo))
    }
}

private struct ReboteDeSimbolo<T: Equatable>: ViewModifier {
    let disparo: T
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    func body(content: Content) -> some View {
        content
            .symbolEffect(.bounce, value: disparo)
            .symbolEffectsRemoved(reducirMovimiento)
    }
}

// MARK: - Fondo

/// El fondo de la app: negro con un brillo violeta arriba que se apaga hacia la
/// mitad. Sin nada detrás, el vidrio no tiene qué refractar y parece gris plano.
///
/// Antes era una aurora de varios colores que cambiaba con el mes. Se comparó
/// con este brillo y con negro liso, y se eligió el brillo: la aurora quedaba
/// detrás de las tarjetas y llamaba más que los importes. Es estático, así que
/// no se recalcula nunca.
struct HomeFondo: View {
    enum Intensidad {
        /// Ajustes, Metas, Recurrentes y detrás de la barra de pestañas.
        case normal
        /// La Home: el brillo cae detrás de la barra del mes y con la
        /// intensidad normal apenas se veía.
        case home
    }

    var intensidad: Intensidad = .normal

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
            EllipticalGradient(
                colors: intensidad == .home
                    ? [Color.clarityPrimary.opacity(0.6), Color.clarityPrimary.opacity(0.2), .clear]
                    : [Color.clarityPrimary.opacity(0.42), Color.clarityPrimary.opacity(0.12), .clear],
                center: UnitPoint(x: 0.5, y: 0),
                startRadiusFraction: 0,
                endRadiusFraction: intensidad == .home ? 0.8 : 0.65
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Zoom al detalle

extension View {
    /// La vista desde la que se hace zoom. En iOS 17 no hace nada.
    @ViewBuilder
    func origenZoom(id: String, en ns: Namespace.ID) -> some View {
        if #available(iOS 18, *) { matchedTransitionSource(id: id, in: ns) } else { self }
    }

    /// La pantalla que crece desde `origenZoom` y vuelve a encogerse al salir.
    @ViewBuilder
    func transicionZoom(id: String, en ns: Namespace.ID) -> some View {
        if #available(iOS 18, *) { navigationTransition(.zoom(sourceID: id, in: ns)) } else { self }
    }

    /// El zoom para HOJAS CON TECLADO, que va por versión de iOS porque cada una
    /// falla de una manera (verificado con usuarios reales, 2.2.0–2.2.2):
    /// - iOS 18–26: con zoom. Presentada como hoja normal, en iOS 26 la app se
    ///   quedaba congelada al abrir el formulario en algunos iPhone.
    /// - iOS 27+: sin zoom. Allí es el zoom —con la barra del teclado— lo que
    ///   dejaba el formulario bloqueado.
    /// No unificar sin probar en las dos.
    @ViewBuilder
    func transicionZoomDeHoja(id: String, en ns: Namespace.ID) -> some View {
        if #available(iOS 27, *) {
            self
        } else if #available(iOS 18, *) {
            navigationTransition(.zoom(sourceID: id, in: ns))
        } else {
            self
        }
    }
}

// MARK: - Vidrio del micro (iOS 26)

extension View {
    /// Agrupa botón y burbuja en un solo contenedor de vidrio para que se
    /// fundan al acercarse, como una gota. Sin iOS 26, no hace nada.
    @ViewBuilder
    ///
    /// - Parameter espaciado: a qué distancia empiezan a fundirse dos piezas.
    ///   Con controles que deben verse separados, poco; con una gota que sale
    ///   de un botón, más.
    func contenedorDeVidrio(espaciado: CGFloat = 24) -> some View {
        if #available(iOS 26, *) { GlassEffectContainer(spacing: espaciado) { self } } else { self }
    }

    /// Botón redondo de vidrio teñido, que se hunde bajo el dedo.
    @ViewBuilder
    func vidrioDeBoton(tinte: Color) -> some View {
        if #available(iOS 26, *) { glassEffect(.regular.tint(tinte).interactive(), in: Circle()) } else { self }
    }

    /// Burbuja de vidrio; en iOS 17 el fondo plano de siempre.
    @ViewBuilder
    func vidrioDeBurbuja() -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            background(Color(.secondarySystemBackground)).cornerRadius(12)
        }
    }
}

// MARK: - Tarjeta pulsable

/// Las tarjetas de la Home son botones: al pulsar se encogen un poco y se
/// apagan, como los widgets de la pantalla de inicio. Sin fondo propio para no
/// pisar el vidrio.
struct TarjetaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Fondo de la app

extension View {
    /// El fondo de la app detrás de listas y formularios. Sin esto cada
    /// pestaña pintaba su negro liso y la barra de vidrio de abajo contrastaba
    /// raro al pasar de la Home a Ajustes o Metas.
    func fondoClarity() -> some View {
        scrollContentBackground(.hidden)
            .background(HomeFondo())
    }
}
