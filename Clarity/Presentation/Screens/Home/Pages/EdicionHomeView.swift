// EdicionHomeView.swift
// La Home en modo edición, como la pantalla de inicio (2.4.0): las tarjetas
// tiemblan, cada una lleva su «−», se arrastran con las demás apartándose y
// las que admiten los dos tamaños llevan un asa para cambiarlo.
//
// Sustituye a la `List` de la Home mientras dura. Un `ScrollView` y no la
// lista porque el arrastre peleaba con ella: la `List` es UIKit por debajo y
// se queda los gestos para desplazar y para deslizar las filas. Aquí no hace
// falta la lista de gastos, así que no se pinta.

import SwiftUI

struct EdicionHomeView: View {
    @Bindable var viewModel: HomeViewModel
    let edicion: HomeEdicion
    var margenSuperior: CGFloat = 0
    let zoom: Namespace.ID

    @Environment(\.medidaBarraInferior) private var barra
    /// El alto de lo que se ve: la rejilla lo ocupa entero para que tocar en
    /// cualquier hueco, también bajo la última tarjeta, salga de la edición.
    @State private var altoVisible: CGFloat = 0

    var body: some View {
        ScrollView {
            RejillaEditable(
                resumen: viewModel.resumen,
                mesAnterior: viewModel.nombreMesAnterior,
                tarjetas: edicion.orden ?? viewModel.tarjetasHome,
                ultimos: viewModel.ultimosGastos,
                edicion: edicion,
                zoom: zoom,
                acciones: acciones
            )
            .frame(minHeight: max(altoVisible - margenSuperior - barra.total - 28, 0), alignment: .top)
            // Detrás de las tarjetas: un toque en un hueco sale de la edición, y
            // uno en una tarjeta no llega aquí.
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { salir() }
                    .accessibilityHidden(true)
            }
        }
        // Mientras se arrastra, el dedo mueve la tarjeta y no la página.
        .scrollDisabled(edicion.arrastrando != nil)
        .contentMargins(.top, margenSuperior, for: .scrollContent)
        .contentMargins(.horizontal, Spacing.sm, for: .scrollContent)
        .contentMargins(.bottom, barra.total + 28, for: .scrollContent)
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { altoVisible = $0 }
        // El gesto de escape de VoiceOver (la Z con dos dedos) también sale.
        .accessibilityAction(.escape) { salir() }
        .onAppear {
            HapticManager.shared.mediumTap()
            AccessibilityNotification.Announcement(
                "Editando la Home. Cada tarjeta tiene acciones para moverla, quitarla o cambiar su tamaño."
            ).post()
        }
        .onDisappear {
            // Al cambiar de pestaña, como la pantalla de inicio: se sale.
            edicion.salir()
            AccessibilityNotification.Announcement("Home guardada").post()
        }
    }

    private func salir() {
        withAnimation(.snappy(duration: AnimationDuration.normal)) { edicion.salir() }
        HapticManager.shared.selection()
    }

    private var acciones: AccionesDeEdicion {
        AccionesDeEdicion(
            quitar: { id in
                withAnimation(.snappy) { viewModel.quitarTarjeta(id) }
                HapticManager.shared.selection()
            },
            cambiarTamano: { id, tamano in
                withAnimation(.snappy) { viewModel.cambiarTamano(id, a: tamano) }
                HapticManager.shared.selection()
            },
            mover: { id, puestos in
                withAnimation(.snappy) { viewModel.moverTarjeta(id, puestos: puestos) }
            },
            ordenar: { ids in viewModel.ordenarTarjetas(ids) }
        )
    }
}

/// Lo que se puede hacer con una tarjeta en edición.
struct AccionesDeEdicion {
    var quitar: (String) -> Void
    var cambiarTamano: (String, HomeDisposicion.Tamano) -> Void
    /// Un puesto antes (−1) o después (+1): VoiceOver no arrastra.
    var mover: (String, Int) -> Void
    var ordenar: ([String]) -> Void
}

// MARK: - Rejilla

/// La cabecera, fija, y las tarjetas en su rejilla, con la copia flotante de
/// la que se arrastra por encima. Sin el `ScrollView` para poder pintarla en
/// las capturas de los tests.
struct RejillaEditable: View {
    let resumen: HomeResumen
    let mesAnterior: String
    let tarjetas: [HomeDisposicion.Tarjeta]
    let ultimos: [Expense]
    let edicion: HomeEdicion
    let zoom: Namespace.ID
    let acciones: AccionesDeEdicion

