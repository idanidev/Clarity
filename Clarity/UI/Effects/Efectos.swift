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

// MARK: - Onda desde el dedo

extension View {
    /// Al tocar, una onda sale del punto exacto del dedo y la vista se
    /// estremece. Shader Metal `onda` en Shaders.metal.
    func ondaAlTocar() -> some View { modifier(OndaAlTocar()) }
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
    /// Shader Metal `destello`.
    func destello<T: Equatable>(cuando disparo: T) -> some View {
        modifier(Destello(disparo: disparo))
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
