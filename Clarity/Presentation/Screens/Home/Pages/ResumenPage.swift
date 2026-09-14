// ResumenPage.swift
// Primera página de la Home: cuánto llevas, y ningún cuadro vacío (#65).

import SwiftUI

struct ResumenPage: View {
    @Bindable var viewModel: HomeViewModel
    /// Hueco de la barra de navegación, medido por quien presenta la página.
    var margenSuperior: CGFloat = 0
    /// Cambia cuando otra tarjeta pide bajar hasta la lista de gastos.
    var irALista: Int = 0
    /// Las transiciones de zoom de la Home: cada fila y cada tarjeta es un origen.
    let zoom: Namespace.ID
    /// El gasto y desde dónde se tocó, para que la hoja crezca desde ahí.
    let onEditar: (Expense, String) -> Void
    let onDestino: (HomeDestino) -> Void

    /// Categorías plegadas. Persiste entre sesiones igual que en la lista vieja.
    @State private var plegadas: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "expenses.collapsedCategories") ?? [])
    @Environment(\.medidaBarraInferior) private var barra

    /// Lo que suman los gastos con los filtros puestos, para enseñarlo bajo el
    /// total del mes. `nil` sin filtros: el total grande sigue siendo el del mes
    /// entero, que es contra el que se mide el presupuesto.
    private var filtrado: HeroCard.Filtrado? {
        guard viewModel.filtroActivo else { return nil }
        // Los mismos datos que las tarjetas y las gráficas: el mes que se ve.
        let r = viewModel.resumen
        return HeroCard.Filtrado(
            total: r.totalAnalisis,
            gastos: r.numeroAnalisis,
            nombre: viewModel.nombreFiltroActual
        )
    }

    var body: some View {
        // Una sola `List`: las tarjetas arriba y los gastos debajo, en el mismo
        // desplazamiento. Es `List` y no `ScrollView` para conservar deslizar
        // para borrar y el menú contextual de cada gasto, que son del sistema.
        ScrollViewReader { proxy in
            List {
                let r = viewModel.resumen

                Group {
                    // El total lleva a Gráficas: es donde se desmenuza.
                    Button { onDestino(.graficas) } label: {
                        HeroCard(resumen: r, mesAnterior: viewModel.nombreMesAnterior, filtrado: filtrado)
                    }
                    .buttonStyle(TarjetaButtonStyle())

                    if let a = r.slots[.a] { slot(a) }

                    if r.slots[.b] != nil || r.slots[.c] != nil {
                        HStack(alignment: .top, spacing: Spacing.xs) {
                            if let b = r.slots[.b] { slot(b, compacta: true) }
                            if let c = r.slots[.c] { slot(c, compacta: true) }
                        }
                    }

                    UltimosCard(gastos: viewModel.ultimosGastos, zoom: zoom, onEditar: onEditar)

                    if let e = r.slots[.e] { slot(e) }
                }
                .filaDeTarjeta()

                listaDeGastos(total: r.total)

                Color.clear.frame(height: 12).filaDeTarjeta()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, margenSuperior, for: .scrollContent)
            // Llega hasta el borde y pasa por debajo de la barra de pestañas: el
            // final deja su hueco y el de los puntos de página.
            .contentMargins(.bottom, barra.total + 28, for: .scrollContent)
            .scrollIndicators(.hidden)
            .onChange(of: irALista) { _, _ in
                withAnimation(.snappy) { proxy.scrollTo("lista", anchor: .top) }
            }
        }
        .trackScreen("home")
    }

    // MARK: - Gastos del mes, por categoría

    @ViewBuilder
    private func listaDeGastos(total: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Gastos del mes").font(.title3.weight(.bold))
            Spacer()
            if viewModel.filtroActivo {
                Label("Filtrado", systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.clarityPrimary)
            } else {
                Text("\(viewModel.filteredExpenses.count) gastos").font(.caption).foregroundStyle(Color.textSecondary)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, Spacing.sm)
        .id("lista")
        .filaDeTarjeta()

        if viewModel.categoryGroups.isEmpty {
            Text("Ningún gasto con este filtro.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.lg)
                .filaDeTarjeta()
        }

        ForEach(viewModel.categoryGroups) { grupo in
            CabeceraCategoria(grupo: grupo, total: viewModel.totalFilteredAmount, plegada: plegadas.contains(grupo.id)) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    if plegadas.contains(grupo.id) { plegadas.remove(grupo.id) } else { plegadas.insert(grupo.id) }
                }
                UserDefaults.standard.set(Array(plegadas), forKey: "expenses.collapsedCategories")
                HapticManager.shared.selection()
            }
            // Mantener pulsada la categoría enseña su detalle entero sin salir.
            .contextMenu {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        if plegadas.contains(grupo.id) { plegadas.remove(grupo.id) } else { plegadas.insert(grupo.id) }
                    }
                } label: {
                    Label(plegadas.contains(grupo.id) ? "Desplegar" : "Plegar",
                          systemImage: plegadas.contains(grupo.id) ? "chevron.down" : "chevron.up")
                }
            } preview: {
                CategoriaDetalleView(grupo: grupo, gastos: viewModel.gastosDelMes, total: total)
                    .frame(width: 360, height: 520)
            }
            .filaDeTarjeta(arriba: 10)

            if !plegadas.contains(grupo.id) {
                ForEach(grupo.subcategories) { sub in
                    if grupo.subcategories.count > 1 {
                        CabeceraSubcategoria(nombre: sub.name, total: sub.totalAmount)
                            .filaDeTarjeta(arriba: 2, abajo: 0)
                    }
                    ForEach(sub.expenses, id: \.stableId) { gasto in
                        let origen = "lista-\(gasto.stableId)"
                        FilaGasto(gasto: gasto, color: grupo.color)
                            .origenZoom(id: origen, en: zoom)
                            .contentShape(Rectangle())
                            .onTapGesture { onEditar(gasto, origen) }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteExpense(gasto) }
                                } label: { Label("Borrar", systemImage: "trash") }
                                Button { onEditar(gasto, origen) } label: { Label("Editar", systemImage: "pencil") }
                                    .tint(Color.clarityPrimary)
                            }
                            // Mantener pulsado: la ficha del gasto y sus acciones.
                            .contextMenu {
                                Button { onEditar(gasto, origen) } label: { Label("Editar", systemImage: "pencil") }
                                Button {
                                    Task { try? await viewModel.duplicateExpense(gasto) }
                                } label: { Label("Duplicar", systemImage: "plus.square.on.square") }
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteExpense(gasto) }
                                } label: { Label("Borrar", systemImage: "trash") }
                            } preview: {
                                GastoPreview(gasto: gasto, color: grupo.color)
                            }
                            .filaDeTarjeta(arriba: 3, abajo: 3)
                    }
                }
            }
        }
    }
}

