// GraficasPage.swift
// Segunda página de la Home: en qué se te va (#65).

import SwiftUI
import Charts

struct GraficasPage: View {
    @Bindable var viewModel: HomeViewModel
    /// Hueco de la barra de navegación, medido por quien presenta la página.
    var margenSuperior: CGFloat = 0
    /// Si es la página visible. Al llegar a ella los gráficos se dibujan desde
    /// cero; al irse se reinician sin animación para dibujarse otra vez al volver.
    var activa: Bool = true
    @Environment(\.medidaBarraInferior) private var barra
    @State private var evolucionMeses = 6
    /// 0 → 1 al entrar en la página. Todo lo que se dibuja cuelga de aquí.
    @State private var dibujado: Double = 0

    var body: some View {
        ScrollView {
            // Las tarjetas ya no entran deslizándose una a una: moverlas movía su
            // vidrio, que se recalculaba en cada frame, y era el tirón al llegar
            // a la página. Lo que se anima es lo de dentro: el anillo se traza,
            // las barras crecen y las cifras cuentan.
            LazyVStack(spacing: Spacing.md) {
                reparto
                porDia
                if !viewModel.gastosMesAnterior.isEmpty { comparativa }
                evolucion
                calendario
                semanas
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xs)
        }
        .contentMargins(.top, margenSuperior, for: .scrollContent)
        // Llega hasta el borde y pasa por debajo de la barra de pestañas: el
        // final deja su hueco y el de los puntos de página.
        .contentMargins(.bottom, barra.total + 28, for: .scrollContent)
        .scrollIndicators(.hidden)
        .trackScreen("home_graficas")
        .onAppear { if activa { dibujar() } }
        .onChange(of: activa) { _, ahora in
            if ahora {
                dibujar()
            } else {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) { dibujado = 0 }
            }
        }
        // Cambiar de mes ya no redibuja desde cero: las seis tarjetas a la vez
        // era medio segundo de tirón con cada flecha.
    }

    private func dibujar() {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.85)) { dibujado = 1 }
    }

    // Reparto por categoría
    private var reparto: some View {
        let datos = gruposParaAnillo(viewModel.gruposDelMes)
        // Lo que pasa los filtros: con el total del mes entero y los grupos
        // filtrados, los porcentajes dejaban de sumar el 100 %.
        let total = viewModel.resumen.totalAnalisis
        let sectores = porciones(datos: datos, total: total)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                // En su propia vista: la selección del anillo cambia en cada frame
                // del arrastre y así solo se repinta él, no la página entera.
                AnilloReparto(datos: datos, sectores: sectores, total: total, dibujado: dibujado)
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(datos, id: \.id) { g in
                        HStack(spacing: 8) {
                            Circle().fill(g.color).frame(width: 8, height: 8)
                            Text(g.name.nombreSinEmoji).font(.footnote).lineLimit(1)
                            Spacer()
                            Text("\(total > 0 ? Int((g.totalAmount / total * 100).rounded()) : 0) %").font(.footnote.weight(.semibold))
                        }
                    }
                }
            }
        }
        .padding(16)
        // Sin onda: con un Chart dentro el efecto rasteriza la vista y el vidrio
        // se vuelve un rectángulo opaco.
        .glassCard()
    }

    // Gasto por día, con el más caro señalado
    private var porDia: some View {
        VStack(alignment: .leading, spacing: 12) {
            GraficoPorDia(
                dias: viewModel.gastosPorDia,
                media: viewModel.resumen.mediaDiariaAnalisis,
                mes: viewModel.selectedMonth,
                dibujado: dibujado
            )

            if let d = viewModel.resumen.diaMasCaro, d.importe > 0 {
                Aviso(icono: "exclamationmark.circle", color: .error,
                      texto: "Día más caro: **\(d.fecha.formatted(.dateTime.weekday(.wide).day()))** · \(Formatters.currency(d.importe))")
            }
        }
        .padding(16)
        .glassCard()
    }

    // Este mes frente al anterior, por categoría
    private var comparativa: some View {
        let filas = viewModel.comparativaPorCategoria
        let maximo = max(filas.map { max($0.actual, $0.anterior) }.max() ?? 1, 1)
        // La de lo filtrado: las filas de abajo también lo son.
        let c = viewModel.resumen.comparativaAnalisis
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Frente a \(viewModel.nombreMesAnterior)").font(.subheadline.weight(.semibold))
                    if let c, c.parcial {
                        Text("hasta el día \(c.hastaDia), en los dos meses").font(.caption2).foregroundStyle(Color.textSecondary)
                    }
                }
                Spacer()
                if let c { Text("\(c.delta > 0 ? "+" : "−")\(Formatters.currency(abs(c.delta))) en total").font(.caption).foregroundStyle(Color.textSecondary) }
            }
            HStack(spacing: 14) {
                Label { Text("Este mes") } icon: { Capsule().fill(Color.clarityPrimary).frame(width: 10, height: 6) }
                Label { Text(viewModel.nombreMesAnterior.capitalized) } icon: { Capsule().fill(Color.primary.opacity(0.28)).frame(width: 10, height: 6) }
            }
            .font(.caption).foregroundStyle(Color.textSecondary)
            ForEach(Array(filas.enumerated()), id: \.element.categoria) { i, f in
                let delta = f.actual - f.anterior
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(f.categoria.nombreSinEmoji).font(.footnote)
                        Spacer()
                        // Sin cambio no es ahorro: "igual", en gris.
                        Text(abs(delta) < 0.5 ? "igual" : "\(delta > 0 ? "+" : "−")\(Formatters.currency(abs(delta)))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(abs(delta) < 0.5 ? Color.textSecondary : (delta > 0 ? Color.error : Color.success))
                    }
                    barra(f.actual / maximo * dibujado, UserDataManager.shared.color(for: f.categoria), retardo: Double(i) * 0.07)
                    barra(f.anterior / maximo * dibujado, Color.primary.opacity(0.28), retardo: Double(i) * 0.07 + 0.04)
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func barra(_ p: Double, _ color: Color, retardo: Double = 0) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(color).frame(width: geo.size.width * min(max(p, 0), 1))
                    .animation(.spring(response: 0.7, dampingFraction: 0.72).delay(retardo), value: p)
            }
        }
        .frame(height: 6)
    }

    /// Cinco categorías y el resto juntas en "Otras": así el anillo y la leyenda
    /// suman siempre el 100 % del total que se enseña en el centro.
    private func gruposParaAnillo(_ grupos: [CategoryGroup]) -> [CategoryGroup] {
        guard grupos.count > 6 else { return grupos }
        let resto = grupos.dropFirst(5)
        let otras = CategoryGroup(
            name: "Otras", emoji: "", color: Color.primary.opacity(0.35),
            totalAmount: resto.reduce(0) { $0 + $1.totalAmount },
            expenseCount: resto.reduce(0) { $0 + $1.expenseCount },
            subcategories: []
        )
        return Array(grupos.prefix(5)) + [otras]
    }

    /// Los sectores del anillo más el relleno transparente que falta hasta
    /// completarlo mientras se dibuja. Vacío cuando no hay nada que repartir.
    ///
    /// Las dos guardas son las del cierre al cambiar de mes: la suma de los
    /// ángulos tiene que ser positiva —si no, Swift Charts divide entre cero—
    /// y ningún sector negativo —`dibujado` sale de un muelle y puede pasarse
    /// de 1 un instante—.
    private func porciones(datos: [CategoryGroup], total: Double) -> [Porcion] {
        let conGasto = datos.filter { $0.totalAmount > 0 && $0.totalAmount.isFinite }
        guard !conGasto.isEmpty else { return [] }
        let progreso = min(max(dibujado, 0), 1)
        var out = conGasto.map { Porcion(id: $0.id, valor: $0.totalAmount * progreso, color: $0.color, relleno: false) }
        out.append(Porcion(id: "_relleno", valor: max(total, 1) * (1 - progreso), color: .clear, relleno: true))
        let suma = out.reduce(0) { $0 + $1.valor }
        return suma > 0 && suma.isFinite ? out : []
    }

    // Últimos seis meses
    private var evolucion: some View {
        // Con filtros, cada mes suma solo lo que los pasa.
        let evo = viewModel.evolucion(meses: evolucionMeses)
        let media = evo.isEmpty ? 0 : evo.map(\.total).reduce(0, +) / Double(evo.count)
        let clave = String(Formatters.localDayString(from: viewModel.selectedMonth).prefix(7))
        return GraficoEvolucion(meses: evolucionMeses, evo: evo, media: media, clave: clave, dibujado: dibujado)
            .padding(16)
            .glassCard()
    }
}

