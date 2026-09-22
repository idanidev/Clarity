// GaleriaTarjetasSheet.swift
// El «+» del modo edición de la Home, como la galería de widgets (2.4.0): cada
// tarjeta con su vista previa, su tamaño y «Añadir», y la pila inteligente.
//
// Las vistas previas llevan los datos de verdad de este mes cuando los hay.
// Cuando no, un ejemplo con cifras normales y dicho como ejemplo: nada de
// «Próximamente» ni de tarjetas vacías, que una tarjeta anunciada que no
// enseña nada es justo lo que App Review rechaza (guideline 2.1).

import SwiftUI

struct GaleriaTarjetasSheet: View {
    @Bindable var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                ContenidoGaleria(
                    disposicion: viewModel.disposicion,
                    contenidos: viewModel.resumen.disponibles,
                    relevancias: viewModel.resumen.relevancias,
                    ultimos: viewModel.ultimosGastos,
                    onAnadir: { tipo, tamano in
                        withAnimation(.snappy) { viewModel.anadirTarjeta(tipo, tamano: tamano) }
                        HapticManager.shared.notification(.success)
                        // Como la de widgets: al añadir se vuelve a la Home, donde
                        // la tarjeta ya está arriba del todo.
                        dismiss()
                    },
                    onDevolver: { clase in
                        withAnimation(.snappy) { viewModel.devolverAPila(clase) }
                        HapticManager.shared.selection()
                    },
                    onRestablecer: {
                        withAnimation(.snappy) { viewModel.restablecerDisposicion() }
                        HapticManager.shared.notification(.success)
                        dismiss()
                    }
                )
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.xl)
            }
            .fondoClarity()
            .navigationTitle("Añadir tarjeta")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .sinHuecoBarraInferior()
    }
}

/// Todo lo de la galería, sin el `ScrollView` ni la barra, para poder pintarlo
/// en las capturas de los tests.
struct ContenidoGaleria: View {
    let disposicion: HomeDisposicion
    let contenidos: [String: HomeResumen.Contenido]
    let relevancias: [String: Double]
    let ultimos: [Expense]
    let onAnadir: (HomeDisposicion.Tipo, HomeDisposicion.Tamano) -> Void
    let onDevolver: (String) -> Void
    let onRestablecer: () -> Void