// MARK: - Cada hueco lleva a donde se gestiona lo que enseña

private extension ResumenPage {
    func slot(_ contenido: HomeResumen.Contenido, compacta: Bool = false) -> some View {
        let destino = destino(de: contenido)
        return Button { onDestino(destino) } label: {
            SlotCard(contenido: contenido, compacta: compacta)
                // Recurrentes y Te deben se abren creciendo desde la tarjeta.
                .origenZoom(id: "destino-\(destino)", en: zoom)
        }
        .buttonStyle(TarjetaButtonStyle())
    }

    func destino(de contenido: HomeResumen.Contenido) -> HomeDestino {
        switch contenido {
        case .limites, .hucha, .limiteSugerido: .metas
        case .cargos: .recurrentes
        case .teDeben: .deudas
        case .reparto, .subeFuerte, .sitios, .hormiga, .racha: .gastos
        case .diaCaro, .semana, .comparativa, .semanaASemana, .fueraDeNormal, .diaSemana, .ahorro, .ranking: .graficas
        }
    }
}

// MARK: - Entrada escalonada al desplazar

private extension View {
    /// Aparece al entrar en pantalla y se apaga al salir por arriba. Va ligado
    /// al desplazamiento, no a un reloj: con la pantalla quieta no cuesta nada.
    func entrada() -> some View {
        scrollTransition(.interactive) { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.6)
                .scaleEffect(phase.isIdentity ? 1 : 0.985)
        }
    }
}

// MARK: - Cabecera: total, presupuesto y ritmo

private struct HeroCard: View {
    /// Lo que suman los gastos con los filtros puestos.
    struct Filtrado: Equatable {
        let total: Double
        let gastos: Int
        /// El nombre del filtro guardado, si lo tiene ("Favs").
        let nombre: String?
    }

