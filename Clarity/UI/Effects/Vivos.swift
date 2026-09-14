// Vivos.swift
// Detalles que dan vida a la app (#65): la carga que respira, el confeti, la
// tarjeta de enhorabuena y la barra que ondula cerca del límite.
//
// Las ideas vienen de Material 3 Expressive —cargas que cambian de forma,
// progreso ondulado, movimiento con muelles—, pero pintadas con lo nativo de
// SwiftUI para que la app siga sintiéndose de iOS. Todo respeta "Reducir
// movimiento": sin animación continua, lo mismo quieto.

import SwiftUI

// MARK: - Carga

/// Lo que se ve mientras llegan los datos: una forma morada que respira y pasa
/// de círculo a cuadrado redondeado, en lugar de bloques grises.
struct CargaClarity: View {
    var texto: String? = nil
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    var body: some View {
        VStack(spacing: 18) {
            Group {
                if reducirMovimiento {
                    forma(fase: 0.5, giro: 0)
                } else {
                    TimelineView(.animation(minimumInterval: 1.0 / 60)) { contexto in
                        let t = contexto.date.timeIntervalSinceReferenceDate
                        forma(fase: (sin(t * 2.4) + 1) / 2, giro: t * 70)
                    }
                }
            }
            .frame(width: 56, height: 56)

            if let texto {
                Text(texto)
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(texto ?? "Cargando")
    }

    private func forma(fase: Double, giro: Double) -> some View {
        RoundedRectangle(cornerRadius: 28 - 14 * fase, style: .continuous)
            .fill(Color.clarityPrimary.gradient)
            .scaleEffect(0.8 + 0.2 * fase)
            .rotationEffect(.degrees(giro))
            .shadow(color: Color.clarityPrimary.opacity(0.5), radius: 6 + 12 * fase)
    }
}

// MARK: - Confeti

/// Papelitos de colores que caen desde arriba durante un par de segundos.
/// No se puede tocar: va por encima de todo sin quitar toques.
struct ConfetiClarity: View {
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var inicio = Date()
    @State private var piezas: [Pieza] = (0..<80).map { _ in Pieza() }

    private let duracion: Double = 2.8

    struct Pieza {
        let x = Double.random(in: 0...1)
        let retraso = Double.random(in: 0...0.4)
        let velocidad = Double.random(in: 0.75...1.3)
        let deriva = Double.random(in: -0.15...0.15)
        let giro = Double.random(in: -7...7)
        let tamano = Double.random(in: 6...10)
        let color = [Color.clarityPrimary, Color.claritySecondary, Color.clarityAccent,
                     Color.success, Color.warning].randomElement() ?? Color.clarityPrimary
    }

    var body: some View {
        if !reducirMovimiento {
            TimelineView(.animation(minimumInterval: 1.0 / 60)) { contexto in
                let t = contexto.date.timeIntervalSince(inicio)
                Canvas { ctx, tamanoLienzo in
                    for pieza in piezas {
                        let tp = max(0, t - pieza.retraso) * pieza.velocidad
                        guard tp < duracion else { continue }
                        // Cae acelerando, con algo de deriva lateral.
                        let y = -24 + tp * tamanoLienzo.height * 0.14 + tp * tp * tamanoLienzo.height * 0.1
                        let x = (pieza.x + pieza.deriva * tp) * tamanoLienzo.width
                        var capa = ctx
                        capa.opacity = tp > duracion - 0.7 ? max(0, (duracion - tp) / 0.7) : 1
                        capa.translateBy(x: x, y: y)
                        capa.rotate(by: .radians(pieza.giro * tp))
                        let rect = CGRect(x: -pieza.tamano / 2, y: -pieza.tamano * 0.3,
                                          width: pieza.tamano, height: pieza.tamano * 0.6)
                        capa.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(pieza.color))
                    }
                }
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Enhorabuena

/// Tarjeta de enhorabuena con confeti y vibración de éxito. Se cierra al
/// tocarla, al tocar fuera o sola a los pocos segundos.
struct CelebracionClarity: View {
    /// SF Symbol.
    let icono: String
    let titulo: String
    let detalle: String
    let onCerrar: () -> Void

    @State private var visible = false
    @State private var cerrando = false

    var body: some View {
        ZStack {
            Color.black.opacity(visible ? 0.4 : 0)
                .ignoresSafeArea()
                .onTapGesture { cerrar() }

            ConfetiClarity()

            VStack(spacing: 14) {
                CirculoIconoClarity(icono: icono, color: .success, tamano: 68, esSimbolo: true)
                    .symbolEffect(.bounce, value: visible)

                Text(titulo)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(detalle)
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)

                Button("Genial") { cerrar() }
                    .buttonStyle(.principalClarity)
                    .padding(.top, 6)
            }
            .padding(24)
            .frame(maxWidth: 340)
            .glassCard(cornerRadius: CornerRadius.xlarge)
            .padding(.horizontal, Spacing.lg)
            .scaleEffect(visible ? 1 : 0.85)
            .opacity(visible ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) { visible = true }
            HapticManager.shared.notification(.success)
        }
        .task {
            try? await Task.sleep(for: .seconds(7))
            cerrar()
        }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    private func cerrar() {
        guard !cerrando else { return }
        cerrando = true
        withAnimation(.easeOut(duration: 0.2)) { visible = false }
        Task {
            try? await Task.sleep(for: .milliseconds(220))
            onCerrar()
        }
    }
}

// MARK: - Barra ondulada

/// Barra de progreso que ondula, para cuando te acercas al límite. Ocupa lo
/// mismo que una barra normal, así que se puede cambiar una por otra sin que
/// salte nada; la onda asoma un poco por arriba y por abajo.
struct BarraOndulada: View {
    let progreso: Double
    var color: Color
    var alto: CGFloat = 6
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento

    private var acotado: Double { progreso.isFinite ? min(max(progreso, 0), 1) : 0 }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))

                Group {
                    if reducirMovimiento {
                        onda(fase: 0)
                    } else {
                        // A 30 fotogramas basta para una onda lenta y gasta la mitad.
                        TimelineView(.animation(minimumInterval: 1.0 / 30)) { contexto in
                            onda(fase: contexto.date.timeIntervalSinceReferenceDate * 5)
                        }
                    }
                }
                .frame(width: geo.size.width * acotado)
            }
        }
        .frame(height: alto)
        .accessibilityElement()
        .accessibilityValue("\(Int((acotado * 100).rounded())) %")
    }

    private func onda(fase: Double) -> some View {
        Onda(fase: fase, amplitud: alto * 0.45, longitud: 16, grosor: alto)
            .stroke(color, style: StrokeStyle(lineWidth: alto, lineCap: .round, lineJoin: .round))
    }
}

/// Una línea senoidal de lado a lado, a media altura.
private struct Onda: Shape {
    var fase: Double
    var amplitud: CGFloat
    var longitud: CGFloat
    /// El trazo redondo sobresale medio grosor por cada lado: se descuenta.
    var grosor: CGFloat

    func path(in rect: CGRect) -> Path {
        var camino = Path()
        let desde = rect.minX + grosor / 2
        let hasta = max(desde, rect.maxX - grosor / 2)
        var x = desde
        var primero = true
        while x <= hasta {
            let y = rect.midY + sin(Double((x - desde) / longitud) * 2 * .pi + fase) * amplitud
            if primero {
                camino.move(to: CGPoint(x: x, y: y))
                primero = false
            } else {
                camino.addLine(to: CGPoint(x: x, y: y))
            }
            x += 1.5
        }
        return camino
    }
}
