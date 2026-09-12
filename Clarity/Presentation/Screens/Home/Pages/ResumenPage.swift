// ResumenPage.swift
// Primera página de la Home: cuánto llevas, y ningún cuadro vacío (#65).

import SwiftUI

struct ResumenPage: View {
    @Bindable var viewModel: HomeViewModel
    let onEditar: (Expense) -> Void
    let onVerGastos: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                let r = viewModel.resumen

                HeroCard(resumen: r)
                    .entrada()

                if let a = r.slots[.a] { SlotCard(contenido: a).entrada() }

                if r.slots[.b] != nil || r.slots[.c] != nil {
                    HStack(alignment: .top, spacing: Spacing.xs) {
                        if let b = r.slots[.b] { SlotCard(contenido: b, compacta: true) }
                        if let c = r.slots[.c] { SlotCard(contenido: c, compacta: true) }
                    }
                    .entrada()
                }

                CategoriasCard(grupos: viewModel.categoryGroups, total: r.total, numero: r.numeroGastos, onVerGastos: onVerGastos)
                    .entrada()

                UltimosCard(gastos: viewModel.ultimosGastos, onEditar: onEditar)
                    .entrada()

                if let e = r.slots[.e] { SlotCard(contenido: e).entrada() }

                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xs)
        }
        .scrollIndicators(.hidden)
        .trackScreen("home")
    }
}

// MARK: - Entrada escalonada al desplazar

private extension View {
    /// Aparece al entrar en pantalla y se apaga al salir por arriba. Va ligado
    /// al desplazamiento, no a un reloj: con la pantalla quieta no cuesta nada.
    func entrada() -> some View {
        scrollTransition(.interactive) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.4)
                .scaleEffect(phase.isIdentity ? 1 : 0.97)
        }
    }
}

// MARK: - Cabecera: total, presupuesto y ritmo

private struct HeroCard: View {
    let resumen: HomeResumen
    /// La cifra sube desde cero al aparecer: los dígitos ruedan hasta el total.
    @State private var mostrado = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("GASTADO ESTE MES")
                    .font(.caption2.weight(.medium))
                    .tracking(0.7)
                    .foregroundStyle(.secondary)
                Spacer()
                chip
            }

            Text(Formatters.currency(mostrado ? resumen.total : 0))
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .tracking(-1.2)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                // Los dígitos ruedan al nuevo valor en vez de parpadear.
                .contentTransition(.numericText(value: mostrado ? resumen.total : 0))
                .animation(.snappy(duration: 0.9), value: mostrado)
                .animation(.snappy(duration: 0.5), value: resumen.total)
                .padding(.top, 4)
                .onAppear { mostrado = true }

            if let progreso = resumen.progresoPresupuesto, let libres = resumen.libres, let presupuesto = resumen.presupuesto {
                Barra(progreso: progreso, color: .clarityPrimary)
                    .padding(.top, 14)
                HStack {
                    Text("\(Int((progreso * 100).rounded())) % del presupuesto · \(Formatters.currency(presupuesto))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Formatters.currency(libres)) libres")
                        .foregroundStyle(libres >= 0 ? Color.success : Color.error)
                        .fontWeight(.medium)
                }
                .font(.footnote)
                .padding(.top, 8)
            } else {
                Text("A este ritmo acabarás el mes en **\(Formatters.currency(resumen.ritmo.prevision))**.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }

            Divider().padding(.vertical, 14)

            HStack {
                Dato("Media diaria", Formatters.currency(resumen.ritmo.mediaDiaria))
                Dato(resumen.presupuesto != nil ? "Previsión" : "Gastos",
                     resumen.presupuesto != nil ? Formatters.currency(resumen.ritmo.prevision) : "\(resumen.numeroGastos)")
                Dato("Quedan", "\(resumen.ritmo.diasRestantes) días")
            }
        }
        .padding(20)
        .glassCard(cornerRadius: CornerRadius.xlarge)
        .ondaAlTocar()
    }

    @ViewBuilder
    private var chip: some View {
        if let c = resumen.comparativa {
            let baja = c.delta <= 0
            Label("\(abs(c.porcentaje)) % \(baja ? "menos" : "más") que el mes pasado",
                  systemImage: baja ? "arrow.down.right" : "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(baja ? Color.success : Color.error)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background((baja ? Color.success : Color.error).opacity(0.16), in: Capsule())
        } else if resumen.diasApuntando > 0 {
            Text("\(resumen.diasApuntando) días apuntando")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(Color.primary.opacity(0.08), in: Capsule())
        }
    }
}