// MARK: - Cuándo

extension GraficasPage {
    private var calendario: some View {
        ExpenseCalendarView(expenses: viewModel.allHistoricalExpenses, mes: viewModel.selectedMonth)
            .glassCard()
    }

    private var semanas: some View {
        let filas = viewModel.semanasDelMes
        let maximo = filas.map(\.importe).max() ?? 0
        return VStack(alignment: .leading, spacing: 12) {
            Text("Por semanas").font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                ForEach(Array(filas.enumerated()), id: \.offset) { _, f in
                    VStack(spacing: 3) {
                        Text(f.etiqueta).font(.caption2).foregroundStyle(Color.textSecondary)
                        Text(Formatters.currencyCompact(f.importe * dibujado))
                            .contentTransition(.numericText(value: f.importe * dibujado))
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(maximo > 0 && f.importe == maximo ? Color.error : .primary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .glassCard()
    }
}

private struct Porcion: Identifiable {
    let id: String
    let valor: Double
    let color: Color
    let relleno: Bool
}

// MARK: - Gráficos que se tocan
//
// Cada uno guarda su selección: Swift Charts la actualiza mientras dura el
// arrastre y, estando aquí y no en la página, solo se repinta la tarjeta tocada.
// Al soltar, `chartXSelection`/`chartAngleSelection` la devuelven a `nil` solos.

/// El anillo del reparto. Al arrastrar, el centro cuenta la categoría que queda
/// bajo el dedo en lugar del total.
private struct AnilloReparto: View {
    let datos: [CategoryGroup]
    let sectores: [Porcion]
    let total: Double
    let dibujado: Double
    /// Euros acumulados bajo el dedo, en el orden de los sectores.
    @State private var angulo: Double?

    var body: some View {
        let elegida = categoriaElegida
        ZStack {
            if sectores.isEmpty {
                // Nada que repartir: un anillo vacío. Un `Chart` con todos
                // los sectores a cero divide entre cero y Swift Charts
                // revienta ("Double value cannot be converted to Int").
                // Pasaba al ir a un mes que aún no había llegado de red.
                Circle()
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 24)
                    .frame(width: 150, height: 150)
            } else {
                // El anillo se traza: cada sector crece con `dibujado` y un
                // sector transparente ocupa lo que falta hasta la vuelta
                // completa. De paso gira un cuarto hasta su posición.
                Chart(sectores) { p in
                    SectorMark(angle: .value("€", p.valor), innerRadius: .ratio(0.68), angularInset: p.relleno ? 0 : 1.5)
                        .cornerRadius(p.relleno ? 0 : 3)
                        .foregroundStyle(p.color)
                        .opacity(elegida == nil || elegida?.id == p.id ? 1 : 0.35)
                }
                .chartLegend(.hidden)
                .chartAngleSelection(value: $angulo)
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees((1 - dibujado) * -120))
            }
            VStack(spacing: 2) {
                if let elegida {
                    Text(elegida.name.nombreSinEmoji)
                        .font(.caption2).foregroundStyle(Color.textSecondary)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(Formatters.currency(elegida.totalAmount))
                        .font(.headline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
                    Text("\(porcentaje(elegida.totalAmount)) %")
                        .font(.caption2.weight(.semibold)).foregroundStyle(Color.textSecondary)
                } else {
                    Text("TOTAL").font(.caption2).tracking(0.6).foregroundStyle(Color.textSecondary)
                    Text(Formatters.currency(total * dibujado))
                        .font(.headline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
                        .contentTransition(.numericText(value: total * dibujado))
                }
            }
            .frame(width: 96)
            // El centro queda encima del gráfico: sin esto se tragaría los
            // arrastres que empiezan en el hueco del anillo.
            .allowsHitTesting(false)
        }
        .onChange(of: elegida?.id) { _, nueva in
            if nueva != nil { HapticManager.shared.selection() }
        }
    }

    /// La categoría bajo el dedo. El sector transparente del dibujado no cuenta.
    private var categoriaElegida: CategoryGroup? {
        guard let angulo else { return nil }
        var acumulado = 0.0
        for p in sectores {
            acumulado += p.valor
            if angulo <= acumulado {
                return p.relleno ? nil : datos.first { $0.id == p.id }
            }
        }
        return nil
    }

    /// Mismo cálculo que la leyenda, para que las dos cifras coincidan.
    private func porcentaje(_ importe: Double) -> Int {
        total > 0 ? Int((importe / total * 100).rounded()) : 0
    }
}

/// Gasto por día, con el más caro señalado. Al arrastrar se ve el día y su importe.
private struct GraficoPorDia: View {
    let dias: [(dia: Int, importe: Double)]
    let media: Double
    /// El mes que se enseña, para ponerle nombre al día elegido.
    let mes: Date
    let dibujado: Double
    /// El día bajo el dedo, con la misma etiqueta que el eje.
    @State private var seleccion: String?

    var body: some View {
        let maximo = dias.max(by: { $0.importe < $1.importe })
        let elegido = seleccion.flatMap { s in dias.first { String($0.dia) == s } }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Por día").font(.subheadline.weight(.semibold))
                Spacer()
                // La anotación del día elegido cae sobre esta fila: la media se
                // aparta para no quedar pisada, sin mover nada de sitio.
                Text("Media \(Formatters.currency(media))").font(.caption).foregroundStyle(Color.textSecondary)
                    .opacity(elegido == nil ? 1 : 0)
            }
            // El día va como categoría, no como número: con un eje numérico las
            // barras de ancho por ratio se quedaban a cero y el gráfico salía vacío.
            Chart {
                ForEach(dias, id: \.dia) { d in
                    BarMark(x: .value("Día", String(d.dia)), y: .value("€", d.importe * dibujado), width: .ratio(0.6))
                        .cornerRadius(2)
                        .foregroundStyle(d.dia == maximo?.dia && d.importe > 0 ? Color.error : Color.clarityPrimary)
                        .opacity(elegido == nil || elegido?.dia == d.dia ? 1 : 0.35)
                }
                if let elegido {
                    RuleMark(x: .value("Día", String(elegido.dia)))
                        .foregroundStyle(Color.textTertiary)
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .zIndex(-1)
                        .annotation(position: .top, spacing: 4,
                                    overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            EtiquetaSeleccion(titulo: nombreDia(elegido.dia), importe: elegido.importe)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: ["1", "10", "20", String(dias.count)]) { v in
                    AxisValueLabel(anchor: .top, collisionResolution: .disabled) {
                        if let n = v.as(String.self) { Text(n).font(.caption2) }
                    }
                }
            }
            .chartYAxis(.hidden)
            // Escala fija al máximo real: sin ella el eje crecería con las barras
            // y parecerían llenas desde el primer frame.
            .chartYScale(domain: 0...max(maximo?.importe ?? 1, 1))
            .chartXSelection(value: $seleccion)
            .frame(height: 110)
        }
        .onChange(of: seleccion) { _, nuevo in
            if nuevo != nil { HapticManager.shared.selection() }
        }
    }

    /// "martes 16". Solo se llama con un día elegido, no en cada pintado.
    private func nombreDia(_ dia: Int) -> String {
        let cal = Calendar.current
        guard let inicio = cal.date(from: cal.dateComponents([.year, .month], from: mes)),
              let fecha = cal.date(byAdding: .day, value: dia - 1, to: inicio)
        else { return "Día \(dia)" }
        return fecha.formatted(.dateTime.weekday(.wide).day())
    }
}

/// Los últimos meses. Al arrastrar, la cabecera enseña el total exacto del mes.
private struct GraficoEvolucion: View {
    let meses: Int
    let evo: [MonthlySpending]
    let media: Double
    /// "yyyy-MM" del mes que se enseña, que va en el color de la app.
    let clave: String
    let dibujado: Double
    /// La etiqueta del mes bajo el dedo, la misma que la del eje.
    @State private var seleccion: String?

    var body: some View {
        let elegido = seleccion.flatMap { s in evo.first { $0.label == s } }
        let claveElegida = elegido?.key
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Últimos \(meses) meses").font(.subheadline.weight(.semibold))
                Spacer()
                if let elegido {
                    // Las barras ya llevan la cifra redondeada; aquí va la exacta.
                    Text("\(nombreMes(elegido)) · \(Formatters.currency(elegido.total))")
                        .font(.caption.weight(.semibold))
                } else {
                    Text("Media \(Formatters.currencyCompact(media))").font(.caption).foregroundStyle(Color.textSecondary)
                }
            }
            Chart(evo) { m in
                BarMark(x: .value("Mes", m.label), y: .value("€", m.total * dibujado), width: .ratio(0.55))
                    .cornerRadius(6)
                    .foregroundStyle(m.key == clave ? Color.clarityPrimary : Color.primary.opacity(0.22))
                    .opacity(claveElegida == nil || claveElegida == m.key ? 1 : 0.4)
                    .annotation(position: .top, spacing: 4) {
                        Text(Formatters.currencyCompact(m.total)).font(.caption2)
                            .foregroundStyle(m.key == clave ? .primary : Color.textSecondary)
                            .opacity(dibujado * (claveElegida == nil || claveElegida == m.key ? 1 : 0.4))
                    }
            }
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...max(evo.map(\.total).max() ?? 1, 1) * 1.18)
            .chartXSelection(value: $seleccion)
            .frame(height: 150)
        }
        .onChange(of: seleccion) { _, nuevo in
            if nuevo != nil { HapticManager.shared.selection() }
        }
    }

    /// "Septiembre" a partir de la clave "yyyy-MM"; la etiqueta corta si no se lee.
    private func nombreMes(_ m: MonthlySpending) -> String {
        guard let numero = Int(m.key.suffix(2)), (1...12).contains(numero) else { return m.label }
        return Formatters.fullMonthName(numero)
    }
}

/// El dato exacto de lo que está bajo el dedo, encima del gráfico.
private struct EtiquetaSeleccion: View {
    let titulo: String
    let importe: Double

    var body: some View {
        VStack(spacing: 1) {
            Text(titulo).font(.caption2).foregroundStyle(Color.textSecondary)
            Text(Formatters.currency(importe)).font(.caption.weight(.semibold))
        }
        .lineLimit(1)
        .padding(.horizontal, 10).padding(.vertical, 5)
        // Material y no color: tapa lo que quede debajo sin romper el vidrio.
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }
}

private struct Aviso: View {
    let icono: String
    let color: Color
    let texto: LocalizedStringKey

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icono).foregroundStyle(color)
            Text(texto).font(.footnote)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(color.opacity(0.3), lineWidth: 0.5))
    }
}
