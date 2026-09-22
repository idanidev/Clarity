// TarjetasHome.swift
// Lo que comparten la Home normal, la de edición y la galería: la rejilla de
// dos columnas y cómo se pinta cada tarjeta de la disposición (2.4.0).

import SwiftUI

// MARK: - Rejilla

/// Cuánto ocupa cada tarjeta en la rejilla.
nonisolated struct TamanoEnRejilla: LayoutValueKey {
    static let defaultValue: HomeDisposicion.Tamano = .ancha
}

/// Dos columnas: una pequeña ocupa media fila y una ancha la entera. Las filas
/// salen de `HomeDisposicion.filas`, la misma regla que se prueba en el
/// dominio, y en cada fila las dos pequeñas se estiran al alto de la mayor,
/// como los widgets.
///
/// Un `Layout` y no filas de `HStack`: todas las tarjetas son hijas directas
/// del mismo contenedor, así que al cambiar el orden conservan su identidad y
/// se desplazan animadas a su sitio nuevo —el reflujo de la pantalla de
/// inicio— en vez de desaparecer de una fila y aparecer en otra.
struct RejillaHome: Layout {
    var espacio: CGFloat = Spacing.sm

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ancho = proposal.width ?? 360
        let filas = filas(subviews)
        let alto = filas.reduce(0) { $0 + altura(de: $1, subviews, ancho: ancho) }
            + espacio * CGFloat(max(filas.count - 1, 0))
        return CGSize(width: ancho, height: alto)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for fila in filas(subviews) {
            let alto = altura(de: fila, subviews, ancho: bounds.width)
            var x = bounds.minX
            for i in fila {
                let w = ancho(de: subviews[i], total: bounds.width)
                subviews[i].place(at: CGPoint(x: x, y: y), anchor: .topLeading,
                                  proposal: ProposedViewSize(width: w, height: alto))
                x += w + espacio
            }
            y += alto + espacio
        }
    }

    private func filas(_ subviews: Subviews) -> [[Int]] {
        HomeDisposicion.filas(Array(subviews.indices)) { subviews[$0][TamanoEnRejilla.self] }
    }

    private func ancho(de subview: LayoutSubview, total: CGFloat) -> CGFloat {
        subview[TamanoEnRejilla.self] == .ancha ? total : max((total - espacio) / 2, 0)
    }

    private func altura(de fila: [Int], _ subviews: Subviews, ancho total: CGFloat) -> CGFloat {
        fila.map { subviews[$0].sizeThatFits(ProposedViewSize(width: ancho(de: subviews[$0], total: total), height: nil)).height }
            .max() ?? 0
    }
}

// MARK: - Una tarjeta

/// Una tarjeta tal cual se pinta: el contenido de su clase, los últimos
/// gastos o, solo en edición, el aviso de que este mes no tiene nada.
struct CuerpoTarjeta: View {
    let tarjeta: HomeDisposicion.Tarjeta
    let contenidos: [String: HomeResumen.Contenido]
    let ultimos: [Expense]
    let zoom: Namespace.ID
    let onEditar: (Expense, String) -> Void

    var body: some View {
        if let clase = tarjeta.clase, let contenido = contenidos[clase] {
            SlotCard(contenido: contenido, compacta: tarjeta.tamano == .pequena)
        } else if tarjeta.elemento.tipo == .ultimos, !ultimos.isEmpty {
            UltimosCard(gastos: ultimos, zoom: zoom, onEditar: onEditar)
        } else {
            TarjetaSinDatos(tarjeta: tarjeta)
        }
    }
}

/// Solo en edición: una tarjeta colocada que este mes no tiene nada que
/// enseñar. Fuera de edición no se pinta (ningún cuadro vacío, #65), pero aquí
/// tiene que verse para poder moverla o quitarla.
struct TarjetaSinDatos: View {
    let tarjeta: HomeDisposicion.Tarjeta

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(HomeDisposicion.nombre(de: tarjeta.elemento.tipo))
                .estiloEtiquetaClarity()
                .lineLimit(1)
            Text(tarjeta.esPila ? "Nada que enseñar este mes" : "Sin datos este mes")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color.textSecondary)
            if tarjeta.esPila {
                Text("Enseña lo más relevante que no esté ya en tu Home.")
                    .font(.caption)
                    .foregroundStyle(Color.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(tarjeta.tamano == .pequena ? 14 : 16)
        .glassCard()
    }
}

// MARK: - Acciones

/// Lo que se puede hacer con una tarjeta fuera de edición: abrir su pantalla,
/// abrir un gasto de los últimos y lo del menú contextual.
struct AccionesDeTarjeta {
    var abrir: (HomeDestino) -> Void
    var editarGasto: (Expense, String) -> Void
    var editarHome: () -> Void
    var quitar: (String) -> Void
    var cambiarTamano: (String, HomeDisposicion.Tamano) -> Void
    var noEnsenarEnPila: (String) -> Void
}

/// El menú contextual de una tarjeta: entrar en edición, el tamaño si admite
/// los dos, sacar de la pila lo que enseña y quitarla.
struct MenuDeTarjeta: View {
    let tarjeta: HomeDisposicion.Tarjeta
    let acciones: AccionesDeTarjeta

    var body: some View {
        Button { acciones.editarHome() } label: {
            Label("Editar Home", systemImage: "square.grid.2x2")
        }
        let tamanos = HomeDisposicion.tamanos(de: tarjeta.elemento.tipo)
        if tamanos.count > 1 {
            Section("Tamaño") {
                ForEach(HomeDisposicion.Tamano.allCases, id: \.self) { tamano in
                    Button { acciones.cambiarTamano(tarjeta.id, tamano) } label: {
                        Label(tamano.nombre, systemImage: tarjeta.tamano == tamano ? "checkmark" : tamano.icono)
                    }
                }
            }
        }
        if tarjeta.esPila, let clase = tarjeta.clase {
            Button { acciones.noEnsenarEnPila(clase) } label: {
                Label("No enseñar esto en la pila", systemImage: "eye.slash")
            }
        }
        Button(role: .destructive) { acciones.quitar(tarjeta.id) } label: {
            Label(tarjeta.esPila ? "Quitar pila" : "Quitar tarjeta", systemImage: "minus.circle")
        }
    }
}

extension HomeDisposicion.Tamano {
    var nombre: String { self == .pequena ? "Pequeña" : "Ancha" }
    var icono: String { self == .pequena ? "square.split.2x1" : "rectangle" }
    var otro: Self { self == .pequena ? .ancha : .pequena }
}

// MARK: - Destinos

extension HomeDestino {
    /// Cada tarjeta lleva a donde se gestiona lo que enseña.
    init(para contenido: HomeResumen.Contenido) {
        switch contenido {
        case .limites, .hucha, .limiteSugerido: self = .metas
        case .cargos: self = .recurrentes
        case .teDeben: self = .deudas
        case .reparto, .subeFuerte, .sitios, .hormiga, .racha: self = .gastos
        case .diaCaro, .semana, .comparativa, .semanaASemana, .fueraDeNormal, .diaSemana, .ahorro, .ranking: self = .graficas
        }
    }
}