    let resumen: HomeResumen
    let mesAnterior: String
    /// Con filtros, su total va debajo del total del mes. El grande sigue siendo
    /// el del mes entero: es contra el que se miden el presupuesto y la previsión.
    let filtrado: Filtrado?
    /// La cifra sube desde cero al aparecer: los dígitos ruedan hasta el total.
    @State private var mostrado = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("GASTADO ESTE MES")
                    .font(.caption2.weight(.medium))
                    .tracking(0.7)
                    .foregroundStyle(Color.textSecondary)
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

            if let filtrado {
                // Lo filtrado debajo, en pequeño: responde a "¿y de lo que he
                // filtrado, cuánto?" sin cambiar lo que mide el presupuesto.
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle.fill")
                        .foregroundStyle(Color.clarityPrimary)
                    Text(filtrado.nombre ?? "Con tus filtros")
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text("· \(filtrado.gastos == 1 ? "1 gasto" : "\(filtrado.gastos) gastos")")
                        .foregroundStyle(Color.textSecondary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(Formatters.currency(filtrado.total))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: filtrado.total))
                }
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.clarityPrimary.opacity(0.14), in: Capsule())
                .padding(.top, 10)
                .transition(.opacity)
            }

            if let progreso = resumen.progresoPresupuesto, let libres = resumen.libres, let presupuesto = resumen.presupuesto {
                if progreso >= 0.85 {
                    // Cerca del tope la barra ondula: se nota sin leer la cifra.
                    BarraOndulada(progreso: progreso, color: progreso >= 1 ? .error : .warning, alto: 6)
                        .padding(.top, 14)
                } else {
                    Barra(progreso: progreso, color: .clarityPrimary)
                        .padding(.top, 14)
                }
                HStack {
                    Text("\(Int((progreso * 100).rounded())) % del presupuesto · \(Formatters.currency(presupuesto))")
                        .foregroundStyle(Color.textSecondary)
                    Spacer()
                    Text("\(Formatters.currency(libres)) libres")
                        .foregroundStyle(libres >= 0 ? Color.success : Color.error)
                        .fontWeight(.medium)
                }
                .font(.footnote)
                .padding(.top, 8)
            } else if resumen.ritmo.cargosPendientes > 0 {
                // Con cargos por venir se dice: la previsión no es solo el ritmo.
                Text("A este ritmo, con **\(Formatters.currency(resumen.ritmo.cargosPendientes))** de cargos pendientes, acabarás en **\(Formatters.currency(resumen.ritmo.prevision))**.")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 10)
            } else {
                Text("A este ritmo acabarás el mes en **\(Formatters.currency(resumen.ritmo.prevision))**.")
                    .font(.footnote)
                    .foregroundStyle(Color.textSecondary)
                    .padding(.top, 10)
            }

            Divider().padding(.vertical, 14)

            HStack {
                Dato("Media diaria", Formatters.currency(resumen.ritmo.mediaDiaria))
                Dato(resumen.presupuesto != nil ? "Previsión" : "Gastos",
                     resumen.presupuesto != nil ? Formatters.currency(resumen.ritmo.prevision) : "\(resumen.numeroGastos)")
                if let porDia = resumen.disponiblePorDia {
                    // Lo libre repartido entre los días que quedan: es lo que
                    // sirve para decidir, no cuántos días faltan.
                    Dato("Al día", Formatters.currency(porDia))
                } else {
                    Dato("Quedan", "\(resumen.ritmo.diasRestantes) días")
                }
            }
        }
        .padding(20)
        // La onda va sobre el contenido y el vidrio por fuera: los efectos de
        // capa rasterizan lo que envuelven, y un material rasterizado pierde el
        // fondo y sale negro.
        .ondaAlTocar()
        .glassCard(cornerRadius: CornerRadius.xlarge)
    }

    @ViewBuilder
    private var chip: some View {
        if let c = resumen.comparativa {
            let baja = c.delta <= 0
            // "que agosto a día 13", no "que agosto": a mediados de mes, contra
            // el mes entero siempre saldría menos y no diría nada.
            Label(c.parcial
                  ? "\(abs(c.porcentaje)) % \(baja ? "menos" : "más") que \(mesAnterior) a día \(c.hastaDia)"
                  : "\(abs(c.porcentaje)) % \(baja ? "menos" : "más") que \(mesAnterior)",
                  systemImage: baja ? "arrow.down.right" : "arrow.up.right")
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .font(.caption.weight(.semibold))
                .foregroundStyle(baja ? Color.success : Color.error)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background((baja ? Color.success : Color.error).opacity(0.16), in: Capsule())
        } else if resumen.diasApuntando > 0 {
            Text("\(resumen.diasApuntando) días apuntando")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.textSecondary)
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
            Text(titulo).font(.caption).foregroundStyle(Color.textSecondary)
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
            case .fueraDeNormal(let d): fueraDeNormalView(d)
            case .sitios(let sitios): sitiosView(sitios)
            case .diaSemana(let d): diaSemanaView(d)
            case .hormiga(let h): hormigaView(h)
            case .ahorro(let a): ahorroView(a)
            case .ranking(let r): rankingView(r)
            case .racha(let r): rachaView(r)
            case .limiteSugerido(let l): limiteSugeridoView(l)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(compacta ? 14 : 16)
        .ondaAlTocar()
        .glassCard(tint: tinte)
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
        Text(t.uppercased()).font(.caption2.weight(.medium)).tracking(0.5).foregroundStyle(Color.textSecondary)
    }

    // Límites
    private func limitesView(_ limites: [HomeResumen.Limite]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            titulo("Límites")
            ForEach(limites.prefix(3)) { l in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(l.categoria.nombreSinEmoji).font(.subheadline.weight(.medium))
                        Spacer()
                        Text(Formatters.currency(l.gastado)).fontWeight(.semibold).foregroundStyle(l.superado ? Color.error : .primary)
                        + Text(" / \(Formatters.currency(l.tope))").foregroundStyle(Color.textSecondary)
                    }
                    .font(.footnote)
                    if l.progreso >= 0.85 {
                        BarraOndulada(progreso: l.progreso, color: l.superado ? .error : .warning, alto: 5)
                    } else {
                        Barra(progreso: l.progreso, color: l.superado ? .error : (l.progreso > 0.75 ? .warning : .success), alto: 5)
                    }
                    Text(l.superado
                         ? "Superado en \(Formatters.currency(-l.restante))"
                         : "Te quedan \(Formatters.currency(l.restante))")
                        .font(.caption).foregroundStyle(l.superado ? Color.error : Color.textSecondary)
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
                        Text(r.categoria.nombreSinEmoji).font(.subheadline.weight(.medium))
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
            Text("\(cargos.count == 1 ? "1 cargo" : "\(cargos.count) cargos") este mes").font(.caption).foregroundStyle(Color.textSecondary)
            VStack(spacing: 5) {
                ForEach(cargos) { c in
                    HStack {
                        Text("\(c.nombre) · \(c.dia)").foregroundStyle(Color.textSecondary).lineLimit(1)
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
            Text(deudas.count == 1 ? "1 persona" : "\(deudas.count) personas").font(.caption).foregroundStyle(Color.textSecondary)
            VStack(spacing: 5) {
                ForEach(deudas.prefix(3)) { d in
                    HStack {
                        Text(d.nombre).foregroundStyle(Color.textSecondary).lineLimit(1)
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
                Text("de \(Formatters.currency(h.objetivo))").font(.footnote).foregroundStyle(Color.textSecondary)
            }
            Barra(progreso: h.progreso, color: .clarityPrimary, alto: 5).padding(.top, 4)
        }
    }

    // Día más caro
    private func diaCaroView(_ d: HomeResumen.DiaCaro) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Día más caro")
            Text(Formatters.currency(d.importe)).font(.title3.weight(.bold))
            Text(d.fecha.formatted(.dateTime.weekday(.wide).day()).capitalized).font(.caption).foregroundStyle(Color.textSecondary)
            Text(d.concepto).font(.caption).foregroundStyle(Color.textSecondary).lineLimit(1).padding(.top, 8)
        }
    }

    // Esta semana vs la anterior
    private func semanaView(_ s: HomeResumen.Semana) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Esta semana")
            Text("\(s.porcentaje >= 0 ? "+" : "")\(s.porcentaje) %")
                .font(.title3.weight(.bold))
                .foregroundStyle(s.porcentaje > 0 ? Color.error : Color.success)
            Text("\(Formatters.currency(s.actual)) frente a \(Formatters.currency(s.anterior))").font(.caption).foregroundStyle(Color.textSecondary)
            Text(s.porcentaje > 0 ? "Más que la semana pasada a estas alturas." : "Menos que la semana pasada a estas alturas.")
                .font(.caption).foregroundStyle(Color.textSecondary).padding(.top, 8)
        }
    }

    // Sube fuerte
    private func subeView(_ s: HomeResumen.Subida) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Sube fuerte")
            Text(s.categoria.nombreSinEmoji).font(.title3.weight(.bold)).lineLimit(1)
            Text("+\(Formatters.currency(s.delta)) frente al mes pasado").font(.caption).foregroundStyle(Color.textSecondary)
        }
    }

    // Comparativa
    private func comparativaView(_ c: HomeResumen.Comparativa) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo(c.parcial ? "Frente al mes pasado, a día \(c.hastaDia)" : "Frente al mes pasado")
            Text("\(c.porcentaje >= 0 ? "+" : "")\(c.porcentaje) %")
                .font(.title3.weight(.bold))
                .foregroundStyle(c.delta > 0 ? Color.error : Color.success)
            Text("\(Formatters.currency(c.totalActual)) frente a \(Formatters.currency(c.totalAnterior))").font(.caption).foregroundStyle(Color.textSecondary)
        }
    }

    // Fuera de lo normal
    private func fueraDeNormalView(_ d: HomeResumen.Desvio) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Fuera de lo normal")
            Text("\(d.porcentaje > 0 ? "+" : "\u{2212}")\(abs(d.porcentaje)) %")
                .font(.title3.weight(.bold))
                .foregroundStyle(d.porcentaje > 0 ? Color.error : Color.success)
            Text("\(d.categoria.nombreSinEmoji) · \(Formatters.currency(d.actual))")
                .font(.footnote.weight(.medium)).lineLimit(1)
            Text("Tu normal a estas alturas: \(Formatters.currency(d.esperado))")
                .font(.caption).foregroundStyle(Color.textSecondary).padding(.top, 8)
        }
    }

    // Tus sitios
    private func sitiosView(_ sitios: [HomeResumen.Sitio]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Tus sitios este mes")
            VStack(spacing: 8) {
                ForEach(sitios) { s in
                    HStack(spacing: 8) {
                        Text(s.nombre).font(.subheadline.weight(.medium)).lineLimit(1)
                        Text("\(s.veces)× · \(Formatters.currency(s.media))/vez")
                            .font(.caption).foregroundStyle(Color.textSecondary).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(Formatters.currency(s.total)).font(.footnote.weight(.semibold))
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // Tu día caro
    private func diaSemanaView(_ d: HomeResumen.DiaSemana) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Tu día caro")
            Text(Self.nombreDelDia(d.dia)).font(.title3.weight(.bold)).lineLimit(1)
            Text("\(Formatters.currency(d.media)) de media, frente a \(Formatters.currency(d.mediaResto)) el resto")
                .font(.caption).foregroundStyle(Color.textSecondary)
            if d.esHoy {
                Text("Hoy toca: ojo.").font(.caption.weight(.medium)).foregroundStyle(Color.warning).padding(.top, 8)
            }
        }
    }

    /// "Sábados", "Lunes": el día en plural, como se dice.
    private static func nombreDelDia(_ dia: Int) -> String {
        let simbolos = Calendar.current.weekdaySymbols
        guard dia >= 1, dia <= simbolos.count else { return "" }
        let nombre = simbolos[dia - 1].capitalized
        return nombre.hasSuffix("s") ? nombre : nombre + "s"
    }

    // Gastos hormiga
    private func hormigaView(_ h: HomeResumen.Hormiga) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Gastos hormiga")
            Text(Formatters.currency(h.total)).font(.title3.weight(.bold))
            Text("\(h.cantidad) gastos de menos de \(Formatters.currency(h.umbral))")
                .font(.caption).foregroundStyle(Color.textSecondary)
        }
    }

    // Ahorro previsto
    private func ahorroView(_ a: HomeResumen.Ahorro) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Ahorro previsto")
            Text(Formatters.currency(a.previsto))
                .font(.title3.weight(.bold))
                .foregroundStyle(a.previsto >= 0 ? Color.success : Color.error)
            if a.previsto < 0 {
                Text("Si el mes sigue así, te pasas.").font(.caption).foregroundStyle(Color.textSecondary)
            } else {
                Text("\(Int((a.porcentaje * 100).rounded())) % de tus ingresos"
                     + (a.medio.map { " · tu media \(Int(($0 * 100).rounded())) %" } ?? ""))
                    .font(.caption).foregroundStyle(Color.textSecondary)
            }
        }
    }

    // Entre tus meses
    private func rankingView(_ r: HomeResumen.Ranking) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Entre tus últimos meses")
            Text(r.posicion == 1 ? "El más barato" : (r.posicion == r.de ? "El más caro" : "\(r.posicion).º más barato"))
                .font(.title3.weight(.bold)).lineLimit(1).minimumScaleFactor(0.8)
            Text("de \(r.de)" + (r.proyectado ? " · si sigue así" : "")).font(.caption).foregroundStyle(Color.textSecondary)
            Text("entre \(Formatters.currencyCompact(r.minimo)) y \(Formatters.currencyCompact(r.maximo))")
                .font(.caption).foregroundStyle(Color.textSecondary).padding(.top, 8)
        }
    }

    // Racha
    private func rachaView(_ r: HomeResumen.Racha) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Racha")
            Text("\(r.dias) días").font(.title3.weight(.bold))
            Text("seguidos apuntando" + (r.record > r.dias ? " · tu récord: \(r.record)" : " · es tu récord"))
                .font(.caption).foregroundStyle(Color.textSecondary)
        }
    }

    // Límite sugerido
    private func limiteSugeridoView(_ l: HomeResumen.LimiteSugerido) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            titulo("Un tope para \(l.categoria.nombreSinEmoji)")
            Text("~\(Formatters.currencyCompact(l.normalMensual)) al mes").font(.title3.weight(.bold))
            Text("Es lo que sueles gastar. Toca para ponerle un límite.")
                .font(.caption).foregroundStyle(Color.textSecondary)
            if l.actual > 0, l.normalMensual > 0 {
                Barra(progreso: min(l.actual / l.normalMensual, 1), color: .clarityPrimary, alto: 5).padding(.top, 10)
                Text("Este mes: \(Formatters.currency(l.actual))").font(.caption).foregroundStyle(Color.textSecondary).padding(.top, 4)
            }
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
                        Text(Formatters.currencyCompact(v)).font(.caption2).foregroundStyle(i == semanas.count - 1 ? .primary : Color.textSecondary)
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