    var body: some View {
        VStack(spacing: Spacing.sm) {
            // La cabecera no se mueve ni se quita. Sin toques: tocarla es tocar
            // fuera de las tarjetas, y eso sale de la edición.
            HeroCard(resumen: resumen, mesAnterior: mesAnterior, filtrado: nil, animarCifra: false)
                .allowsHitTesting(false)

            if tarjetas.isEmpty {
                Text("No queda ninguna tarjeta. Toca + para añadir.")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.lg)
            }

            RejillaHome {
                ForEach(Array(tarjetas.enumerated()), id: \.element.id) { indice, tarjeta in
                    TarjetaEditable(
                        tarjeta: tarjeta,
                        contenidos: resumen.disponibles,
                        ultimos: ultimos,
                        zoom: zoom,
                        edicion: edicion,
                        esPrimera: indice == 0,
                        esUltima: indice == tarjetas.count - 1,
                        acciones: acciones,
                        alEmpezar: { empezar(tarjeta.id) },
                        alMover: mover,
                        alSoltar: soltar
                    )
                    .layoutValue(key: TamanoEnRejilla.self, value: tarjeta.tamano)
                }
            }
            .coordinateSpace(.named(HomeEdicion.espacio))
            .overlay(alignment: .topLeading) { copiaFlotante }
        }
    }

    /// La tarjeta que se arrastra, pegada al dedo por encima de las demás. En
    /// la rejilla queda su hueco, apagado, que es donde caerá.
    @ViewBuilder
    private var copiaFlotante: some View {
        if let id = edicion.arrastrando, let tarjeta = tarjetas.first(where: { $0.id == id }) {
            let marco = edicion.marcoArrastre
            CuerpoTarjeta(tarjeta: tarjeta, contenidos: resumen.disponibles, ultimos: ultimos, zoom: zoom, onEditar: { _, _ in })
                .opacity(tarjeta.conDatos ? 1 : 0.55)
                .frame(width: marco.width, height: marco.height)
                .scaleEffect(edicion.soltando ? 1 : 1.04)
                .shadow(color: Color.black.opacity(edicion.soltando ? 0 : 0.35), radius: 18, y: 10)
                .offset(x: marco.minX, y: marco.minY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private func empezar(_ id: String) {
        guard edicion.empezarArrastre(id, tarjetas: tarjetas) else { return }
        HapticManager.shared.mediumTap()
    }

    private func mover(traslacion: CGSize, dedo: CGPoint) {
        edicion.seguir(traslacion: traslacion)
        if let nuevo = edicion.reordenar(dedo: dedo) {
            withAnimation(.snappy(duration: AnimationDuration.normal)) { edicion.orden = nuevo }
            HapticManager.shared.selection()
        }
    }

    private func soltar() {
        guard edicion.arrastrando != nil else { return }
        var ids: [String]?
        withAnimation(.snappy(duration: AnimationDuration.fast)) { ids = edicion.soltar() }
        if let ids { acciones.ordenar(ids) }
        Task {
            try? await Task.sleep(for: .milliseconds(Int(AnimationDuration.fast * 1000) + 30))
            edicion.acabarArrastre()
        }
    }
}

// MARK: - Una tarjeta en edición

private struct TarjetaEditable: View {
    let tarjeta: HomeDisposicion.Tarjeta
    let contenidos: [String: HomeResumen.Contenido]
    let ultimos: [Expense]
    let zoom: Namespace.ID
    let edicion: HomeEdicion
    let esPrimera: Bool
    let esUltima: Bool
    let acciones: AccionesDeEdicion
    let alEmpezar: () -> Void
    let alMover: (CGSize, CGPoint) -> Void
    let alSoltar: () -> Void

    /// Verdadero desde que la pulsación larga se cumple hasta que se suelta o
    /// el sistema cancela el gesto; al volver a falso se suelta la tarjeta
    /// también en el caso cancelado, que no pasa por `onEnded`.
    @GestureState private var sujetando = false

    private var nombre: String {
        let tipo = HomeDisposicion.nombre(de: tarjeta.elemento.tipo)
        guard tarjeta.esPila else { return tipo }
        return tarjeta.clase.flatMap { HomeDisposicion.ficha($0)?.nombre }.map { "\(tipo), ahora con \($0)" } ?? tipo
    }

    private var admiteLosDos: Bool { HomeDisposicion.tamanos(de: tarjeta.elemento.tipo).count > 1 }

    var body: some View {
        let arrastrada = edicion.arrastrando == tarjeta.id
        CuerpoTarjeta(tarjeta: tarjeta, contenidos: contenidos, ultimos: ultimos, zoom: zoom, onEditar: { _, _ in })
            // Lo de dentro no se toca en edición: las filas de «Últimos» son
            // botones y se quedarían el dedo del arrastre.
            .allowsHitTesting(false)
            .opacity(tarjeta.conDatos ? 1 : 0.55)
            .overlay(alignment: .topTrailing) {
                if tarjeta.esPila { EtiquetaPila() }
            }
            .overlay(alignment: .bottomTrailing) {
                if admiteLosDos {
                    BotonDeEsquina(icono: tarjeta.tamano == .ancha ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                                   desplazamiento: CGSize(width: 16, height: 16)) {
                        acciones.cambiarTamano(tarjeta.id, tarjeta.tamano.otro)
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                BotonDeEsquina(icono: "minus", desplazamiento: CGSize(width: -18, height: -18)) {
                    acciones.quitar(tarjeta.id)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .tembleque(activo: !arrastrada, semilla: Self.semilla(tarjeta.id), ancha: tarjeta.tamano == .ancha)
            // Su hueco, mientras la copia va con el dedo.
            .opacity(arrastrada ? 0.18 : 1)
            .gesture(arrastre)
            .onChange(of: sujetando) { _, ahora in
                if ahora { alEmpezar() } else { alSoltar() }
            }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(HomeEdicion.espacio)) } action: { marco in
                edicion.marcos[tarjeta.id] = marco
            }
            // Con VoiceOver no se arrastra: todo está en las acciones.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(nombre), \(tarjeta.tamano.nombre.lowercased())\(tarjeta.conDatos ? "" : ", sin datos este mes")")
            .accessibilityHint("Desliza arriba o abajo para moverla, quitarla o cambiar su tamaño.")
            .accessibilityActions {
                if !esPrimera { Button("Mover antes") { acciones.mover(tarjeta.id, -1) } }
                if !esUltima { Button("Mover después") { acciones.mover(tarjeta.id, 1) } }
                Button("Quitar") { acciones.quitar(tarjeta.id) }
                if admiteLosDos {
                    Button(tarjeta.tamano == .ancha ? "Hacer pequeña" : "Hacer ancha") {
                        acciones.cambiarTamano(tarjeta.id, tarjeta.tamano.otro)
                    }
                }
            }
    }

    /// Pulsación corta y arrastrar. La pulsación deja desplazar la página con
    /// un gesto rápido; al cumplirse, la tarjeta se levanta y el dedo la lleva.
    private var arrastre: some Gesture {
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(HomeEdicion.espacio)))
            .updating($sujetando) { valor, estado, _ in
                if case .second(true, _) = valor { estado = true }
            }
            .onChanged { valor in
                guard case .second(true, let arrastre?) = valor, edicion.arrastrando == tarjeta.id else { return }
                alMover(arrastre.translation, arrastre.location)
            }
            .onEnded { _ in alSoltar() }
    }

    /// Estable entre arranques (el `hashValue` de un `String` no lo es): que
    /// cada tarjeta tiemble siempre con su compás.
    private static func semilla(_ id: String) -> Int {
        id.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
    }
}

/// El «−» y el asa de tamaño: un círculo en la esquina, medio fuera de la
/// tarjeta como en la pantalla de inicio, con 44 pt de zona táctil.
private struct BotonDeEsquina: View {
    let icono: String
    let desplazamiento: CGSize
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Image(systemName: icono)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.primary)
                .frame(width: 24, height: 24)
                .background(Color.bgSecondary, in: Circle())
                .overlay { Circle().strokeBorder(Color.borderDefault, lineWidth: 0.5) }
                .shadow(color: Color.black.opacity(0.25), radius: 3, y: 1)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .offset(desplazamiento)
        // Las acciones de la tarjeta ya lo dicen: aquí sería repetirlo.
        .accessibilityHidden(true)
    }
}

