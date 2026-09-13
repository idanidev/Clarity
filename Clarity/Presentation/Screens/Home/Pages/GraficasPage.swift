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
    @State private var evolucionMeses = 6
    /// 0 → 1 al entrar en la página. Todo lo que se dibuja cuelga de aquí.
    @State private var dibujado: Double = 0

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                reparto.aparece(dibujado, orden: 0)
                porDia.aparece(dibujado, orden: 1)
                if !viewModel.gastosMesAnterior.isEmpty { comparativa.aparece(dibujado, orden: 2) }
                evolucion.aparece(dibujado, orden: 3)
                calendario.aparece(dibujado, orden: 4)
                semanas.aparece(dibujado, orden: 5)
                Color.clear.frame(height: 16)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xs)
        }
        .contentMargins(.top, margenSuperior, for: .scrollContent)
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
        // Cambiar de mes también redibuja.
        .onChange(of: viewModel.selectedMonth) { _, _ in
            guard activa else { return }
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { dibujado = 0 }
            dibujar()
        }
    }

    private func dibujar() {
        withAnimation(.spring(response: 0.9, dampingFraction: 0.82)) { dibujado = 1 }
    }

    // Reparto por categoría
    private var reparto: some View {
        let datos = gruposParaAnillo(viewModel.gruposDelMes)
        let total = viewModel.resumen.total
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    // El anillo se traza: cada sector crece con `dibujado` y un
                    // sector transparente ocupa lo que falta hasta la vuelta
                    // completa. De paso gira un cuarto hasta su posición.
                    Chart(porciones(datos: datos, total: total)) { p in
                        SectorMark(angle: .value("€", p.valor), innerRadius: .ratio(0.68), angularInset: p.relleno ? 0 : 1.5)
                            .cornerRadius(p.relleno ? 0 : 3)
                            .foregroundStyle(p.color)
                    }
                    .chartLegend(.hidden)
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees((1 - dibujado) * -120))
                    VStack(spacing: 2) {
                        Text("TOTAL").font(.caption2).tracking(0.6).foregroundStyle(Color.textSecondary)
                        Text(Formatters.currency(total * dibujado))
                            .font(.headline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
                            .contentTransition(.numericText(value: total * dibujado))
                    }
                    .frame(width: 96)
                }
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
        let dias = viewModel.gastosPorDia
        let maximo = dias.max(by: { $0.importe < $1.importe })
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Por día").font(.subheadline.weight(.semibold))
                Spacer()
                Text("Media \(Formatters.currency(viewModel.resumen.ritmo.mediaDiaria))").font(.caption).foregroundStyle(Color.textSecondary)
            }
            // El día va como categoría, no como número: con un eje numérico las
            // barras de ancho por ratio se quedaban a cero y el gráfico salía vacío.
            Chart(dias, id: \.dia) { d in
                BarMark(x: .value("Día", String(d.dia)), y: .value("€", d.importe * dibujado), width: .ratio(0.6))
                    .cornerRadius(2)
                    .foregroundStyle(d.dia == maximo?.dia && d.importe > 0 ? Color.error : Color.clarityPrimary)
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
            .frame(height: 110)

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
        let c = viewModel.resumen.comparativa
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
                Capsule().fill(color).frame(width: geo.size.width * p)
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
    /// completarlo mientras se dibuja.
    private func porciones(datos: [CategoryGroup], total: Double) -> [Porcion] {
        var out = datos.map { Porcion(id: $0.id, valor: $0.totalAmount * dibujado, color: $0.color, relleno: false) }
        out.append(Porcion(id: "_relleno", valor: max(total, 1) * (1 - dibujado), color: .clear, relleno: true))
        return out
    }

    // Últimos seis meses
    private var evolucion: some View {
        let evo = viewModel.monthlyEvolution(months: evolucionMeses)
        let media = evo.isEmpty ? 0 : evo.map(\.total).reduce(0, +) / Double(evo.count)
        let clave = String(Formatters.localDayString(from: viewModel.selectedMonth).prefix(7))
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Últimos \(evolucionMeses) meses").font(.subheadline.weight(.semibold))
                Spacer()
                Text("Media \(Formatters.currencyCompact(media))").font(.caption).foregroundStyle(Color.textSecondary)
            }
            Chart(evo) { m in
                BarMark(x: .value("Mes", m.label), y: .value("€", m.total * dibujado), width: .ratio(0.55))
                    .cornerRadius(6)
                    .foregroundStyle(m.key == clave ? Color.clarityPrimary : Color.primary.opacity(0.22))
                    .annotation(position: .top, spacing: 4) {
                        Text(Formatters.currencyCompact(m.total)).font(.caption2)
                            .foregroundStyle(m.key == clave ? .primary : Color.textSecondary)
                            .opacity(dibujado)
                    }
            }
            .chartYAxis(.hidden)
            .chartYScale(domain: 0...max(evo.map(\.total).max() ?? 1, 1) * 1.18)
            .frame(height: 150)
        }
        .padding(16)
        .glassCard()
    }
}

// MARK: - Cuándo

extension GraficasPage {
    private var calendario: some View {
        ExpenseCalendarView(expenses: viewModel.allHistoricalExpenses)
            .padding(.vertical, 8)
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

private extension View {
    /// Cada tarjeta entra desde el lado del swipe, una tras otra.
    func aparece(_ progreso: Double, orden: Int) -> some View {
        self
            .opacity(progreso)
            .offset(x: (1 - progreso) * 44)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(orden) * 0.06), value: progreso)
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