private struct UltimosCard: View {
    let gastos: [Expense]
    let zoom: Namespace.ID
    let onEditar: (Expense, String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Últimos").font(.subheadline.weight(.semibold)).padding(.bottom, 12)
            ForEach(Array(gastos.enumerated()), id: \.element.stableId) { i, g in
                if i > 0 { Divider().padding(.vertical, 10) }
                Button { onEditar(g, "ultimos-\(g.stableId)") } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(g.name).font(.subheadline.weight(.medium)).lineLimit(1)
                            Text("\(Formatters.shortDisplay(g.date)) · \(g.category) · \(g.paymentMethod)")
                                .font(.caption).foregroundStyle(Color.textSecondary).lineLimit(1)
                        }
                        Spacer()
                        Text(Formatters.currency(g.amount)).font(.subheadline.weight(.semibold))
                    }
                    .contentShape(Rectangle())
                    .origenZoom(id: "ultimos-\(g.stableId)", en: zoom)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .destello(cuando: gastos.first?.stableId)
        .glassCard()
    }
}


// MARK: - Detalle de una categoría

/// La tabla del #38 —métricas, subcategorías y todos los gastos— como pantalla
/// propia, a la que se llega con zoom desde la tarjeta.
private struct CategoriaDetalleView: View {
    let grupo: CategoryGroup
    let gastos: [Expense]
    let total: Double