    @State private var preguntandoRestablecer = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Lo que añadas aparece arriba del todo. Mantenlo pulsado en la Home para llevarlo a su sitio.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .padding(.top, Spacing.xs)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                CabeceraSeccionClarity(titulo: "Pila inteligente")
                FilaGaleria(
                    tipo: .pila,
                    nombre: "Pila inteligente",
                    descripcion: "Enseña sola lo que más importa cada día, de lo que no hayas puesto a mano.",
                    previa: { tamano in previaDePila(tamano) },
                    enLaHome: false,
                    onAnadir: onAnadir
                )
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                CabeceraSeccionClarity(titulo: "Tarjetas")
                ForEach(HomeDisposicion.catalogo) { ficha in
                    FilaGaleria(
                        tipo: .clase(ficha.id),
                        nombre: ficha.nombre,
                        descripcion: ficha.descripcion,
                        previa: { tamano in previaDeClase(ficha.id, tamano) },
                        enLaHome: disposicion.contiene(.clase(ficha.id)),
                        onAnadir: onAnadir
                    )
                }
            }

            if !disposicion.contiene(.ultimos) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    CabeceraSeccionClarity(titulo: "Gastos")
                    FilaGaleria(
                        tipo: .ultimos,
                        nombre: "Últimos gastos",
                        descripcion: "Los tres últimos que apuntaste, para abrirlos de un toque.",
                        previa: { _ in previaDeUltimos },
                        enLaHome: false,
                        onAnadir: onAnadir
                    )
                }
            }

            if !disposicion.ocultas.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    CabeceraSeccionClarity(titulo: "Fuera de la pila")
                    Text("Lo que quitaste de la pila. Puesto a mano sigue saliendo.")
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .padding(.horizontal, 6)
                    // En el orden del catálogo, y lo que esta versión no conoce, al final.
                    let ocultas = HomeDisposicion.catalogo.map(\.id).filter(disposicion.ocultas.contains)
                        + disposicion.ocultas.filter { HomeDisposicion.ficha($0) == nil }.sorted()
                    ForEach(ocultas, id: \.self) { clase in
                        HStack {
                            Text(HomeDisposicion.ficha(clase)?.nombre ?? clase)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Button("Devolver a la pila") { onDevolver(clase) }
                                .buttonStyle(.secundarioClarity)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .glassCard(cornerRadius: CornerRadius.medium)
                    }
                }
            }

            // La salida de la hoja de antes, «Volver a lo de siempre».
            if !disposicion.esLaDeSiempre {
                Button("Volver a la Home de siempre", role: .destructive) { preguntandoRestablecer = true }
                    .font(.subheadline.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.top, Spacing.xs)
                    .confirmationDialog("¿Volver a la Home de siempre?", isPresented: $preguntandoRestablecer,
                                        titleVisibility: .visible) {
                        Button("Volver a la de siempre", role: .destructive) { onRestablecer() }
                    } message: {
                        Text("Se quitan las tarjetas que pusiste y vuelve a enseñar lo que sacaste de la pila.")
                    }
            }
        }
    }

    // MARK: - Vistas previas

    /// Lo que enseñaría una pila nueva: se pone arriba, así que coge lo más
    /// relevante que no esté a mano ni fuera de la pila.
    private func previaDePila(_ tamano: HomeDisposicion.Tamano) -> PreviaDeGaleria {
        var prueba = disposicion
        let id = prueba.anadir(.pila, tamano: tamano, id: "previa") ?? "previa"
        if let clase = prueba.contenidoDePilas(relevancias: relevancias)[id], let contenido = contenidos[clase] {
            return PreviaDeGaleria(contenido: contenido, esEjemplo: false)
        }
        return PreviaDeGaleria(contenido: EjemploDeTarjeta.contenido(tamano == .ancha ? "reparto" : "diaCaro"), esEjemplo: true)
    }

    private func previaDeClase(_ clase: String, _ tamano: HomeDisposicion.Tamano) -> PreviaDeGaleria {
        if let contenido = contenidos[clase] { return PreviaDeGaleria(contenido: contenido, esEjemplo: false) }
        return PreviaDeGaleria(contenido: EjemploDeTarjeta.contenido(clase), esEjemplo: true)
    }

    private var previaDeUltimos: PreviaDeGaleria {
        PreviaDeGaleria(ultimos: ultimos.isEmpty ? EjemploDeTarjeta.ultimos : ultimos, esEjemplo: ultimos.isEmpty)
    }
}

/// Lo que se pinta en la vista previa de una fila de la galería.
struct PreviaDeGaleria {
    var contenido: HomeResumen.Contenido?
    var ultimos: [Expense] = []
    /// Sin datos este mes: un ejemplo, y se dice.
    let esEjemplo: Bool
}

/// Una tarjeta de la galería: su vista previa al tamaño en que quedará, el
/// nombre, para qué sirve, el tamaño si admite los dos y «Añadir».
private struct FilaGaleria: View {
    let tipo: HomeDisposicion.Tipo
    let nombre: String
    let descripcion: String
    let previa: (HomeDisposicion.Tamano) -> PreviaDeGaleria
    let enLaHome: Bool
    let onAnadir: (HomeDisposicion.Tipo, HomeDisposicion.Tamano) -> Void

    @State private var tamano: HomeDisposicion.Tamano?
    /// Uno propio: las previas no pueden ser origen del zoom de la Home, que
    /// tiene sus mismos ids.
    @Namespace private var sinZoom

    private var tamanos: [HomeDisposicion.Tamano] { HomeDisposicion.tamanos(de: tipo) }
    private var elegido: HomeDisposicion.Tamano { tamano ?? tamanos.first ?? .ancha }

