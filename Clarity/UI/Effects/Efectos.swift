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
    /// ver la regla 3 de arriba.
    @ViewBuilder
    func ondaAlTocar() -> some View {
        if #available(iOS 26, *) { self } else { modifier(OndaAlTocar()) }
    }
}

private struct OndaAlTocar: ViewModifier {
    @State private var origen: CGPoint = .zero
    @State private var tiempo: Double = 0

    func body(content: Content) -> some View {
        content
            .modifier(OndaModifier(origen: origen, tiempo: tiempo))
            .onTapGesture(coordinateSpace: .local) { punto in
                origen = punto
                tiempo = 0
                withAnimation(.linear(duration: 1.4)) { tiempo = 1.4 }
            }
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
    /// Shader Metal `destello`. En iOS 26 no hace nada: regla 3.
    @ViewBuilder
    func destello<T: Equatable>(cuando disparo: T) -> some View {
        if #available(iOS 26, *) { self } else { modifier(Destello(disparo: disparo)) }
    }
}

private struct Destello<T: Equatable>: ViewModifier {
    let disparo: T
    @State private var progreso: Double = 2  // fuera de la vista = invisible

    func body(content: Content) -> some View {
        content
            .modifier(DestelloModifier(progreso: progreso))
            .onChange(of: disparo) { _, _ in
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
    func temblor<T: Equatable>(cuando disparo: T) -> some View {
        phaseAnimator([0, -7, 7, -5, 5, -2, 0], trigger: disparo) { content, fase in
            content.offset(x: fase)
        } animation: { _ in
            .spring(duration: 0.07, bounce: 0.2)
        }
        .sensoryFeedback(.warning, trigger: disparo)
    }
}

// MARK: - Fondo aurora

/// El fondo de la Home. Sin él, el vidrio no tiene nada que refractar y parece
/// un rectángulo gris. Se recoloca al cambiar de mes, con animación, y el
/// resto del tiempo está quieto: no es un `TimelineView`.
struct HomeFondo: View {
    let mes: Date

    private var semilla: Int { Calendar.current.component(.month, from: mes) }

    var body: some View {
        ZStack {
            DesignTokens.Colors.background
            if #available(iOS 18, *) {
                MeshGradient(width: 3, height: 3, points: puntos, colors: colores)
                    .blur(radius: 36)
                    .opacity(0.6)
                    .animation(.easeInOut(duration: 1.4), value: semilla)
            } else {
                Circle().fill(Color.clarityPrimary.opacity(0.35)).frame(width: 340).blur(radius: 90)
                    .offset(x: -90 + CGFloat(semilla % 3) * 30, y: -160)
                Circle().fill(Color.clarityAccent.opacity(0.28)).frame(width: 320).blur(radius: 90)
                    .offset(x: 120, y: 260 + CGFloat(semilla % 4) * 20)
                    .animation(.easeInOut(duration: 1.4), value: semilla)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    /// Los dos puntos interiores bailan con el mes; los bordes se quedan.
    private var puntos: [SIMD2<Float>] {
        let a = Float(semilla % 5) * 0.06
        let b = Float(semilla % 3) * 0.08
        return [
            [0, 0], [0.5, 0], [1, 0],
            [0, 0.5], [0.35 + a, 0.45 + b], [1, 0.5],
            [0, 1], [0.6 - b, 1], [1, 1],
        ]
    }

    private var colores: [Color] {
        let p = Color.clarityPrimary, i = Color.clarityAccent, r = Color(hex: "#EC4899"), n = DesignTokens.Colors.background
        return semilla.isMultiple(of: 2)
            ? [p, n, i, n, p, n, r, n, i]
            : [i, n, p, n, r, n, p, n, i]
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
}

// MARK: - Vidrio del micro (iOS 26)

extension View {
    /// Agrupa botón y burbuja en un solo contenedor de vidrio para que se
    /// fundan al acercarse, como una gota. Sin iOS 26, no hace nada.
    @ViewBuilder
    func contenedorDeVidrio() -> some View {
        if #available(iOS 26, *) { GlassEffectContainer(spacing: 24) { self } } else { self }
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
    /// La aurora de la Home detrás de listas y formularios. Sin esto cada
    /// pestaña pintaba su negro liso y la barra de vidrio de abajo contrastaba
    /// raro al pasar de la Home a Ajustes o Metas.
    func fondoClarity(mes: Date = Date()) -> some View {
        scrollContentBackground(.hidden)
            .background(HomeFondo(mes: mes))
    }
}