private struct Dato: View {
    let titulo: String
    let valor: String
    init(_ titulo: String, _ valor: String) { self.titulo = titulo; self.valor = valor }
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(titulo).font(.caption).foregroundStyle(.secondary)
            Text(valor).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Barra de progreso con muelle: se pasa un poco y vuelve.
private struct Barra: View {
    let progreso: Double
    let color: Color
    var alto: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule().fill(color)
                    .frame(width: geo.size.width * progreso)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progreso)
            }
        }
        .frame(height: alto)
    }
}

// MARK: - Los huecos

private struct SlotCard: View {
    let contenido: HomeResumen.Contenido
    var compacta = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch contenido {
            case .limites(let limites): limitesView(limites)
            case .reparto(let reparto): repartoView(reparto)
            case .cargos(let cargos, let total): cargosView(cargos, total)
            case .teDeben(let deudas, let total): teDebenView(deudas, total)
            case .hucha(let h): huchaView(h)
            case .diaCaro(let d): diaCaroView(d)
            case .semana(let s): semanaView(s)
            case .subeFuerte(let s): subeView(s)
            case .comparativa(let c): comparativaView(c)
            case .semanaASemana(let semanas): semanaASemanaView(semanas)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compacta ? 14 : 16)
        .glassCard(tint: tinte)
        .ondaAlTocar()
        .temblor(cuando: superados)
    }

    /// Cambia cuando un límite pasa a estar superado: dispara el temblor.
    private var superados: Int {
        if case .limites(let l) = contenido { return l.filter(\.superado).count }
        return 0
    }

    private var tinte: Color? {
        if case .limites(let l) = contenido, l.first?.superado == true { return .error }
        return nil
    }

    private func titulo(_ t: String) -> some View {
        Text(t.uppercased()).font(.caption2.weight(.medium)).tracking(0.5).foregroundStyle(.secondary)
    }

    // Límites
    private func limitesView(_ limites: [HomeResumen.Limite]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            titulo("Límites")
            ForEach(limites.prefix(3)) { l in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(l.categoria).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(Formatters.currency(l.gastado)).fontWeight(.semibold).foregroundStyle(l.superado ? Color.error : .primary)
                        + Text(" / \(Formatters.currency(l.tope))").foregroundStyle(.secondary)
                    }
                    .font(.footnote)
                    Barra(progreso: l.progreso, color: l.superado ? .error : (l.progreso > 0.75 ? .warning : .success), alto: 5)
                    Text(l.superado
                         ? "Superado en \(Formatters.currency(-l.restante))"
                         : "Te quedan \(Formatters.currency(l.restante))")
                        .font(.caption).foregroundStyle(l.superado ? Color.error : .secondary)
                }
            }
        }
    }

    // Dónde se te va
    private func repartoView(_ reparto: [HomeResumen.Reparto]) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            titulo("Dónde se te va")
            ForEach(reparto) { r in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(r.categoria).font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Formatters.currency(r.importe)) · \(r.porcentaje) %").font(.footnote.weight(.semibold))
                    }
                    Barra(progreso: Double(r.porcentaje) / 100, color: UserDataManager.shared.color(for: r.categoria), alto: 5)
                }
            }
        }
    }

    // Próximos cargos
    private func cargosView(_ cargos: [HomeResumen.Cargo], _ total: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Próximos cargos")
            Text(Formatters.currency(total)).font(.title3.weight(.bold))
            Text("\(cargos.count == 1 ? "1 cargo" : "\(cargos.count) cargos") este mes").font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 5) {
                ForEach(cargos) { c in
                    HStack {
                        Text("\(c.nombre) · \(c.dia)").foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Text(Formatters.currency(c.importe))
                    }
                    .font(.caption)
                }
            }
            .padding(.top, 8)
        }
    }

    // Te deben
    private func teDebenView(_ deudas: [HomeResumen.Deuda], _ total: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Te deben")
            Text(Formatters.currency(total)).font(.title3.weight(.bold)).foregroundStyle(Color.success)
            Text(deudas.count == 1 ? "1 persona" : "\(deudas.count) personas").font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 5) {
                ForEach(deudas.prefix(3)) { d in
                    HStack {
                        Text(d.nombre).foregroundStyle(.secondary).lineLimit(1)
                        Spacer()
                        Text(Formatters.currency(d.importe))
                    }
                    .font(.caption)
                }
            }
            .padding(.top, 8)
        }
    }

    // Hucha
    private func huchaView(_ h: HomeResumen.Hucha) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            titulo("Hucha · \(h.nombre)")
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Formatters.currency(h.actual)).font(.callout.weight(.semibold))
                Text("de \(Formatters.currency(h.objetivo))").font(.footnote).foregroundStyle(.secondary)
            }
            Barra(progreso: h.progreso, color: .clarityPrimary, alto: 5).padding(.top, 4)
        }
    }

    // Día más caro
    private func diaCaroView(_ d: HomeResumen.DiaCaro) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Día más caro")
            Text(Formatters.currency(d.importe)).font(.title3.weight(.bold))
            Text(d.fecha.formatted(.dateTime.weekday(.wide).day()).capitalized).font(.caption).foregroundStyle(.secondary)
            Text(d.concepto).font(.caption).foregroundStyle(.secondary).lineLimit(1).padding(.top, 8)
        }
    }

    // Esta semana vs la anterior
    private func semanaView(_ s: HomeResumen.Semana) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Esta semana")
            Text("\(s.porcentaje >= 0 ? "+" : "")\(s.porcentaje) %")
                .font(.title3.weight(.bold))
                .foregroundStyle(s.porcentaje > 0 ? Color.error : Color.success)
            Text("\(Formatters.currency(s.actual)) frente a \(Formatters.currency(s.anterior))").font(.caption).foregroundStyle(.secondary)
            Text(s.porcentaje > 0 ? "Vas por encima de la semana pasada." : "Vas por debajo de la semana pasada.")
                .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
        }
    }

    // Sube fuerte
    private func subeView(_ s: HomeResumen.Subida) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Sube fuerte")
            Text(s.categoria).font(.title3.weight(.bold)).lineLimit(1)
            Text("+\(Formatters.currency(s.delta)) frente al mes pasado").font(.caption).foregroundStyle(.secondary)
        }
    }

    // Comparativa
    private func comparativaView(_ c: HomeResumen.Comparativa) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Frente al mes pasado")
            Text("\(c.porcentaje >= 0 ? "+" : "")\(c.porcentaje) %")
                .font(.title3.weight(.bold))
                .foregroundStyle(c.delta > 0 ? Color.error : Color.success)
            Text("\(Formatters.currency(c.totalActual)) frente a \(Formatters.currency(c.totalAnterior))").font(.caption).foregroundStyle(.secondary)
        }
    }

    // Semana a semana
    private func semanaASemanaView(_ semanas: [Double]) -> some View {
        let maximo = semanas.max() ?? 1
        return VStack(alignment: .leading, spacing: 10) {
            titulo("Semana a semana")
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(semanas.enumerated()), id: \.offset) { i, v in
                    VStack(spacing: 5) {
                        Text(Formatters.currencyCompact(v)).font(.caption2).foregroundStyle(i == semanas.count - 1 ? .primary : .secondary)
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(i == semanas.count - 1 ? Color.clarityPrimary : Color.primary.opacity(0.2))
                            .frame(height: max(6, 56 * (maximo > 0 ? v / maximo : 0)))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Categorías y últimos

private struct CategoriasCard: View {
    let grupos: [CategoryGroup]
    let total: Double
    let numero: Int
    let onVerGastos: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Por categoría").font(.subheadline.weight(.semibold))
                Spacer()
                // La lista completa es la tercera página: esta tarjeta es el
                // resumen y aquella el detalle.
                Button(action: onVerGastos) {
                    HStack(spacing: 3) {
                        Text("\(numero) gastos")
                        Image(systemName: "chevron.right").font(.caption2.weight(.semibold))
                    }
                    .font(.caption).foregroundStyle(Color.clarityPrimary)
                }
            }
            .padding(.bottom, 12)

            ForEach(Array(grupos.prefix(5).enumerated()), id: \.element.id) { i, g in
                if i > 0 { Divider().padding(.leading, 44).padding(.vertical, 10) }
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(g.color.opacity(0.2))
                        Circle().strokeBorder(g.color.opacity(0.45), lineWidth: 0.5)
                        Text(g.emoji).font(.system(size: 15))
                    }
                    .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(g.name).font(.subheadline.weight(.medium)).lineLimit(1)
                            Spacer()
                            Text(Formatters.currency(g.totalAmount)).font(.subheadline.weight(.semibold))
                        }
                        Barra(progreso: total > 0 ? g.totalAmount / total : 0, color: g.color, alto: 3)
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
        .ondaAlTocar()
    }
}

private struct UltimosCard: View {
    let gastos: [Expense]
    let onEditar: (Expense) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Últimos").font(.subheadline.weight(.semibold)).padding(.bottom, 12)
            ForEach(Array(gastos.enumerated()), id: \.element.stableId) { i, g in
                if i > 0 { Divider().padding(.vertical, 10) }
                Button { onEditar(g) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.name).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text("\(Formatters.shortDisplay(g.date)) · \(g.category) · \(g.paymentMethod)")
                                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(Formatters.currency(g.amount)).font(.subheadline.weight(.semibold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard()
        .destello(cuando: gastos.first?.stableId)
    }
}