    var body: some View {
        let vista = previa(elegido)
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Al tamaño que tendrá en la Home: la pequeña, media fila.
            RejillaHome {
                Group {
                    if let contenido = vista.contenido {
                        SlotCard(contenido: contenido, compacta: elegido == .pequena)
                    } else {
                        UltimosCard(gastos: vista.ultimos, zoom: sinZoom, onEditar: { _, _ in })
                    }
                }
                .layoutValue(key: TamanoEnRejilla.self, value: elegido)
            }
            .opacity(vista.esEjemplo ? 0.6 : 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(nombre).font(.subheadline.weight(.semibold))
                    Text(vista.esEjemplo ? "\(descripcion) Ejemplo: este mes aún no hay datos." : descripcion)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                Spacer(minLength: 4)
                if enLaHome {
                    Label("En tu Home", systemImage: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.textSecondary)
                } else {
                    Button("Añadir") { onAnadir(tipo, elegido) }
                        .buttonStyle(.secundarioClarity)
                        .accessibilityLabel("Añadir \(nombre), \(elegido.nombre.lowercased())")
                }
            }

            if tamanos.count > 1 {
                Picker("Tamaño", selection: Binding(get: { elegido }, set: { tamano = $0 })) {
                    ForEach(tamanos.sorted { $0 == .pequena && $1 == .ancha }, id: \.self) { t in
                        Text(t.nombre).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Ejemplos

/// Lo que enseña una tarjeta sin datos este mes en la galería: cifras
/// corrientes y nombres genéricos, siempre marcado como ejemplo.
enum EjemploDeTarjeta {
    static func contenido(_ clase: String) -> HomeResumen.Contenido? {
        typealias R = HomeResumen
        switch clase {
        case "limites":
            return .limites([R.Limite(categoria: "Restaurantes", gastado: 120, tope: 200),
                             R.Limite(categoria: "Ocio", gastado: 45, tope: 100)])
        case "reparto":
            return .reparto([R.Reparto(categoria: "Alimentación", importe: 320, porcentaje: 41),
                             R.Reparto(categoria: "Vivienda", importe: 250, porcentaje: 32),
                             R.Reparto(categoria: "Transporte", importe: 90, porcentaje: 12)])
        case "cargos":
            return .cargos([R.Cargo(nombre: "Gimnasio", importe: 35, dia: 5),
                            R.Cargo(nombre: "Música", importe: 10.99, dia: 18)], total: 45.99)
        case "teDeben":
            return .teDeben([R.Deuda(nombre: "Ana", importe: 24), R.Deuda(nombre: "Luis", importe: 12.5)], total: 36.5)
        case "hucha":
            return .hucha(R.Hucha(nombre: "Viaje", actual: 450, objetivo: 1200))
        case "diaCaro":
            return .diaCaro(R.DiaCaro(fecha: fechaDeEjemplo, importe: 86.4, concepto: "Compra semanal"))
        case "semana":
            return .semana(R.Semana(actual: 142, anterior: 168))
        case "subeFuerte":
            return .subeFuerte(R.Subida(categoria: "Restaurantes", delta: 48))
        case "comparativa":
            return .comparativa(R.Comparativa(totalAnterior: 610, totalActual: 540, hastaDia: 15, parcial: true))
        case "semanaASemana":
            return .semanaASemana([180, 145, 210, 95])
        case "fueraDeNormal":
            return .fueraDeNormal(R.Desvio(categoria: "Ocio", actual: 130, esperado: 80, normalMensual: 160, porcentaje: 63))
        case "sitios":
            return .sitios([R.Sitio(nombre: "Mercado", veces: 6, total: 96),
                            R.Sitio(nombre: "Cafetería", veces: 9, total: 22.5)])
        case "diaSemana":
            return .diaSemana(R.DiaSemana(dia: 7, media: 42, mediaResto: 21, esHoy: false))
        case "hormiga":
            return .hormiga(R.Hormiga(umbral: 5, cantidad: 14, total: 38.5))
        case "ahorro":
            return .ahorro(R.Ahorro(previsto: 320, porcentaje: 0.15, medio: 0.12))
        case "ranking":
            return .ranking(R.Ranking(posicion: 2, de: 6, referencia: 1180, minimo: 1050, maximo: 1490, proyectado: true))
        case "racha":
            return .racha(R.Racha(dias: 9, record: 14))
        case "limiteSugerido":
            return .limiteSugerido(R.LimiteSugerido(categoria: "Restaurantes", normalMensual: 180, actual: 95))
        default:
            return nil
        }
    }

    static let ultimos: [Expense] = [
        Expense(id: "ejemplo-1", amount: 12.4, name: "Cafetería", category: "Ocio", date: Formatters.localDayString(from: fechaDeEjemplo)),
        Expense(id: "ejemplo-2", amount: 54.9, name: "Supermercado", category: "Alimentación", date: Formatters.localDayString(from: fechaDeEjemplo)),
    ]

    private static var fechaDeEjemplo: Date { Calendar.current.startOfDay(for: Date()) }
}