/// La marca de las pilas en edición: fuera de ella no se distinguen de una
/// tarjeta puesta a mano, y aquí conviene saber cuál es cuál.
private struct EtiquetaPila: View {
    var body: some View {
        Image(systemName: "square.stack.3d.up.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.clarityPrimary)
            .frame(width: 22, height: 22)
            .background(Color.bgSecondary, in: Circle())
            .overlay { Circle().strokeBorder(Color.clarityPrimary.opacity(0.5), lineWidth: 0.5) }
            .offset(x: 6, y: -6)
            .accessibilityHidden(true)
    }
}

// MARK: - Temblor

extension View {
    /// El temblor de la pantalla de inicio en edición: una rotación pequeña de
    /// ida y vuelta, en sentidos alternos y con compás distinto por tarjeta
    /// para que no se muevan todas a la vez. Las anchas, menos: con el mismo
    /// ángulo sus esquinas se desplazarían el triple. Quieta con «Reducir
    /// movimiento» (y ahí el «−» ya dice que se está editando).
    func tembleque(activo: Bool, semilla: Int, ancha: Bool) -> some View {
        modifier(Tembleque(activo: activo, semilla: semilla, ancha: ancha))
    }
}

private struct Tembleque: ViewModifier {
    let activo: Bool
    let semilla: Int
    let ancha: Bool
    @Environment(\.accessibilityReduceMotion) private var reducirMovimiento
    @State private var fase = false

    private var moviendo: Bool { activo && !reducirMovimiento }

    func body(content: Content) -> some View {
        let amplitud = ancha ? 0.45 : 1.1
        let sentido: Double = semilla.isMultiple(of: 2) ? 1 : -1
        content
            .rotationEffect(.degrees(moviendo ? (fase ? amplitud : -amplitud) * sentido : 0))
            .onAppear { arrancar(moviendo) }
            .onChange(of: moviendo) { _, ahora in arrancar(ahora) }
    }

    private func arrancar(_ ahora: Bool) {
        guard ahora else {
            // Una animación normal sustituye a la que se repetía: se para.
            withAnimation(.easeOut(duration: AnimationDuration.fast)) { fase = false }
            return
        }
        let compas = 0.13 + Double(semilla % 5) * 0.008
        withAnimation(.easeInOut(duration: compas).repeatForever(autoreverses: true).delay(Double(semilla % 7) * 0.03)) {
            fase.toggle()
        }
    }
}