    var body: some View {
        ScrollView {
            CategoryBreakdownTable(
                category: CategoryChartData(
                    name: grupo.name,
                    amount: grupo.totalAmount,
                    percentage: total > 0 ? grupo.totalAmount / total * 100 : 0,
                    color: grupo.color
                ),
                expenses: gastos
            )
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xs)
        }
        .navigationTitle("\(grupo.emoji) \(grupo.name.nombreSinEmoji)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// El emoji de la categoría, o un punto de su color si no tiene ninguno.
struct EmojiDeCategoria: View {
    let emoji: String
    let nombre: String
    let color: Color
    var tamano: CGFloat = 15

    var body: some View {
        let e = emoji.isEmpty ? nombre.soloEmoji : emoji
        if e.isEmpty {
            Circle().fill(color).frame(width: tamano * 0.55, height: tamano * 0.55)
        } else {
            Text(e).font(.system(size: tamano))
        }
    }
}

// MARK: - Filas de la lista

private extension View {
    /// Fila sin fondo ni separador: la lista solo pinta lo nuestro.
    func filaDeTarjeta(arriba: CGFloat = 6, abajo: CGFloat = 6) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: arriba, leading: Spacing.sm, bottom: abajo, trailing: Spacing.sm))
    }
}

/// Cabecera de categoría: emoji, nombre, peso en el mes, total y un chevron que
/// gira al plegar.
private struct CabeceraCategoria: View {
    let grupo: CategoryGroup
    let total: Double
    let plegada: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(grupo.color.opacity(0.22))
                    Circle().strokeBorder(grupo.color.opacity(0.5), lineWidth: 0.5)
                    EmojiDeCategoria(emoji: grupo.emoji, nombre: grupo.name, color: grupo.color, tamano: 16)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(grupo.name.nombreSinEmoji).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                        Text(grupo.expenseCount == 1 ? "1 gasto" : "\(grupo.expenseCount) gastos")
                            .font(.caption).foregroundStyle(Color.textSecondary)
                        Spacer()
                        Text(Formatters.currency(grupo.totalAmount))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(grupo.color)
                            .contentTransition(.numericText(value: grupo.totalAmount))
                    }
                    Barra(progreso: total > 0 ? grupo.totalAmount / total : 0, color: grupo.color, alto: 3)
                }

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.textTertiary)
                    .rotationEffect(.degrees(plegada ? -90 : 0))
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .glassCard(cornerRadius: CornerRadius.medium)
        }
        .buttonStyle(TarjetaButtonStyle())
    }
}

