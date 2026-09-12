// GraficasPage.swift
// Segunda página de la Home: en qué se te va (#65).

import SwiftUI
import Charts

struct GraficasPage: View {
    @Bindable var viewModel: HomeViewModel
    @State private var evolucionMeses = 6

    var body: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.md) {
                reparto
                porDia
                if !viewModel.gastosMesAnterior.isEmpty { comparativa }
                evolucion
                calendario
                semanas
                Color.clear.frame(height: 90)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.xs)
        }
        .scrollIndicators(.hidden)
        .trackScreen("home_graficas")
    }

    // Reparto por categoría
    private var reparto: some View {
        let datos = viewModel.categoryGroups.prefix(6)
        let total = viewModel.resumen.total
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 18) {
                ZStack {
                    Chart(Array(datos), id: \.id) { g in
                        SectorMark(angle: .value("€", g.totalAmount), innerRadius: .ratio(0.68), angularInset: 1.5)
                            .cornerRadius(3)
                            .foregroundStyle(g.color)
                    }
                    .frame(width: 150, height: 150)
                    VStack(spacing: 2) {
                        Text("TOTAL").font(.caption2).tracking(0.6).foregroundStyle(.secondary)
                        Text(Formatters.currency(total)).font(.headline.weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(width: 96)
                }
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(datos), id: \.id) { g in
                        HStack(spacing: 8) {
                            Circle().fill(g.color).frame(width: 8, height: 8)
                            Text(g.name).font(.footnote).lineLimit(1)
                            Spacer()
                            Text("\(total > 0 ? Int((g.totalAmount / total * 100).rounded()) : 0) %").font(.footnote.weight(.semibold))
                        }
                    }
                }
            }
        }
        .padding(16)
        .glassCard()
        .ondaAlTocar()
    }

    // Gasto por día, con el más caro señalado
    private var porDia: some View {
        let dias = viewModel.gastosPorDia
        let maximo = dias.max(by: { $0.importe < $1.importe })
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Por día").font(.subheadline.weight(.semibold))
                Spacer()
                Text("Media \(Formatters.currency(viewModel.resumen.ritmo.mediaDiaria))").font(.caption).foregroundStyle(.secondary)
            }
            Chart(dias, id: \.dia) { d in
                BarMark(x: .value("Día", d.dia), y: .value("€", d.importe), width: .ratio(0.6))
                    .cornerRadius(2)
                    .foregroundStyle(d.dia == maximo?.dia && d.importe > 0 ? Color.error : Color.clarityPrimary)
            }
            .chartXAxis {
                AxisMarks(values: [1, 10, 20, dias.count]) { v in
                    AxisValueLabel { if let n = v.as(Int.self) { Text("\(n)").font(.caption2) } }
                }
            }
            .chartYAxis(.hidden)
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
            HStack {
                Text("Frente al mes pasado").font(.subheadline.weight(.semibold))
                Spacer()
                if let c { Text("\(c.delta > 0 ? "+" : "−")\(Formatters.currency(abs(c.delta))) en total").font(.caption).foregroundStyle(.secondary) }
            }
            HStack(spacing: 14) {
                Label { Text("Este mes") } icon: { Capsule().fill(Color.clarityPrimary).frame(width: 10, height: 6) }
                Label { Text("Anterior") } icon: { Capsule().fill(Color.primary.opacity(0.28)).frame(width: 10, height: 6) }
            }
            .font(.caption).foregroundStyle(.secondary)
            ForEach(filas, id: \.categoria) { f in
                let delta = f.actual - f.anterior
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(f.categoria).font(.footnote)
                        Spacer()
                        Text("\(delta > 0 ? "+" : "−")\(Formatters.currency(abs(delta)))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(delta > 0 ? Color.error : Color.success)
                    }
                    barra(f.actual / maximo, UserDataManager.shared.color(for: f.categoria))
                    barra(f.anterior / maximo, Color.primary.opacity(0.28))
                }
            }
        }
        .padding(16)
        .glassCard()
    }

    private func barra(_ p: Double, _ color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.08))
                Capsule().fill(color).frame(width: geo.size.width * p)
                    .animation(.spring(response: 0.6, dampingFraction: 0.7), value: p)
            }
        }
        .frame(height: 6)
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
                Text("Media \(Formatters.currencyCompact(media))").font(.caption).foregroundStyle(.secondary)
            }
            Chart(evo) { m in
                BarMark(x: .value("Mes", m.label), y: .value("€", m.total), width: .ratio(0.55))
                    .cornerRadius(6)
                    .foregroundStyle(m.key == clave ? Color.clarityPrimary : Color.primary.opacity(0.22))
                    .annotation(position: .top, spacing: 4) {
                        Text(Formatters.currencyCompact(m.total)).font(.caption2).foregroundStyle(m.key == clave ? .primary : .secondary)
                    }
            }
            .chartYAxis(.hidden)
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
                        Text(f.etiqueta).font(.caption2).foregroundStyle(.secondary)
                        Text(Formatters.currencyCompact(f.importe))
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