private struct CabeceraSubcategoria: View {
    let nombre: String
    let total: Double

    var body: some View {
        HStack {
            Text(nombre.isEmpty ? "Sin subcategoría" : nombre).font(.caption.weight(.medium)).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(Formatters.currency(total)).font(.caption).foregroundStyle(Color.textSecondary)
        }
        .padding(.horizontal, 10).padding(.top, 4)
    }
}

private struct FilaGasto: View {
    let gasto: Expense
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 1.5).fill(color.opacity(0.7)).frame(width: 3, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(gasto.name).font(.subheadline.weight(.medium)).lineLimit(1)
                Text("\(Formatters.shortDisplay(gasto.date)) · \(gasto.paymentMethod)")
                    .font(.caption).foregroundStyle(Color.textSecondary).lineLimit(1)
            }
            Spacer()
            Text(Formatters.currency(gasto.amount)).font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }
}

/// La ficha que sale al mantener pulsado un gasto.
private struct GastoPreview: View {
    let gasto: Expense
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(gasto.category.nombreSinEmoji.uppercased())
                    .font(.caption2.weight(.semibold)).tracking(0.6)
                    .foregroundStyle(color)
                Spacer()
                Text(Formatters.shortDisplay(gasto.date)).font(.caption).foregroundStyle(Color.textSecondary)
            }
            Text(gasto.name).font(.title3.weight(.semibold)).lineLimit(2)
            Text(Formatters.currency(gasto.amount))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .tracking(-1)
            Divider()
            fila("Subcategoría", gasto.subcategory ?? "—")
            fila("Pago", gasto.paymentMethod)
            if let deudores = gasto.debtors, !deudores.isEmpty {
                fila("Te deben", deudores.filter { !$0.isPaid }.map(\.name).joined(separator: ", "))
            }
            if let notas = gasto.notes, !notas.isEmpty {
                Text(notas).font(.footnote).foregroundStyle(Color.textSecondary).lineLimit(4)
            }
        }
        .padding(20)
        .frame(width: 320, alignment: .leading)
        .background(Color(.secondarySystemBackground))
    }

    private func fila(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo).font(.footnote).foregroundStyle(Color.textSecondary)
            Spacer()
            Text(valor).font(.footnote.weight(.medium)).lineLimit(1)
        }
    }
}
